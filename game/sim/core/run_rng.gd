class_name RunRng
extends RefCounted

# RK-005 固定算法常量，修改会破坏已有种子的回放兼容性。
const FNV_OFFSET: int = -3750763034362895579  # 0xCBF29CE484222325
const FNV_PRIME: int = 1099511628211  # 0x100000001B3
const MIX_ADD: int = -7046029254386353131  # 0x9E3779B97F4A7C15
const MIX_MUL_1: int = -4658895280553007687  # 0xBF58476D1CE4E5B9
const MIX_MUL_2: int = -7723592293110705685  # 0x94D049BB133111EB

# 只读约定：构造后不改种子，也不替换子流。
var run_seed: int
var spawn: RandomNumberGenerator
var shop: RandomNumberGenerator
var loot: RandomNumberGenerator
var upgrade: RandomNumberGenerator


func _init(seed_value: int) -> void:
	run_seed = seed_value
	spawn = RandomNumberGenerator.new()
	spawn.seed = derive_seed(seed_value, &"spawn")
	shop = RandomNumberGenerator.new()
	shop.seed = derive_seed(seed_value, &"shop")
	loot = RandomNumberGenerator.new()
	loot.seed = derive_seed(seed_value, &"loot")
	upgrade = RandomNumberGenerator.new()
	upgrade.seed = derive_seed(seed_value, &"upgrade")


## 从单局种子和流名 UTF-8 字节稳定派生一个有符号 64 位种子。
static func derive_seed(seed_value: int, stream_name: StringName) -> int:
	var x: int = FNV_OFFSET
	for byte: int in str(stream_name).to_utf8_buffer():
		x = (x ^ byte) * FNV_PRIME
	x ^= seed_value
	x += MIX_ADD
	x = (x ^ _logical_shift_right(x, 30)) * MIX_MUL_1
	x = (x ^ _logical_shift_right(x, 27)) * MIX_MUL_2
	return x ^ _logical_shift_right(x, 31)


static func _logical_shift_right(value: int, bits: int) -> int:
	# GDScript 的 >> 保留符号位，掩码移除补入的高位 1。
	return (value >> bits) & ((1 << (64 - bits)) - 1)
