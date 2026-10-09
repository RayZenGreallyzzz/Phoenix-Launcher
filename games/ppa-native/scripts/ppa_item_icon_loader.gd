extends Node

# Native PNG/WebP icon resolver: HTTPS assets of the SAME existing PPA
# Worker only. Never loads code, a remote document, or a user-supplied host.
# Lazy requests, maximum three simultaneous downloads, memory-only cache.
const ASSET_BASE := "https://ppa-phoenixpixarena.1988stella1988.workers.dev"
const MAX_PARALLEL := 3
const MAX_BYTES := 5 * 1024 * 1024
const CLASS_KEYS := ["tank", "paladin", "barbarian", "assassin", "gnome", "archer", "mage", "priest"]
const LEGENDARY_SLOTS := ["weapon", "helmet", "armor", "legs", "gloves", "boots"]
const VIEW = preload("res://scripts/ppa_server_inventory_view.gd")

var _cache: Dictionary = {}
var _failed: Dictionary = {}
var _waiting: Dictionary = {}
var _queue: Array[String] = []
var _active := 0

static func _class_key(item: Dictionary, actual_class: String) -> String:
    for field in ["classKey", "class", "cls", "ownerClass", "reqClass"]:
        var cls := str(item.get(field, "")).to_lower()
        if CLASS_KEYS.has(cls):
            return cls
    var name := str(item.get("name", "")).to_lower()
    var aliases := {
        "paladin": ["паладин"], "barbarian": ["варвар", "берсерк"],
        "assassin": ["ассасин"], "gnome": ["гном", "канонир"],
        "archer": ["лучник"], "mage": ["маг"], "priest": ["жрец"],
        "tank": ["танк", "воин"]
    }
    for cls in CLASS_KEYS:
        for hint in aliases[cls]:
            if name.contains(hint):
                return cls
    return actual_class if CLASS_KEYS.has(actual_class) else ""

static func _slot_key(item: Dictionary) -> String:
    var slot := str(item.get("slot", item.get("equipSlot", item.get("type", "")))).to_lower()
    var aliases := {
        "pants":"legs", "leggings":"legs", "helm":"helmet",
        "chest":"armor", "glove":"gloves", "boot":"boots"
    }
    slot = str(aliases.get(slot, slot))
    if LEGENDARY_SLOTS.has(slot):
        return slot
    if slot in ["ring", "necklace", "amulet"]:
        return ""
    var name := str(item.get("name", "")).to_lower()
    var hints := {
        "helmet":["шлем"], "armor":["брон", "доспех"],
        "legs":["понож", "штаны"], "gloves":["перчат", "рукавиц"],
        "boots":["сапог", "ботин"],
        "weapon":["меч", "кинжал", "топор", "лук", "посох", "пушк", "мушкет", "молот", "оруж"]
    }
    for kind in LEGENDARY_SLOTS:
        for hint in hints.get(kind, []):
            if name.contains(hint):
                return kind
    return ""

static func _allowed_path(value: String) -> String:
    var path := value.strip_edges()
    # Telegram PPA build.mjs externalizes inline art as "./assets/<hash>.webp".
    # That original relative form MUST resolve to the same Worker /assets URL.
    if path.begins_with(ASSET_BASE + "/assets/"):
        path = path.trim_prefix(ASSET_BASE)
    elif path.begins_with("./assets/"):
        path = path.trim_prefix(".")
    elif path.begins_with("assets/"):
        path = "/" + path
    if not path.begins_with("/assets/") or path.contains("..") or path.contains("\\") or path.contains("%"):
        return ""
    var filename := path.get_slice("?", 0).to_lower()
    if not (filename.ends_with(".png") or filename.ends_with(".webp") or filename.ends_with(".jpg") or filename.ends_with(".jpeg")):
        return ""
    return path

static func art_path(item: Dictionary, actual_class: String) -> String:
    # Exact approved Telegram PPA v514 legend assets, six gear slots
    # for all eight classes. Rings/necklaces preserve their own imagery.
    if VIEW.rarity(item) == "legendary":
        var slot := _slot_key(item)
        var cls := _class_key(item, actual_class)
        if not slot.is_empty() and not cls.is_empty():
            return "/assets/legendary/" + cls + "-" + slot + ".webp?v=v514"
    for field in ["iconArt", "img", "image", "cardArt", "iconImg", "art", "src"]:
        var path := _allowed_path(str(item.get(field, "")))
        if not path.is_empty():
            return path
    return ""

func bind_button(item: Dictionary, actual_class: String, button: Button) -> void:
    var path := art_path(item, actual_class)
    if path.is_empty():
        # Some original item records have no image at all. Keep their name
        # visible in native inventory rather than an unhelpful "×1" tile.
        return
    button.tooltip_text = str(item.get("name", item.get("title", "Предмет PPA")))
    button.set_meta("ppa_icon_path", path)
    button.set_meta("ppa_icon_qty", VIEW.item_count(item))
    button.set_meta("ppa_icon_upgrade", int(item.get("upgrade", item.get("plus", 0))))
    if _cache.has(path):
        _show_icon(button, path, _cache[path])
        return
    if _failed.has(path):
        return
    if not _waiting.has(path):
        _waiting[path] = []
        _queue.append(path)
    _waiting[path].append(weakref(button))
    _start_more()

func _show_icon(button: Button, path: String, texture: Texture2D) -> void:
    if not is_instance_valid(button) or button.get_meta("ppa_icon_path", "") != path:
        return
    button.icon = texture
    button.expand_icon = true
    button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
    button.text = ""
    button.add_theme_constant_override("icon_max_width", 56)
    # Icons must not hide the actual server stack count and upgrade.
    for key in ["qty", "upgrade"]:
        var amount: int = int(button.get_meta("ppa_icon_" + key, 0))
        if amount <= 0 or (key == "qty" and amount == 1):
            continue
        var label := Label.new()
        label.name = "PPAReal" + key.capitalize()
        label.text = ("×" if key == "qty" else "+") + str(amount)
        label.anchor_left = 1.0 if key == "qty" else 0.0
        label.anchor_right = label.anchor_left
        label.anchor_top = 1.0 if key == "qty" else 0.0
        label.anchor_bottom = label.anchor_top
        label.offset_left = -46.0 if key == "qty" else 3.0
        label.offset_right = -3.0 if key == "qty" else 46.0
        label.offset_top = -21.0 if key == "qty" else 1.0
        label.offset_bottom = -1.0 if key == "qty" else 21.0
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if key == "qty" else HORIZONTAL_ALIGNMENT_LEFT
        label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        label.add_theme_font_size_override("font_size", 11)
        label.add_theme_color_override("font_color", Color("#FFD78F"))
        label.add_theme_color_override("font_shadow_color", Color.BLACK)
        label.add_theme_constant_override("shadow_offset_x", 1)
        label.add_theme_constant_override("shadow_offset_y", 1)
        button.add_child(label)

func _start_more() -> void:
    while _active < MAX_PARALLEL and not _queue.is_empty():
        var path: String = _queue.pop_front()
        var request := HTTPRequest.new()
        request.timeout = 15.0
        request.max_body_size = MAX_BYTES
        add_child(request)
        _active += 1
        request.request_completed.connect(_received.bind(request, path))
        var err := request.request(ASSET_BASE + path, PackedStringArray(["Accept: image/webp,image/png,image/jpeg"]), HTTPClient.METHOD_GET)
        if err != OK:
            _active -= 1
            _failed[path] = true
            _waiting.erase(path)
            request.queue_free()

func _received(result: int, code: int, headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest, path: String) -> void:
    _active = maxi(0, _active - 1)
    if is_instance_valid(request):
        request.queue_free()
    var texture: Texture2D = null
    if result == HTTPRequest.RESULT_SUCCESS and code == 200 and body.size() > 0 and body.size() <= MAX_BYTES:
        var image := Image.new()
        var ext := path.get_slice("?", 0).get_extension().to_lower()
        var err := ERR_FILE_UNRECOGNIZED
        if ext == "webp":
            err = image.load_webp_from_buffer(body)
        elif ext == "png":
            err = image.load_png_from_buffer(body)
        elif ext == "jpg" or ext == "jpeg":
            err = image.load_jpg_from_buffer(body)
        if err == OK and image.get_width() > 0 and image.get_height() > 0:
            texture = ImageTexture.create_from_image(image)
    if texture == null:
        _failed[path] = true
    else:
        _cache[path] = texture
        for weak in _waiting.get(path, []):
            var button: Button = weak.get_ref()
            if button != null:
                _show_icon(button, path, texture)
    _waiting.erase(path)
    _start_more()
