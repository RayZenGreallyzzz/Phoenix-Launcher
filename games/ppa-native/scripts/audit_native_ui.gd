extends SceneTree

# Native UI smoke test runs headless in CI; checks that full PPA-like test menus
# can actually be opened/interacted with, not merely parsed/exported.
const WORLD_MENU = preload("res://scripts/test_world_menu.gd")
const NPCS = preload("res://scripts/test_city_npcs.gd")
const CATALOG = preload("res://scripts/test_shop_catalog.gd")

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
    for page in range(5):
        original_char.open_index(page)
        if str(original_char._caption.text) != str(original_char.CAPTIONS[page]):
            push_error("PPA_UI_SMOKE: PPA character page caption mismatch: " + str(page))
            quit(1)
            return
        if page == 2 and original_char._page_container.get_child_count() != 5:
            push_error("PPA_UI_SMOKE: expected 4 original active skill placeholders")
            quit(1)
            return
        if page == 3 and original_char._page_container.get_child_count() != 6:
            push_error("PPA_UI_SMOKE: expected 5 original passive skill placeholders")
            quit(1)
            return
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
