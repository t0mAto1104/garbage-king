class_name StompGarage
extends Control

const Economy = preload("res://scripts/economy.gd")
const ARENA := Rect2(302, 96, 978, 535)
var state: StompState
var background: Texture2D = preload("res://assets/art/garage.png")
var shoe: Texture2D = preload("res://assets/art/shoe.png")
var coin: Texture2D = preload("res://assets/art/coin.png")
var frames := {}
var particles: Array[Dictionary] = []
var impact := 0.0
var age := 0.0
var machine_flash := 0.0
var pointer := Vector2.ZERO
var pointer_visible := false
var keyboard_impact := false
var last_hit_point := Vector2.ZERO
var text_font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for type in ["red", "blue", "gold"]:
		frames[type] = []
		for stage in range(5):
			frames[type].append(load("res://assets/art/can_%s_%d.png" % [type, stage]))
	text_font = SystemFont.new()
	text_font.font_names = PackedStringArray(["Avenir Next", "Microsoft YaHei", "PingFang SC", "sans-serif"])

func hovering(point: Vector2) -> bool:
	return state != null and not state.field.at_point(point).is_empty()

func hovered_can() -> Dictionary:
	return state.field.at_point(pointer) if state != null else {}

func on_hit(item: Dictionary, payout: int) -> void:
	impact = 1.0
	last_hit_point = state.field.visual_position(item)
	var crushed: bool = item.claimed
	var reduced: bool = state.settings.reduced
	var count := 3 if reduced else (18 if crushed else 6)
	for i in range(count):
		if particles.size() >= int(state.config.gameplay.max_vfx_objects):
			break
		var angle := float(i) * TAU / count
		particles.append({"p": last_hit_point + Vector2(0, 14), "v": Vector2(cos(angle)*randf_range(45,145),sin(angle)*85-100), "life": 0.7, "total": 0.7, "coin": crushed and i % 3 == 0, "text": ""})
	if crushed and particles.size() < int(state.config.gameplay.max_vfx_objects):
		particles.append({"p": last_hit_point + Vector2(24,-30), "v": Vector2(0,-45), "life": 1.15, "total": 1.15, "coin": false, "text": "+%d" % payout})

func on_auto(amount: int) -> void:
	machine_flash = 1.0
	if particles.size() < int(state.config.gameplay.max_vfx_objects):
		particles.append({"p": Vector2(1145,218), "v": Vector2(0,-28), "life": 1.1, "total": 1.1, "coin": false, "text": "+%d" % amount})

func _process(delta: float) -> void:
	if state == null:
		return
	pointer = get_global_mouse_position()
	pointer_visible = ARENA.has_point(pointer) and not state.paused and get_window().has_focus()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if pointer_visible else Input.MOUSE_MODE_VISIBLE
	if not state.paused:
		age += delta
		impact = maxf(0,impact-delta*6)
		machine_flash = maxf(0,machine_flash-delta*4)
		for p in particles:
			p.life -= delta
			p.p += p.v * delta
			if p.text.is_empty():
				p.v.y += 260*delta
		particles = particles.filter(func(p): return p.life > 0)
	queue_redraw()

func _draw() -> void:
	if state == null or frames.is_empty():
		return
	draw_texture_rect(background, Rect2(300,0,980,720),false)
	_draw_supply()
	_draw_machine()
	var ordered := state.field.items.duplicate()
	ordered.sort_custom(func(a,b): return a.id < b.id if a.pos.y == b.pos.y else a.pos.y < b.pos.y)
	for item in ordered:
		_draw_can(item)
	var hovered := hovered_can() if pointer_visible else {}
	if not hovered.is_empty():
		var center := state.field.visual_position(hovered)
		draw_arc(center,43,0,TAU,32,Color(1,.86,.52,.45),1,false)
		draw_arc(center,43,-PI*.5,-PI*.5+TAU*(1-state.cooldown_left/Economy.cooldown(state.config,state.levels)),32,Color("ffde87"),2,false)
	if impact > 0.35 and not state.settings.reduced:
		for i in range(7):
			var angle := i*TAU/7+age*.02
			var a := last_hit_point + Vector2(cos(angle)*34,sin(angle)*29)
			var b := last_hit_point + Vector2(cos(angle)*54,sin(angle)*46)
			draw_line(a,b,Color(1,.84,.46,impact),3)
	for p in particles:
		var alpha: float = minf(1.0,p.life/.28)
		if not p.text.is_empty():
			draw_string(text_font,p.p+Vector2(2,2),p.text,HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color(0.2,.14,.1,alpha))
			draw_string(text_font,p.p,p.text,HORIZONTAL_ALIGNMENT_LEFT,-1,26,Color(1,.86,.44,alpha))
		elif p.coin:
			draw_texture_rect(coin,Rect2(p.p,Vector2(26,26)),false,Color(1,1,1,alpha))
		else:
			draw_rect(Rect2(p.p,Vector2(5,4)),Color(.9,.79,.58,alpha))
	if pointer_visible or (keyboard_impact and impact > .05):
		var stomp_scale := 1.0-impact*.09
		var pos := last_hit_point if keyboard_impact and impact > .05 else pointer
		var scale_size := Vector2(119.6,182)*stomp_scale
		# Exact toe hotspot (46,26) in the 92x140 artwork, invariant while scaling.
		var toe := Vector2(46,26)*1.3*stomp_scale
		draw_texture_rect(shoe,Rect2(pos-toe+Vector2(4,7)*(1-impact),scale_size),false,Color(0,0,0,.16))
		draw_texture_rect(shoe,Rect2(pos-toe,scale_size),false)
	if impact <= .05:
		keyboard_impact = false

func _draw_can(item: Dictionary) -> void:
	var center := state.field.visual_position(item)
	var h: float = item.height
	if item.phase != "belt":
		draw_set_transform(item.pos+Vector2(0,12),0,Vector2(1,.32))
		draw_circle(Vector2.ZERO,maxf(12,28-h*.12),Color(.15,.13,.12,.23-h*.0015))
		draw_set_transform(Vector2.ZERO)
	var squish: float = item.impact*(.12 if not state.settings.reduced else .03)
	draw_set_transform(center,item.rotation,Vector2(1+squish,1-squish))
	var stage := Economy.stage(int(item.hp),int(item.max_hp))
	draw_texture_rect(frames[item.kind][stage],Rect2(-52,-52,104,104),false)
	draw_set_transform(Vector2.ZERO)
	if item.impact > .1 and not item.claimed:
		draw_rect(Rect2(center+Vector2(-22,-44),Vector2(44,3)),Color("5a6155"))
		draw_rect(Rect2(center+Vector2(-22,-44),Vector2(44.0*item.hp/item.max_hp,3)),Color("e3c97a"))

func _draw_supply() -> void:
	var x := 320.0
	var y := 220.0
	draw_rect(Rect2(x+9,y+33,267,13),Color(0,0,0,.2))
	for dx in [20,230]:
		draw_rect(Rect2(x+dx,y+22,10,46),Color("354249"))
		draw_rect(Rect2(x+dx-6,y+63,24,5),Color("465153"))
	draw_rect(Rect2(x,y,278,34),Color("28333b"))
	draw_rect(Rect2(x+3,y+3,272,23),Color("606b68"))
	var offset := fmod(state.elapsed*44.0/Economy.feed_interval(state.config,state.levels),18)
	for i in range(15):
		var dx := fmod(i*18+offset,268)
		draw_line(Vector2(x+5+dx,y+4),Vector2(x+dx,y+24),Color("3c474b"),3)
	draw_rect(Rect2(x+2,y+27,274,7),Color("c3a258"))
	for i in range(17):
		draw_line(Vector2(x+5+i*16,y+27),Vector2(x+12+i*16,y+33),Color("303a3d"),4)
	for dx in [12,264]:
		draw_circle(Vector2(x+dx,y+16),6,Color("a0aaa1"))
		draw_circle(Vector2(x+dx,y+16),3,Color("34444b"))
	# Short chute beneath the moving belt makes the drop origin explicit.
	draw_polygon(PackedVector2Array([Vector2(587,252),Vector2(602,252),Vector2(625,286),Vector2(606,292)]),PackedColorArray([Color("848b80")]))
	draw_line(Vector2(602,252),Vector2(625,286),Color("303c41"),3)

func _draw_machine() -> void:
	var active: bool = state.unlocks.auto_stomper
	var belt: bool = state.unlocks.conveyor
	var x := 1040.0
	var y := 176.0
	var body := Color("52616a") if active else Color("6a6a60")
	# Legs, deck, conveyor rollers, hazard-stripe gantry.
	draw_rect(Rect2(x+4,y+41,169,14),Color(0,0,0,.2))
	for dx in [14,144]:
		draw_rect(Rect2(x+dx,y+26,9,38),Color("333c40"))
		draw_rect(Rect2(x+dx-4,y+61,20,5),Color("414b4d"))
	draw_rect(Rect2(x,y,177,34),Color("252f36"))
	draw_rect(Rect2(x+3,y+3,171,22),body)
	for i in range(9):
		var dx := fmod(i*21 + (state.auto_progress*90 if active and belt else 0),169)
		draw_line(Vector2(x+4+dx,y+4),Vector2(x+dx,y+20),Color("36434a"),2)
	draw_rect(Rect2(x+2,y+24,173,8),Color("b49346") if active else Color("777362"))
	for i in range(11):
		draw_line(Vector2(x+i*16,y+24),Vector2(x+i*16+7,y+31),Color("30383c"),4)
	for dx in [8,158]:
		draw_circle(Vector2(x+dx,y+16),5,Color("919894"))
		draw_circle(Vector2(x+dx,y+16),2,Color("2b363b"))
	if active:
		var p := state.auto_progress
		var stage := clampi(int(maxf(0,(p-.65)/.35)*4),0,4)
		draw_texture_rect(frames.red[stage],Rect2(x+12+p*92,y-39,60,60),false)
		if belt:
			draw_texture_rect(frames.blue[0],Rect2(x+3,y-35,45,45),false)
		draw_rect(Rect2(x+99,y-62,10,71),Color("343f46"))
		draw_rect(Rect2(x+153,y-62,10,71),Color("343f46"))
		draw_rect(Rect2(x+94,y-65,73,14),Color("d2a849"))
		for i in range(5):
			draw_line(Vector2(x+99+i*14,y-64),Vector2(x+107+i*14,y-52),Color("34383b"),5)
		var press_y := maxf(0,p-.7)/.3*26
		draw_rect(Rect2(x+116,y-48,25,24+press_y),Color("9da49c"))
		draw_rect(Rect2(x+110,y-29+press_y,38,9),Color("4a5559"))
		draw_circle(Vector2(x+166,y+12),4,Color("b9dc9d") if machine_flash <= .1 else Color("ffdb7a"))
		draw_rect(Rect2(x,y+76,177,4),Color("6c6555"))
		draw_rect(Rect2(x,y+76,177*p,4),Color("c6db9a"))
