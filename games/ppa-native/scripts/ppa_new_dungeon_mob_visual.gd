extends Node2D

# Candidate NEW dungeon roster from the user's unshipped original "Атлас
# пиксельных монстров 1–20.png" in Library, not the published old PPA art.
# Every PNG belongs in res://assets/dungeon_new_mobs/; never fall back to
# DUNGEON_MOB_SPRITES or the legacy original_dungeon_mob_XX.png assets.
const NEW_MOBS := [
    "mob_01_ash_rat.png",
    "mob_02_cave_spider.png",
    "mob_03_charred_beetle.png",
    "mob_04_carrion_bird.png",
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
const ART_DIR := "res://assets/dungeon_new_mobs/"

var image_sprite: Sprite2D
var selected_level := 0

static func available_count() -> int:
    var count := 0
    for filename in NEW_MOBS:
        if ResourceLoader.exists(ART_DIR + filename):
            count += 1
    return count

static func artwork_complete() -> bool:
    return available_count() == NEW_MOBS.size()

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
    var resource_path := ART_DIR + NEW_MOBS[level - 1]
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
