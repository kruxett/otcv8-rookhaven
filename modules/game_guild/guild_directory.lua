-- Public discovery is separate from the player's management state.
GuildDirectory = {}
local D=GuildDirectory
local window,send,activate
local active=false
local sequence,latest,generation=0,0,0
local listPage,profilePage,profileId=1,1,nil
local debounce,emblemTimeout,emblemPumpEvent,viewTimeout
local targets,queue,cache={}, {}, {}
local pendingEmblem,stamp=nil,0
local settingUp=false
local statusNames={[0]='Not specified',[1]='Recruiting',[2]='Closed to recruitment'}
local classNames={reaver='Reaver',blademaster='Blademaster',earthshaker='Earthshaker',marksman='Marksman',arcanist='Arcanist',lifekeeper='Lifekeeper'}
local ascensions={[0]='Unawakened',[1]='Awakened',[2]='Ascendant',[3]='Ascended'}
local function W(id)return window and window:recursiveGetChildById(id)end
local function cancel(event)if event then removeEvent(event)end end
local function clearRequests()
  cancel(debounce);debounce=nil;cancel(emblemTimeout);emblemTimeout=nil
  cancel(emblemPumpEvent);emblemPumpEvent=nil
  cancel(viewTimeout);viewTimeout=nil
  pendingEmblem=nil;targets={};queue={};generation=generation+1
end
local function defaultCrest(widget)
  widget:setImageSource('/images/game/emblems/emblem_member')
  widget:setImageClip({x=0,y=0,width=0,height=0})
end
local function paint(widget,pixels)
  if widget and not widget:isDestroyed() and widget:setGuildEmblemPixels(pixels) then
    widget:setImageClip({x=0,y=0,width=32,height=32});return true
  end
  return false
end
local function nextRequest(action,fields)
  sequence=sequence+1;fields=fields or {};fields.requestId=sequence
  send(action,fields);return sequence
end
local pumpEmblems
pumpEmblems=function()
  if not active or pendingEmblem or emblemPumpEvent or not queue[1]then return end
  -- Stay below the existing five-per-second action budget on every page.
  emblemPumpEvent=scheduleEvent(function()
    emblemPumpEvent=nil
    local target=table.remove(queue,1)
    pendingEmblem={id=nextRequest('browse_emblem',{guildId=target.id}),guildId=target.id,revision=target.revision,generation=generation}
    emblemTimeout=scheduleEvent(function()emblemTimeout=nil;pendingEmblem=nil;pumpEmblems()end,3000)
  end,210)
end
local function crest(widget,entry)
  defaultCrest(widget)
  local meta=entry.emblem or {}
  if not meta.enabled or not meta.present then return end
  local saved=cache[entry.id]
  if saved and saved.revision==meta.revision then
    stamp=stamp+1;saved.stamp=stamp;paint(widget,saved.pixels);return
  end
  targets[entry.id]={widget=widget,revision=meta.revision}
  queue[#queue+1]={id=entry.id,revision=meta.revision}
end
local function remember(id,revision,pixels)
  stamp=stamp+1;cache[id]={revision=revision,pixels=pixels,stamp=stamp}
  local count,oldest,oldStamp=0,nil,math.huge
  for key,value in pairs(cache)do count=count+1;if value.stamp<oldStamp then oldest,oldStamp=key,value.stamp end end
  if count>64 then cache[oldest]=nil end
end
local function status(text)
  W('directoryStatus'):setText(text or '')
  W('directoryStatus'):setVisible(text~=nil and text~='')
end
local function paging(data)
  local value=data.paging
  if profileId then profilePage=value.page else listPage=value.page end
  local page=profileId and profilePage or listPage
  local unit=profileId and (value.total==1 and 'member' or 'members') or (value.total==1 and 'guild' or 'guilds')
  W('directoryPageLabel'):setText(string.format('Page %d / %d  -  %d %s',page,value.pages,value.total,unit))
  W('directoryPreviousBtn'):setEnabled(page>1)
  W('directoryNextBtn'):setEnabled(page<value.pages)
end
function D.isActive()return active end
function D.refresh()
  if not active or not window or not g_game.isOnline()then return end
  clearRequests()
  W('directoryPreviousBtn'):setEnabled(false);W('directoryNextBtn'):setEnabled(false)
  status('Loading...')
  local fields={page=profileId and profilePage or listPage}
  if profileId then
    fields.guildId=profileId;fields.search=W('directoryMemberSearch'):getText()
    fields.onlineOnly=W('directoryOnlineOnly'):isChecked()
    fields.sort=W('directoryMemberSort'):getCurrentOption().data
  else
    fields.search=W('directorySearch'):getText();fields.recruitingOnly=W('directoryRecruitingOnly'):isChecked()
    fields.sort=W('directorySort'):getCurrentOption().data
  end
  latest=nextRequest(profileId and 'guild_profile' or 'browse',fields)
  local expected=latest
  viewTimeout=scheduleEvent(function()
    viewTimeout=nil
    if active and latest==expected then status('The guild information did not arrive. Please try refreshing.')end
  end,8000)
end
local function changed()
  if settingUp or not active then return end
  if profileId then profilePage=1 else listPage=1 end
  cancel(debounce);debounce=scheduleEvent(function()debounce=nil;D.refresh()end,250)
end
function D.openProfile(id)
  if not active then return end
  profileId=id;profilePage=1;settingUp=true
  W('directoryMemberSearch'):setText('');W('directoryOnlineOnly'):setChecked(false);W('directoryMemberSort'):setCurrentOption('Rank')
  settingUp=false
  W('directoryFilters'):hide();W('directoryGuildList'):hide();W('directoryListBar'):hide()
  W('directoryProfile'):hide();W('directoryBackBtn'):show()
  W('guildNameLabel'):setText('Guild profile');W('guildSummaryLine'):setText('Loading guild information...')
  defaultCrest(W('guildCrest'));D.refresh()
end
function D.open()
  if not window then return end
  active=true;profileId=nil;activate(true)
  W('directoryProfile'):setVisible(false);W('directoryFilters'):show()
  W('directoryGuildList'):show();W('directoryMemberList'):hide()
  W('directoryBackBtn'):hide();W('directoryListBar'):hide();W('directoryMemberBar'):hide()
  W('guildNameLabel'):setText('Browse Guilds');W('guildSummaryLine'):setText('Find a guild and meet its members.')
  defaultCrest(W('guildCrest'));D.refresh()
end
function D.close()
  if not window then return end
  active=false;clearRequests();latest=0;activate(false)
end
function D.attach(widget,sender,onActivate)
  window,send,activate=widget,sender,onActivate
  active=false;listPage=1;profilePage=1;profileId=nil;settingUp=true
  for _,entry in ipairs({{'directorySort',{{'Name','name'},{'Members','members'},{'Online','online'}}},
    {'directoryMemberSort',{{'Rank','rank'},{'Name','name'},{'Level','level'},{'Online','online'}}}})do
    local box=W(entry[1]);box:clearOptions();for _,option in ipairs(entry[2])do box:addOption(option[1],option[2])end
    box.onOptionChange=changed
  end
  for _,id in ipairs({'directorySearch','directoryMemberSearch'})do W(id).onTextChange=changed end
  W('directoryRecruitingOnly').onCheckChange=changed;W('directoryOnlineOnly').onCheckChange=changed
  W('directoryBackBtn').onClick=D.open
  for _,entry in ipairs({{'directoryPreviousBtn',-1},{'directoryNextBtn',1}})do
    local step=entry[2]
    W(entry[1]).onClick=function()if profileId then profilePage=profilePage+step else listPage=listPage+step end;D.refresh()end
  end
  settingUp=false
end
function D.detach()
  clearRequests();active=false;window=nil;send=nil;activate=nil;cache={};latest=0
end
function D.handle(data)
  local kind=data.type
  if kind~='guild_directory' and kind~='guild_profile' and kind~='directory_emblem' and kind~='directory_error'then return false end
  if not active or not window then return true end
  if pendingEmblem and data.requestId==pendingEmblem.id and (kind=='directory_emblem' or kind=='directory_error')then
    local expected=pendingEmblem;pendingEmblem=nil;cancel(emblemTimeout);emblemTimeout=nil
    if kind=='directory_emblem' and expected.generation==generation and data.guildId==expected.guildId and
        data.revision==expected.revision and type(data.pixels)=='string' and #data.pixels==5464 then
      local target=targets[data.guildId]
      if target and target.revision==data.revision and paint(target.widget,data.pixels)then remember(data.guildId,data.revision,data.pixels)end
    end
    pumpEmblems();return true
  end
  if data.requestId~=latest then return true end
  cancel(viewTimeout);viewTimeout=nil
  if kind=='directory_error'then
    status(data.message or 'The guild could not be loaded. Please refresh.')
    W('directoryGuildList'):hide();W('directoryMemberList'):hide();W('directoryListBar'):hide();W('directoryMemberBar'):hide()
    W('directoryBackBtn'):setVisible(profileId~=nil);return true
  end
  status(nil);paging(data)
  if kind=='guild_directory' and not profileId then
    local panel=W('directoryGuildList');panel:destroyChildren();panel:show()
    W('directoryListBar'):hide();W('directoryMemberList'):hide();W('directoryMemberBar'):hide()
    for _,entry in ipairs(data.guilds or {})do
      local row=g_ui.createWidget('GuildDirectoryRow',panel)
      row:recursiveGetChildById('directoryGuildName'):setText(entry.name)
      row:recursiveGetChildById('directoryGuildCounts'):setText(string.format('%d %s  -  %d online',entry.memberCount,entry.memberCount==1 and 'member' or 'members',entry.onlineCount))
      row:recursiveGetChildById('directoryGuildDescription'):setText(entry.description~='' and entry.description or 'No public description.')
      row:recursiveGetChildById('directoryGuildStatus'):setText(statusNames[entry.recruitmentStatus] or statusNames[0])
      row:setTooltip(entry.name..'\n'..(entry.description or '')..'\nClick to view guild and members.')
      local id=entry.id;row.onClick=function()D.openProfile(id)end
      row.onKeyPress=function(_,key)if key==KeyEnter then D.openProfile(id);return true end return false end
      crest(row:recursiveGetChildById('directoryGuildCrest'),entry)
    end
    if #(data.guilds or {})==0 then status('No guilds match your search.')end
  elseif kind=='guild_profile' and profileId==data.info.id then
    local info=data.info
    W('directoryFilters'):hide();W('directoryGuildList'):hide();W('directoryListBar'):hide()
    W('directoryProfile'):show();W('directoryBackBtn'):show()
    W('guildNameLabel'):setText(info.name)
    W('guildSummaryLine'):setText(string.format('%d %s  -  %d online  -  %s',info.memberCount,info.memberCount==1 and 'member' or 'members',info.onlineCount,statusNames[info.recruitmentStatus] or statusNames[0]))
    crest(W('guildCrest'),info)
    W('directoryLeader'):setText('Leader: '..info.ownerName..(info.ownerOnline and '  (online)' or '  (offline)'))
    W('directoryDescription'):setText(info.description~='' and info.description or 'No public description.')
    local contact=W('directoryContactBtn')
    contact:setEnabled(info.ownerName~='' and info.ownerName:lower()~=g_game.getCharacterName():lower())
    contact:setTooltip('Open a private chat with '..info.ownerName..'. Messages can be delivered while the leader is online.')
    contact.onClick=function()
      -- Opening an existing chat tab sends no message or invitation.
      modules.game_console.addPrivateChannel(info.ownerName);modules.game_guild.hide()
    end
    local panel=W('directoryMemberList');panel:destroyChildren();panel:show();W('directoryMemberBar'):hide()
    for _,member in ipairs(data.members or {})do
      local row=g_ui.createWidget('GuildMemberRow',panel)
      row:recursiveGetChildById('memberActionsHint'):hide()
      local class=classNames[member.classId] or ascensions[member.vocation] or 'Unawakened'
      row:recursiveGetChildById('memberName'):setText(string.format('%s [Lv.%d, %s]',member.name,member.level,class))
      local rank=row:recursiveGetChildById('memberRank');rank:setText(member.rankName..(member.online and ' | Online' or ''));rank:setMarginRight(10)
      row:recursiveGetChildById('onlineIndicator'):setBackgroundColor(member.online and '#64b874' or '#555555')
      row:setTooltip(member.name..'\n'..class..' - '..(ascensions[member.vocation] or '')..'\n'..member.rankName..(member.online and ' | Online' or ' | Offline'))
    end
    if #(data.members or {})==0 then status('No members match your search.')end
  end
  pumpEmblems();return true
end
