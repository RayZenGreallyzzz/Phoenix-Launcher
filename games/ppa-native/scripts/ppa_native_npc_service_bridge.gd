extends Node

# Secure Phoenix Game Session -> EXISTING PPA save-derived NPC projection.
# GET only. Never sends purchase, item, hero ID, currency changes or rewards.
# This is UI synchronization, not permission to spend Telegram PPA funds.
signal service_ready(payload: Dictionary)
signal service_failed(service: String, code: String)

const API_BASE := "https://ppa-phoenixpixarena.1988stella1988.workers.dev"
const GAME_ID := "phoenix-pix-arena"
const SERVICES := ["merchant","forge","storage","auction","clan","arena","blackmarket","dungeon","fartzone"]
var http: HTTPRequest
var loading := false
var requested_service := ""
var queued_service := ""
var last_version := -1
var _requested_owner := ""
var _requested_session_sha := ""

func _ready() -> void:
    http = HTTPRequest.new()
    http.timeout = 15.0
    add_child(http)
    http.request_completed.connect(_on_completed)

func request_service(service: String) -> void:
    if not SERVICES.has(service):
        service_failed.emit(service, "INVALID_SERVICE")
        return
    var account: Variant = get_tree().get_meta("phoenix_account", {})
    var owner := str(account.get("telegramId", "")) if account is Dictionary else ""
    var bearer_raw: Variant = get_tree().get_meta("ppa_native_game_session", "")
    var bearer := str(bearer_raw)
    if owner.is_empty():
        service_failed.emit(service, "NO_LINKED_OWNER")
        return
    if bearer.is_empty() or bearer == "<null>":
        service_failed.emit(service, "NO_GAME_SESSION")
        return
    var session_sha := bearer.sha256_text()
    if loading:
        # An in-flight NPC GET is bound to ONE owner and bearer. The next
        # request must still be issued on account/session change, even when
        # it targets the exact same merchant or blacksmith.
        if service != requested_service or owner != _requested_owner \
                or session_sha != _requested_session_sha:
            queued_service = service
        return
    requested_service = service
    _requested_owner = owner
    _requested_session_sha = session_sha
    loading = true
    var headers := PackedStringArray([
        "Authorization: Bearer " + bearer,
        "Accept: application/json",
        "Cache-Control: no-store"
    ])
    var err := http.request(API_BASE + "/api/game/npc/" + service, headers, HTTPClient.METHOD_GET)
    if err != OK:
        loading = false
        service_failed.emit(service, "REQUEST_" + str(err))
        call_deferred("_drain_queued_service")

func _drain_queued_service() -> void:
    if loading or queued_service.is_empty():
        return
    var next_service := queued_service
    queued_service = ""
    request_service(next_service)

func _on_completed(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    loading = false
    # Defer until all response validation/emission is finished.
    call_deferred("_drain_queued_service")
    var service := requested_service
    var owner_at_request := _requested_owner
    var session_at_request := _requested_session_sha
    requested_service = ""
    _requested_owner = ""
    _requested_session_sha = ""
    var account: Variant = get_tree().get_meta("phoenix_account", {})
    var owner_now := str(account.get("telegramId", "")) if account is Dictionary else ""
    var bearer_now := str(get_tree().get_meta("ppa_native_game_session", ""))
    if owner_at_request.is_empty() or owner_at_request != owner_now \
            or session_at_request.is_empty() or bearer_now.sha256_text() != session_at_request:
        service_failed.emit(service, "STALE_SESSION")
        return
    if result != HTTPRequest.RESULT_SUCCESS:
        service_failed.emit(service, "TRANSPORT_" + str(result))
        return
    if status != 200:
        # Code only; never log the bearer token or the response save body.
        service_failed.emit(service, "HTTP_" + str(status))
        return
    var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
    if not (parsed is Dictionary):
        service_failed.emit(service, "INVALID_JSON")
        return
    var response: Dictionary = parsed
    # Signed response must explicitly name its server-authenticated Telegram
    # owner. An old Worker missing this field must not expose a hero's stock.
    if str(response.get("ownerId", "")) != owner_at_request:
        service_failed.emit(service, "OWNER_MISMATCH")
        return
    if response.get("ok", false) != true or response.get("readOnly", false) != true \
        or str(response.get("gameId", "")) != GAME_ID \
        or str(response.get("service", "")) != service \
        or not (response.get("data") is Dictionary):
        service_failed.emit(service, "INVALID_SERVICE_CONTRACT")
        return
    var version = response.get("version", null)
    if not (version is int or version is float) or int(version) < 1:
        service_failed.emit(service, "UNVERIFIED_SAVE")
        return
    var data: Dictionary = response["data"]
    if data.get("readOnly", false) != true or data.get("actionsEnabled", true) != false:
        service_failed.emit(service, "UNSAFE_ACTION_FLAGS")
        return
    # The server is allowed to return only one authenticated owner's view.
    # DO NOT merge into a save or store this JSON in a local file.
    last_version = int(version)
    service_ready.emit(response.duplicate(true))
