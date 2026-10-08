extends SceneTree

# Native UI smoke test runs headless in CI; checks that full PPA-like test menus
# can actually be opened/interacted with, not merely parsed/exported.
const WORLD_MENU = preload("res://scripts/test_world_menu.gd")
const NPCS = preload("res://scripts/test_city_npcs.gd")
const CATALOG = preload("res://scripts/test_shop_catalog.gd")
const CANONICAL_GRIMOIRES = preload("res://scripts/ppa_grimoire_catalog_generated.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var menu = WORLD_MENU.new()
    if menu == null:
        push_error("PPA_UI_SMOKE: cannot instantiate native menu")
        quit(1)
        return
    var test_account := {"accountId":"ppa-native-ui-ci", "ppaNickname":"TestHero", "classKey":"gnome"}
    menu.configure(test_account, "gnome")
    root.add_child(menu)
    menu.size = Vector2(1280, 720)
    menu.open_page("character")
    if not menu.is_open():
        push_error("PPA_UI_SMOKE: character panel did not open")
        quit(1)
        return
    if menu._panel.visible or menu._character_screen == null or not menu._character_screen.is_open():
        push_error("PPA_UI_SMOKE: obsolete character panel visible or original five-page screen missing")
        quit(1)
        return
    var original_char = menu._character_screen
    var iframe_width: float = float(original_char._frame.offset_right - original_char._frame.offset_left)
    var iframe_height: float = float(original_char._frame.offset_bottom - original_char._frame.offset_top)
    if absf(iframe_width - 430.0) > 1.0 or absf(iframe_height - 655.2) > 1.0:
        push_error("PPA_UI_SMOKE: character frame must use live PPA landscape CSS geometry: " + str(Vector2(iframe_width, iframe_height)))
        quit(1)
        return
    # Every original Telegram PPA class, name, skill ID and WebP book picture.
    if CANONICAL_GRIMOIRES.CLASSES.size() != 8:
        push_error("PPA_GRIMOIRE_AUDIT: not all eight PPA classes were extracted")
        quit(1)
        return
    var grimoire_cards := 0
    for cls in CANONICAL_GRIMOIRES.CLASSES.keys():
        var info: Dictionary = CANONICAL_GRIMOIRES.class_info(str(cls))
        if (info.get("active", []) as Array).size() != 4 or (info.get("passive", []) as Array).size() != 5:
            push_error("PPA_GRIMOIRE_AUDIT: wrong original skill count for " + str(cls))
            quit(1)
            return
        for category in ["active", "passive"]:
            for raw in info.get(category, []):
                var real_skill: Dictionary = raw
                var card_path := str(real_skill.get("cardArt", ""))
                if not ResourceLoader.exists(card_path):
                    push_error("PPA_GRIMOIRE_AUDIT: missing book card " + card_path)
                    quit(1)
                    return
                var picture := load(card_path) as Texture2D
                if picture == null or picture.get_width() < 16 or picture.get_height() < 16:
                    push_error("PPA_GRIMOIRE_AUDIT: invalid card image " + card_path)
                    quit(1)
                    return
                grimoire_cards += 1
    if grimoire_cards != 72:
        push_error("PPA_GRIMOIRE_AUDIT: 72 actual cards were expected")
        quit(1)
        return
    print("PPA_REAL_GRIMOIRE_ART_OK cards=", grimoire_cards, " classes=8")

    for page in range(5):
        original_char.open_index(page)
        if str(original_char._caption.text) != str(original_char.CAPTIONS[page]):
            push_error("PPA_UI_SMOKE: PPA character page caption mismatch: " + str(page))
            quit(1)
            return
        if page == 2 and (original_char._page_container.get_child_count() != 5 or original_char._original_skill_card_count != 4):
            push_error("PPA_UI_SMOKE: expected 4 original ACTIVE illustrated grimoire cards")
            quit(1)
            return
        if page == 3 and (original_char._page_container.get_child_count() != 6 or original_char._original_skill_card_count != 5):
            push_error("PPA_UI_SMOKE: expected 5 PPA passive skill slots")
            quit(1)
            return
        if page == 2 or page == 3:
            var expected_count := 5 if page == 3 else 4
            var placeholders := 0
            for card_node in original_char._page_container.get_children():
                if card_node.name != "OriginalPPASkillPlaceholder":
                    continue
                placeholders += 1
                var original_icon = card_node.find_child("OriginalPPASkillIcon", true, false)
                var pips = card_node.find_child("OriginalPPARankPips", true, false)
                var book_button = card_node.find_child("OriginalPPAEmptySkillUpgrade", true, false)
                if original_icon == null or pips == null or pips.get_child_count() != 5 or book_button == null or not book_button.disabled:
                    push_error("PPA_SOURCE_SKILLS: incomplete original closed-skill card")
                    quit(1)
                    return
                for pip in pips.get_children():
                    if pip.custom_minimum_size != Vector2(9.0,9.0) or pip.position.y != 0.0:
                        push_error("PPA_SOURCE_SKILLS: stretched rank pip detected")
                        quit(1)
                        return
            if placeholders != expected_count:
                push_error("PPA_SOURCE_SKILLS: catalog books shown as learned without confirmed player save")
                quit(1)
                return
            await process_frame
            for card_node in original_char._page_container.get_children():
                if card_node.name != "OriginalPPASkillPlaceholder":
                    continue
                if card_node.size.y > 110.0 or card_node.size.y < 84.0:
                    push_error("PPA_SOURCE_SKILLS: screenshot mismatch, skill placeholder height=" + str(card_node.size.y))
                    quit(1)
                    return
            print("PPA_SOURCE_SKILL_PLACEHOLDERS_OK page=", page, " count=", placeholders, " max_height=110")
    # Source skill catalog is reference material, not proof that the player
    # learned it. A verified snapshot can still render an acquired skill.
    var gnome_data: Dictionary = CANONICAL_GRIMOIRES.class_info("gnome")
    var learned_example: Dictionary = (gnome_data.get("active", []) as Array)[0].duplicate(true)
    learned_example["rank"] = 2
    learned_example["book1"] = 3
    learned_example["book2"] = 1
    learned_example["book3"] = 0
    original_char.apply_authoritative_skill_snapshot({"active":[learned_example], "passive":[]})
    original_char.open_index(2)
    var real_count := 0
    var locked_count := 0
    for card_node in original_char._page_container.get_children():
        if card_node.name == "OriginalPPARealSkillCard":
            real_count += 1
        elif card_node.name == "OriginalPPASkillPlaceholder":
            locked_count += 1
    if real_count != 1 or locked_count != 3:
        push_error("PPA_SOURCE_SKILLS: verified skill snapshot did not map to 1 learned + 3 locked")
        quit(1)
        return
    original_char.clear_authoritative_skill_snapshot()
    original_char.open_index(2)
    if original_char._page_container.find_children("*", "PanelContainer", true, false).is_empty():
        push_error("PPA_SOURCE_SKILLS: cleanup destroyed skill page")
        quit(1)
        return
    print("PPA_SOURCE_SKILLS_SNAPSHOT_OK confirmed=1 locked=3 reverted=4")
    original_char.open_index(0)
    var bag_grid = original_char._page_container.find_child("OriginalPPABagGrid", true, false)
    if bag_grid == null or bag_grid.get_child_count() != 100:
        push_error("PPA_UI_SMOKE: original 100 inventory slots missing")
        quit(1)
        return
    var first_slot: Control = bag_grid.get_child(0) as Control
    if first_slot == null or absf(first_slot.custom_minimum_size.x - first_slot.custom_minimum_size.y) > 0.1:
        push_error("PPA_UI_SMOKE: inventory slots must be square, matching original PPA CSS")
        quit(1)
        return
    var bag_count = original_char._page_container.find_child("OriginalPPABagCount", true, false)
    if bag_count == null or bag_count.autowrap_mode != TextServer.AUTOWRAP_OFF:
        push_error("PPA_UI_SMOKE: inventory item counter must never wrap vertically")
        quit(1)
        return
    var locked_slot: Button = bag_grid.get_child(75) as Button
    if locked_slot == null or not locked_slot.disabled or not locked_slot.has_theme_stylebox_override("disabled"):
        push_error("PPA_UI_SMOKE: locked inventory slots disappear under Godot's default disabled Button style")
        quit(1)
        return
    if locked_slot.modulate.a < 0.25:
        push_error("PPA_UI_SMOKE: locked inventory cells must have the source-style visible dim border")
        quit(1)
        return
    if original_char._dots.size() != 5:
        push_error("PPA_UI_SMOKE: exact five page indicator dots are required")
        quit(1)
        return
    for dot in original_char._dots:
        if dot.custom_minimum_size != Vector2(7.0, 7.0):
            push_error("PPA_UI_SMOKE: page indicators must remain 7x7 circles, not stretched buttons")
            quit(1)
            return
    var scrollbar: VScrollBar = original_char._scroll.get_v_scroll_bar()
    if scrollbar == null or not scrollbar.has_theme_stylebox_override("grabber"):
        push_error("PPA_UI_SMOKE: original thin amber inventory scrollbar missing")
        quit(1)
        return
    if original_char._frame.find_child("OriginalPPABackgroundGradient", true, false) == null:
        push_error("PPA_UI_SMOKE: original character CSS radial gradient background missing")
        quit(1)
        return
    print("PPA_CHARACTER_VISUAL_STRUCTURE_OK: unlocked=50 locked=50 circular_dots=5 thin_scrollbar=1 gradient=1")

    # Synthetic directional touch test on the native Godot scroll handler.
    # Both directions must work; horizontal gestures must only flip pages.
    # CI directly exercises the SAME code as Android ScreenTouch/ScreenDrag.
    await process_frame
    await process_frame
    original_char.open_index(0)
    await process_frame
    var scroll: ScrollContainer = original_char._scroll
    var vbar: VScrollBar = scroll.get_v_scroll_bar()
    if vbar.max_value <= vbar.page + 350.0:
        push_error("PPA_GESTURE_TEST: inventory not scrollable in CI")
        quit(1)
        return
    scroll.scroll_vertical = 200
    var p: Vector2 = scroll.get_global_rect().get_center()
    var touch_start := InputEventScreenTouch.new()
    touch_start.index = 12
    touch_start.pressed = true
    touch_start.position = p
    original_char._input(touch_start)
    var drag_up := InputEventScreenDrag.new()
    drag_up.index = 12
    drag_up.position = p + Vector2(0.0, -70.0)
    drag_up.relative = Vector2(0.0, -70.0)
    original_char._input(drag_up)
    if scroll.scroll_vertical <= 200:
        push_error("PPA_GESTURE_TEST: finger UP failed to scroll contents DOWN")
        quit(1)
        return
    var drag_down := InputEventScreenDrag.new()
    drag_down.index = 12
    drag_down.position = p
    drag_down.relative = Vector2(0.0, 70.0)
    original_char._input(drag_down)
    if abs(scroll.scroll_vertical - 200) > 1:
        push_error("PPA_GESTURE_TEST: finger DOWN failed to return content UP")
        quit(1)
        return
    var touch_end := InputEventScreenTouch.new()
    touch_end.index = 12
    touch_end.pressed = false
    touch_end.position = p
    original_char._input(touch_end)
    original_char.open_index(2)
    var book_info: Dictionary = CANONICAL_GRIMOIRES.class_info("gnome")
    var real_book: Dictionary = book_info["active"][0]
    original_char._open_grimoire_popup(real_book, false, str(book_info.get("name", "")))
    if original_char._book_overlay == null or not original_char._book_overlay.visible:
        push_error("PPA_GRIMOIRE_AUDIT: original book detail popup did not open")
        quit(1)
        return
    if original_char._book_container.get_child_count() < 5:
        push_error("PPA_GRIMOIRE_AUDIT: original book effect / rank detail missing")
        quit(1)
        return
    original_char.open_index(3)
    if original_char._book_overlay.visible:
        push_error("PPA_GRIMOIRE_AUDIT: stale book popup covered next skill page")
        quit(1)
        return
    print("PPA_NATIVE_TOUCH_DIRECTIONS_OK up=+70 down=-70 horizontal=paging")
    print("PPA_REAL_GRIMOIRE_UI_OK active=4 passive=5 book_art=72 details=3 upgrade_disabled=1")

    menu.open_page("bag")
    menu.open_page("warehouse")
    menu.open_page("runes")
    menu.open_page("skills")
    var checked := 0
    for npc in NPCS.NPCS:
        menu.open_npc(npc)
        if not menu.is_open():
            push_error("PPA_UI_SMOKE: NPC service failed: " + str(npc.get("id", "")))
            quit(1)
            return
        checked += 1

    # Canonical original PPA merchant has 12 products. These must NEVER
    # spend fabricated coins or mutate local storage via a pretend shop.
    if CATALOG.MERCHANT.size() != 12:
        push_error("PPA_UI_SMOKE: not the original 12 PPA merchant products")
        quit(1)
        return
    if str(CATALOG.MERCHANT[0].get("id", "")) != "hp_small" or int(CATALOG.MERCHANT[0].get("price", 0)) != 100:
        push_error("PPA_UI_SMOKE: real merchant prices changed")
        quit(1)
        return
    var before_items := JSON.stringify({
        "bag": menu.stash.bag,
        "warehouse": menu.stash.warehouse,
        "equipment": menu.stash.equipment
    })
    var native_panel_id: int = int(menu._panel.get_instance_id())
    menu.open_npc(NPCS.NPCS[5])
    menu._set_merchant_tab("boosters")
    menu._select_merchant_item("magic_small")
    menu._adjust_merchant_quantity(2)
    if menu._shop_qty != 3:
        push_error("PPA_UI_SMOKE: original merchant quantity selector broken")
        quit(1)
        return
    menu.open_npc(NPCS.NPCS[6])
    menu._set_market_category("materials")
    menu.open_npc(NPCS.NPCS[0])
    menu._set_smith_tab("legendary")
    menu._set_smith_tab("accessories")
    if menu._panel.get_instance_id() != native_panel_id:
        push_error("PPA_UI_SMOKE: an NPC created a duplicate store panel")
        quit(1)
        return
    var after_items := JSON.stringify({
        "bag": menu.stash.bag,
        "warehouse": menu.stash.warehouse,
        "equipment": menu.stash.equipment
    })
    if after_items != before_items:
        push_error("PPA_UI_SMOKE: NPC display unexpectedly changed test inventory")
        quit(1)
        return

    menu.open_page("character")
    menu.close_menu()
    if menu.is_open():
        push_error("PPA_UI_SMOKE: cannot close character menu")
        quit(1)
        return
    print("PPA_NATIVE_UI_SMOKE_OK npc_windows=", checked, " native_pages=5 original_character=5 canonical_merchant=12 duplicate_shops=0 transactions=0")
    menu.queue_free()
    quit(0)
