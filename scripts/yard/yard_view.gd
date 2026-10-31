class_name YardView
extends Control

const Stage = preload("res://scripts/economy.gd")
const SCALE := 2.0
const ARENA := Rect2(302,145,960,480)
var state: YardState
var font: Font
var background := preload("res://assets/yard/workshop.png")
var coin := preload("res://assets/art/coin.png")
var frames := {}
var cursors := {}
var particles: Array[Dictionary] = []
var pointer := Vector2.ZERO
var pointer_visible := false
var keyboard_point := Vector2(-1000,-1000)
var impact := 0.0
var age := 0.0
var last_hit_time := -100.0
var last_text_time := -100.0
var last_point := Vector2.ZERO
var machine_flash := 0.0
var debug_pointer := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item in state.config.trash:
		frames[item.id] = []
		for i in range(5): frames[item.id].append(load(item.visual % i))
	for tool in state.config.tools: cursors[tool.id] = load(tool.visual)
	if font==null:
		font = SystemFont.new()
		font.font_names = PackedStringArray(["PingFang SC","Microsoft YaHei","sans-serif"])

func logical() -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2(SCALE,SCALE))

func on_hit(item: Dictionary, payout: int, damage: int, weak: bool) -> void:
	var point := state.field.visual_position(item)
	if age-last_hit_time>.025:
		last_point = point
		impact = 1.0
		last_hit_time = age
	var amount := 2 if state.settings.reduced else (8 if item.claimed else 3)
	for i in range(amount):
		if particles.size()>=int(state.config.gameplay.max_vfx_objects): break
		var a := float(i)*TAU/amount
		particles.append({"p":point,"v":Vector2(cos(a)*randf_range(25,85),sin(a)*55-65),"life":.55,"text":"","gold":item.claimed,"weak":weak})
	if payout>0 and particles.size()<int(state.config.gameplay.max_vfx_objects):
		particles.append({"p":point+Vector2(12,-27),"v":Vector2(0,-35),"life":.9,"text":"+%d" % payout,"gold":true,"weak":false})
	elif age-last_text_time>.18 and particles.size()<int(state.config.gameplay.max_vfx_objects):
		particles.append({"p":point+Vector2(9,-27),"v":Vector2(0,-26),"life":.45,"text":str(damage),"gold":false,"weak":weak})
		last_text_time = age

func on_auto(amount: int) -> void:
	machine_flash = 1
	if particles.size()<int(state.config.gameplay.max_vfx_objects):
		particles.append({"p":Vector2(1150,224),"v":Vector2(0,-24),"life":.9,"text":"+%d" % amount,"gold":true,"weak":false})

func _process(delta: float) -> void:
	if not debug_pointer:
		pointer = get_global_mouse_position()/SCALE
		pointer_visible = ARENA.has_point(pointer) and not state.paused and get_window().has_focus()
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if pointer_visible else Input.MOUSE_MODE_VISIBLE
	if not state.paused:
		age += delta
		impact = maxf(0,impact-delta*(12 if state.equipped=="drill" else 6))
		machine_flash = maxf(0,machine_flash-delta*4)
		for p in particles:
			p.life -= delta
			p.p += p.v*delta
			if p.text.is_empty(): p.v.y += delta*180
		particles = particles.filter(func(p): return p.life>0)
	queue_redraw()

func _draw() -> void:
	if state==null or frames.is_empty(): return
	logical()
	draw_texture_rect(background,Rect2(300,0,980,720),false)
	# A generous empty floor is the primary interface.
	_draw_portal()
	_draw_belt()
	_draw_auto()
	var order := state.field.items.duplicate()
	order.sort_custom(func(a,b): return a.id<b.id if a.pos.y==b.pos.y else a.pos.y<b.pos.y)
	for item in order: _draw_item(item)
	var hovered := state.field.at_point(pointer) if pointer_visible else {}
	if not hovered.is_empty():
		var center := state.field.visual_position(hovered)
		var radius := 37*float(hovered.get("shape_scale",1.0))
		draw_arc(center,radius,0,TAU,40,Color(.86,.95,.79,.65),1,false)
		draw_rect(Rect2(center+Vector2(-23,-radius-8),Vector2(46,3)),Color("314b50"))
		draw_rect(Rect2(center+Vector2(-23,-radius-8),Vector2(46.0*hovered.hp/hovered.max_hp,3)),Color("d8c686"))
		if int(state.levels.scanner)>0:
			var weak := state.weak_point(hovered)
			draw_circle(weak,7,Color("dd954d"),false,2)
			draw_line(weak+Vector2(-10,0),weak+Vector2(10,0),Color("f0c47a"),1)
			draw_line(weak+Vector2(0,-10),weak+Vector2(0,10),Color("f0c47a"),1)
	if impact>.12 and state.equipped=="hammer" and not state.settings.reduced:
		draw_arc(last_point,20+(1-impact)*85,0,TAU,40,Color(.95,.77,.4,impact*.6),2,false)
	for p in particles:
		var alpha := minf(1,float(p.life)/.2)
		if not p.text.is_empty():
			var color := Color("f1d27f") if p.gold else (Color("fac488") if p.weak else Color("e6e8ca"))
			color.a = alpha
			draw_string(font,p.p+Vector2(1,1),p.text,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color(.1,.18,.2,alpha))
			draw_string(font,p.p,p.text,HORIZONTAL_ALIGNMENT_LEFT,-1,17,color)
		elif p.gold:
			draw_texture_rect(coin,Rect2(p.p,Vector2(15,15)),false,Color(1,1,1,alpha))
		else:
			draw_rect(Rect2(p.p,Vector2(3,3)),Color(.83,.83,.66,alpha))
	if pointer_visible or impact>.1 and keyboard_point.x>0:
		var point := keyboard_point if impact>.1 and keyboard_point.x>0 else pointer
		var scale := 1.2*(1-impact*.08)
		var tilt := -.25*impact if state.equipped=="hammer" and not state.settings.reduced else 0.0
		draw_set_transform(point*SCALE,tilt,Vector2(SCALE,SCALE)*scale)
		draw_texture_rect(cursors[state.equipped],Rect2(-46,-26,92,140),false)
		logical()
	if impact<=.1: keyboard_point = Vector2(-1000,-1000)

func _draw_item(item: Dictionary) -> void:
	var scale := float(item.get("shape_scale",1.0))
	var center := state.field.visual_position(item)
	if item.phase!="belt":
		draw_set_transform((item.pos+Vector2(0,13))*SCALE,0,Vector2(SCALE,SCALE*.3))
		draw_circle(Vector2.ZERO,maxf(12,25*scale-float(item.height)*.1),Color(.12,.2,.2,.23))
	var squish := float(item.impact)*(.1 if not state.settings.reduced else .02)
	draw_set_transform(center*SCALE,float(item.rotation),Vector2(SCALE*scale*(1+squish),SCALE*scale*(1-squish)))
	draw_texture_rect(frames[item.kind][Stage.stage(int(item.hp),int(item.max_hp))],Rect2(-52,-52,104,104),false)
	logical()

func _draw_portal() -> void:
	var center := Vector2(346,210)
	var color := Color("72d0c3") if int(state.levels.depth)==0 else (Color("75c2e2") if int(state.levels.depth)==1 else Color("c39cde"))
	var pulse := .5+.5*sin(age*2)
	if state.settings.reduced: pulse = .5
	draw_set_transform(center*SCALE,0,Vector2(SCALE*.55,SCALE))
	for i in range(4,0,-1):
		draw_circle(Vector2.ZERO,61+i*7,Color(color.r,color.g,color.b,.02))
	draw_circle(Vector2.ZERO,64,Color("273d46"))
	draw_arc(Vector2.ZERO,61,0,TAU,48,Color("9ba994"),8,false)
	draw_arc(Vector2.ZERO,54,0,TAU,48,color,4,false)
	draw_circle(Vector2.ZERO,49,Color("264e58"))
	for i in range(7):
		var radius := fmod(age*22+i*8,48)
		draw_arc(Vector2.ZERO,radius,0,TAU,40,Color(color.r,color.g,color.b,.2+.08*pulse),2,false)
	if int(state.levels.depth)>0:
		draw_arc(Vector2.ZERO,73,-age*.25,PI*.9-age*.25,40,color,2,false)
	logical()
	draw_rect(Rect2(311,266,73,14),Color("314952"))
	draw_rect(Rect2(320,267,53,3),color)

func _draw_belt() -> void:
	var x := 341.0; var y := 237.0
	for dx in [18,218]:
		draw_rect(Rect2(x+dx,y+19,8,39),Color("304750"))
		draw_rect(Rect2(x+dx-5,y+55,19,5),Color("536c70"))
	draw_rect(Rect2(x-4,y-12,258,31),Color("263e49"))
	draw_rect(Rect2(x,y-9,250,21),Color("6c7e76"))
	var offset := fmod(age*35/state.feed_interval(),18)
	for i in range(14):
		var dx := fmod(i*18+offset,244)
		draw_line(Vector2(x+dx,y-8),Vector2(x+dx-6,y+11),Color("3e5962"),3)
	draw_rect(Rect2(x-2,y+13,254,6),Color("bd9c60"))
	for i in range(16): draw_line(Vector2(x+i*16,y+13),Vector2(x+i*16+5,y+19),Color("304750"),4)
	draw_polygon(PackedVector2Array([Vector2(587,252),Vector2(601,252),Vector2(623,286),Vector2(605,291)]),PackedColorArray([Color("9aa68f")]))

func _draw_auto() -> void:
	var active := int(state.levels.auto_stomper)>0
	var x := 1080.0; var y := 205.0
	draw_rect(Rect2(x+5,y+30,158,8),Color(.1,.18,.2,.23))
	for dx in [8,145]: draw_rect(Rect2(x+dx,y+20,8,44),Color("30464f"))
	draw_rect(Rect2(x,y,166,29),Color("2a444f"))
	draw_rect(Rect2(x+3,y+3,160,18),Color("6c827e") if active else Color("6f7d71"))
	for i in range(9):
		var dx := fmod(i*19+state.auto_progress*50,157)
		draw_line(Vector2(x+4+dx,y+3),Vector2(x+dx,y+21),Color("3c5960"),2)
	draw_rect(Rect2(x+2,y+23,162,6),Color("c19b59") if active else Color("8a8b72"))
	if not active: return
	draw_texture_rect(frames.red[clampi(int(state.auto_progress*4),0,3)],Rect2(x+8+state.auto_progress*98,y-40,58,58),false)
	for dx in [98,145]: draw_rect(Rect2(x+dx,y-56,8,67),Color("2b444f"))
	draw_rect(Rect2(x+91,y-61,68,13),Color("c7a65f"))
	for i in range(5): draw_line(Vector2(x+95+i*13,y-60),Vector2(x+103+i*13,y-49),Color("30464e"),4)
	var press := maxf(0,state.auto_progress-.65)/.35*30
	draw_rect(Rect2(x+113,y-45,17,22+press),Color("bbc6ab"))
	draw_rect(Rect2(x+105,y-24+press,35,7),Color("47636c"))
	draw_circle(Vector2(x+156,y+11),3,Color("e8cd7c") if machine_flash>.1 else Color("a8cd9a"))
	draw_rect(Rect2(x,y+64,166,3),Color("6c7f70"))
	draw_rect(Rect2(x,y+64,166*state.auto_progress,3),Color("99c9b5"))
