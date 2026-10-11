extends SceneTree

# Pure offline checks against REAL NPC formatter; no token, network or saves.
const NPC = preload("res://scripts/ppa_npc_screen.gd")

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, description: String) -> void:
    if not ok:
        push_error("PPA_FORGE_MATERIAL_VIEW_FAIL: " + description)
        quit(1)
        assert(ok, description)

func _run() -> void:
    var forge := NPC.new()
    forge.service = "forge"
    forge.has_verified_state = true
    # Full save is older than this signed, versioned forge projection.
    forge._player_view_readonly = {"money":{"ppa":99999}}
    forge._player_save_readonly = {
        "materials":{"Кристалл Бездны":9, "Руда":6},
        "feathers":{"phoenix":30}
    }
    forge.authoritative = {
        "service":"forge", "readOnly":true,
        "currency":{"ppa":77},
        "materials":{"Кристалл Бездны":2,"Руда":0},
        "feathers":{"phoenix":3},
        "saveVersion":12
    }
    check(forge._forge_owned_material("Кристалл Бездны") == 2,
        "Must show newest signed material quantity, not stale player save")
    check(forge._forge_owned_material("Руда") == 0, "Known zero must remain zero")
    check(forge._forge_owned_material("Перо Феникса") == 3,
        "Phoenix feathers must come from signed forge projection")
    check(forge._forge_owned_material("Несуществующий") == null,
        "Do not guess missing material quantity")
    forge.authoritative["materials"] = null
    check(forge._forge_owned_material("Кристалл Бездны") == null,
        "Unknown server materials must not revive a stale cache")
    forge.authoritative.clear()
    forge.has_verified_state = false
    check(forge._forge_owned_material("Кристалл Бездны") == 9,
        "Older verified save fallback still works without forge API")
    check(forge._forge_owned_material("Перо Феникса") == 30,
        "Old verified save feather fallback still works")
    check(forge.has_signal("authoritative_state_requested"),
        "Every NPC must support a server refresh")
    print("PPA_FORGE_MATERIALS_CLIENT_OK owner_view=1 source=1 no_fake_stock=1")
    forge.free()
    quit(0)
