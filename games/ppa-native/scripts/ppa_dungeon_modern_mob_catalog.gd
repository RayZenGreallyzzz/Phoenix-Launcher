extends RefCounted

# User's UNDEPLOYED replacement dungeon artwork, recovered from Library:
# "Атлас пиксельных монстров 1–20.png"
# "Пепел Феникса: бестиарий данжа.png".
# These are artwork CATALOG INDEXES, not a claim that enemy #N is level N.
# Do not substitute older PPA DUNGEON_MOB_SPRITES.
const SOURCE_ATLAS := "Атлас пиксельных монстров 1–20.png"
const NAME_BY_ATLAS_INDEX := [
    "Пепельная крыса",
    "Пещерный паук",
    "Обугленный жук",
    "Падальщик",
    "Костяной грызун",
    "Гоблин-разведчик",
    "Костяной воин",
    "Пепельный волк",
    "Грибная тварь",
    "Гоблин-шаман",
    "Культист",
    "Проклятый рыцарь",
    "Каменный голем",
    "Лавовый элементаль",
    "Пепельный страж",
    "Адская гончая",
    "Огненный демон",
    "Пустотный наблюдатель",
    "Элитный голем",
    "Пепельный палач",
]

# The modern atlas source is a COMPOSITE POSTER with labels and a brown
# background, not twenty ready-to-render transparent standalone textures.
# Until original isolated approved animation frames are imported/verified,
# native gameplay must fail CLOSED and render none of the old sprites.
const IS_ART_IMPORTED := false
const ART_BY_ATLAS_INDEX: Array[String] = []

static func get_art_name(art_index: int) -> String:
    if art_index < 0 or art_index >= NAME_BY_ATLAS_INDEX.size():
        return ""
    return str(NAME_BY_ATLAS_INDEX[art_index])

static func is_ready() -> bool:
    return IS_ART_IMPORTED and ART_BY_ATLAS_INDEX.size() == NAME_BY_ATLAS_INDEX.size()
