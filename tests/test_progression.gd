extends SceneTree

const Data = preload("res://scripts/data_loader.gd")
const State = preload("res://scripts/game_state.gd")
const Economy = preload("res://scripts/economy.gd")
var events: Array[String] = []

func try_upgrade(s: StompState,id: String,minimum: int) -> void:
	if s.crushed >= minimum and s.purchase(id):
		events.append("%.2fm %s Lv.%d" % [s.elapsed/60,id,s.levels[id]])

func try_unlock(s: StompState,id: String) -> void:
	if s.purchase(id):
		events.append("%.2fm %s" % [s.elapsed/60,id])

func simulate(duty: float) -> StompState:
	var s := State.new(Data.load_config())
	s.rng.seed = 7
	var next_stomp := 0.0
	for i in range(6000):
		s.advance(.1)
		# A floor full of cans allows the player to choose valuable targets.
		var target := -1
		var best := -1.0
		for item in s.field.items:
			if item.claimed or item.phase == "belt": continue
			var value: float = float(s.cans[item.kind].base_coins)/ceilf(float(item.hp)/Economy.damage(s.config,s.levels))
			if value > best:
				best = value
				target = int(item.id)
		if s.elapsed >= next_stomp and target >= 0 and s.stomp(target):
			next_stomp = s.elapsed + Economy.cooldown(s.config,s.levels)/duty
		if s.levels.power == 0: try_upgrade(s,"power",2)
		if s.levels.value == 0: try_upgrade(s,"value",8)
		try_unlock(s,"blue_can")
		if s.levels.power == 1: try_upgrade(s,"power",25)
		if s.levels.speed == 0: try_upgrade(s,"speed",28)
		if s.levels.value == 1: try_upgrade(s,"value",42)
		try_unlock(s,"gold_can")
		if s.levels.power == 2: try_upgrade(s,"power",95)
		try_unlock(s,"auto_stomper")
		if s.unlocks.auto_stomper and s.levels.auto_speed == 0: try_upgrade(s,"auto_speed",145)
		try_unlock(s,"conveyor")
	return s

func _initialize() -> void:
	var standard := simulate(.4)
	print("GUIDED_ENGINE_SIMULATION 40% duty (NOT human playtest)")
	for event in events: print(event)
	print("WALLET=",standard.coins," CRUSHED=",standard.crushed," UNLOCKS=",standard.unlocks)
	var casual := simulate(.32)
	var ok: bool = standard.unlocks.values().all(func(value): return value) and casual.unlocks.auto_stomper and standard.coins >= 0 and casual.coins >= 0
	print("PROGRESSION_TESTS: ","PASS" if ok else "FAIL"," casual auto=",casual.unlocks.auto_stomper)
	quit(0 if ok else 1)
