extends SceneTree

const Data = preload("res://scripts/data_loader.gd")
const State = preload("res://scripts/game_state.gd")
const Economy = preload("res://scripts/economy.gd")
const Field = preload("res://scripts/can_field.gd")
var checks := 0
var failures := 0

func check(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: "+message)

func _initialize() -> void:
	var config := Data.load_config()
	var state := State.new(config)
	state.field.rng.seed = 41
	check(is_equal_approx(Economy.feed_interval(config,state.levels),1),"initial one second per can")
	state.advance(.99)
	check(state.field.items.is_empty(),"no premature supply")
	state.advance(.01)
	check(state.field.items.size() == 1,"one arrival after exactly one second")
	var first: Dictionary = state.field.items[0]
	check(first.phase == "belt" and not state.stomp(first.id),"belt transport is not a stomp target")
	state.advance(.6)
	check(first.phase == "moving" and first.height > 40,"can exits belt above ground")
	var saw_floor := false
	var saw_bounce := false
	var previous_height: float = first.height
	var maximum_speed := 0.0
	for i in range(360):
		state.advance(1.0/60)
		if float(first.height) == 0: saw_floor = true
		if saw_floor and float(first.height) > previous_height: saw_bounce = true
		previous_height = float(first.height)
		maximum_speed = maxf(maximum_speed,first.velocity.length())
	check(saw_floor and saw_bounce,"gravity, ground contact and bounce")
	check(first.phase == "rest" and first.velocity == Vector2.ZERO and maximum_speed > 50,"roll decelerates into sleeping rest")
	check(first.pos.distance_to(Field.DROP_POINT) > 60,"can rolls away from outlet")
	state.advance(52.4)
	check(state.field.items.size() == 60 and state.field.pending_count() == 60,"one minute no-stomp retains all 60 cans")
	var cells := {}
	for item in state.field.items:
		check(item.hp == 3 and not item.claimed,"no automatic deletion or damage")
		if item.phase != "belt":
			check(Field.FLOOR.grow(.01).has_point(item.pos),"floor and edge containment")
		if item.phase == "rest": cells[Vector2i(item.pos/50)] = true
	check(cells.size() > 15,"random resting positions spread across floor")
	check(state.field.active.size() < 15,"settled pile stops physics work")
	check(state.field.at_point(Vector2(200,420)).is_empty(),"UI cannot hit pile")
	check(not state.field.at_point(state.field.visual_position(first)).is_empty(),"hit test follows can position")
	check(state.coins == 0 and state.crushed == 0,"feeding doesn't generate rewards")
	var neighbor: Dictionary = state.field.items[1]
	var other_hp: int = neighbor.hp
	var selected := state.field.at_point(state.field.visual_position(first))
	check(not selected.is_empty() and state.stomp(int(selected.id)),"stomp follows visible can at random location")
	check(neighbor.hp == other_hp if neighbor.id != selected.id else first.hp == 3,"one stomp damages only its selected can")
	var partial_saved := state.snapshot()
	var restored_partial := State.new(config)
	check(restored_partial.restore(partial_saved) and restored_partial.field.by_id[selected.id].hp == 2,"partial damage persists with pile")
	var fast := State.new(config)
	fast.coins = 100000
	fast.earned = fast.coins
	fast.advance(.5)
	var progress := fast.field.feed_progress
	check(fast.purchase("feed_speed") and fast.levels.feed_speed == 1,"feed speed available before auto unlock")
	check(is_equal_approx(fast.field.feed_progress,progress),"upgrade preserves feed cycle")
	fast.advance(.4)
	check(fast.field.items.size() == 1,"remaining half-cycle uses new .8s interval")
	fast.advance(8)
	check(fast.field.items.size() == 11,"level one supplies 10 cans in 8 seconds")
	for level in [2,3,4]:
		check(fast.purchase("feed_speed"),"feed path level %d" % level)
		check(is_equal_approx(Economy.feed_interval(config,fast.levels),float(config.gameplay.feed_intervals_seconds[level])),"configured interval %d" % level)
	var wallet := fast.coins
	check(not fast.purchase("feed_speed") and fast.coins == wallet,"feed upgrade cap doesn't charge")
	var count := fast.field.items.size()
	fast.advance(10)
	check(fast.field.items.size()-count == 40,"max level delivers four cans per second")
	count = fast.field.items.size()
	fast.advance(600)
	check(fast.field.items.size()-count == 2400,"max speed retains 2400 new cans over ten simulated minutes")
	check(fast.field.active.size() < 80,"large sleeping pile doesn't create unlimited active physics")
	var copy := State.new(config)
	check(copy.restore(state.snapshot()),"save every floor and belt can")
	check(copy.field.items.size() == state.field.items.size(),"same saved pile count")
	for i in range(state.field.items.size()):
		check(copy.field.items[i].pos == state.field.items[i].pos and copy.field.items[i].hp == state.field.items[i].hp,"position and hp survive restore")
	var a := State.new(config)
	var b := State.new(config)
	a.rng.seed = 5; b.rng.seed = 5
	a.field.rng.seed = 13; b.field.rng.seed = 13
	for i in range(300): a.advance(1.0/30)
	for i in range(600): b.advance(1.0/60)
	check(a.field.snapshot() == b.field.snapshot(),"deterministic motion independent of render frame grouping")
	var old := state.snapshot()
	old.version = 1
	old.erase("field")
	old.levels.erase("feed_speed")
	var migrated := State.new(config)
	check(migrated.restore(old) and migrated.levels.feed_speed == 0 and migrated.field.items.is_empty(),"v1 migration preserves economy and starts base supply")
	var bad := state.snapshot()
	bad.field.items[0].pos = [NAN,400]
	var before := copy.snapshot()
	check(not copy.restore(bad) and copy.snapshot() == before,"invalid field rejected atomically")
	var malformed := config.duplicate(true)
	malformed.gameplay.feed_intervals_seconds[1] = 0
	check(not Data.validate(malformed).is_empty(),"invalid supply config rejected")
	print("FEED_TESTS: %d checks / %d failures, resting spread cells=%d" % [checks,failures,cells.size()])
	quit(0 if failures == 0 else 1)
