-- Installed only in the disposable loopback photograph runtime. Never ship.
assert(configManager.getString(configKeys.SERVER_NAME)=='Rookhaven Accounts QA')
local catalogue,lookup={},{}
local startup=GlobalEvent('OwnedHousePhotoCatalogue')
function startup.onStartup()
  for _,house in ipairs(Game.getHouses())do
    local floors={}
    for _,tile in ipairs(house:getTiles())do
      local p=tile:getPosition();local f=floors[p.z]
      if not f then f={z=p.z,minx=p.x,maxx=p.x,miny=p.y,maxy=p.y,tiles={}};floors[p.z]=f end
      f.minx=math.min(f.minx,p.x);f.maxx=math.max(f.maxx,p.x);f.miny=math.min(f.miny,p.y);f.maxy=math.max(f.maxy,p.y)
      f.tiles[#f.tiles+1]={x=p.x,y=p.y,z=p.z}
    end
    local h={id=house:getId(),name=house:getName(),entry=house:getExitPosition(),floors={}}
    h.entry={x=h.entry.x,y=h.entry.y,z=h.entry.z}
    for _,floor in pairs(floors)do h.floors[#h.floors+1]=floor end
    table.sort(h.floors,function(a,b)return a.z<b.z end)
    catalogue[#catalogue+1]=h;lookup[h.id]=h
    -- Temporary access only in this owned cold copy, without changing ownership.
    house:setAccessList(GUEST_LIST,'Home Buyer')
  end
  table.sort(catalogue,function(a,b)return a.id<b.id end)
  local file=assert(io.open('house-photo-catalogue.json','wb'));file:write(json.encode(catalogue));file:close()
  return true
end
startup:type('startup');startup:register()
local command=TalkAction('/housephoto')
function command.onSay(player,words,param)
  if player:getName()~='Home Buyer' or player:getGroup():getId()~=1 or not(player:getIp()==0x0100007F or player:getIp()==0x7F000001)then return false end
  local id,z=param:match('^(%d+) (%d+)$');id,z=tonumber(id),tonumber(z)
  local house=assert(lookup[id]);local f
  for _,floor in ipairs(house.floors)do if floor.z==z then f=floor end end
  assert(f,'unknown house floor')
  local cx,cy=(f.minx+f.maxx)/2,(f.miny+f.maxy)/2
  local points={};for _,point in ipairs(f.tiles)do points[#points+1]=point end
  table.sort(points,function(a,b)
    local da,db=(a.x-cx)^2+(a.y-cy)^2,(b.x-cx)^2+(b.y-cy)^2
    return da==db and (a.y==b.y and a.x<b.x or a.y<b.y)or da<db
  end)
  local placed=false
  for _,point in ipairs(points)do
    local tile=Tile(point)
    if tile and tile:isWalkable() and tile:queryAdd(player)==RETURNVALUE_NOERROR and player:teleportTo(point)then
      local p=player:getPosition()
      if p.z==z then placed=true;break end
    end
  end
  assert(placed,'no accessible photograph tile: '..id..' floor '..z)
  local p=player:getPosition()
  player:sendExtendedOpcode(119,json.encode({id=id,z=z,position={x=p.x,y=p.y,z=p.z}}))
  return false
end
command:separator(' ');command:register()
