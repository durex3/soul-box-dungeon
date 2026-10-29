extends GdTest


## 同一种子创建的四个子流分别复现前 1000 个数。
func test_same_seed_sequences() -> void:
	var a: RunRng = RunRng.new(12345)
	var b: RunRng = RunRng.new(12345)
	eq(a.run_seed, 12345)
	for pair: Array in [[a.spawn, b.spawn], [a.shop, b.shop], [a.loot, b.loot], [a.upgrade, b.upgrade]]:
		for i: int in 1000:
			eq(pair[0].randi(), pair[1].randi(), "draw %d" % i)


## 商店多取 100 个数，不改变刷怪、掉落和升级的前 1000 个数。
func test_shop_does_not_affect_other_streams() -> void:
	var a: RunRng = RunRng.new(12345)
	var b: RunRng = RunRng.new(12345)
	for i: int in 100:
		a.shop.randi()
	for pair: Array in [[a.spawn, b.spawn], [a.loot, b.loot], [a.upgrade, b.upgrade]]:
		for i: int in 1000:
			eq(pair[0].randi(), pair[1].randi(), "draw %d" % i)


## 参考值固定算法及各成员使用的派生种子。
func test_derived_seed_vectors() -> void:
	var expected: Dictionary = {
		&"spawn": 7640713538129709433, &"shop": 5310988902323854553,
		&"loot": -244990251510703615, &"upgrade": 49347111058617004,
	}
	var rng: RunRng = RunRng.new(12345)
	for name: StringName in expected:
		eq(RunRng.derive_seed(12345, name), expected[name], str(name))
		eq(rng.get(name).seed, expected[name], "member " + str(name))


## 四个子流的种子与前 10 个数两两不同。
func test_streams_are_distinct() -> void:
	var rng: RunRng = RunRng.new(12345)
	var streams: Array[RandomNumberGenerator] = [rng.spawn, rng.shop, rng.loot, rng.upgrade]
	var sequences: Array[Array] = []
	for stream: RandomNumberGenerator in streams:
		var sequence: Array[int] = []
		for i: int in 10:
			sequence.append(stream.randi())
		sequences.append(sequence)
	for i: int in streams.size():
		for j: int in range(i + 1, streams.size()):
			ok(streams[i].seed != streams[j].seed)
			ok(sequences[i] != sequences[j])


## 不同单局种子的刷怪序列不同。
func test_different_run_seeds() -> void:
	var a: RunRng = RunRng.new(1)
	var b: RunRng = RunRng.new(2)
	var differs: bool = false
	for i: int in 10:
		if a.spawn.randi() != b.spawn.randi():
			differs = true
	ok(differs)


## 零、负数及有符号 64 位边界均可稳定复现。
func test_boundary_seeds() -> void:
	for seed_value: int in [0, -1, 9223372036854775807, -9223372036854775808]:
		var a: RunRng = RunRng.new(seed_value)
		var b: RunRng = RunRng.new(seed_value)
		eq(a.run_seed, seed_value)
		for pair: Array in [[a.spawn, b.spawn], [a.shop, b.shop], [a.loot, b.loot], [a.upgrade, b.upgrade]]:
			for i: int in 1000:
				eq(pair[0].randi(), pair[1].randi(), "seed %d draw %d" % [seed_value, i])


## 引擎随机算法变化时拦下旧回放失效的风险。
func test_engine_rng_baseline() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	for expected: int in [492690617, 1919685028, 3561993920]:
		eq(rng.randi(), expected)


## 使用独立 Python 无符号参考实现核对边界与 UTF-8 字节派生。
func test_additional_reference_vectors() -> void:
	eq(RunRng.derive_seed(0, &"spawn"), -7301329619379992392)
	eq(RunRng.derive_seed(-1, &"shop"), -4368384393166126903)
	eq(RunRng.derive_seed(9223372036854775807, &"loot"), -3479338169743832053)
	eq(RunRng.derive_seed(-9223372036854775808, &"upgrade"), -8412827075152044476)
	eq(RunRng.derive_seed(12345, &"掉落"), -8496249326467868256)
	eq(RunRng.derive_seed(12345, &""), 6239939107816789547)
