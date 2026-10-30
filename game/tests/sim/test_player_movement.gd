extends GdTest

## 构造状态、隔离性、零输入和输入不可变。
func test_initial_state_and_isolation() -> void:
	var a: Sim = Sim.new(1, &"knight")
	var b: Sim = Sim.new(1, &"alchemist")
	eq(a.state.player.position, Vector2(640, 360))
	eq(a.state.player.radius, 8.0)
	eq(b.state.player.character_id, &"alchemist")
	var input: InputFrame = InputFrame.new()
	for i: int in 60:
		eq(a.step(input), [])
	eq(a.state.player.position, Vector2(640, 360))
	input.move_direction = Vector2(3, 4)
	a.step(input)
	eq(input.move_direction, Vector2(3, 4))
	eq(b.state.player.position, Vector2(640, 360))

## 四轴基础/加成距离与数据约定一致。
func test_axis_distance_and_bonus() -> void:
	eq(PlayerConfig.BASE_MOVE_TILES_PER_SECOND, 4.0)
	eq(PlayerConfig.BODY_RADIUS, 8.0)
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		for bonus: float in [0.0, 0.5]:
			var sim: Sim = _walk(direction, bonus, 60)
			var displacement: Vector2 = sim.state.player.position - Vector2(640, 360)
			near(displacement.distance_to(direction * (64 if bonus == 0 else 96)), 0, 0.01)

## 斜向不加速，模拟半幅保留，超长限幅。
func test_diagonal_and_analog_magnitude() -> void:
	for direction: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(3, 4)]:
		near(_walk(direction, 0, 60).state.player.position.distance_to(Vector2(640, 360)), 64, 0.01)
	near(_walk(Vector2(0.5, 0), 0, 60).state.player.position.x - 640, 32, 0.01)
	eq(_walk(Vector2.ZERO, 0, 60).state.player.position, Vector2(640, 360))

## 仅通过构造器验证加成下限与上限。
func test_bonus_clamp() -> void:
	for bonus: float in [-1.0, 1.0, 2.0]:
		near(_walk(Vector2.RIGHT, bonus, 60).state.player.position.x - 640, 64 if bonus < 0 else 128, 0.01)

## 长期八方向走墙，圆始终合法且可立即向内离开。
func test_walls_corners_and_leave_wall() -> void:
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN,
			Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var sim: Sim = Sim.new(1, &"knight")
		var input: InputFrame = InputFrame.new()
		input.move_direction = direction
		for i: int in 2400:
			sim.step(input)
			var p: Vector2 = sim.state.player.position
			ok(p.x >= 40 and p.x <= 1240 and p.y >= 40 and p.y <= 680)
		var at_wall: Vector2 = sim.state.player.position
		if direction.x != 0:
			eq(at_wall.x, 40.0 if direction.x < 0 else 1240.0)
		if direction.y != 0:
			eq(at_wall.y, 40.0 if direction.y < 0 else 680.0)
		input.move_direction = -direction
		sim.step(input)
		ok(sim.state.player.position != at_wall)

## 相同输入序列可重复，保留非整数逻辑位置。
func test_deterministic_fractional_position() -> void:
	var a: Sim = Sim.new(20, &"knight")
	var b: Sim = Sim.new(20, &"knight")
	var input: InputFrame = InputFrame.new()
	for i: int in 123:
		input.move_direction = Vector2(0.3, -0.7) if i % 2 else Vector2(-0.2, 0.5)
		a.step(input)
		b.step(input)
	eq(a.state.player.position, b.state.player.position)
	ok(a.state.player.position != a.state.player.position.round())

func _walk(direction: Vector2, bonus: float, count: int) -> Sim:
	var sim: Sim = Sim.new(1, &"knight", bonus)
	var input: InputFrame = InputFrame.new()
	input.move_direction = direction
	for i: int in count:
		sim.step(input)
	return sim
