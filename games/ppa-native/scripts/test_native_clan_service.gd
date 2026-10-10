extends SceneTree

const BRIDGE = preload("res://scripts/ppa_native_clan_service.gd")
const CONTENT = preload("res://scripts/ppa_clan_menu_content.gd")
const ACTIONS := ["create", "apply", "leaveClan", "acceptApplication", "rejectApplication",
    "kickMember", "transferLeadership", "setPermissions", "setAuthority", "upgradeBonus"]
const OWNER := "990000001"
const OTHER := "990000002"

class OfflineBridge extends "res://scripts/ppa_native_clan_service.gd":
    var refreshes := 0
    func request_state() -> void:
        refreshes += 1

class ClanHost extends Control:
    signal authoritative_state_requested(service: String)
    signal clan_retry_requested
    var _body := VBoxContainer.new()
    var clan_state: Dictionary = {}
    var clan_actions: Array = []
    var clan_busy := false
    var clan_pending := false
    var clan_notice := ""
    var tab := "overview"
    var sent: Array = []
    func _ready() -> void:
        add_child(_body)
    func _label(value: String) -> Label:
        var label := Label.new()
        label.text = value
        return label
    func _button(value: String, enabled: bool = true) -> Button:
        var button := Button.new()
        button.text = value
        button.disabled = not enabled
        return button
    func _section(_heading: String, _subtitle: String) -> void:
        pass
    func _mini_row(_left: String, _right: String) -> void:
        pass
    func show_canonical_clan_storage(_items: Array) -> void:
        pass
    func request_clan_action(action: String, fields: Dictionary) -> void:
        sent.append({"action":action, "fields":fields.duplicate(true)})
    func clear_content() -> void:
        for child in _body.get_children():
            _body.remove_child(child)
            child.queue_free()

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, message: String) -> void:
    if not ok:
        push_error("CLAN_NATIVE_TEST_FAIL: " + message)
        quit(1)
        assert(ok, message)

func payload(owner: String = OWNER) -> Dictionary:
    return {"ok":true, "gameId":"phoenix-pix-arena", "contract":"ppa-clan-v1",
        "ownerId":owner, "actions":ACTIONS, "state":{"connected":true, "self":{"id":owner},
        "clan":null, "members":[]}}

func complete(bridge: Node, response: Dictionary, status: int = 200) -> void:
    bridge._on_completed(HTTPRequest.RESULT_SUCCESS, status, PackedStringArray(), JSON.stringify(response).to_utf8_buffer())

func _run() -> void:
    set_meta("phoenix_account", {"telegramId":OWNER})
    remove_meta("ppa_native_game_session")
    var bridge := OfflineBridge.new()
    root.add_child(bridge)
    await process_frame
    var ready: Array = []
    var failures: Array = []
    bridge.state_ready.connect(func(value: Dictionary): ready.append(value))
    bridge.request_failed.connect(func(value: String): failures.append(value))
    bridge.request_action("create", {"name":"No auth"})
    check(not bridge.loading and bridge._pending.is_empty(), "No-session action attempted")
    var request := {"action":"upgradeBonus", "bonusKey":"hp", "requestId":"a".repeat(32)}
    bridge._owner = OWNER
    bridge._pending_owner = OWNER
    bridge._pending = request.duplicate(true)
    check(bridge._persist_pending(), "Request persistence failed")
    bridge._kind = "state"
    complete(bridge, {"ok":false, "message":"expired"}, 401)
    check(bridge._pending == request, "A failed state read erased an uncertain command")
    complete(bridge, payload())
    check(ready.size() == 1 and bridge._pending == request, "State refresh changed pending command")
    complete(bridge, payload(OTHER))
    check(ready.size() == 1, "Another owner's state accepted")
    bridge._kind = "action"
    complete(bridge, payload())
    check(bridge._pending == request, "Unacknowledged action accepted")
    check(bridge.refreshes == 0, "Unacknowledged action triggered authoritative refresh")
    var recreated := OfflineBridge.new()
    root.add_child(recreated)
    await process_frame
    check(recreated.has_pending() and recreated._pending == request, "App restart lost the same request ID")
    recreated.queue_free()
    var ack := payload()
    ack["requestId"] = request["requestId"]
    ack["commandStatus"] = "done"
    complete(bridge, ack)
    check(bridge._pending.is_empty() and bridge.refreshes == 1, "Confirmed replay must refresh, not apply stale action state")
    check(ready.size() == 1, "Old replay acknowledgement displayed as live state")
    check(not FileAccess.file_exists(bridge._pending_path(OWNER)), "Confirmed request not cleared from disk")
    bridge._pending = request.duplicate(true)
    bridge._persist_pending()
    bridge._kind = "state"
    set_meta("phoenix_account", {"telegramId":OTHER})
    complete(bridge, payload())
    check(ready.size() == 1 and bridge._owner.is_empty(), "Account switch accepted old reply")
    check(FileAccess.file_exists(bridge._pending_path(OWNER)), "Account switch destroyed old owner's recovery request")
    DirAccess.remove_absolute(bridge._pending_path(OWNER))
    set_meta("phoenix_account", {"telegramId":OWNER})

    var host := ClanHost.new()
    root.add_child(host)
    host.clan_actions = ACTIONS.duplicate()
    host.clan_state = payload()["state"]
    CONTENT.render(host)
    var name_input: LineEdit = host._body.get_node("ClanCreateName")
    var create: Button = host._body.get_node("ClanCommand_create")
    check(create.disabled, "Empty clan name allowed")
    name_input.text = "Shared Clan"
    name_input.text_changed.emit(name_input.text)
    check(not create.disabled, "Authorized create is disabled")
    create.pressed.emit()
    check(host.sent == [{"action":"create", "fields":{"name":"Shared Clan"}}], "Create does not send original name command")
    host.clear_content()
    host.clan_state["joinBlockedUntil"] = int((Time.get_unix_time_from_system() + 3600.0) * 1000.0)
    CONTENT.render(host)
    name_input = host._body.get_node("ClanCreateName")
    create = host._body.get_node("ClanCommand_create")
    name_input.text_changed.emit("Blocked Name")
    check(create.disabled, "24h cooldown permits a new clan")
    host.clear_content()
    host.clan_state = {"connected":true, "self":{"id":OWNER, "role":"Глава"},
        "clan":{"leaderId":OWNER}, "members":[{"id":OWNER,"name":"Alpha","role":"Глава"},
        {"id":OTHER,"name":"Beta","role":"Участник"}], "applications":[{"id":"app_beta","name":"Gamma"}],
        "permissions":{}, "authority":{}, "clanProgress":{"freePoints":1,"bonuses":{"hp":0}}}
    host.tab = "members"
    CONTENT.render(host)
    for action in ["kickMember", "transferLeadership", "setPermissions", "setAuthority", "acceptApplication", "rejectApplication"]:
        var button: Button = host._body.get_node("ClanCommand_" + action)
        check(not button.disabled, "Leader's " + action + " unavailable")
        button.pressed.emit()
    check(host.sent[1]["fields"].get("memberId") == OTHER, "Member identity lost")
    check(host.sent[5]["fields"].get("applicationId") == "app_beta", "Application identity lost")
    host.clear_content()
    host.tab = "bonuses"
    host.clan_pending = true
    CONTENT.render(host)
    for button in host._body.get_children():
        if button is Button and str(button.name).begins_with("ClanCommand_"):
            check(button.disabled, "Pending request permits a second bonus spend")
    check(host._body.has_node("ClanRetryPending"), "Same-request recovery button missing")
    host.clear_content()
    host.clan_pending = false
    host.clan_state["self"]["role"] = "Участник"
    host.clan_state["clan"]["leaderId"] = OTHER
    CONTENT.render(host)
    for button in host._body.get_children():
        if button is Button and str(button.name).begins_with("ClanCommand_"):
            check(button.disabled, "Non-leader can allocate bonuses")
    host.queue_free()
    bridge.queue_free()
    await process_frame
    print("PPA_NATIVE_CLAN_CLIENT_OK identity=1 durable_request=1 replay_refresh=1 no_fake_state=1 roles=1 pending_blocks_spend=1 cooldown=1")
    quit()
