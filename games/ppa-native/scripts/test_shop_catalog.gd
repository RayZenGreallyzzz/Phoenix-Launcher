extends RefCounted

# Canonical NPC catalog, transcribed from the deployed PPA merchantFrame
# (const PRODUCTS, captured 2026-10-08). These are real PPA names/prices/icons,
# NOT earlier fabricated local demo offers. "Buy" remains locked until server
# inventory/currency can be read transactionally from the same save.
const MERCHANT = [
    {"id":"hp_small","tab":"potions","name":"Малое зелье HP","price":100,"currency":"gold","img":"res://assets/merchant_hp_small.png","desc":"Восстанавливает 40 HP.","kind":"consumable"},
    {"id":"hp_medium","tab":"potions","name":"Среднее зелье HP","price":250,"currency":"gold","img":"res://assets/merchant_hp_medium.png","desc":"Восстанавливает 100 HP.","kind":"consumable"},
    {"id":"hp_large","tab":"potions","name":"Большое зелье HP","price":500,"currency":"gold","img":"res://assets/merchant_hp_large.png","desc":"Восстанавливает 200 HP.","kind":"consumable"},
    {"id":"mp_small","tab":"potions","name":"Малое зелье маны","price":100,"currency":"gold","img":"res://assets/merchant_mp_small.png","desc":"Восстанавливает 30 MP.","kind":"consumable"},
    {"id":"mp_medium","tab":"potions","name":"Среднее зелье маны","price":250,"currency":"gold","img":"res://assets/merchant_mp_medium.png","desc":"Восстанавливает 75 MP.","kind":"consumable"},
    {"id":"mp_large","tab":"potions","name":"Большое зелье маны","price":500,"currency":"gold","img":"res://assets/merchant_mp_large.png","desc":"Восстанавливает 150 MP.","kind":"consumable"},
    {"id":"magic_small","tab":"boosters","name":"Магическая сила","price":750,"currency":"gold","img":"res://assets/merchant_magic_small.png","desc":"+5% к магическому урону на 3 минуты.","kind":"consumable"},
    {"id":"atk_speed_small","tab":"boosters","name":"Скорость атаки","price":750,"currency":"gold","img":"res://assets/merchant_atk_speed_small.png","desc":"+5% к скорости атаки на 3 минуты.","kind":"consumable"},
    {"id":"run_speed_small","tab":"boosters","name":"Скорость бега","price":750,"currency":"gold","img":"res://assets/merchant_run_speed_small.png","desc":"+5% к скорости передвижения на 3 минуты.","kind":"consumable"},
    {"id":"phys_small","tab":"boosters","name":"Физическая сила","price":750,"currency":"gold","img":"res://assets/merchant_phys_small.png","desc":"+5% к физическому урону на 3 минуты.","kind":"consumable"},
    {"id":"xp_scroll","tab":"scrolls","name":"Свиток опыта","price":1000,"currency":"gold","img":"res://assets/merchant_xp_scroll.png","desc":"+10% опыта за убийства на 3 минуты.","kind":"consumable"},
    {"id":"portal_scroll","tab":"scrolls","name":"Свиток телепорта","price":20,"currency":"ppa","img":"res://assets/merchant_portal_scroll.png","desc":"Телепорт к уже открытой точке главного коридора подземелья. Не работает во время боя.","kind":"consumable"}
]

# PPA Black Market changes per saved character every 24 hours. Only the three
# guaranteed offers below are safely knowable WITHOUT reading the live save.
# DO NOT display them as current owned stock or deduct Gold/PPA/Gram. Additional
# random pets, wings, runes, grimoires, materials etc remain server-owned.
const BLACK_MARKET_REFERENCE = [
    {"id":"premium_stone","category":"materials","name":"Премиум камень заточки","price":120,"currency":"ppa","desc":"Камень для заточки вплоть до +7.","limit":2,"kind":"stone"},
    {"id":"rune_stone","category":"materials","name":"Премиум руна заточки","price":650,"currency":"ppa","desc":"+12–16 п.п. к шансу одной попытки заточки. С Премиум камнем работает до +7.","limit":1,"kind":"stone"},
    {"id":"xp_scroll","category":"special","name":"Свиток опыта","price":160,"currency":"ppa","desc":"+10% опыта на 3 минуты.","limit":2,"kind":"consumable"}
]

# Original PPA panel tab labels and category keys.
const MERCHANT_TABS = [
    {"key":"potions","label":"ЗЕЛЬЯ"},
    {"key":"boosters","label":"УСКОРИТЕЛИ"},
    {"key":"scrolls","label":"СВИТКИ"},
    {"key":"misc","label":"РАЗНОЕ"}
]
const BM_CATEGORIES = [
    {"key":"all","label":"Все предложения"},
    {"key":"pets","label":"Петы"},
    {"key":"wings","label":"Крылья"},
    {"key":"cloaks","label":"Плащи"},
    {"key":"necklaces","label":"Ожерелья"},
    {"key":"artifacts","label":"Артефакты"},
    {"key":"materials","label":"Материалы"},
    {"key":"special","label":"Особое"}
]
const SMITH_TABS = [
    {"key":"enhance","label":"ЗАТОЧКА"},
    {"key":"equipment","label":"СНАРЯЖЕНИЕ"},
    {"key":"legendary","label":"ЛЕГЕНДАРНОЕ"},
    {"key":"accessories","label":"АКСЕССУАРЫ"},
    {"key":"pets","label":"ПЕТЫ"},
    {"key":"rune_fusion","label":"СЛИЯНИЕ РУН"}
]
const EQUIPMENT = [
    {"key":"weapon","label":"ОРУЖИЕ"},
    {"key":"helmet","label":"ШЛЕМ"},
    {"key":"armor","label":"БРОНЯ"},
    {"key":"gloves","label":"ПЕРЧАТКИ"},
    {"key":"legs","label":"ПОНОЖИ"},
    {"key":"boots","label":"САПОГИ"},
    {"key":"ring","label":"КОЛЬЦО"},
    {"key":"necklace","label":"ОЖЕРЕЛЬЕ"},
    {"key":"wings","label":"КРЫЛЬЯ"},
    {"key":"cloak","label":"ПЛАЩ"},
    {"key":"pet","label":"ПЕТ"},
    {"key":"artifact","label":"АРТЕФАКТ"}
]
static func goods(service: String) -> Array:
    if service == "merchant":
        return MERCHANT
    if service == "blackmarket":
        return BLACK_MARKET_REFERENCE
    return []

static func item_kind(item: Dictionary) -> String:
    return str(item.get("kind","material"))

static func rarity_tint(rarity: String) -> Color:
    match rarity:
        "uncommon": return Color("#42C868")
        "rare": return Color("#4B9CFF")
        "epic": return Color("#B565FF")
        "legendary": return Color("#F9B64C")
        _: return Color("#A7A7A7")

static func equipment_slot(kind: String) -> String:
    for entry in EQUIPMENT:
        if entry.get("key") == kind:
            return kind
    return ""
