extends Node2D

# TEST-ONLY: never-shipped Library art for five *candidate* dungeon monsters
# and two boss candidates. Not the approved level-to-monster mapping.
# The binary atlas is injected only by the private QA build, never committed
# to public Phoenix-Launcher or to the original Telegram PPA.
const PRIVATE_PREVIEW_ATLAS := "res://assets/new_dungeon_candidate_qa.webp"
const CANDIDATE_MOB_COUNT := 5
const CANDIDATE_TOTAL := 7

var mob_id := -1
var mob_level := 1
var is_boss := false
var boss_kind := ""
var is_aggro := false
var attack_pulse := false
var art_candidate := -1
var _picture: Sprite2D

static func source_ready() -> bool:
    return ResourceLoader.exists(PRIVATE_PREVIEW_ATLAS)

func setup(source_id: int, level: int, boss: bool, boss_id: String = "") -> void:
    mob_id = source_id
    mob_level = level
    is_boss = boss
    boss_kind = boss_id
    z_index = 4
    if not source_ready():
        visible = false
        push_error("PPA_NEW_DUNGEON_QA_ASSET_MISSING: old artwork is forbidden")
        return
    var atlas_texture := load(PRIVATE_PREVIEW_ATLAS) as Texture2D
    if atlas_texture == null or atlas_texture.get_width() < 7:
        visible = false
        push_error("PPA_NEW_DUNGEON_QA_ATLAS_INVALID")
        return
    var frame_size := floori(float(atlas_texture.get_width()) / 7.0)
    if frame_size < 48 or atlas_texture.get_height() != frame_size:
        visible = false
        push_error("PPA_NEW_DUNGEON_QA_ATLAS_FRAME_INVALID")
        return
    # Reaper / Spider / Tentacle / Dark Guard / Golem are only *visual*
    # candidates; do not infer which PPA dungeon levels they belong to.
    if boss:
        if boss_id == "phoenix":
            art_candidate = 5
        elif boss_id == "dragon":
            art_candidate = 6
        else:
            # No confirmed current Lord40 art. Never substitute an ancient
            # Lord sprite or another boss image as a fake replacement.
            visible = false
            return
    else:
        art_candidate = posmod(source_id, CANDIDATE_MOB_COUNT)
    var frame := AtlasTexture.new()
    frame.atlas = atlas_texture
    frame.region = Rect2(art_candidate * frame_size, 0.0, frame_size, frame_size)
    _picture = Sprite2D.new()
    _picture.name = "NewUnreleasedCandidateArt"
    _picture.texture = frame
    _picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
    var visual_size := 185.0 if boss else 91.0
    _picture.scale = Vector2.ONE * (visual_size / float(frame_size))
    _picture.position = Vector2(0.0, -visual_size * 0.5)
    add_child(_picture)
    if boss:
        var caption := Label.new()
        caption.name = "CandidateBossCaption"
        caption.text = ("НОВЫЙ ФЕНИКС · ТЕСТ" if boss_id == "phoenix"
            else "НОВЫЙ ДРАКОН · ТЕСТ")
        caption.size = Vector2(240.0, 26.0)
        caption.position = Vector2(-120.0, -visual_size - 28.0)
        caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
        caption.add_theme_font_size_override("font_size", 12)
        add_child(caption)

func set_aggro(active: bool) -> void:
    is_aggro = active
    if _picture != null:
        _picture.modulate = Color("#FFE3CC") if active else Color.WHITE

func set_attack(active: bool) -> void:
    attack_pulse = active
    if _picture != null and is_aggro:
        _picture.modulate = Color("#FFC19C") if active else Color("#FFE3CC")
