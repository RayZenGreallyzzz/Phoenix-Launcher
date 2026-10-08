extends Node2D

# INTENTIONALLY EMPTY. The temporary/ancient PPA monster and boss textures
# are explicitly retired from Godot TEST. Never revive these image lookups.
# Keep this typed test-node endpoint only until the never-shipped approved
# dungeon enemy artwork is sourced and mapped to correct levels.
func setup(_source_id: int, _level: int, _boss: bool, _boss_id: String = "") -> void:
    push_error("PPA_LEGACY_ENEMY_ART_REJECTED: provide approved new dungeon art")
    visible = false

func set_aggro(_active: bool) -> void:
    pass

func set_attack(_active: bool) -> void:
    pass
