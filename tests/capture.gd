extends SceneTree

const Main = preload("res://scenes/main.tscn")
var game: Control

func simulate(seconds: float) -> void:
	for i in range(roundi(seconds*60)):
		game.state.advance(1.0/60)
		game.garage._process(1.0/60)

func _initialize() -> void:
	call_deferred("run")

func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("res://tests/screenshots/"+name+".png")
	print("CAPTURE: "+name)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://tests/screenshots")
	game = Main.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.garage.set_process(false)
	game.state.settings.muted = true
	game.state.rng.seed = 7
	game.state.field.rng.seed = 42
	simulate(12)
	game.garage.pointer_visible = true
	game.garage.pointer = Vector2(887,429)
	game.refresh()
	game.garage.queue_redraw()
	await shot("01-new-garage")
	var target: Dictionary = game.state.field.items[0]
	game.garage.pointer = game.state.field.visual_position(target)
	game.state.stomp(target.id)
	game.garage.queue_redraw()
	await shot("02-stomp")
	game.state.coins = 2480
	game.state.earned = 5300
	game.state.crushed = 127
	game.state.manual_crushed = 100
	game.state.auto_crushed = 27
	game.state.elapsed = 525
	game.state.levels = {"power":2,"value":2,"speed":1,"auto_speed":0,"feed_speed":1}
	for id in game.state.unlocks: game.state.unlocks[id] = true
	simulate(10)
	game.state.auto_progress = .72
	game.garage.impact = 0
	game.garage.particles.clear()
	game.garage.pointer = Vector2(869,428)
	game.garage.pointer_visible = true
	game.set_tab(1)
	game.refresh()
	game.garage.queue_redraw()
	await shot("03-automation")
	game.show_modal("summary")
	game.garage.pointer_visible = false
	game.garage.queue_redraw()
	await shot("04-summary")
	game.close_modal()
	game.show_modal("help")
	await shot("05-help")
	game.queue_free()
	await process_frame
	quit()
