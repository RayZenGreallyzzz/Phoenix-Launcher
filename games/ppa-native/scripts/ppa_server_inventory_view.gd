extends RefCounted

# Read-only VIEW of the existing Telegram PPA cloud save. Never normalizes
# items into the local test storage or calls any write endpoint.
const EMPTY: Array = []
# Generated at build time from the PUBLIC current Telegram PPA catalogs.
# These are ONLY names/art; ownership and counts come from the authenticated D1 snapshot.
const LIVE_ART = preload("res://scripts/ppa_item_catalog_generated.gd")

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

static func _sources(save: Dictionary) -> Array[Dictionary]:
    # The original Telegram PPA persists inventory as top-level state.bag,
    # state.equipped and state.storage (see the deployed ppa-bridge.js).
    # Nested 'inventory' may be a partial UI cache. It must NEVER override
    # the authoritative top-level bag or equipment.
    var candidates: Array[Dictionary] = [save]
    for key in ["inventory", "inv", "INV"]:
        var raw: Variant = save.get(key, null)
        if raw is Dictionary:
            candidates.append(raw as Dictionary)
    return candidates

static func _first_value(sources: Array[Dictionary], keys: Array[String]) -> Variant:
    for source in sources:
        for key in keys:
            var value: Variant = source.get(key, null)
            if value != null:
                return value
    return null

static func _raw_dictionary(save: Dictionary, name: String) -> Dictionary:
    var value: Variant = save.get(name, null)
    return value as Dictionary if value is Dictionary else {}

static func _positive_count(value: Variant) -> int:
    if value is int or value is float:
        return maxi(0, int(value))
    if value is String:
        var text := str(value)
        if text.is_valid_int():
            return maxi(0, int(text))
    return 0

static func _add_stack(output: Array, kind: String, name: String, count: int, rarity_value: String, art: String, ico: String, extra: Dictionary = {}) -> void:
    if count <= 0:
        return
    var item := {
        "kind": kind,
        "name": name,
        "count": count,
        "rarity": rarity_value,
        "img": art,
        "icon": ico,
        "ppa_native_virtual": true
    }
    item.merge(extra, true)
    output.append(item)

static func resource_stacks_from_save(save: Dictionary) -> Array:
    # Production PPA sendInvState builds resourceItems from precisely these
    # categories, in this order. Recreate ONLY the visual projection. Never
    # make a fake owned item, change the D1 save or assume drop quantities.
    var result: Array = []
    var official: Dictionary = LIVE_ART.ITEMS
    var material_catalog: Dictionary = official.get("materials", {})
    var stone_art: Dictionary = official.get("stone_art", {})
    var shop_art: Dictionary = official.get("shop_art", {})
    var grimoire_catalog: Dictionary = official.get("grimoires", {})
    var materials := _raw_dictionary(save, "materials")
    for name in materials.keys():
        var count := _positive_count(materials[name])
        if count == 0:
            continue
        var info: Dictionary = material_catalog.get(str(name), {})
        _add_stack(result, "material", str(name), count, str(info.get("rarity", "common")),
            str(info.get("src", "")), "◆")
    var stones := _raw_dictionary(save, "stones")
    for row in [
        ["normal", "Обычный камень заточки", "common", "normalStone", "◆"],
        ["premium", "Премиум камень заточки", "rare", "premiumStone", "✦"],
        ["rune", "Премиум руна заточки", "rare", "premiumRune", "ᚱ"]
    ]:
        _add_stack(result, "stone", str(row[1]), _positive_count(stones.get(row[0], 0)),
            str(row[2]), str(stone_art.get(row[3], "")), str(row[4]))
    var potions := _raw_dictionary(save, "potions")
    for row in [
        ["hp", "hp_small", "Малое зелье HP", "common", "🧪"],
        ["hpMedium", "hp_medium", "Среднее зелье HP", "uncommon", "⚗️"],
        ["hpLarge", "hp_large", "Большое зелье HP", "rare", "🏺"],
        ["mp", "mp_small", "Малое зелье маны", "common", "🔷"],
        ["mpMedium", "mp_medium", "Среднее зелье маны", "uncommon", "🔷"],
        ["mpLarge", "mp_large", "Большое зелье маны", "rare", "🔷"]
    ]:
        _add_stack(result, "consumable", str(row[2]), _positive_count(potions.get(row[0], 0)),
            str(row[3]), str(shop_art.get(row[1], "")), str(row[4]),
            {"consumableId": str(row[1])})
    var consumables := _raw_dictionary(save, "consumables")
    for row in [
        ["magicSmall", "magic_small", "Магическая сила", "uncommon", "🔥"],
        ["atkSpeedSmall", "atk_speed_small", "Скорость атаки", "uncommon", "🪽"],
        ["speedSmall", "run_speed_small", "Скорость бега", "uncommon", "👢"],
        ["physSmall", "phys_small", "Физическая сила", "uncommon", "💪"],
        ["xpScroll", "xp_scroll", "Свиток опыта", "uncommon", "📜"],
        ["premiumHpRegen", "premium_hp_regen", "Премиум банка HP", "epic", "❤"],
        ["premiumMpRegen", "premium_mp_regen", "Премиум банка MP", "epic", "◆"]
    ]:
        var src := str(shop_art.get(row[1], ""))
        if row[1] == "premium_hp_regen":
            src = str(stone_art.get("premiumHp", ""))
        elif row[1] == "premium_mp_regen":
            src = str(stone_art.get("premiumMp", ""))
        _add_stack(result, "consumable", str(row[2]), _positive_count(consumables.get(row[0], 0)),
            str(row[3]), src, str(row[4]), {"consumableId": str(row[1])})
    var feathers := _raw_dictionary(save, "feathers")
    _add_stack(result, "material", "Перо Феникса", _positive_count(feathers.get("phoenix", 0)),
        "rare", str(stone_art.get("feather", "")), "🪶")
    for row in [
        ["luckCoin", "luck_coin", "Премиум-монета удачи", "epic", "🍀"],
        ["portalStone", "portal_stone", "Свиток телепорта", "epic", "📜"]
    ]:
        var src := str(shop_art.get(row[1], ""))
        if row[1] == "luck_coin":
            src = str(stone_art.get("luckCoin", ""))
        _add_stack(result, "consumable", str(row[2]), _positive_count(consumables.get(row[0], 0)),
            str(row[3]), src, str(row[4]), {"consumableId": str(row[1])})
    _add_stack(result, "consumable", "Карточка смены имени",
        _positive_count(save.get("renameCards", 0)), "epic", "", "✒️",
        {"consumableId": "rename_card"})
    var grimoires := _raw_dictionary(save, "grimoires")
    for id in grimoires.keys():
        var amount := _positive_count(grimoires[id])
        if amount == 0:
            continue
        var info: Dictionary = grimoire_catalog.get(str(id), {})
        if info.is_empty():
            continue
        _add_stack(result, "grimoire", "Гримуар · " + str(info.get("name", "")), amount,
            "rare", str(info.get("card", "")), "📖",
            {"skillId": str(id), "classKey": str(info.get("classKey", ""))})
    return result

static func from_save(save: Dictionary) -> Dictionary:
    var sources := _sources(save)
    var bag_raw: Variant = _first_value(sources, ["bag", "items"])
    var equipped_raw: Variant = _first_value(sources, ["equipped", "equipment"])
    var storage_raw: Variant = _first_value(sources, ["storage"])
    var resource_items := resource_stacks_from_save(save)
    return {
        "save": save.duplicate(true),
        "bag": _as_bag(bag_raw),
        "resource_items": resource_items,
        "has_bag": bag_raw is Array or bag_raw is Dictionary,
        "equipped": _as_equipment(equipped_raw),
        "has_equipped": equipped_raw is Dictionary,
        "storage": storage_raw.duplicate(true) if storage_raw is Dictionary else {},
        "version": save.get("version", null)
    }

# Privacy-safe counts of the exact already authenticated PPA save. Never
# include item names, IDs, TG identifiers, tokens, or actual item payloads.
static func _count_bag(raw: Variant) -> int:
    if not (raw is Array or raw is Dictionary):
        return -1
    var values: Array = _as_bag(raw)
    var n := 0
    for entry in values:
        if entry is Dictionary and not (entry as Dictionary).is_empty():
            n += 1
    return n

static func _count_equipped(raw: Variant) -> int:
    if not (raw is Dictionary):
        return -1
    var n := 0
    for entry in (raw as Dictionary).values():
        if entry is Dictionary and not (entry as Dictionary).is_empty():
            n += 1
    return n

static func _count_text(n: int) -> String:
    return str(n) if n >= 0 else "нет поля"

static func diagnose(save: Dictionary) -> Dictionary:
    var nested_raw: Variant = save.get("inventory", null)
    var nested: Dictionary = nested_raw if nested_raw is Dictionary else {}
    var view := from_save(save)
    var bag_root := _count_bag(save.get("bag", null))
    var equip_root := _count_equipped(save.get("equipped", null))
    var bag_nested := _count_bag(nested.get("bag", null))
    var equip_nested := _count_equipped(nested.get("equipped", null))
    return {
        "root_bag": bag_root,
        "root_equipped": equip_root,
        "nested_bag": bag_nested,
        "nested_equipped": equip_nested,
        "shown_bag": _count_bag(view.get("bag", null)),
        "shown_equipped": _count_equipped(view.get("equipped", null)),
        "root_bag_text": _count_text(bag_root),
        "root_equipped_text": _count_text(equip_root),
        "nested_bag_text": _count_text(bag_nested),
        "nested_equipped_text": _count_text(equip_nested)
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
    # Telegram PPA stores some equipment with an empty 'ic' while its real
    # image lives in 'img'. Never show only '×1' if artwork is still loading.
    for key in ["ic", "icon", "short"]:
        var value := str(item.get(key, "")).strip_edges()
        if not value.is_empty() and value != "<null>":
            return value.substr(0, 3)
    var item_title := title(item).strip_edges()
    return item_title.substr(0, 8) if not item_title.is_empty() else "◆"

static func level(save: Dictionary) -> String:
    return str(save.get("lvl", save.get("level", "—")))
