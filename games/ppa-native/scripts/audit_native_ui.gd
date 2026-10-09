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
    # Isolated fixture is fed only to the read-only UI, not written to
    # user:// or a production server. Regression: full 100-slot selector
    # and real selection workflow, not 16 decorative empty boxes.
    var test_inventory := [
        {"id":"test_blade","slot":3,"name":"Тестовый меч","short":"⚔","kind":"weapon","qty":1,"rarity":"rare","upgrade":2},
        {"id":"test_stone","slot":18,"name":"Тестовая заточка","short":"◆","kind":"sharpening","qty":8},
        {"id":"test_rune","slot":32,"name":"Тестовая руна","short":"ᚱ","kind":"rune","qty":3}
    ]
    menu.open_npc(NPCS.NPCS[2])
    menu._npc_screen._select_tab("sell")
    menu._npc_screen.apply_authoritative_snapshot({"service":"auction","data":{"inventory":test_inventory}})
    var sell_grid = menu._npc_screen.find_child("NpcItemChoiceGrid", true, false)
    if sell_grid == null or sell_grid.get_child_count() != 100:
        push_error("PPA_AUCTION_PICKER: complete 100-slot bag missing")
        quit(1)
        return
    var empty_slot = sell_grid.find_child("PickSlot_bag_0", false, false)
    var sellable_slot = sell_grid.find_child("PickSlot_bag_3", false, false)
    if empty_slot == null or sellable_slot == null or not empty_slot.disabled or sellable_slot.disabled:
        push_error("PPA_AUCTION_PICKER: empty slot or selectable item broken")
        quit(1)
        return
    menu._npc_screen._choose_auction("bag:3")
    if menu._npc_screen._auction_item_key != "bag:3":
        push_error("PPA_AUCTION_PICKER: selected slot not stored")
        quit(1)
        return
    if menu._npc_screen._chosen_item("bag:3").get("name", "") != "Тестовый меч":
        push_error("PPA_AUCTION_PICKER: chosen item details are wrong")
        quit(1)
        return
    var price = menu._npc_screen.find_child("NpcAuctionPrice", true, false)
    var qty = menu._npc_screen.find_child("NpcAuctionQuantity", true, false)
    var currency = menu._npc_screen.find_child("NpcAuctionCurrency", true, false)
    if price == null or qty == null or currency == null:
        push_error("PPA_AUCTION_LISTING: price, quantity or currency controls missing")
        quit(1)
        return
    price.value = 125
    menu._npc_screen._set_asking_qty(1)
    currency.select(1)
    menu._npc_screen._set_currency(1)
    if menu._npc_screen._asking_price != 125 or menu._npc_screen._asking_currency != "Gram":
        push_error("PPA_AUCTION_LISTING: listing form edits not retained")
        quit(1)
        return
    var auction_locked = menu._npc_screen.find_children("ServerActionLocked", "Button", true, false)
    if auction_locked.is_empty() or not auction_locked[0].disabled:
        push_error("PPA_AUCTION_LISTING: unverified listing action enabled")
        quit(1)
        return

    menu.open_npc(NPCS.NPCS[0])
    menu._npc_screen.apply_authoritative_snapshot({
        "service":"forge", "data":{
            "inventory":test_inventory,
            "equipment":{"weapon":{"id":"test_worn","name":"Надетый молот","kind":"weapon","short":"⚒","upgrade":1}}
        }})
    var forge_grid = menu._npc_screen.find_child("NpcItemChoiceGrid", true, false)
    if forge_grid == null or forge_grid.get_child_count() != 100:
        push_error("PPA_FORGE_PICKER: full inventory grid missing")
        quit(1)
        return
    var equipped = menu._npc_screen.find_child("NpcEquippedItemChoices", true, false)
    if equipped == null or equipped.get_child_count() != 1:
        push_error("PPA_FORGE_PICKER: worn gear cannot be chosen")
        quit(1)
        return
    menu._npc_screen._choose_forge("equip:weapon")
    if str(menu._npc_screen._forge_keys.get("equipment","")) != "equip:weapon":
        push_error("PPA_FORGE_PICKER: equipped item was not selected")
        quit(1)
        return
    menu._npc_screen._set_forge_filter("stone")
    forge_grid = menu._npc_screen.find_child("NpcItemChoiceGrid", true, false)
    var forge_stone = forge_grid.find_child("PickSlot_bag_18", false, false) if forge_grid != null else null
    if forge_stone == null or forge_stone.disabled:
        push_error("PPA_FORGE_PICKER: sharpening stones unavailable")
        quit(1)
        return
    menu._npc_screen._choose_forge("bag:18")
    menu._npc_screen._set_forge_filter("rune")
    forge_grid = menu._npc_screen.find_child("NpcItemChoiceGrid", true, false)
    var forge_rune = forge_grid.find_child("PickSlot_bag_32", false, false) if forge_grid != null else null
    if forge_rune == null or forge_rune.disabled:
        push_error("PPA_FORGE_PICKER: runes unavailable")
        quit(1)
        return
    menu._npc_screen._choose_forge("bag:32")
    if str(menu._npc_screen._forge_keys.get("equipment", "")) != "equip:weapon" or str(menu._npc_screen._forge_keys.get("stone", "")) != "bag:18" or str(menu._npc_screen._forge_keys.get("rune", "")) != "bag:32":
        push_error("PPA_FORGE_PICKER: selected equipment/stone/rune did not persist")
        quit(1)
        return
    var forge_locked = menu._npc_screen.find_children("ServerActionLocked", "Button", true, false)
    if forge_locked.is_empty() or not forge_locked[0].disabled:
        push_error("PPA_FORGE_PICKER: unauthorized enhance action enabled")
        quit(1)
        return
    print("PPA_NPC_ITEM_PICKERS_OK auction_slots=100 forge_slots=100 worn_gear=1 stone=1 rune=1 transactions=0")

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
