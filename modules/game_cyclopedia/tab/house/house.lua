local UI = nil

-- Native market adapter for the stock house views. Forms retain their original
-- OTUI panels; only their data, validation and server calls are connected here.
local form,confirmBox,inputBox,popup
local mode='houses'
local panelIds={'ListBase','bidArea','moveOutArea','transferArea','cancelHouseTransferArea','acceptTransferHouse','rejectTransferHouse'}
local function money(v)
  return tostring(v or 0):reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,','')
end
local function timeText(value)
  return value and value>0 and os.date('%d %b, %H:%M',value) or 'Not due'
end
local function quoteFor(d)return {houseId=d.id,revision=d.revision}end
local function selectedData()return UI and HouseMarketUI.getData()end
function Cyclopedia.closeHouseDialogs()
  for _,widget in pairs({confirmBox,inputBox,popup})do if widget and not widget:isDestroyed() then widget:destroy()end end
  confirmBox,inputBox,popup=nil,nil,nil
end
function Cyclopedia.setHouseStatus(text,failed)
  if not UI then return end
  UI.houseStatus:setText(text or '')
  UI.houseStatus:setTooltip(text or '')
  UI.houseStatus:setColor(failed and '#e89999' or '#C0C0C0')
end
function Cyclopedia.showHouseError(text)
  if UI then confirmBox=displayErrorBox(tr('Houses'),text or 'The house request was refused.')end
end
local function showPanel(id)
  if not UI then return end
  for _,name in ipairs(panelIds)do UI[name]:setVisible(name==id)end
end
function Cyclopedia.showHouseList()
  local previous=mode
  form=nil;mode='houses';showPanel('ListBase')
  if UI and previous~='houses' then
    Cyclopedia.reloadHouseList(true)
    local d=selectedData();local row=d and UI.ListBase.AuctionList:getChildById(tostring(d.id))
    if row then Cyclopedia.selectHouse(row,true,d)end
  end
end
function Cyclopedia.isHouseFormOpen()return form~=nil or mode~='houses'end
function Cyclopedia.setHouseBusy(value)
  if not UI then return end
  UI.TopBase:setEnabled(not value)
  UI.ListBase:setEnabled(not value)
  UI.LateralBase:setEnabled(not value)
  UI.houseRefresh:setEnabled(not value)
  UI.housePrevious:setEnabled(not value and (Cyclopedia.House.page or 1)>1)
  UI.houseNext:setEnabled(not value and (Cyclopedia.House.page or 1)*15<(Cyclopedia.House.total or 0))
  for _,name in ipairs(panelIds)do
    local panel=UI[name]
    for _,id in ipairs({'bid','move','transfer','cancel'})do
      local button=panel:getChildById(id);if button then button:setEnabled(not value)end
    end
  end
  if not value and form and form.validate then form.validate()end
end
local function fill(panel,d)
  panel.name:setText(d.name);panel.size:setText(d.size..' sqm');panel.beds:setText(tostring(d.beds));panel.rent:setText(money(d.rent))
  if panel:getChildById('paid')then panel.paid:setText(d.rentPeriod=='never' and 'Rent disabled' or timeText(d.paidUntil))end
end
local function showForm(id,title)
  local d=selectedData();if not d or HouseMarketUI.isBusy()then return end
  Cyclopedia.closeHouseDialogs();showPanel(id)
  local panel=UI[id];panel:setText(title);fill(panel,d);Cyclopedia.setHouseStatus('')
  panel.cancel.onClick=Cyclopedia.showHouseList
  form={panel=panel,data=d,quote=quoteFor(d)}
  return panel,d,form
end
local function integer(field,min,max)
  local text=field:getText();local n=tonumber(text)
  return text:match('^%d+$') and n and n>=min and n<=(max or 2147483647) and n or nil
end
local function confirmAction(text,action,fields,quote)
  if HouseMarketUI.isBusy()then return end
  local function cancel()local box=confirmBox;confirmBox=nil;if box then box:destroy()end end
  local function yes()cancel();HouseMarketUI.action(action,fields,quote)end
  confirmBox=displayGeneralBox(tr('Confirm House Action'),text,{{text=tr('Confirm'),callback=yes},{text=tr('Cancel'),callback=cancel}},yes,cancel)
end
local function metadata(d)
  local player=g_game.getLocalPlayer()
  return {id=d.id,name=d.name,description='',rent=d.rent,beds=d.beds,sqm=d.size,gh=false,shop=false,visible=true,
    townName=d.town,owner=d.ownerName~='' and d.ownerName or 'Unowned',rented=d.owner>0,
    state=(d.pending or d.pendingTransfer or d.incomingTransfer) and 3 or (d.owner==0 or (d.endsAt or 0)>0) and 0 or 2,
    hasBid=(d.bid or 0)>0,bidEnd=d.endsAt or 0,hightestBid=d.bid or 0,bidName=d.highestBidderName or 'Loading...',
    isYourOwner=d.isOwner==true or (player and d.ownerName:lower()==player:getName():lower()),
    isYourBid=d.currentLeader==true,bidHolderLimit=d.myMaximum or 0,paidUntil=d.paidUntil or 0,
    incomingTransfer=d.incomingTransfer==true,isTransferOwner=d.listing and d.listing.type=='private' and d.listing.canBuy==true,
    inTransfer=d.pending~=nil or (d.listing and d.listing.type=='private') or d.pendingTransfer==true,position=d.position}
end
function Cyclopedia.applyNativeHouseList(reply)
  if not UI then return end
  Cyclopedia.showHouseList()
  Cyclopedia.House.page=reply.page;Cyclopedia.House.total=reply.total
  Cyclopedia.House.towns=reply.towns
  Cyclopedia.House.Data={}
  for _,d in ipairs(reply.houses)do Cyclopedia.House.Data[#Cyclopedia.House.Data+1]=metadata(d)end
  Cyclopedia.updateHouseCityOptions(reply.towns)
  UI.housePage:setText(reply.page..' / '..math.max(1,math.ceil(reply.total/reply.pageSize)))
  UI.TopBase.GuildhallsCheck:setEnabled(reply.guildhalls==true)
  UI.TopBase.GuildhallsCheck:setTooltip(reply.guildhalls and '' or 'There are no guildhalls in this world.')
  local gold=controllerCyclopedia.ui.GoldBase
  gold.Value:setText(money(reply.bank));gold:setTooltip('Gold available in your bank')
  Cyclopedia.setHouseBusy(false)
  Cyclopedia.reloadHouseList()
end
local function preview(d)
  local frame=UI.LateralBase.MapViewbase
  local path=string.format('/game_cyclopedia/images/houses/rookhaven/previews/%s.png',d.id)
  if not g_resources.fileExists(path)then path=string.format('/game_cyclopedia/images/houses/%s.png',d.id)end
  frame.reload:hide()
  local available=g_resources.fileExists(path)
  frame.houseImage:setVisible(available);frame.noHouse:setVisible(not available)
  if available then frame.houseImage:setImageSource(path)
  else
    local p=d.position
    frame.noHouse.previewMessage:setText('No preview available\n'..d.townName..(p and ('\n'..p.x..', '..p.y..', '..p.z)or ''))
  end
end
function Cyclopedia.clearHouseActions()
  if not UI then return end
  for _,id in ipairs({'bidButton','transferButton','moveOutButton','cancelTransfer','acceptTransfer','rejectTransfer','houseMoreButton'})do
    local widget=UI.LateralBase:getChildById(id);if widget then widget:destroy()end
  end
end
local function leftButton(id,title,callback,width,allowed,why)
  local button=g_ui.createWidget('Button',UI.LateralBase)
  button:setId(id);button:setText(title);button:setSize({width=width or 70,height=20})
  button:addAnchor(AnchorBottom,'parent',AnchorBottom);button:setMarginBottom(7)
  local count=UI.LateralBase._actionOffset or 7
  button:addAnchor(AnchorLeft,'parent',AnchorLeft);button:setMarginLeft(count)
  UI.LateralBase._actionOffset=count+(width or 70)+4
  button:setEnabled(allowed~=false);button:setTooltip(why or '');button.onClick=callback
end
function Cyclopedia.openHouseAmount(kind)
  local panel,d,current=showForm('bidArea',kind=='bid' and 'Place Your Bid' or kind=='sale' and 'List House for Sale' or 'Make Buy Offer')
  if not panel then return end
  local old=panel:getChildById('bidArea');if old then old:destroy()end
  local context=panel:getChildById('nativeAuctionContext')
  if not context then
    context=g_ui.createWidget('Label',panel);context:setId('nativeAuctionContext');context:setTextWrap(true)
    context:addAnchor(AnchorTop,'rent',AnchorBottom);context:addAnchor(AnchorLeft,'parent',AnchorLeft);context:addAnchor(AnchorRight,'parent',AnchorRight)
    context:setMarginTop(23);context:setHeight(44);context:setColor('#C0C0C0')
  end
  panel:recursiveGetChildById('sectionTitle'):setText(kind=='bid' and 'Auction Information' or 'Sale Information')
  context:setText(kind=='bid' and ('Current bid: '..money(d.bid)..' gold | Next: '..money(d.minimum)..' gold\nEnds: '..(d.endsAt>0 and timeText(d.endsAt)or '48 hours after the first bid')) or 'Ownership and payment complete at server restart.\nBelongings move to the current owner\'s depot.')
  local area=g_ui.createWidget('HouseBidArea',panel);area:setId('bidArea')
  area:addAnchor(AnchorTop,'nativeAuctionContext',AnchorBottom);area:addAnchor(AnchorLeft,'parent',AnchorLeft);area:addAnchor(AnchorRight,'parent',AnchorRight);area:setMarginTop(5)
  area.automatic:setVisible(kind=='bid');area.automatic:setChecked(true)
  area.textEdit:setMaxLength(10);area.textEdit:setText(tostring(kind=='bid' and d.minimum or math.max(1,d.rent)))
  local function validate()
    local value=integer(area.textEdit,1)
    panel.bid:setEnabled(value~=nil and not HouseMarketUI.isBusy())
    area.amountLabel:setText(kind=='bid' and (area.automatic:isChecked()and 'Set bid limit:'or 'Bid in gold:')or kind=='sale' and 'Asking price:'or 'Offer in gold:')
    area.information:setText(kind=='offer' and 'No gold is reserved until the owner accepts. You must still have sufficient funds when it is accepted.'or kind=='sale' and 'The buyer reserves this price on purchase. Your payment and the ownership change complete at server restart.'or area.automatic:isChecked()and 'Your full maximum is reserved now. The price rises only as needed. Outbid gold returns to your bank; a win transfers at server restart.'or 'Your full bid is reserved now. Outbid gold returns to your bank; a win transfers at server restart.')
    if not value then Cyclopedia.setHouseStatus('Enter a whole gold amount from 1 to 2147483647.',true)end
  end
  current.validate=validate;area.textEdit.onTextChange=validate;area.automatic.onCheckChange=validate
  panel.bid:setText(kind=='bid' and 'Bid' or kind=='sale' and 'List' or 'Offer')
  panel.bid.onClick=function()
    local value=integer(area.textEdit,1);if not value then validate();return end
    if kind=='bid' then
      local automatic=area.automatic:isChecked()
      confirmAction(d.name..'\n'..(automatic and 'Maximum bid: 'or 'Bid: ')..money(value)..' gold.\nThis gold is reserved now. A winning house transfers at server restart.', 'bid',{amount=value,automatic=automatic},current.quote)
    elseif kind=='sale' then
      confirmAction(d.name..'\nList this house for '..money(value)..' gold?\nOwnership and seller payment complete at server restart.','listSale',{saleType='direct',amount=value},current.quote)
    else confirmAction(d.name..'\nOffer '..money(value)..' gold?\nGold is charged only if the owner accepts and your funds remain available.','offer',{amount=value},current.quote)end
  end
  validate();area.textEdit:focus()
end
function Cyclopedia.openHouseTransfer(kind)
  local panel,d,current=showForm('transferArea',kind=='auction' and 'Start Owner Auction' or 'Configure House Transfer')
  if not panel then return end
  panel.targetLabel:setText(kind=='auction' and 'Hours:'or 'New Owner:')
  panel.priceLabel:setText(kind=='auction' and 'Minimum bid:'or 'Transfer Price:')
  panel.owner:setMaxLength(kind=='auction' and 3 or 29)
  panel.owner:setText(kind=='auction' and tostring(math.min(48,d.maxOwnerHours))or '')
  panel.price:setMaxLength(10);panel.price:setText(kind=='auction' and tostring(math.max(1,d.rent))or '0')
  panel.scheduleValue:setText(kind=='auction' and 'After the auction, at restart' or 'After acceptance, at restart')
  panel.information:setText(kind=='auction' and ('Choose 1-'..d.maxOwnerHours..' hours. An auction with bids cannot be cancelled. The winner\'s payment and house transfer complete at server restart.')or 'The named recipient must accept. A price of 0 is a gift. Gold is reserved on acceptance. Ownership and seller payment complete at server restart. Your belongings move to your depot.')
  local function validate()
    local amount=integer(panel.price,kind=='auction' and 1 or 0)
    local target=panel.owner:getText()
    local validTarget=kind=='auction' and integer(panel.owner,1,d.maxOwnerHours)~=nil or kind~='auction' and #target>=3 and #target<=29
    panel.transfer:setEnabled(amount~=nil and validTarget and not HouseMarketUI.isBusy())
  end
  current.validate=validate;panel.owner.onTextChange=validate;panel.price.onTextChange=validate
  panel.transfer:setText(kind=='auction' and 'Start auction'or 'Transfer')
  panel.transfer.onClick=function()
    local amount=integer(panel.price,kind=='auction' and 1 or 0);if not amount then validate();return end
    local target=panel.owner:getText()
    if kind=='auction' then
      local hours=integer(panel.owner,1,d.maxOwnerHours);if not hours then validate();return end
      confirmAction(d.name..'\nAuction minimum: '..money(amount)..' gold. Duration: '..hours..' hours.\nBids lock the auction; ownership transfers at restart after it ends.','listSale',{saleType='auction',amount=amount,durationHours=hours},current.quote)
    elseif #target>=3 and #target<=29 then
      confirmAction(d.name..'\nOffer a private transfer to '..target..' for '..money(amount)..' gold?\nThey must accept. Belongings move to your depot at the restart handover.','listSale',{saleType='private',amount=amount,target=target},current.quote)
    end
  end
  validate();panel.owner:focus()
end
function Cyclopedia.openHouseMove()
  local panel,d,current=showForm('moveOutArea','Move Out of House');if not panel then return end
  panel.confirmation:setText('');panel.confirmation:setMaxLength(5)
  local function validate()panel.move:setEnabled(panel.confirmation:getText()=='LEAVE' and not HouseMarketUI.isBusy())end
  current.validate=validate;panel.confirmation.onTextChange=validate
  panel.move.onClick=function()
    if panel.confirmation:getText()~='LEAVE'then validate();return end
    confirmAction(d.name..'\nLeave this house at server restart?\nBelongings move to your depot. You can cancel the request before then.','leave',{confirmation='LEAVE'},current.quote)
  end
  validate();panel.confirmation:focus()
end
function Cyclopedia.openHouseAgreement(kind,offer)
  local panelId=(kind=='reject' or kind=='declineOffer')and 'rejectTransferHouse' or (kind=='cancel' or kind=='cancelOffer' or kind=='cancelLeave')and 'cancelHouseTransferArea' or 'acceptTransferHouse'
  local title=({buy='Buy House',accept='Accept House Transfer',reject='Reject House Transfer',cancel='Cancel Listing',acceptOffer='Accept Buy Offer',declineOffer='Decline Buy Offer',cancelOffer='Withdraw Buy Offer',cancelLeave='Cancel Move Out'})[kind]
  local panel,d,current=showForm(panelId,title);if not panel then return end
  local price=offer and offer.price or d.listing and d.listing.price or 0
  local name=offer and offer.name or d.listing and d.listing.recipientName or g_game.getLocalPlayer():getName()
  panel.owner:setText(name or 'Open listing');panel.transferDate:setText('At next server restart');panel.transferPrice:setText(money(price))
  local action=({buy='buy',accept='buy',reject='rejectTransfer',cancel='cancelListing',acceptOffer='acceptOffer',declineOffer='declineOffer',cancelOffer='cancelOffer',cancelLeave='cancelLeave'})[kind]
  local text=(kind=='buy' or kind=='accept' or kind=='acceptOffer')
    and ('Gold is reserved when accepted. Ownership and seller payment complete at server restart. The current owner\'s belongings move to their depot.')
    or 'Confirm this cancellation or decline. No purchase payment is taken by this action.'
  if kind=='cancelLeave'then text='Cancel the move-out request? You will keep your house.'end
  panel.information:setText(text);panel.transfer:setText(({buy='Buy',accept='Accept',reject='Reject',cancel='Cancel listing',acceptOffer='Accept',declineOffer='Decline',cancelOffer='Withdraw',cancelLeave='Keep house'})[kind])
  panel.transfer:setWidth(90)
  panel.transfer.onClick=function()
    confirmAction(d.name..'\n'..title..(price>0 and (' - '..money(price)..' gold')or '')..'?\n'..((kind=='buy' or kind=='accept' or kind=='acceptOffer') and 'Ownership transfers at server restart.'or 'Confirm the selected action.'),action,offer and {offerId=offer.id}or {},current.quote)
  end
end
function Cyclopedia.showHouseOffers()
  local d=selectedData();if not d then return end
  Cyclopedia.showHouseList();mode='offers';UI.ListBase.AuctionList:destroyChildren()
  for _,value in ipairs(d.offers)do
    local offer=value
    local row=g_ui.createWidget('HouseMarketEntry',UI.ListBase.AuctionList)
    row:setText(offer.name);row.size:setText('Offer: '..money(offer.price)..' gold');row.status:setText(d.isOwner and 'Select to accept or decline' or 'Select to withdraw your offer')
    row.onClick=function()
      popup=g_ui.createWidget('PopupMenu')
      if d.isOwner then popup:addOption('Accept offer',function()Cyclopedia.openHouseAgreement('acceptOffer',offer)end);popup:addOption('Decline offer',function()Cyclopedia.openHouseAgreement('declineOffer',offer)end)
      else popup:addOption('Withdraw offer',function()Cyclopedia.openHouseAgreement('cancelOffer',offer)end)end
      popup:display(g_window.getMousePosition())
    end
  end
  if #d.offers==0 then Cyclopedia.setHouseStatus('No active buy offers for this house.')else Cyclopedia.setHouseStatus('Offers reserve gold only when the owner accepts.')end
end
function Cyclopedia.showHouseHistory()
  local d=selectedData();if not d then return end
  Cyclopedia.showHouseList();mode='history';UI.ListBase.AuctionList:destroyChildren()
  for _,entry in ipairs(d.history)do
    local row=g_ui.createWidget('HouseMarketEntry',UI.ListBase.AuctionList)
    row:setText(entry.name);row.size:setText(money(entry.bid_amount)..' gold');row.status:setText(timeText(entry.bid_timestamp));row.onClick=function()end
  end
  Cyclopedia.setHouseStatus(#d.history==0 and 'No bids recorded for the current auction.' or 'Recent bids for this auction.')
end
function Cyclopedia.showHouseActions()
  local d=selectedData();if not d or HouseMarketUI.isBusy()then return end
  popup=g_ui.createWidget('PopupMenu')
  if d.isOwner and not d.pending then
    if not d.listing then
      popup:addOption('List for sale',function()Cyclopedia.openHouseAmount('sale')end)
      popup:addOption('Start auction',function()Cyclopedia.openHouseTransfer('auction')end)
    elseif d.bid==0 then popup:addOption('Cancel listing',function()Cyclopedia.openHouseAgreement('cancel')end)end
  end
  if not d.isOwner and not d.ownedByAccount and d.canAcquire and d.owner>0 and not d.pending and (not d.listing or d.listing.type=='direct')then popup:addOption('Make buy offer',function()Cyclopedia.openHouseAmount('offer')end)end
  if d.autoEnabled and not d.pending then
    local quote=quoteFor(d)
    popup:addOption('Disable auto-bid',function()confirmAction(d.name..'\nDisable automatic bidding? The current winning bid remains reserved.','cancelAuto',{},quote)end)
  end
  popup:addOption('Buy offers',Cyclopedia.showHouseOffers);popup:addOption('Bid history',Cyclopedia.showHouseHistory)
  if d.canEditGuests then
    popup:addSeparator();popup:addOption('Edit guests',function()HouseMarketUI.action('access',{list='guests'})end)
    popup:addOption('Remove visitor',function()
      local quote=quoteFor(d)
      inputBox=UIInputBox.create('Remove House Visitor',function(name)HouseMarketUI.action('kick',{target=name},quote)end)
      inputBox:addLineEdit('Character name',nil,29);inputBox:display('Remove','Cancel')
    end)
  end
  if d.canEditSubowners then
    popup:addOption('Edit subowners',function()HouseMarketUI.action('access',{list='subowners'})end)
    for _,id in ipairs(d.doors)do local door=id;popup:addOption('Edit door '..door,function()HouseMarketUI.action('access',{list='door',doorId=door})end)end
  end
  popup:addSeparator();popup:addOption('Back to houses',function()Cyclopedia.showHouseList();HouseMarketUI.list()end)
  popup:display(g_window.getMousePosition())
end
function Cyclopedia.applyNativeHouseDetail(d,afterAction)
  if not UI then return end
  local previousMode=mode
  local mapped=metadata(d)
  for i,row in ipairs(Cyclopedia.House.Data or {})do if row.id==d.id then Cyclopedia.House.Data[i]=mapped end end
  if afterAction then Cyclopedia.showHouseList()end
  local row=UI.ListBase.AuctionList:getChildById(tostring(d.id))
  if row and mode=='houses'then row.data=mapped
  else row={data=mapped,getId=function()return tostring(d.id)end}end
  Cyclopedia.House.lastSelectedHouse=row;Cyclopedia.House.selectedId=d.id
  Cyclopedia.selectHouse(row,true,d)
  controllerCyclopedia.ui.GoldBase.Value:setText(money(d.bank))
  if not afterAction and previousMode=='offers'then Cyclopedia.showHouseOffers()
  elseif not afterAction and previousMode=='history'then Cyclopedia.showHouseHistory()end
end


local function setHouseLabelText(widget, text)
    if not widget then
        return
    end

    if text == nil then
        text = ""
    else
        text = tostring(text)
    end

    if widget.setColoredText then
        local ok = pcall(function()
            widget:setColoredText(text)
        end)
        if ok then
            return
        end
    end

    local plain = text:gsub("{%s*([^,{}]+)%s*,%s*#%x+%s*}", "%1")
    plain = plain:gsub("[{}]", "")
    widget:setText(plain)
end

function showHouse()
    UI=g_ui.loadUI('house',contentContainer);UI:show()
    local view=UI
    UI.onDestroy=function()
      HouseMarketUI.detach(view)
      if UI==view then Cyclopedia.closeHouseDialogs();UI=nil;form=nil end
    end
    HouseMarketUI.attach(UI)
    Cyclopedia.House.lastSelectedHouse=nil;Cyclopedia.House.selectedId=nil
    Cyclopedia.House.Data={};Cyclopedia.House.page=1;Cyclopedia.House.total=0
    mode='houses';form=nil
    local f=HouseMarketUI.getFilters()
    UI.TopBase.StatesOption:clearOptions()
    for i,title in ipairs({'All States','Auctioned','Rented','For Sale'})do UI.TopBase.StatesOption:addOption(title,i-1)end
    UI.TopBase.StatesOption:setCurrentOptionByData(f.status)
    UI.TopBase.StatesOption.onOptionChange=Cyclopedia.houseChangeState
    UI.TopBase.SortOption:clearOptions()
    for _,item in ipairs({{'Sort by name','name'},{'Sort by size','size'},{'Sort by rent','rent'},{'Sort by bid','bid'},{'Sort by auction end','endsAt'}})do UI.TopBase.SortOption:addOption(item[1],item[2])end
    UI.TopBase.SortOption:setCurrentOptionByData(f.sort)
    UI.TopBase.SortOption.onOptionChange=Cyclopedia.houseSort
    UI.TopBase.HousesCheck:setChecked(true);UI.TopBase.GuildhallsCheck:setChecked(false)
    UI.TopBase.GuildhallsCheck:setEnabled(false)
    Cyclopedia.updateHouseCityOptions({})
    for _,id in ipairs({'CharmsBase','CharmsBase1410','BestiaryTrackerButton','TaskTrackerButton'})do
      local child=controllerCyclopedia.ui:getChildById(id);if child then child:hide()end
    end
    controllerCyclopedia.ui.GoldBase:show()
    Cyclopedia.showHouseList()
    HouseMarketUI.list()
end

Cyclopedia.House = {}
Cyclopedia.StateList = {
    { Title = "All States" },
    { Title = "Auctioned" },
    { Title = "Rented" }
}

-- Optional explicit fallback list when dynamic town data is unavailable.
-- Example:
-- _G.CyclopediaHouseTownFallback = { "Rookhaven", "Asterfield", "..." }
Cyclopedia.CityList = {
    [0] = { Title = "Own Houses" }
}

function Cyclopedia.updateHouseCityOptions(towns)
  if not UI then return end
  local options=UI.TopBase.CityOption;options.onOptionChange=nil;options:clearOptions()
  options:addOption('All Towns','all');options:addOption('Own Houses','mine');options:addOption('My Buy Offers','offers')
  for _,town in ipairs(towns or {})do options:addOption(town.name,town.id)end
  local f=HouseMarketUI.getFilters()
  options:setCurrentOptionByData(f.filter=='mine' and 'mine' or f.filter=='offers' and 'offers' or f.townId>0 and f.townId or 'all')
  options.onOptionChange=Cyclopedia.selectTown
end

Cyclopedia.SortList = {
    { Title = "Sort by name" },
    { Title = "Sort by size" },
    { Title = "Sort by rent" },
    { Title = "Sort by bid" },
    { Title = "Sort by auction end" }
}

local function resetButtons()
    if UI.LateralBase:getChildById("bidButton") then
        UI.LateralBase:getChildById("bidButton"):destroy()
    end

    if UI.LateralBase:getChildById("transferButton") then
        UI.LateralBase:getChildById("transferButton"):destroy()
    end

    if UI.LateralBase:getChildById("moveOutButton") then
        UI.LateralBase:getChildById("moveOutButton"):destroy()
    end

    if UI.LateralBase:getChildById("cancelTransfer") then
        UI.LateralBase:getChildById("cancelTransfer"):destroy()
    end

    if UI.LateralBase:getChildById("acceptTransfer") then
        UI.LateralBase:getChildById("acceptTransfer"):destroy()
    end

    if UI.LateralBase:getChildById("rejectTransfer") then
        UI.LateralBase:getChildById("rejectTransfer"):destroy()
    end
end

local function resetSelectedInfo()
    UI.LateralBase.yourLimitBidGold:setVisible(false)
    UI.LateralBase.yourLimitBid:setVisible(false)
    UI.LateralBase.yourLimitLabel:setVisible(false)
    UI.LateralBase.highestBid:setVisible(false)
    UI.LateralBase.highestBidGold:setVisible(false)
    UI.LateralBase.subAuctionLabel:setVisible(false)
    UI.LateralBase.subAuctionText:setVisible(false)
    UI.LateralBase.transferLabel:setVisible(false)
    UI.LateralBase.transferValue:setVisible(false)
    UI.LateralBase.transferGold:setVisible(false)
end

function Cyclopedia.houseChangeState(widget)
  Cyclopedia.showHouseList();HouseMarketUI.list({page=1,status=widget:getCurrentOption().data})
end

function Cyclopedia.houseMessage(houseId, type, message)
    local confirmWindow
    local function yesCallback()
        if confirmWindow then
            confirmWindow:destroy()
            confirmWindow = nil
            Cyclopedia.Toggle(true, false, 5)
        end
    end

    if type == 1 then
        if message == 0 then
            if not confirmWindow then
                confirmWindow = displayGeneralBox(tr("Summary"), tr(
                    "Your bid was successfull. You are currently holding the highest bid."), {
                    {
                        text = tr("Ok"),
                        callback = yesCallback
                    },
                    anchor = AnchorHorizontalCenter
                }, yesCallback)

                UI.ListBase:setVisible(true)
                UI.bidArea:setVisible(false)
                Cyclopedia.Toggle(true, false)
            end
        elseif message == 17 then
            confirmWindow = displayGeneralBox(tr("Summary"), tr(
                "Bid failed.\nYour character's bank acocunt balance is too low to pay the bid and the rent for the first month."),
                {
                    {
                        text = tr("Ok"),
                        callback = yesCallback
                    },
                    anchor = AnchorHorizontalCenter
                }, yesCallback)

            UI.ListBase:setVisible(true)
            UI.bidArea:setVisible(false)
            Cyclopedia.Toggle(true, false)
        end
    elseif type == 2 then
        if message == 0 then
            confirmWindow = displayGeneralBox(tr("Summary"), tr("You have sucessfully iniated your move out."), {
                {
                    text = tr("Ok"),
                    callback = yesCallback
                },
                anchor = AnchorHorizontalCenter
            }, yesCallback)

            UI.moveOutArea:setVisible(false)
            UI.ListBase:setVisible(true)
            Cyclopedia.Toggle(true, false)
        end
    elseif type == 3 then
        if message == 0 then
            confirmWindow = displayGeneralBox(tr("Summary"),
                tr("You have sucessfully initiated the transfer of your house."), {
                    {
                        text = tr("Ok"),
                        callback = yesCallback
                    },
                    anchor = AnchorHorizontalCenter
                }, yesCallback)

            UI.transferArea:setVisible(false)
            UI.ListBase:setVisible(true)
            Cyclopedia.Toggle(true, false)
        elseif message == 4 then
            confirmWindow = displayGeneralBox(tr("Summary"), tr(
                "Setting up a house transfer failed.\nA character with this name does not exist."), {
                {
                    text = tr("Ok"),
                    callback = yesCallback
                },
                anchor = AnchorHorizontalCenter
            }, yesCallback)

            UI.transferArea:setVisible(false)
            UI.ListBase:setVisible(true)
            Cyclopedia.Toggle(true, false)
        end
    elseif type == 5 then
        if message == 0 then
            confirmWindow = displayGeneralBox(tr("Summary"), tr(
                "You have sucessfully cancelled the transfer. You will keep the house."), {
                {
                    text = tr("Ok"),
                    callback = yesCallback
                },
                anchor = AnchorHorizontalCenter
            }, yesCallback)

            UI.cancelHouseTransferArea:setVisible(false)
            UI.ListBase:setVisible(true)
            Cyclopedia.Toggle(true, false)
        end
    elseif type == 6 then
        if message == 0 then
            confirmWindow = displayGeneralBox(tr("Summary"), tr("You have sucessfully accepted the transfer."), {
                {
                    text = tr("Ok"),
                    callback = yesCallback
                },
                anchor = AnchorHorizontalCenter
            }, yesCallback)

            UI.acceptTransferHouse:setVisible(false)
            UI.ListBase:setVisible(true)
            Cyclopedia.Toggle(true, false)
        end
    elseif type == 7 and message == 0 then
        confirmWindow = displayGeneralBox(tr("Summary"), tr(
            "You jected the house transfer sucessfully. The old owner will keep the house."), {
            {
                text = tr("Ok"),
                callback = yesCallback
            },
            anchor = AnchorHorizontalCenter
        }, yesCallback)

        UI.rejectTransferHouse:setVisible(false)
        UI.ListBase:setVisible(true)
        Cyclopedia.Toggle(true, false)
    end
end

function Cyclopedia.rejectTransfer(widget)
  Cyclopedia.openHouseAgreement('reject')
end

function Cyclopedia.acceptTransfer(widget)
  Cyclopedia.openHouseAgreement('accept')
end

function Cyclopedia.cancelTransfer(widget)
  local d=selectedData();if d then Cyclopedia.openHouseAgreement(d.pending and d.pending.leave and 'cancelLeave'or 'cancel')end
end

function Cyclopedia.transferHouse(widget)
  Cyclopedia.openHouseTransfer('private')
end

function Cyclopedia.moveOutHouse(widget)
  Cyclopedia.openHouseMove()
end

function Cyclopedia.bidHouse(widget)
  Cyclopedia.openHouseAmount('bid')
end

function Cyclopedia.houseRefresh(widget)
  HouseMarketUI.refresh()
end

function Cyclopedia.houseSort(widget)
  Cyclopedia.showHouseList();HouseMarketUI.list({page=1,sort=widget:getCurrentOption().data})
end

function Cyclopedia.houseFilter(widget)
  if not UI then return end
  UI.TopBase.HousesCheck:setChecked(true);UI.TopBase.GuildhallsCheck:setChecked(false)
end

function Cyclopedia.reloadHouseList(skipSelect)
    if not UI then return end
    if not table.empty(Cyclopedia.House.Data) then
        UI.LateralBase.MapViewbase.noHouse:setVisible(false)
        UI.LateralBase.MapViewbase.houseImage:setVisible(false)
        UI.LateralBase.MapViewbase.reload:setVisible(true)
        UI.LateralBase.AuctionLabel:setVisible(true)
        UI.LateralBase.AuctionText:setVisible(true)
        UI.ListBase.AuctionList:destroyChildren()

        for _, data in ipairs(Cyclopedia.House.Data) do
            if data.visible then
                local widget = g_ui.createWidget("House", UI.ListBase.AuctionList)
                widget.data = data
                widget:setId(tostring(data.id))
                widget:setText(data.name)
                setHouseLabelText(widget.size, "{Size:     , #909090}" .. data.sqm .. " sqm")
                setHouseLabelText(widget.beds, "{Max. Beds: ,#909090} " .. data.beds)
                setHouseLabelText(widget.rent, data.rent)

                if data.description ~= "" then
                    local icon = g_ui.createWidget("HouseIcon", widget.icons)
                    -- icon:setImageSource("/game_cyclopedia/images/house-description")
                    icon:setTooltip(data.description)
                end

                if data.state == 0 then
                    if data.hasBid then
                        local function format(timestamp)
                            local difference = timestamp - os.time()
                            local hour = math.floor(difference / 3600)
                            local minutes = math.floor(difference % 3600 / 60)
                            return string.format("%02dh %02dmin", hour, minutes)
                        end

                        setHouseLabelText(widget.status, "{Status:  , #909090}{auctioned, #00F000} (Bid: " ..
                            data.hightestBid .. " Ends in: " .. format(data.bidEnd) .. ")")
                    else
                        setHouseLabelText(widget.status, "{Status:  , #909090}{auctioned, #00F000} (no bid yet)")
                    end
                elseif data.state == 2 then
                    setHouseLabelText(widget.status, "{Status:  , #909090}rented by " .. data.owner)
                else widget.status:setText(data.incomingTransfer and "Private transfer offer for you" or "Transfer pending at server restart")
                end

                widget.onClick = Cyclopedia.selectHouse

                if data.isYourOwner then
                    local icon = g_ui.createWidget("HouseIcon", widget.icons)
                    -- icon:setImageSource("/game_cyclopedia/images/house-owner-icon")
                end

                if widget.data.isTransferOwner then
                    local icon = g_ui.createWidget("HouseIcon", widget.icons)
                    icon:setImageSource("/game_cyclopedia/images/pending-transfer-house")
                end

                if data.isYourOwner and data.inTransfer then
                    local icon = g_ui.createWidget("HouseIcon", widget.icons)
                    icon:setImageSource("/game_cyclopedia/images/transfer-house")
                end

                if data.shop then
                    local icon = g_ui.createWidget("HouseIcon", widget.icons)
                    -- icon:setImageSource("/game_cyclopedia/images/house-shop")
                    icon:setTooltip("This house is a shop.")
                end
            end
        end

        local last=UI.ListBase.AuctionList:getChildById(tostring(Cyclopedia.House.selectedId or '')) or UI.ListBase.AuctionList:getChildByIndex(1)
        if not skipSelect then Cyclopedia.selectHouse(last)end
    else
        UI.LateralBase.MapViewbase.noHouse:setVisible(true)
        UI.LateralBase.MapViewbase.reload:setVisible(false)
        UI.LateralBase.MapViewbase.houseImage:setVisible(false)
        UI.LateralBase.AuctionLabel:setVisible(false)
        UI.LateralBase.AuctionText:setVisible(false)
        UI.LateralBase.icons:destroyChildren()
        UI.LateralBase.yourLimitBidGold:setVisible(false)
        UI.LateralBase.yourLimitBid:setVisible(false)
        UI.LateralBase.yourLimitLabel:setVisible(false)
        UI.LateralBase.highestBid:setVisible(false)
        UI.LateralBase.highestBidGold:setVisible(false)
        UI.LateralBase.subAuctionLabel:setVisible(false)
        UI.LateralBase.subAuctionText:setVisible(false)
        UI.LateralBase.transferLabel:setVisible(false)
        UI.LateralBase.transferValue:setVisible(false)
        UI.LateralBase.transferGold:setVisible(false)
        UI.ListBase.AuctionList:destroyChildren()
        UI.LateralBase.MapViewbase.noHouse.previewMessage:setText('No house selected')
        Cyclopedia.clearHouseActions()
    end
end

function Cyclopedia.loadHouseList(data, other)
    if Cyclopedia.House.ignore then
        Cyclopedia.House.ignore = false
        return
    end

    local houses = {}

    if not table.empty(data) then
        for i = 0, #data do
            local value = data[i]
            local house = HOUSE[value.houseId]
            if house then
                local isGuildHall = house.GH > 0 and true or false
                local data_t = {
                    id = value.houseId,
                    name = house.name,
                    description = house.description,
                    rent = house.rent,
                    beds = house.beds,
                    sqm = house.sqm,
                    gh = isGuildHall,
                    shop = house.shop > 0 and true or false,
                    visible = not isGuildHall,
                    state = value.state,
                    owner = other[i].owner and other[i].owner or "?",
                    isYourBid = data[i].bidHolderLimit and data[i].bidHolderLimit > 0 and true or false,
                    hasBid = data[i].bidEnd and data[i].bidEnd > 0 and true or false,
                    bidEnd = data[i].bidEnd and data[i].bidEnd or nil,
                    hightestBid = data[i].hightestBid and data[i].hightestBid or nil,
                    bidName = other[i].bidName and other[i].bidName or nil,
                    bidHolderLimit = data[i].bidHolderLimit and data[i].bidHolderLimit or nil,
                    canBid = data[i].selfCanBid,
                    rented = data[i].state == 2 and true or false,
                    paidUntil = data[i].paidUntil and data[i].paidUntil or nil,
                    isYourOwner = other[i].owner and other[i].owner:lower() == g_game.getLocalPlayer():getName():lower() and
                        true or false,
                    inTransfer = data[i].state == 3 and true or false,
                    transferName = other[i].transferPlayer and other[i].transferPlayer or nil,
                    transferTime = data[i].time and data[i].time or 0,
                    transferValue = data[i].transferValue and data[i].transferValue or 0,
                    isTransferOwner = data[i].hasTransferOwner and data[i].hasTransferOwner > 0 and true or false,
                    canAcceptTransfer = data[i].canAcceptTransfer and data[i].canAcceptTransfer or 0
                }

                table.insert(houses, data_t)
            end
        end
    else
        UI.ListBase.AuctionList:destroyChildren()
    end

    table.sort(houses, function(a, b)
        return a.name < b.name
    end)

    Cyclopedia.House.Data = houses
    Cyclopedia.reloadHouseList()
end

function Cyclopedia.selectTown(widget)
  local value=widget:getCurrentOption().data
  Cyclopedia.showHouseList()
  HouseMarketUI.list({page=1,townId=type(value)=='number' and value or 0,filter=value=='mine' and 'mine' or value=='offers' and 'offers' or 'all'})
end

function Cyclopedia.selectHouse(widget,hydrated,d)
  if not UI or not widget then return end
  local value=widget.data
  if not hydrated then
    for _,child in ipairs(UI.ListBase.AuctionList:getChildren())do child:setChecked(child==widget)end
    Cyclopedia.House.lastSelectedHouse=widget;Cyclopedia.House.selectedId=value.id
    Cyclopedia.clearHouseActions();resetSelectedInfo();preview(value)
    UI.LateralBase.AuctionLabel:show();UI.LateralBase.AuctionLabel:setText('House Information')
    UI.LateralBase.AuctionText:show();UI.LateralBase.AuctionText:setText('Loading house details...')
    HouseMarketUI.select(value.id);return
  end
  Cyclopedia.clearHouseActions();resetSelectedInfo();preview(value)
  local left=UI.LateralBase;left.icons:destroyChildren();left._actionOffset=7
  left.AuctionLabel:show();left.AuctionText:show()
  if d.pending then
    left.AuctionLabel:setText(d.pending.leave and 'Move Out Pending' or 'Transfer Pending')
    left.AuctionText:setText('At next server restart\n'..(d.pending.recipientName and ('New owner: '..d.pending.recipientName)or 'Ownership change pending'))
    if d.isOwner and d.pending.leave then leftButton('cancelTransfer','Keep house',Cyclopedia.cancelTransfer,86)end
  elseif d.listing and d.listing.type=='private'then
    left.AuctionLabel:setText('Private Transfer Offer')
    left.AuctionText:setText('To: '..(d.listing.recipientName or '')..'\nPrice: '..money(d.listing.price)..' gold\nOn acceptance, at server restart')
    if d.isOwner then leftButton('cancelTransfer','Cancel offer',Cyclopedia.cancelTransfer,86)
    elseif d.listing.canBuy then
      leftButton('acceptTransfer','Accept',Cyclopedia.acceptTransfer,72,d.canAcquire,d.acquireReason)
      leftButton('rejectTransfer','Reject',Cyclopedia.rejectTransfer,72)
    end
  elseif d.owner==0 or (d.listing and d.listing.type=='auction')then
    left.AuctionLabel:setText('Auction')
    left.AuctionText:setText('Highest bidder: '..(d.highestBidderName~='' and d.highestBidderName or 'No bids')..'\nEnds: '..(d.endsAt>0 and timeText(d.endsAt)or 'After first bid')..'\nHighest bid: '..money(d.bid)..' gold')
    if d.myReserved>0 then left.yourLimitLabel:show();left.yourLimitBid:show();left.yourLimitBidGold:show();left.yourLimitBid:setText(money(d.myReserved))end
    if not d.isOwner then leftButton('bidButton','Bid',Cyclopedia.bidHouse,72,d.canAcquire,d.acquireReason)
    elseif d.bid==0 then leftButton('cancelTransfer','Cancel auction',Cyclopedia.cancelTransfer,98)end
  else
    left.AuctionLabel:setText('Rental Details')
    left.AuctionText:setText('Tenant: '..d.ownerName..'\n'..(d.rentPeriod=='never' and 'Rent collection disabled' or 'Paid until: '..timeText(d.paidUntil))..(d.listing and ('\nFor sale: '..money(d.listing.price)..' gold')or ''))
    if d.isOwner then
      leftButton('transferButton','Transfer',Cyclopedia.transferHouse,72)
      leftButton('moveOutButton','Move Out',Cyclopedia.moveOutHouse,72,not d.listing,'Cancel the listing before moving out.')
    elseif d.listing and d.listing.canBuy then leftButton('acceptTransfer','Buy',function()Cyclopedia.openHouseAgreement('buy')end,72,d.canAcquire,d.acquireReason)end
  end
  leftButton('houseMoreButton','More...',Cyclopedia.showHouseActions,68)
end
