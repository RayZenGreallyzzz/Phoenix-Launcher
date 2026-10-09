extends SceneTree

# Test only synthetic saved player data. No production credentials,
# no server write calls and no arena matchmaking.
const VIEW = preload("res://scripts/ppa_shared_save_views.gd")
const HUB = preload("res://scripts/ppa_global_hub.gd")
const NPC = preload("res://scripts/ppa_npc_screen.gd")
const PICKER = preload("res://scripts/ppa_inventory_picker.gd")
const ITEM_ICONS = preload("res://scripts/ppa_item_icon_loader.gd")
const STORAGE_GRID = preload("res://scripts/ppa_virtual_storage_grid.gd")

func _initialize() -> void:
    call_deferred("_check")

func fail(why: String) -> void:
    push_error("PPA_NPC_ARENA_EVENTS_FAIL: " + why)
    quit(1)

func _check() -> void:
    var save := {
        "gold": 3000, "ppa": 145, "arenaTokens": 27,
        "materials": {"Осколок Кристального Титана": 4, "Серебряная руда": 8},
        "runes": {"health|common": 2},
        "runeSlots": [], "lvl": 15,
        "bag": [{"uid":"real-armor", "name":"Броня лучника", "kind":"gear", "slot":"armor", "rarity":"common"}],
        "equipped":{}
    }
    var before := JSON.stringify(save)
    var global_data: Dictionary = VIEW.global_player_view(save)
    if global_data.get("arenaTokens") != 27 or global_data.get("titanShards") != 4:
        fail("Authoritative arena tokens or Titan event shards lost from D1 read-only view")
        return
    var empty := VIEW.global_player_view({})
    if empty.get("arenaTokens", 0) != null or empty.get("titanShards", 0) != null:
        fail("Missing arena/event fields must remain unknown, not invented stock")
        return
    var root := Control.new()
    root.size = Vector2(800, 1280)
    get_root().add_child(root)
    var hub := HUB.new()
    root.add_child(hub)
    hub.size = root.size
    hub.apply_player_save_readonly(save)
    hub.open_section("arena")
    await process_frame
    if hub.find_child("OpenExistingArenaNpcMenu", true, false) == null:
        fail("Arena is not reachable from PPA global tabs")
        return
    var npc := NPC.new()
    root.add_child(npc)
    npc.size = root.size
    npc.apply_player_save_readonly(save)
    npc.open_npc({"service":"forge","id":"smith","name":"Кузнец"})
    await process_frame
    if npc.find_child("NpcInventoryPicker",true,false) == null:
        fail("Forge has no real player inventory picker")
        return
    npc.close_npc()
    npc.open_npc({"service":"arena","id":"arena","name":"Мечник арены"})
    await process_frame
    if not npc.is_open():
        fail("Original native arena NPC menu failed to open")
        return
    npc.tab = "shop"
    npc._render()
    await process_frame
    var price_rows := 0
    for node in npc.find_children("NpcFullWidthPriceRow", "VBoxContainer", true, false):
        price_rows += 1
    if price_rows < 6:
        fail("Original PPA six Arena offers lost or price text still squeezed into tiny right column")
        return
    # The storage screenshot showed original item names but no icons:
    # virtualized cells must now reuse the same approved bundled textures.
    var test_scroll := ScrollContainer.new()
    test_scroll.size = Vector2(340, 340)
    root.add_child(test_scroll)
    var grid := STORAGE_GRID.new()
    test_scroll.add_child(grid)
    grid.configure("inventory", test_scroll, 5)
    var view: Dictionary = VIEW.npc_player_view(save)
    var rendered_items: Array = view.get("inventory", [])
    grid.apply_items_readonly(rendered_items)
    var found_texture := false
    for raw in rendered_items:
        if raw is Dictionary:
            var tex: Texture2D = grid._approved_texture(raw)
            if tex != null:
                found_texture = true
                break
    if not found_texture:
        fail("NPC warehouse item grid did not load any actual PPA texture from APK bundle")
        return
    if before != JSON.stringify(save):
        fail("Read-only menus must never mutate original saved player")
        return
    print("PPA_NPC_ARENA_EVENTS_READONLY_OK icons_shared=1 warehouse_icon=1 arena_open=1 tokens=27 titan_shards=4 writes=0")
    quit(0)
