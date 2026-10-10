extends Node

# Signed Phoenix session -> the SAME PPA pid, safe room and global RealtimeHub.
# City movement only. Never send legacy move (it also carries HP/combat stats).
signal presence_changed(count: int, room_count: int)
signal presence_failed(message: String)
signal presence_connected
signal players_updated(rows: Array)
signal player_left(pid: String)
signal players_cleared

const PROTOCOL = preload("res://scripts/ppa_shared_city_protocol.gd")
const API_BASE := "https://ppa-phoenixpixarena.1988stella1988.workers.dev"
const WS_BASE := "wss://ppa-phoenixpixarena.1988stella1988.workers.dev"
var http: HTTPRequest
var peer: WebSocketPeer
var connecting := false
var online_count := -1
var room_count := -1
var self_pid := ""
var _ticket_pid := ""
var _hello_received := false
var _position_ready := false
var _local_position: Dictionary = {}
var _last_sent: Dictionary = {}
var _players: Dictionary = {}
var _wanted := false
var _retry_delay := 1.2
var _retry_elapsed := -1.0
var _send_elapsed := 0.0
var _ping_elapsed := 0.0
var _handshake_elapsed := 0.0

func _ready() -> void:
    http = HTTPRequest.new()
    http.timeout = 12.0
    add_child(http)
    http.request_completed.connect(_on_ticket)

func connect_explicitly() -> void:
    # One active socket per hero; manual opt-in switches presence from Telegram.
    if connecting or peer != null:
        return
    _wanted = true
    _retry_elapsed = -1.0
    var token := str(get_tree().get_meta("ppa_native_game_session", ""))
    if token.is_empty() or token == "<null>":
        _wanted = false
        presence_failed.emit("Сначала войди через Phoenix Launcher")
        return
    connecting = true
    var err := http.request(API_BASE + "/api/game/realtime/ticket",
        PackedStringArray(["Accept: application/json", "Content-Type: application/json",
            "Authorization: Bearer " + token]), HTTPClient.METHOD_POST, "{}")
    if err != OK:
        connecting = false
        _schedule_retry("Ошибка подключения к серверу")

func set_local_position(point: Vector2, facing: Vector2, animation: String) -> void:
    _local_position = PROTOCOL.position_packet(point, facing, animation)

func refresh_clan_identity_if_connected() -> void:
    # Clan identity is included in the server-signed ticket. Refresh an
    # already opted-in city connection; never restart a displaced hero or
    # opt a menu-only/offline client into the shared world automatically.
    if not _wanted or connecting or peer == null or not _position_ready:
        return
    peer.poll()
    if peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
        return
    disconnect_city()
    connect_explicitly()

func _on_ticket(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    connecting = false
    if not _wanted:
        return
    if result != HTTPRequest.RESULT_SUCCESS or status >= 500:
        _schedule_retry("Соединение PPA потеряно · повторяем")
        return
    if status != 200:
        _wanted = false
        presence_failed.emit("Общий город пока выключен или сессия истекла")
        return
    var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
    if not (parsed is Dictionary) or parsed.get("ok", false) != true:
        _wanted = false
        presence_failed.emit("Сервер не подтвердил онлайн")
        return
    var user: Variant = parsed.get("user", {})
    var pid: Variant = user.get("id", "") if user is Dictionary else ""
    var ticket := str(parsed.get("ticket", ""))
    if not PROTOCOL.valid_pid(pid) or ticket.length() < 50:
        _wanted = false
        presence_failed.emit("Сервер не подтвердил ID персонажа")
        return
    _ticket_pid = str(pid)
    _handshake_elapsed = 0.0
    peer = WebSocketPeer.new()
    var err := peer.connect_to_url(WS_BASE + "/api/realtime/ws?ticket=" + ticket.uri_encode())
    if err != OK:
        peer = null
        _schedule_retry("Не удалось открыть соединение PPA")

func _process(delta: float) -> void:
    if _retry_elapsed >= 0:
        _retry_elapsed -= delta
        if _retry_elapsed <= 0:
            _retry_elapsed = -1.0
            connect_explicitly()
    if peer == null:
        return
    peer.poll()
    var state := peer.get_ready_state()
    if state == WebSocketPeer.STATE_CLOSED:
        var code := peer.get_close_code()
        _clear_connection()
        if code == 4001 or code == 1008:
            _wanted = false # Never fight Telegram's reconnect for the same pid.
            presence_failed.emit("Этот персонаж подключён с другого клиента" if code == 4001 else "Сервер не подтвердил общий город")
        else:
            _schedule_retry("Общий город отключён · переподключаемся")
        return
    _handshake_elapsed += delta
    if not _position_ready and _handshake_elapsed > 12.0:
        disconnect_city()
        presence_failed.emit("Нужен серверный пакет перемещения общего города")
        return
    if state != WebSocketPeer.STATE_OPEN:
        return
    var handled := 0
    while peer != null and peer.get_available_packet_count() > 0 and handled < 32:
        handled += 1
        var bytes := peer.get_packet()
        if bytes.size() > 65536:
            continue
        var packet: Variant = JSON.parse_string(bytes.get_string_from_utf8())
        if packet is Dictionary:
            _handle_packet(packet)
    if not _hello_received:
        return
    _send_elapsed += delta
    _ping_elapsed += delta
    if _send_elapsed >= 0.12 and not _local_position.is_empty():
        if _local_position != _last_sent or _send_elapsed >= 1.2:
            if _send(_local_position):
                _last_sent = _local_position.duplicate()
                _send_elapsed = 0.0
    if _ping_elapsed >= 12.0:
        _ping_elapsed = 0.0
        _send({"type":"ping", "clientTs":Time.get_unix_time_from_system() * 1000.0})

func _send(packet: Dictionary) -> bool:
    return peer != null and peer.get_ready_state() == WebSocketPeer.STATE_OPEN \
        and peer.send_text(JSON.stringify(packet)) == OK

func _handle_packet(packet: Dictionary) -> void:
    var kind := str(packet.get("type", ""))
    if kind == "hello":
        if packet.get("pid") != _ticket_pid or not PROTOCOL.valid_pid(_ticket_pid) \
            or packet.get("serverRoom", packet.get("room", "")) != PROTOCOL.ROOM:
            disconnect_city()
            presence_failed.emit("ID персонажа или комната не совпали")
            return
        self_pid = _ticket_pid
        _hello_received = true
        _last_sent.clear()
        _send_elapsed = 1.2
        _send({"type":"room", "room":PROTOCOL.ROOM})
        return
    if kind == "online":
        online_count = clampi(int(packet.get("count", -1)), -1, 100000)
        room_count = clampi(int(packet.get("roomCount", -1)), -1, 100000)
        presence_changed.emit(online_count, room_count)
        return
    if not _hello_received or packet.get("room", "") != PROTOCOL.ROOM:
        return
    if kind == "snapshot":
        room_count = clampi(int(packet.get("roomCount", -1)), -1, 100000)
        presence_changed.emit(online_count, room_count)
        var rows: Variant = packet.get("players", [])
        if rows is Array:
            for row in rows.slice(0, PROTOCOL.MAX_PLAYERS):
                _accept_player(row)
    elif kind == "move":
        _accept_player(packet.get("player", {}))
    elif kind == "leave":
        var pid := str(packet.get("id", ""))
        if _players.erase(pid):
            player_left.emit(pid)
    elif kind == "player-position-ack":
        if not PROTOCOL.numeric(packet.get("x")) or not PROTOCOL.numeric(packet.get("y")):
            return
        if not _position_ready:
            _position_ready = true
            _retry_delay = 1.2
            presence_connected.emit()
    elif kind == "player-position-rejected":
        disconnect_city()
        presence_failed.emit("Перемещение не принято: " + str(packet.get("code", "")).left(40))

func _accept_player(value: Variant) -> void:
    var row := PROTOCOL.player_row(value, self_pid)
    if row.is_empty():
        return
    var pid := str(row["i"])
    var previous: Dictionary = _players.get(pid, {})
    if not previous.is_empty() and int(row["q"]) < int(previous["q"]):
        return
    if not _players.has(pid) and _players.size() >= PROTOCOL.MAX_PLAYERS:
        return
    _players[pid] = row
    players_updated.emit([row])

func _schedule_retry(message: String) -> void:
    presence_failed.emit(message)
    if _wanted:
        _retry_elapsed = _retry_delay
        _retry_delay = minf(8.0, _retry_delay * 1.7)

func _clear_connection() -> void:
    peer = null
    self_pid = ""
    _hello_received = false
    _position_ready = false
    _players.clear()
    _last_sent.clear()
    online_count = -1
    room_count = -1
    players_cleared.emit()

func disconnect_city() -> void:
    _wanted = false
    _retry_elapsed = -1.0
    if http != null and connecting:
        http.cancel_request()
        connecting = false
    if peer != null:
        peer.close(1000, "Godot scene closed")
    _clear_connection()

func _exit_tree() -> void:
    disconnect_city()
