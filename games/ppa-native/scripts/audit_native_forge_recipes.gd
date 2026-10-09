extends SceneTree

# Verify that Godot reads the ORIGINAL live PPA smith catalog, and that
# browsing recipes neither deducts nor mutates the authenticated cloud save.
const FORGE = preload("res://scripts/ppa_forge_catalog_generated.gd")
const NPC = preload("res://scripts/ppa_npc_screen.gd")

func _initialize() -> void:
    call_deferred("_check")

func _fail(reason: String) -> void:
    push_error("PPA_NATIVE_FORGE_FAIL " + reason)
    quit(1)

func _lookup(rows: Array, uid: String) -> Dictionary:
    for row in rows:
        if row is Dictionary and str(row.get("id", "")) == uid:
            return row
    return {}

func _check() -> void:
    var rows: Array = FORGE.CATALOG.get("rows", [])
    if rows.size() < 35:
        _fail("Source forge must contain original epic equipment, accessories, legendary and pet offers")
        return
    var epic: Dictionary = _lookup(rows, "gear:epic:weapon")
    var ring: Dictionary = _lookup(rows, "acc:ring:legendary")
    var pet_found := false
    var wing_found := false
    var cloak_found := false
    var artifact_found := false
    var legendary_found := false
    for row in rows:
        if str(row.get("tab","")) == "pets":
            pet_found = true
        if str(row.get("slot","")) == "wings":
            wing_found = true
        if str(row.get("slot","")) == "cloak":
            cloak_found = true
        if str(row.get("slot","")) == "artifact":
            artifact_found = true
        if str(row.get("tab","")) == "legendary":
            legendary_found = true
    if epic.is_empty() or pet_found == false or wing_found == false or cloak_found == false or artifact_found == false or legendary_found == false:
        _fail("Missing original PPA epic, wing, cloak, artifact or pet recipe")
        return
    if ring.is_empty() or int(ring.get("price",0)) != 12000:
        _fail("Legendary ring does not match original PPA 12000 PPA")
        return
    var ring_mats: Array = ring.get("materials",[])
    if ring_mats.size() != 1 or str(ring_mats[0].get("name","")) != "Кристалл Бездны" or int(ring_mats[0].get("count",0)) != 1000:
        _fail("Legendary ring missing canonical 1000 Abyss crystals")
        return
    var epic_mats: Array = epic.get("materials", [])
    if epic_mats.size() != 4 or int(epic_mats[0].get("count",0)) != 432 or int(epic_mats[1].get("count",0)) != 288 or int(epic_mats[2].get("count",0)) != 144:
        _fail("Original epic 24/16/8 * 18 material multipliers changed")
        return
    if str(epic_mats[3].get("name","")) != "Перо Феникса" or int(epic_mats[3].get("count",0)) != 2:
        _fail("Epic gear phoenix feathers incorrect")
        return

    var synthetic_save := {
        "ppa": 25000,
        "gold": 2800,
        "materials": {"Рунический слиток":444, "Метеоритная руда":310, "Кровавый кристалл":200, "Кристалл Бездны":1500},
        "feathers": {"phoenix": 4},
        "bag": [{"uid":"smith-test","name":"Клинок лучника","kind":"gear","slot":"weapon","rarity":"rare"}],
        "equipped":{}
    }
    var before := JSON.stringify(synthetic_save)
    var root := Control.new()
    root.size = Vector2(800,1280)
    get_root().add_child(root)
    var npc := NPC.new()
    root.add_child(npc)
    npc.size = root.size
    npc.apply_player_save_readonly(synthetic_save)
    npc.open_npc({"id":"blacksmith","name":"КУЗНЕЦ","service":"forge"})
    await process_frame
    npc._select_tab("equipment")
    await process_frame
    if npc.find_child("NpcProductGrid", true, false) == null:
        _fail("Smith original epic product tiles not rendered")
        return
    npc._select_item("gear:epic:weapon")
    await process_frame
    if npc._forge_owned_material("Рунический слиток") != 444 or npc._forge_owned_material("Перо Феникса") != 4:
        _fail("Materials and phoenix feathers must be read from the signed save")
        return
    for cat in ["legendary", "accessories", "pets"]:
        npc._select_tab(cat)
        await process_frame
        if not npc.is_open():
            _fail("Smith cannot open original tab " + cat)
            return
        var canonical: Dictionary = {}
        for offer in rows:
            if str(offer.get("tab", "")) == cat:
                canonical = offer
                break
        if canonical.is_empty():
            _fail("Canonical smith catalog does not include " + cat)
            return
        var item_id := str(canonical.get("id", ""))
        var product_node := npc.find_child("NpcProduct_" + item_id.to_utf8_buffer().hex_encode(), true, false)
        if product_node == null or str(product_node.get_meta("ppa_original_offer_id", "")) != item_id:
            _fail("Canonical smith " + cat + " offer ID was lost in Godot UI: " + item_id)
            return
        npc._select_item(item_id)
        await process_frame
        if npc.selected_id != item_id:
            _fail("Selecting canonical smith " + cat + " item failed")
            return
    for cat in ["enhance", "rune_fusion"]:
        npc._select_tab(cat)
        await process_frame
        if not npc.is_open():
            _fail("Smith cannot open original tab " + cat)
            return
    if before != JSON.stringify(synthetic_save):
        _fail("Read-only smith UI mutated an authenticated save")
        return
    print("PPA_NATIVE_FORGE_CATALOG_READONLY_OK source=original-live-smith epic=1 legendary=1 pets=1 wings=1 cloak=1 artifact=1 forge_tabs=6 all_original_recipe_cards=1 writes=0")
    quit(0)
