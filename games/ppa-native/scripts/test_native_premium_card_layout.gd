extends SceneTree

# Only UI geometry; does not authorize premium spending or fetch player saves.
const HUB = preload("res://scripts/ppa_global_hub.gd")

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, detail: String) -> void:
    if not ok:
        push_error("PPA_PREMIUM_LAYOUT_FAIL: " + detail)
        quit(1)
        assert(ok, detail)

func _run() -> void:
    var host := Control.new()
    root.add_child(host)
    var hub := HUB.new()
    host.add_child(hub)
    await process_frame

    host.size = Vector2(480, 900)
    hub.size = host.size
    hub.open_section("premium")
    await process_frame
    var portrait: Array = hub.find_children("OriginalPpaPremiumGrid_*", "GridContainer", true, false)
    check(portrait.size() == 3, "Goods, bundles and subscriptions must all be present")
    for grid in portrait:
        check(grid.columns == 1, "Premium mobile cards must use a readable single column")
        check(grid.get_child_count() > 0, "Real premium catalog group is blank")

    host.size = Vector2(1280,720)
    hub.size = host.size
    hub._fit()
    hub.open_section("premium")
    await process_frame
    var landscape: Array = hub.find_children("OriginalPpaPremiumGrid_*", "GridContainer", true, false)
    check(landscape.size() == 3, "Landscape premium groups missing")
    for grid in landscape:
        check(grid.columns == 2, "Tablet premium must fit two cards, not three narrow columns")
        check(grid.get_child_count() > 0, "Premium items disappeared after resizing")

    host.queue_free()
    await process_frame
    print("PPA_PREMIUM_LAYOUT_OK portrait_columns=1 tablet_columns=2 real_catalog=3 no_purchases=1")
    quit(0)
