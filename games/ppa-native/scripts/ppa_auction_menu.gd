extends RefCounted

# Approved Phoenix auction layout. This screen never issues local money/item
# mutations: all write buttons delegate to the signed, versioned NPC service.
const COIN = preload("res://assets/ppa_coin.webp")
const GOLD = Color("#F5C466")
const TEXT = Color("#EEE7D9")
const MUTED = Color("#B0A69A")
const EDGE = Color("#BB7B2F")
const CATEGORIES = [
    {"key":"all","text":"Все предметы","glyph":"▦"},
    {"key":"weapon","text":"Оружие","glyph":"⚔"},
    {"key":"armor","text":"Броня","glyph":"♜"},
    {"key":"accessories","text":"Аксессуары","glyph":"◇"},
    {"key":"consumables","text":"Расходники","glyph":"♥"},
    {"key":"materials","text":"Материалы","glyph":"◆"},
    {"key":"books","text":"Книги","glyph":"▤"},
    {"key":"quest","text":"Квестовые","glyph":"▧"},
    {"key":"misc","text":"Разное","glyph":"✦"}
]
const RARITIES = ["all","common","uncommon","rare","epic","legendary"]
const RARITY_NAMES = ["Любое","Обычное","Необычное","Редкое","Эпическое","Легендарное"]
const RARITY_COLORS = {
    "common":Color("#BDC3C7"),
    "uncommon":Color("#51D175"),
    "rare":Color("#51ADFF"),
    "epic":Color("#DB7CFF"),
    "legendary":Color("#FFBF53")
}

static func _label(text: String, font_size: int = 13, color: Color = TEXT) -> Label:
    var label := Label.new()
    label.text = text
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_color_override("font_color", color)
    label.add_theme_font_size_override("font_size", font_size)
    return label

static func _skin(background: Color = Color("#0C1519"), border: Color = EDGE, radius: int = 7) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = background
    style.border_color = border
    style.set_border_width_all(2)
    style.set_corner_radius_all(radius)
    style.set_content_margin_all(7)
    return style

static func _button(text: String, enabled: bool = true) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size.y = 39
    button.add_theme_font_size_override("font_size", 12)
    button.add_theme_color_override("font_color", GOLD)
    button.add_theme_color_override("font_disabled_color", Color("#91908E"))
    button.add_theme_stylebox_override("normal", _skin(Color("#171717"),EDGE))
    button.add_theme_stylebox_override("hover", _skin(Color("#382410"),GOLD))
    button.add_theme_stylebox_override("pressed", _skin(Color("#543216"),GOLD))
    button.add_theme_stylebox_override("disabled", _skin(Color("#13191C"),Color("#4C4A45")))
    button.disabled = not enabled
    return button

static func _section(parent: VBoxContainer, heading: String, note: String = "") -> void:
    parent.add_child(_label(heading, 17, GOLD))
    if not note.is_empty():
        parent.add_child(_label(note, 11, MUTED))

static func _coin_line(parent: Node, name: String, value: Variant, symbol: String) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 5)
    parent.add_child(row)
    if symbol == "ppa":
        var icon := TextureRect.new()
        icon.texture = COIN
        icon.custom_minimum_size = Vector2(20,20)
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
        row.add_child(icon)
    else:
        row.add_child(_label("◆",15,Color("#42C6FF")))
    row.add_child(_label(name + "  " + str(value) if value != null else name + "  —", 12, GOLD))

# A full-width pinned footer, outside the scrolling auction content.
# Never put currency labels inside the narrow category sidebar.
static func render_wallet(ui: Control, host: HBoxContainer) -> void:
    var state: Dictionary = ui.get("auction_state")
    var verified: bool = bool(ui.call("_owns_verified_state",state))
    var wallet: Dictionary = {}
    # The general game-state snapshot is view-only and may arrive before
    # the auction contract. Do not infer permissions to trade from it.
    var view: Dictionary = ui.get("_player_view_readonly")
    var money: Variant = view.get("money",{})
    if money is Dictionary:
        wallet = (money as Dictionary).duplicate()
    if verified and state.get("wallet") is Dictionary:
        for code in ["ppa","gram"]:
            if state["wallet"].get(code,null) != null:
                wallet[code] = state["wallet"][code]
    host.add_theme_constant_override("separation",6)
    for spec in [
        {"code":"ppa","name":"PPA","icon":"coin"},
        {"code":"gram","name":"Gram","icon":"diamond"}
    ]:
        var code := str(spec["code"])
        var panel := PanelContainer.new()
        panel.name = "PPAAuctionWallet_" + code
        panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        panel.size_flags_stretch_ratio = 1.0
        panel.add_theme_stylebox_override("panel",
            _skin(Color("#10191F"),EDGE,7))
        host.add_child(panel)
        var line := HBoxContainer.new()
        line.alignment = BoxContainer.ALIGNMENT_CENTER
        line.add_theme_constant_override("separation",5)
        panel.add_child(line)
        if code == "ppa":
            var icon := TextureRect.new()
            icon.name = "PPAAuctionWalletCoin"
            icon.texture = COIN
            icon.custom_minimum_size = Vector2(24,24)
            icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
            icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
            line.add_child(icon)
        else:
            line.add_child(_label("◆",18,Color("#42C6FF")))
        var value: Variant = wallet.get(code,null)
        var amount := str(value) if value is int or value is float else "—"
        var label := _label(str(spec["name"]) + "  " + amount,13,GOLD)
        label.name = "PPAAuctionWalletAmount_" + code
        label.autowrap_mode = TextServer.AUTOWRAP_OFF
        label.clip_text = true
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        line.add_child(label)

static func _banner(parent: VBoxContainer) -> void:
    var banner := PanelContainer.new()
    banner.name = "PPAAuctionPhoenixBanner"
    banner.add_theme_stylebox_override("panel",_skin(Color("#190D0A"),GOLD,13))
    parent.add_child(banner)
    var stack := VBoxContainer.new()
    stack.alignment = BoxContainer.ALIGNMENT_CENTER
    banner.add_child(stack)
    var crown := _label("✦  ⚖  ✦", 20, GOLD)
    crown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stack.add_child(crown)
    var title := _label("АУКЦИОН", 23, GOLD)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stack.add_child(title)
    var caption := _label("ПОКУПАЙ · ПРОДАВАЙ · РАЗВИВАЙСЯ", 10, MUTED)
    caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    stack.add_child(caption)

static func _matches(item: Dictionary, category: String) -> bool:
    if category == "all":
        return true
    var kind := str(item.get("kind","")).to_lower()
    var slot := str(item.get("slot","")).to_lower()
    var equip := str(item.get("equipSlot","")).to_lower()
    if category == "weapon":
        return slot == "weapon" or equip == "weapon"
    if category == "armor":
        return slot in ["helmet","armor","gloves","legs","boots","shield"] or equip in ["helmet","armor","gloves","legs","boots","shield"]
    if category == "accessories":
        return slot in ["ring","necklace","artifact","cloak","wings","pet","amulet"] or equip in ["ring","necklace","artifact","cloak","wings","pet","amulet"]
    if category == "consumables":
        return kind in ["consumable","stone","feather","potion"]
    if category == "materials":
        return kind == "material"
    if category == "books":
        return kind in ["grimoire","book"]
    if category == "quest":
        return kind == "quest"
    # No longer let "Разное" accidentally display every item.
    return not (_matches(item,"weapon") or _matches(item,"armor") or _matches(item,"accessories") or _matches(item,"consumables") or _matches(item,"materials") or _matches(item,"books") or _matches(item,"quest"))

static func _category_changed(ui: Control, category: String) -> void:
    ui.set("_auction_category",category)
    ui.call("_render")

static func _make_categories(ui: Control, parent: Node, compact: bool) -> void:
    var layout: Container
    if compact:
        var grid := GridContainer.new()
        grid.columns = 3
        layout = grid
    else:
        layout = VBoxContainer.new()
    layout.name = "PPAAuctionCategoryGrid"
    parent.add_child(layout)
    for item in CATEGORIES:
        var key := str(item["key"])
        var selected := str(ui.get("_auction_category")) == key
        var b := _button(str(item["glyph"]) + " " + str(item["text"]))
        b.name = "PPAAuctionCategory_" + key
        b.custom_minimum_size.y = 34
        b.add_theme_font_size_override("font_size", 10 if compact else 12)
        if selected:
            b.add_theme_stylebox_override("normal",_skin(Color("#51300F"),GOLD,5))
        b.pressed.connect(_category_changed.bind(ui,key))
        layout.add_child(b)

static func _search_changed(new_text: String, ui: Control) -> void:
    ui.set("_auction_search",new_text.strip_edges())

static func _search_submit(_text: String, ui: Control) -> void:
    ui.call("_render")

static func _filter_changed(index: int, ui: Control, property: String, options: Array) -> void:
    if index >= 0 and index < options.size():
        ui.set(property,options[index])
        ui.call("_render")

static func _filters(ui: Control, main: VBoxContainer) -> void:
    var line := HBoxContainer.new()
    line.add_theme_constant_override("separation",4)
    main.add_child(line)
    var search := LineEdit.new()
    search.name = "PPAAuctionSearch"
    search.placeholder_text = "Поиск предмета..."
    search.text = str(ui.get("_auction_search"))
    search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    search.text_changed.connect(_search_changed.bind(ui))
    search.text_submitted.connect(_search_submit.bind(ui))
    line.add_child(search)
    var find := _button("НАЙТИ")
    find.name = "PPAAuctionFind"
    find.pressed.connect(func(): ui.call("_render"))
    line.add_child(find)
    var filters := HBoxContainer.new()
    main.add_child(filters)
    var min_level := OptionButton.new()
    min_level.name = "PPAAuctionLevelFilter"
    var levels := ["all","1-20","21-40","41-60","61+"]
    for level in levels:
        min_level.add_item("Ур. " + level)
    min_level.select(maxi(0,levels.find(str(ui.get("_auction_level")))))
    min_level.item_selected.connect(_filter_changed.bind(ui,"_auction_level",levels))
    filters.add_child(min_level)
    var rarity := OptionButton.new()
    rarity.name = "PPAAuctionRarityFilter"
    for name in RARITY_NAMES:
        rarity.add_item(name)
    rarity.select(maxi(0,RARITIES.find(str(ui.get("_auction_rarity")))))
    rarity.item_selected.connect(_filter_changed.bind(ui,"_auction_rarity",RARITIES))
    rarity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    filters.add_child(rarity)

static func _visible_lot(ui: Control, item: Dictionary) -> bool:
    if not _matches(item,str(ui.get("_auction_category"))):
        return false
    var search := str(ui.get("_auction_search")).to_lower()
    if not search.is_empty() and not str(item.get("name","")).to_lower().contains(search):
        return false
    var rarity := str(ui.get("_auction_rarity"))
    if rarity != "all" and str(item.get("rarity","common")).to_lower() != rarity:
        return false
    var level := int(item.get("level",item.get("lvl",0)))
    match str(ui.get("_auction_level")):
        "1-20": return level >= 1 and level <= 20
        "21-40": return level >= 21 and level <= 40
        "41-60": return level >= 41 and level <= 60
        "61+": return level >= 61
    return true

static func _item_icon(ui: Control, item: Dictionary, width: int = 46) -> Button:
    var icon := _button(str(item.get("icon","◆")))
    icon.custom_minimum_size = Vector2(width,width)
    icon.disabled = true
    icon.clip_contents = true
    var rarity := str(item.get("rarity","common")).to_lower()
    var tint: Color = RARITY_COLORS.get(rarity,GOLD)
    icon.add_theme_stylebox_override("disabled",_skin(Color("#15191D"),tint,5))
    var loader: Node = ui.get("_preview_icons")
    if loader != null:
        loader.call("bind_button",item,"",icon)
    return icon

static func _lot_row(ui: Control, main: VBoxContainer, entry: Dictionary, mine: bool) -> void:
    var item: Dictionary = entry.get("item",{})
    if item.is_empty():
        return
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel",_skin(Color("#10191E"),Color("#69502E")))
    main.add_child(panel)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation",8)
    panel.add_child(row)
    row.add_child(_item_icon(ui,item))
    var details := VBoxContainer.new()
    details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(details)
    var tint: Color = RARITY_COLORS.get(str(item.get("rarity","common")).to_lower(),TEXT)
    details.add_child(_label(str(item.get("name","Предмет PPA")).left(55),13,tint))
    var subtitle := str(entry.get("qty",1)) + " шт. · +" + str(item.get("enh",0))
    if entry.has("expiresAt"):
        var left := maxi(0,int((float(entry["expiresAt"])-Time.get_unix_time_from_system()*1000.0)/60000.0))
        subtitle += " · " + str(left / 60) + " ч " + str(left % 60) + " мин"
    details.add_child(_label(subtitle,10,MUTED))
    details.add_child(_label("Продавец: " + str(entry.get("sellerName","Игрок")).left(25),10,MUTED))
    var trade := VBoxContainer.new()
    trade.add_theme_constant_override("separation",3)
    row.add_child(trade)
    var currency := str(entry.get("currency","ppa")).to_lower()
    if currency == "ppa":
        _coin_line(trade,"",entry.get("price","—"),"ppa")
    else:
        _coin_line(trade,"",entry.get("price","—"),"gram")
    var active := bool(ui.get("auction_state").get("settlementEnabled",false)) and not bool(ui.get("auction_loading")) and not bool(ui.get("auction_pending"))
    var actions: Array = ui.get("auction_actions")
    if mine and actions.has("cancel") and bool(entry.get("canCancel",false)):
        var cancel := _button("СНЯТЬ",active)
        cancel.name = "PPARealAuctionCancel_" + str(entry.get("id",""))
        cancel.pressed.connect(Callable(ui,"_auction_cancel_lot").bind(str(entry.get("id",""))))
        trade.add_child(cancel)
    elif not mine and actions.has("buy") and bool(entry.get("canBuy",false)):
        var buy := _button("КУПИТЬ",active)
        buy.name = "PPARealAuctionBuy_" + str(entry.get("id",""))
        buy.pressed.connect(Callable(ui,"_auction_buy_lot").bind(str(entry.get("id","")),float(entry.get("price",0)),currency))
        trade.add_child(buy)

static func _lots(ui: Control, main: VBoxContainer, entries: Array, mine: bool) -> void:
    var shown := 0
    for raw in entries:
        if not (raw is Dictionary):
            continue
        var lot: Dictionary = raw
        if not (lot.get("item") is Dictionary):
            continue
        if not mine and not _visible_lot(ui,lot["item"]):
            continue
        _lot_row(ui,main,lot,mine)
        shown += 1
        if shown >= 50:
            break
    if shown == 0:
        main.add_child(_label("Подходящих активных лотов нет.",12,MUTED))
    if shown >= 50:
        main.add_child(_label("Показаны первые 50 предложений. Полная серверная пагинация ещё требуется.",10,MUTED))

static func _select_sale(ui: Control, uid: String) -> void:
    ui.set("_auction_sell_uid",uid)
    ui.call("_render")

static func _sale_price_changed(value: float, ui: Control, preview: Label) -> void:
    ui.call("_set_asking_price",value)
    preview.text = "После комиссии 10%: " + str(snappedf(float(ui.get("_asking_price"))*0.9,0.01)) + " " + str(ui.get("_asking_currency"))

static func _sale_currency_changed(index: int, ui: Control, preview: Label) -> void:
    ui.call("_set_currency",index)
    preview.text = "После комиссии 10%: " + str(snappedf(float(ui.get("_asking_price"))*0.9,0.01)) + " " + str(ui.get("_asking_currency"))

static func _sell(ui: Control, main: VBoxContainer, state: Dictionary, verified: bool) -> void:
    _section(main,"ПРОДАТЬ","Выбери вещь из сумки. Сделка доступна только после подтверждения общим сервером.")
    var items: Array = state.get("bag",[]) if verified else []
    if verified:
        main.add_child(_label("Торговые места: " + str(state.get("mine",[]).size()) + " / " + str(state.get("maxSellSlots",0)),11,MUTED))
    else:
        main.add_child(_label("Торговые места: — / — · ждём сервер PPA",11,MUTED))
    var grid := GridContainer.new()
    grid.columns = 4 if ui.size.x < 520 else 6
    grid.name = "PPARealAuctionGearGrid"
    main.add_child(grid)
    var first := ""
    var chosen := str(ui.get("_auction_sell_uid"))
    var found := false
    for item in items:
        if not (item is Dictionary):
            continue
        var gear: Dictionary = item
        var uid := str(gear.get("uid",""))
        if uid.is_empty() or str(gear.get("slot","")).is_empty() or not _matches(gear,str(ui.get("_auction_category"))):
            continue
        if first.is_empty():
            first = uid
        if chosen == uid:
            found = true
        var b := _button(str(gear.get("icon","◆")))
        b.name = "PPARealAuctionSellUID_" + uid
        b.tooltip_text = str(gear.get("name","Предмет"))
        b.custom_minimum_size = Vector2(48,48)
        var border: Color = GOLD if chosen == uid else RARITY_COLORS.get(str(gear.get("rarity","common")).to_lower(),MUTED)
        b.add_theme_stylebox_override("normal",_skin(Color("#141B20"),border,4))
        var loader: Node = ui.get("_preview_icons")
        if loader != null:
            loader.call("bind_button",gear,"",b)
        b.pressed.connect(_select_sale.bind(ui,uid))
        grid.add_child(b)
    if not found:
        chosen = first
        ui.set("_auction_sell_uid",chosen)
    if not verified:
        # An empty inventory grid is a layout placeholder, NOT player items.
        # Never invent owned gear or enable operations without a signed state.
        for cell in range(20):
            var empty := _button("·",false)
            empty.name = "PPAAuctionOfflineEmptySlot_" + str(cell)
            empty.custom_minimum_size = Vector2(48,48)
            grid.add_child(empty)
        main.add_child(_label("Сетка выбора готова. Предметы появятся после подключения аукциона к сохранению персонажа.",11,MUTED))
    elif chosen.is_empty():
        main.add_child(_label("Нет доступной для продажи экипировки. Продажа стопок ресурсов требует отдельной защищённой операции сервера.",11,MUTED))
    else:
        for item in items:
            if item is Dictionary and str(item.get("uid","")) == chosen:
                main.add_child(_label("Выбрано: " + str(item.get("name","Предмет")),12,GOLD))
                break
    main.add_child(_label("Количество: 1 шт. · Срок: 24 часа (ограничение текущего серверного escrow).",11,MUTED))
    var price := SpinBox.new()
    price.name = "PPARealAuctionPrice"
    price.min_value = 1
    price.max_value = 999999999
    price.step = 1
    price.value = float(ui.get("_asking_price"))
    main.add_child(_label("Цена за вещь",12,GOLD))
    main.add_child(price)
    var currencies := OptionButton.new()
    currencies.name = "PPARealAuctionCurrency"
    currencies.add_item("PPA")
    currencies.add_item("Gram")
    currencies.select(0 if str(ui.get("_asking_currency")) == "PPA" else 1)
    main.add_child(_label("Валюта (Gold не используется)",12,GOLD))
    main.add_child(currencies)
    var preview := _label("После комиссии 10%: " + str(snappedf(price.value*0.9,0.01)) + " " + str(ui.get("_asking_currency")),12,GOLD)
    preview.name = "PPAAuctionSellerNet"
    main.add_child(preview)
    price.value_changed.connect(_sale_price_changed.bind(ui,preview))
    currencies.item_selected.connect(_sale_currency_changed.bind(ui,preview))
    var actions: Array = ui.get("auction_actions")
    var enabled: bool = verified and actions.has("place") and bool(state.get("settlementEnabled",false)) and not bool(ui.get("auction_loading")) and not bool(ui.get("auction_pending")) and not chosen.is_empty() and int(state.get("maxSellSlots",0)) > state.get("mine",[]).size()
    var place := _button("ВЫСТАВИТЬ ЛОТ",enabled)
    place.name = "PPARealAuctionPlace"
    place.pressed.connect(Callable(ui,"_auction_place_selected"))
    main.add_child(place)
    main.add_child(_label("Вещь и деньги меняются только после подтверждения общего сервера. Никаких локальных списаний.",10,MUTED))

static func _mine(ui: Control, main: VBoxContainer, state: Dictionary) -> void:
    _section(main,"МОИ ЛОТЫ (" + str(state.get("mine",[]).size()) + "/" + str(state.get("maxSellSlots",0)) + ")")
    _lots(ui,main,state.get("mine",[]),true)
    _section(main,"ИСТЁКШИЕ · ВОЗВРАТ ВЕЩЕЙ")
    var recoverable: Array = state.get("recoverable",[])
    var actions: Array = ui.get("auction_actions")
    if recoverable.is_empty():
        main.add_child(_label("Непроданных вещей на возврат нет.",11,MUTED))
    for entry in recoverable.slice(0,50):
        if not (entry is Dictionary):
            continue
        var lot: Dictionary = entry
        var item: Dictionary = lot.get("item",{})
        main.add_child(_label(str(item.get("name","Предмет PPA")),12,TEXT))
        var enabled: bool = actions.has("recover") and bool(lot.get("canRecover",false)) and bool(state.get("settlementEnabled",false)) and not bool(ui.get("auction_loading")) and not bool(ui.get("auction_pending")) and state.get("bag",[]).size() < 100
        var reclaim := _button("ВЕРНУТЬ В СУМКУ",enabled)
        reclaim.name = "PPARealAuctionRecover_" + str(lot.get("id",""))
        reclaim.pressed.connect(Callable(ui,"_auction_recover_lot").bind(str(lot.get("id",""))))
        main.add_child(reclaim)
    _section(main,"ВЫРУЧКА ОТ ПРОДАЖ")
    var credits: Array = state.get("pendingCredits",[])
    if credits.is_empty():
        main.add_child(_label("Ожидающих выплат нет.",11,MUTED))
    for entry in credits.slice(0,30):
        if not (entry is Dictionary):
            continue
        var credit: Dictionary = entry
        var currency := str(credit.get("currency","ppa")).to_lower()
        _coin_line(main,"Ожидает начисления",credit.get("amount","—"),currency)
        if actions.has("claim") and bool(state.get("serverCreditClaimsEnabled",false)) and bool(credit.get("canClaim",false)):
            var claim := _button("ПОЛУЧИТЬ",not bool(ui.get("auction_loading")) and not bool(ui.get("auction_pending")))
            claim.name = "PPARealAuctionClaim_" + str(credit.get("id",""))
            claim.pressed.connect(Callable(ui,"_auction_claim_credit").bind(str(credit.get("id",""))))
            main.add_child(claim)
    if not bool(state.get("serverCreditClaimsEnabled",false)):
        main.add_child(_label("Начисления видны, но серверное получение пока не включено. Это предотвращает двойную выплату с Telegram.",11,MUTED))

static func render(ui: Control) -> void:
    var body: VBoxContainer = ui.get("_body")
    _banner(body)
    var notice := str(ui.get("auction_notice"))
    if not notice.is_empty():
        body.add_child(_label(notice,12,GOLD))
    if bool(ui.get("auction_pending")):
        var retry := _button("ПРОВЕРИТЬ РЕЗУЛЬТАТ",not bool(ui.get("auction_loading")))
        retry.name = "PPAAuctionRetrySameRequest"
        retry.pressed.connect(func(): ui.emit_signal("auction_retry_requested"))
        body.add_child(retry)
    var refresh := _button("↻ ОБНОВИТЬ АУКЦИОН",not bool(ui.get("auction_loading")))
    refresh.name = "PPAAuctionRefresh"
    refresh.pressed.connect(func(): ui.emit_signal("authoritative_state_requested","auction"))
    body.add_child(refresh)
    var state: Dictionary = ui.get("auction_state")
    var verified: bool = bool(ui.call("_owns_verified_state",state))
    if not verified:
        _section(body,"СЕРВЕР АУКЦИОНА ПОКА НЕДОСТУПЕН",
            "Вкладки, категории, поиск и окно продажи работают для просмотра. Настоящие лоты и предметы загрузятся после подключения PPA.")
        var locked := _button("ПОКУПКИ И ПРОДАЖИ · ОЖИДАЕМ СЕРВЕР",false)
        locked.name = "ServerActionLocked"
        body.add_child(locked)
    var wide := ui.size.x >= 680
    var content: BoxContainer = HBoxContainer.new() if wide else VBoxContainer.new()
    content.name = "PPAAuctionLayout"
    content.add_theme_constant_override("separation",6)
    body.add_child(content)
    var sidebar := VBoxContainer.new()
    sidebar.name = "PPAAuctionSidebar"
    if wide:
        sidebar.custom_minimum_size.x = 160
    content.add_child(sidebar)
    _make_categories(ui,sidebar,not wide)
    var main := VBoxContainer.new()
    main.name = "PPAAuctionMainPanel"
    main.add_theme_constant_override("separation",6)
    main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_child(main)
    var tab := str(ui.get("tab"))
    if tab == "all":
        _section(main,"ПОКУПКА","Общий рынок PPA · цены за штуку")
        _filters(ui,main)
        if verified:
            _lots(ui,main,state.get("lots",[]),false)
        else:
            _section(main,"ОБЪЯВЛЕНИЯ ВРЕМЕННО НЕДОСТУПНЫ",
                "Поиск и фильтры готовы. Не показываем выдуманные лоты, пока сервер не подтвердил объявления.")
    elif tab == "sell":
        _sell(ui,main,state,verified)
    elif tab == "mine":
        if verified:
            _mine(ui,main,state)
        else:
            _section(main,"МОИ ЛОТЫ","Здесь появятся активные продажи, возврат непроданных вещей и выручка.")
            _section(main,"ИСТЁКШИЕ ЛОТЫ","Сведения появятся после подключения сервера.")
            _section(main,"ВЫРУЧКА ОТ ПРОДАЖ","Неизвестный баланс не заменяем нулём.")
    else:
        _section(main,"ВЫБЕРИ РАЗДЕЛ","Купить · Продать · Мои лоты")
