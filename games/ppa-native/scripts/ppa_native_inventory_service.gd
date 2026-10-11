extends "res://scripts/ppa_native_command_service.gd"

# Original PPA bag/equipped from the SAME account-bound save as Telegram.
# Never mutate Godot local inventory or select gear by a recycled array index.
func _init() -> void:
    service_key = "inventory"
    contract_key = "ppa-inventory-v1"
    supported_actions = ["equip", "unequip"]

func _valid_state(state: Dictionary) -> bool:
    return super._valid_state(state) and state.get("bag") is Array \
        and state.get("equipped") is Dictionary and int(state.get("version", 0)) > 0
