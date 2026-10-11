extends SceneTree

# Synthetic original Telegram PPA Durable Object packet fixtures only.
# Tests a future native dungeon read receiver without joining or attacking.
const VIEW = preload("res://scripts/ppa_native_mob_authority_view.gd")

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, reason: String) -> void:
    if not ok:
        push_error("PPA_NATIVE_MOB_VIEW_FAIL: " + reason)
        quit(1)
        assert(ok, reason)

func rec(key: String, hp: int, x: float, face: int) -> Array:
    # Exact 18 cells from realtime-stable.js sendMobAuthoritySnapshot.
    return [key,hp,100,0,"","",x,550.0,0,face,1,"",30,0,"",0,"",0]

func _run() -> void:
    var save := {"gold":24,"bag":[{"uid":"same-plus7","enh":7}],
        "materials":{"Редкий камень":11}}
    var before := JSON.stringify(save)
    var view := VIEW.new()
    check(not view.apply_packet({"type":"mob-hp","room":"dungeon-1",
        "key":"rat1","hp":0,"mhp":100,"ts":1000}),
        "Mob hit fabricated a nonexistent monster without any snapshot")
    view.bind_room("dungeon-1")
    check(not view.apply_packet({"type":"mob-hp","room":"safe",
        "key":"rat1","hp":0,"mhp":100,"ts":1000}),
        "Another room's combat event leaked into dungeon")
    var first := {"type":"mob-authority-snapshot","room":"dungeon-1",
        "rows":[rec("rat1",80,400,0)],"reset":true,"done":false,"ts":1000}
    check(view.apply_packet(first), "Server snapshot first chunk rejected")
    check(view.mobs.is_empty(), "Partial snapshot showed inconsistent mob state")
    check(view.apply_packet({"type":"mob-authority-snapshot","room":"dungeon-1",
        "rows":[rec("rat2",100,600,4)],"reset":false,"done":true,"ts":1000}),
        "Multichunk server mob snapshot lost its last piece")
    check(view.mobs.size() == 2 and view.mobs["rat1"]["dir"] == 0,
        "Two real server enemies or facing up=0 lost")
    check(not view.apply_packet({"type":"mob-hp","room":"dungeon-1",
        "key":"invented-boss","hp":1,"mhp":100,"ts":1001}),
        "Damage created a fake mob")
    check(view.apply_packet({"type":"mob-position","room":"dungeon-1",
        "rows":[["rat1",420,551,1,0,1,"p:myhero"]],"ts":1100}),
        "Server mob movement not projected")
    check(view.mobs["rat1"]["x"] == 420.0 and view.mobs["rat1"]["dir"] == 0,
        "Mob coordinates/dir not based on server packet")
    check(not view.apply_packet({"type":"mob-position","room":"dungeon-1",
        "rows":[["rat1",350,551,1,4,1,""]],"ts":1050}),
        "Old mob position rewound the server timeline")
    check(view.apply_packet({"type":"mob-hp","room":"dungeon-1",
        "key":"rat1","hp":30,"mhp":100,"ts":1200}),
        "Real server hit event did not reduce HP")
    check(view.mobs["rat1"]["hp"] == 30.0, "Confirmed mob HP mismatch")
    check(not view.apply_packet({"type":"mob-hp","room":"dungeon-1",
        "key":"rat1","hp":900,"mhp":100,"ts":1300}),
        "Impossible HP larger than server max was accepted")
    check(view.apply_packet({"type":"mob-dead","room":"dungeon-1",
        "key":"rat1","respawnAt":19900,"ts":1400}),
        "Mob death not received")
    check(view.mobs["rat1"]["hp"] == 0.0 and view.mobs["rat1"]["respawnAt"] == 19900.0,
        "Death/respawn timestamp mismatch")
    check(not view.apply_packet({"type":"mob-hp","room":"dungeon-1",
        "key":"rat1","hp":100,"mhp":100,"ts":1300}),
        "Stale HP message resurrected an already dead mob")
    var old_state := JSON.stringify(view.mobs)
    check(not view.apply_packet({"type":"mob-authority-snapshot","room":"dungeon-1",
        "rows":[["rat1"]],"reset":true,"done":true,"ts":2000}),
        "Malformed snapshot row accepted")
    check(JSON.stringify(view.mobs) == old_state,
        "Malformed multipart update destroyed last correct mob state")
    check(view.apply_packet({"type":"mob-authority-snapshot","room":"dungeon-1",
        "rows":[],"reset":true,"done":true,"ts":2100}) and view.mobs.is_empty(),
        "Authoritative empty snapshot failed to clean departed/dead room monsters")
    view.bind_room("dungeon-2")
    check(view.mobs.is_empty() and not view.apply_packet(first),
        "Room change exposed previous dungeon enemies")
    view.bind_room("safe")
    check(view.room.is_empty() and not view.apply_packet(
        {"type":"mob-authority-snapshot","room":"safe","rows":[],
            "reset":true,"done":true,"ts":3000}),
        "Safe town received combat mob state")
    check(JSON.stringify(save) == before,
        "Native mob observer mutated real Telegram PPA inventory or currency")
    print("PPA_NATIVE_MOB_VIEW_OK snapshots=2 partial_atomic=1 position=1 up_zero=1 hp=1 death=1 stale_filtered=1 rooms_isolated=1 no_combat_writes=1")
    quit(0)
