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

static func fit(model: Node3D, target_body_height: float) -> bool:
    var bounds := rest_bone_bounds(model)
    var body_height := bounds.size.y
    if body_height < 0.001 or body_height > 100.0 or target_body_height <= 0.0:
        push_error("[PPA-DWARF] Missing/invalid skeletal rest bounds: " + str(bounds))
        return false

    var factor := target_body_height / body_height
    var center_x := bounds.position.x + bounds.size.x * 0.5
    var center_z := bounds.position.z + bounds.size.z * 0.5

    model.scale = Vector3.ONE * factor
    model.position = Vector3(-center_x * factor, -bounds.position.y * factor, -center_z * factor)

    print("[PPA-DWARF] Skeleton height=", body_height,
        " uniform root scale=", factor,
        " display body height=", target_body_height,
        " bone feet y=", bounds.position.y,
        " cannon remains hand-attached")
    return true
