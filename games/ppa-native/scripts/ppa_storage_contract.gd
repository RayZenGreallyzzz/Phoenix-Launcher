extends RefCounted

# Storage capacity is a game rule; contents and unlocked slots come from PPA.
# These are maxima, not proof that a player has every slot unlocked.
const INVENTORY := 100
const PERSONAL := 200
const CLAN := 500
const PREMIUM := 50

static func capacity(kind: String) -> int:
    match kind:
        "inventory", "bag": return INVENTORY
        "personal", "warehouse": return PERSONAL
        "clan": return CLAN
        "premium": return PREMIUM
        _: return 0
