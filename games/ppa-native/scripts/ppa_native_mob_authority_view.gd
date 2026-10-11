extends RefCounted

# Read-only receiver for the EXISTING Telegram PPA Durable Object mob events.
# No attacks, skill effects, drops, XP, loot, wallet or D1 save writes.
# No connection to production is made here: native dungeon access remains gated.
const MAX_ROWS_PER_PACKET := 72
const MAX_MOBS := 1200

var room := ""
var mobs: Dictionary = {}
var _stage: Dictionary = {}
var _stage_time := -1.0
var _committed_time := -1.0
var _staging := false

func bind_room(next_room: String) -> void:
    # A room transition must not render another dungeon's enemies.
    room = next_room if next_room != "safe" else ""
    mobs.clear()
    _stage.clear()
    _stage_time = -1.0
    _committed_time = -1.0
    _staging = false

func _number(value: Variant) -> bool:
    return (value is float or value is int) and is_finite(float(value))

func _valid_key(value: Variant) -> bool:
    return value is String and not value.is_empty() and value.length() <= 160

func _clock(packet: Dictionary) -> float:
    var raw: Variant = packet.get("ts", null)
    return float(raw) if _number(raw) and float(raw) >= 0.0 else -1.0

func _full_row(raw: Variant, stamp: float) -> Dictionary:
    # Server src/realtime-stable.js: sendMobAuthoritySnapshot() 18-field rows.
    if not (raw is Array) or raw.size() < 18 or not _valid_key(raw[0]):
        return {}
    if not _number(raw[1]) or not _number(raw[2]) or not _number(raw[3]):
        return {}
    var hp := float(raw[1])
    var mhp := float(raw[2])
    if hp < 0.0 or mhp < 1.0 or hp > mhp or float(raw[3]) < 0.0:
        return {}
    var x: Variant = raw[6]
    var y: Variant = raw[7]
    if (x != null and not _number(x)) or (y != null and not _number(y)):
        return {}
    var face: Variant = raw[9]
    if not _number(face) or int(face) < -8 or int(face) > 8:
        return {}
    return {
        "key": raw[0], "hp": hp, "mhp": mhp,
        "respawnAt": float(raw[3]), "killer": str(raw[4]).left(80),
        "party": str(raw[5]).left(80),
        "x": x, "y": y, "aggro": int(raw[8]) == 1,
        "dir": int(face), "moving": int(raw[10]) == 1,
        "target": str(raw[11]).left(80),
        "size": float(raw[12]) if _number(raw[12]) else 30.0,
        "elite": int(raw[13]) == 1, "eliteWindowKey": str(raw[14]).left(96),
        "eliteExpiresAt": float(raw[15]) if _number(raw[15]) else 0.0,
        "eliteMode": str(raw[16]).left(48),
        "eliteDefBonus": float(raw[17]) if _number(raw[17]) else 0.0,
        "_at": stamp
    }

func apply_packet(packet: Dictionary) -> bool:
    if room.is_empty() or str(packet.get("room", "")) != room:
        return false
    var at := _clock(packet)
    if at < 0.0:
        return false
    var kind := str(packet.get("type", ""))
    if kind == "mob-authority-snapshot":
        var rows: Variant = packet.get("rows", null)
        if not (rows is Array) or rows.size() > MAX_ROWS_PER_PACKET:
            return false
        if packet.get("reset", false) == true:
            if at < _committed_time:
                return false
            _stage.clear()
            _stage_time = at
            _staging = true
        if not _staging or at != _stage_time:
            return false
        for raw in rows:
            var item := _full_row(raw, at)
            if item.is_empty():
                # Reject an entire incomplete stream; old valid state stays.
                _stage.clear()
                _staging = false
                return false
            var key := str(item["key"])
            if not _stage.has(key) and _stage.size() >= MAX_MOBS:
                _stage.clear()
                _staging = false
                return false
            _stage[key] = item
        if packet.get("done", false) == true:
            mobs = _stage.duplicate(true)
            _committed_time = at
            _stage.clear()
            _staging = false
        return true
    if at < _committed_time:
        return false
    if kind == "mob-position":
        var updates: Variant = packet.get("rows", null)
        if not (updates is Array) or updates.size() > MAX_MOBS:
            return false
        var accepted := false
        for raw in updates:
            if not (raw is Array) or raw.size() < 7 or not _valid_key(raw[0]):
                continue
            var key := str(raw[0])
            if not mobs.has(key) or not _number(raw[1]) or not _number(raw[2]):
                continue
            if not _number(raw[4]) or int(raw[4]) < -8 or int(raw[4]) > 8:
                continue
            var mob: Dictionary = mobs[key]
            if at < float(mob.get("_at", 0.0)):
                continue
            mob["x"] = float(raw[1])
            mob["y"] = float(raw[2])
            mob["aggro"] = int(raw[3]) == 1
            mob["dir"] = int(raw[4]) # Up=0 must remain 0.
            mob["moving"] = int(raw[5]) == 1
            mob["target"] = str(raw[6]).left(80)
            mob["_at"] = at
            accepted = true
        return accepted
    if kind == "mob-hp" or kind == "mob-dead":
        var key := str(packet.get("key", ""))
        if not mobs.has(key):
            return false # Never spawn an enemy from an isolated hit packet.
        var mob: Dictionary = mobs[key]
        if at < float(mob.get("_at", 0.0)):
            return false
        if kind == "mob-hp":
            var hp: Variant = packet.get("hp", null)
            var mhp: Variant = packet.get("mhp", null)
            if not _number(hp) or not _number(mhp) or float(mhp) < 1.0 \
                    or float(hp) < 0.0 or float(hp) > float(mhp):
                return false
            mob["hp"] = float(hp)
            mob["mhp"] = float(mhp)
        else:
            mob["hp"] = 0.0
        var respawn: Variant = packet.get("respawnAt", null)
        if _number(respawn) and float(respawn) >= 0.0:
            mob["respawnAt"] = float(respawn)
        mob["_at"] = at
        return true
    return false
