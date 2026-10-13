extends RefCounted

# One crop for the SMALL learned-skill icons (character skills + combat HUD).
# The complete original Telegram grimoire cover stays untouched in book details.
const SHADER := preload("res://shaders/ppa_grimoire_medallion.gdshader")
const MEDALLION_WIDTH_RATIO := 0.64

static func center_medallion(image: Texture2D) -> Texture2D:
    if image == null or image.get_width() <= 0 or image.get_height() <= 0:
        return null
    var crop_side := mini(int(round(float(image.get_width()) * MEDALLION_WIDTH_RATIO)),
        int(round(float(image.get_height()) * 0.50)))
    crop_side = maxi(1,crop_side)
    var crop := AtlasTexture.new()
    crop.atlas = image
    crop.region = Rect2(
        Vector2(float(image.get_width() - crop_side) * 0.5,
            float(image.get_height() - crop_side) * 0.5),
        Vector2(crop_side,crop_side))
    crop.filter_clip = true
    return crop

static func load_medallion(path: String) -> Texture2D:
    if path.is_empty() or not ResourceLoader.exists(path):
        return null
    var full := load(path) as Texture2D
    return center_medallion(full)

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
    icon.texture = load_medallion(path)
    return icon
