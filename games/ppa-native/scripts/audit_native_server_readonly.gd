extends SceneTree

const CLIENT = preload("res://scripts/ppa_server_readonly_snapshot.gd")
const CLASS_GALLERY = preload("res://scripts/character_select.gd")
var got_snapshot := false
var last_failure := ""

func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("PPA_SERVER_READONLY_AUDIT: " + message)
    quit(1)

func _run() -> void:
    set_meta("phoenix_account", {"telegramId":"test-own-user","ppaNickname":"TestHero","classKey":"gnome"})
    var client := CLIENT.new()
    root.add_child(client)
    client.snapshot_ready.connect(func(_payload: Dictionary) -> void: got_snapshot = true)
    client.snapshot_failed.connect(func(code: String) -> void: last_failure = code)
    await process_frame
    var headers := PackedStringArray()
    var saved := {
        "ok":true,"readOnly":true,"gameId":"phoenix-pix-arena",
        "version":24,"profile":{"telegramId":"test-own-user","nickname":"TestHero"},
        "state":{"lvl":22,"hp":412,"mp":76,"playerName":"TestHero","bag":[{"id":"test_gear","qty":1}]}
    }
    client._on_completed(HTTPRequest.RESULT_SUCCESS,200,headers,JSON.stringify(saved).to_utf8_buffer())
    if not got_snapshot or last_failure != "":
        _fail("valid own-player immutable snapshot was refused")
        return
    var observed = get_meta("ppa_readonly_snapshot", {})
    if not (observed is Dictionary) or observed.get("version") != 24:
        _fail("server save version missing")
        return
    if observed.get("state",{}).get("bag",[]).size() != 1 or observed.get("state",{}).get("hp") != 412:
        _fail("original HP and bag were not received")
        return
    # Do not accept a forged profile / wrong account even if HTTP returns 200.
    got_snapshot=false
    last_failure=""
    saved["profile"]["telegramId"]="other-user"
    client._on_completed(HTTPRequest.RESULT_SUCCESS,200,headers,JSON.stringify(saved).to_utf8_buffer())
    if got_snapshot or last_failure != "TELEGRAM_ID_MISMATCH":
        _fail("received a different Telegram account's saved state")
        return
    if has_meta("ppa_readonly_snapshot"):
        _fail("cached snapshot survived foreign-profile rejection")
        return
    got_snapshot = false
    last_failure = ""
    saved["profile"]["telegramId"] = "test-own-user"
    saved["state"]["telegramId"] = "other-user"
    client._on_completed(HTTPRequest.RESULT_SUCCESS,200,headers,JSON.stringify(saved).to_utf8_buffer())
    if got_snapshot or last_failure != "SAVE_TELEGRAM_ID_MISMATCH" or has_meta("ppa_readonly_snapshot"):
        _fail("a foreign save identity was accepted or stale data was retained")
        return
    got_snapshot=false
    last_failure=""
    client._on_completed(HTTPRequest.RESULT_SUCCESS,401,headers,JSON.stringify({"ok":false,"code":"GAME_SESSION_EXPIRED"}).to_utf8_buffer())
    if got_snapshot or not last_failure.begins_with("SERVER_HTTP_401_") or has_meta("ppa_readonly_snapshot"):
        _fail("expired game session left a readable or cached save")
        return
    if client.ENDPOINT != "/api/game/state" or client.API_BASE.begins_with("http://"):
        _fail("unsafe or wrong server endpoint")
        return
    # Preview art must not change the class of the authenticated hero.
    # A player may browse Archer art, but PPA must still open their actual
    # registered Gnome when "Enter City" is pressed.
    var gallery := CLASS_GALLERY.new()
    gallery.account = {"classKey":"gnome", "ppaNickname":"TestHero"}
    root.add_child(gallery)
    gallery._choose_class("archer")
    gallery._confirm_preview()
    if str(get_meta("ppa_native_test_class", "")) != "gnome":
        _fail("3D preview class replaced real PPA server character class")
        return
    gallery.queue_free()
    print("PPA_NATIVE_SERVER_CLASS_PIN_OK preview=archer gameplay=gnome class_writes=0")
    print("PPA_NATIVE_AUTH_READONLY_SMOKE_OK own_snapshot=1 hp=412 inventory=1 cross_user=blocked stale_cache=cleared expired_session=blocked server_writes=0")
    client.queue_free()
    quit(0)
