extends SceneTree

# Pure offline Godot 4.6 test of verified ORIGINAL PPA sharpening UI.
# Never uses a game token, Cloudflare writes or a local fantasy inventory.
const NPC = preload("res://scripts/ppa_npc_screen.gd")
const OWNER := "990000001"
const OTHER := "990000002"

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, description: String) -> void:
    if not ok:
        push_error("PPA_NATIVE_SHARPEN_FAIL: " + description)
        quit(1)
        assert(ok, description)

func _run() -> void:
    set_meta("phoenix_account", {"telegramId":OWNER})
    remove_meta("ppa_native_game_session")
    var host := Control.new()
    root.add_child(host)
    host.size = Vector2(1280,720)
    var npc := NPC.new()
    host.add_child(npc)
    npc.size = host.size
    var sent: Array = []
    npc.forge_action_requested.connect(func(fields: Dictionary): sent.append(fields.duplicate(true)))
    npc.open_npc({"service":"forge", "name":"Кузнец"})
    check(npc._body.find_child("PPARealForgeEnhance", true, false) == null,
        "Unknown server state must never enable sharpening")
    var state := {"ok":true, "gameId":"phoenix-pix-arena", "contract":"ppa-forge-v1",
        "ownerId":OWNER, "actions":["enhance"],
        "state":{"connected":true, "self":{"id":OWNER}, "version":12,
        "offers":[], "wallet":{"ppa":60000},
        "stones":{"normal":3,"premium":2,"rune":1},
        "enhanceRules":{"normal":[43,35,27,19,12,7,3],
            "rune":[55,47,40,33,27,23,19], "normalMax":5, "premiumMax":7},
        "enhanceItems":[
            {"uid":"unique-epic","name":"Посох мага","slot":"weapon","rarity":"epic","enh":5,"special":false},
            {"uid":"unique-pet","name":"Лунный лис","slot":"pet","rarity":"rare","enh":4,"special":false},
            {"uid":"unique-special","name":"Звёздный Хранитель","slot":"pet","rarity":"epic","enh":5,"special":true}]}}
    npc.apply_native_forge(state)
    check(npc._body.find_child("PPARealForgeEnhance", true, false) == null,
        "Normal stone should not allow +6")
    npc._set_enhancement_mode("premium_rune")
    var button := npc._body.find_child("PPARealForgeEnhance", true, false) as Button
    check(button != null and not button.disabled,"Premium + rune must allow +6 with owned stones")
    button.pressed.emit()
    check(sent == [{"action":"enhance","uid":"unique-epic","stone":"premium_rune","version":12}],
        "Only server verified item UID, stone and version may be sent")
    check(npc.forge_state["stones"]["premium"] == 2 and npc.forge_state["stones"]["rune"] == 1,
        "Client may not deduct stones before server acknowledgement")
    npc.set_forge_loading(false,true)
    check(npc._body.find_child("PPARealForgeEnhance", true, false) == null,
        "Pending unconfirmed attempt must block duplicate spending")
    npc.set_forge_loading(false,false)
    npc._choose_enhancement_item("unique-special")
    check(npc._body.find_child("PPARealForgeEnhance", true, false) == null,
        "Special guardian must remain blocked pending original class migration")
    npc._choose_enhancement_item("unique-pet")
    npc._set_enhancement_mode("premium")
    button = npc._body.find_child("PPARealForgeEnhance", true, false) as Button
    check(button != null and not button.disabled, "Normal pet must be eligible for safe premium sharpening")
    set_meta("phoenix_account", {"telegramId":OTHER})
    button.pressed.emit()
    check(sent.size() == 1, "Account switch re-used previous player's forge authority")
    set_meta("phoenix_account", {"telegramId":OWNER})
    npc.close_npc()
    check(npc.forge_state.is_empty() and npc.forge_actions.is_empty(),
        "Closed menu retained original PPA item permissions")
    host.queue_free()
    await process_frame
    print("PPA_NATIVE_SHARPEN_OK uid=1 modes=4 +6=1 safety=1 pet=1 owner=1 no_local_spend=1")
    quit(0)
