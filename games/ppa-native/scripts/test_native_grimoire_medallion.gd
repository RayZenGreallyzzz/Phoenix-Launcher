extends SceneTree

# Render-only test: only authentic center emblem of the 72 PPA book covers
# may appear in character skills and round combat skill buttons.
const MEDALLION = preload("res://scripts/ppa_grimoire_skill_icon.gd")
const BOOKS = preload("res://scripts/ppa_grimoire_catalog_generated.gd")
const SCREEN = preload("res://scripts/ppa_character_screen.gd")
const HUD = preload("res://scripts/ppa_combat_hud.gd")

func _initialize() -> void:
    call_deferred("_check")

func require(value: bool, message: String) -> void:
    if not value:
        push_error("PPA_SKILL_MEDALLION_FAIL: " + message)
        quit(1)
        assert(value,message)

func _check() -> void:
    var catalog: Dictionary = BOOKS.class_info("archer")
    var active: Array = catalog.get("active",[])
    require(active.size()==4,"Cannot load original Archer skills")
    var path := str((active[0] as Dictionary).get("cardArt",""))
    require(ResourceLoader.exists(path),"Missing authentic book cover")
    var original := load(path) as Texture2D
    var sample := MEDALLION.make_icon(path,48.0)
    var crop := (sample.material as ShaderMaterial).get_shader_parameter("crop_fraction") as Vector2
    require(original!=null and sample.texture==original,
        "Skill symbol must sample ONLY its authentic original source cover")
    require(crop.x > 0 and crop.y > 0 and crop.x < 0.8 and crop.y < 0.8,
        "Crop did not isolate only the middle of the original book")
    require(absf(crop.x*float(original.get_width())
        -crop.y*float(original.get_height()))<1.0,
        "Crop must sample a centered square area before circular mask")
    sample.free()

    var host := Control.new()
    host.size = Vector2(720,900)
    root.add_child(host)
    var hud := HUD.new()
    host.add_child(hud)
    hud.size = host.size
    hud.set_class_key("archer")
    hud.apply_server_save({"skillRanks":{str(active[0]["id"]):2}})
    await process_frame
    var button := hud._skills[0]
    var hud_emblem := button.find_child("PPAApprovedGrimoireCenterMedallion",true,false) as TextureRect
    require(hud_emblem!=null and hud_emblem.visible
        and hud_emblem.texture is Texture2D,
        "Combat ability button still shows full book art")
    require(button.icon==null,"Uncropped cover leaked to combat Button.icon")
    require(hud_emblem.material is ShaderMaterial,
        "Combat skill missing circular emblem mask")
    var skill_clicks: Array = []
    hud.action_requested.connect(func(action: String, index: int):
        skill_clicks.append([action,index]))
    button.pressed.emit()
    require(skill_clicks==[["skill",0]],
        "Circular artwork accidentally disabled the skill button")
    var hero := SCREEN.new()
    hero.class_key = "archer"
    hero._mono = SystemFont.new()
    var rows := VBoxContainer.new()
    host.add_child(rows)
    hero._page_container = rows
    hero._draw_source_skill_card({
        "id":str(active[0]["id"]), "rank":2, "n":str(active[0].get("n","Skill")),
        "book1":1,"book2":0,"book3":0
    },false)
    await process_frame
    var skill_slot := rows.find_child("OriginalPPASkillIcon",true,false) as PanelContainer
    require(skill_slot!=null,"Character active skill has no full book slot")
    var skill_image := skill_slot.get_child(0) as TextureRect
    require(skill_image!=null and skill_image.texture==original
        and skill_image.material==null,
        "Character ACTIVE skill must show original COMPLETE grimoire book")
    require(skill_image.custom_minimum_size==Vector2(58.0,76.0),
        "Character book image must remain the full portrait cover")
    require(skill_slot.find_child("PPAApprovedGrimoireCenterMedallion",true,false)==null,
        "Circular battle-only skill graphic leaked into character menu")
    var passive: Array = catalog.get("passive",[])
    require(not passive.is_empty(),"Canonical passive skill definitions missing")
    hero._draw_source_skill_card({
        "id":str(passive[0]["id"]),"rank":1,"n":str(passive[0].get("n","Passive"))
    },true)
    await process_frame
    var covers := rows.find_children("OriginalPPASkillIcon","PanelContainer",true,false)
    require(covers.size()==2,"Character menu must show both active and passive book cards")
    var passive_picture := (covers[1] as PanelContainer).get_child(0) as TextureRect
    var passive_path := str(passive[0].get("cardArt",""))
    require(passive_picture!=null and passive_picture.texture==load(passive_path)
        and passive_picture.material==null,
        "Character PASSIVE skill must also retain complete original book cover")
    host.queue_free()
    await process_frame
    print("PPA_ORIGINAL_SKILL_MEDALLION_OK center_crop=1 circle_mask=1 combat=1 active_full_book=1 passive_full_book=1 click=1 writes=0")
    quit(0)
