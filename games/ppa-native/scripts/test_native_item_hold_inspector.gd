extends SceneTree

# Godot 4.6 offline UI regression for original PPA:
# press 1 s to inspect until release; short tap opens item menu; gear actions
# require signed same-owner inventory and never modify the local save.
const NPC = preload("res://scripts/ppa_npc_screen.gd")
const OWNER := "990000001"

func check(ok: bool, detail: String) -> void:
    if not ok:
        push_error("PPA_ITEM_HOLD_FAIL: " + detail)
        quit(1)
        assert(ok, detail)

func _initialize() -> void:
    call_deferred("_run")

func has_label(root_node: Node, phrase: String) -> bool:
    for label in root_node.find_children("*", "Label", true, false):
        if str(label.text).contains(phrase):
            return true
    return false

func _release(inspector: Control) -> void:
    var event := InputEventScreenTouch.new()
    event.pressed = false
    event.index = 0
    inspector._input(event)

func _run() -> void:
    set_meta("phoenix_account", {"telegramId":OWNER})
    remove_meta("ppa_native_game_session")
    var host := Control.new()
    host.size = Vector2(800, 1300)
    root.add_child(host)
    var npc := NPC.new()
    npc.size = host.size
    host.add_child(npc)
    var weapon := {"uid":"auth-gear","name":"Меч испытателя",
        "kind":"gear","slot":"weapon","rarity":"epic","enh":4,
        "attack":18}
    var stone := {"name":"Обычный камень заточки","kind":"stone",
        "ppa_native_virtual":true,"count":7}
    var before := JSON.stringify(weapon)
    npc.apply_player_save_readonly({"bag":[weapon],"stones":{"normal":7}})
    npc.open_npc({"service":"forge","name":"Кузнец"})
    await process_frame
    var inspector: Control = npc._item_hold
    var grid := npc._forge_inventory_host.find_child("PPAForgeInventoryGrid", true, false) as GridContainer
    check(grid != null and grid.get_child_count() == 100, "Forge inventory unavailable")
    var icon := grid.get_child(0) as Button
    check(icon != null and not icon.disabled and
        icon.get_meta("ppa_inspect_origin", "") == "bag",
        "Owned icon is not inspectable")
    icon.button_down.emit()
    check(not inspector.is_open(), "Hold preview opened before 1 second")
    inspector._hold_timeout()
    check(inspector.is_open() and inspector._temporary,
        "One second press must show temporary item characteristics")
    check(has_label(inspector, "Атака: 18"), "Inspector failed to show authentic item attack")
    check(has_label(inspector, "Отпусти палец"), "Hold preview must explain release")
    check(inspector.find_child("PPAInspectorEquipmentAction", true, false) == null,
        "Temporary hold cannot contain a spending action")
    _release(inspector)
    check(not inspector.is_open(), "Item preview did not close on release")

    icon.button_down.emit()
    _release(inspector)
    check(inspector.is_open() and not inspector._temporary,
        "Short tap must pin the item menu instead of waiting one second")
    var action := inspector.find_child("PPAInspectorEquipmentAction", true, false) as Button
    check(action != null and action.text == "НАДЕТЬ" and action.disabled,
        "Unsigned item must show the equip label but not allow mutation")
    check(not has_label(inspector, "Назад к персонажу"),
        "Mini item panel must not contain a Back to Character button")
    inspector.dismiss()

    var sent: Array = []
    npc.inventory_action_requested.connect(func(fields: Dictionary): sent.append(fields.duplicate(true)))
    npc.apply_native_inventory({"ok":true,"gameId":"phoenix-pix-arena",
        "contract":"ppa-inventory-v1","ownerId":OWNER,
        "actions":["equip","unequip"],
        "state":{"connected":true,"self":{"id":OWNER},"version":14,
            "bag":[weapon],
            "equipped":{"weapon":{"uid":"worn-gear","slot":"weapon",
                "name":"Копьё защитника","rarity":"rare","enh":3}}}})
    grid = npc._forge_inventory_host.find_child("PPAForgeInventoryGrid", true, false) as GridContainer
    icon = grid.get_child(0) as Button
    icon.button_down.emit()
    _release(inspector)
    action = inspector.find_child("PPAInspectorEquipmentAction", true, false) as Button
    check(action != null and action.text == "НАДЕТЬ" and not action.disabled,
        "Matching signed bag UID should enable Equip inside the item menu")
    action.pressed.emit()
    check(sent == [{"action":"equip","uid":"auth-gear","version":14}],
        "Equip menu did not send original server UID and version")
    check(JSON.stringify(weapon) == before and
        npc.inventory_state["bag"][0]["uid"] == "auth-gear",
        "Client changed local equipment before server confirmation")

    inspector._show_item(npc.inventory_state["equipped"]["weapon"], "equipped", false)
    action = inspector.find_child("PPAInspectorEquipmentAction", true, false) as Button
    check(action != null and action.text == "СНЯТЬ" and not action.disabled,
        "Worn gear must show Remove in its own item menu")
    action.pressed.emit()
    check(sent.size() == 2 and sent[1] ==
        {"action":"unequip","slot":"weapon","version":14},
        "Remove menu did not send authenticated equipped slot")

    inspector._show_item(stone, "resource", false)
    check(inspector.find_child("PPAInspectorEquipmentAction", true, false) == null
        and has_label(inspector, "Количество: 7"),
        "Resource mini menu must show count without an Equip/Remove command")

    set_meta("phoenix_account", {"telegramId":"990000002"})
    inspector._show_item(weapon, "bag", false)
    action = inspector.find_child("PPAInspectorEquipmentAction", true, false) as Button
    check(action != null and action.disabled,
        "Inspector leaked previous account permissions after account switch")
    inspector.dismiss()
    npc.close_npc()
    check(not inspector.is_open(), "Closing NPC left item menu covering screen")
    host.queue_free()
    await process_frame
    remove_meta("phoenix_account")
    print("PPA_ITEM_HOLD_OK one_second=1 release=1 short_tap=1 stats=1 equip=1 unequip=1 stone=1 same_owner=1")
    quit(0)
