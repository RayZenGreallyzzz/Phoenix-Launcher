extends SceneTree

const DWARF_FIT = preload("res://scripts/dwarf_model_fit.gd")

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
    var dwarf_root := character as Node3D
    if dwarf_root == null:
        push_error("PPA DWARF TEST: imported root must be Node3D")
        quit(1)
        return
    var rest := DWARF_FIT.rest_bone_bounds(dwarf_root)
    if rest.size.y < 0.001 or rest.size.y > 100.0:
        push_error("PPA DWARF TEST: invalid skeleton body height: " + str(rest))
        quit(1)
        return
    if not DWARF_FIT.fit(dwarf_root, 1.90):
        push_error("PPA DWARF TEST: normalization failed")
        quit(1)
        return
    var fitted_body_height := rest.size.y * dwarf_root.scale.y
    var foot_ground_y := rest.position.y * dwarf_root.scale.y + dwarf_root.position.y
    if absf(fitted_body_height - 1.90) > 0.03 or absf(foot_ground_y) > 0.03:
        push_error("PPA DWARF TEST: invalid fitted height or foot position " +
            str(fitted_body_height) + " ground " + str(foot_ground_y))
        quit(1)
        return
    print("PPA_DWARF_GEOMETRY_OK body_m=", fitted_body_height, " feet_y=", foot_ground_y)
    print("PPA_DWARF_IMPORT_OK")
    quit(0)
