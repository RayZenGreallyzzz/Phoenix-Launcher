extends RefCounted

# All eight temporary preview classes use one PRIVATE LOCAL TEST STASH.
# Never access PPA /api/save or its player profile, inventory and warehouse.
# Data lives under the PhoenixPixArena Android private user:// directory.
const MAX_ITEMS := 64
var account_key: String = ""
var bag: Array = []
var warehouse: Array = []
var coins: int = 3000
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
    coins = 3000
    equipment = {}
    if FileAccess.file_exists(_path()):
        var f := FileAccess.open(_path(), FileAccess.READ)
        if f != null:
            var loaded = JSON.parse_string(f.get_as_text())
            if typeof(loaded) == TYPE_DICTIONARY:
                if typeof(loaded.get("bag")) == TYPE_ARRAY:
                    bag = _filter(loaded.get("bag", []))
                if typeof(loaded.get("warehouse")) == TYPE_ARRAY:
                    warehouse = _filter(loaded.get("warehouse", []))
                coins = maxi(0, int(loaded.get("coins", 3000)))
                var raw_equipment = loaded.get("equipment", {})
                if typeof(raw_equipment) == TYPE_DICTIONARY:
                    for key in ["weapon", "helmet", "armor", "boots", "ring", "necklace"]:
                        var item = raw_equipment.get(key, {})
                        if typeof(item) == TYPE_DICTIONARY and not str(item.get("id", "")).is_empty():
                            equipment[key] = item
                return
    # Clearly labelled TEST samples, not real PPA equipment or rewards.
    bag = [
        {"id":"test_hp","name":"Учебное зелье HP","qty":20},
        {"id":"test_mp","name":"Учебное зелье MP","qty":20},
        {"id":"test_rune","name":"Учебная руна","qty":3},
        {"id":"test_gear","name":"Тестовая экипировка","qty":1}
    ]
    warehouse = []
    _save()

func _filter(items: Array) -> Array:
    var result: Array = []
    for raw in items:
        if result.size() >= MAX_ITEMS:
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
                "rarity": str(item.get("rarity", "common"))
            })
    return result

func move(source_name: String, index: int) -> bool:
    var from: Array = bag if source_name == "bag" else warehouse
    var into: Array = warehouse if source_name == "bag" else bag
    if index < 0 or index >= from.size() or into.size() >= MAX_ITEMS:
        return false
    into.append(from[index])
    from.remove_at(index)
    _save()
    return true

# All operations below touch local user:// data only; never server-backed.
func buy_test_item(product: Dictionary) -> String:
    var price: int = maxi(0, int(product.get("price", 0)))
    if price > coins:
        return "Недостаточно учебных монет."
    var item: Dictionary = product.duplicate(true)
    item.erase("price")
    item.erase("description")
    if not _add_to(bag, item):
        return "Сумка заполнена."
    coins -= price
    _save()
    return "Куплено (тест): " + str(item.get("name", ""))

func _add_to(target: Array, item: Dictionary) -> bool:
    var kind := str(item.get("kind", "material"))
    var id := str(item.get("id", ""))
    if ["consumable", "material", "rune"].has(kind):
        for existing in target:
            if str(existing.get("id", "")) == id and int(existing.get("qty", 1)) < 999:
                existing["qty"] = mini(999, int(existing.get("qty", 1)) + 1)
                return true
    if target.size() >= MAX_ITEMS:
        return false
    var copy: Dictionary = item.duplicate(true)
    copy["qty"] = 1
    target.append(copy)
    return true

func equip_test_item(index: int) -> String:
    if index < 0 or index >= bag.size():
        return "Предмет не найден."
    var item: Dictionary = bag[index]
    var kind := str(item.get("kind", ""))
    var slot := kind
    if not ["weapon", "helmet", "armor", "boots", "ring", "necklace"].has(slot):
        return "Это не экипировка."
    var previous: Dictionary = equipment.get(slot, {})
    if not previous.is_empty() and bag.size() >= MAX_ITEMS:
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
    if bag.size() >= MAX_ITEMS:
        return "Сумка заполнена."
    bag.append(item)
    equipment.erase(slot)
    _save()
    return "Снято: " + str(item.get("name", ""))

func sell_test_item(index: int) -> String:
    if index < 0 or index >= bag.size():
        return "Предмет не найден."
    var item: Dictionary = bag[index]
    if str(item.get("kind", "")) == "consumable" and int(item.get("qty", 1)) > 1:
        item["qty"] = int(item.get("qty", 1)) - 1
    else:
        bag.remove_at(index)
    coins += 20
    _save()
    return "Продано (тест): +20 учебных монет."

func sharpen_test_weapon() -> String:
    var item: Dictionary = equipment.get("weapon", {})
    if item.is_empty():
        return "Сначала надень учебное оружие."
    var used_idx := -1
    for idx in range(bag.size()):
        if str((bag[idx] as Dictionary).get("id", "")) == "test_enchant":
            used_idx = idx
            break
    if used_idx < 0:
        return "Нужна учебная заточка из Блэк Маркета."
    var material: Dictionary = bag[used_idx]
    material["qty"] = int(material.get("qty", 1)) - 1
    if int(material["qty"]) <= 0:
        bag.remove_at(used_idx)
    item["upgrade"] = mini(10, int(item.get("upgrade", 0)) + 1)
    equipment["weapon"] = item
    _save()
    return "Тестовая заточка оружия: +" + str(item["upgrade"])

func _save() -> void:
    var file := FileAccess.open(_path(), FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify({
            "schema": 2, "bag": bag, "warehouse": warehouse,
            "coins": coins, "equipment": equipment
        }))
