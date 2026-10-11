extends "res://scripts/ppa_native_command_service.gd"

# One original Telegram PPA personal storage; never replicate bag or forge gear.
func _init() -> void:
    service_key = "storage/personal"
    contract_key = "ppa-personal-storage-v1"
    supported_actions = ["put", "take"]

# Return only signed, versioned original PPA bag and private store state.
func _valid_state(state: Dictionary) -> bool:
    return super._valid_state(state) and state.get("bag") is Array \
        and state.get("personal") is Array and int(state.get("version", 0)) > 0
