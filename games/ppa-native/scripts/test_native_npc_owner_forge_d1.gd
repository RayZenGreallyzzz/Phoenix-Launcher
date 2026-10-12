extends SceneTree

# Offline owner/session guard and verified D1 forge materials. No network
# request or economy write is performed by this test.
const BRIDGE = preload("res://scripts/ppa_native_npc_service_bridge.gd")
const NPC = preload("res://scripts/ppa_npc_screen.gd")
const OWNER := "990000001"

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, message: String) -> void:
    if not ok:
        push_error("PPA_NPC_IDENTITY_FORGE_FAIL: " + message)
        quit(1)
        assert(ok, message)

func sees_text(node: Node, phrase: String) -> bool:
    for label in node.find_children("*", "Label", true, false):
        if str(label.text).contains(phrase):
            return true
    return false

func fake_response(owner: String) -> Dictionary:
    return {
        "ok":true, "readOnly":true, "gameId":"phoenix-pix-arena",
        "ownerId":owner, "service":"forge", "version":15,
        "data":{"readOnly":true, "actionsEnabled":false,
            "currency":{"gold":100}, "materials":{"Серебряная руда":9}}
    }

func begin_fake(bridge: Node) -> void:
    bridge.requested_service = "forge"
    bridge._requested_owner = OWNER
    bridge._requested_session_sha = "signed-godot-session".sha256_text()
    bridge.loading = true

func deliver(bridge: Node, owner: String) -> void:
    bridge._on_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(),
        JSON.stringify(fake_response(owner)).to_utf8_buffer())

func _run() -> void:
    set_meta("phoenix_account", {"telegramId":OWNER})
    set_meta("ppa_native_game_session", "signed-godot-session")
    var host := Control.new()
    root.add_child(host)
    host.size = Vector2(1100, 740)
    var bridge := BRIDGE.new()
    host.add_child(bridge)
    var npc := NPC.new()
    host.add_child(npc)
    npc.size = host.size
    await process_frame
    var accepted: Array = []
    var refused: Array = []
    bridge.service_ready.connect(func(data: Dictionary): accepted.append(data))
    bridge.service_failed.connect(func(_service: String, code: String): refused.append(code))
    begin_fake(bridge)
    deliver(bridge, "990000002")
    check(accepted.size() == 0 and refused[-1] == "OWNER_MISMATCH",
        "NPC accepted different authenticated Telegram owner")
    begin_fake(bridge)
    set_meta("phoenix_account", {"telegramId":"990000002"})
    deliver(bridge, OWNER)
    check(accepted.is_empty() and refused[-1] == "STALE_SESSION",
        "NPC accepted previous hero response after account switch")
    set_meta("phoenix_account", {"telegramId":OWNER})
    begin_fake(bridge)
    set_meta("ppa_native_game_session", "rotated-session")
    deliver(bridge, OWNER)
    check(accepted.is_empty() and refused[-1] == "STALE_SESSION",
        "NPC accepted expired game bearer session")
    set_meta("ppa_native_game_session", "signed-godot-session")
    begin_fake(bridge)
    deliver(bridge, OWNER)
    check(accepted.size() == 1 and accepted[0].get("ownerId") == OWNER,
        "Current authenticated owner's valid NPC response was rejected")

    var player_save := {
        "gold":813, "ppa":96, "gram":3,
        "stones":{"normal":12,"premium":2,"rune":1},
        "feathers":{"phoenix":4},
        "materials":{"Серебряная руда":9},
        "bag":[{"uid":"original-plus7","name":"Меч +7",
            "kind":"gear","slot":"weapon","enh":7,
            "rarity":"rare"}]
    }
    var before := JSON.stringify(player_save)
    npc.apply_player_save_readonly(player_save)
    npc.open_npc({"service":"forge","name":"Кузнец"})
    await process_frame
    # Forge now prioritizes the active Telegram-style tab. The full signed
    # D1 inventory is still accessible through an explicit resources toggle.
    # Assert both the compact default and the real contents after expanding.
    # Video parity: Telegram forge has 4+2 tabs and a fixed 10-column
    # inventory preview (up to 100 slots), followed by the recipe pane.
    check(npc._tabs.columns == 4 and npc._tabs.get_child_count() == 6,
        "Blacksmith tabs no longer match Telegram 4+2 arrangement")
    check(npc._scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
        and npc._scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER,
        "NPC content must swipe vertically with the side scrollbar hidden")
    check(npc._tab_scroller.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
        "NPC tabs must wrap into rows instead of horizontal side scroll")
    var bag_grid := npc._forge_inventory_host.find_child("PPAForgeInventoryGrid", true, false) as GridContainer
    check(bag_grid != null and bag_grid.columns == 10 and bag_grid.get_child_count() == 100,
        "Blacksmith lost the original 100-slot, ten-column inventory")
    var bag_scroll := npc._forge_inventory_host.find_child("PPAForgeBagScroller", true, false) as ScrollContainer
    check(bag_scroll != null
        and bag_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
        and bag_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER,
        "Original bag must allow vertical swipe without a right-side slider")
    var bag_count := npc._forge_inventory_host.find_child("PPAForgeBagCount", true, false) as Label
    check(bag_count != null and bag_count.autowrap_mode == TextServer.AUTOWRAP_OFF
        and bag_count.custom_minimum_size.x >= 70.0,
        "Forge bag count must remain on one line on Android, not one character per row")
    var has_original_stone := false
    for slot in bag_grid.get_children():
        if slot is Button and str((slot as Button).get_meta("ppa_inspect_name", "")) == "Обычный камень заточки":
            has_original_stone = slot.find_child("PPAForgeVirtualStackCount", true, false) != null
    check(has_original_stone,
        "Original Telegram smith bag must show confirmed stone stacks with quantity badge")
    var bag_first := bag_grid.get_child(0) as Button
    check(bag_first != null and not bag_first.disabled and bag_first.has_meta("ppa_inspect_origin"),
        "Blacksmith must never turn the D1 bag preview into a local spending action")
    # Wallet footer mirrors Telegram: all three confirmed balances stay
    # visible while switching smith tabs, without opening the resource list.
    var wallet := npc._forge_wallet_host
    check(wallet != null and wallet.get_child_count() == 3,
        "Forge lost its fixed Gold / Gram / PPA footer")
    check(sees_text(wallet, "813") and sees_text(wallet, "96") and sees_text(wallet, "3"),
        "Forge footer must display only signed save balances")
    var resources_toggle := npc._body.find_child("PPAForgeResourcesToggle", true, false) as Button
    check(resources_toggle != null, "Forge resources button missing")
    check(not sees_text(npc._body,"813 / 96 / 3"),
        "Forge default view still forces the full D1 inventory before the task")
    resources_toggle.pressed.emit()
    check(sees_text(npc._body,"Серебряная руда") and sees_text(npc._body,"813 / 96 / 3"),
        "Forge ignored real D1 owned materials or balances after opening resources")
    check(sees_text(npc._body,"Перо Феникса") and sees_text(npc._body,"Премиум"),
        "Original D1 stones or feathers absent from expanded forge view")
    check(npc._body.find_child("MerchantCommand_buy", true, false) == null,
        "D1 resource view fabricated merchant buy action")
    check(npc.forge_actions.is_empty() and npc.forge_state.is_empty(),
        "Viewing D1 stock silently enabled forge actions")
    npc._select_tab("accessories")
    npc._set_craft_rarity("rare")
    npc._select_forge_accessory_slot("wings")
    check(npc.selected_id.begins_with("acc:wings:rare"),
        "Original Telegram accessory shortcut does not pick the rare wings recipe")
    check(npc._forge_recipe_target != null,
        "Accessory shortcut must reveal the real canonical recipe")
    npc._select_tab("equipment")
    var forge_cards := npc._body.find_child("NpcProductGrid", true, false) as GridContainer
    check(forge_cards != null and forge_cards.columns == 2 and forge_cards.get_child_count() > 0,
        "Blacksmith recipes must be compact two-column clickable cards")
    check(forge_cards.custom_minimum_size.x >= 250.0,
        "Mobile forge cards collapsed to single-character width during category changes")
    var first_offer := forge_cards.get_child(0) as Control
    check(first_offer != null and first_offer.custom_minimum_size.x >= 116.0,
        "Telegram forge offer tiles need stable minimum widths")
    # Rarity must be visible on the actual 48x48 item square AND title,
    # not just in the product details popup: the old catalog used a
    # brown rectangle regardless of item tier.
    var epic_tint := Color("#D18FFF")
    var epic_style := (first_offer as Button).get_theme_stylebox("normal") as StyleBoxFlat
    var epic_icon := first_offer.find_child("PPAForgeSquareRarityIcon", true, false) as Button
    var epic_title := first_offer.find_child("PPAForgeOfferName", true, false) as Label
    var epic_tag := first_offer.find_child("PPAForgeOfferRarity", true, false) as Label
    check(epic_style != null and epic_style.border_color.is_equal_approx(
        epic_tint.darkened(0.3)),
        "Epic offer still has brown rather than purple card borders")
    check(epic_icon != null and epic_icon.custom_minimum_size == Vector2(48, 48)
        and epic_icon.get_theme_stylebox("disabled") is StyleBoxFlat
        and (epic_icon.get_theme_stylebox("disabled") as StyleBoxFlat).border_color.is_equal_approx(epic_tint),
        "Epic equipment icon must be square with purple rarity border")
    check(epic_title != null and epic_title.get_theme_color("font_color").is_equal_approx(epic_tint)
        and epic_tag != null and epic_tag.text == "ЭПИЧЕСКИЙ",
        "Epic equipment name and explicit rarity label missing")
    npc._select_tab("legendary")
    var legendary_cards := npc._body.find_child("NpcProductGrid", true, false) as GridContainer
    check(legendary_cards != null and legendary_cards.get_child_count() > 0,
        "Legendary PPA forge offers disappeared")
    var legendary_offer := legendary_cards.get_child(0) as Button
    var legendary_icon := legendary_offer.find_child("PPAForgeSquareRarityIcon", true, false) as Button
    var legendary_name := legendary_offer.find_child("PPAForgeOfferName", true, false) as Label
    var legendary_tier := legendary_offer.find_child("PPAForgeOfferRarity", true, false) as Label
    var legendary_tint := Color("#FFD170")
    check(legendary_icon != null
        and legendary_icon.get_theme_stylebox("disabled") is StyleBoxFlat
        and (legendary_icon.get_theme_stylebox("disabled") as StyleBoxFlat).border_color.is_equal_approx(legendary_tint)
        and legendary_name != null and legendary_name.get_theme_color("font_color").is_equal_approx(legendary_tint)
        and legendary_tier != null and legendary_tier.text == "ЛЕГЕНДАРНЫЙ",
        "Legendary equipment must show gold square, name and rarity tag")
    npc._select_tab("equipment")
    npc._select_item("gear:epic:weapon")
    check(npc._forge_recipe_target != null,
        "Selected blacksmith recipe must appear below the product list")
    var materials_grid := npc._body.find_child("PPAForgeOriginalMaterialCards", true, false) as GridContainer
    check(materials_grid != null and materials_grid.columns == 2
        and materials_grid.custom_minimum_size.x >= 230.0,
        "Forge materials must keep proper card widths on Android")
    var material_card := materials_grid.get_child(0) as PanelContainer
    var material_name := material_card.find_child("PPAForgeMaterialName", true, false) as Label
    check(material_card.custom_minimum_size.x >= 125.0 and
        material_name != null and material_name.autowrap_mode == TextServer.AUTOWRAP_OFF,
        "Material names must not break into vertical single-letter columns")
    npc.open_npc({"service":"storage","name":"Склад"})
    check(npc._scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER
        and npc._tab_scroller.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
        "NPC swipe-only layout must apply to other services too")
    npc.open_npc({"service":"forge","name":"Кузнец"})
    npc.apply_authoritative_snapshot(fake_response("990000002"))
    check(not npc.has_verified_state, "NPC view accepted forged different-owner data")
    npc.apply_authoritative_snapshot(fake_response(OWNER))
    check(npc.has_verified_state, "NPC view rejected signed current owner read-only data")
    check(JSON.stringify(player_save) == before,
        "D1 material projection changed player inventory or money")
    set_meta("phoenix_account", {"telegramId":"990000002"})
    npc.clear_player_save_readonly()
    check(npc._player_view_readonly.is_empty(),
        "Owner switch left prior player's D1 material stock in NPC")
    host.queue_free()
    await process_frame
    remove_meta("phoenix_account")
    remove_meta("ppa_native_game_session")
    print("PPA_NPC_IDENTITY_FORGE_OK signed_owner=1 same_service_session_rotation=1 D1_materials=1 no_spend=1")
    quit(0)
