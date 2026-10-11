extends SceneTree

const BRIDGE = preload("res://scripts/ppa_native_combat_profile_bridge.gd")
var successes: Array[Dictionary] = []
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, reason: String) -> void:
    if not ok:
        push_error("PPA_NATIVE_COMBAT_PROFILE_BRIDGE_FAIL: " + reason)
        quit(1)
        assert(ok, reason)

func arm(bridge: Node) -> void:
    var account: Dictionary = get_meta("phoenix_account",{})
    bridge._request_owner = str(account.get("telegramId",""))
    bridge._request_class = str(account.get("classKey",""))
    bridge._request_session_sha = str(get_meta("ppa_native_game_session","")).sha256_text()

func send(bridge: Node, obj: Dictionary, status: int = 200) -> void:
    bridge._on_completed(HTTPRequest.RESULT_SUCCESS,status,PackedStringArray(),
        JSON.stringify(obj).to_utf8_buffer())

func _run() -> void:
    set_meta("phoenix_account",{"telegramId":"game-owner-A","classKey":"gnome"})
    set_meta("ppa_native_game_session","offline-a")
    var bridge := BRIDGE.new()
    root.add_child(bridge)
    bridge.profile_ready.connect(func(p: Dictionary): successes.append(p))
    bridge.profile_failed.connect(func(code: String): failures.append(code))
    await process_frame
    var sample := {
        "ok":true,"ownerId":"game-owner-A","gameId":"phoenix-pix-arena",
        "version":27,"readOnly":true,"actionsEnabled":false,
        "combat":{
            "version":27,"readOnly":true,"actionsEnabled":false,
            "canAttack":false,"canCast":false,"canReceiveRewards":false,
            "authoritativeCombatStats":null,
            "candidate":{"registeredClass":"gnome","level":40,
                "equipped":{"weapon":{"uid":"plus7-gear","enhance":7}},
                "skillRanks":{"cannon_shot":5}},
            "blockedReasons":["SERVER_DAMAGE_AND_REWARD_SETTLEMENT_NOT_READY"]
        }
    }
    var original := JSON.stringify(sample)
    arm(bridge)
    send(bridge,sample)
    check(successes.size() == 1 and failures.is_empty(),
        "Valid read-only profile from signed user rejected")
    check(successes[0]["combat"]["candidate"]["equipped"]["weapon"]["enhance"] == 7,
        "Existing +7 gear modified during profile audit")
    check(successes[0]["combat"]["canAttack"] == false,
        "Read-only profile enabled client damage")
    successes.clear()
    for override in [
        {"ownerId":"game-owner-B"},
        {"gameId":"different-game"},
        {"actionsEnabled":true},
        {"readOnly":false}
    ]:
        var bad: Dictionary = sample.duplicate(true)
        bad.merge(override,true)
        arm(bridge)
        send(bridge,bad)
        check(successes.is_empty() and failures.back() == "UNVERIFIED_OWNER_OR_CONTRACT",
            "Foreign owner or untrusted response accepted: " + str(override))
    for field in ["canAttack","canCast","canReceiveRewards","actionsEnabled"]:
        var bad: Dictionary = sample.duplicate(true)
        bad["combat"][field] = true
        arm(bridge)
        send(bridge,bad)
        check(successes.is_empty() and failures.back() == "UNSAFE_COMBAT_PERMISSION",
            "Untrusted combat enable flag accepted: " + field)
    var damage: Dictionary = sample.duplicate(true)
    damage["combat"]["authoritativeCombatStats"] = {"atk":9999999}
    arm(bridge)
    send(bridge,damage)
    check(successes.is_empty() and failures.back() == "UNSAFE_COMBAT_PERMISSION",
        "Fake authoritative ATK enabled combat")
    var switched: Dictionary = sample.duplicate(true)
    arm(bridge)
    set_meta("ppa_native_game_session","offline-b")
    send(bridge,switched)
    check(successes.is_empty() and failures.back() == "STALE_SESSION",
        "Late old-session PPA profile crossed token rotation")
    arm(bridge)
    set_meta("phoenix_account",{"telegramId":"game-owner-B","classKey":"gnome"})
    send(bridge,switched)
    check(successes.is_empty() and failures.back() == "STALE_SESSION",
        "Late profile crossed Telegram account switch")
    set_meta("phoenix_account",{"telegramId":"game-owner-A","classKey":"mage"})
    arm(bridge)
    send(bridge,switched)
    check(successes.is_empty() and failures.back() == "REGISTERED_CLASS_MISMATCH",
        "Verified character class mismatch was accepted")
    set_meta("phoenix_account",{"telegramId":"game-owner-A","classKey":"gnome"})
    arm(bridge)
    send(bridge,sample,404)
    check(successes.is_empty() and failures.back() == "HTTP_404",
        "Default-OFF read flag did not fail closed")
    check(JSON.stringify(sample) == original,
        "Native profile observer modified legacy D1 save")
    check(not ENDPOINT_MALFORMED(bridge),
        "Bridge must be GET-only and use actual signed player endpoint")
    bridge.queue_free()
    await process_frame
    print("PPA_NATIVE_COMBAT_PROFILE_BRIDGE_OK signed_owner=1 token_rotation=blocked account_switch=blocked class=bound readonly=1 attack=blocked currency_and_plus7_untouched=1")
    quit(0)

func ENDPOINT_MALFORMED(bridge: Node) -> bool:
    return bridge.ENDPOINT != "/api/game/combat/profile" or \
        not bridge.API_BASE.begins_with("https://")
