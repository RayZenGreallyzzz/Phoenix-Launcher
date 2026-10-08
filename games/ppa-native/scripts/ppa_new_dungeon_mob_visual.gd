extends Node2D

# Approved 1-20 mob names are taken from the current PPA video, not from
# old 2026-09 art posters. Artwork itself remains gated until verified.
# Every PNG belongs in res://assets/dungeon_new_mobs/; never fall back to
# DUNGEON_MOB_SPRITES or the legacy original_dungeon_mob_XX.png assets.
const NEW_MOBS := [
    "mob_01_ash_rat.png",
    "mob_02_cave_spider.png",
    "mob_03_charred_beetle.png",
    "mob_04_slime_green.png",
    "mob_05_bone_rodent.png",
    "mob_06_goblin_scout.png",
    "mob_07_bone_warrior.png",
    "mob_08_ash_wolf.png",
    "mob_09_mushroom_abomination.png",
    "mob_10_goblin_shaman.png",
    "mob_11_cultist.png",
    "mob_12_cursed_knight.png",
    "mob_13_stone_golem.png",
    "mob_14_lava_elemental.png",
    "mob_15_ash_guard.png",
    "mob_16_hell_hound.png",
    "mob_17_fire_demon.png",
    "mob_18_void_watcher.png",
    "mob_19_elite_golem.png",
    "mob_20_ash_executioner.png"
]
# Level-to-kind mapping is EXACT, not bracket-based. The level-4 slime
# has three approved visual color variants, selected using stable spawn ID.
const LEVEL_NAMES := [
    "Пепельная крыса", "Пещерный паук", "Обугленный жук",
    "Слайм-падальщик", "Костяной грызун", "Гоблин-разведчик",
    "Костяной воин", "Пепельный волк", "Грибная тварь", "Гоблин-шаман",
    "Культист", "Проклятый рыцарь", "Каменный голем", "Лавовый элементаль",
    "Пепельный страж", "Адская гончая", "Огненный демон",
    "Пустотный наблюдатель", "Элитный голем", "Пепельный палач"
]
const SLIME_VARIANTS := [
    "mob_04_slime_green.png",
    "mob_04_slime_red.png",
    "mob_04_slime_blue.png"
]
const EXTRA_SLIME_FILES := [
    "mob_04_slime_red.png",
    "mob_04_slime_blue.png"
]
const ART_DIR := "res://assets/dungeon_new_mobs/"

var image_sprite: Sprite2D
var selected_level := 0

static func required_file_count() -> int:
    return NEW_MOBS.size() + EXTRA_SLIME_FILES.size()

static func available_count() -> int:
    var count := 0
    for filename in NEW_MOBS:
        if ResourceLoader.exists(ART_DIR + filename):
            count += 1
    for filename in EXTRA_SLIME_FILES:
        if ResourceLoader.exists(ART_DIR + filename):
            count += 1
    return count

static func artwork_complete() -> bool:
    # Refuse the old bird and the obsolete one-color alias.
    if ResourceLoader.exists(ART_DIR + "mob_04_carrion_bird.png"):
        return false
    if ResourceLoader.exists(ART_DIR + "mob_04_scavenger_slime.png"):
        return false
    return available_count() == required_file_count()

static func art_index_for_spawn(level: int, _spawn_id: int) -> int:
    if level < 1 or level > NEW_MOBS.size():
        return -1
    # A whole level has one mob KIND, not a random creature from a five-level tier.
    return level - 1

static func sprite_filename_for_spawn(level: int, spawn_id: int) -> String:
    if level < 1 or level > NEW_MOBS.size():
        return ""
    if level == 4:
        return SLIME_VARIANTS[posmod(spawn_id, SLIME_VARIANTS.size())]
    return String(NEW_MOBS[level - 1])

func setup(_index: int, level: int, boss: bool, _boss_kind: String = "") -> void:
    if boss:
        # The three newly approved boss art packs are a separate import.
        # Never display ancient published Phoenix/Lord/Dragon PNG by accident.
        push_error("PPA_NEW_DUNGEON_BOSS_ART_PENDING: cannot use legacy boss")
        visible = false
        return
    selected_level = level
    if level < 1 or level > 20:
        push_error("PPA_NEW_DUNGEON_LEVEL_ART_PENDING: " + str(level))
        visible = false
        return
    var kind := art_index_for_spawn(level, _index)
    if kind < 0:
        visible = false
        return
    var resource_path: String = ART_DIR + sprite_filename_for_spawn(level, _index)
    if not ResourceLoader.exists(resource_path):
        push_error("PPA_NEW_DUNGEON_MOB_PNG_MISSING: " + resource_path)
        visible = false
        return
    var tex := load(resource_path) as Texture2D
    if tex == null:
        push_error("PPA_NEW_DUNGEON_MOB_IMPORT_FAILURE: " + resource_path)
        visible = false
        return
    image_sprite = Sprite2D.new()
    image_sprite.name = "NewDungeonMob_%02d" % level
    image_sprite.texture = tex
    image_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    image_sprite.centered = true
    var target_height := 74.0
    var zoom := minf(88.0 / float(tex.get_width()), target_height / float(tex.get_height()))
    image_sprite.scale = Vector2.ONE * zoom
    image_sprite.position = Vector2(0.0, -float(tex.get_height()) * zoom / 2.0)
    add_child(image_sprite)

func set_aggro(active: bool) -> void:
    if image_sprite != null:
        image_sprite.modulate = Color("#FFE0D0") if active else Color.WHITE

func set_attack(active: bool) -> void:
    if image_sprite != null:
        image_sprite.self_modulate = Color("#FFD8BD") if active else Color.WHITE
