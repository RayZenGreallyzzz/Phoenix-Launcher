extends RefCounted

# Presentation of the existing PPA clan state. All mutations are authenticated
# commands; no local membership, currency, inventory or bonus calculations.
const BONUS_NAMES := {"mobDamage":"Урон по монстрам", "bossDamage":"Урон по боссам",
    "hp":"HP", "mp":"MP", "xp":"Опыт", "gold":"Gold"}
const AUTHORITY_NAMES := {"acceptMembers":"Приём участников", "viewClanHistory":"Журнал",
    "manageStorageRights":"Права склада", "manageMembers":"Управление составом"}

static func _body(host: Control) -> VBoxContainer:
    return host.get("_body") as VBoxContainer

static func _text(host: Control, value: String) -> void:
    _body(host).add_child(host.call("_label", value))

static func _can(host: Control, action: String, permitted: bool = true) -> bool:
    var blocked_until := float((host.get("clan_state") as Dictionary).get("joinBlockedUntil", 0))
    var cooldown_ok := not action in ["create", "apply"] or blocked_until <= Time.get_unix_time_from_system() * 1000.0
    return permitted and cooldown_ok and (host.get("clan_actions") as Array).has(action) \
        and not bool(host.get("clan_busy")) and not bool(host.get("clan_pending"))

static func _action(host: Control, caption: String, action: String, fields: Dictionary,
        permitted: bool = true) -> Button:
    var button: Button = host.call("_button", caption, _can(host, action, permitted))
    button.name = "ClanCommand_" + action
    button.clip_text = true
    button.tooltip_text = caption
    button.pressed.connect(func(): host.call("request_clan_action", action, fields))
    _body(host).add_child(button)
    return button

static func _right(state: Dictionary, right: String) -> bool:
    var me: Dictionary = state.get("self", {})
    if str(me.get("role", "")) == "Глава":
        return true
    var grants: Dictionary = state.get("authority", {})
    var mine: Dictionary = grants.get(str(me.get("id", "")), {})
    return mine.get(right, false) == true

static func render(host: Control) -> void:
    var state: Dictionary = host.get("clan_state")
    var clan: Variant = state.get("clan")
    var has_clan: bool = clan is Dictionary and not clan.is_empty()
    var me: Dictionary = state.get("self", {})
    var leader: bool = has_clan and str(clan.get("leaderId", "")) == str(me.get("id", ""))
    var captions := {"overview":"ОБЗОР КЛАНА", "clans":"КЛАНЫ И РЕЙТИНГ",
        "members":"УЧАСТНИКИ И ЗАЯВКИ", "storage":"КЛАНОВЫЙ СКЛАД",
        "exchange":"КЛАНОВЫЙ ОБМЕН", "bosses":"КЛАНОВЫЕ БОССЫ",
        "bonuses":"БОНУСЫ КЛАНА", "wars":"ВОЙНЫ И ЦИТАДЕЛЬ", "journal":"ЖУРНАЛ"}
    host.call("_section", captions.get(str(host.get("tab")), "КЛАН"), "Общий клан Telegram и Godot PPA")
    var refresh: Button = host.call("_button", "ОБНОВИТЬ КЛАН", not bool(host.get("clan_busy")))
    refresh.name = "ClanRefresh"
    refresh.pressed.connect(func(): host.emit_signal("authoritative_state_requested", "clan"))
    _body(host).add_child(refresh)
    if bool(host.get("clan_pending")):
        _text(host, "Есть неподтверждённое действие. Повтор отправит тот же запрос без второго выполнения.")
        var retry: Button = host.call("_button", "ПРОВЕРИТЬ ТО ЖЕ ДЕЙСТВИЕ", not bool(host.get("clan_busy")))
        retry.name = "ClanRetryPending"
        retry.pressed.connect(func(): host.emit_signal("clan_retry_requested"))
        _body(host).add_child(retry)
    var notice := str(host.get("clan_notice"))
    if not notice.is_empty():
        _text(host, notice)
    var blocked_until := float(state.get("joinBlockedUntil", 0))
    if blocked_until > Time.get_unix_time_from_system() * 1000.0:
        var minutes := ceili((blocked_until / 1000.0 - Time.get_unix_time_from_system()) / 60.0)
        _text(host, "После выхода создание и вступление закрыты · осталось около " + str(minutes) + " мин.")
    match str(host.get("tab")):
        "clans":
            _directory(host, state, has_clan)
        "overview":
            if not has_clan:
                _text(host, "Ты ещё не состоишь в клане. Подай заявку во вкладке «Кланы» или создай свой.")
                _create(host)
                return
            host.call("_mini_row", str(clan.get("name", "")), str(me.get("role", "")))
            var progress: Dictionary = state.get("clanProgress", {})
            host.call("_mini_row", "Уровень клана", str(progress.get("level", "—")))
            host.call("_mini_row", "Участников", str((state.get("members", []) as Array).size()))
            host.call("_mini_row", "Клановые монеты", str(progress.get("coins", "—")))
            host.call("_mini_row", "Мой вклад", str(progress.get("personalContribution", "—")))
            host.call("_mini_row", "Свободные очки", str(progress.get("freePoints", "—")))
            _action(host, "ВЫЙТИ ИЗ КЛАНА", "leaveClan", {})
        "members":
            _members(host, state, leader)
        "bonuses":
            _bonuses(host, state, leader)
        "storage":
            if not has_clan:
                _text(host, "Для склада нужно состоять в клане.")
                return
            var storage: Dictionary = state.get("storage", {})
            host.call("_mini_row", "Общий склад", str(storage.get("used", 0)) + " / " + str(storage.get("max", 500)))
            _text(host, "Открыт" if state.get("storageUnlocked", false) else "Склад ещё не открыт")
            host.call("show_canonical_clan_storage", storage.get("items", []))
            _text(host, "Перенос вещей появится после подключения общей проверки предметов и сохранения.")
        "journal":
            if not _right(state, "viewClanHistory"):
                _text(host, "Просмотр журнала доступен по правам клана.")
                return
            _entries(host, state.get("events", []), "События клана")
            _entries(host, state.get("history", []), "История склада")
        "exchange":
            var trade: Variant = state.get("tradeSession")
            _text(host, "Есть обмен на сервере" if trade is Dictionary else "Активного обмена нет")
            _text(host, "Отправка вещей в Godot требует общей проверки предметов. Этот этап ещё не подключён.")
        "bosses":
            _entries(host, state.get("bosses", []), "Клановые боссы")
            _text(host, "Сетевой бой и награды будут подключены к боевому серверу PPA отдельно.")
        "wars":
            _entries(host, state.get("wars", []), "Войны клана")
            _text(host, "Участие в осаде требует подключения общего боевого мира.")

static func _create(host: Control) -> void:
    var name_input := LineEdit.new()
    name_input.name = "ClanCreateName"
    name_input.placeholder_text = "Название клана · минимум 3 символа"
    name_input.max_length = 24
    name_input.custom_minimum_size.y = 44
    _body(host).add_child(name_input)
    var button: Button = host.call("_button", "СОЗДАТЬ КЛАН", false)
    button.name = "ClanCommand_create"
    name_input.text_changed.connect(func(value: String):
        button.disabled = not (_can(host, "create") and value.strip_edges().length() >= 3))
    button.pressed.connect(func(): host.call("request_clan_action", "create", {"name":name_input.text.strip_edges()}))
    _body(host).add_child(button)

static func _directory(host: Control, state: Dictionary, has_clan: bool) -> void:
    var rows: Array = state.get("clanRanking", state.get("clanDirectory", []))
    if rows.is_empty():
        _text(host, "Кланов пока нет")
    for value in rows.slice(0, 200):
        if not value is Dictionary:
            continue
        var row: Dictionary = value
        host.call("_mini_row", str(row.get("name", "")), "Ур. " + str(row.get("level", "—")) \
            + " · участников " + str(row.get("members", row.get("memberCount", "—"))))
        if not has_clan:
            _action(host, "ЗАЯВКА ОТПРАВЛЕНА" if row.get("applied", false) else "ПОДАТЬ ЗАЯВКУ", "apply",
                {"name":str(row.get("name", ""))}, row.get("applied", false) != true)

static func _members(host: Control, state: Dictionary, leader: bool) -> void:
    var me: Dictionary = state.get("self", {})
    for value in (state.get("members", []) as Array).slice(0, 200):
        if not value is Dictionary:
            continue
        var member: Dictionary = value
        var member_id := str(member.get("id", ""))
        host.call("_mini_row", str(member.get("name", "")), str(member.get("role", "")))
        if member_id == str(me.get("id", "")) or member.get("role") == "Глава":
            continue
        if _right(state, "manageMembers"):
            _action(host, "ИСКЛЮЧИТЬ " + str(member.get("name", "")), "kickMember", {"memberId":member_id})
        if leader:
            _action(host, "ПЕРЕДАТЬ ГЛАВУ " + str(member.get("name", "")), "transferLeadership", {"memberId":member_id})
            _authority(host, state, member_id)
        if _right(state, "manageStorageRights"):
            _permissions(host, state, member_id)
    if _right(state, "acceptMembers"):
        _text(host, "Заявки")
        for value in (state.get("applications", []) as Array).slice(0, 200):
            if not value is Dictionary:
                continue
            var application: Dictionary = value
            _text(host, str(application.get("name", "")))
            var fields := {"applicationId":str(application.get("id", ""))}
            _action(host, "ПРИНЯТЬ", "acceptApplication", fields)
            _action(host, "ОТКЛОНИТЬ", "rejectApplication", fields)

static func _authority(host: Control, state: Dictionary, member_id: String) -> void:
    var all_rights: Dictionary = state.get("authority", {})
    var granted: Dictionary = all_rights.get(member_id, {})
    var checks: Dictionary = {}
    for key in AUTHORITY_NAMES:
        var check := CheckBox.new()
        check.text = AUTHORITY_NAMES[key]
        check.button_pressed = granted.get(key, false) == true
        check.disabled = not _can(host, "setAuthority")
        _body(host).add_child(check)
        checks[key] = check
    var button: Button = host.call("_button", "СОХРАНИТЬ ПОЛНОМОЧИЯ", _can(host, "setAuthority"))
    button.name = "ClanCommand_setAuthority"
    button.pressed.connect(func():
        var rights: Dictionary = {}
        for key in checks:
            rights[key] = (checks[key] as CheckBox).button_pressed
        host.call("request_clan_action", "setAuthority", {"memberId":member_id, "authority":rights}))
    _body(host).add_child(button)

static func _permissions(host: Control, state: Dictionary, member_id: String) -> void:
    var all_rights: Dictionary = state.get("permissions", {})
    var rights: Dictionary = all_rights.get(member_id, {})
    var deposit := CheckBox.new()
    deposit.text = "Может класть вещи"
    deposit.button_pressed = rights.get("canDeposit", false) == true
    deposit.disabled = not _can(host, "setPermissions")
    _body(host).add_child(deposit)
    var withdraw := OptionButton.new()
    withdraw.name = "ClanWithdrawRights"
    withdraw.add_item("Забирать: ничего")
    withdraw.add_item("Забирать: всё")
    withdraw.select(1 if rights.get("withdrawMode") == "all" else 0)
    withdraw.disabled = not _can(host, "setPermissions")
    _body(host).add_child(withdraw)
    if rights.get("withdrawMode") == "selected":
        _text(host, "Сейчас разрешены отдельные вещи. Сохранение ниже заменит этот режим выбранным.")
    var button: Button = host.call("_button", "СОХРАНИТЬ ПРАВА СКЛАДА", _can(host, "setPermissions"))
    button.name = "ClanCommand_setPermissions"
    button.pressed.connect(func(): host.call("request_clan_action", "setPermissions",
        {"memberId":member_id, "permissions":{"canDeposit":deposit.button_pressed,
        "withdrawMode":"all" if withdraw.selected == 1 else "none"}}))
    _body(host).add_child(button)

static func _bonuses(host: Control, state: Dictionary, leader: bool) -> void:
    var progress: Dictionary = state.get("clanProgress", {})
    var points := int(progress.get("freePoints", 0))
    host.call("_mini_row", "Свободные очки", str(points))
    var bonuses: Dictionary = progress.get("bonuses", {})
    for key in BONUS_NAMES:
        var level := int(bonuses.get(key, 0))
        host.call("_mini_row", BONUS_NAMES[key], str(level) + " / 3")
        _action(host, "УЛУЧШИТЬ " + str(BONUS_NAMES[key]), "upgradeBonus", {"bonusKey":key},
            leader and points > 0 and level < 3)

static func _entries(host: Control, entries: Array, title: String) -> void:
    _text(host, title)
    if entries.is_empty():
        _text(host, "Записей нет")
    for value in entries.slice(0, 200):
        if value is Dictionary:
            _text(host, str(value.get("text", value.get("name", ""))).left(600))
