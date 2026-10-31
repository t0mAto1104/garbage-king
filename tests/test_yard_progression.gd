extends SceneTree

const Data = preload("res://scripts/yard/yard_data.gd")
const Model = preload("res://scripts/yard/yard_state.gd")
const Economy = preload("res://scripts/yard/yard_economy.gd")

func simulate(duty: float) -> bool:
	var state:=Model.new(Data.load_config())
	state.rng.seed=7; state.field.rng.seed=42
	var events: Array[String]=[]
	var log_purchase := func(id): events.append("%.2fm %s" % [state.elapsed/60,id])
	state.purchased.connect(log_purchase)
	var next_attack:=0.0
	var peak:=0
	for i in range(15000):
		state.advance(.1)
		var best: Dictionary={}
		var score:=-1.0
		for item in state.field.items:
			if item.claimed or item.phase=="belt" or not state.field.STOMP_AREA.has_point(state.field.visual_position(item)): continue
			var definition: Dictionary=state.catalog[item.kind]
			var damage:=Economy.damage(state.config,state.tools[state.equipped],state.levels,definition.material,int(state.levels.scanner)>0)
			var value:=float(definition.base_coins)/ceilf(float(item.hp)/damage)
			if value>score: score=value; best=item
		if not best.is_empty() and state.elapsed>=next_attack and state.attack(best.id,state.weak_point(best) if int(state.levels.scanner)>0 else Vector2(-10000,-10000)):
			next_attack=state.elapsed+state.cooldown()/duty
		if state.energy>=100: state.activate_frenzy()
		if int(state.levels.power)==0: state.purchase("power")
		if not state.owned.fist: state.purchase("tool:fist")
		if state.owned.fist:
			if int(state.levels.value)==0: state.purchase("value")
			if int(state.levels.depth)==0: state.purchase("depth")
			if int(state.levels.quality)==0: state.purchase("quality")
			if int(state.levels.feed_speed)==0: state.purchase("feed_speed")
			if not state.owned.hammer: state.purchase("tool:hammer")
		if state.owned.hammer:
			if int(state.levels.scanner)==0: state.purchase("scanner")
			if int(state.levels.speed)==0: state.purchase("speed")
			if int(state.levels.value)==1: state.purchase("value")
			if int(state.levels.feed_speed)==1: state.purchase("feed_speed")
			if not state.owned.drill: state.purchase("tool:drill")
		if state.owned.drill:
			if int(state.levels.depth)==1: state.purchase("depth")
			if int(state.levels.auto_stomper)==0: state.purchase("auto_stomper")
		peak=maxi(peak,state.field.items.size())
		if state.completed and state.owned.drill and int(state.levels.auto_stomper)>0: break
	print("YARD_PROGRESSION: %d%% effective contact, deterministic simulation, NOT human playtest" % roundi(duty*100))
	for event in events: print(event)
	print("%.2fm; %d crushed; %d wallet; peak objects %d; chapter complete=%s" % [state.elapsed/60,state.crushed,state.coins,peak,state.completed])
	var passed: bool=state.owned.fist and state.owned.hammer and state.owned.drill and int(state.levels.depth)==2 and int(state.levels.auto_stomper)>0 and state.completed and state.coins>=0
	print("YARD_PROGRESSION: ","PASS" if passed else "FAIL")
	state.purchased.disconnect(log_purchase)
	return passed

func _initialize() -> void:
	var passed := true
	for duty in [.30,.50,.75]:
		if not simulate(duty): passed=false
	quit(0 if passed else 1)
