class_name YardEconomy
extends RefCounted

static func cooldown(data: Dictionary, tool: Dictionary, levels: Dictionary, frenzy: bool) -> float:
	var result := maxf(float(tool.min_cooldown),float(tool.cooldown)*(1-float(data.gameplay.tool_speed_per_level)*int(levels.speed)))
	return result/(float(data.gameplay.frenzy_speed) if frenzy else 1.0)

static func damage(data: Dictionary, tool: Dictionary, levels: Dictionary, material: String, weak: bool, ramp: float = 1) -> int:
	var base := float(tool.damage)+float(data.gameplay.power_per_level)*int(levels.power)
	return maxi(1,roundi(base*float(tool.affinity[material])*(float(data.gameplay.weak_multiplier) if weak else 1.0)*ramp))

static func reward(data: Dictionary, item: Dictionary, levels: Dictionary, event_multiplier: float) -> int:
	return maxi(1,roundi(float(item.base_coins)*(1+float(data.gameplay.value_bonus_per_level)*int(levels.value))*event_multiplier))

static func auto_interval(data: Dictionary, levels: Dictionary) -> float:
	return float(data.gameplay.auto_interval_seconds[mini(int(levels.auto_speed),data.gameplay.auto_interval_seconds.size()-1)])*(float(data.gameplay.conveyor_multiplier) if int(levels.conveyor)>0 else 1.0)
