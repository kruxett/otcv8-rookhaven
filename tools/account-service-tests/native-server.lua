-- Installed only in the runner's cold loopback fixture. No access/progression grants.
assert(configManager.getString(configKeys.SERVER_NAME)=='Rookhaven Accounts QA')
local function owned(p)
  return p:getName()=='Ui New Hero' and p:getGroup():getId()==1 and
    (p:getIp()==0x0100007F or p:getIp()==0x7F000001)
end
local function emit(p,label)
  local guild=p:getGuild()
  local r={label=label,level=p:getLevel(),vocation=p:getVocation():getId(),group=p:getGroup():getId(),
    torch=p:getItemCount(2050),knife=p:getItemCount(2382),robe=p:getItemCount(2651),bag=p:getItemCount(1987),apple=p:getItemCount(2674),
    guild=guild and guild:getName() or '',rank=p:getGuildLevel(),canInvite=GuildSystem.hasPermission(p,'canInvite'),canCreate=GuildSystem.canCreateGuild(p)}
  p:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE,'ACCOUNTS_NATIVE '..json.encode(r))
  print('ACCOUNTS_NATIVE '..json.encode(r))
end
local cmd=TalkAction('/accountsqa')
function cmd.onSay(p,words,param)
  if not owned(p) then return false end
  if param=='guildmaster' then
    local npc=assert(Npc('Crestwick'),'Crestwick not spawned')
    local pos=npc:getPosition()
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}})do
      local target=Position(pos.x+d[1],pos.y+d[2],pos.z);local tile=Tile(target)
      if tile and tile:getGround() and not tile:hasFlag(TILESTATE_BLOCKSOLID) and not tile:getTopCreature()then
        assert(p:teleportTo(target));emit(p,param);return false
      end
    end
    error('No adjacent Guildmaster tile')
  elseif param=='rest' then
    assert(p:teleportTo(p:getTown():getTemplePosition()))
    p:removeCondition(CONDITION_INFIGHT);emit(p,param)
  else emit(p,param) end
  return false
end
cmd:separator(' ');cmd:register()
