class_name StompCanField
extends RefCounted

# Fixed-step, top-down pseudo physics. Sleeping cans remain as plain data;
# only rolling, airborne, belt and recently crushed cans are updated.
const STEP := 1.0 / 60.0
const FLOOR := Rect2(365, 310, 842, 255)
const STOMP_AREA := Rect2(345, 280, 890, 334)
const BELT_START := Vector2(341, 236)
const BELT_EXIT := Vector2(590, 252)
const DROP_POINT := Vector2(603, 315)
const BELT_TRAVEL := 0.55
const GRAVITY := 740.0
const DRAG := 2.45
const RADIUS := 22.0
const CELL := 56.0

var items: Array[Dictionary] = []
var active: Array[Dictionary] = []
var by_id := {}
var grid := {}
var next_id := 1
var feed_progress := 0.0
var accumulator := 0.0
var rng := RandomNumberGenerator.new()
var max_shape_scale := 1.0

func _init() -> void:
	rng.randomize()

func spawn(kind: String, max_hp: int, shape_scale: float = 1.0) -> Dictionary:
	var destination := Vector2(rng.randf_range(FLOOR.position.x+35,FLOOR.end.x-35),rng.randf_range(FLOOR.position.y+25,FLOOR.end.y-20))
	var item := {"id":next_id,"kind":kind,"hp":max_hp,"max_hp":max_hp,"claimed":false,
		"pos":BELT_START,"velocity":(destination-DROP_POINT)*1.32,"height":0.0,"vertical_speed":35.0,
		"rotation":0.0,"spin":rng.randf_range(-8,8),"phase":"belt","age":0.0,"impact":0.0,"cleanup":0.0}
	next_id += 1
	if not is_equal_approx(shape_scale,1.0): item.shape_scale = shape_scale
	max_shape_scale = maxf(max_shape_scale,shape_scale)
	items.append(item)
	active.append(item)
	by_id[item.id] = item
	return item

func advance(delta: float, feed_interval: float, deliver: Callable) -> void:
	accumulator += delta
	while accumulator + 0.0000001 >= STEP:
		accumulator = maxf(0,accumulator-STEP)
		feed_progress += STEP / feed_interval
		while feed_progress + 0.0000001 >= 1.0:
			feed_progress = maxf(0,feed_progress-1.0)
			deliver.call()
		_step()

func _cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x/CELL),floori(point.y/CELL))

func _unindex(item: Dictionary) -> void:
	if not item.has("cell"):
		return
	var key: Vector2i = item.cell
	if grid.has(key):
		# Identity is the serial, not Dictionary equality for moving objects.
		var bucket: Array = grid[key]
		for i in range(bucket.size()-1,-1,-1):
			if bucket[i].id == item.id:
				bucket.remove_at(i)
		if bucket.is_empty(): grid.erase(key)
	item.erase("cell")

func _index(item: Dictionary) -> void:
	var key := _cell(item.pos)
	if item.has("cell") and item.cell == key:
		return
	_unindex(item)
	if not grid.has(key): grid[key] = []
	grid[key].append(item)
	item.cell = key

func _step() -> void:
	var keep: Array[Dictionary] = []
	var remove_ids: Array[int] = []
	for item in active:
		item.impact = maxf(0,item.impact-STEP*6)
		if item.claimed:
			item.cleanup -= STEP
			if item.cleanup <= 0:
				_unindex(item)
				by_id.erase(item.id)
				remove_ids.append(item.id)
			else:
				keep.append(item)
			continue
		if item.phase == "belt":
			item.age += STEP
			item.pos = BELT_START.lerp(BELT_EXIT,minf(1,item.age/BELT_TRAVEL))
			if item.age >= BELT_TRAVEL:
				item.phase = "moving"
				item.pos = DROP_POINT
				item.height = 59.0
				item.age = 0.0
			keep.append(item)
			continue
		if item.phase == "moving":
			var flying: bool = item.height > 0.0 or item.vertical_speed > 0.0
			if flying:
				item.vertical_speed -= GRAVITY*STEP
				item.height += item.vertical_speed*STEP
				if item.height <= 0:
					item.height = 0.0
					var speed: float = absf(item.vertical_speed)
					item.vertical_speed = speed*.32 if speed > 62 else 0.0
					item.velocity *= .78
			else:
				item.velocity *= exp(-DRAG*STEP)
			item.pos += item.velocity*STEP
			item.rotation += item.spin*STEP
			item.spin *= exp(-(1.0 if flying else 3.5)*STEP)
			_bounds(item)
			if item.height < 10:
				_contact(item)
				_bounds(item)
			_index(item)
			if item.height == 0.0 and item.vertical_speed == 0.0 and item.velocity.length_squared() < 64:
				item.velocity = Vector2.ZERO
				item.spin = 0.0
				item.phase = "rest"
		if item.phase != "rest" or item.impact > 0:
			keep.append(item)
	active = keep
	if not remove_ids.is_empty():
		var survivors: Array[Dictionary] = []
		for item in items:
			if by_id.has(item.id): survivors.append(item)
		items = survivors

func _bounds(item: Dictionary) -> void:
	if item.pos.x < FLOOR.position.x or item.pos.x > FLOOR.end.x:
		item.pos.x = clampf(item.pos.x,FLOOR.position.x,FLOOR.end.x)
		item.velocity.x *= -.42
	if item.pos.y < FLOOR.position.y or item.pos.y > FLOOR.end.y:
		item.pos.y = clampf(item.pos.y,FLOOR.position.y,FLOOR.end.y)
		item.velocity.y *= -.42

func _contact(item: Dictionary) -> void:
	var key := _cell(item.pos)
	var contacts := 0
	var reach := ceili(RADIUS*(float(item.get("shape_scale",1.0))+max_shape_scale)/CELL)
	for dx in range(-reach,reach+1):
		for dy in range(-reach,reach+1):
			for other in grid.get(key+Vector2i(dx,dy),[]):
				if other.id == item.id or other.claimed or other.height > 10:
					continue
				var offset: Vector2 = item.pos-other.pos
				var distance := offset.length()
				var contact_radius := RADIUS*(float(item.get("shape_scale",1.0))+float(other.get("shape_scale",1.0)))
				if distance >= contact_radius:
					continue
				# Soft, local contacts deflect the newcomer; the settled pile sleeps.
				var normal := offset/distance if distance > .01 else Vector2.from_angle(float(item.id)*2.4)
				item.pos += normal*minf(5,(contact_radius-distance)*.4)
				var approach: float = item.velocity.dot(normal)
				if approach < 0:
					item.velocity -= normal*approach*1.4
					item.spin *= .65
				contacts += 1
				if contacts >= 5: return

func impact_can(item: Dictionary, crushed: bool, cleanup: float) -> void:
	item.impact = 1.0
	if crushed:
		item.claimed = true
		item.cleanup = cleanup
		item.height = 0.0
		item.vertical_speed = 0.0
		item.velocity = Vector2.ZERO
		item.phase = "crushed"
		_unindex(item)
	if not active.has(item): active.append(item)

func visual_position(item: Dictionary) -> Vector2:
	return item.pos-Vector2(0,item.height)

func at_point(point: Vector2) -> Dictionary:
	if not STOMP_AREA.has_point(point): return {}
	var best := {}
	var best_depth := -INF
	for item in items:
		if item.claimed or item.phase == "belt": continue
		var offset := (point-visual_position(item)).rotated(-item.rotation)/(Vector2(26,37)*float(item.get("shape_scale",1.0)))
		if offset.length_squared() <= 1.0 and item.pos.y >= best_depth:
			best = item
			best_depth = item.pos.y
	return best

func keyboard_target() -> Dictionary:
	for item in items:
		if not item.claimed and item.phase != "belt": return item
	return {}

func pending_count() -> int:
	var count := 0
	for item in items:
		if not item.claimed: count += 1
	return count

func gather(point: Vector2, radius: float, speed: float) -> int:
	var count := 0
	for item in items:
		if item.claimed or item.phase == "belt" or item.pos.distance_to(point)>radius: continue
		var direction: Vector2 = point-item.pos
		if direction.length_squared()<900: continue
		item.velocity = direction.normalized()*speed
		item.phase = "moving"
		if not active.has(item): active.append(item)
		count += 1
	return count

func snapshot() -> Dictionary:
	var result: Array[Dictionary] = []
	for item in items:
		var saved := item.duplicate()
		saved.erase("cell")
		saved.pos = [item.pos.x,item.pos.y]
		saved.velocity = [item.velocity.x,item.velocity.y]
		result.append(saved)
	return {"next_id":next_id,"feed_progress":feed_progress,"accumulator":accumulator,"rng_state":str(rng.state),"items":result}

static func finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

func restore(data: Dictionary, can_defs: Dictionary) -> bool:
	# Parse and validate the whole field before replacing any live objects.
	if not data.get("items") is Array: return false
	for key in ["next_id","feed_progress","accumulator"]:
		if not finite_number(data.get(key)): return false
	if float(data.feed_progress) < 0 or float(data.feed_progress) >= 1.000001 or float(data.accumulator) < 0 or float(data.accumulator) > STEP+.000001: return false
	var restored: Array[Dictionary] = []
	var ids := {}
	var highest := 0
	for raw in data.items:
		if not raw is Dictionary or not can_defs.has(raw.get("kind","")): return false
		for key in ["id","hp","max_hp","height","vertical_speed","rotation","spin","age","impact","cleanup"]:
			if not finite_number(raw.get(key)): return false
		if not raw.get("pos") is Array or not raw.get("velocity") is Array or raw.pos.size() != 2 or raw.velocity.size() != 2: return false
		for value in raw.pos+raw.velocity:
			if not finite_number(value): return false
		var serial := int(raw.id)
		if serial < 1 or ids.has(serial): return false
		if not raw.get("phase","") in ["belt","moving","rest","crushed"]: return false
		if int(raw.max_hp) != int(can_defs[raw.kind].hp) or int(raw.hp) < 0 or int(raw.hp) > int(raw.max_hp): return false
		if not raw.get("claimed") is bool or raw.claimed != (int(raw.hp) == 0) or raw.claimed != (raw.phase == "crushed"): return false
		if float(raw.height) < 0 or float(raw.height) > 200 or absf(float(raw.vertical_speed)) > 1000 or float(raw.age) < 0: return false
		if raw.has("shape_scale") and (not finite_number(raw.shape_scale) or float(raw.shape_scale)<.5 or float(raw.shape_scale)>2): return false
		var pos := Vector2(float(raw.pos[0]),float(raw.pos[1]))
		if raw.phase == "belt":
			if not Rect2(330,220,275,50).has_point(pos) or float(raw.age) > BELT_TRAVEL+STEP: return false
		elif not FLOOR.grow(1).has_point(pos): return false
		var item: Dictionary = raw.duplicate()
		item.erase("cell")
		item.id = serial
		item.hp = int(raw.hp)
		item.max_hp = int(raw.max_hp)
		item.pos = pos
		item.velocity = Vector2(float(raw.velocity[0]),float(raw.velocity[1]))
		restored.append(item)
		ids[serial] = true
		highest = maxi(highest,serial)
	if int(data.next_id) <= highest: return false
	items = restored
	active.clear()
	by_id.clear()
	grid.clear()
	max_shape_scale = 1.0
	for item in items:
		max_shape_scale = maxf(max_shape_scale,float(item.get("shape_scale",1.0)))
		by_id[item.id] = item
		if item.phase != "rest" or float(item.impact) > 0: active.append(item)
		if item.phase not in ["belt","crushed"]: _index(item)
	next_id = maxi(1,int(data.next_id))
	feed_progress = float(data.feed_progress)
	accumulator = float(data.accumulator)
	if str(data.get("rng_state","")).is_valid_int(): rng.state = int(str(data.rng_state))
	return true
