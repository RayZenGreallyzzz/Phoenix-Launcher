extends "res://scripts/ppa_native_command_service.gd"

# One original clan_meta.storage_json, not a duplicate Godot clan container.
# /api/game/storage/clan/state includes rights, save version and clanRevision.
func _init() -> void:
    service_key = "storage/clan"
    contract_key = "ppa-clan-storage-v1"
    supported_actions = ["put", "take"]

func _valid_state(state: Dictionary) -> bool:
    return super._valid_state(state) and state.get("bag") is Array \
        and state.get("items") is Array \
        and state.get("clanRevision") is String \
        and str(state.get("clanRevision", "")).length() == 64 \
        and int(state.get("version", 0)) > 0
