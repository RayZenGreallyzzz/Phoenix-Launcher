extends RefCounted

# Read ONLY the authenticated Telegram PPA /api/game/state body already
# validated by ppa_server_readonly_snapshot.gd. No fake combat health,
# item ownership, new currency or side-effectful stat computation.
# Runtime-only P.hp/P.mp must remain unknown when missing from the D1 save.

static func _number(source: Dictionary, names: Array) -> Variant:
    for key in names:
        var value: Variant = source.get(key, null)
        if value is int or value is float:
            var amount := float(value)
            if is_finite(amount) and amount >= 0.0:
                return amount
    return null

static func _object(source: Dictionary, name: String) -> Dictionary:
    var raw: Variant = source.get(name, null)
    return raw if raw is Dictionary else {}

static func vitals(save: Dictionary) -> Dictionary:
    # The root save is preferred; a signed "vitals" projection may supply
    # current/max values later. Do not treat base equipment/stat HP as live HP.
    var v := _object(save, "vitals")
    var current_hp: Variant = _number(save, ["hp", "currentHp", "hpCurrent"])
    var maximum_hp: Variant = _number(save, ["maxHp", "hpMax", "maxHP"])
    var current_mp: Variant = _number(save, ["mp", "currentMp", "mpCurrent"])
    var maximum_mp: Variant = _number(save, ["maxMp", "mpMax", "maxMP"])
    var current_xp: Variant = _number(save, ["xp"])
    var maximum_xp: Variant = _number(save, ["xpNext", "xpToNext", "nextXp"])
    return {
        "hp": current_hp if current_hp != null else _number(v, ["hp", "currentHp", "hpCurrent"]),
        "maxHp": maximum_hp if maximum_hp != null else _number(v, ["maxHp", "hpMax", "maxHP"]),
        "mp": current_mp if current_mp != null else _number(v, ["mp", "currentMp", "mpCurrent"]),
        "maxMp": maximum_mp if maximum_mp != null else _number(v, ["maxMp", "mpMax", "maxMP"]),
        "xp": current_xp,
        "xpNext": maximum_xp,
    }

static func arena(save: Dictionary) -> Dictionary:
    # Matches the server's src/native-npc-readonly.js projection without
    # enabling the additional /api/game/npc/arena feature-flagged route.
    var pvp := _object(save, "pvp")
    if pvp.is_empty():
        pvp = _object(save, "arena")
    return {
        "rating": _number(pvp, ["rating", "pvpRating"]),
        "wins": _number(pvp, ["wins"]),
        "losses": _number(pvp, ["losses"]),
        "attemptsRemaining": _number(pvp, ["attemptsRemaining"]),
    }
