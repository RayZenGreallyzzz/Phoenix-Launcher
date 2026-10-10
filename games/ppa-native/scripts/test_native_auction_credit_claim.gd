extends SceneTree

# Godot 4.6 safety gate: never pay pending seller credits locally.
# Credit claim only has an actionable button when server explicitly
# enables server-managed settlement for this same Telegram player.
const NPC = preload("res://scripts/ppa_npc_screen.gd")
const OWNER := "990000001"
const OTHER := "990000002"

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, reason: String) -> void:
    if not ok:
        push_error("PPA_NATIVE_AUCTION_CREDIT_FAIL: " + reason)
        quit(1)
        assert(ok,reason)

func _run() -> void:
    set_meta("phoenix_account",{"telegramId":OWNER})
    remove_meta("ppa_native_game_session")
    var host := Control.new()
    root.add_child(host)
    host.size=Vector2(1280,720)
    var npc := NPC.new()
    host.add_child(npc)
    npc.size=host.size
    var requests: Array=[]
    npc.auction_action_requested.connect(func(x: Dictionary): requests.append(x.duplicate(true)))
    npc.open_npc({"service":"auction","name":"Аукционист"})
    npc._select_tab("mine")
    var data := {"gameId":"phoenix-pix-arena","contract":"ppa-auction-v1",
        "ownerId":OWNER,"actions":["place","buy","cancel","recover"],
        "state":{"connected":true,"self":{"id":OWNER},"version":18,
        "settlementEnabled":true,"serverCreditClaimsEnabled":false,
        "wallet":{"ppa":5,"gram":3},"commissionPct":10,"maxSellSlots":2,
        "lots":[],"mine":[],"recoverable":[],"bag":[],
        "pendingCredits":[{"id":"credit_123","lotId":"nat_123",
          "currency":"ppa","amount":900,"soldQty":1,"canClaim":false}]}}
    npc.apply_native_auction(data)
    check(npc._body.find_child("PPARealAuctionClaim_credit_123",true,false)==null,
        "Legacy Telegram payout must remain read only")
    check(npc.auction_state["wallet"]["ppa"]==5,
        "Preview falsely credited pending money")
    var enabled := data.duplicate(true)
    enabled["actions"]=["place","buy","cancel","recover","claim"]
    enabled["state"]["serverCreditClaimsEnabled"]=true
    enabled["state"]["pendingCredits"][0]["canClaim"]=true
    npc.apply_native_auction(enabled)
    var button := npc._body.find_child("PPARealAuctionClaim_credit_123",true,false) as Button
    check(button!=null and not button.disabled,"Explicit server mode did not enable safe claim")
    button.pressed.emit()
    check(requests==[{"action":"claim","creditId":"credit_123","version":18}],
        "Claim must be server credit ID + save version, not client wallet/amount")
    check(npc.auction_state["wallet"]["ppa"]==5,
        "Local UI paid seller before server confirmed atomic claim")
    npc.set_native_auction_pending(false,true)
    button=npc._body.find_child("PPARealAuctionClaim_credit_123",true,false) as Button
    check(button!=null and button.disabled,"Duplicate credit action allowed while pending")
    npc.set_native_auction_pending(false,false)
    set_meta("phoenix_account",{"telegramId":OTHER})
    npc._auction_claim_credit("credit_123")
    check(requests.size()==1,"Other owner was allowed to reuse an old credit")
    set_meta("phoenix_account",{"telegramId":OWNER})
    npc.apply_native_auction(data)
    check(npc._body.find_child("PPARealAuctionClaim_credit_123",true,false)==null,
        "Legacy fallback must close claim action again")
    npc.close_npc()
    check(npc.auction_state.is_empty(),"Credit ownership leaked across NPC close")
    host.queue_free()
    await process_frame
    print("PPA_NATIVE_AUCTION_CREDIT_MODE_OK legacy_blocked=1 server_claim=1 no_local_payout=1 owner=1 pending=1")
    quit(0)
