extends RefCounted

# Pure validator for the server-owned read-only dungeon observation stream.
# Never infer a room instance from client coordinates, local spawn data,
# currency, a bare scene name or the native player's chosen room.
const ALLOWED_BASES := ["dungeon-1-20", "dungeon-21-40", "dungeon-41-60"]
const MOB_EVENT_TYPES := [
    "mob-authority-snapshot", "mob-authority", "mob-position",
    "mob-hp", "mob-dead", "mob-state"
]

static func allowed_base(base: String) -> bool:
    return base in ALLOWED_BASES

static func room_of(base: String, room: String) -> bool:
    if not allowed_base(base) or not room.begins_with(base + "-i"):
        return false
    var suffix := room.substr((base + "-i").length())
    return suffix.is_valid_int() and not suffix.begins_with("0") and int(suffix) >= 1

static func assignment(packet: Dictionary, requested_base: String) -> String:
    if packet.get("type") != "dungeon-observe-assigned" \
            or packet.get("readOnly") != true \
            or packet.get("actionsEnabled") != false \
            or not allowed_base(requested_base) \
            or str(packet.get("base", "")) != requested_base:
        return ""
    var room := str(packet.get("room", ""))
    return room if room_of(requested_base, room) else ""

static func mob_packet(packet: Dictionary, confirmed_room: String) -> bool:
    if confirmed_room.is_empty() or not packet.get("type", "") in MOB_EVENT_TYPES \
            or str(packet.get("room", "")) != confirmed_room:
        return false
    var ts: Variant = packet.get("ts", null)
    return (ts is int or ts is float) and is_finite(float(ts)) and float(ts) >= 0.0
