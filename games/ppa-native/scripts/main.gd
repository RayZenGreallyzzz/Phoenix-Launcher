extends Control

const API_BASE := "https://ppa-phoenixpixarena.1988stella1988.workers.dev"
const GAME_ID := "phoenix-pix-arena"
const CHARACTER_SELECT_SCRIPT = preload("res://scripts/character_select.gd")
const SESSION_FILE := "user://phoenix_game_session.json"
const TICKET_EXTRA := "phoenix_game_ticket"
const GAME_ID_EXTRA := "phoenix_game_id"

var http: HTTPRequest
var request_mode := ""
var session_token := ""
var account: Dictionary = {}

var status_label: Label
var title_label: Label
var account_label: Label
var details_label: Label
var play_button: Button
var retry_button: Button
var selection_screen: Control

func _ready() -> void:
    _build_ui()
    http = HTTPRequest.new()
    http.timeout = 20.0
    add_child(http)
    http.request_completed.connect(_on_request_completed)

    var ticket := _android_extra(TICKET_EXTRA)
    var incoming_game_id := _android_extra(GAME_ID_EXTRA)

    if not ticket.is_empty():
        if not incoming_game_id.is_empty() and incoming_game_id != GAME_ID:
            _show_error("Launcher передал ticket другой игры.")
            return
        _exchange_ticket(ticket)
        return

    if _restore_saved_session():
        _load_profile()
    else:
        _show_error("Открой Phoenix Pix Arena через Phoenix Launcher, чтобы получить игровую сессию.")

func _build_ui() -> void:
    var background := TextureRect.new()
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.texture = load("res://assets/ppa_hero.jpg")
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(background)

    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.01, 0.012, 0.016, 0.72)
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(shade)

    var root_margin := MarginContainer.new()
    root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root_margin.add_theme_constant_override("margin_left", 36)
    root_margin.add_theme_constant_override("margin_right", 36)
    root_margin.add_theme_constant_override("margin_top", 30)
    root_margin.add_theme_constant_override("margin_bottom", 30)
    add_child(root_margin)

    var outer := VBoxContainer.new()
    outer.alignment = BoxContainer.ALIGNMENT_CENTER
    root_margin.add_child(outer)

    var center_panel := PanelContainer.new()
    center_panel.custom_minimum_size = Vector2(0, 420)
    center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    center_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.04, 0.047, 0.055, 0.94)
    panel_style.border_color = Color(0.16, 0.17, 0.19, 1)
    panel_style.set_border_width_all(1)
    panel_style.set_corner_radius_all(18)
    center_panel.add_theme_stylebox_override("panel", panel_style)
    outer.add_child(center_panel)

    var pad := MarginContainer.new()
    pad.add_theme_constant_override("margin_left", 34)
    pad.add_theme_constant_override("margin_right", 34)
    pad.add_theme_constant_override("margin_top", 28)
    pad.add_theme_constant_override("margin_bottom", 28)
    center_panel.add_child(pad)

    var stack := VBoxContainer.new()
    stack.alignment = BoxContainer.ALIGNMENT_CENTER
    stack.add_theme_constant_override("separation", 12)
    pad.add_child(stack)

    var brand := Label.new()
    brand.text = "PHOENIX PIX ARENA"
    brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    brand.add_theme_font_size_override("font_size", 34)
    brand.add_theme_color_override("font_color", Color("#FE6D1C"))
    stack.add_child(brand)

    title_label = Label.new()
    title_label.text = "ЗАГРУЗКА ИГРОВОЙ СЕССИИ"
    title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_label.add_theme_font_size_override("font_size", 18)
    title_label.add_theme_color_override("font_color", Color("#EDEFF0"))
    stack.add_child(title_label)

    status_label = Label.new()
    status_label.text = "Подключение к Phoenix Account…"
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.add_theme_font_size_override("font_size", 16)
    status_label.add_theme_color_override("font_color", Color("#7E848B"))
    stack.add_child(status_label)

    account_label = Label.new()
    account_label.text = ""
    account_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    account_label.add_theme_font_size_override("font_size", 28)
    account_label.add_theme_color_override("font_color", Color("#EDEFF0"))
    stack.add_child(account_label)

    details_label = Label.new()
    details_label.text = ""
    details_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    details_label.add_theme_font_size_override("font_size", 14)
    details_label.add_theme_color_override("font_color", Color("#7E848B"))
    stack.add_child(details_label)

    var spacer := Control.new()
    spacer.custom_minimum_size = Vector2(1, 10)
    stack.add_child(spacer)

    play_button = Button.new()
    play_button.text = "ВОЙТИ В НАТИВНЫЙ МИР"
    play_button.custom_minimum_size = Vector2(0, 58)
    play_button.disabled = true
    play_button.pressed.connect(_enter_native_world)
    _style_primary_button(play_button)
    stack.add_child(play_button)

    retry_button = Button.new()
    retry_button.text = "ПОВТОРИТЬ ПРОВЕРКУ"
    retry_button.custom_minimum_size = Vector2(0, 48)
    retry_button.visible = false
    retry_button.pressed.connect(_retry)
    stack.add_child(retry_button)

func _style_primary_button(button: Button) -> void:
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("#FE6D1C")
    normal.set_corner_radius_all(10)
    var pressed := normal.duplicate()
    pressed.bg_color = Color("#D84D0D")
    var disabled := normal.duplicate()
    disabled.bg_color = Color(0.25, 0.18, 0.15, 1)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", normal)
    button.add_theme_stylebox_override("pressed", pressed)
    button.add_theme_stylebox_override("disabled", disabled)
    button.add_theme_color_override("font_color", Color.WHITE)
    button.add_theme_font_size_override("font_size", 16)

func _android_extra(key: String) -> String:
    if OS.get_name() != "Android":
        return ""
    var runtime = Engine.get_singleton("AndroidRuntime")
    if runtime == null:
        return ""
    var activity = runtime.getActivity()
    if activity == null:
        return ""
    var intent = activity.getIntent()
    if intent == null:
        return ""
    var value = intent.getStringExtra(key)
    if value == null:
        return ""
    return str(value)

func _exchange_ticket(ticket: String) -> void:
    request_mode = "exchange"
    status_label.text = "Проверяем одноразовый game ticket…"
    status_label.add_theme_color_override("font_color", Color("#7E848B"))
    retry_button.visible = false
    var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
    var payload := JSON.stringify({"ticket": ticket, "gameId": GAME_ID})
    var err := http.request(API_BASE + "/api/game/session/exchange", headers, HTTPClient.METHOD_POST, payload)
    if err != OK:
        _show_error("Не удалось отправить game ticket: %s" % error_string(err))

func _load_profile() -> void:
    if session_token.is_empty():
        _show_error("Игровая сессия отсутствует.")
        return
    request_mode = "me"
    status_label.text = "Восстанавливаем игровую сессию…"
    var headers := PackedStringArray([
        "Accept: application/json",
        "Authorization: Bearer " + session_token
    ])
    var err := http.request(API_BASE + "/api/game/me", headers, HTTPClient.METHOD_GET)
    if err != OK:
        _show_error("Не удалось проверить игровую сессию: %s" % error_string(err))

func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    var body_text := body.get_string_from_utf8()
    var parsed = JSON.parse_string(body_text)
    if response_code < 200 or response_code >= 300 or typeof(parsed) != TYPE_DICTIONARY:
        var message := "Phoenix Server HTTP %d" % response_code
        if typeof(parsed) == TYPE_DICTIONARY:
            message = str(parsed.get("message", message))
        _show_error(message)
        if response_code == 401:
            _clear_saved_session()
        return

    var data: Dictionary = parsed
    # Both existing PPA auth endpoints must identify the same server game.
    # Do not accept a successful HTTP response with another game's account.
    if data.get("ok", false) != true or str(data.get("gameId", "")) != GAME_ID:
        _show_error("Ответ сервера относится к другой игре или не подтверждён.")
        return
    if not (data.get("account") is Dictionary):
        _show_error("Сервер не подтвердил аккаунт Phoenix.")
        return
    if request_mode == "exchange":
        var session: Dictionary = data.get("session", {})
        session_token = str(session.get("token", ""))
        if session_token.is_empty():
            _show_error("Phoenix Server не вернул игровую сессию.")
            return
        _save_session(session_token)
        account = data.get("account", {})
        _show_connected()
        return

    if request_mode == "me":
        account = data.get("account", {})
        _show_connected()

func _show_connected() -> void:
    var nickname := str(account.get("nickname", "Phoenix"))
    var ppa_nickname := str(account.get("ppaNickname", nickname))
    var class_key := str(account.get("classKey", ""))
    var telegram_id := str(account.get("telegramId", ""))

    status_label.text = "✓ Phoenix Account подключён · game ticket принят"
    status_label.add_theme_color_override("font_color", Color("#53CDAB"))
    account_label.text = ppa_nickname if not ppa_nickname.is_empty() else nickname

    var parts: Array[String] = []
    if not class_key.is_empty():
        parts.append("Класс: " + class_key)
    if not telegram_id.is_empty():
        parts.append("Telegram ID связан с PPA")
    parts.append("Сессия: native Godot")
    details_label.text = "   ·   ".join(parts)

    play_button.disabled = false
    retry_button.visible = false
    # Player selection is a real mandatory step after account verification.
    # Never let the native client silently create/change the live hero class.
    _show_character_selection()

func _show_character_selection() -> void:
    if selection_screen != null:
        selection_screen.queue_free()
        selection_screen = null
    selection_screen = CHARACTER_SELECT_SCRIPT.new()
    selection_screen.name = "AuthoritativeCharacterSelection"
    add_child(selection_screen)
    selection_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    selection_screen.set_account(account)
    selection_screen.character_confirmed.connect(_enter_native_world)

func _show_error(message: String) -> void:
    status_label.text = "✕ " + message
    status_label.add_theme_color_override("font_color", Color("#F14D4C"))
    account_label.text = ""
    details_label.text = ""
    play_button.disabled = true
    retry_button.visible = true

func _retry() -> void:
    retry_button.visible = false
    if _restore_saved_session():
        _load_profile()
    else:
        _show_error("Нужен новый запуск через Phoenix Launcher.")

func _enter_native_world() -> void:
    # The selection is server-owned. A client-side class preview is NEVER
    # permission to enter with an unregistered or different character.
    if str(account.get("ppaNickname", "")).strip_edges().is_empty() or str(account.get("classKey", "")).strip_edges().is_empty():
        _show_error("В Phoenix Account пока нет зарегистрированного персонажа PPA.")
        return
    get_tree().set_meta("phoenix_account", account.duplicate(true))
    # Expose the game SESSION in process memory to the read-only native
    # save adapter. Never pass launcher credentials or Telegram ID as auth.
    if session_token.is_empty():
        _show_error("Игровая сессия Phoenix истекла. Нужна новая авторизация.")
        return
    get_tree().set_meta("ppa_native_game_session", session_token)
    var err := get_tree().change_scene_to_file("res://world.tscn")
    if err != OK:
        _show_error("Не удалось открыть native world: %s" % error_string(err))

func _save_session(token: String) -> void:
    var file := FileAccess.open(SESSION_FILE, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify({"token": token}))

func _restore_saved_session() -> bool:
    if not FileAccess.file_exists(SESSION_FILE):
        return false
    var file := FileAccess.open(SESSION_FILE, FileAccess.READ)
    if file == null:
        return false
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return false
    session_token = str(parsed.get("token", ""))
    return not session_token.is_empty()

func _clear_saved_session() -> void:
    session_token = ""
    if FileAccess.file_exists(SESSION_FILE):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_FILE))
