extends Node2D

# Original published PPA monster images ONLY. No generated polygon monsters,
# green cardboard figures, invented character meshes, or fake world shadows.
# Art is downloaded and SHA verified in GitHub Actions at build time.
const ART = preload("res://scripts/ppa_dungeon_art_generated.gd")

var mob_id := -1
var mob_level := 1
var is_boss := false
var boss_kind := "phoenix"
var is_aggro := false
var attack_pulse := false
var _picture: Sprite2D
var _caption: Label

func setup(source_id: int, level: int, boss: bool, boss_id: String = "") -> void:
    mob_id = source_id
    mob_level = level
    is_boss = boss
    boss_kind = boss_id
    z_index = 4
    var resource_path := ""
    if is_boss:
        resource_path = str(ART.BOSS_RESOURCES.get(boss_kind, ""))
    else:
        var source_index := posmod(mob_level - 1, 20)
        resource_path = str(ART.MOB_RESOURCES[source_index])
    if resource_path.is_empty() or not ResourceLoader.exists(resource_path):
        push_error("PPA_MOB_ORIGINAL_ART_MISSING: " + resource_path + " " + boss_kind)
        return
    var tex := load(resource_path) as Texture2D
    if tex == null or tex.get_width() < 24 or tex.get_height() < 24:
        push_error("PPA_MOB_ORIGINAL_ART_INVALID: " + resource_path)
        return

    # Lord40 is published as a sprite ATLAS: show one genuine frame, never the
    # entire tiled sheet squeezed into a giant character on-screen.
    var displayed_texture: Texture2D = tex
    if is_boss and boss_kind == "lord":
        var frame := AtlasTexture.new()
        frame.atlas = tex
        frame.region = Rect2(
            0.0, 0.0,
            floorf(float(tex.get_width()) / 4.0),
            floorf(float(tex.get_height()) / 4.0)
        )
        displayed_texture = frame

    _picture = Sprite2D.new()
    _picture.name = "OriginalPpaEnemySprite"
    _picture.texture = displayed_texture
    _picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _picture.centered = true
    var preferred_h := 185.0 if is_boss else 68.0
    var preferred_w := preferred_h * float(displayed_texture.get_width()) / maxf(1.0, float(displayed_texture.get_height()))
    var max_width := 245.0 if is_boss else 87.0
    if preferred_w > max_width:
        preferred_h *= max_width / preferred_w
        preferred_w = max_width
    _picture.scale = Vector2(
        preferred_w / float(displayed_texture.get_width()),
        preferred_h / float(displayed_texture.get_height())
    )
    # Bottom of the original art touches the exact source map ground point.
    _picture.position = Vector2(0.0, -preferred_h * 0.5)
    add_child(_picture)

    if is_boss:
        _caption = Label.new()
        _caption.name = "OriginalPpaBossCaption"
        _caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _caption.position = Vector2(-110.0, -preferred_h - 24.0)
        _caption.size = Vector2(220.0, 28.0)
        _caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        _caption.add_theme_font_size_override("font_size", 14)
        _caption.add_theme_color_override("font_color", Color("#F6D5A4"))
        var title := "ФЕНИКС" if boss_kind == "phoenix" else ("ВЛАДЫКА" if boss_kind == "lord" else "ДРАКОН")
        _caption.text = "БОСС · " + title + " · УР. " + str(mob_level)
        add_child(_caption)
    # Regular mobs have NO permanent nameplates, preventing unreadable label
    # piles near dungeon rooms and along the top/bottom phone HUD.

func set_aggro(active: bool) -> void:
    if is_aggro == active:
        return
    is_aggro = active
    if _picture != null:
        _picture.modulate = Color("#FFE5D6") if active else Color.WHITE

func set_attack(active: bool) -> void:
    if attack_pulse == active:
        return
    attack_pulse = active
    # Visual indication only. No client-side HP, skill, loot, or reward.
    if _picture != null and is_aggro:
        _picture.modulate = Color("#FFDDBB") if active else Color("#FFE5D6")
