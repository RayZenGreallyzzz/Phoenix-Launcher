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
    # The actual Telegram PPA cloud save keeps the canonical bag/equipment at
    # the top level; nested inventories may contain unrelated UI/test data.
    var cloud := {
        "bag": [{"uid":"cloud-armor","name":"Броня лучника"}],
        "equipped": {"weapon":{"uid":"cloud-bow","name":"Лук лучника"}},
        "storage": {"personal":[]},
        "inventory": {
            "bag": [{"uid":"stale-test-item"}],
            "equipped": {"weapon":{"uid":"incorrect-local-bow"}}
        }
    }
    var canonical := VIEW.from_save(cloud)
    if VIEW.item_at(canonical["bag"],0).get("uid","")!="cloud-armor":
        _fail("Nested inventory took priority over canonical Telegram bag")
        return
    if canonical["equipped"].get("weapon",{}).get("uid","")!="cloud-bow":
        _fail("Nested inventory took priority over canonical Telegram equipped weapon")
        return
    var root_diag := VIEW.diagnose(cloud)
    if root_diag.get("root_bag",-1)!=1 or root_diag.get("root_equipped",-1)!=1:
        _fail("Wrong raw root cloud-save diagnostic")
        return
    if root_diag.get("nested_bag",-1)!=1 or root_diag.get("nested_equipped",-1)!=1:
        _fail("Wrong untrusted nested inventory diagnostic")
        return
    if root_diag.get("shown_bag",-1)!=1 or root_diag.get("shown_equipped",-1)!=1:
        _fail("Godot interpreted wrong inventory source")
        return
    var cloud_only := {"bag":[{"name":"Сундук 1"}, {"name":"Руна 2"}],"equipped":{"ring":{"name":"Кольцо"}}}
    var cloud_only_diag := VIEW.diagnose(cloud_only)
    if cloud_only_diag.get("root_bag",-1)!=2 or cloud_only_diag.get("root_equipped",-1)!=1:
        _fail("Bad D1 actual root counters")
        return
    if cloud_only_diag.get("nested_bag",0)!=-1:
        _fail("A missing nested inventory should not look like zero items")
        return
    # The original PPA combines two physical bag pieces with independently
    # saved materials/potions/stones/grimoire stacks into the same UI grid.
    var live_cloud := {
        "bag": [
            {"uid":"real-armor", "name":"Броня лучника","slot":"armor"},
            {"uid":"real-gloves", "name":"Перчатки лучника","slot":"gloves"}
        ],
        "equipped":{"ring":ring},
        "materials":{"Серебряная руда":16, "Синий кристалл":4},
        "stones":{"normal":3},
        "potions":{"hp":132,"mp":125},
        "consumables":{"portalStone":1},
        "grimoires":{"arch_piercing_shot":1}
    }
    var original_view := VIEW.from_save(live_cloud)
    var stacks: Array = original_view.get("resource_items", [])
    if original_view.get("bag", []).size()!=2 or stacks.size()!=7:
        _fail("Original virtual stack projection missing or added fictitious items")
        return
    if str(stacks[0].get("name",""))!="Серебряная руда" or int(stacks[0].get("count",0))!=16:
        _fail("Material count/order no longer match the original Telegram save")
        return
    if str(stacks[3].get("name",""))!="Малое зелье HP" or int(stacks[3].get("count",0))!=132:
        _fail("Live original PPA HP potion stack lost")
        return
    if str(stacks[6].get("name","")).find("Гримуар")<0:
        _fail("Live original PPA grimoire failed to resolve from authoritative count")
        return
    if ART.art_path(stacks[0], "archer").is_empty() or ART.art_path(stacks[6], "archer").is_empty():
        _fail("Official PPA resource/grimoire art is not resolved")
        return
    if VIEW.diagnose(live_cloud).get("server_stacks",0)!=7:
        _fail("Server snapshot stack-count diagnostic incorrect")
        return
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
    if VIEW.symbol({"name":"Серый сундук новичка","ic":""})!="Серый су":
        _fail("Missing Telegram fallback icons must reveal original item name")
        return
    print("PPA_NATIVE_SERVER_ITEMS_VIEW_OK server_bag=1 art=original-only ring=preserved external_url=blocked writes=0")
    quit(0)
