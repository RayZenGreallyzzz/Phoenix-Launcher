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
    var native_panel_id := menu._panel.get_instance_id()
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
    print("PPA_NATIVE_UI_SMOKE_OK npc_windows=", checked, " native_pages=5 canonical_merchant=12 duplicate_shops=0 transactions=0")
    menu.queue_free()
    quit(0)
