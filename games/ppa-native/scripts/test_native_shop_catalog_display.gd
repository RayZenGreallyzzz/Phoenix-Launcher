extends SceneTree

# Read-only shop QA: all original merchant goods in APK, responsive cards,
# and personalized Black Market data ONLY from the authenticated D1 save.
const NPC = preload("res://scripts/ppa_npc_screen.gd")
const SHOP = preload("res://scripts/test_shop_catalog.gd")
const ICONS = preload("res://scripts/ppa_item_icon_loader.gd")

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, reason: String) -> void:
    if not ok:
        push_error("PPA_SHOP_DISPLAY_FAIL: " + reason)
        quit(1)
        assert(ok, reason)

func has_label(root_node: Node, snippet: String) -> bool:
    for label in root_node.find_children("*", "Label", true, false):
        if str(label.text).contains(snippet):
            return true
    return false

func _run() -> void:
    var host := Control.new()
    host.size = Vector2(460, 860)
    root.add_child(host)
    var npc := NPC.new()
    npc.size = host.size
    host.add_child(npc)
    await process_frame
    npc.open_npc({"service":"merchant", "name":"Торговец"})
    var all_products: Array = npc._merchant_products()
    check(all_products.size() == 12, "Expected all 12 original Telegram PPA merchant offers")
    for row in all_products:
        check(row.get("ppa_reference_only") == true,
            "Original catalog row must be locked before live server price arrives")
    var grid: GridContainer = npc._body.find_child("NpcProductGrid", true, false)
    check(grid != null and grid.columns == 1 and grid.get_child_count() == 6,
        "Portrait phone lost its six original HP/MP potions or squeezed columns")
    npc._select_item("hp_small")
    check(npc._body.find_child("MerchantCommand_buy", true, false) == null,
        "Reference merchant goods allowed a real purchase")
    npc._select_tab("boosters")
    grid = npc._body.find_child("NpcProductGrid", true, false)
    check(grid.get_child_count() == 4, "Four approved original boosters missing")
    npc._select_tab("scrolls")
    grid = npc._body.find_child("NpcProductGrid", true, false)
    check(grid.get_child_count() == 2, "Original XP and teleport scrolls missing")
    npc._select_tab("misc")
    check(has_label(npc._body, "нет товаров"),
        "Empty original merchant category pretended to have server stock")

    # On landscape tablet, two readable cards per row; no three-column squeeze.
    host.size = Vector2(1280, 720)
    npc.size = host.size
    npc._fit()
    npc._select_tab("potions")
    grid = npc._body.find_child("NpcProductGrid", true, false)
    check(grid.columns == 2 and grid.get_child_count() == 6,
        "Tablet merchant grid did not use two columns")

    npc.open_npc({"service":"blackmarket","name":"Блек Маркет"})
    await process_frame
    var references := SHOP.black_market_reference_goods()
    check(references.size()==3,"Three real PPA Black Market reference items missing")
    for row in references:
        var path := ICONS.art_path(row,"")
        check(path.begins_with("/assets/"),
            "Black Market reference item missing original image: " + str(row.get("id","")))
        var tex := "res://assets/ppa_item_icons/" + path.get_slice("?",0).trim_prefix("/assets/")
        check(ResourceLoader.exists(tex),
            "Black Market original art not bundled: " + tex)
        check(not row.has("rarity"),"Reference offer invented item rarity")
    var bm_icons := npc._body.find_children("PPABlackMarketRarityIcon_*","Button",true,false)
    check(bm_icons.size()==3,"Black Market did not draw square art boxes for three reference goods")
    for tile in bm_icons:
        check(tile.icon!=null and tile.has_meta("ppa_rarity_tint"),
            "Black Market known item must display original image inside rarity-ready frame")
    npc._select_tab("materials")
    await process_frame
    bm_icons = npc._body.find_children("PPABlackMarketRarityIcon_*","Button",true,false)
    check(bm_icons.size()==2,"Materials category lost its premium stone and rune")
    npc.close_npc()

    var saved := {"blackMarket":{"refreshAt":int(Time.get_unix_time_from_system()*1000.0)+7200000,
        "offers":[{"id":"real_bm_1","category":"materials","price":770,
            "currency":"ppa","limit":2,"item":{"name":"Кристалл PPA","icon":"◆","rarity":"rare"}},
            {"id":"real_bm_2","category":"materials","limit":2,
            "item":{"name":"Редкий камень","icon":"◇"}}],
        "bought":{"real_bm_1":1}}}
    var original := JSON.stringify(saved)
    npc.apply_player_save_readonly(saved)
    npc.open_npc({"service":"blackmarket","name":"Блек Маркет"})
    npc._select_tab("materials")
    grid = npc._body.find_child("NpcProductGrid", true, false)
    check(grid != null and grid.get_child_count() == 2,
        "Original per-character Black Market offers were lost")
    check(has_label(npc._body, "РЕДКИЙ"),"Original signed Black Market rarity not shown")
    var personal_tile := npc._body.find_child(
        "PPABlackMarketRarityIcon_" + "real_bm_1".to_utf8_buffer().hex_encode(),
        true,false) as Button
    check(personal_tile!=null and personal_tile.has_meta("ppa_rarity_tint"),
        "Personal Black Market offer lost its rarity-framed square")
    check(has_label(npc._body, "Кристалл PPA") and has_label(npc._body, "770 PPA"),
        "Personal stock lost its nested PPA item name or original price")
    check(has_label(npc._body, "Цена не подтверждена"),
        "Missing price must not become invented 0 Gold")
    npc._select_item("real_bm_1")
    check(has_label(npc._body, "осталось 1"),
        "Black Market forgot one prior purchase from D1 bought counter")
    npc._select_item("real_bm_2")
    check(has_label(npc._body, "остаток не подтверждён"),
        "Missing Black Market purchase counter was shown as available stock")
    check(npc._body.find_child("MerchantCommand_buy", true, false) == null,
        "Black Market received unsigned native merchant buy action")
    check(JSON.stringify(saved) == original, "Shop preview modified original D1 stock")

    # The optional /api/game/npc/blackmarket read projection must carry
    # canonical daily purchase counters. Server-confirmed count wins over
    # the earlier city snapshot, but still cannot authorize a purchase.
    set_meta("phoenix_account", {"telegramId":"990000001"})
    npc.apply_authoritative_snapshot({
        "ok":true, "gameId":"phoenix-pix-arena","ownerId":"990000001",
        "readOnly":true,"service":"blackmarket","version":32,
        "data":{"readOnly":true,"actionsEnabled":false,
            "offers":[{"id":"real_bm_1","name":"Кристалл PPA",
                "category":"materials","price":770,"currency":"ppa",
                "limit":2,"bought":2}]}
    })
    check(npc.has_verified_state, "Signed Black Market projection was rejected")
    npc._select_item("real_bm_1")
    check(has_label(npc._body, "осталось 0"),
        "Current server bought count did not override older D1 preview")
    check(npc._body.find_child("MerchantCommand_buy", true, false) == null,
        "Read-only Black Market projection enabled a real merchant purchase")
    remove_meta("phoenix_account")
    check(JSON.stringify(saved) == original,
        "Applying signed Black Market projection modified legacy Telegram save")

    npc.close_npc()
    npc.clear_player_save_readonly()
    npc.open_npc({"service":"blackmarket","name":"Блек Маркет"})
    check(not has_label(npc._body, "Кристалл PPA"),
        "Another account could see a former hero's personal Black Market stock")
    host.queue_free()
    await process_frame
    print("PPA_SHOP_DISPLAY_OK catalog=12 portrait=1 tablet=2 boosters=4 scrolls=2 personal_bm=2 unknown_prices=hidden no_economy_writes=1")
    quit(0)
