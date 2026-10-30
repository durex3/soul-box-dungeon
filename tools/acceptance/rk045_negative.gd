extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var kind: String = OS.get_cmdline_user_args()[0]
	var pool: NodePool = NodePool.new()
	pool.configure(load("res://view/battle/enemy_projectile_view.tscn"), 1)
	root.add_child(pool)
	var item: EnemyProjectileView = pool.get_child(0) as EnemyProjectileView
	if kind != "inactive":
		item = pool.acquire() as EnemyProjectileView
		item.present(77, Vector2(17.3, 25.8), 12)
	var before: Array = [item.entity_id, item.position, item.world_position, item.diameter_px, item.visible, item.active]
	item.present(99, Vector2(100, 100), 9 if kind == "inactive" else int(kind))
	var after: Array = [item.entity_id, item.position, item.world_position, item.diameter_px, item.visible, item.active]
	if before != after:
		print("RK045_NEGATIVE: failed")
		quit(1)
		return
	pool.queue_free()
	await process_frame
	print("RK045_NEGATIVE: passed")
	quit()
