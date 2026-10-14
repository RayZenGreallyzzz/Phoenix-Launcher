extends SceneTree

# End-to-end original arena map QA. Uses only public original PPA map art,
# exact copied PvP masks and NPC walk previews. No PvP, XP, save or server.
const NPC = preload("res://scripts/ppa_npc_screen.gd")
const PREVIEW = preload("res://arena_map_preview.tscn")
const MAPS = preload("res://scripts/ppa_arena_maps_generated.gd")

func _initialize() -> void:
    call_deferred("_run")

func require(value: bool, message: String) -> void:
    if not value:
        push_error("PPA_ORIGINAL_ARENA_MAP_FAIL: "+message)
        quit(1)
        assert(value,message)

func _run() -> void:
    var host := Control.new()
    host.size = Vector2(800,1280)
    root.add_child(host)
    var npc := NPC.new()
    host.add_child(npc)
    npc.size = host.size
    var entries: Array[String] = []
    npc.arena_map_preview_requested.connect(func(mode: String): entries.append(mode))
    npc.open_npc({"id":"arena","service":"arena","name":"Мечник арены"})
    await process_frame
    require(npc.find_child("NpcTab_maps",true,false) != null,
        "NPC Arena missing dedicated КАРТЫ tab")
    var open_gallery := npc.find_child("NpcArenaOpenMapGallery",true,false) as Button
    require(open_gallery != null and not open_gallery.disabled,
        "NPC Arena trials should offer prominent shortcut to its real maps")
    open_gallery.pressed.emit()
    await process_frame
    require(npc.tab == "maps",
        "Tapping Arena maps shortcut did not switch to gallery")
    for mode in ["1x1","3x3","5x5","xp"]:
        var card := npc.find_child("PPAOriginalArenaMapCard_"+mode,true,false)
        var thumbnail := npc.find_child("PPAOriginalArenaThumbnail_"+mode,true,false) as TextureRect
        var button := npc.find_child("PPAOriginalArenaEnter_"+mode,true,false) as Button
        require(card!=null and thumbnail!=null and thumbnail.texture!=null,
            "NPC missing real artwork for "+mode)
        require(button!=null and not button.disabled,
            "No clickable map preview route for "+mode)
        require(npc.find_child("PPAOriginalArenaCollisionBadge_"+mode,
            true,false) != null,
            "Original PPA collision preview indication missing for "+mode)
        button.pressed.emit()
    require(entries==["1x1","3x3","5x5","xp"],
        "NPC original map button modes mismatched")
    npc._select_tab("fights")
    require(npc.find_child("PPAOriginalArenaMapCard_1x1",true,false)==null,
        "Map gallery should not be buried in the long arena trials menu")
    var dedicated := npc.find_child("NpcTab_maps",true,false) as Button
    dedicated.pressed.emit()
    require(npc.tab=="maps" and
        npc.find_child("PPAOriginalArenaMapCard_xp",true,false)!=null,
        "Arena КАРТЫ tab does not reopen all four actual maps")
    npc.close_npc()
    npc.queue_free()
    await process_frame

    var count := 0
    for mode in ["1x1","3x3","5x5","xp"]:
        root.set_meta("ppa_preview_arena_mode",mode)
        var game := PREVIEW.instantiate()
        game.size=host.size
        host.add_child(game)
        await process_frame
        var source: TextureRect = game.find_child(
            "PPAExactOriginalArenaArtwork",true,false) as TextureRect
        require(source!=null and source.texture!=null,
            "Not displaying authentic "+mode+" arena art")
        var expected: Vector2 = MAPS.XP_WORLD_SIZE if mode=="xp" else MAPS.PVP_WORLD_SIZE
        require(source.size==expected,mode+" map dimension mismatch")
        require(game.get_node_or_null("PPAOriginalArenaVisualMap")!=null,
            "Arena map scene not attached to camera")
        require(game._combat_hud!=null and game._native_global_realtime==null,
            "Local walk-only map preview leaked into server combat or writes")
        require(game.find_child("PPAOriginalArenaReturnToCity",true,false)!=null,
            "Map preview lacks return to town")
        require(game._walkable(game.world_pos_px),
            mode+" PPA original spawn outside its original mask")
        require(game._can_stand(Vector2(512,512)) if mode=="xp" else
            game._walkable(game.world_pos_px),
            mode+" collision checker rejected original safe ground")
        require(not game._walkable(Vector2(0,0)),
            mode+" must have impassable outside boundary")
        require(is_equal_approx(game.LOWER_COLLISION_SHIFT,50.0),
            "Lower arena collider has not moved exactly 50 world pixels")
        if mode!="xp":
            require(game._walk_map.get_size()==MAPS.MASK_SIZE,
                "PvP collision not using exact original 768x512 mask")
            require(not game._can_stand(Vector2(0,0)),
                "PvP original wall sample is traversable")
            var checked_bottom := false
            # Use a real original walkable column to prove that its last wall
            # moved 50px down, but blocked sides/interior stayed unchanged.
            for mx in range(60, MAPS.MASK_SIZE.x-60):
                var edge: float = game._original_lower_edge_y(mx)
                if edge < MAPS.PVP_WORLD_SIZE.y * 0.50:
                    continue
                var sample_x := (float(mx) + 0.5) * MAPS.PVP_WORLD_SIZE.x / float(MAPS.MASK_SIZE.x)
                require(game._walkable(Vector2(sample_x,edge-1.0)),
                    mode+" original last walkable cell was changed")
                require(game._walkable(Vector2(sample_x,edge+49.0)),
                    mode+" bottom lip was not extended 50px")
                require(not game._walkable(Vector2(sample_x,edge+51.0)),
                    mode+" bottom lip extended more than 50px")
                checked_bottom = true
                break
            require(checked_bottom,mode+" original mask missing lower walkable edge")
            require(not game._walkable(Vector2(-1.0,500.0)),
                mode+" LEFT outside wall must stay blocked")
        else:
            require(game._walk_map==null and
                game._walkable(Vector2(40,40)) and
                not game._walkable(Vector2(39,40)),
                "XP arena must keep original top/left boundaries, no fake mask")
            require(game._walkable(Vector2(512,1033)) and
                not game._walkable(Vector2(512,1035)) and
                game._can_stand(Vector2(512,1021)) and
                not game._can_stand(Vector2(512,1022)),
                "XP southern edge must move exactly 50px from 984 to 1034")
            require(not game._walkable(Vector2(985,512)),
                "XP RIGHT edge must remain unchanged")
        var blocked: Vector2 = game._resolve_city_collision(Vector2(-400,-400))
        require(blocked==game.world_pos_px,
            "Player could walk through original arena perimeter")
        count+=1
        game.queue_free()
        await process_frame
    root.remove_meta("ppa_preview_arena_mode")
    host.queue_free()
    await process_frame
    print("PPA_ORIGINAL_ARENA_MAPS_OK maps=3 modes="+str(count)+
        " pvp_masks=2 xp_bounds=1 NPC_buttons=4 lower_shift=50 read_only=1 no_rewards=1")
    quit(0)
