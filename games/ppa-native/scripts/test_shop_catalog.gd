extends RefCounted

# Native TEST inventory and shop display for PPA city service interaction.
# These prices are local demonstration values, NOT real PPA economy prices.
# No requests are sent to production purchase/auction/payment endpoints.
const MERCHANT = [
    {"id":"test_hp","name":"Малое зелье HP","short":"HP","description":"Учебное восстановление здоровья.","price":40,"kind":"consumable","rarity":"common"},
    {"id":"test_mp","name":"Малое зелье MP","short":"MP","description":"Учебное восстановление маны.","price":40,"kind":"consumable","rarity":"common"},
    {"id":"test_hp_big","name":"Большое зелье HP","short":"HP+","description":"Тестовый расходник.","price":125,"kind":"consumable","rarity":"uncommon"},
    {"id":"test_mp_big","name":"Большое зелье MP","short":"MP+","description":"Тестовый расходник.","price":125,"kind":"consumable","rarity":"uncommon"},
    {"id":"test_scroll","name":"Свиток возвращения","short":"TP","description":"Тестовый предмет.","price":210,"kind":"consumable","rarity":"common"},
    {"id":"test_pickaxe","name":"Обычная кирка","short":"PK","description":"Для проверки слота предмета.","price":370,"kind":"material","rarity":"uncommon"},
    {"id":"test_blade","name":"Учебное оружие","short":"WPN","description":"Подходит для тестового слота оружия.","price":450,"kind":"weapon","rarity":"uncommon"},
    {"id":"test_armor","name":"Учебная броня","short":"ARM","description":"Подходит для тестового слота брони.","price":450,"kind":"armor","rarity":"uncommon"}
]
const BLACK_MARKET = [
    {"id":"test_rune","name":"Учебная руна","short":"R","description":"Тестовая руна для проверки сумки.","price":220,"kind":"rune","rarity":"uncommon"},
    {"id":"test_enchant","name":"Учебная заточка","short":"+","description":"Тестовый материал кузницы.","price":180,"kind":"material","rarity":"uncommon"},
    {"id":"test_ore","name":"Кузнечная руда","short":"ORE","description":"Тестовый материал.","price":120,"kind":"material","rarity":"uncommon"},
    {"id":"test_blue_ore","name":"Синяя руда","short":"◆","description":"Редкий тестовый ресурс.","price":600,"kind":"material","rarity":"rare"},
    {"id":"test_ring","name":"Учебное кольцо","short":"RNG","description":"Тестовый аксессуар.","price":750,"kind":"ring","rarity":"rare"},
    {"id":"test_necklace","name":"Учебное ожерелье","short":"NEC","description":"Тестовый аксессуар.","price":750,"kind":"necklace","rarity":"rare"},
    {"id":"test_helmet","name":"Учебный шлем","short":"HLM","description":"Тестовый шлем.","price":420,"kind":"helmet","rarity":"uncommon"},
    {"id":"test_boots","name":"Учебные сапоги","short":"BOT","description":"Тестовая экипировка.","price":380,"kind":"boots","rarity":"uncommon"}
]
const CATEGORIES = [
    {"key":"character","title":"ПЕРСОНАЖ"},
    {"key":"bag","title":"ИНВЕНТАРЬ"},
    {"key":"runes","title":"РУНЫ"},
    {"key":"skills","title":"НАВЫКИ"},
    {"key":"warehouse","title":"СКЛАД"}
]
const EQUIPMENT = [
    {"key":"weapon","label":"ОРУЖИЕ"},
    {"key":"helmet","label":"ШЛЕМ"},
    {"key":"armor","label":"БРОНЯ"},
    {"key":"boots","label":"САПОГИ"},
    {"key":"ring","label":"КОЛЬЦО"},
    {"key":"necklace","label":"ОЖЕРЕЛЬЕ"}
]
static func goods(service: String) -> Array:
    if service == "merchant":
        return MERCHANT
    if service == "blackmarket":
        return BLACK_MARKET
    return []
static func item_kind(item: Dictionary) -> String:
    return str(item.get("kind", "material"))
static func rarity_tint(rarity: String) -> Color:
    match rarity:
        "uncommon": return Color("#5FBF73")
        "rare": return Color("#4A9DFF")
        "epic": return Color("#BC73FF")
        "legendary": return Color("#F9B64C")
        _: return Color("#9EA5AB")
static func equipment_slot(kind: String) -> String:
    if ["weapon","helmet","armor","boots","ring","necklace"].has(kind):
        return kind
    return ""
