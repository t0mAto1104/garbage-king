class_name StompState
extends RefCounted

signal changed
signal hit(can: Dictionary, payout: int)
signal spawned
signal auto_completed(payout: int)
signal purchased(id: String)
signal summary_due

const Economy = preload("res://scripts/economy.gd")
const CanField = preload("res://scripts/can_field.gd")
var config: Dictionary
var cans := {}
var upgrades := {}
var unlock_defs := {}
var levels := {}
var unlocks := {}
var coins := 0
var earned := 0
var crushed := 0
var manual_crushed := 0
var auto_crushed := 0
var elapsed := 0.0
var summary_seen := false
var settings := {"muted": false, "reduced": false}
var field := CanField.new()
var cooldown_left := 0.0
var auto_progress := 0.0
var paused := false
var rng := RandomNumberGenerator.new()

func _init(data: Dictionary = {}) -> void:
	if data.is_empty():
		return
	config = data
	for c in data.cans:
		cans[c.id] = c
	for u in data.upgrades:
		upgrades[u.id] = u
		levels[u.id] = 0
	for u in data.unlocks:
		unlock_defs[u.id] = u
		unlocks[u.id] = false
	coins = int(config.gameplay.initial_coins)
	rng.randomize()

func spawn_can() -> Dictionary:
	var kind := choose_can()
	var item := field.spawn(kind,int(cans[kind].hp))
	spawned.emit()
	changed.emit()
	return item

func choose_can() -> String:
	if unlocks.get("gold_can", false) and rng.randf() < float(config.gameplay.rare_can_probability_after_unlock):
		return "gold"
	if unlocks.get("blue_can", false) and rng.randf() < float(config.gameplay.blue_can_probability_after_unlock):
		return "blue"
	return "red"

func advance(delta: float) -> void:
	if paused or delta <= 0.0:
		return
	elapsed += delta
	cooldown_left = maxf(0.0, cooldown_left - delta)
	field.advance(delta,Economy.feed_interval(config,levels),spawn_can)
	if unlocks.get("auto_stomper", false):
		auto_progress += delta / Economy.auto_interval(config, levels, unlocks)
		while auto_progress >= 1.0:
			auto_progress -= 1.0
			var amount := Economy.reward(config, levels, cans.red)
			credit(amount, true)
			auto_completed.emit(amount)
	if not summary_seen and elapsed >= float(config.gameplay.summary_appears_after_seconds):
		summary_seen = true
		summary_due.emit()

func stomp(serial: int = -1) -> bool:
	var item: Dictionary = field.by_id.get(serial,{}) if serial >= 0 else field.keyboard_target()
	if paused or item.is_empty() or item.claimed or item.phase == "belt" or int(item.hp) <= 0 or cooldown_left > 0.00001:
		return false
	cooldown_left = Economy.cooldown(config, levels)
	item.hp = maxi(0,int(item.hp)-Economy.damage(config,levels))
	var amount := 0
	if item.hp == 0:
		# Claim BEFORE any signal, preventing reentrant rewards.
		field.impact_can(item,true,float(config.gameplay.replacement_delay_seconds))
		amount = Economy.reward(config, levels, cans[item.kind])
		credit(amount, false)
	else:
		field.impact_can(item,false,0)
	hit.emit(item,amount)
	changed.emit()
	return true

func credit(amount: int, from_auto: bool) -> void:
	coins += amount
	earned += amount
	crushed += 1
	if from_auto:
		auto_crushed += 1
	else:
		manual_crushed += 1
	changed.emit()

func price(id: String) -> int:
	if upgrades.has(id):
		var level: int = levels[id]
		return -1 if level >= int(upgrades[id].max_level) else int(upgrades[id].costs[level])
	return int(unlock_defs[id].cost) if unlock_defs.has(id) and not unlocks[id] else -1

func blocked_reason(id: String) -> String:
	if paused:
		return "暂停中"
	if price(id) < 0:
		return "已满级" if upgrades.has(id) else "已解锁"
	if id == "auto_speed" and not unlocks.auto_stomper:
		return "先解锁自动踩踏机"
	if unlock_defs.has(id):
		var d: Dictionary = unlock_defs[id]
		if crushed < int(d.requires_crushed):
			return "需踩扁 %d / %d" % [crushed, d.requires_crushed]
		if d.has("requires_unlock") and not unlocks.get(d.requires_unlock, false):
			return "先解锁自动踩踏机"
	return "金币不足" if coins < price(id) else ""

func purchase(id: String) -> bool:
	if not upgrades.has(id) and not unlock_defs.has(id):
		return false
	if not blocked_reason(id).is_empty():
		return false
	coins -= price(id)
	if upgrades.has(id):
		levels[id] += 1
	else:
		unlocks[id] = true
	purchased.emit(id)
	changed.emit()
	return true

func snapshot() -> Dictionary:
	return {"version": 2, "coins": coins, "earned": earned, "crushed": crushed, "manual_crushed": manual_crushed, "auto_crushed": auto_crushed, "levels": levels.duplicate(), "unlocks": unlocks.duplicate(), "elapsed": elapsed, "summary_seen": summary_seen, "settings": settings.duplicate(),"field":field.snapshot()}

func restore(d: Dictionary) -> bool:
	if int(d.get("version", -1)) not in [1,2]:
		return false
	for key in ["coins", "earned", "crushed", "elapsed"]:
		if not d.has(key) or not (d[key] is int or d[key] is float) or not is_finite(float(d[key])) or float(d[key]) < 0:
			return false
	if not d.get("levels", {}) is Dictionary or not d.get("unlocks", {}) is Dictionary or not d.get("settings", {}) is Dictionary:
		return false
	for id in levels:
		var value = d.get("levels", {}).get(id, 0)
		if not (value is int or value is float) or not is_finite(float(value)):
			return false
	var restored_field := CanField.new()
	if int(d.version) == 2:
		if not d.get("field") is Dictionary or not restored_field.restore(d.field,cans): return false
	field = restored_field
	coins = clampi(int(d.coins), 0, 2000000000)
	earned = maxi(coins, clampi(int(d.earned), 0, 2000000000))
	crushed = clampi(int(d.crushed), 0, 2000000000)
	auto_crushed = clampi(int(d.get("auto_crushed", 0)), 0, crushed)
	manual_crushed = crushed - auto_crushed
	elapsed = clampf(float(d.elapsed), 0, 1000000000)
	for id in levels:
		levels[id] = clampi(int(d.get("levels", {}).get(id, 0)), 0, int(upgrades[id].max_level))
	for id in unlocks:
		unlocks[id] = d.get("unlocks", {}).get(id, false) == true
	if not unlocks.auto_stomper:
		unlocks.conveyor = false
		levels.auto_speed = 0
	for id in settings:
		settings[id] = d.get("settings", {}).get(id, false) == true
	summary_seen = d.get("summary_seen", false) == true
	auto_progress = 0.0
	cooldown_left = 0.0
	changed.emit()
	return true
