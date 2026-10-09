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
assert 'button.disabled = locked' in select, "Real characters cannot swap class just by clicking a visual preview"
assert 'ТЕСТ: классы, сумка и склад локальные' in select, "Unconnected beta inventory must be disclosed"
assert 'Сумка тестового мира пока локальная' in select, "Read-only server snapshot is not yet real inventory integration"
print('PPA_NATIVE_ACCOUNT_GUARD_OK fresh_ticket=1 owner_match=1 read_only=1 beta_isolated=1 class_locked=1')
