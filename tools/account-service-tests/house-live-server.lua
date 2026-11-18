-- Installed only in the owned cold-copy runtime; never part of server data.
assert(configManager.getString(configKeys.SERVER_NAME)=='Rookhaven Accounts QA')
local action=TalkAction('/housewalletqa')
function action.onSay(player,words,param)
  if player:getName()~='House Wallet Hero' or player:getGroup():getId()~=1 or
     (player:getIp()~=0x0100007F and player:getIp()~=0x7F000001) then return false end
  if param~='commit_unknown_before' and param~='commit_unknown_after' then return false end
  player:setBankBalance(1000)
  assert(player:addItem(2148,25))
  assert(player:depositMoney(25),'ordinary bank deposit failed')
  local ok=Game.commitHouseBalances({{playerId=player:getGuid(),delta=-100}},function()
    return db.query('INSERT INTO owned_house_live_receipts(label) VALUES ('..db.escapeString(param)..')')
  end,param)
  assert(not ok,'uncertain live commit was reported successful')
  print('HOUSE_LIVE_OK '..param)
  return false
end
action:separator(' ');action:register()
