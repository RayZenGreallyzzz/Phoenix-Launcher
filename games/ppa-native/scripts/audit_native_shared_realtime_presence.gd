extends SceneTree

# No external WebSocket, only original PPA online packet handling + opt-in UI.
const ONLINE = preload("res://scripts/ppa_native_shared_realtime.gd")
const NPC = preload("res://scripts/ppa_npc_screen.gd")

func _initialize() -> void:
    call_deferred("_run")

func fail(message: String) -> void:
    push_error("PPA_NATIVE_REALTIME_PRESENCE_FAIL: " + message)
    quit(1)

func _run() -> void:
    var client := ONLINE.new()
    root.add_child(client)
    await process_frame
    var counts := {"total": -1, "safe": -1, "changed": 0}
    var errors: Array[String] = []
    client.presence_changed.connect(func(n: int, safe: int):
        counts["total"] = n
        counts["safe"] = safe
        counts["changed"] = int(counts["changed"]) + 1
    )
    client.presence_failed.connect(func(m: String): errors.append(m))
    client._handle_packet({"type": "online", "count": 31, "roomCount": 9})
    if counts["total"] != 31 or counts["safe"] != 9:
        fail("Server online packet did not map to visible Godot presence")
        return
    client._handle_packet({"type": "snapshot", "roomCount": 10, "players": [{"i": "p:fake"}]})
    if counts["safe"] != 10 or counts["changed"] != 2:
        fail("Room population snapshot was not consumed")
        return

    var host := Control.new()
    host.size = Vector2(1280, 720)
    root.add_child(host)
    var npc := NPC.new()
    host.add_child(npc)
    npc.size = host.size
    var requested := {"count": 0}
    npc.native_realtime_requested.connect(func(): requested["count"] += 1)
    npc.open_npc({"service": "arena", "id": "arena", "name": "Мечник арены"})
    await process_frame
    var button := npc.find_child("NpcRealtimePresenceConnect", true, false) as Button
    if button == null or button.disabled:
        fail("Player cannot intentionally opt in from arena NPC")
        return
    button.pressed.emit()
    if int(requested["count"]) != 1:
        fail("Presence must be requested from exactly one explicit user action")
        return
    npc.set_online_presence(31, 10)
    if not "31" in npc.native_online_status or not "10" in npc.native_online_status:
        fail("Arena NPC did not show actual online counts")
        return
    # No session means no network request and no Telegram WebSocket eviction.
    client.connect_explicitly()
    if client.peer != null or errors.is_empty():
        fail("Native online attempted to connect without Phoenix account")
        return
    print("PPA_SHARED_REALTIME_PRESENCE_OK same_hub_protocol=1 opt_in_only=1 no_combat_writes=1 online=31 safe=10")
    quit()
