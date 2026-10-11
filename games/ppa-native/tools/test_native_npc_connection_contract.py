#!/usr/bin/env python3
"""Safe source smoke test for the native NPC connection and error contract.

This does not call Cloudflare, spend currencies or touch a character save.
"""
from pathlib import Path

scripts = Path(__file__).resolve().parents[1] / "scripts"
world = (scripts / "native_world.gd").read_text(encoding="utf-8")
menu = (scripts / "test_world_menu.gd").read_text(encoding="utf-8")
npc = (scripts / "ppa_npc_screen.gd").read_text(encoding="utf-8")
bridge = (scripts / "ppa_native_npc_service_bridge.gd").read_text(encoding="utf-8")

entry = world.split("func _request_npc_service(service: String) -> void:", 1)[1].split("\nfunc ", 1)[0]
assert entry.count("_npc_service_loader.request_service(service)") == 1, "All NPC types must get one projection request"
assert entry.rfind("_npc_service_loader.request_service(service)") > entry.rfind('elif service == "storage":')
assert "_merchant_service.request_state()" in entry
assert "_forge_service.request_state()" in entry
assert "_auction_service.request_state()" in entry
assert "_clan_service.request_state()" in entry
assert "_npc_service_loader.service_failed.connect(_on_npc_service_failed)" in world
assert 'test_menu.set_npc_service_failure(service, code)' in world
assert "    pass\n" not in world.split("func _on_npc_service_failed(",1)[1].split("\nfunc ",1)[0]
assert "func set_npc_service_failure(service: String, code: String)" in menu
assert '_npc_screen.set_npc_service_failure(service, code)' in menu
assert 'func set_npc_service_failure(requested: String, code: String)' in npc
for reason in ("NO_LINKED_OWNER", "NO_GAME_SESSION", "HTTP_404", "HTTP_409"):
    assert reason in npc, f"Missing visible diagnostic for {reason}"
assert '    _npc_read_error = ""' in npc
assert '"СЕРВЕР NPC · " + _npc_read_error' in npc
assert '"NPC · " + _npc_read_error' in npc
assert 'if not visible or requested != service:' in npc, "No stale NPC screen writes"
assert '"Authorization: Bearer " + bearer' in bridge
assert '"/api/game/npc/" + service' in bridge
assert 'data.get("actionsEnabled", true) != false' in bridge
assert 'str(response.get("ownerId", "")) != owner_at_request' in bridge
assert 'var _player_save_readonly: Dictionary = {}' in npc
assert '_merchant_products()' in npc
assert 'SHOP.MERCHANT' in npc
print("PPA_NPC_CLIENT_CONNECTION_DIAGNOSTIC_OK all_services=1 owner_guard=1 no_local_spend=1 error_visible=1 stale_room_ignored=1")
