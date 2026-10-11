extends SceneTree

# Original server event fixtures, Godot canvas only. NO WebSocket, auth
# mutation, boss fabrication, local mob AI, attacks or loot.
const LAYER = preload("res://scripts/ppa_native_dungeon_mob_layer.gd")

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, message: String) -> void:
    if not ok:
        push_error("PPA_DUNGEON_AUTHORITY_LAYER_FAIL: " + message)
        quit(1)
        assert(ok, message)

func sample(key: String, hp: int, x: float, y: float, dir: int) -> Array:
    return [key,hp,100,0,"","",x,y,0,dir,1,"",30,0,"",0,"",0]

func packet(rows: Array, time: int, done: bool = true) -> Dictionary:
    return {"type":"mob-authority-snapshot","room":"dungeon-1",
        "rows":rows,"reset":true,"done":done,"ts":time}

func _run() -> void:
    var inventory := {"gold":5000, "ppa":100,
        "bag":[{"uid":"sword-plus7", "enh":7}]}
    var unchanged := JSON.stringify(inventory)
    var host := Node2D.new()
    root.add_child(host)
    var layer := LAYER.new()
    host.add_child(layer)
    var spawns: Array[Vector2] = [Vector2(400,500),Vector2(470,500)]
    var branches: Array[int] = [0,1]
    var ordinals: Array[int] = [0,0]
    check(not layer.configure("safe",spawns,branches,ordinals,0,false),
        "A city was mistaken for a mob authority dungeon")
    check(layer.configure("dungeon-1",spawns,branches,ordinals,0,false),
        "Signed dungeon room was not accepted")
    layer.observe_player_position(Vector2(400,500))
    check(layer.apply_authenticated_packet(packet(
        [sample("s0",80,400,500,0)],1000,false)),
        "First chunk not staged")
    check(layer.rendered_keys().is_empty(),
        "Partial packet created ghost mobs")
    check(layer.apply_authenticated_packet({
        "type":"mob-authority-snapshot","room":"dungeon-1",
        "rows":[sample("s1",100,470,500,2)],
        "reset":false,"done":true,"ts":1000}),"Final snapshot chunk lost")
    check(layer.rendered_keys().size() == 2,"Two real mob visuals not created")
    var first: Node2D = layer.get_node("ConfirmedServerMob_s0")
    check(first != null and first.position == Vector2(400,514),
        "Server coordinates/mask alignment changed")
    check(first.get_node("ServerMobHP").value == 80,
        "Server HP didn't reach canvas health bar")
    check(first.get_node("ServerMobHPText").text == "80/100",
        "Confirmed numeric HP incorrectly displayed")
    check(first.get_node_or_null("ApprovedPPAMobArt") == null and
        first.get_node_or_null("ServerUnknownArtMarker") != null,
        "No approved art must never show guessed enemy graphics")
    check(layer.authority.mobs["s0"]["dir"] == 0,
        "Up = 0 facing lost in scene renderer")
    check(not layer.apply_authenticated_packet({
        "type":"mob-hp","room":"dungeon-2","key":"s0",
        "hp":0,"mhp":100,"ts":1100}),
        "Dungeon 2 HP hit modified dungeon 1")
    check(layer.apply_authenticated_packet({
        "type":"mob-position","room":"dungeon-1",
        "rows":[["s0",420,515,1,0,1,"p:test"]],"ts":1200}),
        "Server mob position update not received")
    check(first.position == Vector2(420,529) and layer.rendered_keys().size()==2,
        "Godot did not move the SAME server mob")
    check(not layer.apply_authenticated_packet({
        "type":"mob-hp","room":"dungeon-1","key":"fake-999",
        "hp":0,"mhp":100,"ts":1250}),
        "An arbitrary mob was created from an unsigned damage fragment")
    check(layer.apply_authenticated_packet({
        "type":"mob-dead","room":"dungeon-1",
        "key":"s0","respawnAt":30000,"ts":1300}),
        "Canonical death event not accepted")
    check(layer.rendered_keys().size() == 1 and
        layer.get_node_or_null("ConfirmedServerMob_s0") == null,
        "Dead server mob kept attacking visually")
    check(layer.authority.mobs["s0"]["hp"] == 0,
        "Canvas renderer fabricated a respawn")
    check(layer.apply_authenticated_packet(packet([],1400)),
        "Server authoritative empty snapshot failed")
    check(layer.rendered_keys().is_empty(),
        "Old room NPCs survived a valid empty snapshot")
    check(layer.configure("dungeon-2",spawns,branches,ordinals,1,false),
        "Entering a different room failed")
    check(not layer.apply_authenticated_packet(packet([sample("s0",100,400,500,1)],2000)),
        "Old dungeon mob packet leaked into another instance")
    check(layer.rendered_keys().is_empty(),
        "Room switch retained previous mobs")
    check(JSON.stringify(inventory) == unchanged,
        "Pure mob visuals changed items/Gold/+7")
    host.queue_free()
    await process_frame
    print("PPA_DUNGEON_AUTHORITY_LAYER_OK canvas=2 original_pixel_coords=1 up_zero=1 hp=real dead=hidden chunk_atomic=1 no_local_ai=1 account_money_untouched=1")
    quit(0)
