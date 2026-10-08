extends SceneTree

const HERO_CATALOG = preload("res://scripts/test_hero_catalog.gd")
const NPC_CATALOG = preload("res://scripts/test_city_npcs.gd")
const RIG_FIT = preload("res://scripts/dwarf_model_fit.gd")
const ORIGINAL_SHOPS = preload("res://scripts/test_shop_catalog.gd")

func _initialize() -> void:
    var checked := 0
    for hero in HERO_CATALOG.CLASSES:
        var path := str(hero.get("model", ""))
        var resource = load(path)
        if not (resource is PackedScene):
            push_error("[PPA-HERO-AUDIT] Not an imported GLB: " + path)
            quit(1)
            return
        var model := (resource as PackedScene).instantiate() as Node3D
        if model == null:
            push_error("[PPA-HERO-AUDIT] Model root not Node3D: " + path)
            quit(1)
            return
        root.add_child(model)
        var bones = model.find_children("*", "Skeleton3D", true, false)
        var meshes = model.find_children("*", "MeshInstance3D", true, false)
        var players = model.find_children("*", "AnimationPlayer", true, false)
        var clips: Array[String] = []
        for candidate in players:
            var player := candidate as AnimationPlayer
            if player != null:
                for animation_name in player.get_animation_list():
                    clips.append(str(animation_name).to_lower())
        if bones.is_empty() or meshes.size() < 2:
            push_error("[PPA-HERO-AUDIT] Missing skinned mesh / skeleton: " + path)
            quit(1)
            return
        if not clips.has("idle") or not clips.has("run") or not clips.has("attack"):
            push_error("[PPA-HERO-AUDIT] Missing class clips: " + path + " " + str(clips))
            quit(1)
            return
        var height := float(hero.get("height", 2.25))
        if not RIG_FIT.fit(model, height):
            push_error("[PPA-HERO-AUDIT] Failed to normalize class " + path)
            quit(1)
            return
        var rest := RIG_FIT.rest_bone_bounds(model)
        # The rest bounds have to remain usable as a numeric rig invariant.
        if rest.size.y < 0.001 or not rest.size.is_finite():
            push_error("[PPA-HERO-AUDIT] Invalid skeleton bounds " + path)
            quit(1)
            return
        if str(hero.get("key", "")) == "paladin":
            var sword = model.find_child("Dawnblade", true, false)
            if sword == null:
                push_error("[PPA-PALADIN] Imported character is missing Dawnblade")
                quit(1)
                return
            print("PPA_PALADIN_SWORD_IMPORTED name=", sword.name, " attachment=", sword.get_parent().name)
        print("PPA_HERO_IMPORT_OK ", hero.get("key"), " meshes=", meshes.size(), " bones=", bones.size(), " clips=", clips)
        model.free()
        checked += 1

    var nc := 0
    for npc in NPC_CATALOG.NPCS:
        var sprite := load(str(npc.get("image", ""))) as Texture2D
        if sprite == null or sprite.get_width() < 16 or sprite.get_height() < 16:
            push_error("[PPA-NPC-AUDIT] Missing 2D art " + str(npc.get("id", "")))
            quit(1)
            return
        print("PPA_NPC_IMPORT_OK ", npc.get("id"), " size=", sprite.get_size())
        nc += 1
    if ORIGINAL_SHOPS.MERCHANT.size() != 12:
        push_error("[PPA-MERCHANT] Canonical source must have twelve products")
        quit(1)
        return
    for p in ORIGINAL_SHOPS.MERCHANT:
        var icon_path := str(p.get("img", ""))
        var icon := load(icon_path) as Texture2D
        if icon == null or icon.get_width() < 8 or icon.get_height() < 8:
            push_error("[PPA-MERCHANT] Missing original store icon " + str(p.get("id")))
            quit(1)
            return
    print("PPA_CANONICAL_MERCHANT_ICONS_OK count=12")
    if checked != 8 or nc != 9:
        push_error("[PPA-TEST] Unexpected hero/NPC counts")
        quit(1)
        return
    print("PPA_ALL_TEST_ASSETS_OK heroes=", checked, " npcs=", nc)
    quit(0)
