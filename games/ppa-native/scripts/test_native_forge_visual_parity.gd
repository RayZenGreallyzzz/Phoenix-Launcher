extends SceneTree

# Every visible smith preview uses verified REAL original Telegram PPA
# imagery and stat lines. Never generates stock, changes saves or forges.
const FORGE = preload("res://scripts/ppa_forge_catalog_generated.gd")
const ICONS = preload("res://scripts/ppa_item_icon_loader.gd")
const ATTR = preload("res://scripts/ppa_item_attribute_view.gd")

func _initialize() -> void:
    call_deferred("_run")

func require(ok: bool, message: String) -> void:
    if not ok:
        push_error("PPA_FORGE_VISUAL_PARITY_FAIL: " + message)
        quit(1)
        assert(ok, message)

func _run() -> void:
    var rows: Array = FORGE.CATALOG.get("rows",[])
    require(rows.size() == 58,"All 58 real current PPA smith recipes required")
    var images := 0
    var stats := 0
    var pets := 0
    var accessories := 0
    var legends := 0
    var loader := ICONS.new()
    root.add_child(loader)
    var one := Button.new()
    root.add_child(one)
    for raw in rows:
        var item: Dictionary = raw
        var id := str(item.get("id",""))
        var cat := str(item.get("tab",""))
        var slot := str(item.get("slot",""))
        var rarity := str(item.get("rarity",""))
        var path := str(ICONS.art_path(item,"archer"))
        require(not path.is_empty(),"Empty original art URL for "+id)
        require(path.begins_with("/assets/"),"Unapproved art URL for "+id)
        var source := "res://assets/ppa_item_icons/" + path.get_slice("?",0).trim_prefix("/assets/")
        require(ResourceLoader.exists(source),"Missing original bundled image for "+id+": "+source)
        images += 1
        if cat=="pets":
            pets += 1
        if str(item.get("kind",""))=="accessory":
            accessories += 1
        if cat=="legendary" and str(item.get("kind",""))=="gear":
            legends += 1
            var exact: Array = item.get("sourceStats",[])
            require(not exact.is_empty(),"Legendary gear missing real PPA base attributes "+id)
            for bonus in exact:
                require(ATTR.stat_lines_for_item(item).has(bonus),
                    "Legendary PPA bonus not visible independently of image "+id)
                require(not ATTR.description_lines_for_item(item).has(bonus),
                    "PPA stat duplicated into description "+id)
            stats += 1
    require(pets == 24 and accessories == 21 and legends == 6,
        "Incomplete real PPA pets/accessories/legendary smith catalog")
    var wolf: Dictionary = {}
    for raw in rows:
        if str(raw.get("id",""))=="pet:Северный волчонок:common":
            wolf = raw
            break
    require(not wolf.is_empty(),"Missing original wolf pet")
    loader.bind_button(wolf,"archer",one)
    require(one.icon != null,"Original wolf icon not visible on native Godot button")
    root.remove_child(one)
    one.queue_free()
    root.remove_child(loader)
    loader.queue_free()
    await process_frame
    print("PPA_FORGE_VISUAL_PARITY_OK", "images="+str(images),
        "pets="+str(pets),"accessories="+str(accessories),
        "legendary_stats="+str(stats),"bundled=1 writes=0")
    quit(0)
