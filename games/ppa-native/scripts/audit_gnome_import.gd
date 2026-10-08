extends SceneTree

# Prevent publishing a successful APK without the actual playable dwarf model.
func _initialize() -> void:
    var resource = load("res://assets/Dwarf.glb")
    if not (resource is PackedScene):
        push_error("PPA DWARF TEST: GLB is not an imported scene")
        quit(1)
        return
    var character = (resource as PackedScene).instantiate()
    if character == null:
        push_error("PPA DWARF TEST: scene instantiation failed")
        quit(1)
        return
    root.add_child(character)
    var meshes := character.find_children("*", "MeshInstance3D", true, false)
    var players := character.find_children("*", "AnimationPlayer", true, false)
    var names: Array[String] = []
    for entry in players:
        var player := entry as AnimationPlayer
        for clip in player.get_animation_list():
            names.append(str(clip).to_lower())
            print("IMPORTED_GNOME_CLIP=", str(clip))
    print("IMPORTED_GNOME_MESHES=", meshes.size(), " ANIM_PLAYERS=", players.size())
    if meshes.size() < 2 or names.find("idle") < 0 or names.find("run") < 0 or names.find("attack") < 0:
        push_error("PPA DWARF TEST: mesh/animation imports invalid: " + str(names))
        quit(1)
        return
    print("PPA_DWARF_IMPORT_OK")
    quit(0)
