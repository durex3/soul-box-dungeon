class_name ReviewCatalog
extends RefCounted
## 只读生产元数据目录；损坏条目仍可选，错误由验收台展示。

const ROOTS: PackedStringArray = ["res://assets/sprites/greybox/rk073/", "res://assets/sprites/greybox/rk074/"]
var entries: Array[Dictionary] = []

## 扫描正式 JSON，不依赖 art 源文件或导出清单。
func scan() -> void:
	entries.clear()
	var numbers: Dictionary = {}
	for folder: String in ROOTS:
		var files: PackedStringArray = DirAccess.get_files_at(folder)
		files.sort()
		for file: String in files:
			if not file.ends_with(".json"):
				continue
			var path: String = folder + file
			var parser: JSON = JSON.new()
			var code: Error = parser.parse(FileAccess.get_file_as_string(path))
			var data: Dictionary = parser.data if code == OK and parser.data is Dictionary else {}
			var meta: Dictionary = data.get("meta", {}) if data.get("meta", {}) is Dictionary else {}
			var category: String = str(meta.get("category", "player" if file.begins_with("chr_") else "enemy"))
			if category == "enemy" and meta.get("elite", false) == true:
				category = "elite"
			var key: String = category + "/" + str(meta.get("id", file.get_basename()))
			if not numbers.has(key):
				numbers[key] = numbers.size() + 1
			entries.append({"path": path, "id": str(meta.get("id", file.get_basename())),
				"category": category, "action": str(meta.get("action", "单帧")),
				"tier": int(meta.get("tier", 0)) if _number(meta.get("tier", 0)) else 0, "number": numbers[key]})

## 每次选择重新读取，返回完整验证结果；失败时不提供纹理或可播放帧。
func read_entry(entry: Dictionary) -> Dictionary:
	var path: String = entry["path"]
	var parser: JSON = JSON.new()
	var code: Error = parser.parse(FileAccess.get_file_as_string(path))
	if code != OK:
		return _bad(path, "JSON 第%d行：%s" % [parser.get_error_line(), parser.get_error_message()])
	if not parser.data is Dictionary:
		return _bad(path, "根节点必须是对象")
	var data: Dictionary = parser.data
	if not data.get("meta") is Dictionary or not data.get("frames") is Array:
		return _bad(path, "缺少 meta 对象或 frames 数组")
	var meta: Dictionary = data["meta"]
	if not meta.get("image") is String or not meta.get("id") is String:
		return _bad(path, "缺少 meta.image / meta.id 字符串")
	if (path.contains("/rk073/") and not meta.get("action") is String) or (path.contains("/rk074/") and not meta.get("category") is String):
		return _bad(path, "缺少 meta.action / meta.category 分类字段")
	if str(meta["id"]).is_empty():
		return _bad(path, "meta.id 不能为空")
	if meta.get("category", "") == "soul" and (not _number(meta.get("tier")) or not float(meta["tier"]) in [1.0, 2.0, 3.0, 4.0]):
		return _bad(path, "魂匣缺少有效 meta.tier（1—4）")
	var image_name: String = meta["image"]
	if image_name.get_file() != image_name or not image_name.ends_with(".png"):
		return _bad(path, "meta.image 必须是同目录 PNG 文件名")
	var image_path: String = path.get_base_dir().path_join(image_name)
	if not FileAccess.file_exists(image_path):
		return _bad(path, "缺图：" + image_path)
	var image: Image = Image.new()
	if image.load_png_from_buffer(FileAccess.get_file_as_bytes(image_path)) != OK or image.is_empty():
		return _bad(path, "PNG 无法解码：" + image_path)
	if not _numbers(meta.get("size"), ["w", "h"]) or Vector2(meta["size"]["w"], meta["size"]["h"]) != Vector2(image.get_size()):
		return _bad(path, "meta.size 缺失或与 PNG 尺寸不符")
	var frames: Array = data["frames"]
	if frames.is_empty():
		return _bad(path, "frames 不能为空")
	var result: Array[Dictionary] = []
	for i: int in frames.size():
		if not frames[i] is Dictionary:
			return _bad(path, "frames[%d] 必须是对象" % i)
		var frame: Dictionary = frames[i]
		if not _numbers(frame.get("frame"), ["x", "y", "w", "h"]) or not _numbers(frame.get("pivot"), ["x", "y"]):
			return _bad(path, "frames[%d] 缺少 frame 矩形或 pivot 数值" % i)
		var rect: Rect2 = _rect(frame["frame"])
		if not _valid_rect(rect, Rect2(Vector2.ZERO, Vector2(image.get_size()))):
			return _bad(path, "frames[%d].frame 越界或非整数矩形：%s，PNG=%s" % [i, rect, image.get_size()])
		if not _numbers(frame.get("sourceSize"), ["w", "h"]) or Vector2(frame["sourceSize"]["w"], frame["sourceSize"]["h"]) != rect.size:
			return _bad(path, "frames[%d].sourceSize 缺少或不匹配（只支持未裁切帧）" % i)
		if frame.get("rotated", false) != false or frame.get("trimmed", false) != false:
			return _bad(path, "frames[%d] 不支持 rotated/trimmed 帧" % i)
		if not _number(frame.get("duration")) or float(frame["duration"]) < 1.0 or float(frame["duration"]) != floorf(float(frame["duration"])):
			return _bad(path, "frames[%d].duration 必须是正整数毫秒" % i)
		var pivot: Vector2 = Vector2(frame["pivot"]["x"], frame["pivot"]["y"])
		if pivot.x < 0 or pivot.y < 0 or pivot.x > rect.size.x or pivot.y > rect.size.y:
			return _bad(path, "frames[%d].pivot 超出画布" % i)
		var parsed: Dictionary = {"rect": rect, "pivot": pivot, "duration": float(frame["duration"]), "exclude_shadow": path.contains("/rk073/")}
		if frame.has("body_rect"):
			if not _numbers(frame["body_rect"], ["x", "y", "w", "h"]) or not _valid_rect(_rect(frame["body_rect"]), Rect2(Vector2.ZERO, rect.size)):
				return _bad(path, "frames[%d].body_rect 缺失字段或越界" % i)
			parsed["body_rect"] = _rect(frame["body_rect"])
		result.append(parsed)
	return {"error": "", "frames": result, "texture": ImageTexture.create_from_image(image), "image_path": image_path}

func _bad(path: String, reason: String) -> Dictionary:
	return {"error": path + "\n" + reason, "frames": []}

func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

func _numbers(value: Variant, fields: Array) -> bool:
	if not value is Dictionary:
		return false
	for field: String in fields:
		if not _number(value.get(field)):
			return false
	return true

func _rect(value: Dictionary) -> Rect2:
	return Rect2(value["x"], value["y"], value["w"], value["h"])

func _valid_rect(rect: Rect2, bounds: Rect2) -> bool:
	return rect.size.x > 0 and rect.size.y > 0 and rect.position == rect.position.floor() and rect.size == rect.size.floor() and bounds.encloses(rect)
