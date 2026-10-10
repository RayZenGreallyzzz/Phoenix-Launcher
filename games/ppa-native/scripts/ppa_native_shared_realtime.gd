extends Node

# Optional, explicitly user-triggered view of the EXISTING PPA RealtimeHub.
# One shared pid and one active socket (Telegram -> Godot switches presence).
# Does NOT send movement, skill damage, purchases or battle rewards.
signal presence_changed(count: int, room_count: int)
signal presence_failed(message: String)
signal presence_connected

const API_BASE := "https://ppa-phoenixpixarena.1988stella1988.workers.dev"
const WS_BASE := "wss://ppa-phoenixpixarena.1988stella1988.workers.dev"
var http: HTTPRequest
var peer: WebSocketPeer
var connecting := false
var enabled := false
var online_count := -1
var room_count := -1
var ping_elapsed := 0.0

func _ready() -> void:
    http = HTTPRequest.new()
    http.timeout = 12.0
    add_child(http)
    http.request_completed.connect(_on_ticket)

func connect_explicitly() -> void:
    # Connecting WILL replace any other realtime socket for this same hero.
    if connecting or peer != null:
        return
    var token: String = str(get_tree().get_meta("ppa_native_game_session", ""))
    if token.is_empty() or token == "<null>":
        presence_failed.emit("Сначала войди через Phoenix Launcher")
        return
    connecting = true
    var err := http.request(API_BASE + "/api/game/realtime/ticket",
        PackedStringArray(["Accept: application/json", "Content-Type: application/json",
            "Authorization: Bearer " + token]), HTTPClient.METHOD_POST, "{}")
    if err != OK:
        connecting = false
        presence_failed.emit("Ошибка подключения к серверу")

func _on_ticket(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    connecting = false
    if result != HTTPRequest.RESULT_SUCCESS or status != 200:
        presence_failed.emit("Общий онлайн пока выключен или недоступен")
        return
    var data: Variant = JSON.parse_string(body.get_string_from_utf8())
    if not (data is Dictionary) or data.get("ok", false) != true:
        presence_failed.emit("Сервер не подтвердил онлайн")
        return
    var user: Dictionary = data.get("user", {}) if data.get("user", {}) is Dictionary else {}
    var pid := str(user.get("id", ""))
    var ticket := str(data.get("ticket", ""))
    if not pid.begins_with("p:") or pid.length() != 34 or ticket.length() < 50:
        presence_failed.emit("Сервер не подтвердил ID персонажа")
        return
    peer = WebSocketPeer.new()
    var url := WS_BASE + "/api/realtime/ws?ticket=" + ticket.uri_encode()
    var err := peer.connect_to_url(url)
    if err != OK:
        peer = null
        presence_failed.emit("Не удалось открыть соединение PPA")
        return
    enabled = true
    set_process(true)

func _process(delta: float) -> void:
    if peer == null:
        set_process(false)
        return
    peer.poll()
    var state := peer.get_ready_state()
    if state == WebSocketPeer.STATE_OPEN:
        if enabled:
            enabled = false
            presence_connected.emit()
            _send_ping()
        ping_elapsed += delta
        if ping_elapsed >= 12.0:
            ping_elapsed = 0.0
            _send_ping()
        var handled := 0
        while peer.get_available_packet_count() > 0 and handled < 16:
            handled += 1
            var raw: String = peer.get_packet().get_string_from_utf8()
            var packet: Variant = JSON.parse_string(raw)
            if packet is Dictionary:
                _handle_packet(packet)
    elif state == WebSocketPeer.STATE_CLOSED:
        peer = null
        online_count = -1
        room_count = -1
        set_process(false)
        presence_failed.emit("Общий онлайн отключён")

func _send_ping() -> void:
    if peer == null or peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
        return
    # Room-safe only; server owns the player identity.
    peer.send_text(JSON.stringify({"type": "ping", "room": "safe"}))

func _handle_packet(packet: Dictionary) -> void:
    if packet.get("type") == "online":
        online_count = clampi(int(packet.get("count", -1)), -1, 100000)
        room_count = clampi(int(packet.get("roomCount", -1)), -1, 100000)
        presence_changed.emit(online_count, room_count)
    elif packet.get("type") == "snapshot":
        room_count = clampi(int(packet.get("roomCount", -1)), -1, 100000)
        presence_changed.emit(online_count, room_count)
    # Critically: native cannot create rewards, apply combat, or alter D1 data.

func _exit_tree() -> void:
    if peer != null:
        peer.close(1000, "Godot scene closed")
        peer = null
