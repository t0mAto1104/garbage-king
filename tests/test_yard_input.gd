extends SceneTree

const Main=preload("res://scenes/yard.tscn")
var checks:=0
var failures:=0
var viewport: SubViewport

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("FAIL: "+message)

func _initialize() -> void:
	call_deferred("run")

func move(point: Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=point; event.global_position=point
	viewport.push_input(event,true)

func click(point: Vector2) -> void:
	move(point)
	var event:=InputEventMouseButton.new()
	event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true
	viewport.push_input(event,true)
	var release:=event.duplicate()
	release.pressed=false
	viewport.push_input(release,true)

func run() -> void:
	viewport=SubViewport.new(); viewport.size=Vector2i(2560,1440)
	root.add_child(viewport)
	var game:=Main.instantiate(); viewport.add_child(game)
	await process_frame
	game.set_process(false); game.world.set_process(false); game.state.settings.muted=true
	var item: Dictionary=game.state.spawn("red")
	item.phase="rest"; item.pos=Vector2(800,430); item.velocity=Vector2.ZERO; item.height=0; item.vertical_speed=0
	move(Vector2(1600,860))
	await process_frame
	check(game.get_global_mouse_position().distance_to(Vector2(1600,860))<.01,"QHD viewport receives exact input coordinates")
	check(game.state.field.at_point(game.get_global_mouse_position()/2).get("id")==item.id,"QHD pointer resolves actual junk hotspot")
	click(Vector2(1600,860)); await process_frame
	check(item.hp==2 and game.state.coins==0,"engine-routed click hits the selected can")
	click(Vector2(1600,860)); await process_frame
	check(item.hp==2,"repeated engine click shares cooldown")
	game.state.coins=18; game.state.earned=18; game.state.cooldown_left=0
	game.refresh(); await process_frame
	click(Vector2(480,984)); await process_frame
	check(game.state.levels.power==1 and game.state.coins==0,"QHD GUI price button purchases through real input routing")
	check(item.hp==2,"GUI click never bleeds through to arena")
	print("YARD_INPUT_TESTS: %d checks / %d failures" % [checks,failures])
	game.queue_free(); await process_frame; viewport.queue_free(); await process_frame
	quit(0 if failures==0 else 1)
