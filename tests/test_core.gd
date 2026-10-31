extends SceneTree

const Data = preload("res://scripts/data_loader.gd")
const State = preload("res://scripts/game_state.gd")
const Economy = preload("res://scripts/economy.gd")
const Save = preload("res://scripts/save_service.gd")
const Garage = preload("res://scripts/garage.gd")
var failures := 0
var checks := 0
var config: Dictionary

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: "+message)

func _initialize() -> void:
	config = Data.load_config()
	check(not config.has("error"),"valid data")
	if config.has("error"):
		quit(1)
		return
	var state := State.new(config)
	check(state.field.items.is_empty() and state.coins == 0,"start empty / wallet")
	state.advance(2)
	var can: Dictionary = state.field.items[0]
	state.stomp()
	check(can.hp == 2 and state.coins == 0,"no reward before crush")
	check(not state.stomp() and can.hp == 2,"shared cooldown blocks repeated click")
	state.advance(.68)
	state.stomp()
	check(can.hp == 1,"second stomp")
	state.advance(.68)
	var reentrant := func(_item,_amount): state.stomp(can.id)
	state.hit.connect(reentrant)
	state.stomp()
	state.hit.disconnect(reentrant)
	check(can.hp == 0 and state.coins == 6 and state.crushed == 1,"exactly one payout under reentry")
	for i in range(100): state.stomp(can.id)
	check(state.coins == 6,"no payout on crushed can")
	state.advance(.85)
	check(not state.field.by_id.has(can.id) and state.field.pending_count() >= 3,"only crushed can removed; feed continues")
	for level in [1,2,3,4]:
		var s := State.new(config)
		s.advance(2)
		s.levels.power = level
		s.stomp()
		check(s.field.items[0].hp == maxi(0,3-1-level),"power %d damage" % level)
	for hp in range(9):
		check(Economy.stage(hp,8) == (4 if hp == 0 else clampi(floori(4.0*(8-hp)/8),0,3)),"stage mapping")
	for type in ["red","blue","gold"]:
		for stage in range(5):
			check(ResourceLoader.exists("res://assets/art/can_%s_%d.png" % [type,stage]),"frame exists")
	state = State.new(config)
	check(not state.purchase("power") and state.coins == 0,"insufficient wallet atomic")
	state.coins = 18
	check(state.purchase("power") and state.coins == 0 and state.levels.power == 1,"valid purchase")
	state.coins = 100000
	check(not state.purchase("auto_speed"),"auto speed needs auto")
	check(not state.purchase("blue_can"),"count gate")
	state.crushed = 20
	check(state.purchase("blue_can"),"blue unlock at threshold")
	var wallet := state.coins
	check(not state.purchase("blue_can") and state.coins == wallet,"duplicate unlock doesn't charge")
	for i in range(10): state.purchase("power")
	wallet = state.coins
	check(state.levels.power == 4 and not state.purchase("power") and state.coins == wallet,"max level")
	state.levels.value = 3
	check(Economy.reward(config,state.levels,state.cans.red) == 11,"additive rounded value")
	check(not state.purchase("missing"),"unknown upgrade rejected")
	state = State.new(config)
	state.rng.seed = 73
	var counts := {"red":0,"blue":0,"gold":0}
	for i in range(10000): counts[state.choose_can()] += 1
	check(counts.red == 10000,"no locked type can spawn")
	state.unlocks.blue_can = true
	state.unlocks.gold_can = true
	counts = {"red":0,"blue":0,"gold":0}
	for i in range(10000): counts[state.choose_can()] += 1
	check(absf(counts.gold/10000.0-.055) < .015,"gold probability")
	check(absf(counts.blue/10000.0-.945*.4) < .025,"conditional blue probability")
	print("SPAWN_SAMPLE ",counts)
	state = State.new(config)
	state.advance(20)
	check(state.coins == 0 and state.field.pending_count() == 20,"locked auto does nothing; all cans retained")
	state.unlocks.auto_stomper = true
	state.advance(20)
	check(state.coins == 30 and state.auto_crushed == 5 and state.field.pending_count() == 40 and state.field.items[0].hp == 3,"independent auto 5 completions; floor untouched")
	state.advance(1)
	var progress := state.auto_progress
	state.coins = 2000
	state.purchase("auto_speed")
	check(is_equal_approx(state.auto_progress,progress),"auto upgrade preserves normalized progress")
	check(is_equal_approx(Economy.auto_interval(config,state.levels,state.unlocks),2.4),"speed interval")
	state.unlocks.conveyor = true
	check(is_equal_approx(Economy.auto_interval(config,state.levels,state.unlocks),1.8),"conveyor interval")
	state.paused = true
	state.earned = maxi(state.earned,state.coins)
	var saved := state.snapshot()
	state.advance(500)
	check(state.snapshot() == saved,"pause freezes time and economy")
	check(not state.stomp() and not state.purchase("value"),"pause blocks input")
	var clone := State.new(config)
	check(clone.restore(saved) and clone.snapshot() == saved,"normalized round trip")
	check(clone.auto_progress == 0 and clone.field.pending_count() == 41,"no offline reward; accumulated cans survive load")
	check(not clone.restore({"version":99}),"unsupported version")
	var bad := saved.duplicate(true)
	bad.coins = "bad"
	check(not clone.restore(bad),"invalid save type")
	bad = saved.duplicate(true)
	bad.levels.power = "bad"
	check(not clone.restore(bad),"invalid level type")
	var path := "res://tests/.test_save.json"
	check(Save.write(clone,path) == OK,"atomic save write")
	var loaded := State.new(config)
	check(Save.read_into(loaded,path).is_empty() and loaded.field.pending_count() == clone.field.pending_count() and loaded.coins == clone.coins and loaded.levels == clone.levels,"save load")
	check(loaded.field.items[0].pos.distance_to(clone.field.items[0].pos) < .001,"disk save preserves floor position")
	var f := FileAccess.open(path,FileAccess.WRITE)
	f.store_string("broken{")
	f.close()
	check(not Save.read_into(loaded,path).is_empty(),"corrupt save recovers")
	DirAccess.remove_absolute(path)
	var fresh := State.new(config)
	state.restore(fresh.snapshot())
	check(state.coins == 0 and state.crushed == 0 and state.levels.power == 0 and not state.unlocks.auto_stomper,"reset normalized state")
	var g := Garage.new()
	state.paused = false
	state.advance(2)
	g.state = state
	check(g.hovering(state.field.visual_position(state.field.items[0])),"target hit point follows rolling can")
	check(not g.hovering(Vector2(200,422)) and not g.hovering(Vector2(790,150)),"UI and empty-floor exclusion")
	g.free()
	var malformed := config.duplicate(true)
	malformed.gameplay.auto_interval_level1_seconds = 0
	check(not Data.validate(malformed).is_empty(),"bad balance fails clearly")
	state = State.new(config)
	var summaries := [0]
	state.summary_due.connect(func(): summaries[0] += 1)
	state.advance(600)
	state.advance(200)
	check(summaries[0] == 1 and state.elapsed == 800 and state.field.pending_count() == 800,"summary once; 800 intact cans retained without cap")
	print("CORE_TESTS: %d checks / %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
