extends SceneTree

# Tested against the same D1 field contracts as src/native-npc-readonly.js.
# Offline only: no linked account, live backend, purchases or save mutations.
const PLAYER = preload("res://scripts/ppa_verified_player_projection.gd")
const HUD = preload("res://scripts/ppa_combat_hud.gd")
const NPC = preload("res://scripts/ppa_npc_screen.gd")

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, why: String) -> void:
    if not ok:
        push_error("PPA_VERIFIED_PLAYER_FAIL: " + why)
        quit(1)
        assert(ok, why)

func has_label(node: Node, term: String) -> bool:
    for label in node.find_children("*", "Label", true, false):
        if str(label.text).contains(term):
            return true
    return false

func _run() -> void:
    var save := {
        "lvl":21, "stats":{"hp":8000,"mp":9000},
        "pvp":{"rating":1360,"wins":13,"losses":0,"attemptsRemaining":2},
        "arenaTokens":18,
    }
    var before := JSON.stringify(save)
    var none: Dictionary = PLAYER.vitals(save)
    check(none["hp"] == null and none["mp"] == null,
        "Base stat points were invented as live HP/MP")
    check(PLAYER.arena(save) == {
        "rating":1360.0,"wins":13.0,"losses":0.0,"attemptsRemaining":2.0
    }, "Verified D1 PVP fields not projected")
    var root_data := {"hp":345,"maxHp":890,"mp":10,"maxMp":60,"xp":8,"xpNext":200}
    var v: Dictionary = PLAYER.vitals(root_data)
    check(v["hp"] == 345.0 and v["maxHp"] == 890.0 and
        v["mp"] == 10.0 and v["maxMp"] == 60.0, "Root saved vitals lost")
    var nested := {"vitals":{"currentHp":7,"maxHp":90,"currentMp":0,"maxMp":50}}
    v = PLAYER.vitals(nested)
    check(v["hp"] == 7.0 and v["mp"] == 0.0 and v["maxMp"] == 50.0,
        "Explicit verified vitals missing or legitimate zero lost")
    check(PLAYER.vitals({"vitals":{"currentHp":-1,"maxHp":"999"}})["hp"] == null,
        "Invalid/non-authoritative values were accepted")

    var host := Control.new()
    host.size = Vector2(1280, 720)
    root.add_child(host)
    var hud := HUD.new()
    host.add_child(hud)
    hud.size = host.size
    await process_frame
    hud.apply_server_save(save)
    check(hud._hp_text.text == "—" and hud._mp_text.text == "—",
        "HUD fabricated health from character attributes")
    hud.apply_server_save(nested)
    check(hud._hp_text.text == "7/90" and hud._mp_text.text == "0/50",
        "HUD failed to display verified current/max from signed save")
    hud.clear_server_save()
    check(hud._hp_text.text == "—", "Old player's HUD remained after logout")

    var npc := NPC.new()
    host.add_child(npc)
    npc.size = host.size
    npc.apply_player_save_readonly(save)
    npc.open_npc({"service":"arena","name":"Мечник арены"})
    await process_frame
    check(has_label(npc, "1360") and has_label(npc, "13 / 0"),
        "Arena NPC did not show the confirmed original PPA D1 rating/wins")
    check(has_label(npc, "2") and has_label(npc, "18"),
        "D1 arena attempts or tokens lost without native NPC route")
    npc.close_npc()
    npc.apply_player_save_readonly({})
    npc.open_npc({"service":"arena","name":"Мечник арены"})
    check(has_label(npc, "нет подтверждённого статуса арены"),
        "Unknown PPA arena stats were presented as real zeros")
    check(JSON.stringify(save) == before, "Native projections mutated D1 save")
    host.queue_free()
    await process_frame
    print("PPA_VERIFIED_PLAYER_OK hp_real_only=1 live_missing_is_unknown=1 pvp_from_d1=1 npc_404_safe=1 no_writes=1")
    quit(0)
