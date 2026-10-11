extends SceneTree

# Restore an expired real PPA auction item; NEVER trust a local bag copy.
const NPC = preload("res://scripts/ppa_npc_screen.gd")
const OWNER := "990000001"
const OTHER := "990000002"
const EXPIRED_ID := "nat_cccccccccccccccccccccccccccccccc"

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, detail: String) -> void:
    if not ok:
        push_error("PPA_NATIVE_AUCTION_RECOVERY_FAIL: " + detail)
        quit(1)
        assert(ok, detail)

func _run() -> void:
    set_meta("phoenix_account", {"telegramId":OWNER})
    remove_meta("ppa_native_game_session")
    var host := Control.new()
    root.add_child(host)
    host.size = Vector2(1280, 720)
    var npc := NPC.new()
    host.add_child(npc)
    npc.size = host.size
    var recorded: Array = []
    npc.auction_action_requested.connect(func(fields: Dictionary):
        recorded.append(fields.duplicate(true)))
    npc.open_npc({"service":"auction","name":"Аукционист"})
    npc._select_tab("mine")
    var packet := {"gameId":"phoenix-pix-arena","contract":"ppa-auction-v1",
        "ownerId":OWNER,"actions":["place","buy","cancel","recover"],
        "state":{"connected":true,"self":{"id":OWNER},"version":14,
            "wallet":{"ppa":50,"gram":2},"commissionPct":10,
            "settlementEnabled":true,"maxSellSlots":3,
            "lots":[],"mine":[],"pendingCredits":[],
            "bag":[],
            "recoverable":[{"id":EXPIRED_ID,"uid":"pet-+7",
                "item":{"name":"Исходный питомец +7","enh":7,"slot":"pet","rarity":"epic"},
                "qty":1,"price":250,"currency":"ppa","sellerId":OWNER,
                "sellerName":"Я","canRecover":true}]}}
    npc.apply_native_auction(packet)
    var reclaim := npc._body.find_child("PPARealAuctionRecover_" + EXPIRED_ID,true,false) as Button
    check(reclaim != null and not reclaim.disabled,
        "Owner cannot recover confirmed expired item")
    reclaim.pressed.emit()
    check(recorded == [{"action":"recover","lotId":EXPIRED_ID,"version":14}],
        "Recovery must carry original lot ID and version, not raw item payload")
    check((npc.auction_state["recoverable"][0] as Dictionary).get("uid") == "pet-+7",
        "Native client mutated original item before confirmation")
    npc.set_native_auction_pending(false,true)
    reclaim = npc._body.find_child("PPARealAuctionRecover_" + EXPIRED_ID,true,false) as Button
    check(reclaim != null and reclaim.disabled,
        "Unconfirmed return can be duplicated")
    npc.set_native_auction_pending(false,false)
    set_meta("phoenix_account",{"telegramId":OTHER})
    npc._auction_recover_lot(EXPIRED_ID)
    check(recorded.size() == 1,"Other account could return previous owner item")
    set_meta("phoenix_account",{"telegramId":OWNER})
    var disabled := packet.duplicate(true)
    disabled["actions"] = []
    disabled["state"]["settlementEnabled"] = false
    npc.apply_native_auction(disabled)
    reclaim = npc._body.find_child("PPARealAuctionRecover_" + EXPIRED_ID,true,false) as Button
    check(reclaim != null and reclaim.disabled,
        "Server-off flag must hide recovery write")
    npc.close_npc()
    check(npc.auction_state.is_empty(),
        "Closed auction retained account's stale escrow rights")
    host.queue_free()
    await process_frame
    print("PPA_NATIVE_AUCTION_RECOVERY_OK original_uid=1 owner=1 pending=1 readonly_preview=1")
    quit(0)
