extends SceneTree

const Main = preload("res://scenes/yard.tscn")
var game: Control
var viewport: SubViewport

func _initialize() -> void:
	call_deferred("run")

func simulate(seconds: float) -> void:
	for i in range(roundi(seconds*60)):
		game.state.advance(1.0/60)
		game.world._process(1.0/60)

func shot(name: String) -> void:
	game.refresh(); game.world.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var img:=viewport.get_texture().get_image()
	img.save_png("res://tests/screenshots/"+name+".png")
	print("YARD_CAPTURE: "+name+" "+str(img.get_size()))

func run() -> void:
	viewport=SubViewport.new()
	viewport.size=Vector2i(2560,1440)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	game=Main.instantiate(); viewport.add_child(game)
	await process_frame
	game.set_process(false); game.world.set_process(false)
	game.world.debug_pointer=true
	game.state.settings.muted=true
	game.state.rng.seed=41; game.state.field.rng.seed=42
	simulate(14)
	game.world.pointer_visible=true
	game.world.pointer=Vector2(840,430)
	await shot("yard-01-start-2k")
	game.state.coins=1260; game.state.earned=4630; game.state.crushed=86; game.state.manual_crushed=74; game.state.auto_crushed=12
	game.state.owned.fist=true; game.state.owned.hammer=true; game.state.equipped="hammer"
	game.state.levels.depth=1; game.state.levels.quality=1; game.state.levels.scanner=1; game.state.levels.magnet=1
	game.state.levels.power=1; game.state.levels.value=1; game.state.levels.feed_speed=1; game.state.levels.auto_stomper=1
	for kind in ["keyboard","fan","blue","gold","keyboard","fan"]: game.state.spawn(kind)
	simulate(8)
	game.state.energy=83; game.state.combo=7
	game.world.pointer_visible=true; game.world.pointer=Vector2(853,450)
	await shot("yard-02-workshop-2k")
	game.set_tab(1)
	await shot("yard-03-portal-2k")
	game.state.owned.drill=true; game.state.equipped="drill"; game.state.levels.depth=2
	game.state.coins=2640; game.state.earned=8240
	for kind in ["computer","washer","fan","keyboard","gold"]: game.state.spawn(kind)
	simulate(5)
	game.state.start_event("rain")
	game.state.energy=100; game.state.activate_frenzy()
	var target: Dictionary={}
	for item in game.state.field.items:
		if item.kind=="washer": target=item; break
	game.world.pointer=game.state.weak_point(target)
	game.world.pointer_visible=true
	game.state.attack(target.id,game.world.pointer)
	game.set_tab(0)
	await shot("yard-04-drill-2k")
	game.set_tab(2)
	await shot("yard-05-codex-2k")
	game.show_modal("installed_fist")
	game.world.pointer_visible=false
	await shot("yard-06-prosthesis-2k")
	game.close_modal(); game.state.completed=true; game.state.recovered.washer=1; game.show_modal("chapter_done")
	await shot("yard-07-chapter-2k")
	game.queue_free(); await process_frame
	viewport.queue_free(); await process_frame
	quit()
