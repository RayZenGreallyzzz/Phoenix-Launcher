extends RefCounted

# All eight temporary preview classes use one PRIVATE LOCAL TEST STASH.
# Never access PPA /api/save or its player profile, inventory and warehouse.
# Data lives under the PhoenixPixArena Android private user:// directory.
const CAPACITY = preload("res://scripts/ppa_storage_contract.gd")
const MAX_BAG := CAPACITY.INVENTORY
const MAX_WAREHOUSE := CAPACITY.PERSONAL
# Old example items are no longer shown in the character inventory.
# This never deletes real server items or unrelated local test items.
const LEGACY_DEMO_IDS := ["test_hp", "test_mp", "test_rune", "test_gear"]
const EQUIPMENT_SLOTS := ["weapon", "helmet", "armor", "gloves", "legs", "boots", "ring", "necklace", "wings", "cloak", "pet", "artifact"]
var account_key: String = ""
var bag: Array = []
var warehouse: Array = []
var equipment: Dictionary = {}

func _init(account: Dictionary = {}) -> void:
    var identity := str(account.get("accountId", "")).strip_edges()
    if identity.is_empty():
        identity = str(account.get("telegramId", "")).strip_edges()
    if identity.is_empty():
        identity = "local_debug"
    account_key = identity.sha256_text().substr(0, 24)
    load_test_data()

func _path() -> String:
    return "user://ppa_native_shared_test_" + account_key + ".json"

func load_test_data() -> void:
    bag = []
    warehouse = []
    equipment = {}
    if FileAccess.file_exists(_path()):
        var f := FileAccess.open(_path(), FileAccess.READ)
        if f != null:
            var loaded = JSON.parse_string(f.get_as_text())
            if typeof(loaded) == TYPE_DICTIONARY:
                if typeof(loaded.get("bag")) == TYPE_ARRAY:
                    bag = _filter(loaded.get("bag", []), MAX_BAG)
                if typeof(loaded.get("warehouse")) == TYPE_ARRAY:
                    warehouse = _filter(loaded.get("warehouse", []), MAX_WAREHOUSE)
                var raw_equipment = loaded.get("equipment", {})
                if typeof(raw_equipment) == TYPE_DICTIONARY:
                    for key in EQUIPMENT_SLOTS:
                        var item = raw_equipment.get(key, {})
                        if typeof(item) == TYPE_DICTIONARY and not str(item.get("id", "")).is_empty():
                            equipment[key] = item
                # Prior installed APKs already saved demo HP/MP/rune/gear
                # in user://. Remove these exact example IDs once on load,
                # including examples moved to local storage/equipment.
                if _discard_legacy_demo_items():
                    _save()
                return
    # An uninitialized native test character starts with empty slots.
    # Only an authenticated server snapshot may populate real PPA items.
    _save()

func _discard_legacy_demo_items() -> bool:
    var old_bag_count := bag.size()
    var old_warehouse_count := warehouse.size()
    var cleaned_bag: Array = []
    var cleaned_warehouse: Array = []
    for item in bag:
        if not LEGACY_DEMO_IDS.has(str(item.get("id", ""))):
            cleaned_bag.append(item)
    for item in warehouse:
        if not LEGACY_DEMO_IDS.has(str(item.get("id", ""))):
            cleaned_warehouse.append(item)
    bag = cleaned_bag
    warehouse = cleaned_warehouse
    var changed := bag.size() != old_bag_count or warehouse.size() != old_warehouse_count
    for slot in equipment.keys():
        if LEGACY_DEMO_IDS.has(str(equipment[slot].get("id", ""))):
            equipment.erase(slot)
            changed = true
    return changed

func _filter(items: Array, capacity: int) -> Array:
    var result: Array = []
    for raw in items:
        if result.size() >= capacity:
            break
        if typeof(raw) != TYPE_DICTIONARY:
            continue
        var item: Dictionary = raw
        var item_id := str(item.get("id", ""))
        var title := str(item.get("name", ""))
        if item_id.length() > 0 and item_id.length() < 80 and title.length() > 0 and title.length() < 128:
            result.append({
                "id": item_id,
                "name": title,
                "qty": clampi(int(item.get("qty", 1)),1,999),
                "kind": str(item.get("kind", "material")),
                "short": str(item.get("short", "?")),
                "rarity": str(item.get("rarity", "common")),
                "upgrade": clampi(int(item.get("upgrade", 0)), 0, 10)
            })
    return result

func move(source_name: String, index: int) -> bool:
    var from: Array = bag if source_name == "bag" else warehouse
    var into: Array = warehouse if source_name == "bag" else bag
    var target_capacity := MAX_WAREHOUSE if source_name == "bag" else MAX_BAG
    if index < 0 or index >= from.size() or into.size() >= target_capacity:
        return false
    into.append(from[index])
    from.remove_at(index)
    _save()
    return true

# Local character preview equipment changes only; no store or currency API.
func equip_test_item(index: int) -> String:
    if index < 0 or index >= bag.size():
        return "Предмет не найден."
    var item: Dictionary = bag[index]
    var kind := str(item.get("kind", ""))
    var slot := kind
    if not EQUIPMENT_SLOTS.has(slot):
        return "Это не экипировка."
    var previous: Dictionary = equipment.get(slot, {})
    if not previous.is_empty() and bag.size() >= MAX_BAG:
        return "Освободи слот в сумке."
    bag.remove_at(index)
    if not previous.is_empty():
        bag.append(previous)
    item["qty"] = 1
    equipment[slot] = item
    _save()
    return "Надето: " + str(item.get("name", ""))

func unequip_test_item(slot: String) -> String:
    var item: Dictionary = equipment.get(slot, {})
    if item.is_empty():
        return "Слот пуст."
    if bag.size() >= MAX_BAG:
        return "Сумка заполнена."
    bag.append(item)
    equipment.erase(slot)
    _save()
    return "Снято: " + str(item.get("name", ""))

func _save() -> void:
    var file := FileAccess.open(_path(), FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify({
            "schema": 3, "bag": bag, "warehouse": warehouse,
            "equipment": equipment
        }))
