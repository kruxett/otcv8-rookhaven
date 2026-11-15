"""Native 8.60 account/login client used only by the owned loopback runner."""
import os,socket,struct,zlib,time,threading
from cryptography.hazmat.primitives.serialization import load_pem_private_key

def u16(n):return struct.pack('<H',n)
def string(s):
    b=s.encode();return u16(len(b))+b
def xtea(data,key,decrypt=False):
    assert len(data)%8==0
    result=bytearray(); mask=0xffffffff; delta=0x9e3779b9
    for start in range(0,len(data),8):
        a,b=struct.unpack_from('<II',data,start); total=(delta*32)&mask if decrypt else 0
        for _ in range(32):
            if decrypt:
                b=(b-((((a<<4)^(a>>5))+a)^(total+key[(total>>11)&3])))&mask
                total=(total-delta)&mask
                a=(a-((((b<<4)^(b>>5))+b)^(total+key[total&3])))&mask
            else:
                a=(a+((((b<<4)^(b>>5))+b)^(total+key[total&3])))&mask
                total=(total+delta)&mask
                b=(b+((((a<<4)^(a>>5))+a)^(total+key[(total>>11)&3])))&mask
        result+=struct.pack('<II',a,b)
    return bytes(result)
class Reader:
    def __init__(self,data):self.data,self.pos=data,0
    def take(self,n):
        assert self.pos+n<=len(self.data),'short reply'
        b=self.data[self.pos:self.pos+n];self.pos+=n;return b
    def byte(self):return self.take(1)[0]
    def word(self):return struct.unpack('<H',self.take(2))[0]
    def text(self):return self.take(self.word()).decode()
    def complete(self):assert self.pos==len(self.data),'trailing reply'
connect_lock=threading.Lock()
last_connect=0
connect_spacing=.55
class Wire:
    def __init__(self,pem,port):
        self.public=load_pem_private_key(pem,None).public_key().public_numbers()
        self.key=struct.unpack('<IIII',os.urandom(16))
        # Respect the existing shared native connection flood protection.
        global last_connect
        with connect_lock:
            time.sleep(max(0,connect_spacing-(time.monotonic()-last_connect)))
            self.socket=socket.create_connection(('127.0.0.1',port),5);last_connect=time.monotonic()
        self.socket.settimeout(6)
    def close(self):self.socket.close()
    def rsa(self,data):
        size=(self.public.n.bit_length()+7)//8
        assert len(data)<=size
        data+=os.urandom(size-len(data))
        return pow(int.from_bytes(data,'big'),self.public.e,self.public.n).to_bytes(size,'big')
    def send(self,payload,encrypted=True):
        if encrypted:
            payload=u16(len(payload))+payload
            payload+=b'\0'*((-len(payload))%8)
            payload=xtea(payload,self.key)
        frame=struct.pack('<I',zlib.adler32(payload))+payload
        self.socket.sendall(u16(len(frame))+frame)
    def receive(self):
        def exact(n):
            data=b''
            while len(data)<n:
                b=self.socket.recv(n-len(data))
                if not b:raise EOFError('server closed')
                data+=b
            return data
        data=exact(struct.unpack('<H',exact(2))[0]);assert zlib.adler32(data[4:])==struct.unpack('<I',data[:4])[0]
        clear=xtea(data[4:],self.key,True);size=struct.unpack_from('<H',clear)[0]
        assert 0<size<=len(clear)-2
        return Reader(clear[2:2+size])
    def handshake(self):
        self.send(b'\x03\x01'+u16(860)+self.rsa(b'\0'+struct.pack('<IIII',*self.key)+string('RHA1')),False)
        r=self.receive();op=r.byte()
        if op==0x12:return self.result(r)
        assert op==0x11 and r.byte()==1
        policy={'account':r.byte(),'character':r.byte(),'limit':r.byte(),'world':r.text(),'town':r.text()};r.complete()
        return policy
    def result(self,r):
        answer={'success':r.byte(),'message':r.text(),'name':r.text()};r.complete();return answer
    def create(self,action,account,password,value,sex=1,extra=b''):
        policy=self.handshake();assert 'success' not in policy,policy
        return self.submit(action,account,password,value,sex,extra)
    def submit(self,action,account,password,value,sex=1,extra=b''):
        self.send(bytes([action])+string(account)+string(password)+string(value)+(bytes([sex]) if action==2 else b'')+extra)
        r=self.receive();assert r.byte()==0x12
        return self.result(r)
    def login(self,account,password):
        self.send(b'\x01'+u16(2)+u16(860)+b'\0'*12+self.rsa(b'\0'+struct.pack('<IIII',*self.key)+string(account)+string(password)+string('OTCv8')+u16(400)),False)
        r=self.receive();characters=[]
        while r.pos<len(r.data):
            op=r.byte()
            if op in (10,11):return {'error':r.text()}
            if op==20:r.text()
            elif op==100:
                for _ in range(r.byte()):characters.append({'name':r.text(),'world':r.text(),'ip':socket.inet_ntoa(r.take(4)),'port':r.word()})
                r.word()
            else:raise AssertionError('unexpected normal login opcode '+str(op))
        return {'characters':characters}
