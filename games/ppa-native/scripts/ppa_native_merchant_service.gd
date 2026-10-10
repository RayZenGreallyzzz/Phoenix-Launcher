extends "res://scripts/ppa_native_command_service.gd"

func _init() -> void:
    service_key = "merchant"
    contract_key = "ppa-merchant-v1"
    supported_actions = ["buy"]

func _valid_state(state: Dictionary) -> bool:
    return super._valid_state(state) and state.get("offers") is Array \
        and state.get("wallet") is Dictionary and int(state.get("version", 0)) > 0
