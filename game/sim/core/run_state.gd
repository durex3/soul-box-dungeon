class_name RunState
extends RefCounted

# 外部只读；每局独立创建。
var player: PlayerState = PlayerState.new()
var enemies: Array[EnemyState] = []
