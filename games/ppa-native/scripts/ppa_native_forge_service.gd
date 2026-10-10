extends "res://scripts/ppa_native_command_service.gd"

# One server-owned crafting operation on the SAME Telegram PPA save.
# Only authenticated, versioned receipts may update the native menu.
func _init() -> void:
    service_key = "forge"
    contract_key = "ppa-forge-v1"
    supported_actions = ["craft", "enhance"]

func _valid_state(state: Dictionary) -> bool:
    return super._valid_state(state) and state.get("offers") is Array \
        and state.get("wallet") is Dictionary and int(state.get("version", 0)) > 0
