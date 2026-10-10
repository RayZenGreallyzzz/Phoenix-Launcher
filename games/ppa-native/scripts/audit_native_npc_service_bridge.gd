extends SceneTree

# Synthetic offline test of NPC service bridge; no production account,
# no real Cloudflare requests, no purchases and no server save writes.
const BRIDGE = preload("res://scripts/ppa_native_npc_service_bridge.gd")
const NPC = preload("res://scripts/ppa_npc_screen.gd")

func _initialize() -> void:
    call_deferred("_run")

func fail(message: String) -> void:
    push_error("PPA_NPC_BRIDGE_FAIL: " + message)
    quit(1)

func _run() -> void:
    var bridge := BRIDGE.new()
    root.add_child(bridge)
    await process_frame
    var successes: Array[Dictionary] = []
    var failures: Array[String] = []
    bridge.service_ready.connect(func(payload: Dictionary): successes.append(payload))
    bridge.service_failed.connect(func(_service: String, code: String): failures.append(code))

    var data := {"readOnly": true, "actionsEnabled": false, "service": "arena",
        "arenaTokens": 27, "rating": 1250, "currency": {"gold": 300, "ppa": 100}}
    var valid := {"ok": true, "readOnly": true, "gameId": "phoenix-pix-arena",
        "service": "arena", "version": 8, "data": data}
    bridge.requested_service = "arena"
    bridge._on_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(valid).to_utf8_buffer())
    if successes.size() != 1 or bridge.last_version != 8:
        fail("Genuine versioned read-only NPC data was not delivered")
        return

    var host := Control.new()
    host.size = Vector2(1280, 720)
    root.add_child(host)
    var npc := NPC.new()
    host.add_child(npc)
    npc.size = host.size
    npc.open_npc({"service": "arena", "id": "arena", "name": "Мечник арены"})
    await process_frame
    npc.apply_authoritative_snapshot(successes[0])
    await process_frame
    if not npc.has_verified_state or int(npc.authoritative.get("arenaTokens", -1)) != 27:
        fail("Arena NPC did not accept the real service token balance")
        return

    bridge.requested_service = "arena"
    var spoofed: Dictionary = valid.duplicate(true)
    spoofed["service"] = "merchant"
    bridge._on_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(spoofed).to_utf8_buffer())
    if successes.size() != 1 or failures.is_empty():
        fail("Client accepted an NPC response from the wrong service")
        return

    bridge.requested_service = "arena"
    var unsafe: Dictionary = valid.duplicate(true)
    unsafe["data"] = {"readOnly": true, "actionsEnabled": true}
    bridge._on_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(unsafe).to_utf8_buffer())
    if successes.size() != 1 or failures.size() < 2:
        fail("Client accepted unsafe purchase permissions from an NPC read route")
        return

    bridge.requested_service = "arena"
    bridge._on_completed(HTTPRequest.RESULT_SUCCESS, 404, PackedStringArray(), PackedByteArray())
    if failures.size() < 3 or failures[-1] != "HTTP_404":
        fail("Feature flag disabled must fail gracefully without a save")
        return
    if npc.service != "arena" or not npc.visible:
        fail("A disabled server feature must not close the NPC or freeze the game")
        return
    print("PPA_NATIVE_NPC_BRIDGE_OK original_save=1 service_id_checked=1 no_mutation=1 feature_flag_fallback=1 arena=1")
    quit()
