extends RefCounted

# Shared UI capacity contract for PPA Native test views.
# Values are fixed by the original PPA design, not derived from item counts.
# Actual unlocked slots, content and permissions are server authoritative.
const INVENTORY := 100
const PERSONAL := 200
const CLAN := 500
const PREMIUM := 50
const PAGE_SIZE := 20

static func capacity(kind: String) -> int:
    match kind:
        "inventory", "bag": return INVENTORY
        "personal", "warehouse": return PERSONAL
        "clan": return CLAN
        "premium": return PREMIUM
        _: return 0

static func pages(kind: String) -> int:
    var count := capacity(kind)
    if count <= 0:
        return 0
    return ceili(float(count) / float(PAGE_SIZE))

static func first_slot(kind: String, page: int) -> int:
    var total_pages := pages(kind)
    if total_pages == 0:
        return 0
    return clampi(page, 0, total_pages - 1) * PAGE_SIZE

static func visible_slots(kind: String, page: int) -> int:
    return maxi(0, mini(PAGE_SIZE, capacity(kind) - first_slot(kind, page)))
