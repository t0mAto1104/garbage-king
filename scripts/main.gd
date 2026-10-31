extends Control

const Data = preload("res://scripts/data_loader.gd")
const State = preload("res://scripts/game_state.gd")
const Economy = preload("res://scripts/economy.gd")
const Save = preload("res://scripts/save_service.gd")
const Garage = preload("res://scripts/garage.gd")
const Progress = preload("res://scripts/progress_strip.gd")
const CREAM := Color("f2ead6")
const MUTED := Color("b3b5ad")
const GOLD := Color("f1ce71")
var state: StompState
var garage: StompGarage
var wallet_label: Label
var crushed_label: Label
var timer_label: Label
var can_title: Label
var can_details: Label
var toast_label: Label
var auto_label: Label
var objective: Label
var objective_details: Label
var goal_bar: Control
var hp_bar: Control
var rows := {}
var tab_buttons: Array[Button] = []
var content: Control
var overlay: Control
var modal_panel: Panel
var sound_button: Button
var tab := 0
var toast_time := 0.0
var save_time := 0.0
var last_second := -1
var last_save_error := false
var sounds := {}
var voice_index := 0
var voices: Array[AudioStreamPlayer] = []
var modal_kind := ""
var ui_font: SystemFont
var test_mode := false
var feed_label: Label
var selected_serial := -1
var target_panel: Panel

func _ready() -> void:
	test_mode = "--test-mode" in OS.get_cmdline_user_args()
	get_window().min_size = Vector2i(960,540)
	get_window().title = "Can Stomper · 经典参考"
	get_window().content_scale_size = Vector2i(1280,720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_font = SystemFont.new()
	ui_font.font_names = PackedStringArray(["PingFang SC", "Microsoft YaHei", "Noto Sans CJK SC", "Avenir Next", "sans-serif"])
	var ui_theme := Theme.new()
	ui_theme.default_font = ui_font
	ui_theme.default_font_size = 16
	theme = ui_theme
	var config := Data.load_config()
	if config.has("error"):
		label(self,Rect2(90,160,1100,180),"无法启动车库\n"+config.error+"\n请检查 data/demo_balance.json 后重新运行。",24,CREAM)
		return
	state = State.new(config)
	var warning := "" if test_mode else Save.read_into(state)
	if not warning.is_empty():
		# Preserve the corrupt source so the next automatic save cannot destroy it.
		DirAccess.copy_absolute(ProjectSettings.globalize_path(Save.PATH),ProjectSettings.globalize_path(Save.PATH+".corrupt"))
	garage = Garage.new()
	garage.state = state
	add_child(garage)
	state.hit.connect(garage.on_hit)
	state.auto_completed.connect(garage.on_auto)
	state.hit.connect(_on_hit)
	state.auto_completed.connect(_on_auto)
	state.purchased.connect(_on_purchase)
	state.changed.connect(refresh)
	state.summary_due.connect(func(): show_modal("summary"))
	build_ui()
	for name in ["hit","crush","coin","buy"]:
		sounds[name] = load("res://assets/audio/"+name+".wav")
	for i in range(4):
		var player := AudioStreamPlayer.new()
		player.volume_db = -10
		add_child(player)
		voices.append(player)
	refresh()
	if not warning.is_empty():
		toast(warning,8)
	get_window().focus_exited.connect(_on_focus_exited)
	get_tree().auto_accept_quit = false

func style(bg: Color, border: Color = Color.TRANSPARENT, radius: int = 5) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 10
	box.content_margin_right = 10
	return box

func panel(parent: Node, rect: Rect2, color: Color, border: Color = Color.TRANSPARENT) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel",style(color,border))
	parent.add_child(node)
	return node

func label(parent: Node, rect: Rect2, text: String, font_size: int = 16, color: Color = CREAM) -> Label:
	var node := Label.new()
	node.position = rect.position
	node.size = rect.size
	node.text = text
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func button(parent: Node, rect: Rect2, text: String, action: Callable, accent: bool = false) -> Button:
	var node := Button.new()
	node.position = rect.position
	node.size = rect.size
	node.text = text
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_size_override("font_size",14)
	node.add_theme_color_override("font_color",Color("172c2a") if accent else CREAM)
	node.add_theme_color_override("font_hover_color",Color("172c2a") if accent else Color.WHITE)
	node.add_theme_color_override("font_focus_color",Color("172c2a") if accent else CREAM)
	node.add_theme_color_override("font_disabled_color",Color("90978f"))
	node.add_theme_stylebox_override("normal",style(Color("b5ce8b") if accent else Color("303b43"),Color("56605e")))
	node.add_theme_stylebox_override("hover",style(Color("d1e3a8") if accent else Color("43525b"),GOLD))
	node.add_theme_stylebox_override("pressed",style(Color("8ea76b") if accent else Color("202d35"),GOLD))
	node.add_theme_stylebox_override("disabled",style(Color("343c40"),Color("434b4d")))
	var focus := style(Color.TRANSPARENT,GOLD)
	focus.set_border_width_all(2)
	node.add_theme_stylebox_override("focus",focus)
	node.pressed.connect(func(): node.release_focus(); action.call())
	parent.add_child(node)
	return node

func texture(parent: Node, rect: Rect2, path: String) -> TextureRect:
	var node := TextureRect.new()
	node.position = rect.position
	node.size = rect.size
	node.texture = load(path)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func bar(parent: Node, rect: Rect2, color: Color) -> Control:
	var node := Progress.new()
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.fill_color = color
	parent.add_child(node)
	return node

func build_ui() -> void:
	panel(self,Rect2(0,0,300,720),Color("202932"))
	panel(self,Rect2(298,0,3,720),Color("101c23"))
	label(self,Rect2(22,22,260,35),"CAN STOMPER",25)
	panel(self,Rect2(20,89,260,1),Color("424b50"))
	texture(self,Rect2(20,105,40,40),"res://assets/art/coin.png")
	wallet_label = label(self,Rect2(70,100,209,49),"0",36,GOLD)
	crushed_label = label(self,Rect2(23,156,250,24),"已踩扁   0 个",16)
	tab_buttons.append(button(self,Rect2(20,218,127,36),"属性升级",func(): set_tab(0)))
	tab_buttons.append(button(self,Rect2(153,218,127,36),"自动工坊",func(): set_tab(1)))
	content = Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	build_rows()
	panel(self,Rect2(20,652,260,1),Color("424b50"))
	button(self,Rect2(20,666,84,32),"重置试玩",func(): show_modal("reset"))
	panel(self,Rect2(320,18,210,48),Color("283037e8"),Color("5a5b55"))
	label(self,Rect2(335,27,185,26),"回收工坊",19)
	timer_label = label(self,Rect2(903,25,128,30),"00:00 / 10:00",15,CREAM)
	button(self,Rect2(1035,22,58,36),"玩法",func(): show_modal("help"))
	button(self,Rect2(580,22,100,36),"返回新工坊",func():
		persist()
		get_window().content_scale_size=Vector2i(2560,1440)
		get_tree().change_scene_to_file("res://scenes/yard.tscn"))
	sound_button = button(self,Rect2(1101,22,78,36),"声音 开",toggle_sound)
	button(self,Rect2(1187,22,73,36),"暂停",func(): show_modal("pause"))
	auto_label = label(self,Rect2(1040,268,182,36),"独立生产 · 等待启用",13,Color("484c43"))
	auto_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_panel = panel(self,Rect2(640,96,370,76),Color("29343be8"),Color("65695f"))
	can_title = label(self,Rect2(651,104,348,28),"",18,CREAM)
	can_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	can_details = label(self,Rect2(650,135,350,25),"",12,Color("d1d4bf"))
	can_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_bar = bar(self,Rect2(771,166,108,3),Color("d6b45d"))
	panel(self,Rect2(320,177,278,35),Color("29343be8"),Color("65695f"))
	feed_label = label(self,Rect2(332,182,255,24),"",14,CREAM)
	panel(self,Rect2(320,632,940,70),Color("293238f5"),Color("63675c"))
	objective = label(self,Rect2(338,643,390,25),"",15,CREAM)
	objective_details = label(self,Rect2(338,671,390,19),"",11,MUTED)
	goal_bar = bar(self,Rect2(775,665,455,5),Color("c7d597"))
	label(self,Rect2(776,642,455,20),"01 蓝罐    /    02 金罐    /    03 自动机    /    04 传送带",11,CREAM)
	toast_label = label(self,Rect2(460,105,560,44),"",15,CREAM)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_stylebox_override("normal",style(Color("27343bea")))
	toast_label.visible = false
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	overlay.visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.04,.07,.09,.77)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	modal_panel = panel(overlay,Rect2(395,135,490,450),Color("25323b"),Color("a3b48b"))
	modal_panel.mouse_filter = Control.MOUSE_FILTER_STOP

func build_rows() -> void:
	for child in content.get_children():
		child.queue_free()
	rows.clear()
	var ids := ["power","value","speed","blue_can","gold_can"] if tab == 0 else ["feed_speed","auto_stomper","auto_speed","conveyor"]
	var names := {"power":"脚力强化","value":"回收溢价","speed":"踩踏节奏","blue_can":"厚壁饮料罐","gold_can":"闪亮收藏罐","feed_speed":"供罐速度","auto_stomper":"自动踩踏机","auto_speed":"自动踩踏加速","conveyor":"自动线传送带"}
	var descriptions := {"power":"每级 +1 踩踏伤害","value":"每级 +30% 回收收益","speed":"每级 -0.10 秒间隔","blue_can":"解锁更值钱的厚壁罐","gold_can":"解锁稀有金色收藏罐","feed_speed":"加速初始供罐传送带","auto_stomper":"独立生产，无需悬停","auto_speed":"自动生产间隔缩短","conveyor":"自动线耗时 × 75%"}
	for i in range(ids.size()):
		var id: String = ids[i]
		var row := panel(content,Rect2(20,266+i*76,260,68),Color("29353e"),Color("485254"))
		var path := "res://assets/art/shoe.png"
		if id == "value": path = "res://assets/art/coin.png"
		if id == "blue_can": path = "res://assets/art/can_blue_0.png"
		if id == "gold_can": path = "res://assets/art/can_gold_0.png"
		if id in ["feed_speed","auto_stomper","auto_speed","conveyor"]: path = "res://assets/placeholders/auto_stomper.png"
		texture(row,Rect2(8,10,38,45),path)
		label(row,Rect2(53,7,131,23),names[id],16)
		var level := label(row,Rect2(53,31,129,17),"",11,MUTED)
		var buy := button(row,Rect2(183,11,69,29),"",func(): state.purchase(id),true)
		buy.tooltip_text = descriptions[id]
		var status := label(row,Rect2(53,49,199,16),"",10,MUTED)
		rows[id] = {"level":level,"button":buy,"status":status,"description":descriptions[id]}

func set_tab(value: int) -> void:
	if tab == value:
		return
	tab = value
	build_rows()
	refresh()

func refresh() -> void:
	if wallet_label == null:
		return
	wallet_label.text = str(state.coins)
	var second := int(state.elapsed)
	timer_label.text = "%02d:%02d / 10:00" % [second/60,second%60]
	crushed_label.text = "已踩扁   %d 个" % state.crushed
	for i in range(tab_buttons.size()):
		tab_buttons[i].add_theme_stylebox_override("normal",style(Color("347b88") if i == tab else Color("303b43"),Color("60969b") if i == tab else Color("56605e")))
	for id in rows:
		var row: Dictionary = rows[id]
		var price := state.price(id)
		var reason := state.blocked_reason(id)
		row.button.text = str(price) if price >= 0 else "完成"
		row.button.disabled = not reason.is_empty()
		row.level.text = "Lv. %d / %d" % [state.levels[id],state.upgrades[id].max_level] if state.levels.has(id) else ""
		row.status.text = row_stat(id)
		if id == "feed_speed":
			var level: int = state.levels.feed_speed
			var intervals: Array = state.config.gameplay.feed_intervals_seconds
			row.status.text = "%.2f → %.2f 秒 / 罐" % [intervals[level],intervals[mini(level+1,intervals.size()-1)]] if level < int(state.upgrades.feed_speed.max_level) else "最快 %.2f 秒 / 罐" % intervals[level]
		row.button.tooltip_text = reason if not reason.is_empty() else "花费 %d 金币 · %s" % [price,row.description]
	update_target_info()
	feed_label.text = "%.2f 秒 / 罐   →" % Economy.feed_interval(state.config,state.levels)
	auto_label.visible = state.unlocks.auto_stomper
	if state.unlocks.auto_stomper:
		auto_label.text = "%d 罐  ·  %.1fs / 罐" % [state.auto_crushed,Economy.auto_interval(state.config,state.levels,state.unlocks)]
	var next := ""
	var completed := 0
	for id in ["blue_can","gold_can","auto_stomper","conveyor"]:
		if state.unlocks[id]:
			completed += 1
		elif next.is_empty():
			next = id
	goal_bar.value = completed*25
	if next.is_empty():
		objective.text = "全部解锁"
		objective_details.text = "累计 %d 金币" % state.earned
	else:
		var u: Dictionary = state.unlock_defs[next]
		objective.text = u.name
		objective_details.text = "%d / %d 罐   ·   %d 金币" % [mini(state.crushed,int(u.requires_crushed)),u.requires_crushed,u.cost]
	sound_button.text = "声音 关" if state.settings.muted else "声音 开"

func row_stat(id: String) -> String:
	match id:
		"power":
			return "伤害 %d" % Economy.damage(state.config,state.levels)
		"value":
			return "收益 ×%.1f" % (1+float(state.config.gameplay.coin_value_bonus_per_level)*state.levels.value)
		"speed":
			return "%.2fs / 脚" % Economy.cooldown(state.config,state.levels)
		"auto_speed":
			return "%.1fs / 罐" % Economy.auto_interval(state.config,state.levels,state.unlocks) if state.unlocks.auto_stomper else "需自动踩踏机"
	if state.unlock_defs.has(id):
		if state.unlocks[id]: return ""
		var d: Dictionary = state.unlock_defs[id]
		if d.has("requires_unlock") and not state.unlocks[d.requires_unlock]: return "需自动踩踏机"
		return "%d / %d 罐" % [mini(state.crushed,int(d.requires_crushed)),d.requires_crushed]
	return ""

func update_target_info() -> void:
	var item := state.field.at_point(get_global_mouse_position())
	selected_serial = int(item.id) if not item.is_empty() else -1
	var count := state.field.pending_count()
	if item.is_empty():
		target_panel.size.y = 44
		can_title.text = "待踩 %d" % count
		can_details.text = ""
		hp_bar.visible = false
	else:
		target_panel.size.y = 76
		can_title.text = state.cans[item.kind].name
		can_details.text = "%d / %d HP    +%d 金币" % [item.hp,item.max_hp,Economy.reward(state.config,state.levels,state.cans[item.kind])]
		hp_bar.visible = true
		hp_bar.value = 100.0*item.hp/item.max_hp

func _process(delta: float) -> void:
	if state == null:
		return
	# Simulation stops on window blur or pause; never catch up wall-clock time.
	state.advance(minf(delta,.1))
	var hovered := state.field.at_point(get_global_mouse_position())
	if not state.paused and get_window().has_focus() and not hovered.is_empty():
		state.stomp(int(hovered.id))
	if (int(hovered.id) if not hovered.is_empty() else -1) != selected_serial:
		update_target_info()
	var second := int(state.elapsed)
	if second != last_second:
		last_second = second
		timer_label.text = "%02d:%02d / 10:00" % [second/60,second%60]
	if not state.paused:
		save_time += delta
		if save_time >= 8.0:
			save_time = 0
			persist()
	toast_time = maxf(0,toast_time-delta)
	toast_label.visible = toast_time > 0

func _unhandled_input(event: InputEvent) -> void:
	if state == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if overlay.visible:
				close_modal()
			else:
				show_modal("pause")
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE and not state.paused and get_window().has_focus():
			garage.keyboard_impact = true
			var target := state.field.at_point(get_global_mouse_position())
			state.stomp(int(target.id) if not target.is_empty() else -1)
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and garage.hovering(get_global_mouse_position()):
		var target := state.field.at_point(get_global_mouse_position())
		if not target.is_empty(): state.stomp(int(target.id))

func _on_hit(item: Dictionary, _amount: int) -> void:
	play_sound("crush" if item.claimed else "hit",item.kind)
	if item.claimed:
		persist()

func _on_auto(_amount: int) -> void:
	play_sound("coin")
	persist()

func _on_purchase(id: String) -> void:
	play_sound("buy")
	var name: String = state.upgrades[id].name if state.upgrades.has(id) else state.unlock_defs[id].name
	toast("已升级 · "+name)
	persist()

func play_sound(id: String, kind: String = "red") -> void:
	if state.settings.muted or voices.is_empty():
		return
	var player := voices[voice_index % voices.size()]
	voice_index += 1
	player.stream = sounds[id]
	player.pitch_scale = 1.0 if id != "hit" else {"red":1.12,"blue":.87,"gold":1.35}[kind]
	player.play()

func toast(message: String, seconds: float = 2.8) -> void:
	toast_label.text = message
	toast_time = seconds
	toast_label.visible = true

func toggle_sound() -> void:
	state.settings.muted = not state.settings.muted
	if state.settings.muted:
		for voice in voices:
			voice.stop()
	refresh()
	persist()

func persist() -> void:
	if test_mode:
		return
	var error := Save.write(state)
	if error != OK and not last_save_error:
		last_save_error = true
		toast("存档写入失败，请检查磁盘权限。",6)

func show_modal(kind: String) -> void:
	state.paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	modal_kind = kind
	overlay.visible = true
	for child in modal_panel.get_children():
		child.queue_free()
	var titles := {"pause":"已暂停","help":"玩法","reset":"重新开始试玩？","summary":"试玩总结"}
	label(modal_panel,Rect2(30,27,435,42),titles[kind],25)
	var body := "传送带持续送罐，初始每秒一只。\n落地弹跳、滚动停稳，不踩就会越积越多。\n\n鞋尖悬停任意一罐，自动连续踩踏。\n空格踩一只；Esc 暂停。\n在自动工坊升级供罐速度，最多四级。\n独立自动线另行生产，双线赚金币。"
	if kind == "pause":
		body = "已踩扁  %d 罐\n\n累计  %d 金币\n\n游玩  %02d:%02d" % [state.crushed,state.earned,int(state.elapsed)/60,int(state.elapsed)%60]
	if kind == "summary":
		var upgrades_count := 0
		for value in state.levels.values(): upgrades_count += int(value)
		body = "已踩扁  %d 罐\n累计  %d 金币\n\n手动 %d  /  自动 %d\n升级 %d 次\n\n自动机：%s  ·  自动线传送带：%s" % [state.crushed,state.earned,state.manual_crushed,state.auto_crushed,upgrades_count,"已启用" if state.unlocks.auto_stomper else "未启用","已启用" if state.unlocks.conveyor else "未启用"]
	if kind == "reset":
		body = "将清空这台设备上的本游戏试玩进度：\n\n金币、等级、解锁设备、试玩时间。\n\n这个操作无法撤销。"
	var body_label := label(modal_panel,Rect2(31,114,428,220),body,16,Color("d4dbd3"))
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if kind == "reset":
		button(modal_panel,Rect2(31,363,200,48),"取消",close_modal)
		button(modal_panel,Rect2(246,363,213,48),"确认重置",reset_demo,true)
	else:
		var toggle := CheckButton.new()
		toggle.position = Vector2(26,319)
		toggle.size = Vector2(300,35)
		toggle.text = "减弱特效与震动"
		toggle.button_pressed = state.settings.reduced
		toggle.toggled.connect(func(value): state.settings.reduced = value; persist())
		modal_panel.add_child(toggle)
		var resume := button(modal_panel,Rect2(31,369,428,48),"继续回收" if kind != "help" else "明白了，开踩！",close_modal,true)
		resume.grab_focus()
	refresh()
	persist()

func close_modal() -> void:
	overlay.visible = false
	state.paused = false
	modal_kind = ""
	# Drop GUI focus to ensure Space works as the advertised stomp alternative.
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null: focus.release_focus()
	refresh()

func reset_demo() -> void:
	var fresh := State.new(state.config)
	state.restore(fresh.snapshot())
	state.auto_progress = 0
	state.cooldown_left = 0
	garage.particles.clear()
	garage.impact = 0
	garage.machine_flash = 0
	last_second = -1
	persist()
	close_modal()
	toast("全新的车库，第一脚开始。")

func _on_focus_exited() -> void:
	if state != null and not state.paused and not test_mode:
		show_modal("pause")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if state != null:
			persist()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().quit()
