extends SceneTree

# Headless PPA cache contract: real native world code, no network or save writes.
# Prevent a second GET on character/NPC opening right after city login.
class SaveWorld extends "res://scripts/native_world.gd":
    func _ready() -> void:
        pass

class FakeLoader extends Node:
    var loading := false
    var gets := 0
    func fetch_once() -> void:
        gets += 1

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, reason: String) -> void:
    if not ok:
        push_error("PPA_NATIVE_SAVE_CACHE_FAIL: " + reason)
        quit(1)
        assert(ok, reason)

func _run() -> void:
    set_meta("phoenix_account", {"telegramId":"990000001"})
    set_meta("ppa_native_game_session", "offline-valid-session-A")
    var game := SaveWorld.new()
    root.add_child(game)
    await process_frame
    var loader := FakeLoader.new()
    game.add_child(loader)
    game._server_snapshot_loader = loader

    game._refresh_server_readonly_save()
    check(loader.gets == 1, "First authenticated city GET missing")
    loader.loading = true
    game._refresh_server_readonly_save()
    check(loader.gets == 1 and not game._pending_save_refresh,
        "Menu open queued an unnecessary duplicate GET during city loading")
    loader.loading = false
    var payload := {"version":12, "state":{"lvl":40,"hp":980,
        "bag":[{"uid":"original_plus7", "enh":7}]}}
    game._on_readonly_snapshot_ready(payload)
    game._refresh_server_readonly_save()
    game._refresh_server_readonly_save()
    check(loader.gets == 1, "Opening menus caused repeated server loads")

    # Explicit manual refresh must bypass a fresh cache.
    game._refresh_server_readonly_save(true)
    check(loader.gets == 2, "Manual reload ignored")
    loader.loading = true
    game._refresh_server_readonly_save(true)
    check(game._pending_save_refresh, "Post-purchase reload should wait for ongoing GET")
    loader.loading = false
    game._on_readonly_snapshot_ready(payload)
    await process_frame
    await process_frame
    check(loader.gets == 3 and not game._pending_save_refresh,
        "Forced refresh queued during in-flight request was lost")

    # Never reuse saved items after switching owner, even inside 30 seconds.
    set_meta("phoenix_account", {"telegramId":"990000002"})
    game._refresh_server_readonly_save()
    check(loader.gets == 4, "Snapshot leaked across two accounts")
    loader.loading = false
    game._on_readonly_snapshot_failed("TELEGRAM_ID_MISMATCH")
    check(game._readonly_cache_at_ms == -1 and game._readonly_cache_owner.is_empty(),
        "Failed authentication did not clear cache identity")
    game._refresh_server_readonly_save()
    check(loader.gets == 5, "Failed snapshot was reused")
    loader.loading = false

    # The bearer session can rotate even without a new Telegram ID.
    game._on_readonly_snapshot_ready(payload)
    set_meta("ppa_native_game_session", "offline-valid-session-B")
    game._refresh_server_readonly_save()
    check(loader.gets == 6, "Snapshot survived session rotation")

    game.queue_free()
    remove_meta("phoenix_account")
    remove_meta("ppa_native_game_session")
    await process_frame
    print("PPA_NATIVE_SAVE_CACHE_OK city_prefetch=1 menu_reuse=1 manual_refresh=1 queued_force=1 owner_isolation=1 session_rotation=1 no_writes=1")
    quit(0)
