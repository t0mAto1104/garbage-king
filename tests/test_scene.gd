extends SceneTree

const Main = preload("res://scenes/main.tscn")
const State = preload("res://scripts/game_state.gd")
var failures := 0
var checks := 0
var game: Control
var maximum_vfx := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: "+message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = Main.instantiate()
	root.add_child(game)
	await process_frame
	# All scene tests run against an isolated in-memory state; persist is redirected below.
	game.set_process(false)
	game.garage.set_process(false)
	game.state.restore(State.new(game.state.config).snapshot())
	game.state.settings.muted = true
	var node_count := get_node_count()
	game.set_tab(1)
	await process_frame
	check(game.rows.size() == 4 and game.rows.has("feed_speed"),"supply speed and automation tab")
	game.set_tab(0)
	await process_frame
	check(game.rows.size() == 5,"upgrade tab")
	var nodes_after_tab := get_node_count()
	for i in range(36000):
		game.state.advance(1.0/60)
		game.state.stomp()
		game.garage._process(1.0/60)
		maximum_vfx = maxi(maximum_vfx,game.garage.particles.size())
		if i % 600 == 0:
			check(game.garage.particles.size() <= int(game.state.config.gameplay.max_vfx_objects),"bounded VFX")
		if i == 300:
			game.state.coins = 10000
			game.state.crushed = 150
			for id in ["blue_can","gold_can","auto_stomper","conveyor","auto_speed"]: game.state.purchase(id)
	game.state.advance(.1)
	check(get_node_count() <= nodes_after_tab+25,"no accumulating scene nodes over simulated 10min")
	check(game.state.auto_crushed > 100,"auto operates with scene UI")
	check(game.overlay.visible and game.state.summary_seen,"summary modal shown")
	game.close_modal()
	check(not game.state.paused and not game.overlay.visible,"summary continue")
	game.show_modal("reset")
	await process_frame
	game.reset_demo()
	check(game.state.coins == 0 and game.state.crushed == 0 and not game.state.unlocks.auto_stomper,"scene reset")
	check(game.garage.particles.is_empty(),"reset clears VFX")
	print("SCENE_TESTS: %d checks / %d failures, peak VFX=%d, initial nodes=%d, current=%d (600 simulated seconds; not real-time GPU profiling)" % [checks,failures,maximum_vfx,node_count,get_node_count()])
	game.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
