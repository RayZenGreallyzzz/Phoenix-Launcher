extends "res://scripts/ppa_native_command_service.gd"

# ONLY real original Telegram PPA auction tables. No unsafe trade commands
# until original Telegram and native settlements share one D1 transaction.
func _init() -> void:
    service_key = "auction"
    contract_key = "ppa-auction-v1"
    supported_actions = ["place", "buy", "cancel", "recover", "claim"]

func _valid_state(state: Dictionary) -> bool:
    return super._valid_state(state) and state.get("lots") is Array \
        and state.get("mine") is Array and state.get("recoverable") is Array \
        and state.get("pendingCredits") is Array \
        and state.get("wallet") is Dictionary \
        and int(state.get("version", 0)) > 0 \
        and state.get("settlementEnabled") is bool
