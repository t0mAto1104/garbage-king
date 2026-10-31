extends SceneTree

const Data = preload("res://scripts/yard/yard_data.gd")
const Model = preload("res://scripts/yard/yard_state.gd")
const Economy = preload("res://scripts/yard/yard_economy.gd")
const Save = preload("res://scripts/yard/yard_save.gd")
const OldModel = preload("res://scripts/game_state.gd")
const OldData = preload("res://scripts/data_loader.gd")
var config: Dictionary
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition:
		failures+=1; push_error("FAIL: "+message)

func target(s: YardState, kind: String, point: Vector2 = Vector2(800,430)) -> Dictionary:
	var item := s.spawn(kind)
	item.phase="rest"; item.pos=point; item.height=0; item.velocity=Vector2.ZERO
	item.vertical_speed=0; item.spin=0
	s.field._index(item)
	return item

func _initialize() -> void:
	config=Data.load_config()
	check(not config.has("error"),"new data validates")
	if config.has("error"): quit(1); return
	var s := Model.new(config)
	check(s.coins==0 and s.equipped=="shoe" and s.field.items.is_empty(),"fresh yard")
	check(is_equal_approx(s.cooldown(),.68) and is_equal_approx(s.feed_interval(),1),"original shoe and feed rhythm")
	s.rng.seed=9; s.field.rng.seed=17
	s.advance(10)
	check(s.field.pending_count()==10 and s.coins==0,"all supplied junk accumulates")
	check(s.field.items.all(func(item): return int(s.catalog[item.kind].depth)==0 and item.kind!="gold"),"initial pool gated")
	for kind in s.catalog:
		for frame in range(5): check(ResourceLoader.exists(s.catalog[kind].visual % frame),"five-frame asset "+kind)
	s=Model.new(config)
	var a := target(s,"red")
	var b := target(s,"red",Vector2(1000,450))
	check(s.attack(a.id) and a.hp==2 and b.hp==3 and s.coins==0,"shoe damages only selected junk")
	check(not s.attack(b.id) and b.hp==3,"global cooldown across targets")
	s.advance(.68); s.attack(a.id); s.advance(.68)
	var reentry := func(item,_p,_d,_w): s.attack(item.id)
	s.hit.connect(reentry); s.attack(a.id); s.hit.disconnect(reentry)
	check(a.claimed and s.coins==6 and s.crushed==1,"claim before reentrant signal")
	for i in range(100): s.attack(a.id)
	check(s.coins==6,"crushed target never repeats payout")
	check(not s.purchase("tool:fist"),"tool purchase gate and wallet")
	s.coins=20000; s.earned=20000; s.crushed=100; s.manual_crushed=100
	check(s.purchase("tool:fist") and s.equipped=="fist","buy and equip first prosthesis")
	var wallet:=s.coins
	check(not s.purchase("tool:fist") and s.coins==wallet,"duplicate prosthesis not charged")
	s.cooldown_left=.3; s.equip("shoe"); s.equip("fist")
	check(is_equal_approx(s.cooldown_left,.3),"switching does not reset cooldown")
	check(s.purchase("tool:hammer") and s.purchase("tool:drill"),"all slice tools unlock")
	s=Model.new(config); s.owned.hammer=true; s.equipped="hammer"
	a=target(s,"red"); b=target(s,"red",Vector2(850,430))
	var far := target(s,"red",Vector2(1100,500))
	s.attack(a.id)
	check(a.claimed and b.claimed and far.hp==3 and s.crushed==2 and s.coins==12,"hammer shockwave bounded and individually credited")
	s=Model.new(config); s.owned.drill=true; s.equipped="drill"
	a=target(s,"washer")
	var hp: int=a.hp
	s.attack(a.id); var first_damage: int=hp-int(a.hp)
	s.advance(.12); hp=int(a.hp); s.attack(a.id)
	check(hp-int(a.hp)>=first_damage and first_damage==6,"drill material and sustained ramp")
	check(s.cooldown()<.13,"drill high frequency")
	s.advance(.5); s.attack(a.id)
	check(s.drill_streak==0,"drill ramp requires genuinely continuous contact")
	s=Model.new(config); s.levels.scanner=1
	a=target(s,"red")
	s.attack(a.id,s.weak_point(a))
	check(a.hp==1,"weak point multiplier rounds to two damage")
	check(Economy.damage(config,s.tools.hammer,s.levels,"metal",false)>Economy.damage(config,s.tools.hammer,s.levels,"composite",false),"material tool matchup")
	s=Model.new(config); s.energy=100
	check(s.activate_frenzy() and s.energy==0 and s.frenzy_left==8,"player-triggered frenzy")
	check(not s.activate_frenzy() and s.cooldown()<.68 and s.feed_interval()<1,"frenzy cannot restart and boosts feed/frequency")
	for i in range(8):
		a=target(s,"paper",Vector2(500+i*50,420)); s.cooldown_left=0; s.attack(a.id)
	check(s.energy==0,"frenzy cannot recharge itself")
	s=Model.new(config); s.levels.magnet=1
	a=target(s,"red",Vector2(700,450))
	check(s.gather(Vector2(820,450))>0 and a.phase=="moving" and a.velocity.x>0,"magnet wakes and gathers sleeping junk")
	check(s.gather(Vector2(820,450))==0,"magnet cooldown")
	s=Model.new(config)
	check(s.start_event("rain") and s.feed_interval()==.5,"rain boosts supply without replacing existing pile")
	s.advance(1); var old_count:=s.field.pending_count()
	s.paused=true; var frozen:=s.snapshot(); s.advance(100)
	check(s.snapshot()==frozen and not s.attack() and not s.purchase("power"),"pause freezes events, field, economy and input")
	s.paused=false; s.advance(12)
	check(s.event_left==0 and s.field.pending_count()>old_count,"event ends but intact pile remains")
	s=Model.new(config); s.start_event("gold_day"); s.levels.power=4
	a=target(s,"red"); s.attack(a.id)
	check(s.coins==11,"gold day configured reward multiplier")
	s=Model.new(config); s.start_event("parcel")
	check(s.field.items.size()==1 and s.field.items[0].kind=="keyboard","wrong-dimensional parcel special drop")
	s=Model.new(config); s.coins=20000; s.earned=20000; s.crushed=150; s.manual_crushed=150
	check(s.purchase("depth") and s.purchase("depth"),"portal depth has two paid levels")
	check(s.purchase("quality"),"portal quality purchase")
	var kinds := {}
	s.rng.seed=88
	for i in range(10000): kinds[s.choose_trash()]=true
	check(kinds.size()==9,"all nine types reachable, no missing category")
	s.purchase("auto_stomper"); a=target(s,"red"); var before:=s.coins
	s.advance(20)
	check(s.auto_crushed==5 and s.coins-before==30 and a.hp==3,"auto lane still independent")
	check(s.purchase("auto_speed") and s.purchase("conveyor") and is_equal_approx(Economy.auto_interval(config,s.levels),1.8),"auto interval upgrades")
	s.owned.drill=true; s.equipped="drill"; s.energy=63; s.levels.scanner=1
	a=target(s,"washer"); a.hp=77
	var snapshot:=s.snapshot()
	var restored:=Model.new(config)
	check(restored.restore(snapshot) and restored.field.pending_count()==s.field.pending_count() and restored.field.by_id[a.id].hp==77,"v3 field and damage restore")
	check(restored.equipped=="drill" and restored.energy==63 and restored.levels.depth==2,"v3 tool, portal and energy restore")
	var bad:=snapshot.duplicate(true); bad.owned.drill=false
	var unchanged:=restored.snapshot()
	check(not restored.restore(bad) and restored.snapshot()==unchanged,"bad equipped ownership rejects atomically")
	bad=snapshot.duplicate(true); bad.field.items[0].shape_scale=NAN
	check(not restored.restore(bad),"bad hitbox scale rejects")
	var path:="res://tests/.yard_test_save.json"
	check(Save.write(s,path)==OK,"atomic v3 write")
	var loaded:=Model.new(config)
	check(Save.load_into(loaded,path,"res://tests/not-a-save.json").is_empty() and loaded.field.by_id[a.id].hp==77,"v3 disk roundtrip")
	DirAccess.remove_absolute(path)
	var old:=OldModel.new(OldData.load_config())
	old.coins=1234; old.earned=2000; old.crushed=72; old.manual_crushed=72
	old.levels.power=2; old.levels.feed_speed=1; old.unlocks.blue_can=true; old.unlocks.gold_can=true; old.unlocks.auto_stomper=true
	old.advance(8); old.field.items[0].hp=2
	var legacy_snapshot:=old.snapshot()
	var migrated:=Model.new(config)
	check(migrated.import_legacy(legacy_snapshot) and migrated.coins==old.coins and migrated.field.pending_count()==old.field.pending_count(),"v2 import preserves money and entire pile")
	check(migrated.field.items[0].hp==2 and migrated.levels.power==2 and migrated.levels.depth==1 and migrated.levels.quality==1,"v2 damage and progression mapping")
	check(old.snapshot()==legacy_snapshot,"import never mutates legacy state")
	var legacy_path:=path+".legacy"
	var legacy_file:=FileAccess.open(legacy_path,FileAccess.WRITE)
	var original_bytes:=JSON.stringify(legacy_snapshot,"\t",true,true)
	legacy_file.store_string(original_bytes); legacy_file.close()
	var disk_import:=Model.new(config)
	check(Save.load_into(disk_import,path,legacy_path)=="旧工坊已接续" and disk_import.coins==old.coins,"automatic first-run import reads real v2 file")
	check(Save.write(disk_import,path)==OK and FileAccess.get_file_as_string(legacy_path)==original_bytes,"new v3 write leaves old file byte-for-byte intact")
	var corrupt:=FileAccess.open(path,FileAccess.WRITE)
	corrupt.store_string("broken{"); corrupt.close()
	var recover:=Model.new(config)
	check(not Save.load_into(recover,path,legacy_path).is_empty() and recover.coins==0,"corrupt new save recovers without silently importing twice")
	check(FileAccess.get_file_as_string(path+".corrupt-backup")=="broken{" and FileAccess.get_file_as_string(path)=="broken{","corrupt source and backup are both preserved")
	for file_path in [path,legacy_path,path+".corrupt-backup"]: DirAccess.remove_absolute(file_path)
	legacy_snapshot.version=1; legacy_snapshot.erase("field")
	check(Model.new(config).import_legacy(legacy_snapshot),"v1 economy import")
	s=Model.new(config); s.owned.hammer=true; s.equipped="hammer"
	s.owned.drill=true; s.levels.depth=2
	a=target(s,"washer"); a.hp=1
	var wins:=[0]; s.milestone.connect(func(id):
		if id=="chapter_done": wins[0]+=1)
	s.attack(a.id); s.cooldown_left=0; s.attack(a.id)
	check(s.completed and wins[0]==1 and s.chapter()==2,"chapter ending once, can continue")
	var invalid:=config.duplicate(true); invalid.tools[0].cooldown=0
	check(not Data.validate(invalid).is_empty(),"bad new runtime data fails clearly")
	invalid=config.duplicate(true); invalid.tools[3].erase("chain_window_seconds")
	check(not Data.validate(invalid).is_empty(),"missing tool-specific parameter fails validation")
	print("YARD_TESTS: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
