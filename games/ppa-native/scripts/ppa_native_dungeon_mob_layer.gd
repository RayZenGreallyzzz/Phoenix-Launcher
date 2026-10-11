extends Node2D

# Server-owned PPA mob state projected into the original dungeon canvas.
# The host feeds ONLY authenticated room-scoped WebSocket observations.
# Nothing here emits attacks, loot, XP, save changes or target commands.
const AUTHORITY = preload("res://scripts/ppa_native_mob_authority_view.gd")
const ART = preload("res://scripts/ppa_new_dungeon_mob_visual.gd")
const CATALOG = preload("res://scripts/ppa_dungeon_entities_generated.gd")
const MAX_VISIBLE := 24
const CULL_RADIUS := 675.0
const WALK_MASK_OFFSET := Vector2(0.0, 14.0)

var authority = AUTHORITY.new()
var _approved_art := false
var _tier := 0
var _branch: Array[int] = []
var _ordinal: Array[int] = []
var _source_spawns: Array[Vector2] = []
var _player := Vector2.ZERO
var _visible: Dictionary = {}
var packets_accepted := 0

func configure(room: String, source_spawns: Array[Vector2],
        branches: Array[int], ordinals: Array[int], tier: int,
        art_ready: bool) -> bool:
    if not room.begins_with("dungeon-") or source_spawns.size() != branches.size() \
            or branches.size() != ordinals.size() or tier < 0 or tier > 2:
        return false
    clear_authoritative_room()
    _tier = tier
    _source_spawns = source_spawns.duplicate()
    _branch = branches.duplicate()
    _ordinal = ordinals.duplicate()
    _approved_art = art_ready
    authority.bind_room(room)
    return true

func clear_authoritative_room() -> void:
    for key in _visible.keys():
        var node: Node2D = _visible[key]
        if is_instance_valid(node):
            remove_child(node)
            node.queue_free()
    _visible.clear()
    authority.bind_room("")
    packets_accepted = 0

func observe_player_position(point: Vector2) -> void:
    if not point.is_finite():
        return
    if _player.distance_squared_to(point) < 80.0 * 80.0:
        return
    _player = point
    _sync_view()

func apply_authenticated_packet(packet: Dictionary) -> bool:
    if not authority.apply_packet(packet):
        return false
    packets_accepted += 1
    if packet.get("type", "") == "mob-authority-snapshot" \
            and packet.get("done", false) != true:
        return true # Keep the last complete snapshot on screen.
    _sync_view()
    return true

func rendered_keys() -> Array:
    return _visible.keys().duplicate()

func _source_spawn_index(key: String) -> int:
    # PPA original realtime keys: s0..sNNN and p20/b40/b60 bosses.
    # Never assign a monster sprite to an unknown/new server key.
    if key.length() < 2 or key[0] != "s" or not key.substr(1).is_valid_int():
        return -1
    var index := int(key.substr(1))
    if index < 0 or index >= _source_spawns.size():
        return -1
    if not _source_spawns[index].is_finite():
        return -1
    return index

func _visual_level(index: int) -> int:
    if index < 0 or index >= _branch.size():
        return -1
    var branch := _branch[index]
    if branch < 0 or branch >= CATALOG.ROOM_LEVELS.size():
        return -1
    return int(CATALOG.ROOM_LEVELS[branch]) + _tier * 20

func _create_mob(key: String, index: int) -> Node2D:
    var wrapper := Node2D.new()
    wrapper.name = "ConfirmedServerMob_" + key
    wrapper.set_meta("ppa_server_mob_key", key)
    # Existing approved PPA sprite sheets only for an original, index-bound
    # spawn. Boss art is not yet approved: don't resurrect old boss PNGs.
    if _approved_art and index >= 0:
        var level := _visual_level(index)
        if level >= 1 and level <= 60:
            var sprite := ART.new() as Node2D
            sprite.name = "ApprovedPPAMobArt"
            sprite.call("setup", index, level, false)
            wrapper.add_child(sprite)
    var health := ProgressBar.new()
    health.name = "ServerMobHP"
    health.position = Vector2(-32, -43)
    health.size = Vector2(64, 8)
    health.show_percentage = false
    health.mouse_filter = Control.MOUSE_FILTER_IGNORE
    wrapper.add_child(health)
    var hp_text := Label.new()
    hp_text.name = "ServerMobHPText"
    hp_text.position = Vector2(-37, -58)
    hp_text.size = Vector2(74, 16)
    hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    hp_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hp_text.add_theme_font_size_override("font_size", 10)
    wrapper.add_child(hp_text)
    # For a future server key with no known approved art, show only
    # the verified key/HP, never an arbitrary species or fake boss sprite.
    if not _approved_art or index < 0:
        var marker := Label.new()
        marker.name = "ServerUnknownArtMarker"
        marker.text = "● " + key.left(16)
        marker.position = Vector2(-38, -29)
        marker.size = Vector2(76, 20)
        marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
        wrapper.add_child(marker)
    add_child(wrapper)
    return wrapper

func _sync_view() -> void:
    if authority.room.is_empty():
        return
    var near: Array[Dictionary] = []
    for raw_key in authority.mobs.keys():
        var mob: Dictionary = authority.mobs[raw_key]
        if float(mob.get("hp", 0.0)) <= 0.0:
            continue
        var x: Variant = mob.get("x", null)
        var y: Variant = mob.get("y", null)
        if not authority._number(x) or not authority._number(y):
            continue
        var server_pos := Vector2(float(x), float(y))
        if not server_pos.is_finite():
            continue
        var world_pos := server_pos + WALK_MASK_OFFSET
        var distance := _player.distance_squared_to(world_pos)
        if distance <= CULL_RADIUS * CULL_RADIUS:
            near.append({"key":str(raw_key), "point":world_pos,
                "distance":distance, "mob":mob})
    near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return float(a["distance"]) < float(b["distance"])
    )
    var wanted := {}
    for i in range(mini(near.size(), MAX_VISIBLE)):
        var item: Dictionary = near[i]
        var key: String = item["key"]
        var mob: Dictionary = item["mob"]
        var point: Vector2 = item["point"]
        wanted[key] = true
        var node: Node2D = _visible.get(key, null)
        if node == null or not is_instance_valid(node):
            node = _create_mob(key, _source_spawn_index(key))
            _visible[key] = node
        node.position = point
        var bar: ProgressBar = node.get_node("ServerMobHP")
        bar.max_value = maxf(1.0, float(mob["mhp"]))
        bar.value = clampf(float(mob["hp"]), 0.0, bar.max_value)
        var text_label: Label = node.get_node("ServerMobHPText")
        text_label.text = "%d/%d" % [ceili(float(mob["hp"])), ceili(float(mob["mhp"]))]
        var sprite: Node2D = node.get_node_or_null("ApprovedPPAMobArt")
        if sprite != null:
            var face := int(mob.get("dir", 1))
            var motion := Vector2.UP if face == 0 else (
                Vector2.LEFT if face == 2 else (
                    Vector2.RIGHT if face == 3 else Vector2.DOWN))
            sprite.call("set_motion", motion, bool(mob.get("moving", false)))
            sprite.call("set_aggro", bool(mob.get("aggro", false)))
            sprite.call("set_attack", false)
    for key in _visible.keys():
        if not wanted.has(key):
            var node: Node2D = _visible[key]
            if is_instance_valid(node):
                remove_child(node)
                node.queue_free()
            _visible.erase(key)
