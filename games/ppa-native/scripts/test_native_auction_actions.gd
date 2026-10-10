extends SceneTree

# Offline Godot 4.6: original PPA escrowed auction actions are available
# only for signed owner, original native lot IDs and on server enablement.
const NPC = preload("res://scripts/ppa_npc_screen.gd")
const OWNER := "990000001"
const OTHER := "990000002"
const BUY_ID := "nat_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const SELL_ID := "nat_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, why: String) -> void:
    if not ok:
        push_error("PPA_NATIVE_AUCTION_ESCROW_FAIL: " + why)
        quit(1)
        assert(ok, why)

func _run() -> void:
    set_meta("phoenix_account", {"telegramId":OWNER})
    remove_meta("ppa_native_game_session")
    var host := Control.new()
    root.add_child(host)
    host.size = Vector2(1280,720)
    var npc := NPC.new()
    host.add_child(npc)
    npc.size = host.size
    var received: Array = []
    npc.auction_action_requested.connect(func(fields: Dictionary): received.append(fields.duplicate(true)))
    npc.open_npc({"service":"auction", "name":"Аукционист"})
    var packet := {"gameId":"phoenix-pix-arena","contract":"ppa-auction-v1",
        "ownerId":OWNER,"actions":["place","buy","cancel"],
        "state":{"connected":true,"self":{"id":OWNER},"version":13,
        "settlementEnabled":true,"wallet":{"ppa":5000,"gram":25},
        "maxSellSlots":3,"commissionPct":10,
        "lots":[{"id":BUY_ID,"item":{"name":"Посох мага +7",
            "slot":"weapon","rarity":"epic","enh":7,"kind":"gear"},
            "qty":1,"price":1200,"currency":"ppa","sellerId":OTHER,"sellerName":"Друг",
            "canBuy":true,"canCancel":false}],
        "mine":[{"id":SELL_ID,"item":{"name":"Лунный лис +5",
            "slot":"pet","rarity":"epic","enh":5,"kind":"gear"},
            "qty":1,"price":99,"currency":"gram","sellerId":OWNER,"sellerName":"Я",
            "canBuy":false,"canCancel":true}],
        "recoverable":[],"pendingCredits":[],"bag":[{"uid":"real-item-plus7","name":"Броня +7",
            "slot":"armor","enh":7,"rarity":"epic"}]}}
    npc.apply_native_auction(packet)
    var buy := npc._body.find_child("PPARealAuctionBuy_" + BUY_ID,true,false) as Button
    check(buy != null and not buy.disabled,"Real native escrowed lot cannot be bought")
    buy.pressed.emit()
    check(received.size() == 1,"Buy button did not relay")
    check(received[0] == {"action":"buy","lotId":BUY_ID,
        "expectedUnitPrice":1200.0,"currency":"ppa","version":13},
        "Purchase must carry only actual lot/price/version and server owner")
    npc._select_tab("mine")
    var cancel := npc._body.find_child("PPARealAuctionCancel_" + SELL_ID,true,false) as Button
    check(cancel != null and not cancel.disabled,"Owned original escrowed listing not cancelable")
    cancel.pressed.emit()
    check(received[1] == {"action":"cancel","lotId":SELL_ID,"version":13},
        "Cancel requires original saved lot ID")
    npc._select_tab("sell")
    var place := npc._body.find_child("PPARealAuctionPlace",true,false) as Button
    check(place != null and not place.disabled,"Cannot list actual signed bag gear")
    place.pressed.emit()
    check(received[2] == {"action":"place","uid":"real-item-plus7",
        "price":1,"currency":"ppa","version":13},
        "New listing must be exact original UID, server price and version")
    check(npc.auction_state["bag"][0]["enh"] == 7,
        "Native auction mutated +7 before server receipt")
    npc.set_native_auction_pending(false,true)
    place = npc._body.find_child("PPARealAuctionPlace",true,false) as Button
    check(place != null and place.disabled,"Pending transaction allowed second listing")
    npc.set_native_auction_pending(false,false)
    set_meta("phoenix_account", {"telegramId":OTHER})
    npc._send_real_auction_action("place",
        {"uid":"real-item-plus7","price":1,"currency":"ppa"})
    check(received.size() == 3,"Account switch leaked sale permission")
    set_meta("phoenix_account", {"telegramId":OWNER})
    var disabled := packet.duplicate(true)
    disabled["actions"] = []
    disabled["state"]["settlementEnabled"] = false
    npc.apply_native_auction(disabled)
    place = npc._body.find_child("PPARealAuctionPlace",true,false) as Button
    check(place != null and place.disabled,"Default-off server flags did not lock sale")
    npc.close_npc()
    check(npc.auction_state.is_empty(),"Auction state leaked after closing NPC")
    host.queue_free()
    await process_frame
    print("PPA_NATIVE_AUCTION_ESCROW_OK buy=1 listing=1 cancel=1 owner=1 server_quote=1 pending=1 no_local_mutation=1")
    quit(0)
