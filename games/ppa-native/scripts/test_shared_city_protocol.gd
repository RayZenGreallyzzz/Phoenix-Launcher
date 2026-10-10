extends SceneTree

const PROTOCOL = preload("res://scripts/ppa_shared_city_protocol.gd")
const CLIENT = preload("res://scripts/ppa_native_shared_realtime.gd")
const PLAYERS = preload("res://scripts/ppa_shared_city_players.gd")
const SELF := "p:0123456789abcdef0123456789abcdef"
const OTHER := "p:abcdef0123456789abcdef0123456789"

class CityHost extends Control:
    var viewport_3d: SubViewport
    var city_world := Control.new()
    var _modal_world_frozen := false
    func _ready() -> void:
        add_child(city_world)
    func _screen_to_ground(point: Vector2) -> Vector3:
        return Vector3(point.x, 0.0, point.y)

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, message: String) -> void:
    if not ok:
        push_error("SHARED_CITY_TEST_FAIL: " + message)
        quit(1)
        assert(ok, message)

func _run() -> void:
    check(PROTOCOL.valid_pid(SELF), "Original opaque pid rejected")
    check(not PROTOCOL.valid_pid("p:fake"), "Invalid pid accepted")
    check(not PROTOCOL.valid_pid(SELF.replace("a", "z")), "Non-hex pid accepted")
    var up := PROTOCOL.position_packet(Vector2(1395, 1463), Vector2.UP, "run")
    check(up.get("f") == 0 and up.get("room") == "safe", "Up=0 or room mismatch")
    check(PROTOCOL.position_packet(Vector2(3, 4), Vector2.DOWN, "idle").get("f") == 4, "Down direction mismatch")
    check(PROTOCOL.position_packet(Vector2(-1, 0), Vector2.UP, "run").is_empty(), "Bad pixel coordinates sent")
    for forbidden in ["h", "m", "dead", "at", "df", "damage", "amount", "c", "save", "inventory"]:
        check(not up.has(forbidden), "Movement contains health/combat/economy field")

    var client := CLIENT.new()
    root.add_child(client)
    await process_frame
    var received: Array = []
    var departures: Array = []
    var clears := {"count":0}
    var counts := {"total":-1, "room":-1}
    client.players_updated.connect(func(rows: Array): received.append_array(rows))
    client.player_left.connect(func(pid: String): departures.append(pid))
    client.players_cleared.connect(func(): clears["count"] += 1)
    client.presence_changed.connect(func(total: int, room: int): counts["total"] = total; counts["room"] = room)
    client._ticket_pid = SELF
    client._handle_packet({"type":"hello", "pid":SELF, "serverRoom":"safe"})
    check(client.self_pid == SELF, "Ticket and hello identity not bound")
    var row := {"i":OTHER, "r":"safe", "x":1400.0, "y":1463.0,
        "c":"gnome", "n":"Telegram Hero", "cn":"Clan", "f":0, "a":"run", "q":1}
    client._handle_packet({"type":"online", "count":2, "roomCount":2})
    client._handle_packet({"type":"snapshot", "room":"safe", "roomCount":2, "players":[row, {"i":SELF}]})
    check(received.size() == 1 and received[0]["i"] == OTHER, "Snapshot or self filtering failed")
    check(counts["total"] == 2 and counts["room"] == 2, "Online counts lost")
    client._handle_packet({"type":"snapshot", "room":"safe", "roomCount":2, "players":[]})
    check(client._players.size() == 1, "Temporary empty snapshot deleted a live peer")
    var moved := row.duplicate()
    moved["x"] = 1410.0
    moved["q"] = 2
    client._handle_packet({"type":"move", "room":"safe", "player":moved})
    client._handle_packet({"type":"move", "room":"safe", "player":row})
    client._handle_packet({"type":"move", "room":"dungeon-1", "player":moved})
    check(received.size() == 2 and client._players[OTHER]["x"] == 1410.0, "Stale/foreign-room move accepted")
    var spoof := moved.duplicate()
    spoof["x"] = "bad"
    client._handle_packet({"type":"move", "room":"safe", "player":spoof})
    check(received.size() == 2, "Malformed remote position accepted")
    client._handle_packet({"type":"leave", "room":"safe", "id":OTHER})
    check(client._players.is_empty() and departures == [OTHER], "Leave did not remove original pid")
    client._handle_packet({"type":"player-position-ack", "room":"safe", "x":1395.0, "y":1463.0})
    check(client._position_ready, "Server position acceptance required")
    client.disconnect_city()
    check(not client._hello_received and not client._position_ready and clears["count"] == 1, "Disconnect retained another account")
    client.refresh_clan_identity_if_connected()
    check(not client._wanted and client.peer == null and not client.connecting, "Clan menu restarted a disconnected/replaced hero")
    # No session means no HTTP request/WebSocket, even after an explicit tap.
    client.connect_explicitly()
    check(client.peer == null and not client.connecting and not client._wanted, "Missing-session connection attempted")

    var host := CityHost.new()
    host.size = Vector2(1280, 720)
    host.city_world.position = Vector2(-760, -1100)
    root.add_child(host)
    var view := PLAYERS.new()
    view.render_models = false
    host.add_child(view)
    view.bind_world(host)
    view.update_players([row])
    check(view.entries.size() == 1, "Remote view did not create one player")
    view.update_players([moved])
    check(view.entries.size() == 1, "Remote move duplicated model/label")
    view._process(0.12)
    check(view.entries[OTHER]["label"].text == "[Clan]\nTelegram Hero", "Clan/nickname rendering lost")
    view.remove_player(OTHER)
    check(view.entries.is_empty(), "Remote view cleanup failed")
    view.clear_players()
    print("PPA_SHARED_CITY_PROTOCOL_OK pid_bound=1 safe_only=1 up_zero=1 no_health_fields=1 snapshot_move_leave=1 stale_filtered=1 cleanup=1")
    quit()
