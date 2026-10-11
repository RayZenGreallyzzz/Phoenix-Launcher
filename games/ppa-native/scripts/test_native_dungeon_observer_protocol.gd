extends SceneTree

# Offline signed-message replay; does not request a live ticket, join a DO,
# alter a save, enable any write flag or give the Godot hero dungeon combat.
const OBSERVE = preload("res://scripts/ppa_dungeon_observer_protocol.gd")
const REALTIME = preload("res://scripts/ppa_native_shared_realtime.gd")

func _initialize() -> void:
    call_deferred("_run")

func check(value: bool, message: String) -> void:
    if not value:
        push_error("PPA_DUNGEON_OBSERVER_PROTOCOL_FAIL: " + message)
        quit(1)
        assert(value, message)

func _run() -> void:
    var save := {"gold":320, "gram":7, "bag":[{"uid":"plus7","enh":7}]}
    var saved := JSON.stringify(save)
    for base in OBSERVE.ALLOWED_BASES:
        check(OBSERVE.allowed_base(base), "An original dungeon tier was denied")
        check(OBSERVE.room_of(base, base + "-i1"), "Valid server instance rejected")
    check(not OBSERVE.allowed_base("worldboss") and not OBSERVE.allowed_base("dungeon-9"),
        "Arbitrary scene got observer permission")
    for bad in ["dungeon-1-20", "dungeon-1-20-i0",
        "dungeon-1-20-i01", "dungeon-21-40-i1", "dungeon-1-20-i2/other"]:
        check(not OBSERVE.room_of("dungeon-1-20", bad),
            "Client chose an invalid or foreign server dungeon instance")
    var fake := {"type":"dungeon-observe-assigned","readOnly":true,
        "actionsEnabled":false, "base":"dungeon-1-20", "room":"dungeon-1-20-i2"}
    check(OBSERVE.assignment(fake,"dungeon-1-20") == "dungeon-1-20-i2",
        "Original server room was not accepted")
    check(OBSERVE.assignment(fake,"dungeon-21-40") == "",
        "Another character's dungeon base was treated as this one")
    for forbidden in [
        {"readOnly":false}, {"actionsEnabled":true}, {"room":"dungeon-1-20-i0"},
        {"room":"dungeon-21-40-i1"}, {"base":"dungeon-41-60"}
    ]:
        var item: Dictionary = fake.duplicate(true)
        item.merge(forbidden, true)
        check(OBSERVE.assignment(item,"dungeon-1-20") == "",
            "Read-write or forged dungeon assignment was accepted")
    var native := REALTIME.new()
    root.add_child(native)
    await process_frame
    native._hello_received = true
    native._observer_only = true
    native._observer_requested_base = "dungeon-1-20"
    var assignments: Array = []
    var packets: Array = []
    var ends: Array = []
    native.dungeon_observer_assigned.connect(func(room: String): assignments.append(room))
    native.dungeon_observer_event.connect(func(packet: Dictionary): packets.append(packet))
    native.dungeon_observer_ended.connect(func(reason: String): ends.append(reason))
    native._handle_packet(fake)
    check(assignments == ["dungeon-1-20-i2"] and native._observer_room == "dungeon-1-20-i2",
        "Native websocket did not bind to the server-confirmed room")
    native._handle_packet({"type":"mob-hp","room":"dungeon-1-20-i2",
        "key":"s0","hp":27,"mhp":100,"ts":1200})
    check(packets.size() == 1 and packets[0]["hp"] == 27,
        "A legitimate server mob HP event was lost")
    native._handle_packet({"type":"mob-hp","room":"dungeon-1-20-i8",
        "key":"s0","hp":999,"mhp":999,"ts":1300})
    native._handle_packet({"type":"mob-hit-event","room":"dungeon-1-20-i2",
        "key":"s0","amount":9999,"ts":1300})
    native._handle_packet({"type":"mob-hp","room":"dungeon-1-20-i2",
        "key":"s0","hp":999,"mhp":999})
    check(packets.size() == 1,
        "Forged, cross-room or un-timestamped gameplay event entered Godot")
    native._handle_packet({"type":"dungeon-observe-ended","room":"safe",
        "reason":"ROOM_EMPTY"})
    check(native._observer_room == "" and ends == ["ROOM_EMPTY"],
        "Server ended observer but client retained the previous instance")
    native._handle_packet({"type":"mob-dead","room":"dungeon-1-20-i2",
        "key":"s0","ts":1400})
    check(packets.size() == 1,
        "Old dungeon events were accepted after observer end")
    check(JSON.stringify(save) == saved,
        "Read-only observer modified D1 currency/gear")
    native.disconnect_city()
    native.queue_free()
    await process_frame
    print("PPA_DUNGEON_OBSERVER_PROTOCOL_OK signed_room=1 tiers=3 read_only=1 no_attack=1 cross_room=blocked end_clears_state=1 no_save_writes=1")
    quit(0)
