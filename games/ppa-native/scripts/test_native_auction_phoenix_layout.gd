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
    check(npc._body.find_child("PPARealAuctionPlace",true,false)==null,"Unsigned sell action unexpectedly shown")
    var state := {
        "connected":true,"self":{"id":OWNER},"version":17,"settlementEnabled":true,
        "wallet":{"ppa":551,"gram":3},"commissionPct":10,"maxSellSlots":3,
        "lots":[{"id":LOT,"item":{"name":"Посох мага +7","kind":"gear","rarity":"epic","slot":"weapon","level":60},
            "qty":1,"price":1250,"currency":"ppa","sellerName":"Игрок","canBuy":true}],
        "mine":[],"pendingCredits":[],"recoverable":[],
        "bag":[{"uid":"gear-unique-7","name":"Броня мага +7","kind":"gear",
            "slot":"armor","enh":7,"rarity":"epic"}]
    }
    npc.apply_native_auction({
        "gameId":"phoenix-pix-arena","contract":"ppa-auction-v1",
        "ownerId":OWNER,"actions":["buy","place","cancel","recover"],"state":state})
    check(npc._body.find_child("PPAAuctionCategoryGrid",true,false)!=null,"Categories not displayed")
    check(npc._body.find_child("PPAAuctionSearch",true,false)!=null,"Real auction search missing")
    check(npc._body.find_child("PPAAuctionRarityFilter",true,false)!=null,"Rarity filter missing")
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
