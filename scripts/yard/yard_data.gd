class_name YardData
extends RefCounted

static func load_config(path: String = "res://data/yard_balance.json") -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return {"error":"无法读取工坊配置"}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary: return {"error":"工坊 JSON 格式错误"}
	var data: Dictionary = parser.data
	var error := validate(data)
	return data if error.is_empty() else {"error":error}

static func number(value: Variant, positive: bool = false) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and (float(value)>0 if positive else float(value)>=0)

static func validate(data: Dictionary) -> String:
	if data.get("schema_version") != 1: return "工坊配置版本不兼容"
	for key in ["gameplay","trash","tools","upgrades","events","chapters"]:
		if not data.has(key): return "缺少工坊字段："+key
	if not data.gameplay is Dictionary: return "gameplay 必须为对象"
	if not data.chapters is Array or data.chapters.size()<3: return "缺少章节标题"
	for chapter in data.chapters:
		if not chapter is String or chapter.is_empty(): return "章节标题无效"
	var g: Dictionary = data.gameplay
	for key in ["initial_coins","max_vfx_objects","replacement_delay_seconds","value_bonus_per_level","power_per_level","tool_speed_per_level","weak_multiplier","combo_window_seconds","energy_per_crush","combo_energy","weak_energy","frenzy_threshold","frenzy_seconds","frenzy_speed","frenzy_feed","conveyor_multiplier","magnet_cooldown","magnet_radius","magnet_speed","first_event_seconds","event_interval_seconds"]:
		if not number(g.get(key),key != "initial_coins"): return "工坊数值无效："+key
	if float(g.tool_speed_per_level) >= .5: return "工具加速参数超出范围"
	for key in ["feed_intervals_seconds","auto_interval_seconds"]:
		if not g.get(key) is Array or g[key].is_empty(): return "缺少间隔表："+key
		for value in g[key]:
			if not number(value,true): return "间隔必须大于零"
	var ids := {}
	for key in ["trash","tools","upgrades","events"]:
		if not data[key] is Array or data[key].is_empty(): return "目录为空："+key
		ids[key] = {}
		for entry in data[key]:
			if not entry is Dictionary or not entry.get("id") is String or not entry.get("name") is String or ids[key].has(entry.id): return "目录 ID 无效/重复："+key
			ids[key][entry.id] = true
	for item in data.trash:
		if not item.has_all(["hp","base_coins","depth","material","weight","scale","visual"]): return "废品字段缺失"
		if not number(item.hp,true) or int(item.hp) != float(item.hp) or not number(item.base_coins,true) or not number(item.weight,true) or not number(item.scale,true) or float(item.scale)>2 or not number(item.depth): return "废品数值无效"
		if item.material not in ["light","metal","mechanical","composite"]: return "废品材质无效"
	for tool in data.tools:
		if not tool.has_all(["cost","damage","cooldown","min_cooldown","affinity","visual","requires_crushed"]): return "工具字段缺失"
		if not number(tool.cost) or not number(tool.damage,true) or not number(tool.cooldown,true) or not number(tool.min_cooldown,true) or not tool.affinity is Dictionary: return "工具数值无效"
		for material in ["light","metal","mechanical","composite"]:
			if not number(tool.affinity.get(material),true): return "工具相性无效"
		if tool.id=="hammer":
			for key in ["splash_radius","splash_fraction","splash_targets"]:
				if not number(tool.get(key),true): return "重锤震荡参数无效"
		if tool.id=="drill":
			for key in ["ramp_per_hit","ramp_limit","chain_window_seconds"]:
				if not number(tool.get(key),true): return "电钻连钻参数无效"
	for up in data.upgrades:
		if not up.get("costs") is Array or up.costs.is_empty(): return "升级价格为空"
		for price in up.costs:
			if not number(price,true): return "升级价格无效"
		if up.has("requires_crushed") and (not up.requires_crushed is Array or up.requires_crushed.size() != up.costs.size()): return "升级门槛数量不匹配"
		if up.has("requires_upgrade") and not ids.upgrades.has(up.requires_upgrade): return "升级前置不存在"
	for id in ["shoe","fist","hammer","drill"]:
		if not ids.tools.has(id): return "缺少工具："+id
	for id in ["red","blue","gold"]:
		if not ids.trash.has(id): return "缺少兼容罐型："+id
	for id in ["power","value","speed","feed_speed","depth","quality","scanner","magnet","auto_stomper","auto_speed","conveyor"]:
		if not ids.upgrades.has(id): return "缺少升级："+id
	for up in data.upgrades:
		if up.id == "feed_speed" and up.costs.size()+1 != g.feed_intervals_seconds.size(): return "供货等级数量不匹配"
	for event in data.events:
		for key in ["seconds","feed_multiplier","reward_multiplier"]:
			if not number(event.get(key),true): return "事件参数无效"
	return ""
