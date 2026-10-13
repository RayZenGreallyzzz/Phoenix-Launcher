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
    for mode in ["1x1","3x3","5x5","xp"]:
        var card := npc.find_child("PPAOriginalArenaMapCard_"+mode,true,false)
        var thumbnail := npc.find_child("PPAOriginalArenaThumbnail_"+mode,true,false) as TextureRect
        var button := npc.find_child("PPAOriginalArenaEnter_"+mode,true,false) as Button
        require(card!=null and thumbnail!=null and thumbnail.texture!=null,
            "NPC missing real artwork for "+mode)
        require(button!=null and not button.disabled,
            "No clickable map preview route for "+mode)
        button.pressed.emit()
    require(entries==["1x1","3x3","5x5","xp"],
        "NPC original map button modes mismatched")
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
        if mode!="xp":
            require(game._walk_map.get_size()==MAPS.MASK_SIZE,
                "PvP collision not using exact original 768x512 mask")
            require(not game._can_stand(Vector2(0,0)),
                "PvP original wall sample is traversable")
        else:
            require(game._walk_map==null and
                game._walkable(Vector2(40,40)) and
                not game._walkable(Vector2(39,40)),
                "XP arena must use exact 40px original boundaries, no fake mask")
        var blocked := game._resolve_city_collision(Vector2(-400,-400))
        require(blocked==game.world_pos_px,
            "Player could walk through original arena perimeter")
        count+=1
        game.queue_free()
        await process_frame
    root.remove_meta("ppa_preview_arena_mode")
    host.queue_free()
    await process_frame
    print("PPA_ORIGINAL_ARENA_MAPS_OK maps=3 modes="+str(count)+
        " pvp_masks=2 xp_bounds=1 NPC_buttons=4 read_only=1 no_rewards=1")
    quit(0)
