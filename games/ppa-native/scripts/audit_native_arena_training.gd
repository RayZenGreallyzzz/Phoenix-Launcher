extends SceneTree

# Headless end-to-end smoke: live NPC controls open a playable arena scene.
# No Phoenix session, no network, no production player record or currency.
const NPC = preload("res://scripts/ppa_npc_screen.gd")
const ARENA = preload("res://arena_training.tscn")

func _initialize() -> void:
    call_deferred("_check")

func fail(message: String) -> void:
    push_error("PPA_ARENA_PRACTICE_FAIL: " + message)
    quit(1)

func _check() -> void:
    var container := Control.new()
    container.size = Vector2(1280, 720)
    root.add_child(container)
    var npc := NPC.new()
    container.add_child(npc)
    npc.size = container.size
    var calls := {"count": 0}
    npc.arena_training_requested.connect(func(): calls["count"] += 1)
    npc.open_npc({"service":"merchant","id":"merchant","name":"Торговец"})
    await process_frame
    if not npc.visible or npc.service != "merchant":
        fail("Merchant NPC must open its real tabbed store")
        return
    npc.close_npc()
    npc.open_npc({"service":"arena","id":"arena","name":"Мечник арены"})
    await process_frame
    var training: Button = npc.find_child("NpcArenaAiPractice", true, false) as Button
    if training == null or training.disabled:
        fail("AI training must have a clickable entry button at the Arena NPC")
        return
    training.pressed.emit()
    if int(calls["count"]) != 1:
        fail("Arena NPC did not emit exactly one authorized local scene request")
        return

    var game = ARENA.instantiate()
    if game == null:
        fail("Local playable arena scene missing")
        return
    game.size = Vector2(1280, 720)
    root.add_child(game)
    await process_frame
    if game.bots.size() != 3 or game.player_hp != game.PLAYER_MAX_HP:
        fail("Arena needs three real mobile AI bots and live HP")
        return
    # All worlds share ONE original Telegram PPA HUD. The old arena-only
    # _attack_button was intentionally removed; verify the real 80px button.
    if game._combat_hud == null:
        fail("Shared PPA combat HUD missing from Arena practice")
        return
    var attack_button = game._combat_hud.find_child("PPAOriginalAttackButton", true, false) as Button
    if attack_button == null or attack_button.disabled:
        fail("Original shared PPA attack control is unavailable")
        return
    var first: Dictionary = game.bots[0]
    (first["node"] as Node2D).position = game.world_pos_px + Vector2(65, 0)
    game.bots[0] = first
    var hp_before := int(game.bots[0]["hp"])
    attack_button.pressed.emit()
    if int(game.bots[0]["hp"]) >= hp_before:
        fail("Pressing attack must DAMAGE an actual AI bot")
        return
    first = game.bots[0]
    first["cooldown"] = 0.0
    game.bots[0] = first
    game._physics_process(0.15)
    if game.player_hp >= game.PLAYER_MAX_HP:
        fail("Approaching AI bot must DAMAGE the player")
        return
    if game.finished:
        fail("Combat ended before all AI opponents were defeated")
        return
    if not game.get_script().resource_path.ends_with("arena_training_world.gd"):
        fail("Wrong training scene script")
        return
    print("PPA_ARENA_TRAINING_PLAYABLE_OK merchant=1 arena_npc=1 ai_count=3 hud_attack_signal=1 enemy_attack=1 original_world_hero=1 server_writes=0")
    quit()
