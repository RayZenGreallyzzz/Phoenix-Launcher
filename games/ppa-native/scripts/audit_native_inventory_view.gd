extends SceneTree

const VIEW = preload("res://scripts/ppa_server_inventory_view.gd")
const ART = preload("res://scripts/ppa_item_icon_loader.gd")

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("PPA_NATIVE_ITEMS_AUDIT: " + message)
    quit(1)

func _run() -> void:
    var legendary := {
        "id":"actual-server-gear", "name":"Легендарная пушка гнома",
        "rarity":"legendary", "slot":"weapon", "classKey":"gnome",
        "qty":1, "img":"/assets/old-art.webp"
    }
    var ring := {
        "id":"actual-ring", "name":"Кольцо", "slot":"ring",
        "rarity":"legendary", "img":"/assets/rings/existing-ring.png"
    }
    var source := {
        "lvl":52, "hp":789, "xp":450, "statPts":7,
        "inventory":{"bag":[legendary,ring,null],"equipped":{"weapon":legendary}}
    }
    var snap := VIEW.from_save(source)
    if not snap.get("has_bag",false) or snap.get("bag",[]).size()!=3:
        _fail("Original bag shape was lost")
        return
    if VIEW.item_at(snap["bag"],0).get("id","")!="actual-server-gear":
        _fail("Cloud item ID was lost")
        return
    if ART.art_path(legendary,"gnome")!="/assets/legendary/gnome-weapon.webp?v=v514":
        _fail("Legendary approved item art mapping broken")
        return
    if ART.art_path(ring,"gnome")!="/assets/rings/existing-ring.png":
        _fail("Legendary ring should preserve its original PPA icon")
        return
    # build.mjs exports the ORIGINAL PPA inline item art with a leading "./".
    # Real cloud items often retain precisely this string inside their save.
    var exported_ppa_art := {"name":"Лук лучника","rarity":"common","img":"./assets/c73ef6814017bda6.png"}
    if ART.art_path(exported_ppa_art,"archer")!="/assets/c73ef6814017bda6.png":
        _fail("Original Telegram ./assets URL was rejected")
        return
    var exported_potion := {"name":"Зелье","img":"assets/test-ppa-potion.webp?v=1"}
    if ART.art_path(exported_potion,"archer")!="/assets/test-ppa-potion.webp?v=1":
        _fail("Original asset URL normalization broke")
        return
    var fake_escape := {"img":"./assets/../secrets.png"}
    if ART.art_path(fake_escape,"archer")!="":
        _fail("Escaping asset directory should be blocked")
        return
    var fake_external := {"img":"https://evil.example/steal.png"}
    if ART.art_path(fake_external,"gnome")!="":
        _fail("External image URL permitted")
        return
    source["inventory"]["bag"].clear()
    if snap["bag"].size()!=3:
        _fail("Server view mutated with the source save")
        return
    if VIEW.item_count({"qty":13})!=13 or VIEW.rarity(legendary)!="legendary":
        _fail("Quantity or rarity changed")
        return
    if VIEW.symbol({"name":"Серый сундук новичка","ic":""})!="Серый сун":
        _fail("Missing Telegram fallback icons must reveal original item name")
        return
    print("PPA_NATIVE_SERVER_ITEMS_VIEW_OK server_bag=1 art=original-only ring=preserved external_url=blocked writes=0")
    quit(0)
