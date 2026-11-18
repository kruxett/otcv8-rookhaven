-- Injected only into the runner's disposable loopback database/runtime.
assert(configManager.getString(configKeys.SERVER_NAME)=='Rookhaven Accounts QA')
local testcase = '__CASE__'
local requestedTown=__HOUSE_CORE_TOWN__
local event=GlobalEvent('owned-house-core')
function event.onStartup()
  local seller,buyer=880001,880002
  assert(db.query("INSERT INTO accounts(id,name,password,email,premium_ends_at) VALUES (880001,'housecoreseller',SHA1('owned fixture'),'seller@example.invalid',UNIX_TIMESTAMP()+86400),(880002,'housecorebuyer',SHA1('owned fixture'),'buyer@example.invalid',UNIX_TIMESTAMP()+86400)"))
  assert(db.query("INSERT INTO players(id,name,account_id,group_id,level,vocation,health,healthmax,town_id,balance) VALUES (880001,'House Core Seller',880001,1,1,0,150,150,1,1000),(880002,'House Core Buyer',880002,1,1,0,150,150,1,1000)"))
  assert(db.query('UPDATE players SET level=20,vocation=3,health=400,healthmax=500,mana=120,manamax=200 WHERE id=880001'))
  assert(db.query("INSERT INTO accounts(id,name,password,email) VALUES (880003,'housecoreguest',SHA1('owned fixture'),'guest@example.invalid')"))
  assert(db.query("INSERT INTO players(id,name,account_id,group_id,level,vocation,health,healthmax,town_id,balance,soul) VALUES (880003,'House Core Guest',880003,1,1,0,100,150,1,1000,0)"))
  local ranks='1,'..string.rep('0,',27)..'0'
  assert(db.query("INSERT INTO player_passives(player_id,class_id,earned_points,respec_count,ranks) VALUES (880001,'arcanist',3,0,"..db.escapeString(ranks)..")"))
  assert(db.query('CREATE TABLE owned_house_core_receipts(id INT PRIMARY KEY,house_id INT NOT NULL DEFAULT 0) ENGINE=InnoDB'))
  local house
  for _,h in ipairs(Game.getHouses()) do if h:getOwnerGuid()==0 and #h:getBeds()>0 and (requestedTown==0 or h:getTown():getId()==requestedTown) then house=h;break end end
  assert(house,'no unowned house fixture')
  assert(db.query('INSERT INTO owned_house_core_receipts(id,house_id) VALUES (0,'..house:getId()..')'))
  local function receipt(id)return function()return db.query('INSERT INTO owned_house_core_receipts(id) VALUES ('..id..')')end end
  if testcase=='normal' then
    assert(Game.commitHouseBalances({{playerId=seller,delta=100},{playerId=buyer,delta=-100}},receipt(1)))
    assert(not Game.commitHouseBalances({{playerId=buyer,delta=-2000}},receipt(2)))
    assert(not Game.commitHouseBalances({{playerId=buyer,delta=-100}},function()assert(receipt(3)());return false end))
    assert(not Game.commitHouseBalances({{playerId=buyer,delta=-100},{playerId=buyer,delta=100}},receipt(4)))
    assert(not Game.commitHouseBalances({{playerId=buyer,delta=0/0}},receipt(5)))
  elseif testcase:find('balance_',1,true)==1 then
    local fault=testcase:sub(9)
    local ok=Game.commitHouseBalances({{playerId=seller,delta=100},{playerId=buyer,delta=-100}},receipt(1),fault)
    assert(not ok,'uncertain balance commit reported success')
    print('HOUSE_CORE_OK '..testcase)
    return true
  end
  assert(house:setOwnerGuid(seller))
  -- Use the real native attribute loader to establish an offline sleeping
  -- guest; waking after 30 minutes grants two soul points even without food.
  local function u32(n)local s='';for i=1,4 do s=s..string.char(n%256);n=math.floor(n/256)end;return s end
  local attributes=string.char(20)..u32(880003)..string.char(21)..u32(os.time()-1800)..string.char(0)
  local cursor=assert(db.storeQuery('SELECT '..db.escapeBlob(attributes,#attributes)..' AS attributes'))
  house:getBeds()[1]:loadAttributes(cursor);result.free(cursor)
  assert(house:getBeds()[1]:getAttribute(ITEM_ATTRIBUTE_DESCRIPTION):find('House Core Guest',1,true),'sleeping guest fixture not loaded')
  local tile=assert(house:getTiles()[1])
  assert(Game.createItem(2148,17,tile:getPosition()))
  local bag=assert(Game.createItem(1987,1,tile:getPosition()))
  assert(bag:addItem(2152,3))
  assert(house:save()) -- establish the old persisted house before fault injection
  local fault=testcase=='normal' and '' or testcase:sub(10)
  if testcase=='transfer_rollback' then fault='' end
  local ok=Game.completeHouseTransfer(house:getId(),buyer,function()
    assert(receipt(6)())
    assert(db.query('UPDATE players SET balance=balance+50 WHERE id='..seller))
    return testcase~='transfer_rollback'
  end,fault)
  if testcase=='normal' then assert(ok) else assert(not ok,'uncertain transfer reported success') end
  print('HOUSE_CORE_OK '..testcase)
  return true
end
event:register()
