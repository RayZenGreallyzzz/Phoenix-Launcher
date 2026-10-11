extends SceneTree

# Godot 4.6 offline: canonical PPA personal storage and signed clan vault.
const NPC = preload("res://scripts/ppa_npc_screen.gd")
const STORAGE_SERVICE = preload("res://scripts/ppa_native_personal_storage_service.gd")
const OWNER := "990000001"
const OTHER := "990000002"

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, detail: String) -> void:
    if not ok:
        push_error("PPA_NATIVE_PERSONAL_STORAGE_FAIL: " + detail)
        quit(1)
        assert(ok, detail)

func _run() -> void:
    set_meta("phoenix_account", {"telegramId":OWNER})
    remove_meta("ppa_native_game_session")
    var host := Control.new()
    root.add_child(host)
    host.size = Vector2(1280,720)
    var npc := NPC.new()
    host.add_child(npc)
    npc.size = host.size
    var recorded: Array = []
    npc.personal_storage_action_requested.connect(func(fields: Dictionary):
        recorded.append(fields.duplicate(true)))
    npc.open_npc({"service":"storage","name":"Хранитель"})
    check(npc._body.find_child("PPARealPersonalStorage_put",true,false) == null,
        "Unsynced bag should not permit deposit")
    var live := {"gameId":"phoenix-pix-arena","contract":"ppa-personal-storage-v1",
        "ownerId":OWNER,"actions":["put","take"],"state":{"connected":true,
        "self":{"id":OWNER},"version":21,
        "bag":[{"uid":"epic-uid+7","name":"Броня +7","slot":"armor","rarity":"epic",
            "enh":7,"stats":{"def":145}}],
        "personal":[{"uid":"pet-uid+5","name":"Лунный лис +5","slot":"pet",
            "rarity":"epic","enh":5,"stats":{"hp":300}}]}}
    npc.apply_native_personal_storage(live)
    var dep := npc._body.find_child("PPARealPersonalStorage_put",true,false) as Button
    var take := npc._body.find_child("PPARealPersonalStorage_take",true,false) as Button
    check(dep != null and not dep.disabled and take != null and not take.disabled,
        "Actual signed bag and store cannot be moved")
    dep.pressed.emit()
    take.pressed.emit()
    check(recorded == [
        {"action":"put","uid":"epic-uid+7","version":21},
        {"action":"take","uid":"pet-uid+5","version":21}],
        "Client must send only exact original PPA UID and version")
    check(npc.personal_storage_state["bag"][0]["enh"] == 7,
        "Godot altered original +7 item without signed confirmation")
    npc.set_personal_storage_loading(false,true)
    dep = npc._body.find_child("PPARealPersonalStorage_put",true,false) as Button
    check(dep != null and dep.disabled,
        "Uncertain request must block second transfer")
    npc.set_personal_storage_loading(false,false)
    set_meta("phoenix_account",{"telegramId":OTHER})
    dep = npc._body.find_child("PPARealPersonalStorage_put",true,false) as Button
    dep.pressed.emit()
    check(recorded.size() == 2, "Other account could withdraw previous owner's items")
    set_meta("phoenix_account",{"telegramId":OWNER})
    npc._select_tab("clan")
    var clan := {"gameId":"phoenix-pix-arena","contract":"ppa-clan-v1",
        "ownerId":OWNER,"actions":["create","upgradeBonus"],
        "state":{"self":{"id":OWNER},"clan":{"id":"clanA","name":"PPA"},
            "storage":{"used":1,"max":500,"items":[{"uid":"clan+6","name":"Крылья +6","enh":6}]}}}
    npc.apply_native_clan(clan)
    check(npc.clan_state.get("storage",{}).get("items",[]).size() == 1,
        "Clan items were taken from obsolete character storage instead of canonical clan")
    check(npc.clan_actions.is_empty(), "Clan permissions exposed actions in the storage-only view")
    check(npc._body.find_child("PPARealPersonalStorage_put",true,false) == null,
        "Viewing clan vault reused personal deposit buttons")
    npc.close_npc()
    check(npc.personal_storage_state.is_empty() and npc.personal_storage_actions.is_empty(),
        "Closing storage retains previous owner balance/permissions")
    host.queue_free()
    await process_frame
    var bridge := STORAGE_SERVICE.new()
    check(bridge._pending_path(OWNER).find("storage/personal") == -1,
        "Pending requests path would create a nonexistent folder")
    bridge.free()
    print("PPA_NATIVE_PERSONAL_STORAGE_OK uid=1 original_plus7=1 replay=1 owner=1 clan_readonly=1")
    quit(0)
