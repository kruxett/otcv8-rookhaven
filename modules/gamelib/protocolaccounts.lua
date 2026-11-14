-- RHA1: account services on the selected world's existing login port.
-- Only the RSA/XTEA handshake precedes encryption; credentials never use HTTP.
ProtocolAccounts = extends(Protocol, 'ProtocolAccounts')

function ProtocolAccounts:request(endpoint, action, values, callback)
  self.action, self.values, self.callback = action, values or {}, callback
  self.completed = false
  self.timeout = scheduleEvent(function()
    self:finish(false, tr('The connection timed out. If you submitted a creation request, try logging in or refreshing your character list before retrying.'))
  end, 20000)
  self:connect(endpoint.host, endpoint.port)
end

function ProtocolAccounts:finish(success, message, name, policy)
  if self.completed then return end
  self.completed = true
  if self.timeout then removeEvent(self.timeout); self.timeout = nil end
  self:disconnect()
  local callback = self.callback
  self.callback, self.values = nil, nil
  if callback then callback(success, message, name, policy or self.policy) end
end

function ProtocolAccounts:cancel()
  self.callback = nil
  self:finish(false, '')
end

function ProtocolAccounts:onConnect()
  local ok = pcall(function()
    local msg = OutputMessage.create()
    msg:addU8(0x03) -- separate service identifier; ordinary login remains 0x01
    msg:addU8(1)
    msg:addU16(860)
    local offset = msg:getMessageSize()
    msg:addU8(0)
    self:generateXteaKey()
    local key = self:getXteaKey()
    for i = 1, 4 do msg:addU32(key[i]) end
    msg:addString('RHA1')
    for i = msg:getMessageSize() - offset + 1, g_crypt.rsaGetSize() do msg:addU8(math.random(0, 255)) end
    msg:encryptRsa()
    self:enableChecksum()
    self:send(msg)
    self:enableXteaEncryption()
    self:recv()
  end)
  if not ok then self:finish(false, tr('Could not establish an encrypted connection.')) end
end

function ProtocolAccounts:onRecv(msg)
  if self.completed then return end
  local ok = pcall(function()
    local opcode = msg:getU8()
    if opcode == 0x11 and not self.policy then
      local version, account, character, limit = msg:getU8(), msg:getU8(), msg:getU8(), msg:getU8()
      local world, town = msg:getString(), msg:getString()
      if version ~= 1 or account > 1 or character > 1 or limit < 1 or limit > 20 or #world > 64 or #town > 64 or not msg:eof() then error('reply') end
      self.policy = {account=account == 1, character=character == 1, limit=limit, world=world, town=town}
      if self.action == 0 then return self:finish(true, '', '', self.policy) end
      if (self.action == 1 and not self.policy.account) or (self.action == 2 and not self.policy.character) then
        return self:finish(false, tr('Creation is currently closed on this server.'))
      end
      local request, value = OutputMessage.create(), self.values
      request:addU8(self.action)
      request:addString(value.account)
      request:addString(value.password)
      request:addString(self.action == 1 and value.email or value.name)
      if self.action == 2 then request:addU8(value.sex) end
      self:send(request)
      self:recv()
    elseif opcode == 0x12 then
      local success, message, name = msg:getU8(), msg:getString(), msg:getString()
      if success > 1 or (success == 1 and not self.policy) or #message > 512 or #name > 64 or not msg:eof() then error('reply') end
      self:finish(success == 1, message, name)
    else error('reply') end
  end)
  if not ok then self:finish(false, tr('The account service returned an invalid reply.')) end
end

function ProtocolAccounts:onError()
  self:finish(false, tr('Account services could not be reached. Please try again later.'))
end
