#!/usr/bin/env python3
"""Non-mutating source guard: original PPA 2.5D combat HUD in same APK."""
from pathlib import Path

root = Path(__file__).resolve().parents[3]
hud = (root / "games/ppa-native/scripts/ppa_combat_hud.gd").read_text(encoding="utf-8")
world = (root / "games/ppa-native/scripts/native_world.gd").read_text(encoding="utf-8")
arena = (root / "games/ppa-native/scripts/arena_training_world.gd").read_text(encoding="utf-8")
export = (root / "games/ppa-native/export_presets.cfg").read_text(encoding="utf-8")

assert 'package/unique_name="com.phoenixgames.ppa"' in export, "Existing PPA package must stay unchanged"
assert 'signal action_requested(action: String, slot: int)' in hud
assert 'func _layout()' in hud and "GROUP_H * factor" in hud
assert hud.count('_skills.append(skill)') == 1 and "range(4)" in hud
for key in ['"pk"', '"auto"', '"potion_hp"', '"potion_mp"', '"attack"', '"skill"']:
    assert key in hud, f"Missing Telegram combat control: {key}"
assert "skillRanks" in hud and "GRIMOIRES.class_info" in hud
assert 'func apply_server_save(save: Dictionary)' in hud
assert 'func clear_server_save()' in hud
assert '"maxHp"' in hud and '"maxMp"' in hud
assert "get_global_rect().has_point(point)" in hud
for forbidden in ["HTTPClient.METHOD_POST", "/api/save", "saveGameState", 'peer.send_text(', "player_hp -="]:
    assert forbidden not in hud, f"Native HUD must not fabricate server actions: {forbidden}"
assert 'const PPA_COMBAT_HUD = preload("res://scripts/ppa_combat_hud.gd")' in world
assert '_combat_hud.action_requested.connect(_on_hud_action)' in world
assert '_combat_hud.apply_server_save(save)' in world
assert '_combat_hud.clear_server_save()' in world
assert '_combat_hud.is_over_action_area(screen_position)' in world
assert "func _on_hud_action(action: String, slot: int)" in arena
assert "super._on_hud_action(action, slot)" in arena
assert "_attack_button.pressed.connect(_player_attack)" not in arena
assert '_combat_hud.set_training(true)' in arena
print("PPA_ORIGINAL_COMBAT_HUD_OK one_hud=1 skill_arc=4 read_only=1 existing_package=1")
