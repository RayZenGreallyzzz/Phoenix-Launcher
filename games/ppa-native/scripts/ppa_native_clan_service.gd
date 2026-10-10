extends "res://scripts/ppa_native_command_service.gd"

const ACTIONS := ["create", "apply", "leaveClan", "acceptApplication", "rejectApplication",
    "kickMember", "transferLeadership", "setPermissions", "setAuthority", "upgradeBonus"]

func _init() -> void:
    service_key = "clan"
    contract_key = "ppa-clan-v1"
    supported_actions = ACTIONS.duplicate()

func _valid_state(state: Dictionary) -> bool:
    return super._valid_state(state) and state.get("members") is Array
