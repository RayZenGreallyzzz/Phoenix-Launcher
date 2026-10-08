extends RefCounted

# Canonical coordinates and art names from the currently deployed PPA
# SCENES.safe.npcs list. Source coords are in the 1254px original city image.
# Keep these stable even if class preview models are changed.
const NPCS = [
    {"id":"blacksmith","name":"КУЗНЕЦ","x":445.0,"y":304.0,"radius":74.0,"image":"res://assets/npc_blacksmith.png","height":112.0,"service":"forge"},
    {"id":"storage","name":"ХРАНИТЕЛЬ СКЛАДА","x":350.0,"y":304.0,"radius":70.0,"image":"res://assets/npc_storage.png","height":112.0,"service":"storage"},
    {"id":"auction","name":"АУКЦИОНИСТ","x":590.0,"y":304.0,"radius":72.0,"image":"res://assets/npc_auction.png","height":112.0,"service":"auction"},
    {"id":"arena","name":"МЕЧНИК АРЕНЫ","x":907.0,"y":304.0,"radius":72.0,"image":"res://assets/npc_arena.png","height":112.0,"service":"arena"},
    {"id":"clan","name":"МАГИСТР КЛАНОВ","x":967.0,"y":480.0,"radius":72.0,"image":"res://assets/npc_clan.png","height":112.0,"service":"clan"},
    {"id":"merchant","name":"ТОРГОВЕЦ","x":240.0,"y":304.0,"radius":72.0,"image":"res://assets/npc_merchant.png","height":112.0,"service":"merchant"},
    {"id":"blackmarket","name":"БЛЕК МАРКЕТ","x":707.0,"y":304.0,"radius":72.0,"image":"res://assets/npc_blackmarket.png","height":112.0,"service":"blackmarket"},
    {"id":"dungeon","name":"ХРАНИТЕЛЬ ПОДЗЕМЕЛЬЯ","x":590.0,"y":840.0,"radius":82.0,"image":"res://assets/npc_dungeon.png","height":126.0,"service":"dungeon"},
    {"id":"fartzone_guide","name":"ШАХТЁР ФАРТ ЗОНЫ","x":967.0,"y":590.0,"radius":78.0,"image":"res://assets/npc_fartzone_guide.png","height":90.0,"service":"fartzone"}
]

static func world_pos(npc: Dictionary, source_to_world: float) -> Vector2:
    return Vector2(roundf(float(npc.get("x", 0.0)) * source_to_world), roundf(float(npc.get("y", 0.0)) * source_to_world))
