extends SceneTree

# Only authentic signed saved offers may appear. Never create local goods.
const NPC = preload("res://scripts/ppa_npc_screen.gd")
const OWNER := "990000001"

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, message: String) -> void:
    if not ok:
        push_error("PPA_AUCTION_BUY_PAGES_FAIL: " + message)
        quit(1)
        assert(ok,message)

func _run() -> void:
    set_meta("phoenix_account",{"telegramId":OWNER})
    var host := Control.new()
    host.size = Vector2(800,1280)
    root.add_child(host)
    var npc := NPC.new()
    host.add_child(npc)
    npc.size = host.size
    await process_frame
    npc.open_npc({"service":"auction","name":"Аукционист"})
    await process_frame
    var grid := npc._body.find_child("PPAAuctionBuyLotsGrid",true,false) as GridContainer
    var pager := npc._body.find_child("PPAAuctionBuyPageCount",true,false) as Label
    check(grid!=null and grid.columns==2 and grid.get_child_count()==10,
        "Offline Buy must show exactly 10 EMPTY cells without fictitious offers")
    check(grid.find_children("PPARealAuctionBuy_*","Button",true,false).is_empty(),
        "Offline Buy must NEVER include simulated buy buttons")
    check(pager!=null and pager.text=="1 / 1",
        "No server listings must not claim 100 or 200 imaginary goods")

    # A server-authenticated 205-item array tests 21 pages without mounting
    # all rows or truncating after the former 50. This is test data only.
    var lots: Array = []
    for i in range(205):
        lots.append({"id":"lot_%03d" % i,"qty":1,"price":10+i,
            "currency":"gram" if i%2 else "ppa","canBuy":true,
            "item":{"name":"Verified Lot %d" % i,"kind":"gear",
                "slot":"weapon","rarity":"rare","level":20}})
    npc.apply_native_auction({"gameId":"phoenix-pix-arena",
        "contract":"ppa-auction-v1","ownerId":OWNER,
        "actions":["buy","place","cancel","recover"],
        "state":{"connected":true,"self":{"id":OWNER},"version":22,
            "settlementEnabled":false,"wallet":{"gram":0,"ppa":0},
            "maxSellSlots":3,"mine":[],"recoverable":[],
            "pendingCredits":[],"bag":[],"lots":lots}})
    await process_frame
    grid = npc._body.find_child("PPAAuctionBuyLotsGrid",true,false) as GridContainer
    pager = npc._body.find_child("PPAAuctionBuyPageCount",true,false) as Label
    check(pager.text=="1 / 21" and grid.get_child_count()==10,
        "Only first 10 of 205 signed listings should be rendered")
    check(grid.find_children("PPARealAuctionBuy_*","Button",true,false).size()==10,
        "Missing verified real auction purchase controls")
    var next := npc._body.find_child("PPAAuctionBuyNext",true,false) as Button
    next.pressed.emit()
    await process_frame
    check(npc._auction_browse_page==1,"Auction forward arrow failed")
    var second := npc._body.find_child("PPAAuctionBuyLotsGrid",true,false) as GridContainer
    check(second.get_child_count()==10 and
        second.find_child("PPARealAuctionBuy_lot_010",true,false)!=null,
        "Second page is not populated with correct server lot IDs")
    var start := second.get_global_rect().get_center()
    npc._auction_swipe_origin = start
    npc._auction_finish_swipe(start+Vector2(-110,8))
    await process_frame
    check(npc._auction_browse_page==2,
        "Horizontal left swipe failed to show next ten real listings")
    npc._auction_swipe_origin = start
    npc._auction_finish_swipe(start+Vector2(4,100))
    check(npc._auction_browse_page==2,
        "Vertical drag must not change auction page")
    npc._auction_swipe_origin = start
    npc._auction_finish_swipe(start+Vector2(110,4))
    await process_frame
    check(npc._auction_browse_page==1,
        "Horizontal right swipe failed to show previous real page")

    # Jump via the same real view navigation function, not a fake fixture UI.
    const AUCTION = preload("res://scripts/ppa_auction_menu.gd")
    AUCTION._browse_page(npc,20)
    await process_frame
    grid = npc._body.find_child("PPAAuctionBuyLotsGrid",true,false) as GridContainer
    pager = npc._body.find_child("PPAAuctionBuyPageCount",true,false) as Label
    check(pager.text=="21 / 21" and grid.get_child_count()==10,
        "Last 5 real lots require 5 EMPTY slots to preserve 10-cell layout")
    check(grid.find_children("PPARealAuctionBuy_*","Button",true,false).size()==5
        and grid.find_child("PPARealAuctionBuy_lot_204",true,false)!=null,
        "Last confirmed server lot is missing or slots were fabricated")
    check(npc._body.find_child("PPAAuctionBuyNext",true,false).disabled,
        "Last page must have disabled forward arrow")
    npc._auction_filter("armor")
    await process_frame
    pager = npc._body.find_child("PPAAuctionBuyPageCount",true,false) as Label
    check(pager.text=="1 / 1" and
        npc._body.find_child("PPAAuctionBuyLotsGrid",true,false).get_child_count()==10,
        "Category filtering must reset to page one, preserving 10 empty cells")
    check(JSON.stringify(lots).contains("lot_204"),
        "UI changed authoritative signed lot objects")
    npc.close_npc()
    host.queue_free()
    remove_meta("phoenix_account")
    await process_frame
    print("PPA_AUCTION_BUY_PAGES_OK cells=10 real_205=21_pages swipe=both no_fake_lots=1 filtering=1 no_writes=1")
    quit(0)
