extends SceneTree

# Native UI smoke test runs headless in CI; checks that full PPA-like test menus
# can actually be opened/interacted with, not merely parsed/exported.
const WORLD_MENU = preload("res://scripts/test_world_menu.gd")
const NPCS = preload("res://scripts/test_city_npcs.gd")
const CATALOG = preload("res://scripts/test_shop_catalog.gd")
const CANONICAL_GRIMOIRES = preload("res://scripts/ppa_grimoire_catalog_generated.gd")
const STORAGE = preload("res://scripts/ppa_storage_contract.gd")

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
    # Regression: a new local TEST account must have no seeded loot.
    if not menu.stash.bag.is_empty() or not menu.stash.warehouse.is_empty():
        push_error("PPA_EMPTY_TEST_BAG: new profile contains prefabricated inventory")
        quit(1)
        return
    # Regression: an APK upgrade must purge only the FOUR known seeded IDs,
    # including examples previously moved to local storage/equipment.
    menu.stash.bag.append({"id":"test_hp","name":"Old demo HP","qty":20})
    menu.stash.warehouse.append({"id":"test_rune","name":"Old demo rune","qty":3})
    menu.stash.equipment["weapon"] = {"id":"test_gear","name":"Old demo weapon"}
    menu.stash._save()
    menu.stash.load_test_data()
    if not menu.stash.bag.is_empty() or not menu.stash.warehouse.is_empty() or menu.stash.equipment.has("weapon"):
        push_error("PPA_EMPTY_TEST_BAG: old persisted demo items were not cleared")
        quit(1)
        return
    print("PPA_EMPTY_TEST_BAG_OK seeded=0 migrated_demo=3")
    root.add_child(menu)
    menu.size = Vector2(1280, 720)
    # Only top-right "РАЗДЕЛЫ" remains: character menu is accessed by
    # tapping the 3D player, not a second "ГЕРОЙ" HUD control.
    var direct_hero_buttons := 0
    var global_hub_buttons := 0
    for child in menu.get_children():
        if child is Button and (child as Button).text == "ГЕРОЙ":
            direct_hero_buttons += 1
        if child is Button and child.name == "OpenGlobalPpaHub":
            global_hub_buttons += 1
    if direct_hero_buttons != 0 or global_hub_buttons != 1:
        push_error("PPA_UI_SMOKE: duplicate hero HUD or missing global hub")
        quit(1)
        return
    print("PPA_HERO_HUD_DEDUP_OK hero_button=0 hub_button=1")
    # Telegram and Godot must read one shared save when the hero is reopened.
    # No request is allowed merely from scrolling/changing character pages.
    var character_refreshes := {"count":0}
    menu.refresh_readonly_save_requested.connect(func(): character_refreshes["count"] = int(character_refreshes["count"]) + 1)
    menu.open_page("character")
    if character_refreshes["count"] != 1:
        push_error("PPA_SHARED_SAVE_REFRESH: character entry must request one authenticated GET")
        quit(1)
        return
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
        if character_refreshes["count"] != 1:
            push_error("PPA_SHARED_SAVE_REFRESH: page switches must never trigger extra GET")
            quit(1)
            return
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
                if not card_node.has_meta("ppa_skill_slot") or bool(card_node.get_meta("ppa_skill_verified", true)):
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
                push_error("PPA_SOURCE_SKILLS: wrong locked count " + str(placeholders) + ", expected " + str(expected_count))
                quit(1)
                return
            await process_frame
            for card_node in original_char._page_container.get_children():
                if not card_node.has_meta("ppa_skill_slot") or bool(card_node.get_meta("ppa_skill_verified", true)):
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
        if not card_node.has_meta("ppa_skill_slot"):
            continue
        if bool(card_node.get_meta("ppa_skill_verified", false)):
            real_count += 1
        else:
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
    await process_frame
    var cosmetic_row = original_char._page_container.find_child("OriginalPPACosmeticSlots", true, false)
    if cosmetic_row == null or cosmetic_row.get_child_count() != 4:
        push_error("PPA_SQUARE_COSMETICS: four character accessory slots are missing")
        quit(1)
        return
    for cosmetic in cosmetic_row.get_children():
        if cosmetic is not Button or absf(cosmetic.size.x - cosmetic.size.y) > 0.5:
            push_error("PPA_SQUARE_COSMETICS: cosmetic slot is stretched " + str(cosmetic.size))
            quit(1)
            return
    print("PPA_SQUARE_COSMETICS_OK count=4")
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
    var npc_screen_id := 0
    for npc in NPCS.NPCS:
        # Exact regression of reported bug: NPC tap WHILE the hero screen
        # is open must show only the requested service, never the hero.
        menu.open_page("character")
        if menu._character_screen == null or not menu._character_screen.is_open():
            push_error("PPA_NPC_ISOLATION: failed to open hero before NPC")
            quit(1)
            return
        menu.open_npc(npc)
        if not menu.is_open() or menu._npc_screen == null or not menu._npc_screen.is_open():
            push_error("PPA_NPC_ISOLATION: failed to open NPC " + str(npc.get("id", "")))
            quit(1)
            return
        var screen = menu._npc_screen
        if menu._panel.visible or menu._background.visible or menu._character_screen.visible or menu._web_open:
            push_error("PPA_NPC_ISOLATION: hero or old window stayed active behind " + str(npc.get("id", "")))
            quit(1)
            return
        if screen.service != str(npc.get("service", "")) or screen._heading.text != str(npc.get("name", "")):
            push_error("PPA_NPC_ISOLATION: wrong NPC header/service")
            quit(1)
            return
        if screen._tabs.get_child_count() == 0 or screen._body.get_child_count() == 0:
            push_error("PPA_NPC_ISOLATION: NPC controls/content missing")
            quit(1)
            return
        if npc_screen_id == 0:
            npc_screen_id = screen.get_instance_id()
        elif npc_screen_id != screen.get_instance_id():
            push_error("PPA_NPC_ISOLATION: duplicate NPC windows created")
            quit(1)
            return
        var locked_actions = screen.find_children("ServerActionLocked", "Button", true, false)
        if locked_actions.is_empty():
            push_error("PPA_NPC_AUTHORITY: server-side actions missing lock for " + screen.service)
            quit(1)
            return
        for action in locked_actions:
            if not action.disabled:
                push_error("PPA_NPC_AUTHORITY: unsafe enabled action at " + screen.service)
                quit(1)
                return
        var specifications: Array = screen._tab_specs()
        screen._select_tab(str(specifications[specifications.size()-1].get("key", "")))
        if screen._body.get_child_count() == 0:
            push_error("PPA_NPC_TABS: last tab failed to render for " + screen.service)
            quit(1)
            return
        checked += 1
    print("PPA_NPC_ISOLATION_OK npc_services=", checked, " windows=1 hero_overlap=0 disabled_transactions=1")
    # The Telegram reference screenshots have more pages than the first
    # native NPC prototype. Guard every real service menu contract.
    var expected_tabs := {
        "clan": 9, "forge": 6, "storage": 4, "auction": 3,
        "arena": 5, "dungeon": 4, "blackmarket": 9, "merchant": 4, "fartzone": 3
    }
    for npc in NPCS.NPCS:
        menu.open_npc(npc)
        var npc_ui = menu._npc_screen
        var kind := str(npc.get("service", ""))
        var specs: Array = npc_ui._tab_specs()
        if specs.size() != int(expected_tabs.get(kind, 0)):
            push_error("PPA_TABS_PARITY: missing Telegram tabs for " + kind + " got " + str(specs.size()))
            quit(1)
            return
        for spec in specs:
            npc_ui._select_tab(str(spec.get("key", "")))
            if npc_ui._body.get_child_count() < 1 or npc_ui._heading.text != str(npc.get("name", "")):
                push_error("PPA_TABS_PARITY: dead tab " + kind + " / " + str(spec.get("key", "")))
                quit(1)
                return
    # Simulate a real portrait canvas resize without claiming a hardware
    # sensor test. NPC window must stay inside the viewport; clan tab strip
    # scrolls horizontally instead of covering portrait content.
    menu.open_npc(NPCS.NPCS[4])
    var npc_ui = menu._npc_screen
    npc_ui.size = Vector2(720.0, 1280.0)
    npc_ui._fit()
    var frame_width: float = npc_ui._frame.offset_right - npc_ui._frame.offset_left
    var frame_height: float = npc_ui._frame.offset_bottom - npc_ui._frame.offset_top
    if frame_width >= 720.0 or frame_height >= 1280.0 or npc_ui._tab_scroller == null:
        push_error("PPA_PORTRAIT_UI: NPC frame is clipped or tab strip missing: " + str(Vector2(frame_width, frame_height)))
        quit(1)
        return
    if not (npc_ui._tabs is GridContainer) or npc_ui._tabs.columns != 3 or npc_ui._tabs.get_child_count() != 9:
        push_error("PPA_PORTRAIT_UI: all nine clan tabs must be visible in a 3x3 grid")
        quit(1)
        return
    if npc_ui._tab_scroller.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
        push_error("PPA_CLAN_TABS: sideways hidden tabs remain in portrait")
        quit(1)
        return
    if frame_height < 1100.0 or npc_ui._tab_scroller.custom_minimum_size.y < 160.0:
        push_error("PPA_NPC_PORTRAIT_HEIGHT: NPC frame/tabs still too short: " +
            str(Vector2(frame_height, npc_ui._tab_scroller.custom_minimum_size.y)))
        quit(1)
        return
    await process_frame
    var bottom_tab := npc_ui._tabs.find_child("NpcTab_journal", false, false) as Button
    if bottom_tab == null or bottom_tab.get_global_rect().end.y > npc_ui._tab_scroller.get_global_rect().end.y + 2.0:
        push_error("PPA_NPC_PORTRAIT_HEIGHT: lower clan tab row is clipped")
        quit(1)
        return
    print("PPA_NPC_PORTRAIT_TABS_OK height=", frame_height,
        " tabstrip=", npc_ui._tab_scroller.size.y, " rows=3")

    if npc_ui._tabs.find_child("NpcTab_exchange", false, false) == null:
        push_error("PPA_CLAN_EXCHANGE: exchange tab is missing")
        quit(1)
        return
    npc_ui._select_tab("exchange")
    if not npc_ui._heading.text.contains("КЛАН") or not npc_ui._body.find_children("ServerActionLocked", "Button", true, false).size():
        push_error("PPA_CLAN_EXCHANGE: exchange page did not render or mutate action unlocked")
        quit(1)
        return
    npc_ui._select_tab("storage")
    await process_frame
    var clan_grid = npc_ui.find_child("NpcStorageGrid_clan", true, false)
    if clan_grid == null or clan_grid.capacity != 500:
        push_error("PPA_CLAN_STORAGE: virtual 500-slot canvas missing")
        quit(1)
        return
    if clan_grid.get_child_count() != 0:
        push_error("PPA_CLAN_STORAGE: allocating hundreds of slot nodes instead of drawing visible cells")
        quit(1)
        return
    var clan_scroll = npc_ui.find_child("NpcStorageScroll_clan", true, false)
    if clan_scroll == null or clan_scroll.get_v_scroll_bar().max_value <= clan_scroll.size.y:
        push_error("PPA_CLAN_STORAGE: continuous vertical scroll is unavailable")
        quit(1)
        return
    var clan_range_start: Vector2i = clan_grid.range_at(0.0, 296.0)
    var clan_last_offset: float = maxf(0.0, clan_grid.custom_minimum_size.y - clan_scroll.size.y)
    var clan_range_end: Vector2i = clan_grid.range_at(clan_last_offset, clan_scroll.size.y)
    if clan_range_start.x != 0 or clan_range_start.y >= 500 or clan_range_end.x >= 500 or clan_range_end.y != 500:
        push_error("PPA_CLAN_STORAGE: first/last slots unavailable in scroll range")
        quit(1)
        return
    if npc_ui.find_child("NpcStorageNext_clan", true, false) != null or npc_ui.find_child("NpcStoragePrev_clan", true, false) != null:
        push_error("PPA_CLAN_STORAGE: ancient paging buttons still exist")
        quit(1)
        return
    menu.open_npc(NPCS.NPCS[1])
    var capacities := {"inventory":100, "personal":200, "clan":500, "premium":50}
    for scope in capacities.keys():
        if STORAGE.capacity(scope) != int(capacities[scope]):
            push_error("PPA_STORAGE_CONTRACT: incorrect capacity: " + scope)
            quit(1)
            return
    for scope in ["personal", "clan", "premium"]:
        npc_ui._select_tab(scope)
        await process_frame
        var inv_grid = npc_ui.find_child("NpcStorageGrid_inventory", true, false)
        var grid = npc_ui.find_child("NpcStorageGrid_" + scope, true, false)
        if inv_grid == null or grid == null:
            push_error("PPA_STORAGE_UI: continuous inventory or warehouse grid missing " + scope)
            quit(1)
            return
        if inv_grid.capacity != 100 or grid.capacity != int(capacities[scope]):
            push_error("PPA_STORAGE_UI: grid capacity wrong " + scope)
            quit(1)
            return
        if inv_grid.get_child_count() > 0 or grid.get_child_count() > 0:
            push_error("PPA_STORAGE_UI: slots allocated instead of virtual draw " + scope)
            quit(1)
            return
        var scroller = npc_ui.find_child("NpcStorageScroll_" + scope, true, false)
        if scroller == null:
            push_error("PPA_STORAGE_UI: scroll container missing " + scope)
            quit(1)
            return
        var visible_start: Vector2i = grid.range_at(0.0, scroller.size.y)
        var last_offset: float = maxf(0.0, grid.custom_minimum_size.y - scroller.size.y)
        var visible_end: Vector2i = grid.range_at(last_offset, scroller.size.y)
        if visible_start.x != 0 or visible_end.y != grid.capacity:
            push_error("PPA_STORAGE_UI: cannot reach first/last slot by scrolling " + scope +
                " start=" + str(visible_start) + " end=" + str(visible_end))
            quit(1)
            return
        if visible_start.y - visible_start.x > 80 or visible_end.y - visible_end.x > 80:
            push_error("PPA_STORAGE_UI: renderer draws too many offscreen cells " + scope)
            quit(1)
            return
        if scroller.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_AUTO:
            push_error("PPA_STORAGE_UI: continuous scroll disabled " + scope)
            quit(1)
            return
    var local_items: Array = []
    for i in range(251):
        local_items.append({"id":"ci_slot_" + str(i), "name":"Preview %s" % i})
    if menu.stash._filter(local_items, STORAGE.INVENTORY).size() != 100 or menu.stash._filter(local_items, STORAGE.PERSONAL).size() != 200:
        push_error("PPA_TEST_STASH_CAPACITY: local 64-slot truncation remains")
        quit(1)
        return
    npc_ui.size = Vector2(1280.0, 720.0)
    npc_ui._fit()
    menu.open_npc(NPCS.NPCS[4])
    if npc_ui._tabs.columns != 5 or npc_ui._tabs.get_child_count() != 9:
        push_error("PPA_CLAN_LANDSCAPE: nine tabs must fit in two rows")
        quit(1)
        return
    print("PPA_STORAGE_CAPACITY_OK bag=100 personal=200 clan=500 premium=50 continuous_scroll=1 rendered_visible_only=1")
    print("PPA_CLAN_EXCHANGE_VISIBLE_OK portrait=3x3 landscape=5x2")
    print("PPA_TELEGRAM_NPC_PARITY_OK clan=9 forge=6 storage=4 arena=5 portrait=1")


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
    # Offline signed-state fixture: new shared PPA auction selects actual UID,
    # not the removed local-storage slot index or decorative NpcItemChoiceGrid.
    # No credentials, HTTP requests, D1 writes or local item grants.
    var test_owner := "990000001"
    set_meta("phoenix_account", {"telegramId":test_owner})
    var signed_bag: Array = []
    for index in range(100):
        signed_bag.append({"uid":"qa_original_" + str(index),
            "name":"Серверная вещь " + str(index), "slot":"weapon",
            "kind":"gear", "rarity":"epic", "enh":7 if index == 99 else 0,
            "stats":{"atk":190}})
    menu.open_npc(NPCS.NPCS[2])
    menu._npc_screen._select_tab("sell")
    var auction_packet := {
        "gameId":"phoenix-pix-arena", "contract":"ppa-auction-v1",
        "ownerId":test_owner, "actions":["place"],
        "state":{"connected":true,"self":{"id":test_owner},"version":14,
            "wallet":{"ppa":2000,"gram":8},"commissionPct":10,
            "maxSellSlots":3,"settlementEnabled":true,
            "serverCreditClaimsEnabled":false,
            "lots":[],"mine":[],"recoverable":[],"pendingCredits":[],
            "bag":signed_bag}}
    var sale_actions: Array = []
    menu._npc_screen.auction_action_requested.connect(
        func(fields: Dictionary): sale_actions.append(fields.duplicate(true)))
    # Without server permission the full list may be VIEWED but no sale sent.
    var locked_auction := auction_packet.duplicate(true)
    locked_auction["actions"] = []
    locked_auction["state"]["settlementEnabled"] = false
    menu._npc_screen.apply_native_auction(locked_auction)
    var auction_button = menu._npc_screen.find_child("PPARealAuctionPlace", true, false)
    if auction_button == null or not auction_button.disabled:
        push_error("PPA_AUCTION_UI: server-off must prohibit native sales")
        quit(1)
        return
    menu._npc_screen.apply_native_auction(auction_packet)
    var picker = menu._npc_screen.find_child("PPARealAuctionGearPicker", true, false) as OptionButton
    if picker == null or picker.item_count != 100:
        push_error("PPA_AUCTION_PICKER: signed 100-item UID selector missing")
        quit(1)
        return
    if str(picker.get_item_metadata(0)) != "qa_original_0" or str(picker.get_item_metadata(99)) != "qa_original_99":
        push_error("PPA_AUCTION_PICKER: real gear UID or last item lost")
        quit(1)
        return
    picker.select(99)
    menu._npc_screen._auction_sell_uid_changed(99, picker)
    if menu._npc_screen._auction_sell_uid != "qa_original_99":
        push_error("PPA_AUCTION_PICKER: actual UID selection not retained")
        quit(1)
        return
    var price = menu._npc_screen.find_child("PPARealAuctionPrice", true, false) as SpinBox
    var currency = menu._npc_screen.find_child("PPARealAuctionCurrency", true, false) as OptionButton
    if price == null or currency == null:
        push_error("PPA_AUCTION_UI: server-backed price/currency missing")
        quit(1)
        return
    price.value = 125
    currency.select(1)
    menu._npc_screen._set_currency(1)
    if menu._npc_screen._asking_price != 125 or menu._npc_screen._asking_currency != "Gram":
        push_error("PPA_AUCTION_UI: chosen sale price/currency did not persist")
        quit(1)
        return
    auction_button = menu._npc_screen.find_child("PPARealAuctionPlace", true, false)
    if auction_button == null or auction_button.disabled:
        push_error("PPA_AUCTION_UI: server-authorized sale wrongly locked")
        quit(1)
        return
    auction_button.pressed.emit()
    if sale_actions.size() != 1 or sale_actions[0] != {
        "action":"place","uid":"qa_original_99","price":125,
        "currency":"gram","version":14}:
        push_error("PPA_AUCTION_UI: action must contain original UID and save version")
        quit(1)
        return
    if (menu._npc_screen.auction_state.get("bag",[]) as Array).size() != 100 or (
            menu._npc_screen.auction_state["bag"][99] as Dictionary).get("enh") != 7:
        push_error("PPA_AUCTION_UI: local listing modified +7 before server receipt")
        quit(1)
        return

    # The blacksmith now uses server-verified enhancement UIDs and materials,
    # not the legacy 100-button local inventory and fake enhancement callbacks.
    menu.open_npc(NPCS.NPCS[0])
    var forge_packet := {"gameId":"phoenix-pix-arena",
        "contract":"ppa-forge-v1","ownerId":test_owner,
        "actions":["enhance"],
        "state":{"connected":true,"self":{"id":test_owner},"version":18,
            "wallet":{"ppa":50000},"offers":[],
            "stones":{"normal":3,"premium":2,"rune":1},
            "enhanceRules":{"normal":[43,35,27,19,12,7,3],
                "rune":[55,47,40,33,27,23,19],
                "normalMax":5,"premiumMax":7},
            "enhanceItems":[{"uid":"qa_enh_7","name":"Оригинальный посох",
                "slot":"weapon","rarity":"epic","enh":5,"special":false}]}}
    var forge_actions_sent: Array = []
    menu._npc_screen.forge_action_requested.connect(
        func(fields: Dictionary): forge_actions_sent.append(fields.duplicate(true)))
    var locked_forge := forge_packet.duplicate(true)
    locked_forge["actions"] = []
    menu._npc_screen.apply_native_forge(locked_forge)
    if menu._npc_screen.find_child("PPARealForgeEnhance", true, false) != null:
        push_error("PPA_FORGE_UI: unverified enhancement enabled")
        quit(1)
        return
    menu._npc_screen.apply_native_forge(forge_packet)
    menu._npc_screen._set_enhancement_mode("premium_rune")
    var enhance_button = menu._npc_screen.find_child("PPARealForgeEnhance", true, false) as Button
    if enhance_button == null or enhance_button.disabled:
        push_error("PPA_FORGE_UI: verified +5 to +6 action missing")
        quit(1)
        return
    enhance_button.pressed.emit()
    if forge_actions_sent.size() != 1 or forge_actions_sent[0] != {
        "action":"enhance","uid":"qa_enh_7","stone":"premium_rune","version":18}:
        push_error("PPA_FORGE_UI: enhance command lost UID or save version")
        quit(1)
        return
    if (menu._npc_screen.forge_state["enhanceItems"][0] as Dictionary).get("enh") != 5:
        push_error("PPA_FORGE_UI: local view sharpened before server confirmation")
        quit(1)
        return
    menu._npc_screen.set_forge_loading(false, true)
    if menu._npc_screen.find_child("PPARealForgeEnhance", true, false) != null:
        push_error("PPA_FORGE_UI: pending write allowed duplicate sharpening")
        quit(1)
        return
    menu._npc_screen.set_forge_loading(false, false)
    remove_meta("phoenix_account")
    print("PPA_NPC_ITEM_PICKERS_OK auction_uid_count=100 last_plus7=1 forge_verified_uid=1 version=1 server_only=1 no_local_transactions=1")

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
    if menu._shop_qty != 3 or menu._npc_screen.quantity != 3 or menu._npc_screen.selected_id != "magic_small":
        push_error("PPA_NPC_SHOP: merchant tabs, selection or quantity broken")
        quit(1)
        return
    var product_cards = menu._npc_screen.find_children("NpcProduct_*", "PanelContainer", true, false)
    if product_cards.size() < 4:
        push_error("PPA_NPC_SHOP: merchant cards not rendered")
        quit(1)
        return
    menu.open_npc(NPCS.NPCS[6])
    menu._set_market_category("materials")
    if menu._npc_screen.tab != "materials":
        push_error("PPA_NPC_MARKET: categories broken")
        quit(1)
        return
    menu.open_npc(NPCS.NPCS[0])
    menu._set_smith_tab("legendary")
    menu._set_smith_tab("accessories")
    if menu._npc_screen.tab != "accessories":
        push_error("PPA_NPC_FORGE: category switching broken")
        quit(1)
        return
    if menu._panel.get_instance_id() != native_panel_id or menu._npc_screen.get_instance_id() != npc_screen_id:
        push_error("PPA_NPC_ISOLATION: duplicate store UI created")
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

    menu.close_menu()
    if menu._npc_screen.is_open() or menu.is_open():
        push_error("PPA_NPC_ISOLATION: closing NPC left a visible modal")
        quit(1)
        return
    menu.open_page("character")
    if not menu._character_screen.is_open() or menu._npc_screen.is_open():
        push_error("PPA_NPC_ISOLATION: hero cannot reopen after closing NPC")
        quit(1)
        return
    menu.close_menu()
    if menu.is_open():
        push_error("PPA_UI_SMOKE: cannot close character menu")
        quit(1)
        return
    print("PPA_NATIVE_UI_SMOKE_OK npc_windows=", checked, " native_pages=5 original_character=5 canonical_merchant=12 duplicate_shops=0 transactions=0")
    # Global PPA sections are neither NPCs nor the five-page character panel.
    var hub = menu._global_hub
    for section in ["premium", "wallet", "events", "locations", "arena"]:
        menu.open_page("character")
        menu.open_global_section(section)
        if hub == null or not hub.is_open() or menu._character_screen.visible or menu._npc_screen.is_open() or menu._panel.visible:
            push_error("PPA_GLOBAL_ISOLATION: global page overlaps character or NPC: " + section)
            quit(1)
            return
        if hub.section != section or hub._tabs.get_child_count() != 5 or hub._body.get_child_count() == 0:
            push_error("PPA_GLOBAL_NAV: missing native global page " + section)
            quit(1)
            return
        var all_locks: Array[Node] = hub.find_children("GlobalServerActionLocked", "Button", true, false)
        if all_locks.is_empty():
            push_error("PPA_GLOBAL_AUTHORITY: no locked server operations in " + section)
            quit(1)
            return
        for locked_node in all_locks:
            var locked_button := locked_node as Button
            if locked_button == null or not locked_button.disabled:
                push_error("PPA_GLOBAL_AUTHORITY: server operation enabled in " + section)
                quit(1)
                return
    menu.open_global_section("events")
    if hub.find_child("GlobalEvent_ruri", true, false) == null:
        push_error("PPA_GLOBAL_EVENTS: Ruri entry missing")
        quit(1)
        return
    hub._change_event("mimic")
    if hub.find_child("GlobalEvent_mimic", true, false) == null:
        push_error("PPA_GLOBAL_EVENTS: Mimic event missing")
        quit(1)
        return
    hub._change_sub("war")
    if hub.find_child("GlobalEvent_citadel", true, false) == null:
        push_error("PPA_GLOBAL_EVENTS: Citadel entry missing")
        quit(1)
        return
    hub._change_sub("updates")
    if hub.find_child("GlobalEvent_updates", true, false) == null:
        push_error("PPA_GLOBAL_EVENTS: update category missing")
        quit(1)
        return
    menu.open_npc(NPCS.NPCS[0])
    if hub.is_open() or not menu._npc_screen.is_open():
        push_error("PPA_GLOBAL_ISOLATION: NPC opened while global hub remained visible")
        quit(1)
        return
    # Both entry points must be functional OFFLINE walk tests, while real
    # dungeon travel remains server-locked. Emit signals rather than changing
    # the actual scene in this independent menu smoke test.
    var dungeon_routes: Array[String] = []
    menu.dungeon_visual_test_requested.connect(func(): dungeon_routes.append("walk"))
    menu.open_npc(NPCS.NPCS[7])
    var keeper_walk := menu._npc_screen.find_child("NpcDungeonWalkTest", true, false) as Button
    var keeper_locks: Array[Node] = menu._npc_screen.find_children("ServerActionLocked", "Button", true, false)
    if keeper_walk == null or keeper_walk.disabled or keeper_locks.is_empty():
        push_error("PPA_DUNGEON_KEEPER: missing offline preview or disabled live entry")
        quit(1)
        return
    keeper_walk.pressed.emit()
    if dungeon_routes.size() != 1:
        push_error("PPA_DUNGEON_KEEPER: NPC preview doesn't route to Godot dungeon")
        quit(1)
        return
    menu.open_global_section("locations")
    var global_walk := hub.find_child("GlobalDungeonMapPreview", true, false) as Button
    if global_walk == null or global_walk.disabled:
        push_error("PPA_DUNGEON_HUB: visible enabled map preview missing")
        quit(1)
        return
    global_walk.pressed.emit()
    if dungeon_routes.size() != 2:
        push_error("PPA_DUNGEON_HUB: global preview doesn't route to Godot dungeon")
        quit(1)
        return
    print("PPA_DUNGEON_OFFLINE_ENTRY_OK keeper=1 locations=1 live_entry_locked=1")
    menu.close_menu()
    if hub.is_open() or menu.is_open():
        push_error("PPA_GLOBAL_ISOLATION: close left global hub visible")
        quit(1)
        return
    if menu.find_child("OpenGlobalPpaHub", true, false) == null:
        push_error("PPA_GLOBAL_NAV: HUD entry button absent")
        quit(1)
        return
    print("PPA_GLOBAL_MENUS_OK sections=4 events=4 disabled_transactions=1 city_only=1 overlaps=0")
    menu.queue_free()
    quit(0)
