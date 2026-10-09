extends Node

# A single authenticated, READ-ONLY snapshot of the existing PPA save.
# Never posts to /api/save or writes game state, skills, drops or inventory.
# The bearer token originates from the validated, one-time Phoenix game ticket
# and is kept in process memory only, not displayed in UI or written to logs.
signal snapshot_ready(snapshot: Dictionary)
signal snapshot_failed(code: String)

const API_BASE := "https://ppa-phoenixpixarena.1988stella1988.workers.dev"
const GAME_ID := "phoenix-pix-arena"
const ENDPOINT := "/api/game/state"

var http: HTTPRequest
var loading := false
var last_status := 0

func _ready() -> void:
    http = HTTPRequest.new()
    http.timeout = 20.0
    add_child(http)
    http.request_completed.connect(_on_completed)

func fetch_once() -> void:
    if loading or http == null:
        return
    # Never reuse a former hero's save across scene transitions or accounts.
    get_tree().remove_meta("ppa_readonly_snapshot")
    var bearer: String = str(get_tree().get_meta("ppa_native_game_session", ""))
    if bearer.is_empty():
        snapshot_failed.emit("NO_GAME_SESSION")
        return
    loading = true
    var err := http.request(
        API_BASE + ENDPOINT,
        PackedStringArray([
            "Authorization: Bearer " + bearer,
            "Accept: application/json",
            "Cache-Control: no-store"
        ]),
        HTTPClient.METHOD_GET
    )
    if err != OK:
        loading = false
        snapshot_failed.emit("NETWORK_REQUEST_" + str(err))

func _on_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    loading = false
    last_status = response_code
    # An auth error, partial response or wrong identity must never leave an
    # earlier account's inventory/stats available in SceneTree metadata.
    get_tree().remove_meta("ppa_readonly_snapshot")
    if result != HTTPRequest.RESULT_SUCCESS:
        snapshot_failed.emit("TRANSPORT_" + str(result))
        return
    var parsed = JSON.parse_string(body.get_string_from_utf8())
    if not (parsed is Dictionary):
        snapshot_failed.emit("BAD_SERVER_JSON")
        return
    var response: Dictionary = parsed
    if response_code != 200 or response.get("ok", false) != true:
        # Never log the response body, bearer token, save, inventory or user ID.
        snapshot_failed.emit("SERVER_HTTP_" + str(response_code) + "_" + str(response.get("code", "ERROR")))
        return
    if response.get("readOnly", false) != true or str(response.get("gameId", "")) != GAME_ID:
        snapshot_failed.emit("UNEXPECTED_SNAPSHOT_CONTRACT")
        return
    if not (response.get("state") is Dictionary):
        snapshot_failed.emit("NO_REGISTERED_SAVE")
        return
    var account = get_tree().get_meta("phoenix_account", {})
    var profile = response.get("profile", {})
    if not (account is Dictionary) or not (profile is Dictionary):
        snapshot_failed.emit("INVALID_IDENTITY")
        return
    var expected_tg: String = str(account.get("telegramId", ""))
    var actual_tg: String = str(profile.get("telegramId", ""))
    if expected_tg.is_empty() or expected_tg == "<null>" or actual_tg != expected_tg:
        snapshot_failed.emit("TELEGRAM_ID_MISMATCH")
        return
    var state: Dictionary = response["state"]
    # The original PPA save includes these profile-bound IDs. Reject a
    # contradictory saved identity even when the response profile matches.
    for field in ["telegramId", "profileTelegramId"]:
        if state.has(field) and str(state[field]) != expected_tg:
            snapshot_failed.emit("SAVE_TELEGRAM_ID_MISMATCH")
            return
    # Never persist any of this data or feed it back as an attempted save.
    var immutable_copy: Dictionary = response.duplicate(true)
    get_tree().set_meta("ppa_readonly_snapshot", immutable_copy)
    snapshot_ready.emit(immutable_copy)
