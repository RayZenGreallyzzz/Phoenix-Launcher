extends RefCounted

# Display ONLY fields stored on an authenticated original PPA item. Never
# manufacture computed damage/defense or server permissions.
const ATTRIBUTES := {
    "attack":"Атака", "atk":"Атака", "atkMin":"Мин. атака", "atkMax":"Макс. атака",
    "minAtk":"Мин. атака", "maxAtk":"Макс. атака",
    "def":"Защита", "defense":"Защита", "armor":"Броня", "magicResist":"Магическая защита",
    "hp":"HP", "maxHp":"Макс. HP", "hpBonus":"Бонус HP",
    "mp":"MP", "maxMp":"Макс. MP", "mpBonus":"Бонус MP",
    "str":"Сила", "strength":"Сила", "agi":"Ловкость", "agility":"Ловкость",
    "int":"Интеллект", "intellect":"Интеллект",
    "crit":"Крит. шанс", "critChance":"Крит. шанс",
    "critDamage":"Крит. урон", "critDmg":"Крит. урон",
    "dodge":"Уворот", "evasion":"Уворот", "controlResist":"Сопротивление контролю", "slowResist":"Сопротивление замедлению",
    "speed":"Скорость", "spd":"Скорость", "spdFlat":"Бонус скорости", "atkSpeed":"Скорость атаки",
    "attackSpeed":"Скорость атаки", "moveSpeed":"Скорость передвижения",
    "vampirism":"Вампиризм", "lifesteal":"Вампиризм",
    "magic":"Магия", "magicPower":"Сила магии", "heal":"Лечение",
    "upgrade":"Заточка", "enhance":"Заточка", "enhancement":"Заточка",
    "plus":"Заточка", "enh":"Заточка", "upgradeLevel":"Заточка", "bm":"Боевая мощь",
    "requiredLevel":"Требуемый уровень", "levelRequired":"Требуемый уровень",
    "minLevel":"Требуемый уровень", "lvlReq":"Требуемый уровень",
    "valueText":"Эффект", "bonusText":"Бонус", "hpPct":"HP (%)", "mpPct":"MP (%)", "atkPct":"Атака (%)", "defPct":"Защита (%)"
}
const NESTED := ["stats", "baseStats", "bonuses", "bonus", "extraStats", "attributes", "effects"]
const DESCRIPTIONS := ["description", "desc", "effectText", "useText", "bonusText", "valueText", "skillDescription"]

static func _describe_value(value: Variant) -> String:
    if value is int or value is float:
        return str(value)
    if value is String:
        return (value as String).strip_edges().left(160)
    return ""

static func _append_values(item: Dictionary, output: Array, seen: Dictionary) -> void:
    for field in ATTRIBUTES.keys():
        if not item.has(field):
            continue
        var printed := _describe_value(item[field])
        if printed.is_empty():
            continue
        var label: String = str(ATTRIBUTES[field])
        var key := label + "|" + printed
        if not seen.has(key):
            output.append(label + ": " + printed)
            seen[key] = true

static func lines_for_item(item: Dictionary) -> Array:
    var lines: Array = []
    var seen := {}
    _append_values(item, lines, seen)
    for field in NESTED:
        if item.get(field, null) is Dictionary:
            _append_values(item[field] as Dictionary, lines, seen)
    for field in DESCRIPTIONS:
        if not item.has(field):
            continue
        var value := _describe_value(item[field])
        if value.is_empty():
            continue
        var entry := "Описание: " + value
        if not seen.has(entry):
            lines.append(entry)
            seen[entry] = true
    return lines

# For the compact tooltip, description has a dedicated section.
# Original PPA uses desc for forge recipes, useText for resources, and
# description/effectText for some equipped pieces. Never derive bonuses
# from rarity/name: show only the item's real source text.
static func description_lines_for_item(item: Dictionary) -> Array:
    var output: Array = []
    var seen := {}
    for field in ["description", "desc", "useText", "skillDescription", "effectText"]:
        var raw: Variant = item.get(field, null)
        if not (raw is String):
            continue
        var entry := (raw as String).strip_edges().left(480)
        if not entry.is_empty() and not seen.has(entry):
            output.append(entry)
            seen[entry] = true
    if output.is_empty():
        for field in ["bonusText", "valueText"]:
            var value: Variant = item.get(field, null)
            if not (value is String):
                continue
            var effect := (value as String).strip_edges().left(400)
            if not effect.is_empty() and not seen.has(effect):
                output.append(effect)
                seen[effect] = true
    return output

static func stat_lines_for_item(item: Dictionary) -> Array:
    var output: Array = []
    var seen := {}
    _append_values(item, output, seen)
    for field in NESTED:
        var raw: Variant = item.get(field, null)
        if raw is Dictionary:
            _append_values(raw as Dictionary, output, seen)
    return output


static func resolved_money_value(save: Dictionary, aliases: Array) -> Variant:
    # Original PPA save formats sometimes wrap player state in inventory
    # while the newer registered D1 save keeps values on its root.
    # Never invent a zero or read someone else's account.
    for node in [save, save.get("inventory", {}), save.get("player", {})]:
        if not (node is Dictionary):
            continue
        var source: Dictionary = node
        for name in aliases:
            var value: Variant = source.get(name, null)
            if value is int or value is float:
                return value
            if value is String:
                var numeric := str(value).strip_edges()
                if numeric.is_valid_int() or numeric.is_valid_float():
                    return float(numeric)
    return null
