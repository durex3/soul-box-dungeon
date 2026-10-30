extends Node2D

var idle_count: int = 0
var physics_count: int = 0


func _process(_delta: float) -> void:
	idle_count += 1


func _physics_process(_delta: float) -> void:
	physics_count += 1
