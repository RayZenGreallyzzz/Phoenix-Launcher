extends "res://scripts/ppa_native_command_service.gd"

# Offline-only probe: never reaches live Cloudflare after a signed receipt.
var refresh_count := 0

func request_state() -> void:
    refresh_count += 1
