extends Control

const Data = preload("res://scripts/yard/yard_data.gd")
const Model = preload("res://scripts/yard/yard_state.gd")
const View = preload("res://scripts/yard/yard_view.gd")
const Store = preload("res://scripts/yard/yard_save.gd")
const Economy = preload("res://scripts/yard/yard_economy.gd")
const S := 2.0
const CREAM := Color("ede8d4")
const MUTED := Color("a5b5ae")
const GOLD := Color("ecd088")
const MINT := Color("aed2ba")
const DARK := Color("20333c")
var state: YardState
var world: YardView
var ui_font: SystemFont
var test_mode := false
var tab := 0
var rows := {}
var content: Control
var tab_buttons: Array[Button] = []
var slots := {}
var wallet: Label
var count_label: Label
var chapter_label: Label
var target_label: Label
var event_label: Label
var flow_label: Label
var frenzy_button: Button
var frenzy_bar: Control
var magnet_button: Button
var combo_label: Label
var toast_label: Label
var toast_left := 0.0
var modal: Control
var modal_body: Panel
var modal_kind := ""
var last_second := -1
var save_timer := 0.0
var selected_id := -1
var goals := {}
var audio_players: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer
var motor: AudioStreamPlayer
var audio := {}
var voice := 0
var hit_sound_age := 1.0
var saved_error := false

func _ready() -> void:
	test_mode = "--test-mode" in OS.get_cmdline_user_args()
	get_window().min_size = Vector2i(1152,648)
	get_window().title = "垃圾王 · 传送工坊"
	get_window().content_scale_size = Vector2i(2560,1440)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_font = SystemFont.new()
	ui_font.font_names = PackedStringArray(["PingFang SC","Microsoft YaHei","Noto Sans CJK SC","sans-serif"])
	var theme_data := Theme.new()
	theme_data.default_font = ui_font
	theme_data.default_font_size = 28
	theme = theme_data
	var data := Data.load_config()
	if data.has("error"):
		text(self,Rect2(150,200,900,200),data.error,24,CREAM)
		return
	state = Model.new(data)
	var note := "" if test_mode else Store.load_into(state)
	world = View.new()
	world.state = state; world.font = ui_font
	add_child(world)
	build_ui()
	build_audio()
	state.changed.connect(refresh)
	state.hit.connect(world.on_hit)
	state.hit.connect(on_hit)
	state.auto_completed.connect(world.on_auto)
	state.purchased.connect(on_purchase)
	state.event_started.connect(on_event)
	state.milestone.connect(on_milestone)
	get_window().focus_exited.connect(func():
		if not state.paused and not test_mode: show_modal("pause"))
	get_tree().auto_accept_quit = false
	refresh()
	if not note.is_empty(): toast(note)
	if not test_mode: persist()

func box(color: Color, border: Color = Color.TRANSPARENT, radius: int = 5) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color=color; result.border_color=border
	result.set_border_width_all(2); result.set_corner_radius_all(radius*2)
	result.content_margin_left=10; result.content_margin_right=10
	return result

func place(node: Control, rect: Rect2) -> void:
	node.position=rect.position*S; node.size=rect.size*S

func panel(parent: Node, rect: Rect2, color: Color, border: Color = Color.TRANSPARENT) -> Panel:
	var node := Panel.new()
	place(node,rect); node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel",box(color,border))
	parent.add_child(node)
	return node

func text(parent: Node, rect: Rect2, value: String, font_size: int = 15, color: Color = CREAM) -> Label:
	var node := Label.new()
	place(node,rect); node.text=value; node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size",font_size*2)
	node.add_theme_color_override("font_color",color)
	parent.add_child(node)
	return node

func image_rect(parent: Node, rect: Rect2, path: String) -> TextureRect:
	var node := TextureRect.new()
	place(node,rect)
	node.texture=load(path); node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func button(parent: Node, rect: Rect2, title: String, action: Callable, accent: bool = false) -> Button:
	var node := Button.new()
	place(node,rect); node.text=title
	node.add_theme_font_size_override("font_size",26)
	node.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	node.add_theme_stylebox_override("normal",box(MINT if accent else Color("314b55"),Color("56716e")))
	node.add_theme_stylebox_override("hover",box(Color("c6dfbf") if accent else Color("416472"),GOLD))
	node.add_theme_stylebox_override("pressed",box(Color("80ac99") if accent else Color("213a45"),MINT))
	node.add_theme_stylebox_override("disabled",box(Color("30434a"),Color("445a5b")))
	node.add_theme_stylebox_override("focus",box(Color.TRANSPARENT,GOLD))
	for key in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]:
		node.add_theme_color_override(key,DARK if accent else CREAM)
	node.add_theme_color_override("font_disabled_color",Color("859b94"))
	node.pressed.connect(func(): node.release_focus(); action.call())
	parent.add_child(node)
	return node

func build_ui() -> void:
	panel(self,Rect2(0,0,300,720),Color("1c303a"))
	panel(self,Rect2(296,0,4,720),Color("112932"))
	text(self,Rect2(22,23,240,45),"垃圾王",31)
	image_rect(self,Rect2(22,89,32,32),"res://assets/art/coin.png")
	wallet=text(self,Rect2(66,78,215,50),"0",32,GOLD)
	count_label=text(self,Rect2(24,131,250,24),"",13,MUTED)
	for i in range(3):
		var index := i
		tab_buttons.append(button(self,Rect2(20+i*88,170,82,34),["改造","传送","档案"][i],func(): set_tab(index)))
	content=Control.new(); content.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(content)
	build_rows()
	button(self,Rect2(20,670,111,32),"经典 Demo",open_classic)
	button(self,Rect2(140,670,140,32),"设置",func(): show_modal("pause"))
	panel(self,Rect2(321,20,320,61),Color("213943ed"),Color("71867a"))
	chapter_label=text(self,Rect2(338,28,290,43),"",22)
	combo_label=text(self,Rect2(662,34,145,32),"",18,GOLD)
	event_label=text(self,Rect2(826,28,270,40),"",16,Color("c2d5b6"))
	event_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	button(self,Rect2(1110,27,67,36),"小破",func(): show_modal("story"))
	button(self,Rect2(1185,27,73,36),"暂停",func(): show_modal("pause"))
	var goal_panel := panel(self,Rect2(660,89,287,62),Color("213943e8"),Color("617d73"))
	goal_panel.mouse_filter=Control.MOUSE_FILTER_PASS
	goal_panel.tooltip_text="工坊目标：电钻、深度 II、回收洗衣机"
	for i in range(3):
		var id: String=["drill","depth","washer"][i]
		var icon: String={"drill":state.tools.drill.visual,"depth":"res://assets/yard/portal.png","washer":state.catalog.washer.visual % 0}[id]
		var pic:=image_rect(goal_panel,Rect2(8+i*94,5,42,51),icon)
		var value:=text(goal_panel,Rect2(51+i*94,19,34,24),"",12,MUTED)
		goals[id]={"picture":pic,"value":value}
	flow_label=text(self,Rect2(395,171,200,28),"",12,Color("d5d4b5"))
	target_label=text(self,Rect2(800,585,420,31),"",13,Color("344c4e"))
	target_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	# Tools live immediately below the work floor, making selection spatial.
	panel(self,Rect2(322,641,937,65),Color("203a43ed"),Color("668579"))
	for i in range(4):
		var id: String = ["shoe","fist","hammer","drill"][i]
		var slot := button(self,Rect2(333+i*117,650,109,47),"",func(): state.equip(id))
		image_rect(slot,Rect2(5,4,28,38),state.tools[id].visual)
		text(slot,Rect2(37,7,66,30),"%d %s" % [i+1,["鞋","拳","锤","钻"][i]],14)
		slots[id]=slot
	frenzy_button=button(self,Rect2(820,650,204,47),"狂拆  F",func(): state.activate_frenzy(),true)
	frenzy_button.tooltip_text="拆解充能后，主动释放短时高速作业"
	frenzy_bar=preload("res://scripts/progress_strip.gd").new()
	place(frenzy_bar,Rect2(828,690,187,3)); frenzy_bar.fill_color=GOLD; frenzy_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(frenzy_bar)
	magnet_button=button(self,Rect2(1035,650,213,47),"归拢  R",gather)
	magnet_button.tooltip_text="磁力将附近废品拉向光标；未解锁时在传送页购买"
	toast_label=text(self,Rect2(614,99,610,40),"",15,CREAM)
	toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	modal=Control.new(); modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal); modal.visible=false
	var shade := ColorRect.new()
	shade.color=Color(.03,.09,.12,.80); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	modal_body=panel(modal,Rect2(374,138,534,444),DARK,Color("91ac96"))
	modal_body.mouse_filter=Control.MOUSE_FILTER_STOP

func row(parent: Node, rect: Rect2, id: String, name: String, icon: String, stat: String) -> void:
	var card := panel(parent,rect,Color("29434d"),Color("4d696b"))
	image_rect(card,Rect2(7,5,37,44),icon)
	text(card,Rect2(52,7,139,24),name,15)
	var info := text(card,Rect2(53,32,182,18),stat,11,MUTED)
	var buy := button(card,Rect2(188,12,63,32),"",func(): buy_item(id),true)
	rows[id]={"button":buy,"info":info,"card":card}
	if id.begins_with("tool:"):
		card.mouse_filter=Control.MOUSE_FILTER_PASS
		var tool_id:=id.trim_prefix("tool:")
		var details: String={"shoe":"单件踩踏","fist":"轻质 ×1.5","hammer":"金属 ×1.5 · 近邻震荡","drill":"机械 / 复合 ×1.5 · 连钻最高 ×2"}[tool_id]
		card.tooltip_text=details

func build_rows() -> void:
	for node in content.get_children(): node.queue_free()
	rows.clear()
	if tab==0:
		for i in range(4):
			var id: String = ["shoe","fist","hammer","drill"][i]
			row(content,Rect2(20,218+i*59,260,54),"tool:"+id,state.tools[id].name,state.tools[id].visual,"")
		for i in range(3):
			var id: String = ["power","value","speed"][i]
			row(content,Rect2(20,464+i*56,260,51),id,state.upgrades[id].name,"res://assets/yard/"+["hammer","magnet","scanner"][i]+".png","")
	elif tab==1:
		for i in range(5):
			var id: String = ["feed_speed","depth","quality","scanner","magnet"][i]
			row(content,Rect2(20,218+i*81,260,66),id,state.upgrades[id].name,"res://assets/yard/"+["portal","portal","portal","scanner","magnet"][i]+".png","")
	else:
		for i in range(state.config.trash.size()):
			var definition: Dictionary = state.config.trash[i]
			var card := panel(content,Rect2(20+(i%3)*88,218+(i/3)*61,82,55),Color("29434d"),Color("4a6668"))
			var pic := image_rect(card,Rect2(4,-1,48,52),definition.visual % 0)
			pic.modulate=Color.WHITE if int(state.discovered[definition.id])>0 else Color(.2,.3,.32)
			var tally := text(card,Rect2(49,16,30,24),str(state.recovered[definition.id]) if int(state.discovered[definition.id])>0 else "?",12,MUTED)
			card.tooltip_text=definition.name
			card.mouse_filter=Control.MOUSE_FILTER_PASS
			rows["entry:"+definition.id]={"picture":pic,"count":tally}
		for i in range(3):
			var id: String = ["auto_stomper","auto_speed","conveyor"][i]
			row(content,Rect2(20,419+i*74,260,64),id,state.upgrades[id].name,"res://assets/yard/auto.png","")

func set_tab(index: int) -> void:
	if index==tab: return
	tab=index; build_rows(); refresh()

func buy_item(id: String) -> void:
	if id.begins_with("tool:") and state.owned[id.trim_prefix("tool:")]:
		state.equip(id.trim_prefix("tool:"))
	else:
		state.purchase(id)

func refresh() -> void:
	if wallet==null: return
	wallet.text=str(state.coins)
	count_label.text="%d 已回收  ·  %d 待拆" % [state.crushed,state.field.pending_count()]
	chapter_label.text="%02d  %s" % [state.chapter()+1,state.config.chapters[state.chapter()]]
	for i in range(3): tab_buttons[i].add_theme_stylebox_override("normal",box(Color("487d7e") if i==tab else Color("2b434e"),Color("719a8d") if i==tab else Color("48666a")))
	for id in rows:
		var data: Dictionary=rows[id]
		if id.begins_with("entry:"):
			var kind: String = id.trim_prefix("entry:")
			data.picture.modulate=Color.WHITE if int(state.discovered[kind])>0 else Color(.2,.3,.32)
			data.count.text=str(state.recovered[kind]) if int(state.discovered[kind])>0 else "?"
			continue
		var cost := state.price(id)
		var reason := state.blocked_reason(id)
		var owned: bool = id.begins_with("tool:") and state.owned[id.trim_prefix("tool:")]
		data.button.text=("装备" if id.trim_prefix("tool:")!=state.equipped else "已装") if owned else (str(cost) if cost>=0 else "完成")
		data.button.disabled=(state.paused or id.trim_prefix("tool:")==state.equipped) if owned else not reason.is_empty()
		data.button.tooltip_text=reason if not reason.is_empty() else "回收金 %d" % cost
		data.info.text=row_stat(id)
	for id in slots:
		slots[id].disabled=not state.owned[id] or state.paused
		slots[id].add_theme_stylebox_override("normal",box(Color("3d686a") if id==state.equipped else Color("29434e"),MINT if id==state.equipped else Color("48666a")))
	for id in goals:
		var complete: bool=state.owned.drill if id=="drill" else (int(state.levels.depth)>=2 if id=="depth" else int(state.recovered.washer)>0)
		goals[id].picture.modulate=Color.WHITE if complete else Color(.58,.72,.68)
		goals[id].value.text=("II" if complete else str(state.levels.depth)+"/II") if id=="depth" else ("1/1" if complete else "0/1")
		goals[id].value.add_theme_color_override("font_color",MINT if complete else MUTED)
	refresh_timers()

func row_stat(id: String) -> String:
	if id.begins_with("tool:"):
		var definition: Dictionary=state.tools[id.trim_prefix("tool:")]
		return "%d 伤害  ·  %.2fs" % [int(definition.damage)+int(state.levels.power)*int(state.config.gameplay.power_per_level),Economy.cooldown(state.config,definition,state.levels,false)]
	var level: int=state.levels[id]
	match id:
		"power": return "Lv.%d / %d" % [level,state.upgrades[id].costs.size()]
		"value": return "×%.1f" % (1+float(state.config.gameplay.value_bonus_per_level)*level)
		"speed": return "Lv.%d  ·  %.2fs" % [level,state.cooldown()]
		"feed_speed": return "%.2fs → %.2fs" % [state.config.gameplay.feed_intervals_seconds[level],state.config.gameplay.feed_intervals_seconds[mini(level+1,state.config.gameplay.feed_intervals_seconds.size()-1)]]
		"depth": return ["生活废品 → 小电器","小电器 → 大型家电","大型家电"][level]
		"quality": return "Lv.%d / %d" % [level,state.upgrades[id].costs.size()]
		"scanner": return "已安装" if level>0 else "深度 I"
		"magnet": return "R  ·  %.0fs" % state.config.gameplay.magnet_cooldown
		"auto_stomper":
			var required: int=state.upgrades.auto_stomper.requires_crushed[0]
			return "%.1fs / 罐" % Economy.auto_interval(state.config,state.levels) if level>0 else "%d / %d 罐" % [mini(state.crushed,required),required]
		"auto_speed": return "%.1fs / 罐" % Economy.auto_interval(state.config,state.levels)
		"conveyor": return "×%.2f" % state.config.gameplay.conveyor_multiplier
	return ""

func refresh_timers() -> void:
	flow_label.text="%.2fs / 件" % state.feed_interval()
	frenzy_bar.value=100*state.energy/float(state.config.gameplay.frenzy_threshold)
	frenzy_button.disabled=state.paused or state.frenzy_left>0 or state.energy<float(state.config.gameplay.frenzy_threshold)
	frenzy_button.text="狂拆  %.1fs" % state.frenzy_left if state.frenzy_left>0 else "狂拆  F"
	magnet_button.disabled=state.paused or int(state.levels.magnet)==0 or state.magnet_left>0
	magnet_button.text="归拢  %.1fs" % state.magnet_left if state.magnet_left>0 else "归拢  R"
	combo_label.text="×%d 连拆" % state.combo if state.combo>1 else ""
	var event := state.event_definition()
	event_label.text="%s  %.0fs" % [event.name,state.event_left] if state.event_left>0 and not event.is_empty() else ""

func _process(delta: float) -> void:
	if state==null: return
	hit_sound_age+=delta
	state.advance(minf(delta,.1))
	var point := get_global_mouse_position()/S
	var target := state.field.at_point(point)
	if not state.paused and get_window().has_focus() and not target.is_empty(): state.attack(int(target.id),point)
	selected_id=int(target.id) if not target.is_empty() else -1
	if not target.is_empty():
		var material: String={"light":"轻质","metal":"金属","mechanical":"机械","composite":"复合"}[state.catalog[target.kind].material]
		target_label.text="%s · %s   %d / %d   +%d" % [state.catalog[target.kind].name,material,target.hp,target.max_hp,Economy.reward(state.config,state.catalog[target.kind],state.levels,1)]
	else: target_label.text=""
	refresh_timers()
	if not state.paused:
		save_timer+=delta
		if save_timer>=8:
			save_timer=0; persist()
	toast_left=maxf(0,toast_left-delta); toast_label.visible=toast_left>0
	if motor!=null:
		var running: bool = not state.paused and not state.settings.muted and state.equipped=="drill" and state.cooldown_left>0
		if running and not motor.playing: motor.play()
		if not running and motor.playing: motor.stop()

func _unhandled_input(event: InputEvent) -> void:
	if state==null: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE:
			if modal.visible: close_modal()
			else: show_modal("pause")
		elif event.keycode in [KEY_1,KEY_2,KEY_3,KEY_4]: state.equip(["shoe","fist","hammer","drill"][event.keycode-KEY_1])
		elif event.keycode==KEY_F: state.activate_frenzy()
		elif event.keycode==KEY_R: gather()
		elif event.keycode==KEY_SPACE and not state.paused:
			var target := state.field.at_point(get_global_mouse_position()/S)
			if target.is_empty(): target=state.field.keyboard_target()
			if not target.is_empty():
				world.keyboard_point=state.field.visual_position(target)
				state.attack(int(target.id))
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and not state.paused:
		var point := get_global_mouse_position()/S
		var target := state.field.at_point(point)
		if not target.is_empty(): state.attack(int(target.id),point)

func gather() -> void:
	var point := get_global_mouse_position()/S
	if not View.ARENA.has_point(point): point=Vector2(790,443)
	state.gather(point)

func build_audio() -> void:
	for id in ["hit","crush","coin","buy","yard_hammer","yard_fist","yard_portal"]: audio[id]=load("res://assets/audio/"+id+".wav")
	for i in range(5):
		var player := AudioStreamPlayer.new(); player.volume_db=-12
		add_child(player); audio_players.append(player)
	music=AudioStreamPlayer.new(); music.volume_db=-15
	var track: AudioStreamWAV=load("res://assets/audio/yard_music.wav")
	track.loop_mode=AudioStreamWAV.LOOP_FORWARD; track.loop_end=int(track.get_length()*track.mix_rate)
	music.stream=track; add_child(music)
	motor=AudioStreamPlayer.new(); motor.volume_db=-14
	var stream: AudioStreamWAV=load("res://assets/audio/yard_drill.wav")
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD; stream.loop_end=int(stream.get_length()*stream.mix_rate)
	motor.stream=stream; add_child(motor)
	update_music()

func sound(id: String) -> void:
	if state.settings.muted or audio_players.is_empty(): return
	var player := audio_players[voice%audio_players.size()]; voice+=1
	player.stream=audio[id]; player.play()

func update_music() -> void:
	if music==null: return
	if state.settings.muted or not state.settings.music or state.paused:
		music.stream_paused=true
	else:
		music.stream_paused=false
		if not music.playing and not test_mode: music.play()

func on_hit(item: Dictionary, payout: int, _damage: int, _weak: bool) -> void:
	if hit_sound_age>.08:
		sound("crush" if item.claimed else {"shoe":"hit","fist":"yard_fist","hammer":"yard_hammer","drill":"yard_fist"}[state.equipped])
		hit_sound_age=0
	if payout>0: persist()

func on_purchase(id: String) -> void:
	sound("buy"); persist()
	if id=="depth": sound("yard_portal")

func on_event(_id: String) -> void:
	var definition := state.event_definition()
	toast(definition.line,4)
	sound("yard_portal"); persist()

func on_milestone(id: String) -> void:
	show_modal(id)
	persist()

func toast(value: String, seconds: float = 3.0) -> void:
	toast_label.text=value; toast_left=seconds

func persist() -> void:
	if test_mode: return
	if Store.write(state)!=OK and not saved_error:
		saved_error=true; toast("存档写入失败",6)

func show_modal(kind: String) -> void:
	state.paused=true; modal_kind=kind; modal.visible=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	update_music()
	if motor!=null: motor.stop()
	for node in modal_body.get_children(): node.queue_free()
	var titles := {"pause":"工坊已暂停","story":"小破的工作日志","installed_fist":"第一只手，握住明天。","chapter_done":"这间工坊，归你了。","reset":"重新开工？"}
	text(modal_body,Rect2(28,24,478,45),titles[kind],25)
	if kind=="pause":
		var stats := text(modal_body,Rect2(29,86,476,70),"%d 已回收     %d 金币\n%02d:%02d" % [state.crushed,state.earned,int(state.elapsed)/60,int(state.elapsed)%60],17)
		stats.add_theme_constant_override("line_spacing",14)
		for i in range(3):
			var key: String=["muted","music","reduced"][i]
			var toggle := CheckButton.new(); place(toggle,Rect2(23,175+i*41,476,36))
			toggle.text={"muted":"静音","music":"背景音乐","reduced":"减弱特效"}[key]
			toggle.button_pressed=state.settings[key]
			toggle.toggled.connect(func(value): state.settings[key]=value; update_music(); persist())
			modal_body.add_child(toggle)
		button(modal_body,Rect2(29,322,476,38),"重置",func(): show_modal("reset"))
	elif kind=="story":
		var copy := text(modal_body,Rect2(29,84,476,250),"雨夜之后，你失去了双臂，也失去了原来的生活。\n\n一台被扔进仓库的旧机器，却打开了另一扇门。\n\n“跨维度废品转运系统，小破，为您服务。”\n\n从六块钱的汽水罐，到自己的机械义肢。\n这一次，未来握在自己手里。",16)
		copy.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	elif kind=="installed_fist":
		image_rect(modal_body,Rect2(53,100,132,205),state.tools.fist.visual)
		var copy := text(modal_body,Rect2(220,117,265,153),"机械义手已安装。\n\n指节合拢的第一声，\n不是结束，是开工。",19)
		copy.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	elif kind=="chapter_done":
		image_rect(modal_body,Rect2(45,98,160,184),state.catalog.washer.visual % 4)
		text(modal_body,Rect2(235,103,254,184),"%d 件废品\n%d 回收金\n\n旧仓库 → 回收工坊" % [state.crushed,state.earned],19)
	elif kind=="reset":
		text(modal_body,Rect2(29,112,476,190),"清空新工坊的金币、工具与废品堆。\n经典 Demo 的原存档会保留。\n\n此操作无法撤销。",17)
		button(modal_body,Rect2(29,372,225,45),"取消",close_modal)
		button(modal_body,Rect2(271,372,234,45),"确认重置",reset_yard,true)
		refresh(); return
	var resume := button(modal_body,Rect2(29,372,476,45),"开工" if kind=="installed_fist" else "继续",close_modal,true)
	resume.grab_focus()
	refresh()

func close_modal() -> void:
	modal.visible=false; modal_kind=""; state.paused=false
	var focus := get_viewport().gui_get_focus_owner()
	if focus!=null: focus.release_focus()
	update_music(); refresh()

func reset_yard() -> void:
	var fresh := Model.new(state.config)
	state.restore(fresh.snapshot())
	world.particles.clear(); world.impact=0
	close_modal(); persist()

func open_classic() -> void:
	persist(); Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	get_window().content_scale_size=Vector2i(1280,720)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:
		if state!=null: persist()
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
		get_tree().quit()
