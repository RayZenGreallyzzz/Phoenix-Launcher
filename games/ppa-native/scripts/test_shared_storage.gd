extends RefCounted

# All eight temporary preview classes use one PRIVATE LOCAL TEST STASH.
# Never access PPA /api/save or its player profile, inventory and warehouse.
# Data lives under the PhoenixPixArena Android private user:// directory.
const MAX_ITEMS := 64
var account_key: String = ""
var bag: Array = []
var warehouse: Array = []

func _init(account: Dictionary = {}) -> void:
    var identity := str(account.get("accountId", "")).strip_edges()
    if identity.is_empty():
        identity = str(account.get("telegramId", "")).strip_edges()
    if identity.is_empty():
        identity = "local_debug"
    account_key = identity.sha256_text().substr(0, 24)
    load_test_data()

func _path() -> String:
    return "user://ppa_native_shared_test_" + account_key + ".json"

func load_test_data() -> void:
    bag = []
    warehouse = []
    if FileAccess.file_exists(_path()):
        var f := FileAccess.open(_path(), FileAccess.READ)
        if f != null:
            var loaded = JSON.parse_string(f.get_as_text())
            if typeof(loaded) == TYPE_DICTIONARY:
                if typeof(loaded.get("bag")) == TYPE_ARRAY:
                    bag = _filter(loaded.get("bag", []))
                if typeof(loaded.get("warehouse")) == TYPE_ARRAY:
                    warehouse = _filter(loaded.get("warehouse", []))
                return
    # Clearly labelled TEST samples, not real PPA equipment or rewards.
    bag = [
        {"id":"test_hp","name":"Учебное зелье HP","qty":20},
        {"id":"test_mp","name":"Учебное зелье MP","qty":20},
        {"id":"test_rune","name":"Учебная руна","qty":3},
        {"id":"test_gear","name":"Тестовая экипировка","qty":1}
    ]
    warehouse = []
    _save()

func _filter(items: Array) -> Array:
    var result: Array = []
    for raw in items:
        if result.size() >= MAX_ITEMS:
            break
        if typeof(raw) != TYPE_DICTIONARY:
            continue
        var item: Dictionary = raw
        var item_id := str(item.get("id", ""))
        var title := str(item.get("name", ""))
        if item_id.length() > 0 and item_id.length() < 80 and title.length() > 0 and title.length() < 128:
            result.append({"id": item_id,"name":title,"qty":clampi(int(item.get("qty", 1)),1,999)})
    return result

func move(source_name: String, index: int) -> bool:
    var from: Array = bag if source_name == "bag" else warehouse
    var into: Array = warehouse if source_name == "bag" else bag
    if index < 0 or index >= from.size() or into.size() >= MAX_ITEMS:
        return false
    into.append(from[index])
    from.remove_at(index)
    _save()
    return true

func _save() -> void:
    var file := FileAccess.open(_path(), FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify({"schema":1,"bag":bag,"warehouse":warehouse}))
