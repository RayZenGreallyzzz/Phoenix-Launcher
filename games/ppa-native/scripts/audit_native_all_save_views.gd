extends SceneTree

# Offline contract smoke test: one registered save must populate all native
# read-only menu projections, with absolutely no data loss or pseudo currency.
const VIEWS = preload("res://scripts/ppa_shared_save_views.gd")

func _initialize() -> void:
    call_deferred("_verify")

func _fail(message: String) -> void:
    push_error("PPA_SHARED_ALL_MENUS_FAIL: " + message)
    quit(1)

func _verify() -> void:
    var save := {
        "gold": 12345, "ppa": 77, "gram": 2.5,
        "bag": [
            {"uid":"real-1","name":"Броня лучника","kind":"armor","rarity":"common"},
            {"uid":"real-2","name":"Перчатки лучника","kind":"gloves","rarity":"rare"}],
        "equipped":{"ring":{"uid":"real-ring","name":"Кольцо"}},
        "materials":{"Серебряная руда":16, "Синий кристалл":4},
        "stones":{"normal": 5},
        "potions":{"hp":132, "mp":125},
        "storage":{"personal":[{"uid":"stored-1","name":"Кольцо"}],"premium":[],"clan":[]}
    }
    var before := JSON.stringify(save)
    var player := VIEWS.npc_player_view(save)
    var all_items: Array = player.get("inventory", [])
    if all_items.size() != 7:
        _fail("Two original gear items and five resource stacks must share a single NPC picker")
        return
    for i in range(all_items.size()):
        var item: Dictionary = all_items[i]
        if item.get("id","") != "ppa-view-only:" + str(i) or int(item.get("slot",-1)) != i:
            _fail("Native picker display-only locator mismatch")
            return
    if (player.get("equipment", {}) as Dictionary).get("ring", {}).get("uid", "") != "real-ring":
        _fail("NPC must use same D1 equipment as original character panel")
        return
    var storage: Dictionary = player.get("storage", {})
    if (storage.get("personal", []) as Array).size() != 1:
        _fail("Original PPA personal storage not linked")
        return
    if not VIEWS.storage_exists(save,"premium") or VIEWS.storage_exists(save,"unknown"):
        _fail("Missing storage field must not masquerade as empty real inventory")
        return
    var wallet := VIEWS.global_player_view(save)
    if wallet.get("gramDisplay","") != "2.5" or wallet.get("goldDisplay","") != "12345" or wallet.get("ppaDisplay","") != "77":
        _fail("One PPA wallet view must reflect actual save money, not test fake balance")
        return
    if before != JSON.stringify(save):
        _fail("Read-only projections mutated original saved character")
        return
    var no_wallet := VIEWS.global_player_view({})
    if no_wallet.get("gramDisplay","").find("—") < 0:
        _fail("Missing server money must stay unknown, not fabricated as zero")
        return
    print("PPA_SHARED_ALL_MENUS_READONLY_OK canonical_items=7 verified_storage=1 currencies=3 no_save_writes=1")
    quit(0)
