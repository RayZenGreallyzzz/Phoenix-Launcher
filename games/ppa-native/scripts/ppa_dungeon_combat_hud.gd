extends Control

# Standalone native Godot TEST-only combat HUD. No backend/UI bridge.
# Button callbacks are hooked by dungeon_world.gd for LOCAL previews only.
signal attack_pressed
signal skill_pressed(slot: int)
signal potion_pressed(kind: String)

var hp_bar: ProgressBar
var mp_bar: ProgressBar
var player_text: Label
var stat_text: Label
var target_text: Label
var notice_text: Label
var attack_button: Button
var hp_button: Button
var mp_button: Button
var skill_buttons: Array[Button] = []
var _buttons: Array[Button] = []
var _source_skills: Array = []

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    z_index = 72
    player_text = _label("БОЙ · ТЕСТ БЕЗ СЕРВЕРА",16,Color("#F1CD95"),Vector2(16,72),Vector2(350,25))
    hp_bar = _bar("LocalTestPlayerHP",Vector2(16,101),Vector2(310,14),Color("#D74543"))
    mp_bar = _bar("LocalTestPlayerMP",Vector2(16,121),Vector2(310,13),Color("#398BDD"))
    stat_text = _label("АТК — · ЗАЩ — · ДАЛЬН —",11,Color("#E3C89C"),Vector2(16,142),Vector2(350,24))
    target_text = _label("ЦЕЛЬ: нет · авто-поиск по атаке",12,Color("#E7E7E7"),Vector2(16,194),Vector2(440,25))
    notice_text = _label("HP/MP, навыки и банки — только локальный тест",10,Color("#CBA767"),Vector2(16,220),Vector2(440,25))
    attack_button = _button("⚔\nАТАКА","LocalTestAttackButton",-110.0,-240.0,92.0,87.0,Color("#9C4A18"))
    attack_button.add_theme_font_size_override("font_size",17)
    attack_button.pressed.connect(func():attack_pressed.emit())
    hp_button = _button("HP +50\n×20","LocalTestPotionHP",-321,-189,103,44,Color("#802B37"))
    hp_button.pressed.connect(func():potion_pressed.emit("hp"))
    mp_button = _button("MP +50\n×20","LocalTestPotionMP",-321,-137,103,44,Color("#254B88"))
    mp_button.pressed.connect(func():potion_pressed.emit("mp"))
    for i in range(4):
        var row := int(i/2)
        var column := i%2
        var skill := _button("НАВЫК\n"+str(i+1),"LocalTestSkill"+str(i+1),
            -328.0+float(column)*107.0,-314.0+float(row)*62.0,
            101.0,55.0,Color("#4B365A"))
        skill.add_theme_font_size_override("font_size",10)
        skill.pressed.connect(_press_skill.bind(i))
        skill_buttons.append(skill)

func _press_skill(slot: int) -> void:
    skill_pressed.emit(slot)

func _label(text: String, font_size: int, tint: Color, pos: Vector2, dims: Vector2) -> Label:
    var l := Label.new()
    l.text=text
    l.position=pos
    l.size=dims
    l.mouse_filter=Control.MOUSE_FILTER_IGNORE
    l.add_theme_font_size_override("font_size",font_size)
    l.add_theme_color_override("font_color",tint)
    l.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
    add_child(l)
    return l

func _bar(tag: String,pos: Vector2,dims: Vector2,fill: Color) -> ProgressBar:
    var b:=ProgressBar.new()
    b.name=tag
    b.position=pos
    b.size=dims
    b.show_percentage=false
    b.min_value=0
    b.max_value=100
    b.value=100
    var background := StyleBoxFlat.new()
    background.bg_color=Color("#111314")
    background.set_corner_radius_all(2)
    var foreground := StyleBoxFlat.new()
    foreground.bg_color=fill
    foreground.set_corner_radius_all(2)
    b.add_theme_stylebox_override("background",background)
    b.add_theme_stylebox_override("fill",foreground)
    b.mouse_filter=Control.MOUSE_FILTER_IGNORE
    add_child(b)
    return b

func _button(caption:String,tag:String,dx:float,dy:float,w:float,h:float,tint:Color) -> Button:
    var b:=Button.new()
    b.name=tag
    b.text=caption
    b.anchor_left=1.0
    b.anchor_right=1.0
    b.anchor_top=1.0
    b.anchor_bottom=1.0
    b.offset_left=dx
    b.offset_right=dx+w
    b.offset_top=dy
    b.offset_bottom=dy+h
    b.mouse_filter=Control.MOUSE_FILTER_STOP
    b.focus_mode=Control.FOCUS_NONE
    b.add_theme_font_size_override("font_size",11)
    b.add_theme_color_override("font_color",Color.WHITE)
    var style:=StyleBoxFlat.new()
    style.bg_color=tint
    style.border_color=Color("#C79D58")
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    b.add_theme_stylebox_override("normal",style)
    b.add_theme_stylebox_override("hover",style)
    add_child(b)
    _buttons.append(b)
    return b

func set_skills(skills: Array) -> void:
    _source_skills=skills
    for i in range(skill_buttons.size()):
        if i>=skills.size():
            skill_buttons[i].disabled=true
            continue
        var def:Dictionary=skills[i]
        var title:=str(def.get("n","Навык"))
        skill_buttons[i].tooltip_text=title+" · ТЕСТ: MP "+str(def.get("mp",0))+" / откат "+str(def.get("cd",0))+"с"
        skill_buttons[i].text=title+"\nMP "+str(def.get("mp",0))

func update_display(hero: Dictionary, hp: int, mp: int, potions: Dictionary, cooldowns: Array,
        target: Dictionary, notice: String, alive: bool) -> void:
    hp_bar.max_value=maxi(1,int(hero.get("mhp",1)))
    hp_bar.value=hp
    hp_bar.tooltip_text="HP %d / %d" % [hp,int(hero.get("mhp",1))]
    mp_bar.max_value=maxi(1,int(hero.get("mmp",1)))
    mp_bar.value=mp
    mp_bar.tooltip_text="MP %d / %d" % [mp,int(hero.get("mmp",1))]
    player_text.text="%s · ур.%d · ТЕСТ" % [str(hero.get("name","Герой")),int(hero.get("level",1))]
    stat_text.text="HP %d/%d  MP %d/%d  АТК %d  DEF %d  ДАЛЬН %d" % [
        hp,int(hero.get("mhp",1)),mp,int(hero.get("mmp",1)),int(hero.get("atk",0)),
        int(hero.get("def",0)),int(hero.get("range",0))]
    if target.is_empty():
        target_text.text="ЦЕЛЬ: нет · ближайшая выбирается при атаке"
    else:
        target_text.text="ЦЕЛЬ ур.%d %s · HP %d/%d" % [
            int(target.get("level",0)),str(target.get("name","")),int(target.get("hp",0)),int(target.get("mhp",0))]
    notice_text.text=notice
    attack_button.disabled=not alive
    hp_button.text="HP +50\n×"+str(potions.get("hp",0))
    mp_button.text="MP +50\n×"+str(potions.get("mp",0))
    hp_button.disabled=not alive or int(potions.get("hp",0))<=0
    mp_button.disabled=not alive or int(potions.get("mp",0))<=0
    for i in range(skill_buttons.size()):
        if i>=_source_skills.size():
            skill_buttons[i].disabled=true
            continue
        var def:Dictionary=_source_skills[i]
        var remaining:=float(cooldowns[i]) if i<cooldowns.size() else 0.0
        var title:=str(def.get("n","Навык"))
        skill_buttons[i].text=title+"\n"+(
            "%.1fs" % remaining if remaining>0.05 else ("MP "+str(def.get("mp",0))))
        skill_buttons[i].disabled=not alive or remaining>0.05 or mp<int(def.get("mp",0))

func captures_joystick_point(point:Vector2) -> bool:
    for b in _buttons:
        if b.visible and b.get_global_rect().has_point(point):
            return true
    return false
