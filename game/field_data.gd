extends RefCounted

# 단일 PNG의 색상으로 추측하지 않고 명시된 좌표와 기존 충돌 맵을 사용합니다.
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://game/field_data.json"))
	return _data

static func npcs(area: String) -> Array:
	return data().areas.get(area, []).duplicate(true)

static func grass_config(area: String) -> Dictionary:
	return data().grass.get(area, {})

static func is_grass(area: String, point: Vector2) -> bool:
	for zone in grass_config(area).get("zones", []):
		if point.x >= zone[0] and point.x <= zone[2] and point.y >= zone[1] and point.y <= zone[3]:
			return true
	return false
