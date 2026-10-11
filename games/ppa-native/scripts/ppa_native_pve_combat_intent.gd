extends RefCounted

# The canonical Godot -> PPA PvE intent has NO HP, damage, item, reward,
# client position, userId, class, level, Mana, cooldown or attack stat.
# IMPORTANT: This only creates a read-only preflight packet. A future
# authoritative server combat profile must approve real hit execution.
const OBSERVE = preload("res://scripts/ppa_dungeon_observer_protocol.gd")

static func valid_target(key: String) -> bool:
    if key in ["p20", "b40", "b60"]:
        return true
    if not key.begins_with("s") or key.length() < 2 or key.length() > 5:
        return false
    var number := key.substr(1)
    if (number.length() > 1 and number.begins_with("0")):
        return false
    for i in range(number.length()):
        var c := number.unicode_at(i)
        if c < 48 or c > 57:
            return false
    var n := int(number)
    return n >= 0 and n <= 9999

static func valid_request_id(value: String) -> bool:
    if value.length() < 8 or value.length() > 64:
        return false
    for i in range(value.length()):
        var c := value.unicode_at(i)
        if not ((c >= 48 and c <= 57) or (c >= 65 and c <= 90) or \
                (c >= 97 and c <= 122) or (i > 0 and (c == 45 or c == 95))):
            return false
    return true

static func valid_skill_id(value: String) -> bool:
    if value.length() < 2 or value.length() > 40:
        return false
    for i in range(value.length()):
        var c := value.unicode_at(i)
        if i == 0 and not (c >= 97 and c <= 122):
            return false
        if not ((c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95):
            return false
    return true

static func packet(room: String, mob_key: String, request_id: String,
        action: String = "basic", skill_id: String = "") -> Dictionary:
    var room_valid := false
    for base in OBSERVE.ALLOWED_BASES:
        if OBSERVE.room_of(base, room):
            room_valid = true
            break
    if not room_valid or not valid_target(mob_key) or \
            not valid_request_id(request_id) or action not in ["basic", "skill"]:
        return {}
    if action == "basic" and not skill_id.is_empty():
        return {}
    if action == "skill" and not valid_skill_id(skill_id):
        return {}
    var intent := {
        "type": "dungeon-combat-intent",
        "room": room,
        "key": mob_key,
        "action": action,
        "requestId": request_id
    }
    if action == "skill":
        intent["skillId"] = skill_id
    return intent
