extends Node

# Account-bound transport for typed PPA commands. No local save mutations.
signal state_ready(payload: Dictionary)
signal request_failed(message: String)
signal loading_changed(busy: bool)
signal command_finished(message: String)

const API_BASE := "https://ppa-phoenixpixarena.1988stella1988.workers.dev"
var service_key := ""
var contract_key := ""
var supported_actions: Array = []
var http: HTTPRequest
var loading := false
var _kind := ""
var _owner := ""
var _pending_owner := ""
var _pending: Dictionary = {}
var _recovery_error := false

func _ready() -> void:
    http = HTTPRequest.new()
    http.timeout = 15.0
    add_child(http)
    http.request_completed.connect(_on_completed)

func request_state() -> void:
    _begin("state", {})

func request_action(action: String, fields: Dictionary) -> void:
    if loading:
        return
    var owner := _account_owner()
    var token := str(get_tree().get_meta("ppa_native_game_session", ""))
    if owner.is_empty() or token.is_empty() or token == "<null>":
        request_failed.emit("Сначала войди в свой аккаунт PPA")
        return
    _restore_pending(owner)
    if _recovery_error or not _pending.is_empty():
        request_failed.emit("Сначала проверь неподтверждённое действие")
        return
    if not supported_actions.has(action):
        request_failed.emit("Действие сервиса не поддерживается")
        return
    var command := fields.duplicate(true)
    # Fields supplied by UI cannot change actor or request identity.
    for key in ["state", "ownerId", "telegramId", "characterId", "initData"]:
        command.erase(key)
    command["action"] = action
    command["requestId"] = Crypto.new().generate_random_bytes(16).hex_encode()
    _pending = command
    if not _persist_pending():
        _pending.clear()
        request_failed.emit("Не удалось сохранить запрос · действие не отправлено")
        return
    _begin("action", command)

func retry_pending() -> void:
    _restore_pending(_account_owner())
    if _recovery_error:
        request_failed.emit("Запись неподтверждённого действия повреждена · нужна проверка на сервере")
        return
    if not loading and not _pending.is_empty():
        _begin("action", _pending)

func _account_owner() -> String:
    var account: Variant = get_tree().get_meta("phoenix_account", {})
    var owner := str(account.get("telegramId", "")) if account is Dictionary else ""
    return owner if owner.is_valid_int() and owner.length() <= 20 and int(owner) > 0 else ""

func _pending_path(owner: String) -> String:
    return "user://ppa_" + service_key.replace("/", "_") + "_pending_" + owner + ".json"

func _restore_pending(owner: String) -> void:
    if owner.is_empty() or owner == _pending_owner:
        return
    _pending_owner = owner
    _pending.clear()
    _recovery_error = false
    if not FileAccess.file_exists(_pending_path(owner)):
        return
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_pending_path(owner)))
    if data is Dictionary and supported_actions.has(data.get("action")) \
        and _valid_request_id(str(data.get("requestId", ""))):
        _pending = data.duplicate(true)
    else:
        # A corrupt recovery record cannot safely be replaced with a new ID.
        _recovery_error = true

func _valid_request_id(value: String) -> bool:
    if value.length() != 32:
        return false
    for character in value:
        if not "0123456789abcdef".contains(character):
            return false
    return true

func _persist_pending() -> bool:
    var temporary := _pending_path(_pending_owner) + ".tmp"
    var file := FileAccess.open(temporary, FileAccess.WRITE)
    if file == null:
        return false
    # Only command fields and a random request ID; never credentials or save.
    file.store_string(JSON.stringify(_pending))
    file.flush()
    var result := file.get_error() == OK
    file.close()
    return result and DirAccess.rename_absolute(temporary, _pending_path(_pending_owner)) == OK

func _clear_pending() -> void:
    _pending.clear()
    _recovery_error = false
    if not _pending_owner.is_empty():
        DirAccess.remove_absolute(_pending_path(_pending_owner))

func _begin(kind: String, body: Dictionary) -> void:
    if loading or http == null:
        return
    var owner := _account_owner()
    var token := str(get_tree().get_meta("ppa_native_game_session", ""))
    if owner.is_empty() or owner == "<null>" or token.is_empty() or token == "<null>":
        request_failed.emit("Сначала войди в свой аккаунт PPA")
        return
    _restore_pending(owner)
    if kind == "action" and body != _pending:
        request_failed.emit("Аккаунт изменился · обнови данные сервиса")
        return
    _owner = owner
    _kind = kind
    loading = true
    loading_changed.emit(true)
    var headers := PackedStringArray(["Authorization: Bearer " + token,
        "Accept: application/json", "Content-Type: application/json", "Cache-Control: no-store"])
    var method := HTTPClient.METHOD_GET if kind == "state" else HTTPClient.METHOD_POST
    var result := http.request(API_BASE + "/api/game/" + service_key + "/" + kind, headers, method,
        "" if kind == "state" else JSON.stringify(body))
    if result != OK:
        loading = false
        loading_changed.emit(false)
        request_failed.emit("Не удалось связаться с сервером PPA")

func _on_completed(result: int, status: int, _headers: PackedStringArray, bytes: PackedByteArray) -> void:
    loading = false
    loading_changed.emit(false)
    if _owner != _account_owner():
        # Retain the old owner's disk request for safe retry on their next login.
        _pending.clear()
        _pending_owner = ""
        _owner = ""
        request_failed.emit("Аккаунт изменился · ответ отклонён")
        return
    if result != HTTPRequest.RESULT_SUCCESS:
        request_failed.emit("Не удалось подтвердить действие · обнови данные или повтори тот же запрос")
        return
    var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
    if not (parsed is Dictionary):
        request_failed.emit("Некорректный ответ сервера PPA")
        return
    var response: Dictionary = parsed
    var acknowledged: bool = _kind == "action" and response.get("gameId") == "phoenix-pix-arena" \
        and response.get("contract") == contract_key and str(response.get("ownerId", "")) == _owner \
        and response.get("commandStatus") == "done" and response.get("requestId") == _pending.get("requestId")
    if acknowledged:
        _clear_pending()
    if status != 200 or response.get("ok", false) != true:
        # A failed state read, expired token or ambiguous command response
        # cannot erase a previously sent command or mint a fresh request ID.
        # 404 is the intentional default-off server feature gate, not a
        # missing inventory item. Never offer a local fake purchase instead.
        var public_message := str(response.get("message", "Сервис PPA пока недоступен"))
        if status == 404 and str(response.get("code", "")) == "NOT_FOUND":
            public_message = "Этот раздел NPC ещё не включён на общем сервере PPA"
        request_failed.emit(public_message.left(240))
        if acknowledged:
            request_state()
        return
    if _kind == "action":
        # Canonical PPA command receipts are deliberately SMALL: the server
        # returns gameId, contract, ownerId, requestId, commandStatus and
        # receipt/version, but never a mutable state/actions snapshot.
        # Require the signed acknowledgement, then request fresh state.
        if not acknowledged:
            request_failed.emit("Сервер не подтвердил ID действия · повтори тот же запрос")
            return
        command_finished.emit(str(response.get("message", "Действие подтверждено")))
        # Replayed receipts may be older than another client's actions.
        # Never use their balances or inventory as the current NPC state.
        request_state()
        return
    if response.get("gameId") != "phoenix-pix-arena" or response.get("contract") != contract_key \
        or str(response.get("ownerId", "")) != _owner or not (response.get("state") is Dictionary) \
        or not (response.get("actions") is Array):
        request_failed.emit("Ответ сервера не принадлежит текущему персонажу")
        return
    var state: Dictionary = response["state"]
    if not _valid_state(state):
        request_failed.emit("Сервер не подтвердил данные персонажа")
        return
    state_ready.emit(response.duplicate(true))

func _valid_state(state: Dictionary) -> bool:
    return state.get("connected") == true and state.get("self") is Dictionary \
        and str(state["self"].get("id", "")) == _owner

func has_pending() -> bool:
    _restore_pending(_account_owner())
    return _recovery_error or not _pending.is_empty()

func _exit_tree() -> void:
    if http != null:
        http.cancel_request()
    _pending.clear()
