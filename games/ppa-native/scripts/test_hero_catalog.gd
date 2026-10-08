extends RefCounted

# TEST ONLY: class switching changes the local rendered 3D model, never
# Phoenix Account profile, server character class, or live PPA save state.
const CLASSES = [
    {"key":"tank","name":"СТРАЖ","role":"Танк · ближний бой","description":"Прочный защитник с молотом и щитом. Держит удар и защищает союзников.","model":"res://assets/hero_tank.glb","height":2.25},
    {"key":"barbarian","name":"ВАРВАР","role":"Воин · ближний бой","description":"Стремительный боец с парными клинками. Ставит на мощный урон вблизи.","model":"res://assets/hero_barbarian.glb","height":2.25},
    {"key":"paladin","name":"ПАЛАДИН","role":"Защитник · ближний бой","description":"Воин света с мечом. Сочетает защиту и поддержку команды.","model":"res://assets/hero_paladin.glb","height":2.25},
    {"key":"gnome","name":"ГНОМ · КАНОНИР","role":"Стрелок · дальний бой","description":"Невысокий инженер с тяжёлой пушкой. Атакует врагов с расстояния.","model":"res://assets/Dwarf.glb","height":1.90},
    {"key":"archer","name":"ЛУЧНИК","role":"Стрелок · дальний бой","description":"Точный и подвижный стрелок с луком. Сражается на дистанции.","model":"res://assets/hero_archer.glb","height":2.25},
    {"key":"mage","name":"МАГ","role":"Магия · дальний бой","description":"Использует боевые заклинания для атаки врагов на расстоянии.","model":"res://assets/hero_mage.glb","height":2.25},
    {"key":"assassin","name":"АССАСИН","role":"Убийца · ближний бой","description":"Быстрый скрытный боец с двумя клинками. Рассчитан на ближние атаки.","model":"res://assets/hero_assassin.glb","height":2.25},
    {"key":"priest","name":"ЖРЕЦ","role":"Поддержка · магия","description":"Помогает союзникам лечением и защитными способностями.","model":"res://assets/hero_priest.glb","height":2.25}
]

static func get_class(key: String) -> Dictionary:
    for info in CLASSES:
        if str(info.get("key", "")) == key:
            return info
    return CLASSES[3]

static func valid_key(key: String) -> bool:
    for info in CLASSES:
        if str(info.get("key", "")) == key:
            return true
    return false
