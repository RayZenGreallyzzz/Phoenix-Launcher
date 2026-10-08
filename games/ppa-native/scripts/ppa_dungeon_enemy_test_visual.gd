extends Node2D

# Locally rendered, deliberately provisional enemy silhouettes. Positions and
# branch levels come from the ACTUAL deployed PPA dungeon, but no server mob
# state, original monster art, HP, drops or character damage are fabricated.
# Lightweight CanvasItem drawing keeps Android WebGL/GL Compatibility simple.
var mob_id := -1
var mob_level := 1
var is_boss := false
var boss_kind := "phoenix"
var is_aggro := false
var attack_pulse := false
var _caption: Label

func setup(source_id: int, level: int, boss: bool, boss_id: String = "") -> void:
    mob_id = source_id
    mob_level = level
    is_boss = boss
    boss_kind = boss_id
    z_index = 4
    _caption = Label.new()
    _caption.name = "EnemyTestLabel"
    _caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _caption.position = Vector2(-88.0 if boss else -52.0, -115.0 if boss else -63.0)
    _caption.size = Vector2(176.0 if boss else 104.0, 30.0)
    _caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _caption.add_theme_font_size_override("font_size", 16 if boss else 12)
    _caption.add_theme_color_override("font_color", Color("#F4D8B2"))
    _caption.text = ("БОСС · " + ("ФЕНИКС" if boss_kind == "phoenix" else ("ВЛАДЫКА" if boss_kind == "lord" else "ДРАКОН"))) if boss else "МОБ · УР. %d" % mob_level
    add_child(_caption)
    queue_redraw()

func set_aggro(active: bool) -> void:
    if is_aggro != active:
        is_aggro = active
        queue_redraw()

func set_attack(active: bool) -> void:
    if attack_pulse != active:
        attack_pulse = active
        queue_redraw()

func _draw() -> void:
    var tier := 0 if mob_level <= 20 else (1 if mob_level <= 40 else 2)
    var hide_color := Color("#557C5A") if tier == 0 else (Color("#765D98") if tier == 1 else Color("#A94F5F"))
    var torso := Color("#293D34") if tier == 0 else (Color("#332C45") if tier == 1 else Color("#4D292F"))
    var line := Color("#E5C57D") if is_boss else (Color("#D69D68") if is_aggro else Color("#7D967C"))
    var glow := Color("#F7DE91") if attack_pulse else (Color("#FF6E59") if is_aggro else Color("#A7F0CB"))

    if is_boss:
        if boss_kind == "phoenix":
            hide_color = Color("#D85B31")
            torso = Color("#702E24")
            glow = Color("#FFD65B")
        elif boss_kind == "lord":
            hide_color = Color("#715B9C")
            torso = Color("#292438")
            glow = Color("#F27AEE")
        else:
            hide_color = Color("#5D9A73")
            torso = Color("#193D35")
            glow = Color("#AAE9D1")
        # Winged/armored large boss with distinct crown and claws.
        draw_colored_polygon(PackedVector2Array([
            Vector2(-19,-50),Vector2(-92,-78),Vector2(-76,-28),
            Vector2(-101,-13),Vector2(-46,-20),Vector2(-22,-12)
        ]), hide_color.darkened(0.24))
        draw_colored_polygon(PackedVector2Array([
            Vector2(19,-50),Vector2(92,-78),Vector2(76,-28),
            Vector2(101,-13),Vector2(46,-20),Vector2(22,-12)
        ]), hide_color.darkened(0.24))
        draw_colored_polygon(PackedVector2Array([
            Vector2(-29,-72),Vector2(-12,-102),Vector2(0,-82),
            Vector2(12,-102),Vector2(29,-72)
        ]), hide_color)
        draw_colored_polygon(PackedVector2Array([
            Vector2(-31,-59),Vector2(-40,-11),Vector2(-28,4),
            Vector2(28,4),Vector2(40,-11),Vector2(31,-59)
        ]), torso)
        draw_colored_polygon(PackedVector2Array([
            Vector2(-30,-7),Vector2(-24,17),Vector2(-10,20),
            Vector2(-7,1)
        ]), hide_color)
        draw_colored_polygon(PackedVector2Array([
            Vector2(30,-7),Vector2(24,17),Vector2(10,20),
            Vector2(7,1)
        ]), hide_color)
        draw_circle(Vector2(-12,-65),7,glow)
        draw_circle(Vector2(12,-65),7,glow)
        draw_arc(Vector2(0,-43),39,0.15,PI-0.15,22,line,2.5)
        return

    # Distinct hand-drawn hostile creature test silhouette (not a human avatar).
    draw_colored_polygon(PackedVector2Array([
        Vector2(-15,-41), Vector2(-30,-53), Vector2(-26,-24),
        Vector2(-17,-18), Vector2(-26,0), Vector2(-10,5),
        Vector2(-2,-10), Vector2(11,5), Vector2(27,0),
        Vector2(18,-20), Vector2(26,-42), Vector2(14,-37)
    ]), hide_color)
    draw_colored_polygon(PackedVector2Array([
        Vector2(-15,-39), Vector2(-10,-48), Vector2(10,-48),
        Vector2(19,-39), Vector2(21,-18), Vector2(12,-4),
        Vector2(-13,-4), Vector2(-22,-18)
    ]), torso)
    draw_colored_polygon(PackedVector2Array([
        Vector2(-18,-38),Vector2(-24,-55),Vector2(-12,-43),
        Vector2(12,-43),Vector2(23,-55),Vector2(18,-34)
    ]), hide_color.darkened(0.32))
    draw_circle(Vector2(-7,-28),3.5,glow)
    draw_circle(Vector2(7,-28),3.5,glow)
    draw_line(Vector2(-10,-14),Vector2(10,-14),line,2)
    if attack_pulse:
        draw_arc(Vector2(0,-24),25,-PI*0.18,PI*1.13,18,Color("#F9B858"),2.5)
