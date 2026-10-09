extends RefCounted

# Read-only VIEW of the existing Telegram PPA cloud save. Never normalizes
# items into the local test storage or calls any write endpoint.
const EMPTY: Array = []

static func _as_bag(raw: Variant) -> Array:
    if raw is Array:
        return (raw as Array).duplicate(true)
    if raw is Dictionary:
        # Saved slots may be sparse dictionary indices. Keep slot positions.
        var slots: Dictionary = raw
        var largest := -1
        for key in slots.keys():
            var index_text := str(key)
            if not index_text.is_valid_int():
                continue
            largest = maxi(largest, int(index_text))
        if largest < 0 or largest > 200:
            return []
        var result: Array = []
        result.resize(largest + 1)
        for key in slots.keys():
            if str(key).is_valid_int():
                result[int(str(key))] = slots[key]
        return result
    return []

static func _as_equipment(raw: Variant) -> Dictionary:
    return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}

static func _find_source(save: Dictionary) -> Dictionary:
    for key in ["inventory", "inv", "INV"]:
        if save.get(key) is Dictionary:
            return save[key]
    return save

static func from_save(save: Dictionary) -> Dictionary:
    var src := _find_source(save)
    var bag_raw: Variant = null
    for key in ["bag", "items"]:
        if src.has(key):
            bag_raw = src[key]
            break
    if bag_raw == null and src != save:
        bag_raw = save.get("bag", save.get("items", null))
    var equipped_raw: Variant = src.get("equipped", src.get("equipment", null))
    if equipped_raw == null and src != save:
        equipped_raw = save.get("equipped", save.get("equipment", {}))
    var storage_raw: Variant = src.get("storage", save.get("storage", {}))
    return {
        "save": save.duplicate(true),
        "bag": _as_bag(bag_raw),
        "has_bag": bag_raw is Array or bag_raw is Dictionary,
        "equipped": _as_equipment(equipped_raw),
        "has_equipped": equipped_raw is Dictionary,
        "storage": storage_raw.duplicate(true) if storage_raw is Dictionary else {},
        "version": save.get("version", null)
    }

static func item_at(items: Array, index: int) -> Dictionary:
    if index < 0 or index >= items.size() or not (items[index] is Dictionary):
        return {}
    return (items[index] as Dictionary)

static func item_count(item: Dictionary) -> int:
    for key in ["qty", "count", "amount"]:
        if item.has(key):
            return maxi(0, int(item[key]))
    return 1

static func rarity(item: Dictionary) -> String:
    var raw: Variant = item.get("rarity", item.get("quality", item.get("grade", "common")))
    if raw is int or raw is float:
        return {0:"common", 1:"uncommon", 2:"rare", 3:"epic", 4:"legendary", 5:"legendary"}.get(int(raw), "common")
    var key := str(raw).to_lower()
    if key in ["legend", "legendary", "orange", "gold", "легендарный", "легендарная", "легендарное", "4", "5"]:
        return "legendary"
    if key in ["epic", "эпический", "фиолетовый", "3"]:
        return "epic"
    if key in ["rare", "blue", "редкий", "2"]:
        return "rare"
    if key in ["uncommon", "green", "необычный", "1"]:
        return "uncommon"
    return "common"

static func title(item: Dictionary) -> String:
    return str(item.get("name", item.get("title", "Предмет PPA")))

static func symbol(item: Dictionary) -> String:
    return str(item.get("ic", item.get("icon", item.get("short", "◆")))).substr(0, 3)

static func level(save: Dictionary) -> String:
    return str(save.get("lvl", save.get("level", "—")))
