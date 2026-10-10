extends RefCounted

# Pixel coordinates of the original Telegram city; never camera/3D positions.
const ROOM := "safe"
const WORLD_SIZE := 2822.0
const MAX_PLAYERS := 40
const CLASSES := ["tank", "barbarian", "paladin", "gnome", "archer", "mage", "assassin", "priest"]

static func valid_pid(value: Variant) -> bool:
    if not (value is String) or value.length() != 34 or not value.begins_with("p:"):
        return false
    for letter in value.substr(2):
        if not letter in "0123456789abcdef":
            return false
    return true

static func numeric(value: Variant) -> bool:
    return (value is int or value is float) and is_finite(float(value))

static func position_packet(point: Vector2, facing: Vector2, animation: String) -> Dictionary:
    if not point.is_finite() or point.x < 0 or point.y < 0 \
        or point.x > WORLD_SIZE or point.y > WORLD_SIZE:
        return {}
    var direction := facing if facing.is_finite() and facing.length_squared() > 0.0001 else Vector2.DOWN
    var compass := (int(round(atan2(direction.x, -direction.y) / TAU * 8.0)) + 8) % 8
    # No health, stat/class overrides, damage, rewards or inventory/save data.
    return {"type":"player-position", "room":ROOM, "x":point.x, "y":point.y,
        "f":compass, "a":"run" if animation == "run" else "idle"}

static func player_row(value: Variant, self_pid: String) -> Dictionary:
    if not (value is Dictionary):
        return {}
    var row: Dictionary = value
    var pid: Variant = row.get("i", "")
    if not valid_pid(pid) or pid == self_pid or row.get("r", ROOM) != ROOM:
        return {}
    if not numeric(row.get("x")) or not numeric(row.get("y")):
        return {}
    var point := Vector2(float(row["x"]), float(row["y"]))
    if point.x < 0 or point.y < 0 or point.x > WORLD_SIZE or point.y > WORLD_SIZE:
        return {}
    var class_key := str(row.get("c", ""))
    if not CLASSES.has(class_key):
        return {}
    return {"i":pid, "x":point.x, "y":point.y, "c":class_key,
        "n":str(row.get("n", "Игрок")).replace("\n", " ").left(24),
        "cn":str(row.get("cn", "")).replace("\n", " ").left(24), "r":ROOM,
        "f":clampi(int(row.get("f", 4)) if numeric(row.get("f")) else 4, -8, 8),
        "a":"run" if row.get("a") == "run" else "idle",
        "q":int(row.get("q", 0)) if numeric(row.get("q")) else 0,
        "hu":float(row.get("hu", 0)) if numeric(row.get("hu")) else 0.0}
