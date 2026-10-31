class_name YardState
extends RefCounted

signal changed
signal hit(item: Dictionary, payout: int, damage: int, weak: bool)
signal purchased(id: String)
signal auto_completed(payout: int)
signal event_started(id: String)
signal milestone(id: String)

const Field = preload("res://scripts/can_field.gd")
const Economy = preload("res://scripts/yard/yard_economy.gd")
const LegacyState = preload("res://scripts/game_state.gd")
const LegacyData = preload("res://scripts/data_loader.gd")
var config: Dictionary
var catalog := {}
var tools := {}
var upgrades := {}
var levels := {}
var owned := {"shoe":true,"fist":false,"hammer":false,"drill":false}
var equipped := "shoe"
var field := Field.new()
var coins := 0
var earned := 0
var crushed := 0
var manual_crushed := 0
var auto_crushed := 0
var elapsed := 0.0
var cooldown_left := 0.0
var auto_progress := 0.0
var energy := 0.0
var frenzy_left := 0.0
var combo := 0
var last_kill := -100.0
var drill_target := -1
var drill_streak := 0
var last_attack := -100.0
var magnet_left := 0.0
var event_id := ""
var event_left := 0.0
var next_event := 150.0
var discovered := {}
var recovered := {}
var story_flags: Array[String] = []
var completed := false
var paused := false
var settings := {"muted":false,"music":true,"reduced":false}
var rng := RandomNumberGenerator.new()

func _init(data: Dictionary = {}) -> void:
	if data.is_empty(): return
	config = data
	coins = int(data.gameplay.initial_coins)
	next_event = float(data.gameplay.first_event_seconds)
	for item in data.trash:
		catalog[item.id] = item
		discovered[item.id] = 0
		recovered[item.id] = 0
	for tool in data.tools: tools[tool.id] = tool
	for up in data.upgrades:
		upgrades[up.id] = up
		levels[up.id] = 0
	rng.randomize()

func choose_trash() -> String:
	var candidates: Array[Dictionary] = []
	var total := 0.0
	for item in config.trash:
		if int(item.depth)>int(levels.depth) or int(item.get("quality",0))>int(levels.quality): continue
		var weight := float(item.weight)*(1+int(levels.quality) if item.id=="gold" else 1)
		total += weight
		candidates.append({"id":item.id,"weight":weight})
	var roll := rng.randf()*total
	for item in candidates:
		roll -= float(item.weight)
		if roll<=0: return item.id
	return "red"

func spawn(kind: String = "") -> Dictionary:
	if kind.is_empty(): kind = choose_trash()
	var definition: Dictionary = catalog[kind]
	var item := field.spawn(kind,int(definition.hp),float(definition.scale))
	if float(definition.scale)>1.2:
		item.velocity *= .8
		item.spin *= .35
	discovered[kind] += 1
	changed.emit()
	return item

func _deliver() -> void:
	spawn()

func event_definition() -> Dictionary:
	for definition in config.events:
		if definition.id == event_id: return definition
	return {}

func feed_interval() -> float:
	var interval := float(config.gameplay.feed_intervals_seconds[int(levels.feed_speed)])
	if frenzy_left>0: interval /= float(config.gameplay.frenzy_feed)
	var definition := event_definition()
	if event_left>0 and not definition.is_empty(): interval /= float(definition.feed_multiplier)
	return interval

func cooldown() -> float:
	return Economy.cooldown(config,tools[equipped],levels,frenzy_left>0)

func advance(delta: float) -> void:
	if paused or delta<=0: return
	elapsed += delta
	cooldown_left = maxf(0,cooldown_left-delta)
	magnet_left = maxf(0,magnet_left-delta)
	frenzy_left = maxf(0,frenzy_left-delta)
	event_left = maxf(0,event_left-delta)
	if event_left<=0: event_id = ""
	if elapsed-last_kill>float(config.gameplay.combo_window_seconds): combo = 0
	field.advance(delta,feed_interval(),_deliver)
	if int(levels.auto_stomper)>0:
		auto_progress += delta/Economy.auto_interval(config,levels)
		while auto_progress>=1:
			auto_progress -= 1
			var payout := Economy.reward(config,catalog.red,levels,1)
			coins += payout; earned += payout; crushed += 1; auto_crushed += 1
			recovered.red += 1
			auto_completed.emit(payout)
			changed.emit()
	if elapsed>=next_event and event_left<=0:
		start_event(config.events[rng.randi_range(0,config.events.size()-1)].id)
		next_event = elapsed+float(config.gameplay.event_interval_seconds)

func start_event(id: String) -> bool:
	for definition in config.events:
		if definition.id != id: continue
		event_id = id
		event_left = float(definition.seconds)
		if id=="parcel": spawn("washer" if int(levels.depth)>0 else "keyboard")
		event_started.emit(id)
		changed.emit()
		return true
	return false

func activate_frenzy() -> bool:
	if paused or frenzy_left>0 or energy<float(config.gameplay.frenzy_threshold): return false
	energy = 0
	frenzy_left = float(config.gameplay.frenzy_seconds)
	changed.emit()
	return true

func gather(point: Vector2) -> int:
	if paused or int(levels.magnet)==0 or magnet_left>0: return 0
	var target := Vector2(clampf(point.x,Field.FLOOR.position.x,Field.FLOOR.end.x),clampf(point.y,Field.FLOOR.position.y,Field.FLOOR.end.y))
	var count := field.gather(target,float(config.gameplay.magnet_radius),float(config.gameplay.magnet_speed))
	if count>0: magnet_left = float(config.gameplay.magnet_cooldown)
	return count

func weak_point(item: Dictionary) -> Vector2:
	return field.visual_position(item)+Vector2(8,-7).rotated(float(item.rotation))*float(item.get("shape_scale",1.0))

func attack(serial: int = -1, point: Vector2 = Vector2(-10000,-10000)) -> bool:
	var item: Dictionary = field.by_id.get(serial,{}) if serial>=0 else field.keyboard_target()
	if paused or cooldown_left>.00001 or item.is_empty() or item.claimed or item.phase=="belt": return false
	cooldown_left = cooldown()
	var weak := int(levels.scanner)>0 and point.distance_to(weak_point(item))<=10*float(item.get("shape_scale",1.0))
	var ramp := 1.0
	if equipped=="drill":
		drill_streak = drill_streak+1 if drill_target==int(item.id) and elapsed-last_attack<=float(tools.drill.chain_window_seconds) else 0
		drill_target = int(item.id)
		ramp = minf(float(tools.drill.ramp_limit),1+drill_streak*float(tools.drill.ramp_per_hit))
	else:
		drill_streak = 0; drill_target = -1
	last_attack = elapsed
	var damage := Economy.damage(config,tools[equipped],levels,catalog[item.kind].material,weak,ramp)
	var origin: Vector2 = item.pos
	var primary_id: int = item.id
	_apply_damage(item,damage,weak)
	if equipped=="hammer":
		var candidates: Array[Dictionary] = []
		for other in field.items:
			if other.id!=primary_id and not other.claimed and other.phase!="belt" and other.pos.distance_to(origin)<=float(tools.hammer.splash_radius): candidates.append(other)
		candidates.sort_custom(func(a,b): return a.pos.distance_squared_to(origin)<b.pos.distance_squared_to(origin))
		for i in range(mini(int(tools.hammer.splash_targets),candidates.size())):
			_apply_damage(candidates[i],maxi(1,roundi(damage*float(tools.hammer.splash_fraction))),false)
	changed.emit()
	return true

func _apply_damage(item: Dictionary, damage: int, weak: bool) -> void:
	if item.claimed: return
	item.hp = maxi(0,int(item.hp)-damage)
	var payout := 0
	if item.hp==0:
		# Claim before any signal or secondary area hit.
		field.impact_can(item,true,float(config.gameplay.replacement_delay_seconds))
		var definition := event_definition()
		var multiplier: float = float(definition.reward_multiplier) if event_left>0 and not definition.is_empty() else 1.0
		payout = Economy.reward(config,catalog[item.kind],levels,multiplier)
		coins += payout; earned += payout; crushed += 1; manual_crushed += 1
		recovered[item.kind] += 1
		combo = combo+1 if elapsed-last_kill<=float(config.gameplay.combo_window_seconds) else 1
		last_kill = elapsed
		if frenzy_left<=0:
			energy = minf(float(config.gameplay.frenzy_threshold),energy+float(config.gameplay.energy_per_crush)+(float(config.gameplay.combo_energy) if combo>1 else 0)+(float(config.gameplay.weak_energy) if weak else 0))
		_check_completion()
	else:
		field.impact_can(item,false,0)
	hit.emit(item,payout,damage,weak)

func price(id: String) -> int:
	if id.begins_with("tool:"):
		var name := id.trim_prefix("tool:")
		return int(tools[name].cost) if tools.has(name) and not owned[name] else -1
	if not upgrades.has(id): return -1
	return int(upgrades[id].costs[int(levels[id])]) if int(levels[id])<upgrades[id].costs.size() else -1

func blocked_reason(id: String) -> String:
	if paused: return "已暂停"
	if price(id)<0: return "已拥有"
	if id.begins_with("tool:"):
		var definition: Dictionary = tools[id.trim_prefix("tool:")]
		if crushed<int(definition.requires_crushed): return "%d / %d 罐" % [crushed,definition.requires_crushed]
	else:
		var definition: Dictionary = upgrades[id]
		if definition.has("requires_depth") and int(levels.depth)<int(definition.requires_depth): return "需深度 I"
		if definition.has("requires_upgrade") and int(levels[definition.requires_upgrade])==0: return "需自动线"
		if definition.has("requires_crushed") and crushed<int(definition.requires_crushed[int(levels[id])]): return "%d / %d 罐" % [crushed,definition.requires_crushed[int(levels[id])]]
	return "金币不足" if coins<price(id) else ""

func purchase(id: String) -> bool:
	if not blocked_reason(id).is_empty(): return false
	coins -= price(id)
	if id.begins_with("tool:"):
		var name := id.trim_prefix("tool:")
		owned[name] = true
		equip(name)
		if name=="fist" and not story_flags.has("installed_fist"):
			story_flags.append("installed_fist")
			milestone.emit("installed_fist")
	else:
		levels[id] += 1
	purchased.emit(id)
	_check_completion()
	changed.emit()
	return true

func _check_completion() -> void:
	if not completed and owned.drill and int(levels.depth)>=2 and int(recovered.washer)>0:
		completed = true
		milestone.emit("chapter_done")

func equip(id: String) -> bool:
	if paused or not owned.get(id,false): return false
	equipped = id
	# Switching cannot clear an existing cooldown or claim any rewards.
	drill_target = -1; drill_streak = 0
	changed.emit()
	return true

func chapter() -> int:
	return 2 if completed else (1 if owned.fist else 0)

func snapshot() -> Dictionary:
	return {"version":3,"coins":coins,"earned":earned,"crushed":crushed,"manual_crushed":manual_crushed,"auto_crushed":auto_crushed,"elapsed":elapsed,"levels":levels.duplicate(),"owned":owned.duplicate(),"equipped":equipped,"field":field.snapshot(),"energy":energy,"frenzy_left":frenzy_left,"magnet_left":magnet_left,"event_id":event_id,"event_left":event_left,"next_event":next_event,"discovered":discovered.duplicate(),"recovered":recovered.duplicate(),"story_flags":story_flags.duplicate(),"completed":completed,"settings":settings.duplicate(),"rng_state":str(rng.state)}

func restore(data: Dictionary) -> bool:
	if data.get("version")!=3: return false
	for key in ["coins","earned","crushed","manual_crushed","auto_crushed","elapsed","energy","frenzy_left","magnet_left","event_left","next_event"]:
		if not YardData.number(data.get(key)): return false
	for key in ["levels","owned","field","discovered","recovered","settings"]:
		if not data.get(key) is Dictionary: return false
	if not data.get("story_flags") is Array or not data.get("equipped") is String or not tools.has(data.equipped): return false
	for key in levels:
		if not YardData.number(data.levels.get(key)) or int(data.levels[key])>upgrades[key].costs.size(): return false
	for key in owned:
		if not data.owned.get(key) is bool: return false
	if not data.owned.shoe or not data.owned[data.equipped]: return false
	for key in catalog:
		if not YardData.number(data.discovered.get(key)) or not YardData.number(data.recovered.get(key)): return false
	for flag in data.story_flags:
		if not flag is String: return false
	var new_field := Field.new()
	if not new_field.restore(data.field,catalog): return false
	field = new_field
	coins = clampi(int(data.coins),0,2000000000); earned = maxi(coins,int(data.earned))
	crushed = int(data.crushed); auto_crushed = mini(crushed,int(data.auto_crushed)); manual_crushed = crushed-auto_crushed
	elapsed = float(data.elapsed)
	for key in levels: levels[key] = int(data.levels[key])
	if int(levels.auto_stomper)==0: levels.auto_speed=0; levels.conveyor=0
	owned = data.owned.duplicate(); equipped = data.equipped
	energy = clampf(float(data.energy),0,float(config.gameplay.frenzy_threshold))
	frenzy_left = clampf(float(data.frenzy_left),0,float(config.gameplay.frenzy_seconds))
	magnet_left = clampf(float(data.magnet_left),0,float(config.gameplay.magnet_cooldown))
	event_id = str(data.get("event_id","")); event_left = float(data.event_left)
	if event_definition().is_empty(): event_id=""; event_left=0
	next_event = maxf(elapsed,float(data.next_event))
	discovered = data.discovered.duplicate(); recovered = data.recovered.duplicate()
	story_flags.clear()
	for flag in data.story_flags: story_flags.append(flag)
	completed = data.get("completed",false)==true
	for key in settings: settings[key] = data.settings.get(key,false)==true
	if str(data.get("rng_state","")).is_valid_int(): rng.state = int(str(data.rng_state))
	cooldown_left = 0; auto_progress = 0; drill_target = -1; drill_streak = 0; combo = 0; last_kill = -100
	changed.emit()
	return true

func import_legacy(data: Dictionary) -> bool:
	var legacy_config := LegacyData.load_config()
	if legacy_config.has("error"): return false
	var legacy := LegacyState.new(legacy_config)
	if not legacy.restore(data): return false
	var new_field := Field.new()
	if not new_field.restore(legacy.field.snapshot(),catalog): return false
	field = new_field
	coins = legacy.coins; earned = legacy.earned; crushed = legacy.crushed
	manual_crushed = legacy.manual_crushed; auto_crushed = legacy.auto_crushed; elapsed = legacy.elapsed
	for key in ["power","value","speed","feed_speed","auto_speed"]: levels[key] = legacy.levels[key]
	levels.auto_stomper = 1 if legacy.unlocks.auto_stomper else 0
	levels.conveyor = 1 if legacy.unlocks.conveyor else 0
	levels.depth = 1 if legacy.unlocks.blue_can else 0
	levels.quality = 1 if legacy.unlocks.gold_can else 0
	settings.muted = legacy.settings.muted; settings.reduced = legacy.settings.reduced
	for item in field.items: discovered[item.kind] += 1
	story_flags.append("legacy_imported")
	next_event = elapsed+float(config.gameplay.first_event_seconds)
	changed.emit()
	return true
