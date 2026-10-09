extends SceneTree

# Validate only public approved skill/rune definition mapping + synthetic
# counts. Never touches real characters, tokens, DB or backend endpoints.
const VIEW = preload("res://scripts/ppa_server_inventory_view.gd")
const SCREEN = preload("res://scripts/ppa_character_screen.gd")
const BOOKS = preload("res://scripts/ppa_grimoire_catalog_generated.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(why: String) -> void:
    push_error("PPA_NATIVE_SKILL_RUNE_VIEW_FAIL: " + why)
    quit(1)

func _run() -> void:
    var source := {
        "lvl": 12, "rebirths": 0, "classKey": "archer",
        "skillRanks": {"arch_piercing_shot": 2},
        "grimoires": {"arch_piercing_shot": 4},
        "grimoireRankDrops": {"arch_piercing_shot": {"2":2,"3":1}},
        "runes": {"strength|rare": 3, "health|common": 1},
        "runeSlots": ["strength|uncommon", null],
        "runeProgress": {"levelSlots": 1, "rebirthSlots": 0}
    }
    var hero := SCREEN.new()
    hero.class_key = "archer"
    var projection: Dictionary = hero._project_server_skill_cards(source)
    var active: Array = projection.get("active", [])
    var passive: Array = projection.get("passive", [])
    if active.size() != 4 or passive.size() != 5:
        _fail("Expected all four active and five passive canonical Archer cards")
        return
    var skill: Dictionary = active[0]
    if str(skill.get("id", "")) != "arch_piercing_shot" or int(skill.get("rank", -1)) != 2:
        _fail("Actual Archer rank not restored from server skillRanks")
        return
    if int(skill.get("book1", -1)) != 1 or int(skill.get("book2", -1)) != 2 or int(skill.get("book3", -1)) != 1:
        _fail("Original Telegram book rank count did not match D1 grimoireRankDrops")
        return
    var rune_view: Dictionary = VIEW.rune_view_from_save(source)
    var available: Array = rune_view.get("inventory", [])
    var equipped: Array = rune_view.get("slots", [])
    if int(rune_view.get("unlocked", -1)) != 1:
        _fail("Level 12 must unlock one rune slot")
        return
    if available.size() != 2 or equipped.size() != 10:
        _fail("Runes must read separate save.runes and save.runeSlots, NOT save.bag")
        return
    if str((equipped[0] as Dictionary).get("name", "")) != "Руна Силы":
        _fail("Official equipped stat rune type mapping missing")
        return
    var total := 0
    for raw in available:
        total += int((raw as Dictionary).get("count", 0))
    if total != 4:
        _fail("Real rune stack quantities lost")
        return
    if VIEW.rune_definition("unknown|rare").size() != 0:
        _fail("Unknown rune key should fail closed")
        return
    hero.free()
    print("PPA_NATIVE_SKILL_RUNE_VIEW_OK canonical_9=1 rank_1_to_5=1 exact_books=1 real_rune_slots=1 writes=0")
    quit(0)
