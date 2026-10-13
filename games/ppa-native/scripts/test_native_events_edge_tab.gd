extends SceneTree

# Visual navigation test, no PPA account, gameplay writes or fake rewards.
const WORLD_MENU = preload("res://scripts/test_world_menu.gd")

func _initialize() -> void:
    call_deferred("_run")

func check(ok: bool, message: String) -> void:
    if not ok:
        push_error("PPA_VERTICAL_EVENTS_TAB_FAIL: " + message)
        quit(1)
        assert(ok, message)

func _run() -> void:
    var screen := Control.new()
    screen.size = Vector2(800,1280)
    root.add_child(screen)
    var menu := WORLD_MENU.new()
    menu.configure({},"archer")
    screen.add_child(menu)
    menu.size = screen.size
    await process_frame
    await process_frame
    var button := menu.find_child("OpenGlobalPpaHub",true,false) as Button
    var caption := menu.find_child("PPAVerticalEventsTitle",true,false) as Label
    check(button!=null and caption!=null,
        "The right-side Events tab is not rendered")
    check(caption.text=="СОБЫТИЯ" and is_equal_approx(caption.rotation,-PI/2.0),
        "Events tab label must be ROTATED 90 degrees, not stacked letters")
    check(button.size.x<=46.0 and button.size.y>=130.0
        and button.position.x>=screen.size.x-46.0,
        "Events button must sit vertically against RIGHT edge of phone")
    check(caption.mouse_filter==Control.MOUSE_FILTER_IGNORE,
        "Rotated label must not intercept touch presses")
    var rotated_center: Vector2 = caption.get_global_transform() * (caption.size * 0.5)
    check(rotated_center.distance_to(button.get_global_rect().get_center()) <= 3.0,
        "Rotated Events text must be visually CENTERED inside its side button")
    # Simulate the actual press rather than faking event section state.
    button.pressed.emit()
    check(menu._global_hub.is_open() and menu._global_hub.section=="events",
        "Tapping side tab did not open authentic events hub")
    menu.close_menu()
    screen.size=Vector2(360,740)
    menu.size=screen.size
    await process_frame
    check(button.position.x>=screen.size.x-46.0
        and button.get_global_rect().end.x<=screen.size.x+1.0,
        "Events tab is off screen on compact mobile displays")
    screen.queue_free()
    await process_frame
    print("PPA_VERTICAL_EVENTS_TAB_OK side=right rotation=-90 target=touch events=1 small_phone=1 writes=0")
    quit(0)
