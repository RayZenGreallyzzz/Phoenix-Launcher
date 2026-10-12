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
    # The previous Android build drew the forge's stack quantity twice:
    # generic PPARealQty (×7) over PPAForgeVirtualStackCount (7).
    var stone_cell := grid.get_child(1) as Button
    check(stone_cell != null and bool(stone_cell.get_meta("ppa_suppress_icon_qty", false))
        and stone_cell.clip_contents and
        stone_cell.find_child("PPAForgeVirtualStackCount", true, false) != null,
        "Forge resource must have ONE own badge and clip image within slot")
    var item_icon_loader := preload("res://scripts/ppa_item_icon_loader.gd").new()
    host.add_child(item_icon_loader)
    var fake_texture := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
    stone_cell.set_meta("ppa_icon_path", "test-stone.png")
    stone_cell.set_meta("ppa_icon_qty", 7)
    stone_cell.set_meta("ppa_icon_virtual", true)
    item_icon_loader._show_icon(stone_cell, "test-stone.png", fake_texture)
    check(stone_cell.find_child("PPARealQty", true, false) == null,
        "Generic loader repainted ×7 over the forge's custom stack badge")
    var rerendered := Button.new()
    rerendered.custom_minimum_size = Vector2(60, 60)
    rerendered.set_meta("ppa_icon_path", "test-gear.png")
    rerendered.set_meta("ppa_icon_qty", 4)
    rerendered.set_meta("ppa_icon_virtual", true)
    rerendered.set_meta("ppa_icon_upgrade", 2)
    host.add_child(rerendered)
    item_icon_loader._show_icon(rerendered, "test-gear.png", fake_texture)
    item_icon_loader._show_icon(rerendered, "test-gear.png", fake_texture)
    check(rerendered.find_children("PPARealQty", "Label", false, false).size() == 1 and
        rerendered.find_children("PPARealUpgrade", "Label", false, false).size() == 1 and
        rerendered.clip_contents and rerendered.get_theme_constant("icon_max_width") <= 52,
        "Rebound icons duplicated their count/upgrade or spilled over adjacent cells")
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
    await process_frame
    await process_frame
    var mini_popup := inspector.find_child("PPAItemInspectorPopup", true, false) as PanelContainer
    var popup_center := inspector.find_child("PPAItemInspectorCenter", true, false) as CenterContainer
    check(mini_popup != null and popup_center != null and
        mini_popup.size.y > 70.0 and mini_popup.size.y < 300.0,
        "Android recording: short item tooltip must use content height, not a fixed 400px empty panel")
    check(absf(mini_popup.get_global_rect().get_center().y -
        popup_center.get_global_rect().get_center().y) < 6.0,
        "Compact inspector popup must remain centered on the game viewport")

    # Pinned tooltips have no Close button: touch ANY blank region, even
    # inside their own card, dismisses without triggering underlying actions.
    check(inspector.find_child("PPAInspectorClose", true, false) == null,
        "Item mini panel must not show a Close button")
    var tap_dismiss := InputEventScreenTouch.new()
    tap_dismiss.index = 0
    tap_dismiss.position = mini_popup.get_global_rect().get_center()
    tap_dismiss.pressed = true
    inspector._input(tap_dismiss)
    check(not inspector.is_open(),
        "Tapping the description card must dismiss pinned item details")
    inspector._show_item(stone, "resource", false)
    tap_dismiss.position = Vector2(2, 2)
    inspector._input(tap_dismiss)
    check(not inspector.is_open(), "Tapping outside the item popup must dismiss it")
    inspector._show_item(weapon, "bag", false)
    await process_frame
    var equip_tap_target := inspector.find_child("PPAInspectorEquipmentAction", true, false) as Button
    check(equip_tap_target != null and not equip_tap_target.disabled,
        "Signed Equip menu must remain tappable after dismiss-by-touch update")
    tap_dismiss.position = equip_tap_target.get_global_rect().get_center()
    inspector._input(tap_dismiss)
    check(inspector.is_open(),
        "Tapping Equip should not preempt the real server button with dismiss")
    inspector.dismiss()

    # The real PPA forge catalog includes a desc field which previously
    # vanished from the item inspector. Show it in a separate readable line
    # with the canonical rarity palette (never invent item bonuses).
    for spec in [
        {"tier":"common","color":Color("#C5CDD7")},
        {"tier":"uncommon","color":Color("#5FEC99")},
        {"tier":"rare","color":Color("#73B2FF")},
        {"tier":"epic","color":Color("#D18FFF")},
        {"tier":"legendary","color":Color("#FFD170")}
    ]:
        var sample := {"name":"Кольцо PPA", "kind":"gear",
            "rarity":str(spec["tier"]), "desc":"Бонусы из оригинального рецепта PPA"}
        inspector._show_item(sample, "catalog", true)
        var border := inspector._panel.get_theme_stylebox("panel") as StyleBoxFlat
        var heading := inspector.find_child("PPAInspectorName", true, false) as Label
        var rarity_caption := inspector.find_child("PPAInspectorRarity", true, false) as Label
        check(border != null and border.border_color.is_equal_approx(spec["color"]),
            "Item inspector frame did not use the item's real rarity color")
        check(heading != null and heading.get_theme_color("font_color").is_equal_approx(spec["color"])
            and rarity_caption != null and rarity_caption.get_theme_color("font_color").is_equal_approx(spec["color"]),
            "Item name/rarity text must use its rarity tint, not universal gold")
        check(has_label(inspector, "Бонусы из оригинального рецепта PPA"),
            "The original forge description field was missing from tooltip")
    inspector._show_item({"name":"Малоизвестный предмет","rarity":"rare"}, "catalog", true)
    check(has_label(inspector, "Описание не указано в данных PPA."),
        "Missing original item description must be labelled honestly, never invented")
    inspector._show_item({"name":"Камень","rarity":"common",
        "useText":"Безопасная заточка PPA"}, "resource", true)
    check(has_label(inspector, "Безопасная заточка PPA"),
        "The saved resource useText must appear in the dedicated description")

    # The virtual storage canvas must support the same hold interaction
    # WITHOUT allocating 500 Button nodes or blocking finger-scroll.
    var storage_scroller := ScrollContainer.new()
    storage_scroller.custom_minimum_size = Vector2(360, 200)
    host.add_child(storage_scroller)
    var virtual := preload("res://scripts/ppa_virtual_storage_grid.gd").new()
    virtual.item_inspector = inspector
    storage_scroller.add_child(virtual)
    virtual.custom_minimum_size.x = 360
    virtual.configure("personal", storage_scroller, 4)
    virtual.apply_items_readonly([weapon])
    await process_frame
    check(virtual.mouse_filter == Control.MOUSE_FILTER_PASS
        and virtual.item_at_position(Vector2(8, 8)).get("uid", "") == "auth-gear",
        "Virtual storage canvas must resolve real populated slot without blocking vertical swipes")
    var down := InputEventScreenTouch.new()
    down.index = 0
    down.pressed = true
    down.position = Vector2(8, 8)
    virtual._inspect_canvas_input(down)
    inspector._hold_timeout()
    check(inspector.is_open() and inspector._temporary,
        "Holding a painted warehouse cell must show the shared mini panel")
    _release(inspector)
    check(not inspector.is_open(), "Virtual grid hold preview did not disappear on release")

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
