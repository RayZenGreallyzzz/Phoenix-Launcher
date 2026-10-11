extends SceneTree

# Offline Godot test; only REAL original PPA auction read fields and
# the account-bound service. No money or item mutation can be triggered.
const NPC = preload("res://scripts/ppa_npc_screen.gd")
const BRIDGE = preload("res://scripts/ppa_native_auction_service.gd")
const OWNER := "990000001"
const OTHER := "990000002"

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, message: String) -> void:
    if not ok:
        push_error("PPA_ORIGINAL_AUCTION_READ_FAIL: " + message)
        quit(1)
        assert(ok, message)

func _run() -> void:
    set_meta("phoenix_account", {"telegramId":OWNER})
    remove_meta("ppa_native_game_session")
    var host := Control.new()
    root.add_child(host)
    host.size = Vector2(1280,720)
    var npc := NPC.new()
    host.add_child(npc)
    npc.size = host.size
    npc.open_npc({"service":"auction","name":"Аукционист"})
    check(npc.auction_state.is_empty(), "Unsigned PPA auction should not be shown")
    var signed := {"gameId":"phoenix-pix-arena","contract":"ppa-auction-v1",
        "ownerId":OWNER,"actions":[],"state":{
        "connected":true,"self":{"id":OWNER},"version":19,
        "commissionPct":10,"source":"Telegram PPA auction_lots/auction_credits",
        "settlementEnabled":false,"wallet":{"ppa":5000,"gram":12},
        "lots":[{"id":"original-lot","item":{"name":"Посох мага","rarity":"epic","enh":7,
            "kind":"gear","slot":"weapon"},"price":4000,"qty":1,"currency":"ppa",
            "sellerId":OTHER,"sellerName":"Другой игрок","canBuy":false}],
        "mine":[{"id":"my-lot","item":{"name":"Лунный лис","rarity":"epic","enh":5,
            "kind":"gear","slot":"pet"},"price":60,"qty":1,"currency":"gram",
            "sellerId":OWNER,"sellerName":"Я","canCancel":false}],
        "recoverable":[],"pendingCredits":[{"id":"credit1","lotId":"oldlot","soldQty":1,"currency":"ppa",
            "amount":900,"createdAt":123}],
        "bag":[{"uid":"my-+7","name":"Броня +7","slot":"armor","enh":7,"rarity":"epic"}]}}
    npc.apply_native_auction(signed)
    check(npc.auction_state["lots"].size() == 1,
        "Real Telegram lot not displayed")
    check(npc.auction_state["wallet"]["ppa"] == 5000,
        "Original server wallet is not used")
    check(npc.auction_state["commissionPct"] == 10,
        "Original commission not visible")
    check(npc.auction_state["pendingCredits"][0]["amount"] == 900,
        "Seller credits not read from original server")
    var wrong := signed.duplicate(true)
    wrong["ownerId"] = OTHER
    wrong["state"]["self"]["id"] = OTHER
    npc.apply_native_auction(wrong)
    check(npc.auction_state["wallet"]["ppa"] == 5000,
        "Auction accepted another account's balances")
    npc._select_tab("mine")
    check(npc.auction_state["mine"][0]["id"] == "my-lot",
        "Own original PPA lot missing")
    npc._select_tab("sell")
    check(npc.auction_state["bag"][0]["enh"] == 7,
        "Speculative Godot auction altered original +7 gear")
    var bridge := BRIDGE.new()
    check(bridge.supported_actions.has("buy"),"Server escrow service missing")
    check(npc.auction_actions.is_empty(), "Auction actions enabled with flags off")
    bridge.free()
    npc.close_npc()
    check(npc.auction_state.is_empty(),"Old auction account state survived NPC close")
    host.queue_free()
    await process_frame
    print("PPA_NATIVE_AUCTION_READONLY_OK listings=1 mine=1 seller_credits=1 commission=10 owner=1 no_spend=1")
    quit(0)
