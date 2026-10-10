"""Fail-closed regression guard for PPA native account switching/snapshot."""
from pathlib import Path
root = Path(__file__).resolve().parents[3]
main = (root / "games/ppa-native/scripts/main.gd").read_text(encoding="utf-8")
select = (root / "games/ppa-native/scripts/character_select.gd").read_text(encoding="utf-8")
runtime = (root / "app/src/main/java/com/phoenixgames/launcher/runtime/GameRuntime.kt").read_text(encoding="utf-8")

assert 'FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK' in runtime, "Must start a fresh game instance per account"
assert 'FLAG_ACTIVITY_CLEAR_TOP' not in runtime, "Old Godot instance could be reused for new account"
assert 'if _restore_saved_session()' not in main, "Old account session must not be silently restored"
assert '_clear_saved_session()' in main
assert 'getStringExtra(key)' in main, "Game ticket must come from Launcher Android Intent"
assert '/api/game/session/exchange' in main
assert '/api/game/state' in main, "Use actual shared PPA save"
assert 'HTTPClient.METHOD_GET' in main
assert '"Authorization: Bearer " + session_token' in main
assert 'data.get("readOnly", false)' in main, "Never treat writable/untrusted state as authoritative"
assert 'p.get("telegramId"' in main, "Compare state owner against launcher account"
assert 'verified_save_version < 1' in main
assert 'ppa_native_authoritative_state' in main
assert 'set_verified_state' in main and 'set_verified_state' in select
assert 'state_read_available = false' in main
assert 'account_switch_requested.connect(_return_to_launcher)' in main
assert 'func _return_to_launcher()' in main
assert 'get_tree().quit()' in main
assert 'registration_requested.emit(' in select, "Native new-hero UI must collect nickname and class"
assert 'LineEdit.new()' in select, "Nickname field must exist for new players"
assert 'signal registration_requested' in select
assert 'selection_screen.registration_requested.connect(_register_character)' in main
assert '/api/game/character/register' in main, "Native must use server-owned registration only"
assert 'HTTPClient.METHOD_POST' in main
assert '_nullable_account_text' in main, "Null Email provider must not look like registered hero"
assert 'Email-only регистрация ждёт миграцию' in select, "Email-only saves must not fabricate Telegram IDs"
assert 'button.disabled = locked' in select, "Real characters cannot swap class just by clicking a visual preview"
assert 'ТЕСТ: классы, сумка и склад локальные' in select, "Unconnected beta inventory must be disclosed"
assert 'get_tree().set_meta("ppa_native_game_session", session_token)' in main, "MISSING HANDOFF: native world cannot read the authenticated save"
assert 'resized.connect(_adapt_orientation)' in select, "Phone/tablet responsive class UI must be preserved"
assert 'func _adapt_orientation()' in select
assert '/api/game/npc/' not in main, "Entry flow must not issue NPC mutations"
assert '"/api/save"' not in main, "Native account flow must never write legacy player state"
print('PPA_NATIVE_INTEGRATION_GUARD_OK fresh_ticket=1 identity=1 handoff=1 read_only=1 orientation=1 class_locked=1')
