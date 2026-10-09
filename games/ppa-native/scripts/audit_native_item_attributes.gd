extends SceneTree

# No player secrets or live D1 access. Verify the EXACT nested item stats
# structure of approved Telegram PPA gear + original root save currencies.
const ATTR = preload("res://scripts/ppa_item_attribute_view.gd")
const VIEWS = preload("res://scripts/ppa_shared_save_views.gd")
const SCREEN = preload("res://scripts/ppa_character_screen.gd")

func _initialize() -> void:
    call_deferred("_audit")

func _fail(why: String) -> void:
    push_error("PPA_ITEM_ATTRIBUTES_FAIL: " + why)
    quit(1)

func _audit() -> void:
    var real_item := {
        "name":"Броня ассасина", "rarity":"common", "enh":3,
        "stats":{"def":38,"hp":120,"magicResist":5,"critDmg":12},
        "kind":"gear", "uid":"nonpublic-test-uid"}
    var rows: Array = ATTR.lines_for_item(real_item)
    for expected in ["Заточка: 3","Защита: 38","HP: 120","Магическая защита: 5","Крит. урон: 12"]:
        if not rows.has(expected):
            _fail("Actual original PPA nested stats are missing: " + expected)
            return
    var resource := {"name":"Демонический кристалл", "count":4,
        "useText":"Крафтовый материал для кузнеца"}
    var resource_rows: Array = ATTR.lines_for_item(resource)
    if not resource_rows.has("Описание: Крафтовый материал для кузнеца"):
        _fail("Real PPA resource useText absent in native popup")
        return
    var currencies := VIEWS.money({"gold":1234,"gram":2.25,"ppa":987})
    if currencies.get("gold") != 1234 or currencies.get("gram") != 2.25 or currencies.get("ppa") != 987:
        _fail("Original Telegram save gold/ppa/gram not shown")
        return
    var missing := VIEWS.money({})
    if missing.get("gram",0) != null or missing.get("gold",0) != null:
        _fail("Missing currency must display as unknown, not fabricated zero")
        return
    var root := Control.new()
    root.size = Vector2(800,1280)
    get_root().add_child(root)
    var screen := SCREEN.new()
    root.add_child(screen)
    screen.size = Vector2(800,1280)
    await process_frame
    var overlay := screen.get_node_or_null("PPAOriginalCharacterItemDetail")
    if overlay == null:
        _fail("Item popup must be sibling of character frame, not stretched inside PanelContainer")
        return
    var popup := overlay.find_child("PPACompactItemDetailsPopup",true,false)
    if popup == null:
        _fail("New fixed-height scrollable item popup missing")
        return
    print("PPA_REAL_ITEM_LONG_PRESS_ATTRIBUTES_OK nested_stats=1 source_currencies=3 centered_popup=1 no_writes=1")
    quit(0)
