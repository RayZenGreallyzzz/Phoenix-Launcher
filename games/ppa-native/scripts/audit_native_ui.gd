extends SceneTree

# Native UI smoke test runs headless in CI; checks that full PPA-like test menus
# can actually be opened/interacted with, not merely parsed/exported.
const WORLD_MENU = preload("res://scripts/test_world_menu.gd")
const NPCS = preload("res://scripts/test_city_npcs.gd")
const CATALOG = preload("res://scripts/test_shop_catalog.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var menu := WORLD_MENU.new() as Control
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

    menu.open_npc(NPCS.NPCS[5])
    var before_gold := int(menu.stash.coins)
    var before_size := (menu.stash.bag as Array).size()
    var product: Dictionary = CATALOG.MERCHANT[0]
    menu._buy_demo_item(product)
    if int(menu.stash.coins) != before_gold - int(product.get("price", 0)):
        push_error("PPA_UI_SMOKE: shop purchase did not spend local demo currency")
        quit(1)
        return
    if (menu.stash.bag as Array).size() < before_size:
        push_error("PPA_UI_SMOKE: demo shop item was lost")
        quit(1)
        return

    menu.open_page("character")
    menu.close_menu()
    if menu.is_open():
        push_error("PPA_UI_SMOKE: cannot close character menu")
        quit(1)
        return
    print("PPA_NATIVE_UI_SMOKE_OK npc_windows=", checked, " native_pages=5 shop_purchases=1")
    menu.queue_free()
    quit(0)
