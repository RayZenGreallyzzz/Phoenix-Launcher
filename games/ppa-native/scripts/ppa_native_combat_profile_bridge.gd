extends Node

# Signed, staged read-only D1 combat profile AUDIT. Not a source of
# executable damage, HP/MP, cooldowns or reward authorization.
# The endpoint is OFF unless the operator enables TWO explicit read flags.
signal profile_ready(payload: Dictionary)
signal profile_failed(code: String)

const API_BASE := "https://ppa-phoenixpixarena.1988stella1988.workers.dev"
const ENDPOINT := "/api/game/combat/profile"
const GAME_ID := "phoenix-pix-arena"

var http: HTTPRequest
var loading := false
var _request_owner := ""
var _request_session_sha := ""
var _request_class := ""

func _ready() -> void:
    http = HTTPRequest.new()
    http.timeout = 15.0
    add_child(http)
    http.request_completed.connect(_on_completed)

func request_profile_for_qa() -> void:
    if loading or http == null:
        return
    var account: Variant = get_tree().get_meta("phoenix_account", {})
    var owner := str(account.get("telegramId","")) if account is Dictionary else ""
    var class_key := str(account.get("classKey","")) if account is Dictionary else ""
    var bearer := str(get_tree().get_meta("ppa_native_game_session",""))
    if owner.is_empty() or owner == "<null>":
        profile_failed.emit("NO_LINKED_OWNER")
        return
    if bearer.is_empty() or bearer == "<null>":
        profile_failed.emit("NO_GAME_SESSION")
        return
    _request_owner = owner
    _request_session_sha = bearer.sha256_text()
    _request_class = class_key
    loading = true
    var err := http.request(API_BASE + ENDPOINT,PackedStringArray([
        "Authorization: Bearer " + bearer,
        "Accept: application/json",
        "Cache-Control: no-store"
    ]),HTTPClient.METHOD_GET)
    if err != OK:
        loading = false
        _request_owner = ""
        _request_session_sha = ""
        _request_class = ""
        profile_failed.emit("REQUEST_" + str(err))

func _on_completed(result: int, status: int, _headers: PackedStringArray,
        body: PackedByteArray) -> void:
    loading = false
    var owner_at_request := _request_owner
    var session_at_request := _request_session_sha
    var class_at_request := _request_class
    _request_owner = ""
    _request_session_sha = ""
    _request_class = ""
    var account: Variant = get_tree().get_meta("phoenix_account", {})
    var current_owner := str(account.get("telegramId","")) if account is Dictionary else ""
    var current_class := str(account.get("classKey","")) if account is Dictionary else ""
    var bearer := str(get_tree().get_meta("ppa_native_game_session",""))
    if owner_at_request.is_empty() or owner_at_request != current_owner \
            or class_at_request != current_class \
            or session_at_request.is_empty() or session_at_request != bearer.sha256_text():
        profile_failed.emit("STALE_SESSION")
        return
    if result != HTTPRequest.RESULT_SUCCESS:
        profile_failed.emit("TRANSPORT_" + str(result))
        return
    if status != 200:
        profile_failed.emit("HTTP_" + str(status))
        return
    var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
    if not (parsed is Dictionary):
        profile_failed.emit("INVALID_JSON")
        return
    var response: Dictionary = parsed
    if response.get("ok",false) != true or \
            str(response.get("ownerId","")) != owner_at_request or \
            str(response.get("gameId","")) != GAME_ID or \
            response.get("readOnly") != true or \
            response.get("actionsEnabled") != false:
        profile_failed.emit("UNVERIFIED_OWNER_OR_CONTRACT")
        return
    var version: Variant = response.get("version",null)
    if not (version is int or version is float) or int(version) < 1:
        profile_failed.emit("UNVERIFIED_SAVE_VERSION")
        return
    var raw: Variant = response.get("combat",null)
    if not (raw is Dictionary):
        profile_failed.emit("INVALID_PROFILE")
        return
    var combat: Dictionary = raw
    # No later server version may be interpreted as combat approval through
    # this AUDIT endpoint. It must remain deny-only by its contract.
    if combat.get("readOnly") != true or combat.get("actionsEnabled") != false \
            or combat.get("canAttack") != false or combat.get("canCast") != false \
            or combat.get("canReceiveRewards") != false \
            or combat.get("authoritativeCombatStats") != null \
            or int(combat.get("version",-1)) != int(version):
        profile_failed.emit("UNSAFE_COMBAT_PERMISSION")
        return
    var candidate: Variant = combat.get("candidate",null)
    if not (candidate is Dictionary):
        profile_failed.emit("INVALID_CANDIDATE")
        return
    if not class_at_request.is_empty() and \
            str(candidate.get("registeredClass","")) != class_at_request:
        profile_failed.emit("REGISTERED_CLASS_MISMATCH")
        return
    # Only emit an isolated copy. Never mutate the original Telegram PPA save
    # or install these candidate stats into the native runtime combat actor.
    profile_ready.emit(response.duplicate(true))
