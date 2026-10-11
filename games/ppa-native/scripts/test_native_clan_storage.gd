extends SceneTree

# Offline Godot 4.6 safety gate for the ORIGINAL common clan D1 vault.
# No real account, requests, D1 writes or Telegram session tokens.
const NPC = preload("res://scripts/ppa_npc_screen.gd")
const BRIDGE = preload("res://scripts/ppa_native_clan_storage_service.gd")
const OWNER := "990000001"
const OTHER := "990000002"
const REVISION := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, why: String) -> void:
    if not ok:
        push_error("PPA_NATIVE_ATOMIC_CLAN_STORAGE_FAIL: " + why)
        quit(1)
        assert(ok, why)

func _run() -> void:
    set_meta("phoenix_account", {"telegramId":OWNER})
    remove_meta("ppa_native_game_session")
    var host := Control.new()
    root.add_child(host)
    host.size = Vector2(1280,720)
    var npc := NPC.new()
    host.add_child(npc)
    npc.size = host.size
    var emitted: Array = []
    npc.clan_storage_action_requested.connect(func(fields: Dictionary): emitted.append(fields.duplicate(true)))
    npc.open_npc({"service":"storage","name":"Хранитель"})
    npc._select_tab("clan")
    check(npc._body.find_child("PPARealClanStorage_put",true,false) == null,
        "Unsigned clan vault unexpectedly enabled transfers")
    var quote := {"gameId":"phoenix-pix-arena","contract":"ppa-clan-storage-v1",
        "ownerId":OWNER,"actions":["put","take"],
        "state":{"connected":true,"self":{"id":OWNER},"version":12,
        "clanRevision":REVISION,"clanId":"clan-true","storageUnlocked":true,
        "canDeposit":true,"capacity":{"bag":100,"clan":500},
        "bag":[{"uid":"weapon-7","name":"Оружие +7","enh":7,"rarity":"epic","stats":{"atk":777}}],
        "items":[{"uid":"pet-5","name":"Лунный лис +5","enh":5,"rarity":"epic","canTake":true},
            {"uid":"protected-6","name":"Чужие крылья +6","enh":6,"canTake":false}]}}
    npc.apply_native_clan_storage(quote)
    var put := npc._body.find_child("PPARealClanStorage_put",true,false) as Button
    var take := npc._body.find_child("PPARealClanStorage_take",true,false) as Button
    check(put != null and not put.disabled and take != null and not take.disabled,
        "Signed allowed put/take not visible")
    put.pressed.emit()
    take.pressed.emit()
    check(emitted == [
        {"action":"put","uid":"weapon-7","version":12,"clanRevision":REVISION},
        {"action":"take","uid":"pet-5","version":12,"clanRevision":REVISION}],
        "Clan action must only use original server UID, version and revision")
    check(npc.clan_storage_state["bag"][0]["enh"] == 7,
        "Native UI rewrote original equipped gear on speculative transfer")
    npc._request_clan_storage_move("take","protected-6",12,REVISION)
    check(emitted.size() == 2,"Client bypassed selected-item withdrawal rights")
    npc.set_clan_storage_loading(false,true)
    put = npc._body.find_child("PPARealClanStorage_put",true,false) as Button
    check(put != null and put.disabled,"Unconfirmed action enabled a duplicate")
    npc.set_clan_storage_loading(false,false)
    set_meta("phoenix_account",{"telegramId":OTHER})
    npc._request_clan_storage_move("put","weapon-7",12,REVISION)
    check(emitted.size() == 2,"Account switch bypassed owner binding")
    set_meta("phoenix_account",{"telegramId":OWNER})
    var disabled := quote.duplicate(true)
    disabled["actions"] = []
    npc.apply_native_clan_storage(disabled)
    put = npc._body.find_child("PPARealClanStorage_put",true,false) as Button
    check(put != null and put.disabled,"Default-off server action flag ignored")
    npc.close_npc()
    check(npc.clan_storage_state.is_empty() and npc.clan_storage_actions.is_empty(),
        "Previous character clan permissions persisted after closing")
    var bridge := BRIDGE.new()
    check(bridge._pending_path(OWNER).find("storage/clan") < 0,
        "Request retry path would create unsupported nested directory")
    bridge.free()
    host.queue_free()
    await process_frame
    print("PPA_NATIVE_ATOMIC_CLAN_STORAGE_OK owner=1 version=1 revision=1 selected_rights=1 no_local_write=1 pending=1")
    quit(0)
