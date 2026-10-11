extends SceneTree

# Signed PPA inventory equip/unequip on the same Godot blacksmith.
# No network, fake game tokens or actual player save writes.
const NPC = preload("res://scripts/ppa_npc_screen.gd")
const OWNER := "990000001"
const OTHER := "990000002"

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, detail: String) -> void:
    if not ok:
        push_error("PPA_NATIVE_INVENTORY_EQUIP_FAIL: " + detail)
        quit(1)
        assert(ok, detail)

func _run() -> void:
    set_meta("phoenix_account", {"telegramId":OWNER})
    remove_meta("ppa_native_game_session")
    var host := Control.new()
    root.add_child(host)
    host.size = Vector2(1280, 720)
    var npc := NPC.new()
    host.add_child(npc)
    npc.size = host.size
    var actions: Array = []
    npc.inventory_action_requested.connect(func(fields: Dictionary): actions.append(fields.duplicate(true)))
    npc.open_npc({"service":"forge", "name":"Кузнец"})
    check(npc._body.find_child("PPARealUnequip_weapon", true, false) == null,
        "Unsigned inventory offered an unequip button")
    var payload := {"ok":true,"gameId":"phoenix-pix-arena","contract":"ppa-inventory-v1",
        "ownerId":OWNER,"actions":["equip","unequip"],
        "state":{"connected":true,"self":{"id":OWNER},"version":14,
        "bag":[{"uid":"new-weapon","name":"Посох мага +5",
            "slot":"weapon","rarity":"epic","enh":5,"classKey":"mage"}],
        "equipped":{"weapon":{"uid":"old-weapon","name":"Посох мага +7",
            "slot":"weapon","rarity":"epic","enh":7}}}}
    npc.apply_native_inventory(payload)
    var remove := npc._body.find_child("PPARealUnequip_weapon", true, false) as Button
    var equip := npc._body.find_child("PPARealEquip_" +
        "new-weapon".to_utf8_buffer().hex_encode(), true, false) as Button
    check(remove != null and not remove.disabled, "Original equipped weapon cannot be removed")
    check(equip != null and not equip.disabled, "Real bag UID cannot be equipped")
    remove.pressed.emit()
    equip.pressed.emit()
    check(actions.size() == 2, "Two signed PPA inventory actions not relayed")
    check(actions[0] == {"action":"unequip","slot":"weapon","version":14},
        "Unequip used a recycled bag index instead of original slot")
    check(actions[1] == {"action":"equip","uid":"new-weapon","version":14},
        "Equip did not preserve authentic saved item UID and version")
    check(npc.inventory_state["equipped"]["weapon"]["enh"] == 7,
        "Native UI rewrote original +7 equipment before the server confirmed")
    npc.set_inventory_loading(false, true)
    check((npc._body.find_child("PPARealUnequip_weapon", true, false) as Button).disabled,
        "Uncertain swap allows a second spend")
    npc.set_inventory_loading(false, false)
    set_meta("phoenix_account",{"telegramId":OTHER})
    remove = npc._body.find_child("PPARealUnequip_weapon", true, false) as Button
    remove.pressed.emit()
    check(actions.size() == 2,"Account switch allowed another owner's item to be unequipped")
    set_meta("phoenix_account",{"telegramId":OWNER})
    npc.close_npc()
    check(npc.inventory_state.is_empty() and npc.inventory_actions.is_empty(),
        "Closing forge retained previous original character gear privileges")
    host.queue_free()
    await process_frame
    print("PPA_NATIVE_EQUIP_UNEQUIP_OK uid=1 version=1 owner=1 pending=1 original_plus7=1 no_local_write=1")
    quit(0)
