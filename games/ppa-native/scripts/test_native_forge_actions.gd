extends SceneTree

# Pure Godot 4.6 integration QA. No credentials or network are ever used.
const NPC = preload("res://scripts/ppa_npc_screen.gd")
const MENU = preload("res://scripts/test_world_menu.gd")
const WORLD = preload("res://scripts/native_world.gd")
const FORGE = preload("res://scripts/ppa_native_forge_service.gd")
const CATALOG = preload("res://scripts/ppa_forge_catalog_generated.gd")
const OWNER := "990000001"
const OTHER := "990000002"

class OfflineForge extends "res://scripts/ppa_native_forge_service.gd":
    var refreshes := 0
    func request_state() -> void:
        refreshes += 1

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, why: String) -> void:
    if not ok:
        push_error("PPA_FORGE_SHARED_ACTION_TEST_FAIL: " + why)
        quit(1)
        assert(ok, why)

func _run() -> void:
    set_meta("phoenix_account", {"telegramId":OWNER})
    remove_meta("ppa_native_game_session")
    # Load real scripts without initializing the dungeon/3D renderer.
    var world := WORLD.new()
    world.free()
    var menu := MENU.new()
    check(menu.has_signal("forge_action_requested") and menu.has_signal("forge_retry_requested"),
        "NPC forge actions not wired into shared city menu")
    menu.free()
    var host := Control.new()
    root.add_child(host)
    host.size = Vector2(1280,720)
    var npc := NPC.new()
    host.add_child(npc)
    npc.size = host.size
    var offered: Dictionary = {}
    for row in CATALOG.CATALOG.get("rows", []):
        if row is Dictionary and row.get("tab") == "equipment" and row.get("slot") == "weapon":
            offered = row
            break
    check(not offered.is_empty(), "Original Telegram epic weapon recipe absent")
    var stocks := {}
    for req in offered.get("materials", []):
        if str(req.get("name", "")) != "Перо Феникса":
            stocks[str(req.get("name", ""))] = 10000
    var forge := {"ok":true,"gameId":"phoenix-pix-arena","contract":"ppa-forge-v1",
        "ownerId":OWNER,"actions":["craft"],"state":{"connected":true,"self":{"id":OWNER},
        "version":8,"catalogSourceSha":str(CATALOG.CATALOG.get("sha256", "")),"wallet":{"ppa":100000},"materials":stocks,"feathers":{"phoenix":100},
        "offers":[{"id":offered["id"],"name":offered["name"],"price":offered["price"],
        "currency":"ppa","materials":offered["materials"]}]}}
    var sent: Array = []
    npc.forge_action_requested.connect(func(fields: Dictionary): sent.append(fields.duplicate(true)))
    npc.open_npc({"service":"forge","name":"Кузнец"})
    npc._select_tab("equipment")
    npc._select_item(str(offered["id"]))
    check(npc._body.find_child("PPARealForgeCraft",true,false) == null,
        "Client enabled crafting without a server-verified receipt")
    npc.apply_native_forge(forge)
    var button := npc._body.find_child("PPARealForgeCraft",true,false) as Button
    check(button != null and not button.disabled,
        "Verified original Telegram forge recipe is not usable")
    button.pressed.emit()
    check(sent == [{"id":str(offered["id"]),"version":8}],
        "Craft request must carry only ID and server save version")
    check(npc.forge_state["wallet"]["ppa"] == 100000 and npc.forge_state["feathers"]["phoenix"] == 100,
        "UI deducted PPA/materials without server confirmation")
    npc.set_forge_loading(false,true)
    check(npc._body.find_child("PPARealForgeCraft",true,false) == null,
        "Unconfirmed craft allows a second request")
    npc.set_forge_loading(false,false)

    var drifted := forge.duplicate(true)
    drifted["state"]["offers"][0]["price"] = int(offered["price"]) - 1
    npc.apply_native_forge(drifted)
    check(npc._body.find_child("PPARealForgeCraft",true,false) == null,
        "Godot crafts client price when server catalog differs")
    npc.apply_native_forge(forge)
    set_meta("phoenix_account",{"telegramId":OTHER})
    npc.apply_native_forge(forge)
    check(npc.forge_state.get("version") == 8,
        "Forged state unexpectedly replaced after owner change")
    # Press event cannot leak another user's funds; world-level transport
    # independently validates signed owner and bearer before any HTTP action.
    npc.close_npc()
    check(npc.forge_state.is_empty() and npc.forge_actions.is_empty(),
        "NPC close preserved old craft authorization")
    set_meta("phoenix_account",{"telegramId":OWNER})

    var bridge := OfflineForge.new()
    root.add_child(bridge)
    await process_frame
    var ready: Array = []
    bridge.state_ready.connect(func(value: Dictionary): ready.append(value))
    bridge._owner = OWNER
    bridge._kind = "state"
    bridge._on_completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify(forge).to_utf8_buffer())
    check(ready.size() == 1,"Signed native forge service response rejected")
    var wrong := forge.duplicate(true)
    wrong["contract"] = "ppa-merchant-v1"
    bridge._on_completed(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),JSON.stringify(wrong).to_utf8_buffer())
    check(ready.size() == 1,"Wrong game-service contract accepted")
    bridge.queue_free()
    host.queue_free()
    await process_frame
    print("PPA_SHARED_FORGE_CLIENT_OK original_items=1 server_quote=1 no_local_spend=1 saved_version=1 owner=1")
    quit()
