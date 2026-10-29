extends SceneTree

const MIX_ADD: int = -7046029254386353131  # 0x9E3779B97F4A7C15
const MIX_MUL1: int = -4658895280553007687  # 0xBF58476D1CE4E5B9
const MIX_MUL2: int = -7723592293110705685  # 0x94D049BB133111EB
const FNV_OFFSET: int = -3750763034362895579  # 0xCBF29CE484222325
const FNV_PRIME: int = 1099511628211  # 0x100000001B3


static func _shr(x: int, n: int) -> int:
	return (x >> n) & ((1 << (64 - n)) - 1)


static func mix(x: int) -> int:
	x = x + MIX_ADD
	x = (x ^ _shr(x, 30)) * MIX_MUL1
	x = (x ^ _shr(x, 27)) * MIX_MUL2
	return x ^ _shr(x, 31)


static func fnv(name: StringName) -> int:
	var h: int = FNV_OFFSET
	for b: int in String(name).to_utf8_buffer():
		h = (h ^ b) * FNV_PRIME
	return h


func _init() -> void:
	var big: int = 9223372036854775807
	var neg: int = -1
	print("OVF ", big + 1, " ", neg >> 1, " ", _shr(neg, 1))
	for s: int in [0, 1, 12345, -1, 9223372036854775807]:
		for n: StringName in [&"spawn", &"shop", &"loot", &"upgrade"]:
			print("DS %d %s %d" % [s, n, mix(s ^ fnv(n))])
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = 42
	var a: Array[int] = []
	for i: int in 3:
		a.append(r.randi())
	r.seed = 42
	print("RESEED_SAME ", r.randi() == a[0], " seed_read=", r.seed, " first=", a)
	quit(0)
