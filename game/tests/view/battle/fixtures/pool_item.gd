extends PooledView

var payload: int = 0
var acquire_count: int = 0
var release_count: int = 0
var ready_count: int = 0
var idle_count: int = 0
var physics_count: int = 0


func _ready() -> void:
	ready_count += 1


func _process(_delta: float) -> void:
	idle_count += 1


func _physics_process(_delta: float) -> void:
	physics_count += 1


func _on_pool_acquire() -> void:
	acquire_count += 1


func _on_pool_release() -> void:
	payload = 0
	release_count += 1
