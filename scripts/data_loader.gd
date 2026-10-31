class_name BalanceData
extends RefCounted

static func load_config(path: String = "res://data/demo_balance.json") -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "无法读取平衡文件：" + path}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {"error": "平衡 JSON 格式错误："+parser.get_error_message()}
	var raw = parser.data
	if not raw is Dictionary:
		return {"error": "平衡文件不是有效的 JSON 对象。"}
	var error := validate(raw)
	if not error.is_empty():
		return {"error": error}
	return raw

static func validate(d: Dictionary) -> String:
	for key in ["gameplay", "cans", "upgrades", "unlocks", "meta"]:
		if not d.has(key):
			return "平衡文件缺少字段：" + key
	if not d.gameplay is Dictionary or not d.cans is Array or not d.upgrades is Array or not d.unlocks is Array:
		return "平衡文件字段类型错误。"
	var g: Dictionary = d.gameplay
	if not g.get("feed_intervals_seconds") is Array or g.feed_intervals_seconds.is_empty():
		return "缺少供罐间隔配置。"
	var previous := INF
	for interval in g.feed_intervals_seconds:
		if not (interval is int or interval is float) or not is_finite(float(interval)) or float(interval) <= 0 or float(interval) >= previous:
			return "供罐间隔必须为递减的正数。"
		previous = float(interval)
	for key in ["initial_coins", "initial_shoe_damage", "base_stomp_cooldown_seconds", "stomp_cooldown_reduction_per_level", "minimum_stomp_cooldown_seconds", "replacement_delay_seconds", "coin_value_bonus_per_level", "rare_can_probability_after_unlock", "blue_can_probability_after_unlock", "auto_interval_level1_seconds", "auto_interval_level2_seconds", "conveyor_auto_interval_multiplier", "summary_appears_after_seconds", "max_vfx_objects"]:
		if not g.has(key) or not (g[key] is float or g[key] is int) or not is_finite(float(g[key])) or float(g[key]) < 0:
			return "平衡数值缺失或无效：" + key
	for key in ["initial_shoe_damage", "minimum_stomp_cooldown_seconds", "replacement_delay_seconds", "auto_interval_level1_seconds", "auto_interval_level2_seconds", "conveyor_auto_interval_multiplier", "summary_appears_after_seconds"]:
		if float(g[key]) <= 0:
			return "平衡数值必须大于零：" + key
	for key in ["rare_can_probability_after_unlock", "blue_can_probability_after_unlock"]:
		if float(g[key]) > 1:
			return "概率超出范围：" + key
	var ids := {}
	for c in d.cans:
		if not c is Dictionary or not c.has_all(["id", "name", "hp", "base_coins", "sprite_prefix"]) or float(c.hp) <= 0 or float(c.base_coins) <= 0:
			return "罐子配置错误。"
		ids[c.id] = true
	for id in ["red", "blue", "gold"]:
		if not ids.has(id):
			return "缺少罐子：" + id
	ids.clear()
	for u in d.upgrades:
		if not u is Dictionary or not u.has_all(["id", "name", "costs", "max_level", "description"]) or not u.costs is Array or u.costs.size() != int(u.max_level) or int(u.max_level) < 1:
			return "升级配置错误。"
		for price in u.costs:
			if not (price is float or price is int) or float(price) <= 0:
				return "升级价格无效。"
		ids[u.id] = true
		if u.id == "feed_speed" and int(u.max_level)+1 != g.feed_intervals_seconds.size():
			return "供罐速度等级与间隔数量不匹配。"
	for id in ["power", "value", "speed", "auto_speed", "feed_speed"]:
		if not ids.has(id):
			return "缺少升级：" + id
	ids.clear()
	for u in d.unlocks:
		if not u is Dictionary or not u.has_all(["id", "name", "cost", "requires_crushed", "description"]) or float(u.cost) <= 0 or float(u.requires_crushed) < 0:
			return "解锁配置错误。"
		ids[u.id] = true
	for id in ["blue_can", "gold_can", "auto_stomper", "conveyor"]:
		if not ids.has(id):
			return "缺少解锁：" + id
	for u in d.unlocks:
		if u.has("requires_unlock") and not ids.has(u.requires_unlock):
			return "解锁前置配置错误。"
	return ""
