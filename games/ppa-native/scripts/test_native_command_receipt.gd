extends SceneTree

# Real Godot 4.6 command handler. Offline: no D1/Cloudflare/Android writes.
# A signed action receipt has NO state/actions; those belong to a GET snapshot.
const Probe = preload("res://scripts/test_native_command_receipt_probe.gd")
const OWNER := "990000001"
const OTHER := "990000002"
const REQUEST := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const NEXT_REQUEST := "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, why: String) -> void:
    if not ok:
        push_error("PPA_NATIVE_RECEIPT_FAIL: " + why)
        quit(1)
        assert(ok, why)

func _reply(service: Node, status: int, value: Dictionary) -> void:
    service._on_completed(HTTPRequest.RESULT_SUCCESS, status, PackedStringArray(),
        JSON.stringify(value).to_utf8_buffer())

func _run() -> void:
    set_meta("phoenix_account", {"telegramId":OWNER})
    var service := Probe.new()
    root.add_child(service)
    await process_frame
    service.service_key = "auction"
    service.contract_key = "ppa-auction-v1"
    service._owner = OWNER
    service._pending_owner = OWNER
    service._kind = "action"
    service._pending = {"requestId":REQUEST,"action":"claim",
        "creditId":"credit_123","version":5}
    var completed: Array = []
    var failed: Array = []
    var snapshots: Array = []
    service.command_finished.connect(func(message: String): completed.append(message))
    service.request_failed.connect(func(message: String): failed.append(message))
    service.state_ready.connect(func(snapshot: Dictionary): snapshots.append(snapshot.duplicate(true)))

    # Canonical server success has only signed command receipt, no state/actions.
    _reply(service, 200, {"ok":true,"gameId":"phoenix-pix-arena",
        "contract":"ppa-auction-v1","ownerId":OWNER,"requestId":REQUEST,
        "commandStatus":"done","receipt":{"id":"credit_123","amount":900},
        "version":6,"refreshRequired":true,"message":"PPA received"})
    check(completed.size()==1 and completed[0]=="PPA received",
        "Valid receipt without state/actions was rejected")
    check(failed.is_empty(), "Valid action receipt raised a failure")
    check(service.refresh_count==1, "Successful command must GET canonical state")
    check(service._pending.is_empty(), "Confirmed command was not cleared")
    check(snapshots.is_empty(), "Receipt must not be applied as mutable state")

    # A fresh GET must still have real state/actions and owner identity.
    service._kind = "state"
    _reply(service, 200, {"ok":true,"gameId":"phoenix-pix-arena",
        "contract":"ppa-auction-v1","ownerId":OWNER,"actions":[],
        "state":{"connected":true,"self":{"id":OWNER},"version":6}})
    check(snapshots.size()==1, "Authoritative GET snapshot not accepted")

    # A missing ack or wrong request ID can NEVER clear a pending action.
    service._kind = "action"
    service._pending = {"requestId":NEXT_REQUEST,"action":"buy","version":6}
    _reply(service, 200, {"ok":true,"gameId":"phoenix-pix-arena",
        "contract":"ppa-auction-v1","ownerId":OWNER,"requestId":REQUEST,
        "commandStatus":"done","message":"stale reply"})
    check(service._pending.get("requestId")==NEXT_REQUEST,
        "Stale response cleared a different command")
    check(service.refresh_count==1 and completed.size()==1,
        "Stale response applied as a new purchase")
    check(not failed.is_empty(), "Missing command ack was not reported")

    # A terminal error tied to the exact request is safe to acknowledge,
    # then refresh; it does not grant local items or money.
    _reply(service, 409, {"ok":false,"gameId":"phoenix-pix-arena",
        "contract":"ppa-auction-v1","ownerId":OWNER,"requestId":NEXT_REQUEST,
        "commandStatus":"done","code":"SAVE_VERSION_CONFLICT",
        "message":"Refresh character version"})
    check(service._pending.is_empty(), "Terminal server refusal was not cleared")
    check(service.refresh_count==2, "Terminal refusal must also refresh state")
    check(completed.size()==1, "Refused action generated success signal")

    # Do not trust a snapshot from another player.
    service._kind = "state"
    _reply(service, 200, {"ok":true,"gameId":"phoenix-pix-arena",
        "contract":"ppa-auction-v1","ownerId":OTHER,"actions":[],
        "state":{"connected":true,"self":{"id":OTHER},"version":7}})
    check(snapshots.size()==1, "Foreign account snapshot leaked to current UI")

    service.queue_free()
    await process_frame
    print("PPA_NATIVE_RECEIPT_PARITY_OK receipt_without_state=1 refresh=1 replay=1 refusal=1 owner=1 no_local_credit=1")
    quit(0)
