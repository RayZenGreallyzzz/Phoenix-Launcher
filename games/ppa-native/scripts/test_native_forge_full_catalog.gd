extends SceneTree

# All current original Telegram PPA recipes must be displayed by the SAME
# Godot PPA NPC and accepted only under matching signed server cost/stock.
# No real accounts, network, inventory or database transactions.
const NPC = preload("res://scripts/ppa_npc_screen.gd")
const CATALOG = preload("res://scripts/ppa_forge_catalog_generated.gd")
const OWNER := "990000001"

func _initialize() -> void:
    call_deferred("_run")

func check(condition: bool, message: String) -> void:
    if not condition:
        push_error("PPA_FORGE_FULL_CATALOG_FAIL: " + message)
        quit(1)
        assert(condition,message)

func _run() -> void:
    set_meta("phoenix_account", {"telegramId":OWNER})
    remove_meta("ppa_native_game_session")
    var rows: Array = CATALOG.CATALOG.get("rows", [])
    check(rows.size() == 58, "Expected all 58 original Telegram smith recipes")
    var stats := {}
    var totals := {}
    var tabs := {}
    for raw in rows:
        var r: Dictionary = raw
        var id := str(r.get("id", ""))
        var tab := str(r.get("tab", ""))
        check(not id.is_empty() and tab in ["equipment","legendary","accessories","pets"],
            "Unknown original smith recipe: " + id)
        stats[id] = true
        tabs[tab] = int(tabs.get(tab,0)) + 1
        for ingredient in r.get("materials",[]):
            if ingredient is Dictionary and str(ingredient.get("name","")) != "Перо Феникса":
                totals[str(ingredient.get("name",""))] = 1000000
    check(stats.size() == 58 and tabs.get("legendary") == 11 and
        tabs.get("accessories") == 16 and tabs.get("pets") == 24,
        "Legendary/accessory/pet recipes are missing")
    var host := Control.new()
    root.add_child(host)
    host.size = Vector2(1280,720)
    var npc := NPC.new()
    host.add_child(npc)
    var issued: Array = []
    npc.forge_action_requested.connect(func(fields: Dictionary):
        issued.append(fields.duplicate(true)))
    var count := 0
    for raw in rows:
        var r: Dictionary = raw
        var quote := {"ok":true,"gameId":"phoenix-pix-arena",
            "contract":"ppa-forge-v1","ownerId":OWNER,
            "actions":["craft"],"state":{"connected":true,"self":{"id":OWNER},
                "version":12,"catalogRecipeSha":str(CATALOG.CATALOG.get("recipe_sha256","")),
                "wallet":{"ppa":1000000},"materials":totals,"feathers":{"phoenix":100},
                "offers":[{"id":r["id"],"price":r["price"],"currency":"ppa",
                    "materials":r["materials"]}]}}
        npc.open_npc({"service":"forge","name":"Кузнец"})
        npc._select_tab(str(r["tab"]))
        npc._select_item(str(r["id"]))
        check(npc._body.find_child("PPARealForgeCraft",true,false) == null,
            "Reference-only recipe can craft before signed offer " + str(r["id"]))
        npc.apply_native_forge(quote)
        var button := npc._body.find_child("PPARealForgeCraft",true,false) as Button
        check(button != null and not button.disabled,
            "Server-verified original smith recipe unavailable " + str(r["id"]))
        button.pressed.emit()
        check(issued.size()==count+1 and str(issued.back().get("id",""))==str(r["id"])
            and int(issued.back().get("version",0))==12,
            "Wrong recipe ID/version sent to common server")
        check(npc.forge_state["wallet"]["ppa"] == 1000000,
            "Godot changed shared wallet without server acknowledgement")
        npc.close_npc()
        check(npc.forge_actions.is_empty(),
            "Craft permission leaked between NPC sessions")
        count+=1
    var mismatched := {"ok":true,"gameId":"phoenix-pix-arena",
        "contract":"ppa-forge-v1","ownerId":OWNER,"actions":["craft"],
        "state":{"connected":true,"self":{"id":OWNER},"version":13,
            "catalogRecipeSha":"wrong-economic-rules",
            "wallet":{"ppa":1000000},"materials":totals,"feathers":{"phoenix":100},
            "offers":[{"id":rows[0]["id"],"price":rows[0]["price"],
                "currency":"ppa","materials":rows[0]["materials"]}]}}
    npc.open_npc({"service":"forge","name":"Кузнец"})
    npc._select_tab(str(rows[0]["tab"]))
    npc._select_item(str(rows[0]["id"]))
    npc.apply_native_forge(mismatched)
    check(npc._body.find_child("PPARealForgeCraft",true,false)==null,
        "Mismatched server economy enables crafting")
    host.queue_free()
    await process_frame
    print("PPA_ORIGINAL_GODOT_FORGE_ALL_OK recipes="+str(count)+
        " legendary=11 accessories=16 pets=24 same_wallet=1")
    quit()
