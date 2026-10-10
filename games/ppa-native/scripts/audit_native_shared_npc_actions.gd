extends SceneTree

# Actual native NPC controls and transport, offline only. Synthetic account
# metadata never contains a game token; no request reaches production.
const NPC = preload("res://scripts/ppa_npc_screen.gd")
const WORLD = preload("res://scripts/native_world.gd")
const MENU = preload("res://scripts/test_world_menu.gd")
const OWNER := "990000001"
const OTHER := "990000002"

class OfflineMerchant extends "res://scripts/ppa_native_merchant_service.gd":
    var refreshes := 0
    func request_state() -> void:
        refreshes += 1

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, message: String) -> void:
    if not ok:
        push_error("PPA_SHARED_NPC_TEST_FAIL: " + message)
        quit(1)
        assert(ok, message)

func _run() -> void:
    set_meta("phoenix_account", {"telegramId":OWNER})
    remove_meta("ppa_native_game_session")
    # Compile the complete menu/world wiring without launching an offline
    # scene, duplicating monsters or loading a second 3D renderer.
    print("PPA_NPC_AUDIT_PHASE creating_world")
    var world := WORLD.new()
    world.free()
    var menu := MENU.new()
    check(menu.has_signal("clan_action_requested") and menu.has_signal("merchant_action_requested"), "Menu action forwarding missing")
    menu.free()
    var host := Control.new()
    root.add_child(host)
    host.size = Vector2(1280, 720)
    print("PPA_NPC_AUDIT_PHASE creating_npc")
    var npc := NPC.new()
    host.add_child(npc)
    npc.size = host.size
    var sent: Array = []
    npc.merchant_action_requested.connect(func(fields: Dictionary): sent.append(fields.duplicate(true)))
    print("PPA_NPC_AUDIT_PHASE opening_merchant")
    npc.open_npc({"service":"merchant", "name":"Торговец"})
    npc._select_item("hp_small")
    check(npc._body.find_child("MerchantCommand_buy", true, false) == null, "Reference catalog permits a live purchase")
    var merchant := {"ok":true, "gameId":"phoenix-pix-arena", "contract":"ppa-merchant-v1", "ownerId":OWNER,
        "actions":["buy"], "state":{"connected":true,"self":{"id":OWNER},"version":8,
        "wallet":{"gold":1000,"ppa":40},"offers":[{"id":"hp_small","name":"Малое зелье HP",
        "price":102,"currency":"gold","owned":6}]}}
    print("PPA_NPC_AUDIT_PHASE applying_merchant")
    npc.apply_native_merchant(merchant)
    npc._change_quantity(1)
    var products: Array = npc._merchant_products()
    check(products.size() == 1 and products[0].get("price") == 102, "UI overrides live price with APK catalog")
    var button: Button = npc._body.find_child("MerchantCommand_buy", true, false)
    check(button != null and not button.disabled, "Verified merchant buy is unavailable")
    button.pressed.emit()
    check(sent == [{"id":"hp_small","qty":2,"version":8}], "Purchase must send ID/quantity/version only")
    check(npc.merchant_state["wallet"]["gold"] == 1000 and npc.merchant_state["offers"][0]["owned"] == 6,
        "UI fabricated a wallet or potion change before acknowledgement")
    npc.set_merchant_loading(false, true)
    button = npc._body.find_child("MerchantCommand_buy", true, false)
    check(button.disabled and npc._body.has_node("MerchantRetryPending"), "Uncertain purchase permits a second spend")
    npc.set_merchant_loading(false, false)
    set_meta("phoenix_account", {"telegramId":OTHER})
    button = npc._body.find_child("MerchantCommand_buy", true, false)
    button.pressed.emit()
    check(sent.size() == 1, "Stale UI acted on a newly signed-in character")
    set_meta("phoenix_account", {"telegramId":OWNER})
    npc.set_merchant_loading(true, false)
    check((npc._body.find_child("MerchantCommand_buy", true, false) as Button).disabled, "Loading does not block purchase")
    npc.close_npc()
    check(npc.merchant_state.is_empty() and npc.merchant_actions.is_empty(), "Closed merchant retained privileges")

    var bridge := OfflineMerchant.new()
    root.add_child(bridge)
    await process_frame
    var ready: Array = []
    bridge.state_ready.connect(func(value: Dictionary): ready.append(value))
    bridge._owner = OWNER
    bridge._kind = "state"
    bridge._on_completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify(merchant).to_utf8_buffer())
    check(ready.size() == 1, "Merchant transport rejects verified contract")
    var wrong := merchant.duplicate(true)
    wrong["contract"] = "ppa-clan-v1"
    bridge._on_completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify(wrong).to_utf8_buffer())
    check(ready.size() == 1, "Merchant accepts clan response")

    var clan := {"ok":true,"gameId":"phoenix-pix-arena","contract":"ppa-clan-v1","ownerId":OWNER,"actions":["create","apply","upgradeBonus"],
        "state":{"connected":true,"self":{"id":OWNER,"role":"Глава"},"clan":{"name":"Shared","leaderId":OWNER},
        "members":[{"id":OWNER,"name":"Alpha","role":"Глава"}],"clanDirectory":[],"clanRanking":[],
        "applications":[],"permissions":{},"authority":{},"storageUnlocked":true,
        "storage":{"used":1,"max":500,"items":[{"uid":"server-item","name":"Общая вещь"}]},
        "clanProgress":{"level":2,"coins":500,"freePoints":1,"bonuses":{"hp":0}},
        "events":[],"history":[],"wars":[],"bosses":[]}}
    print("PPA_NPC_AUDIT_PHASE opening_clan")
    npc.open_npc({"service":"clan","name":"Магистр кланов"})
    print("PPA_NPC_AUDIT_PHASE applying_clan")
    npc.apply_native_clan(clan)
    check(npc.clan_state["clan"]["name"] == "Shared", "Canonical clan not displayed")
    npc._select_tab("storage")
    var grid = npc._body.find_child("NpcStorageGrid_clan", true, false)
    check(grid != null and grid.capacity == 500 and grid._verified_items[0]["uid"] == "server-item",
        "Clan storage uses a local save copy instead of the common clan table")
    npc._select_tab("bonuses")
    check((npc._body.find_child("ClanCommand_upgradeBonus", true, false) as Button).disabled == false,
        "Leader's canonical bonus upgrade unavailable")
    npc.clear_player_save_readonly()
    check(npc.clan_state.is_empty() and npc.merchant_state.is_empty(), "Identity loss retained action data")
    bridge.queue_free()
    host.queue_free()
    await process_frame
    print("PPA_SHARED_NPC_ACTIONS_OK native_wiring=1 live_prices=1 typed_buy=1 no_local_spend=1 account_switch=1 pending_guard=1 canonical_clan_storage=1")
    quit()
