extends SceneTree

# Offline test: the Godot client MUST NOT interpret PvE preflight as a hit.
# No Cloudflare requests, actual game session, currency or damage mutations.
const INTENT = preload("res://scripts/ppa_native_pve_combat_intent.gd")
const REALTIME = preload("res://scripts/ppa_native_shared_realtime.gd")

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, reason: String) -> void:
    if not ok:
        push_error("PPA_NATIVE_PVE_INTENT_FAIL: " + reason)
        quit(1)
        assert(ok, reason)

func _run() -> void:
    var old_save := {"money":{"gold":140,"ppa":500,"gram":2},
        "bag":[{"uid":"godot-plus7","enh":7}], "hp":180}
    var before := JSON.stringify(old_save)
    var basic: Dictionary = INTENT.packet(
        "dungeon-1-20-i1","s0","qa_request_0123")
    check(basic == {"type":"dungeon-combat-intent",
        "room":"dungeon-1-20-i1","key":"s0",
        "action":"basic","requestId":"qa_request_0123"},
        "Basic intent included unverified damage/stats or lacked exact keys")
    var skill: Dictionary = INTENT.packet(
        "dungeon-21-40-i3","b40","qa_request_0124","skill","sword_slash")
    check(skill.get("skillId") == "sword_slash" and skill.size() == 6,
        "Skill request included extra server-owned values")
    for bad in [
        ["safe","s0","qa_request_0123","basic",""],
        ["dungeon-1-20","s0","qa_request_0123","basic",""],
        ["dungeon-1-20-i0","s0","qa_request_0123","basic",""],
        ["dungeon-1-20-i01","s0","qa_request_0123","basic",""],
        ["dungeon-1-20-i1","s0000","qa_request_0123","basic",""],
        ["dungeon-1-20-i1","not-existing","qa_request_0123","basic",""],
        ["dungeon-1-20-i1","s1","x","basic",""],
        ["dungeon-1-20-i1","s1","qa_request_0123","basic","sword_slash"],
        ["dungeon-1-20-i1","s1","qa_request_0123","skill","../slash"],
        ["dungeon-1-20-i1","s1","qa_request_0123","admin",""]
    ]:
        check(INTENT.packet(bad[0],bad[1],bad[2],bad[3],bad[4]).is_empty(),
            "Client created invalid PvE command: " + str(bad))
    var native := REALTIME.new()
    root.add_child(native)
    await process_frame
    var results: Array = []
    native.dungeon_preflight_checked.connect(
        func(value: Dictionary): results.append(value))
    check(not native.request_pve_preflight_for_qa("s0","qa_request_0123"),
        "Godot transmitted attack preflight without confirmed observer room")
    native._hello_received = true
    native._observer_only = true
    native._observer_requested_base = "dungeon-1-20"
    native._observer_room = "dungeon-1-20-i1"
    native._pve_preflight_pending["qa_request_0123"] = {
        "room":"dungeon-1-20-i1", "key":"s0","action":"basic"}
    var reply: Dictionary = {
        "type":"dungeon-combat-preflight","requestId":"qa_request_0123",
        "room":"dungeon-1-20-i1","key":"s0","action":"basic",
        "readOnly":true,"targetConfirmed":true,
        "canAttack":false,"reason":"SERVER_COMBAT_PROFILE_REQUIRED"}
    for forged in [
        {"room":"dungeon-1-20-i2"},
        {"key":"s1"},
        {"action":"skill"},
        {"readOnly":false},
        {"targetConfirmed":false},
        {"canAttack":true}
    ]:
        var response: Dictionary = reply.duplicate(true)
        response.merge(forged,true)
        native._handle_packet(response)
        check(results.is_empty() and native._pve_preflight_pending.size() == 1,
            "Forged preflight response was accepted: " + str(forged))
    native._handle_packet(reply)
    check(results.size() == 1 and results[0].get("canAttack") == false,
        "Read-only verified preflight response not handled")
    check(native._pve_preflight_pending.is_empty(),
        "Acknowledged preflight request remained pending")
    native._handle_packet(reply)
    check(results.size() == 1,
        "Replayed preflight acknowledged same request twice")
    native._pve_preflight_pending["qa_request_0124"] = {
        "room":"dungeon-1-20-i1", "key":"s1", "action":"skill"}
    native._handle_packet({
        "type":"dungeon-combat-preflight-rejected",
        "requestId":"qa_request_0124",
        "code":"SERVER_SKILL_NOT_READY","canAttack":false})
    check(results.size() == 2 and results[1].get("code") == "SERVER_SKILL_NOT_READY",
        "Canonical signed rejection was ignored")
    native._pve_preflight_pending["qa_request_0125"] = {
        "room":"dungeon-1-20-i1","key":"s1","action":"basic"}
    native._handle_packet({"type":"dungeon-observe-ended",
        "room":"safe","reason":"ROOM_EMPTY"})
    check(native._observer_room.is_empty() and native._pve_preflight_pending.is_empty(),
        "Closed dungeon left attack intent pending")
    native._handle_packet(reply)
    check(results.size() == 2 and JSON.stringify(old_save) == before,
        "Old combat response mutated game state or replayed after room close")
    native.disconnect_city()
    native.queue_free()
    await process_frame
    print("PPA_NATIVE_PVE_INTENT_OK strict_fields=1 valid_basic_skill=1 room_and_target_bound=1 forged_reply_blocked=1 replay_blocked=1 room_close_clears_pending=1 no_hp_or_currency_changes=1")
    quit(0)
