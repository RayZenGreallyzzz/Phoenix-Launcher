extends RefCounted

# Normalize the PPA dwarf from its actual bind skeleton, NOT from Mesh AABBs.
# A skinned mesh's static vertex AABB can be tiny; the cannon used to be very
# far from the skeleton due to an exporter unit mismatch. Both cases make
# AABB-based fit useless. Rest bones are authoritative for body proportions.
#
# Fits the imported scene ROOT: the entire body + cannon get one uniform scale.
# The feet are placed on y=0 with no model-part stretching.
static func rest_bone_bounds(model: Node3D) -> AABB:
    var skeletons := model.find_children("*", "Skeleton3D", true, false)
    var minimum := Vector3(INF, INF, INF)
    var maximum := Vector3(-INF, -INF, -INF)
    var found := false
    var model_inverse: Transform3D = model.global_transform.affine_inverse()

    for element in skeletons:
        var skeleton := element as Skeleton3D
        if skeleton == null:
            continue
        var relative: Transform3D = model_inverse * skeleton.global_transform
        for bone_id in range(skeleton.get_bone_count()):
            var rest_position: Vector3 = relative * skeleton.get_bone_global_rest(bone_id).origin
            if not rest_position.is_finite():
                continue
            minimum = minimum.min(rest_position)
            maximum = maximum.max(rest_position)
            found = true

    if not found:
        return AABB()
    return AABB(minimum, maximum - minimum)

# The lowest REST bone is not necessarily the character's foot: long
# accessories/weapon helper bones may extend below the actual boots. Place
# the visible lower foot/toe bones on the world ground, not the skeleton's
# all-bones AABB floor. The resting model stays at one uniform scale.
static func rest_foot_floor(model: Node3D, all_bone_bounds: AABB) -> float:
    var skeletons := model.find_children("*", "Skeleton3D", true, false)
    var inverse: Transform3D = model.global_transform.affine_inverse()
    var foot_floor := INF
    var feet_found := 0
    for item in skeletons:
        var skeleton := item as Skeleton3D
        if skeleton == null:
            continue
        var relative := inverse * skeleton.global_transform
        for bone_id in range(skeleton.get_bone_count()):
            var bone_name := skeleton.get_bone_name(bone_id).to_lower()
            if not (bone_name.contains("foot") or bone_name.contains("toe") or bone_name.contains("ankle")):
                continue
            if bone_name.contains("ik") or bone_name.contains("pole") or bone_name.contains("target") or bone_name.contains("ctrl"):
                continue
            var foot: Vector3 = relative * skeleton.get_bone_global_rest(bone_id).origin
            if foot.is_finite():
                foot_floor = minf(foot_floor, foot.y)
                feet_found += 1
    # Reject implausible helper bone coordinates; fall back to legacy
    # bounds instead of moving a malformed rig underground.
    var min_y := all_bone_bounds.position.y
    if feet_found == 0 or foot_floor < min_y - 0.01 or foot_floor > min_y + all_bone_bounds.size.y * 0.30:
        return min_y
    return foot_floor

static func fit(model: Node3D, target_body_height: float) -> bool:
    var bounds := rest_bone_bounds(model)
    var body_height := bounds.size.y
    if body_height < 0.001 or body_height > 100.0 or target_body_height <= 0.0:
        push_error("[PPA-DWARF] Missing/invalid skeletal rest bounds: " + str(bounds))
        return false

    var factor := target_body_height / body_height
    var center_x := bounds.position.x + bounds.size.x * 0.5
    var center_z := bounds.position.z + bounds.size.z * 0.5
    var foot_floor := rest_foot_floor(model, bounds)

    model.scale = Vector3.ONE * factor
    model.position = Vector3(-center_x * factor, -foot_floor * factor, -center_z * factor)

    print("[PPA-DWARF] Skeleton height=", body_height,
        " uniform root scale=", factor,
        " display body height=", target_body_height,
        " all bones min y=", bounds.position.y, " rest-foot min y=", foot_floor,
        " cannon remains hand-attached")
    return true
