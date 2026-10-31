extends SceneTree

const Main = preload("res://scenes/yard.tscn")
var checks:=0
var failures:=0

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error("FAIL: "+message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game:=Main.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false); game.world.set_process(false)
	game.state.settings.muted=true
	check(root.content_scale_size==Vector2i(2560,1440),"native QHD canvas")
	check(game.rows.has("tool:fist") and game.rows.has("tool:drill"),"prosthetic workshop")
	game.set_tab(1); await process_frame
	check(game.rows.has("depth") and game.rows.has("scanner") and game.rows.has("magnet"),"portal and modules")
	game.set_tab(2); await process_frame
	check(game.rows.has("entry:washer") and game.rows.has("auto_stomper"),"codex and independent line")
	var nodes:=get_node_count()
	game.state.coins=25000; game.state.earned=25000; game.state.crushed=150; game.state.manual_crushed=150
	game.state.purchase("tool:fist")
	check(game.modal.visible and game.state.paused,"first installation scene")
	game.close_modal()
	game.state.purchase("tool:hammer"); game.state.purchase("tool:drill")
	game.state.purchase("depth"); game.state.purchase("depth"); game.state.purchase("auto_stomper")
	for i in range(3600):
		game.state.advance(1.0/60)
		game.state.attack()
		game.world._process(1.0/60)
		if i%300==0: check(game.world.particles.size()<=150,"bounded high frequency VFX")
		if game.state.paused: game.close_modal()
	await process_frame
	check(get_node_count()<=nodes+12,"no per-trash/per-hit scene node growth")
	game.show_modal("pause"); await process_frame
	var before: Dictionary=game.state.snapshot(); game.state.advance(20)
	check(game.state.snapshot()==before,"pause UI really pauses all state")
	game.close_modal()
	game.show_modal("reset"); await process_frame
	game.reset_yard()
	check(game.state.coins==0 and game.state.field.items.is_empty() and not game.state.owned.fist,"reset new yard")
	check(not game.state.paused and game.world.particles.is_empty(),"reset resumes with clean effects")
	print("YARD_SCENE_TESTS: %d checks / %d failures" % [checks,failures])
	game.queue_free(); await process_frame
	quit(0 if failures==0 else 1)
