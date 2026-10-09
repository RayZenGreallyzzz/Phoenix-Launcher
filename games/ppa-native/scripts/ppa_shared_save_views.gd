extends RefCounted

# Single authenticated player-save snapshot -> DRAW-ONLY views for every
# native menu. No server mutations, invented inventory, or separate database.
const INV = preload("res://scripts/ppa_server_inventory_view.gd")
const ATTR = preload("res://scripts/ppa_item_attribute_view.gd")

static func _number(save: Dictionary, key: String) -> Variant:
    var raw: Variant = save.get(key, null)
    return raw if raw is int or raw is float else null

static func money(save: Dictionary) -> Dictionary:
    return {
        "gold": ATTR.resolved_money_value(save, ["gold", "goldBalance"]),
        "ppa": ATTR.resolved_money_value(save, ["ppa", "ppaBalance"]),
        "gram": ATTR.resolved_money_value(save, ["gram", "gramBalance"]),
        "clanCoins": ATTR.resolved_money_value(save, ["clanCoins"]),
        "arenaTokens": ATTR.resolved_money_value(save, ["arenaTokens"])
    }

static func items_for_picker(save: Dictionary) -> Array:
    var data := INV.from_save(save)
    var bag: Array = data.get("bag", [])
    var resources: Array = data.get("resource_items", [])
    var result: Array = []
    for entry in bag + resources:
        if not (entry is Dictionary) or (entry as Dictionary).is_empty():
            continue
        var item: Dictionary = (entry as Dictionary).duplicate(true)
        # The old local item picker requires a non-empty id and numeric slot.
        # These are VIEW-ONLY locators and must never be sent to the server.
        item["id"] = "ppa-view-only:" + str(result.size())
        # The NPC picker uses numeric slot indices, while Telegram PPA
        # records equipment in string slots (armor, weapon, etc). Preserve
        # the real slot before adding the UI-only index.
        var original_slot: Variant = item.get("slot", item.get("equipSlot", ""))
        if original_slot is String:
            item["ppaEquipmentSlot"] = original_slot
            if not item.has("equipSlot"):
                item["equipSlot"] = original_slot
        item["slot"] = result.size()
        item["qty"] = INV.item_count(item)
        result.append(item)
        if result.size() >= 100:
            break
    return result

static func equipped(save: Dictionary) -> Dictionary:
    return INV.from_save(save).get("equipped", {})

static func storage(save: Dictionary, which: String) -> Array:
    if not ["personal", "premium", "clan"].has(which):
        return []
    var raw: Variant = save.get("storage", {})
    if not (raw is Dictionary):
        return []
    var scope: Variant = (raw as Dictionary).get(which, [])
    return (scope as Array).duplicate(true) if scope is Array else []

static func storage_exists(save: Dictionary, which: String) -> bool:
    var raw: Variant = save.get("storage", {})
    return raw is Dictionary and (raw as Dictionary).get(which, null) is Array

static func npc_player_view(save: Dictionary) -> Dictionary:
    return {
        "inventory": items_for_picker(save),
        "equipment": equipped(save),
        "money": money(save),
        "storage": {
            "personal": storage(save, "personal"),
            "premium": storage(save, "premium"),
            "clan": storage(save, "clan")
        },
        "storageFieldsPresent": {
            "personal": storage_exists(save, "personal"),
            "premium": storage_exists(save, "premium"),
            "clan": storage_exists(save, "clan")
        }
    }

static func global_player_view(save: Dictionary) -> Dictionary:
    var currency := money(save)
    var result := {
        "gramDisplay": str(currency["gram"]) if currency["gram"] != null else "— · нет данных",
        "goldDisplay": str(currency["gold"]) if currency["gold"] != null else "— · нет данных",
        "ppaDisplay": str(currency["ppa"]) if currency["ppa"] != null else "— · нет данных",
        "arenaTokens": currency["arenaTokens"],
        "titanShards": null,
        "readOnlySave": true
    }
    var mats: Variant = save.get("materials", null)
    if mats is Dictionary:
        result["titanShards"] = maxi(0,int((mats as Dictionary).get("Осколок Кристального Титана",0)))
    return result
