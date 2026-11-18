-- Focused lifecycle/failure checks for the actual client service implementation.
local timers,results={},{ }
function tr(s)return s end
function scheduleEvent(fn)timers[#timers+1]=fn;return fn end
function removeEvent(fn)end
Protocol={}
function extends(base)
  local class=setmetatable({}, {__index=base})
  class.create=function()return setmetatable({sent={}}, {__index=class})end
  return class
end
function Protocol:connect()self:onConnect()end
function Protocol:disconnect()self.disconnected=true end
function Protocol:generateXteaKey()end
function Protocol:getXteaKey()return {1,2,3,4}end
function Protocol:enableChecksum()self.checksum=true end
function Protocol:enableXteaEncryption()self.encrypted=true end
function Protocol:recv()end
function Protocol:send(msg)
  assert(self.checksum,'frame checksum missing')
  self.sent[#self.sent+1]={values=msg.values,encrypted=self.encrypted,rsa=msg.rsa}
end
OutputMessage={create=function()
  local m={values={},size=0}
  for name,size in pairs({addU8=1,addU16=2,addU32=4})do m[name]=function(self,n)self.values[#self.values+1]=n;self.size=self.size+size end end
  function m:addString(s)assert(type(s)=='string');self.values[#self.values+1]=s;self.size=self.size+2+#s end
  function m:getMessageSize()return self.size end
  function m:encryptRsa()self.rsa=true end
  return m
end}
g_crypt={rsaGetSize=function()return 128 end}
dofile('modules/gamelib/protocolaccounts.lua')
dofile('modules/corelib/json.lua')
local function message(values)
  local m={values=values,p=0}
  function m:next()self.p=self.p+1;assert(self.values[self.p]~=nil,'overrun');return self.values[self.p]end
  m.getU8,m.getString=m.next,m.next
  function m:eof()return self.p==#self.values end
  return m
end
local policy={0x11,1,1,1,8,'Rookhaven','Stillshore'}
local function begin(action,values)
  results={};local p=ProtocolAccounts.create()
  p:request({host='qa',port=1},action or 1,values or {account='privateaccount',password='privatepassword',email='private@example.invalid',name='Hero',sex=1},function(...)results[#results+1]={...}end)
  assert(#p.sent==1 and p.sent[1].rsa and not p.sent[1].encrypted,'credentials connection must begin with RSA handshake')
  for _,v in ipairs(p.sent[1].values)do assert(v~='privateaccount'and v~='privatepassword'and v~='private@example.invalid','credential before encryption')end
  return p
end
local p=begin();p:onRecv(message(policy));assert(#p.sent==2 and p.sent[2].encrypted,'credentials not encrypted')
p:onRecv(message({0x12,1,'Ready','privateaccount'}));p:onError();timers[#timers]()
assert(#results==1 and results[1][1] and p.disconnected and p.values==nil,'completion not exactly once/credentials retained')
p=begin(0);p:onRecv(message(policy));assert(#p.sent==1 and results[1][1]and results[1][4].town=='Stillshore','policy query sent credentials')
for _,reply in ipairs({{0x12,1,'Early','account'},{0x11,1,2,1,8,'World','Town'},{0x11,1,1,1,21,'World','Town'},{0x11,2,1,1,8,'World','Town'},{0x11,1,1},{0x99}})do
  p=begin();p:onRecv(message(reply));assert(#results==1 and not results[1][1]and #p.sent==1,'malformed/early reply accepted')
end
p=begin();p:onRecv(message(policy));p:onRecv(message(policy));assert(not results[1][1]and #p.sent==2,'repeated policy accepted')
p=begin();p:onRecv(message({0x11,1,0,1,8,'World','Town'}));assert(#p.sent==1 and not results[1][1],'closed registration submitted credentials')
p=begin();p:cancel();p:onRecv(message(policy));timers[#timers]();assert(#results==0 and p.values==nil and #p.sent==1,'cancel callback leaked into reopened UI')
p=begin();timers[#timers]();p:onRecv(message(policy));assert(#results==1 and not results[1][1],'timeout accepted a late reply')
p=begin();p:onRecv(message({0x12,0,'Unavailable',''}));assert(not results[1][1],'pre-policy refusal not handled')
local caps={management=true,twoFactor=true,emailVerification=false,passwordRecovery=false}
local function v2(values)return {0x11,2,1,1,8,'Rookhaven','Stillshore',json.encode(values or caps)}end
p=begin(3);assert(p.sent[1].values[2]==2,'management did not select RHA2')
p:onRecv(message(v2()));assert(p.sent[2].encrypted,'management credentials were not encrypted')
p:onRecv(message({0x13,1,'Done','{"account":"privateaccount"}'}));assert(results[1][1] and results[1][5].account=='privateaccount','typed management data missing')
for _,raw in ipairs({'[]','{"management":true}','not-json',string.rep('x',513)})do
  p=begin(3);p:onRecv(message({0x11,2,1,1,8,'World','Town',raw}));assert(not results[1][1] and #p.sent==1,'invalid RHA2 capabilities accepted')
end
caps.management=false;p=begin(3);p:onRecv(message(v2()));assert(not results[1][1] and #p.sent==1,'disabled management submitted credentials');caps.management=true
caps.account=false;caps.world=false;p=begin(3);p:onRecv(message(v2()));assert(p.policy.account and p.policy.world=='Rookhaven','capability extension overwrote base policy');caps.account=nil;caps.world=nil
for _,reply in ipairs({{0x13,1,'Done','bad-json'},{0x13,2,'Done','{}'},{0x13,1,'Done','{}','trailing'},{0x12,1,'Wrong operation',''}})do
  p=begin(3);p:onRecv(message(v2()));p:onRecv(message(reply));assert(not results[1][1],'malformed management reply accepted')
end
p=begin(3);p:cancel();p:onRecv(message(v2()));assert(#results==0 and p.values==nil,'management cancellation leaked a callback')
print('ACCOUNTS_PROTOCOL_OK encryptedCredentials=true strictReplies=true cancel=true timeout=true closed=true exactlyOnce=true')
