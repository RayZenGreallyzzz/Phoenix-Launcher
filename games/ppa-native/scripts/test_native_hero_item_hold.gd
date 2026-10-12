extends SceneTree

# Hero inventory shares the same hold-to-preview and signed gear actions as
# the blacksmith. No local stash writes or production API calls are made.
const HERO = preload("res://scripts/ppa_character_screen.gd")
const OWNER := "990000001"

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, detail: String) -> void:
    if not ok:
        push_error("PPA_HERO_ITEM_MENU_FAIL: " + detail)
        quit(1)
        assert(ok, detail)

func _release(inspector: Control) -> void:
    var e := InputEventScreenTouch.new()
    e.index = 0
    e.pressed = false
    inspector._input(e)

func _run() -> void:
    set_meta("phoenix_account", {"telegramId":OWNER})
    var host := Control.new()
    host.size = Vector2(800, 1280)
    root.add_child(host)
    var screen := HERO.new()
    host.add_child(screen)
    screen.size = host.size
    await process_frame
    var gear := {"uid":"hero-gear-1","name":"Доспех мага","slot":"armor",
        "kind":"gear","rarity":"epic","enh":3,"stats":{"def":35}}
    var equipped := {"uid":"hero-worn-1","name":"Броня мага +2",
        "slot":"weapon","rarity":"rare","enh":2}
    screen.apply_readonly_save({"bag":[gear],"equipped":{"weapon":equipped},
        "stones":{"normal":5}})
    screen.open_index(0)
    await process_frame
    var bag := screen.find_child("OriginalPPABagGrid", true, false) as GridContainer
    check(bag != null and bag.get_child_count() == 100,
        "Original hero inventory is missing")
    var first := bag.get_child(0) as Button
    var inspector: Control = screen._item_hold_view
    check(first != null and first.has_meta("ppa_inspect_origin"),
        "Hero bag item is not connected to one-second shared inspector")
    first.button_down.emit()
    inspector._hold_timeout()
    check(inspector.is_open() and inspector._temporary,
        "Hero must show item stats after one-second hold")
    _release(inspector)
    check(not inspector.is_open(), "Hero hold preview stayed open after finger lifted")

    first.button_down.emit()
    _release(inspector)
    check(inspector.is_open() and not screen._item_overlay.visible,
        "Hero short tap must show mini panel instead of old character page")
    var action := inspector.find_child("PPAInspectorEquipmentAction", true, false) as Button
    check(action != null and action.text == "НАДЕТЬ" and action.disabled,
        "Hero equipment must not be enabled until signed server state arrives")

    var emitted: Array = []
    screen.inventory_action_requested.connect(func(fields: Dictionary): emitted.append(fields.duplicate(true)))
    screen.apply_native_inventory({"ok":true,"gameId":"phoenix-pix-arena",
        "contract":"ppa-inventory-v1","ownerId":OWNER,"actions":["equip","unequip"],
        "state":{"self":{"id":OWNER},"version":41,"bag":[gear],
            "equipped":{"weapon":equipped}}})
    check(not inspector.is_open(),
        "New authoritative state must dismiss old item menu before refresh")
    first.button_down.emit()
    _release(inspector)
    action = inspector.find_child("PPAInspectorEquipmentAction", true, false) as Button
    check(action != null and action.text == "НАДЕТЬ" and not action.disabled,
        "Signed hero gear must show actionable Equip")
    action.pressed.emit()
    check(emitted.size() == 1 and emitted[0] ==
        {"action":"equip","uid":"hero-gear-1","version":41},
        "Hero equip must preserve owner-bound UID and server version")

    inspector._show_item(equipped, "equipped", false)
    action = inspector.find_child("PPAInspectorEquipmentAction", true, false) as Button
    check(action != null and action.text == "СНЯТЬ" and not action.disabled,
        "Worn hero gear must show Remove")
    action.pressed.emit()
    check(emitted.size() == 2 and emitted[1] ==
        {"action":"unequip","slot":"weapon","version":41},
        "Hero removal must call server slot action")

    set_meta("phoenix_account", {"telegramId":"990000002"})
    inspector._show_item(gear, "bag", false)
    action = inspector.find_child("PPAInspectorEquipmentAction", true, false) as Button
    check(action != null and action.disabled,
        "Hero menu leaked action permission to another character")
    screen.clear_readonly_save()
    check(not inspector.is_open() and screen._authorized_inventory.is_empty(),
        "Character switch kept stale gear permissions")
    host.queue_free()
    await process_frame
    remove_meta("phoenix_account")
    print("PPA_HERO_ITEM_MENU_OK hold=1 release=1 tap=1 same_owner=1 equip=1 unequip=1 no_local_spend=1")
    quit(0)
