class_name StompEconomy
extends RefCounted

static func damage(config: Dictionary, levels: Dictionary) -> int:
	var effect := 0
	for upgrade in config.upgrades:
		if upgrade.id == "power":
			effect = int(upgrade.effect_per_level)
	return int(config.gameplay.initial_shoe_damage) + int(levels.get("power", 0))*effect

static func cooldown(config: Dictionary, levels: Dictionary) -> float:
	var g: Dictionary = config.gameplay
	return maxf(g.minimum_stomp_cooldown_seconds, g.base_stomp_cooldown_seconds - g.stomp_cooldown_reduction_per_level * int(levels.get("speed", 0)))

static func reward(config: Dictionary, levels: Dictionary, can: Dictionary) -> int:
	return roundi(float(can.base_coins) * (1.0 + float(config.gameplay.coin_value_bonus_per_level) * int(levels.get("value", 0))))

static func auto_interval(config: Dictionary, levels: Dictionary, unlocks: Dictionary) -> float:
	var g: Dictionary = config.gameplay
	var result: float = g.auto_interval_level2_seconds if int(levels.get("auto_speed", 0)) > 0 else g.auto_interval_level1_seconds
	return result * (float(g.conveyor_auto_interval_multiplier) if unlocks.get("conveyor", false) else 1.0)

static func stage(hp: int, max_hp: int) -> int:
	return 4 if hp <= 0 else clampi(floori(4.0 * (max_hp - hp) / max_hp), 0, 3)

static func feed_interval(config: Dictionary, levels: Dictionary) -> float:
	var intervals: Array = config.gameplay.feed_intervals_seconds
	return float(intervals[clampi(int(levels.get("feed_speed",0)),0,intervals.size()-1)])
