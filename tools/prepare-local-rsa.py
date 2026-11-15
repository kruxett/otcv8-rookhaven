"""Prepare a private loopback RSA-2048 fixture and its matching public modulus.

Never rotates an existing key or reads a DEV/production runtime key.
"""
from pathlib import Path
import argparse,csv,io,json,os,subprocess
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.serialization import Encoding,PrivateFormat,NoEncryption,load_pem_private_key
p=argparse.ArgumentParser();p.add_argument('--directory',type=Path);args=p.parse_args()
root=Path(__file__).resolve().parents[1]
directory=(args.directory or root/'out/local-server/auth').resolve()
directory.mkdir(parents=True,exist_ok=True)
if os.name=='nt':
 system=Path(os.environ['SystemRoot'])/'System32'
 identity=subprocess.check_output([str(system/'whoami.exe'),'/user','/fo','csv','/nh'],text=True)
 sid=next(csv.reader(io.StringIO(identity)))[1]
 assert sid.startswith('S-1-5-'),'Unexpected local Windows identity'
 subprocess.run([str(system/'icacls.exe'),str(directory),'/inheritance:r','/grant:r','*'+sid+':(OI)(CI)F','*S-1-5-18:(OI)(CI)F'],check=True,capture_output=True)
private=directory/'key.pem';public=directory/'public-modulus.txt'
if private.exists():key=load_pem_private_key(private.read_bytes(),None)
else:
 key=rsa.generate_private_key(public_exponent=65537,key_size=2048)
 with private.open('xb') as file:file.write(key.private_bytes(Encoding.PEM,PrivateFormat.TraditionalOpenSSL,NoEncryption()))
assert key.key_size==2048 and key.public_key().public_numbers().e==65537,'Loopback fixture requires RSA-2048; existing key was preserved'
modulus=str(key.public_key().public_numbers().n)+'\n'
if public.exists():assert public.read_text(encoding='ascii')==modulus,'Public fixture differs; existing files were preserved'
else:
 with public.open('x',encoding='ascii') as file:file.write(modulus)
print(json.dumps({'privateKey':str(private),'publicKey':str(public),'bits':2048}))
