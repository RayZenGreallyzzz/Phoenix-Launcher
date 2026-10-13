extends RefCounted

# Render only the centered medallion from the authentic source book in the
# small active/passive skill icon and round combat HUD. The full book remains
# unchanged in the grimoire details popup. No generated/owned items.
const SHADER := preload("res://shaders/ppa_grimoire_medallion.gdshader")
const MEDALLION_WIDTH_RATIO := 0.64

static func set_book(icon: TextureRect, path: String) -> void:
    if icon == null:
        return
    icon.texture = null
    if path.is_empty() or not ResourceLoader.exists(path):
        return
    var original := load(path) as Texture2D
    if original == null or original.get_width() <= 0 or original.get_height() <= 0:
        return
    var crop_side := maxf(1.0,minf(float(original.get_width()) * MEDALLION_WIDTH_RATIO,
        float(original.get_height()) * 0.50))
    # Shader crops the original texture around the exact center then masks
    # the resulting square into a circle. UV therefore ALWAYS runs 0..1,
    # unlike AtlasTexture UVs, which refer to an atlas region.
    var region_fraction := Vector2(crop_side/float(original.get_width()),
        crop_side/float(original.get_height()))
    if icon.material is ShaderMaterial:
        (icon.material as ShaderMaterial).set_shader_parameter("crop_fraction",region_fraction)
    icon.texture = original

static func make_icon(path: String, diameter: float) -> TextureRect:
    var icon := TextureRect.new()
    icon.name = "PPAApprovedGrimoireCenterMedallion"
    icon.custom_minimum_size = Vector2(diameter,diameter)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_SCALE
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var material := ShaderMaterial.new()
    material.shader = SHADER
    icon.material = material
    set_book(icon,path)
    return icon
