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
    # The screenshot's two bordered panels must appear even while the
    # signed owner state is still loading; the action stays disabled.
    check(npc._body.find_child("PPAForgeOriginalSharpenPanel", true, false) != null and
        npc._body.find_child("PPAForgeOriginalStonePanel", true, false) != null,
        "Telegram sharpening panels must show even without server state")
    var unverified_action := npc._body.find_child("ServerActionLocked", true, false) as Button
    check(unverified_action != null and unverified_action.disabled,
        "Preview sharpening must not spend without server permission")
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
    # The original smith presents item/stone dropdowns, then the +N→+N+1
    # preview, rather than a separate huge grid of native action buttons.
    var rarity_picker := npc._body.find_child("PPAForgeRarityDropdown", true, false) as OptionButton
    check(rarity_picker != null and rarity_picker.item_count == 5,
        "Screenshot parity: first dropdown chooses the five item rarities")
    var chance_table := npc._body.find_child("PPAForgeStoneChanceTable", true, false) as GridContainer
    check(chance_table != null and chance_table.columns == 2 and chance_table.get_child_count() == 14,
        "Screenshot parity: seven rows of signed sharpening chances")
    # Android recording: the first summary label collapsed to one glyph wide.
    var summary := npc._body.find_child("PPAForgeSharpenSummary", true, false) as GridContainer
    check(summary != null and summary.get_child_count() == 8,
        "Forge lost the four visible sharpening summary rows")
    var summary_name := summary.get_child(0) as Label
    var summary_value := summary.get_child(1) as Label
    check(summary_name.autowrap_mode == TextServer.AUTOWRAP_OFF and
        summary_name.custom_minimum_size.x >= 160.0 and
        summary_value.autowrap_mode == TextServer.AUTOWRAP_OFF and
        summary_value.custom_minimum_size.x >= 160.0,
        "Summary text wraps vertically on Android")
    var stone_level := chance_table.get_child(0) as Label
    check(stone_level.autowrap_mode == TextServer.AUTOWRAP_OFF,
        "Stone chance level labels must never wrap vertically")
    var official_stone := npc._body.find_child("PPAForgeOfficialStoneIcon", true, false) as Button
    check(official_stone != null, "Canonical original PPA stone artwork slot missing")
    var gear_picker := npc._body.find_child("PPAForgeGearDropdown", true, false) as OptionButton
    var stone_picker := npc._body.find_child("PPAForgeStoneDropdown", true, false) as OptionButton
    var progression := npc._body.find_child("PPAForgeEnhancementBeforeAfter", true, false) as HBoxContainer
    check(gear_picker != null and gear_picker.item_count == 2,
        "Forge must show only same-rarity signed equipment, not other rarities")
    check(stone_picker != null and stone_picker.item_count == 4,
        "Forge lost the four original stone/rune combinations")
    check(progression != null and progression.get_child_count() == 3,
        "Forge must show previous level, arrow and next level")
    check(not npc._forge_equipment_tools_expanded and
        npc._body.find_child("PPAForgeEquipmentToolsToggle", true, false) != null,
        "Optional equipment tool actions must not block sharpening view")
    npc._set_enhancement_rarity("rare")
    check(npc._enhance_uid == "unique-pet",
        "Choosing rare must select the authenticated rare pet, not epic gear")
    var rare_picker := npc._body.find_child("PPAForgeGearDropdown", true, false) as OptionButton
    check(rare_picker != null and rare_picker.item_count == 1 and not rare_picker.visible,
        "A sole confirmed rarity match should not add an unnecessary dropdown")
    npc._set_enhancement_rarity("legendary")
    var empty_picker := npc._body.find_child("PPAForgeGearDropdown", true, false) as OptionButton
    check(empty_picker != null and empty_picker.disabled and
        npc._body.find_child("PPARealForgeEnhance", true, false) == null,
        "Choosing a rarity with no signed item must never enable sharpening")
    npc._set_enhancement_rarity("epic")
    check(npc._enhance_uid == "unique-epic",
        "Returning to epic must select the genuine owner's epic weapon")
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
