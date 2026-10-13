extends SceneTree

# Offline Godot 4.6 UI + auth test. No live purchases or balance mutations.
const NPC = preload("res://scripts/ppa_npc_screen.gd")
const OWNER := "990000001"
const OTHER := "990000002"
const LOT := "nat_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, message: String) -> void:
    if not value:
        push_error("PPA_AUCTION_PHOENIX_LAYOUT_FAIL: " + message)
        quit(1)
        assert(value, message)

func _run() -> void:
    set_meta("phoenix_account",{"telegramId":OWNER})
    var host := Control.new()
    host.size = Vector2(480,850)
    root.add_child(host)
    var npc := NPC.new()
    npc.size = host.size
    host.add_child(npc)
    var sent: Array = []
    npc.auction_action_requested.connect(func(fields: Dictionary): sent.append(fields.duplicate(true)))
    npc.open_npc({"service":"auction","name":"Аукционист"})
    check(npc._body.find_child("PPAAuctionPhoenixBanner",true,false)!=null,"Phoenix banner missing")
    var footer := npc.find_child("PPAAuctionFixedWallet",true,false) as HBoxContainer
    check(footer!=null and footer.visible and footer.get_child_count()==2,
        "Offline auction footer must show PPA and Gram horizontally")
    var offline_ppa := footer.find_child("PPAAuctionWalletAmount_ppa",true,false) as Label
    var offline_gram := footer.find_child("PPAAuctionWalletAmount_gram",true,false) as Label
    check(offline_ppa!=null and offline_gram!=null and offline_ppa.text=="PPA  —"
        and offline_gram.text=="Gram  —",
        "Unknown balances should display dashes, never guessed amounts")
    check(npc._body.find_child("PPAAuctionWallet_ppa",true,false)==null,
        "PPA wallet must not be inside scrolling category content")
    check(npc._body.find_child("PPAAuctionCategoryGrid",true,false)!=null,
        "Offline auction must still show item categories")
    check(npc._body.find_child("PPAAuctionSearch",true,false)!=null,
        "Offline auction must still show search and filters")
    npc._select_tab("sell")
    var offline_grid := npc._body.find_child("PPARealAuctionGearGrid",true,false) as GridContainer
    var offline_place := npc._body.find_child("PPARealAuctionPlace",true,false) as Button
    check(offline_grid!=null and offline_grid.get_child_count()==0,
        "Offline auction must not invent owned inventory items")
    check(offline_place!=null and offline_place.disabled,
        "Offline auction must never enable item listing")
    npc.apply_player_save_readonly({
        "bag":[{"uid":"owned-real-1","slot":"weapon","kind":"gear",
            "name":"Настоящий предмет","rarity":"epic"}],
        "potions":{"hp":2},"ppa":551,"gram":3
    })
    offline_grid = npc._body.find_child("PPARealAuctionGearGrid",true,false) as GridContainer
    check(offline_grid!=null and offline_grid.get_child_count()>=2,
        "Auction sale tab ignores canonical authenticated save inventory")
    var saved_item := npc._body.find_child("PPARealAuctionSellUID_owned-real-1",true,false) as Button
    check(saved_item==null,
        "Read-only save item incorrectly gained server escrow authority")
    var price_preview := npc._body.find_child("PPARealAuctionPrice",true,false) as SpinBox
    var currencies_preview := npc._body.find_child("PPARealAuctionCurrency",true,false) as OptionButton
    check(price_preview!=null and currencies_preview!=null and currencies_preview.item_count==2,
        "Read-only auction must allow editing price and selecting Gram/PPA")
    price_preview.value = 120
    currencies_preview.select(1)
    npc._set_currency(1)
    check(npc._asking_price==120 and npc._asking_currency=="Gram",
        "Read-only price entry and Gram choice failed")
    npc.clear_player_save_readonly()
    npc._select_tab("mine")
    check(npc._body.find_child("PPAAuctionMainPanel",true,false)!=null,
        "Offline auction hides the my-lots tab")
    check(npc._body.find_child("ServerActionLocked",true,false)!=null,
        "Unsigned auction must explicitly lock server actions")
    npc._select_tab("all")
    var state := {
        "connected":true,"self":{"id":OWNER},"version":17,"settlementEnabled":true,
        "wallet":{"ppa":551,"gram":3},"commissionPct":10,"maxSellSlots":3,
        "lots":[{"id":LOT,"item":{"name":"Посох мага +7","kind":"gear","rarity":"epic","slot":"weapon","level":60},
            "qty":1,"price":1250,"currency":"ppa","sellerName":"Игрок","canBuy":true}],
        "mine":[],"pendingCredits":[],"recoverable":[],
        "bag":[{"uid":"gear-unique-7","name":"Броня мага +7","kind":"gear",
            "slot":"armor","enh":7,"rarity":"epic"}]
    }
    npc._set_asking_price(1)
    npc._set_currency(0)
    npc.apply_native_auction({
        "gameId":"phoenix-pix-arena","contract":"ppa-auction-v1",
        "ownerId":OWNER,"actions":["buy","place","cancel","recover"],"state":state})
    check(npc._body.find_child("PPAAuctionCategoryGrid",true,false)!=null,"Categories not displayed")
    check(npc._body.find_child("PPAAuctionSearch",true,false)!=null,"Real auction search missing")
    check(npc._body.find_child("PPAAuctionRarityFilter",true,false)!=null,"Rarity filter missing")
    footer = npc.find_child("PPAAuctionFixedWallet",true,false) as HBoxContainer
    check(footer != null and footer.visible and footer.get_child_count()==2,
        "Signed PPA and Gram wallet must stay pinned at the bottom")
    var ppa := footer.find_child("PPAAuctionWalletAmount_ppa",true,false) as Label
    var gram := footer.find_child("PPAAuctionWalletAmount_gram",true,false) as Label
    check(ppa!=null and gram!=null and ppa.text=="PPA  551" and gram.text=="Gram  3",
        "Pinned wallet did not show real signed balances")
    check(ppa.autowrap_mode==TextServer.AUTOWRAP_OFF
        and gram.autowrap_mode==TextServer.AUTOWRAP_OFF,
        "Wallet counters must not wrap vertically on mobile")
    var buy := npc._body.find_child("PPARealAuctionBuy_" + LOT,true,false) as Button
    check(buy!=null and not buy.disabled,"Signed buy quote missing")
    buy.pressed.emit()
    check(sent.size()==1 and sent[0]["action"]=="buy" and sent[0]["currency"]=="ppa",
        "Buy did not send a server-backed PPA quote")
    npc._auction_filter("misc")
    check(npc._body.find_child("PPARealAuctionBuy_" + LOT,true,false)==null,
        "Misc erroneously included weapons")
    npc._auction_filter("all")
    npc._select_tab("sell")
    var grid := npc._body.find_child("PPARealAuctionGearGrid",true,false) as GridContainer
    check(grid!=null and grid.get_child_count()>0,"Real UID equipment grid missing")
    var currency := npc._body.find_child("PPARealAuctionCurrency",true,false) as OptionButton
    check(currency!=null and currency.item_count==2 and currency.get_item_text(0)=="PPA"
        and currency.get_item_text(1)=="Gram","Auction allows an unsupported currency")
    var place := npc._body.find_child("PPARealAuctionPlace",true,false) as Button
    check(place!=null and not place.disabled,"Protected PPA gear listing unavailable")
    place.pressed.emit()
    check(sent.size()==2 and sent[1]=={
        "action":"place","uid":"gear-unique-7","price":1,"currency":"ppa","version":17
    },"Real listing must carry only UID, PPA price and version")
    check(state["bag"][0]["enh"]==7,"UI mutated source gear")
    npc.set_native_auction_pending(false,true)
    place = npc._body.find_child("PPARealAuctionPlace",true,false) as Button
    check(place!=null and place.disabled,"Pending server receipt allowed duplicate sale")
    npc.set_native_auction_pending(false,false)
    npc._select_tab("mine")
    check(npc._body.find_child("PPAAuctionMainPanel",true,false)!=null,"Own listings panel missing")
    npc.close_npc()
    host.queue_free()
    await process_frame
    print("PPA_AUCTION_PHOENIX_LAYOUT_OK buy=1 sell=1 mine=1 search=1 rarity=1 coin=1 currencies=ppa_gram misc=1 pending=1")
    quit(0)
