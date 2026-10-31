extends SceneTree
## 真实限帧下正式固定步驱动同一600帧预生成输入，不拿墙钟秒数代替逻辑步数。

var sim: Sim
var driver: FixedStepDriver
var inputs: Array[InputFrame] = []
var index: int = 0
var shots: Array = []
var process_frames: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	sim = Sim.new(1717,&"knight")
	WeaponTestFixture.equip(sim,0,&"knight_sword")
	WeaponTestFixture.equip(sim,1,&"apprentice_fire_staff")
	for i: int in 600:
		var input: InputFrame = WeaponTestFixture.input(not (i>=300 and i<330),1 if i in [0,330] else 0,1 if i in [200,400] else 0)
		input.move_direction = Vector2(0.25,0) if i<300 else Vector2(0,0.25)
		input.aim_valid = true
		input.aim_world = Vector2(1000,500)
		inputs.append(input)
	driver = FixedStepDriver.new()
	driver.configure(_tick)
	root.add_child(driver)
	var start: int = Time.get_ticks_usec()
	while index<600:
		await process_frame
		process_frames += 1
	driver.set_paused(true)
	var elapsed: float = (Time.get_ticks_usec()-start)/1000000.0
	var record: Dictionary = {"fps_limit":args[1],"steps":index,"process_frames":process_frames,"elapsed_seconds":elapsed,"events":shots,"player":str(sim.state.player.position)}
	var file: FileAccess = FileAccess.open(args[0].path_join("rate_"+args[1]+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(record,"\t")+"\n")
	file.close()
	print("RK017 rate limit=",args[1]," logical_steps=",index," process_frames=",process_frames," elapsed=",elapsed," shot_frames=",shots)
	driver.queue_free()
	await process_frame
	print("RK017_RATE: passed")
	quit()

func _tick() -> void:
	if index>=inputs.size():
		return
	if index==300:
		WeaponTestFixture.speed(sim,1.0)
	for event: SimEvent in sim.step(inputs[index]):
		if event.kind==SimEvent.Kind.WEAPON_FIRED:
			shots.append([index+1,str(event.weapon_id),event.slot_index,event.base_damage,event.effective_shots_per_sec,str(event.origin),str(event.direction)])
	index += 1
