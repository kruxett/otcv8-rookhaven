"""Real encrypted house RPCs against the runner's disposable native fixture."""
import json,time,socket
from wire import Wire,string

def run(pem,sql,check,boot,create,stop,runtime,ui_only=False,rent_only=False):
    flags='\nclientHouseMarketEnabled = true\n'
    boot(flags)
    pw='HouseFixtureOnly'
    people={}
    for account,name in [('homeseller','Home Seller'),('homebuyer','Home Buyer'),('homerival','Home Rival')]:
        check(create(1,account,pw,account+'@example.invalid')['success']==1,'housing fixture account '+account)
        created=create(2,account,pw,name)
        check(created['success']==1,'housing fixture character '+name)
        assert created['name']==name,'fixture received a different character identity'
        deadline=time.monotonic()+2
        while True:
            persisted=sql("SELECT id FROM players WHERE name='"+name+"'")
            if persisted:break
            assert time.monotonic()<deadline,'successful fixture character is missing from SQL: '+name
            time.sleep(.05)
        people[account]=int(persisted)
    stop()
    sql("UPDATE accounts SET premium_ends_at=UNIX_TIMESTAMP()+864000 WHERE name IN ('homeseller','homebuyer','homerival')")
    sql('UPDATE players SET balance=10000 WHERE id IN ('+','.join(map(str,people.values()))+')')
    ids=[int(x) for x in sql('SELECT id FROM houses WHERE owner=0 ORDER BY id LIMIT 3').splitlines()]
    assert len(ids)==3,'three map houses required'
    owned,auction,spare=ids
    sql('UPDATE houses SET owner='+str(people['homebuyer' if ui_only or rent_only else 'homeseller'])+' WHERE id='+str(owned))
    if rent_only:sql('UPDATE houses SET owner='+str(people['homerival'])+' WHERE id='+str(auction))
    boot(flags)
    if ui_only:return
    clients=[];request=0
    def connect(account,name):
        w=Wire(pem,7188);assert w.game_login(account,name,pw);clients.append(w);return w
    def rpc(w,action,**fields):
        nonlocal request
        request+=1;payload=dict(action=action,requestId=request,**fields)
        # The service intentionally limits writes to one/sec/account.
        time.sleep(1.05)
        w.send(b'\x32\x76'+string(json.dumps(payload,separators=(',',':'))))
        deadline=time.monotonic()+8
        while time.monotonic()<deadline:
            data=w.receive().data;offset=0
            while True:
                index=data.find(b'\x32\x76',offset)
                if index<0:break
                offset=index+2
                if index+4>len(data):continue
                length=int.from_bytes(data[index+2:index+4],'little')
                try:value=json.loads(data[index+4:index+4+length])
                except (ValueError,UnicodeError):continue
                if value.get('requestId')==request:return value
        raise AssertionError('no house RPC response '+action)
    def detail(w,house):
        value=rpc(w,'detail',houseId=house)
        assert value['success'],value
        return value['data']
    def action(w,kind,data,**fields):return rpc(w,kind,houseId=data['id'],revision=data['revision'],**fields)
    if rent_only:
        try:
            buyer=connect('homebuyer','Home Buyer');seller=connect('homeseller','Home Seller')
            data=detail(buyer,owned)
            check(action(buyer,'listSale',data,saleType='auction',amount=100,durationHours=1)['success'],'rent fixture owner starts auction')
            data=detail(seller,owned)
            check(action(seller,'bid',data,amount=1000,automatic=True)['success'],'rent fixture bidder reserves proxy maximum')
        finally:
            for w in clients:w.close()
        stop()
        sql('UPDATE players SET balance=0 WHERE id='+str(people['homebuyer']))
        sql('UPDATE houses SET paid=0,warnings=7 WHERE id='+str(owned))
        other_rent=int(sql('SELECT rent FROM houses WHERE id='+str(auction)))
        boot(flags+'\nhouseRentPeriod = "daily"\n')
        check(sql('SELECT owner FROM houses WHERE id='+str(owned))=='0','final unpaid warning evicts through atomic native handover')
        check(sql('SELECT balance FROM players WHERE id='+str(people['homeseller']))=='10000','rent eviction refunds bidder entire proxy maximum')
        check(sql('SELECT COUNT(*) FROM web_house_auto_bids WHERE house_id='+str(owned))=='0' and sql("SELECT COUNT(*) FROM web_house_sale_listings WHERE house_id="+str(owned)+" AND status='active'")=='0','rent eviction clears obsolete reservation and listing')
        check(sql('SELECT balance FROM players WHERE id='+str(people['homerival']))==str(10000-other_rent),'ordinary funded owner still pays native rent once')
        stop();boot(flags+'\nhouseRentPeriod = "daily"\n')
        check(sql('SELECT balance FROM players WHERE id='+str(people['homeseller']))=='10000','second restart never repeats rent-eviction refund')
        check(sql('SELECT balance FROM players WHERE id='+str(people['homerival']))==str(10000-other_rent),'funded owner is not charged rent twice for same period')
        return
    try:
        seller=connect('homeseller','Home Seller');buyer=connect('homebuyer','Home Buyer');rival=connect('homerival','Home Rival')
        check(rpc(buyer,'capabilities')['enabled'],'native world advertises enabled house market')
        catalog=rpc(buyer,'list',page=1,filter='all',search='',townId=0)
        check(catalog['success'] and len(catalog['data']['houses'])>0,'encrypted house catalogue and town list')
        for sort in ('name','size','rent','bid','endsAt'):
            ordered=rpc(buyer,'list',page=1,filter='all',search='',sort=sort,status=1)
            check(ordered['success'] and all(h['owner']==0 or h['endsAt']>0 for h in ordered['data']['houses']),'stock auction filter and bounded '+sort+' sorting')
        rented=rpc(seller,'list',page=1,filter='mine',search='',sort='name',status=2)
        check(rented['success'] and [h['id'] for h in rented['data']['houses']]==[owned],'stock own-house and rented filters combine correctly')
        data=detail(buyer,owned)
        check(not action(buyer,'listSale',data,saleType='direct',amount=500)['success'],'non-owner cannot list another character house')
        data=detail(seller,owned)
        check(action(seller,'listSale',data,saleType='direct',amount=500)['success'],'owner publishes fixed-price sale')
        stale=data;data=detail(buyer,owned)
        check(not action(buyer,'buy',stale)['success'],'stale revision cannot charge buyer')
        check(action(buyer,'buy',data)['success'],'direct purchase reserves buyer gold')
        check(sql('SELECT balance FROM players WHERE id='+str(people['homebuyer']))=='9500' and sql('SELECT balance FROM players WHERE id='+str(people['homeseller']))=='10000','seller is paid only with restart handover')
        check(not action(buyer,'buy',data)['success'] and sql('SELECT balance FROM players WHERE id='+str(people['homebuyer']))=='9500','duplicate purchase never charges twice')
        check(detail(buyer,owned)['pending']['price']==500,'pending purchase visible in native detail')
        private=detail(rival,owned)['pending']
        check('price' not in private and 'recipientName' not in private,'pending private agreement terms hidden from unrelated character')
        # The same account cannot reserve a second house while waiting.
        data=detail(buyer,auction)
        check(not action(buyer,'bid',data,amount=500,automatic=False)['success'],'pending buyer cannot lead a second house auction')
        data=detail(rival,auction);minimum=data['minimum']
        maximum=minimum+1000
        check(action(rival,'bid',data,amount=maximum,automatic=True)['success'],'first proxy bid reserves its full maximum')
        check(sql('SELECT balance FROM players WHERE id='+str(people['homerival']))==str(10000-maximum),'proxy maximum reserved once')
        data=detail(rival,auction)
        check(data['bid']==minimum and data['myReserved']==maximum,'initial proxy price starts at rent with maximum private')
        check(action(rival,'cancelAuto',data)['success'],'leading bidder disables proxy and releases excess')
        check(sql('SELECT balance FROM players WHERE id='+str(people['homerival']))==str(10000-minimum),'disabling proxy keeps only winning price reserved')
        data=detail(seller,auction)
        check(not action(seller,'bid',data,amount=minimum+100,automatic=False)['success'],'account already owning house cannot acquire another')
    finally:
        for w in clients:w.close()
    stop();boot(flags)
    check(sql('SELECT owner FROM houses WHERE id='+str(owned))==str(people['homebuyer']),'ordinary restart completes direct ownership transfer')
    check(sql('SELECT balance FROM players WHERE id='+str(people['homeseller']))=='10500','ordinary restart pays seller exactly once')
    check(sql('SELECT COUNT(*) FROM web_house_pending_transfers WHERE house_id='+str(owned))=='0','settled transfer removed after atomic handover')
    stop();boot(flags)
    check(sql('SELECT balance FROM players WHERE id='+str(people['homeseller']))=='10500','second restart does not repeat seller payment')
    clients=[]
    try:
        seller=connect('homeseller','Home Seller');rival=connect('homerival','Home Rival')
        data=detail(seller,auction)
        check(action(seller,'bid',data,amount=minimum+100,automatic=False)['success'],'new eligible bidder overtakes standing manual bid')
        check(sql('SELECT balance FROM players WHERE id='+str(people['homerival']))=='10000','outbid participant receives full previous reservation')
        data=detail(rival,auction)
        check(action(rival,'bid',data,amount=minimum+2000,automatic=True)['success'],'proxy challenger overtakes manual leader')
        check(sql('SELECT balance FROM players WHERE id='+str(people['homeseller']))=='10500','former manual bidder refunded exactly once')
        data=detail(seller,auction);challenge=data['bid']+100
        check(action(seller,'bid',data,amount=challenge,automatic=False)['success'],'standing proxy immediately outbids smaller challenger')
        check(sql('SELECT balance FROM players WHERE id='+str(people['homeseller']))=='10500','immediately outbid challenger pays nothing')
        data=detail(seller,auction)
        check(data['myMaximum']==0 and data['myReserved']==0 and not data['autoEnabled'],'another bidder maximum stays private')
        final_bid=int(sql('SELECT bid FROM houses WHERE id='+str(auction)))
    finally:
        for w in clients:w.close()
    # Expiry reserves price, releases excess, then waits for restart ownership.
    stop();sql('UPDATE houses SET bid_end=UNIX_TIMESTAMP()-1 WHERE id='+str(auction));boot(flags)
    deadline=time.monotonic()+8
    while sql('SELECT COUNT(*) FROM web_house_pending_transfers WHERE house_id='+str(auction))!='1':
        assert time.monotonic()<deadline,'expired auction settlement timed out';time.sleep(.2)
    check(sql('SELECT native_escrow FROM web_house_pending_transfers WHERE house_id='+str(auction))==str(final_bid),'expired auction stores winning-price escrow')
    check(sql('SELECT balance FROM players WHERE id='+str(people['homerival']))==str(10000-final_bid),'auction expiry releases unused proxy maximum')
    stop();boot(flags)
    check(sql('SELECT owner FROM houses WHERE id='+str(auction))==str(people['homerival']),'auction winner receives house at restart')
    clients=[]
    try:
        seller=connect('homeseller','Home Seller');buyer=connect('homebuyer','Home Buyer')
        data=detail(seller,owned)
        check(action(seller,'offer',data,amount=700)['success'],'eligible non-owner makes private buy offer')
        check(sql('SELECT balance FROM players WHERE id='+str(people['homeseller']))=='10500','unaccepted buy offer reserves no gold')
        offered=detail(seller,owned)['offers'][0]
        data=detail(buyer,owned)
        check(not action(seller,'declineOffer',data,offerId=offered['id'])['success'],'buyer cannot decline another owner offer')
        data=detail(seller,owned)
        check(action(seller,'cancelOffer',data,offerId=offered['id'])['success'],'buyer withdraws own offer')
        data=detail(seller,owned);check(action(seller,'offer',data,amount=700)['success'],'buyer can offer again after withdrawal')
        data=detail(buyer,owned);offered=data['offers'][0]
        check(action(buyer,'declineOffer',data,offerId=offered['id'])['success'],'owner declines incoming offer')
        data=detail(seller,owned);check(action(seller,'offer',data,amount=700)['success'],'declined offer can be replaced')
        data=detail(buyer,owned);offered=data['offers'][0]
        check(action(buyer,'acceptOffer',data,offerId=offered['id'])['success'],'owner accepts funded private offer')
        check(sql('SELECT balance FROM players WHERE id='+str(people['homeseller']))=='9800','acceptance reserves exact offered amount')
    finally:
        for w in clients:w.close()
    stop();boot(flags)
    check(sql('SELECT owner FROM houses WHERE id='+str(owned))==str(people['homeseller']) and sql('SELECT balance FROM players WHERE id='+str(people['homebuyer']))=='10200','accepted offer settles ownership and seller payment together')
    clients=[]
    try:
        seller=connect('homeseller','Home Seller');buyer=connect('homebuyer','Home Buyer');rival=connect('homerival','Home Rival')
        data=detail(seller,owned)
        check(action(seller,'listSale',data,saleType='private',amount=0,target='Home Buyer')['success'],'owner creates named gift offer')
        other=detail(rival,owned)
        check('listing' not in other,'private gift listing hidden from another character')
        check(not action(rival,'rejectTransfer',other)['success'],'unrelated character cannot reject named transfer')
        incoming=rpc(buyer,'list',page=1,filter='mine',search='',status=0,sort='name')['data']['houses']
        check(any(h['id']==owned and h['incomingTransfer'] for h in incoming),'stock own houses includes incoming private transfer')
        data=detail(buyer,owned)
        before=sql('SELECT balance FROM players WHERE id='+str(people['homebuyer']))
        check(action(buyer,'rejectTransfer',data)['success'],'named recipient declines private transfer')
        check(sql('SELECT balance FROM players WHERE id='+str(people['homebuyer']))==before and sql('SELECT owner FROM houses WHERE id='+str(owned))==str(people['homeseller']),'declined gift preserves balances and ownership')
        data=detail(seller,owned)
        check(action(seller,'listSale',data,saleType='private',amount=0,target='Home Buyer')['success'],'owner may recreate declined private gift')
        check(not action(rival,'buy',other)['success'],'another character cannot accept named transfer')
        data=detail(buyer,owned)
        check(action(buyer,'buy',data)['success'],'named recipient accepts zero-gold gift')
    finally:
        for w in clients:w.close()
    stop();boot(flags)
    check(sql('SELECT owner FROM houses WHERE id='+str(owned))==str(people['homebuyer']) and sql('SELECT balance FROM players WHERE id='+str(people['homeseller']))=='9800','gift transfers house without inventing seller payment')
    clients=[]
    try:
        buyer=connect('homebuyer','Home Buyer');data=detail(buyer,owned)
        check(action(buyer,'leave',data,confirmation='LEAVE')['success'],'owner requests abandonment at restart')
        data=detail(buyer,owned)
        check(data['pending']['leave'] and action(buyer,'cancelLeave',data)['success'],'owner cancels pending abandonment')
        data=detail(buyer,owned)
        check(action(buyer,'leave',data,confirmation='LEAVE')['success'],'owner may request abandonment after cancelling')
    finally:
        for w in clients:w.close()
    stop();boot(flags)
    check(sql('SELECT owner FROM houses WHERE id='+str(owned))=='0','restart processes abandoned house')
    # Old website direct sales already paid the seller. Never pay again.
    stop()
    sql('UPDATE houses SET owner='+str(people['homebuyer'])+' WHERE id='+str(spare))
    sql('UPDATE players SET balance=balance+400 WHERE id='+str(people['homebuyer']))
    sql('UPDATE players SET balance=balance-400 WHERE id='+str(people['homeseller']))
    sql("INSERT INTO web_house_pending_transfers(house_id,from_player_id,to_player_id,agreed_price,status) VALUES ("+str(spare)+','+str(people['homebuyer'])+','+str(people['homeseller'])+",400,'pending_server_save')")
    boot(flags)
    check(sql('SELECT owner FROM houses WHERE id='+str(spare))==str(people['homeseller']),'legacy already-paid pending sale completes native handover')
    check(sql('SELECT balance FROM players WHERE id='+str(people['homebuyer']))=='10600','legacy pending sale never pays seller a second time')
    clients=[]
    try:
        seller=connect('homeseller','Home Seller');buyer=connect('homebuyer','Home Buyer')
        data=detail(seller,spare)
        check(action(seller,'listSale',data,saleType='auction',amount=500,durationHours=1)['success'],'owner starts an auction with explicit duration and minimum')
        data=detail(buyer,spare)
        check(action(buyer,'bid',data,amount=700,automatic=False)['success'],'eligible buyer bids on owner auction')
        data=detail(seller,spare)
        check(not action(seller,'cancelListing',data)['success'],'owner cannot cancel auction after a bid')
    finally:
        for w in clients:w.close()
    stop();sql('UPDATE houses SET bid_end=UNIX_TIMESTAMP()-1 WHERE id='+str(spare));boot(flags)
    deadline=time.monotonic()+8
    while sql('SELECT COUNT(*) FROM web_house_pending_transfers WHERE house_id='+str(spare))!='1':
        assert time.monotonic()<deadline,'owner auction settlement timed out';time.sleep(.2)
    stop();boot(flags)
    check(sql('SELECT owner FROM houses WHERE id='+str(spare))==str(people['homebuyer']) and sql('SELECT balance FROM players WHERE id='+str(people['homeseller']))=='10100','owner auction pays seller with restart ownership handover')
    clients=[]
    try:
        seller=connect('homeseller','Home Seller');buyer=connect('homebuyer','Home Buyer')
        data=detail(buyer,spare)
        check(action(buyer,'listSale',data,saleType='private',amount=300,target='Home Seller')['success'],'owner creates paid named transfer')
        data=detail(seller,spare)
        check(action(seller,'buy',data)['success'],'named buyer reserves agreed payment')
    finally:
        for w in clients:w.close()
    stop();sql("UPDATE accounts SET premium_ends_at=0 WHERE name='homeseller'");boot(flags)
    check(sql('SELECT balance FROM players WHERE id='+str(people['homeseller']))=='10100' and sql('SELECT balance FROM players WHERE id='+str(people['homebuyer']))=='9900','ineligible recipient refunded in full without seller credit')
    check(sql('SELECT owner FROM houses WHERE id='+str(spare))==str(people['homebuyer']) and sql('SELECT COUNT(*) FROM web_house_pending_transfers WHERE house_id='+str(spare))=='0','expired premium cancels pending purchase while retaining existing ownership')
    stop()
    # An unavailable persistence read must fail startup, not look like no jobs.
    sql('RENAME TABLE web_house_pending_transfers TO owned_preserved_pending')
    boot(flags,expect_stop=True)
    check(sql('SELECT balance FROM players WHERE id='+str(people['homebuyer']))=='9900','failed persistence read leaves bank unchanged and opens no services')
    sql('RENAME TABLE owned_preserved_pending TO web_house_pending_transfers')
    boot(flags)
    stop();boot('\nclientHouseMarketEnabled = false\n')
    w=Wire(pem,7188)
    try:
        assert w.game_login('homebuyer','Home Buyer',pw)
        check(not rpc(w,'capabilities')['enabled'],'house feature flag is advertised closed')
        check(not rpc(w,'buy',houseId=spare,revision=0)['success'],'disabled house market refuses direct mutation')
    finally:w.close()
