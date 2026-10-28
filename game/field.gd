class_name LegendField
extends Node2D

## 필드 전용 SD 대체 그림과 한옥 타일을 그립니다. 승인 일러스트는 UI에서 별도로 사용합니다.
const Placement = preload("res://game/field_data.gd")
const TILE: float = 32.0
const WORLD_SIZE := Vector2(960, 640)
const BUILDINGS: Dictionary = {
	"incheon": [
		{"x": 4.5, "y": 3.6, "w": 5.2, "h": 3.8, "label": "백서화 연구소", "type": "lab"},
		{"x": 3.3, "y": 14.2, "w": 4.3, "h": 3.6, "label": "", "type": "house"},
		{"x": 24.1, "y": 13.2, "w": 4.3, "h": 3.6, "label": "", "type": "house"}],
	"route": [],
	"suwon_gym": [],
	"suwon": [
		{"x": 7.0, "y": 5.7, "w": 6.2, "h": 3.1, "label": "포켓몬 센터", "type": "center"},
		{"x": 21.4, "y": 5.6, "w": 6.5, "h": 4.6, "label": "수원 체육관", "type": "gym"},
		{"x": 17.7, "y": 2.0, "w": 5.8, "h": 2.8, "label": "유물 전시관", "type": "museum"},
		{"x": 13.0, "y": 12.0, "w": 4.9, "h": 3.5, "label": "여행 상점", "type": "shop"}]
}
const ROUTE_TRAINERS: Array[Vector2] = [Vector2(8, 8), Vector2(11, 12), Vector2(15, 7), Vector2(18, 13), Vector2(22, 8)]
const TREE_INTERIOR: Dictionary = {
	"incheon": [[2.5, 5, 1], [10.8, 4.8, 1], [3, 10, 1], [10.3, 16.7, 1], [16.3, 5.5, 1], [22.5, 3, 0], [27, 4.1, 1], [26.7, 7.7, 0], [22.1, 15.8, 1], [16, 17.7, 0]],
	"route": [[3, 4.7, 0], [5.4, 6, 1], [2.7, 15.6, 0], [6, 17, 1], [10, 2.2, 0], [17, 2.9, 1], [23.4, 4, 0], [27.7, 6, 1], [25, 16.7, 0], [20, 18, 1], [13, 18.2, 0]],
	"suwon": [[2.7, 4.7, 1], [10.5, 5.5, 1], [25.5, 5.2, 1], [3, 14.8, 1], [6.5, 16.9, 0], [17.5, 16.8, 1], [25.7, 16, 1], [21, 12.9, 1]],
	"suwon_gym": []
}

var state: Dictionary = {}
var debug_positions := false
var encounter_shake := 0.0
var moving: bool = false
var reduced_motion: bool = false
var field_font: Font
var _tree_cache: Dictionary = {}
var _time: float = 0.0
static var _collision_trees: Dictionary = {}
var _paint_target: Node2D
var _layers: Dictionary = {}
var _map_key: String = ""
var tile_map_layer: TileMapLayer
var atlas_source: TileSetAtlasSource
var actor_sheets: Dictionary = {}
var cinematic_mode: String = ""
var map_backdrop: Sprite2D
var map_textures: Dictionary = {}

class PaintLayer extends Node2D:
	var paint: Callable

	func _draw() -> void:
		if paint.is_valid():
			paint.call(self)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists("res://assets/fonts/NotoSansKR.otf"):
		field_font = load("res://assets/fonts/NotoSansKR.otf") as Font
	for id in ["player", "harin", "seohwa"]:
		var sprite_path := "res://assets/generated/%s_walk_48.png" % id
		if ResourceLoader.exists(sprite_path): actor_sheets[id] = load(sprite_path) as Texture2D
	for id in ["seol_yuna", "yun_seorin", "moon_si_yeon", "hae_nari", "erika", "reina", "kaien", "shiori", "se_arin", "ren_kaito", "karen_yuzuhwa", "shin_tsukasa"]:
		var sprite_path := "res://assets/generated/field_characters/%s_walk_48.png" % id
		if ResourceLoader.exists(sprite_path): actor_sheets[id] = load(sprite_path) as Texture2D
	_build_tilemap()
	_build_map_backdrop()


func _build_tilemap() -> void:
	if not ResourceLoader.exists("res://assets/generated/incheon_tileset_32.png"): return
	var texture := load("res://assets/generated/incheon_tileset_32.png") as Texture2D
	if texture == null: return
	atlas_source = TileSetAtlasSource.new()
	atlas_source.texture = texture
	atlas_source.texture_region_size = Vector2i(32, 32)
	for row in range(16):
		for col in range(16): atlas_source.create_tile(Vector2i(col, row))
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(32, 32)
	tileset.add_source(atlas_source, 0)
	tile_map_layer = TileMapLayer.new()
	tile_map_layer.name = "IncheonTileMap"
	tile_map_layer.tile_set = tileset
	tile_map_layer.z_index = -1100
	tile_map_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(tile_map_layer)


func _build_map_backdrop() -> void:
	map_backdrop = Sprite2D.new()
	map_backdrop.name = "DSStylePixelMap"
	map_backdrop.centered = false
	map_backdrop.position = Vector2.ZERO
	map_backdrop.z_index = -1300
	map_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_backdrop.visible = false
	add_child(map_backdrop)


func _set_map_backdrop(area: String) -> bool:
	if map_backdrop == null:
		return false
	var file: String = str({
		"incheon":"incheon_bw_field_960.png", "route":"route_bw_field_960.png",
		"suwon":"suwon_bw_field_960.png", "suwon_gym":"suwon_gym_bw_field_960.png"
	}.get(area, ""))
	if file.is_empty():
		map_backdrop.visible = false
		return false
	var path := "res://assets/generated/maps/%s" % file
	if not ResourceLoader.exists(path):
		map_backdrop.visible = false
		return false
	if not map_textures.has(path):
		map_textures[path] = load(path) as Texture2D
	map_backdrop.texture = map_textures[path] as Texture2D
	map_backdrop.visible = true
	return true


func _set_tile(cell: Vector2i, atlas: Vector2i) -> void:
	if tile_map_layer != null: tile_map_layer.set_cell(cell, 0, atlas)


func _populate_tilemap(area: String) -> void:
	if tile_map_layer == null: return
	tile_map_layer.clear()
	var use_pixel_backdrop := _set_map_backdrop(area)
	tile_map_layer.visible = area in ["incheon", "suwon_gym"] and not use_pixel_backdrop
	if area == "incheon":
		for y in range(20):
			for x in range(30): _set_tile(Vector2i(x,y), Vector2i(0 if _noise(x,y) < 0.74 else 1, 0))
		for x in range(30):
			for y in [9,10]: _set_tile(Vector2i(x,y), Vector2i(0 if x % 3 else 1, 1))
		for y in range(2,18):
			for x in [12,13]: _set_tile(Vector2i(x,y), Vector2i(2 if y % 4 == 0 else 0, 1))
		for y in range(7,11):
			for x in range(6,9): _set_tile(Vector2i(x,y), Vector2i(0,1))
		for y in range(5,11):
			for x in range(22,25): _set_tile(Vector2i(x,y), Vector2i(1,1))
		for y in range(20):
			if y == 9 or y == 10: continue
			for x in [18,19,20]: _set_tile(Vector2i(x,y), Vector2i((x+y)%5,3))
		for y in [9,10]:
			for x in [18,19,20]: _set_tile(Vector2i(x,y), Vector2i(x%4,6))
	elif area == "suwon_gym":
		for y in range(20):
			for x in range(30): _set_tile(Vector2i(x,y), Vector2i((x+y)%3,1))
		for x in range(30):
			_set_tile(Vector2i(x,0),Vector2i(x%4,2))
			_set_tile(Vector2i(x,19),Vector2i(x%4,2))
		for y in range(1,19):
			_set_tile(Vector2i(0,y),Vector2i(0,2))
			_set_tile(Vector2i(29,y),Vector2i(1,2))
		for y in range(5,18): _set_tile(Vector2i(14,y),Vector2i(y%3,1))
		for x in range(12,17): _set_tile(Vector2i(x,4),Vector2i(x%4,2))
		_set_tile(Vector2i(14,18),Vector2i(2,6))


static func area_info(area: String) -> Dictionary:
	match area:
		"route": return {"name": "1번도로", "subtitle": "인천 → 수원 · 바람이 머무는 숲길"}
		"suwon": return {"name": "수원 · 성곽 마을", "subtitle": "첫 번째 배지를 향하여"}
		"suwon_gym": return {"name": "수원 체육관 · 성문 안뜰", "subtitle": "문양을 밝히고 관장에게 도전하세요"}
		_: return {"name": "인천 · 벚꽃 마을", "subtitle": "모든 인연이 시작되는 곳"}


static func _noise(a: float, b: float = 0.0) -> float:
	return fposmod(sin(a * 127.1 + b * 311.7) * 43758.5453, 1.0)


static func _trees(area: String) -> Array[Dictionary]:
	if area == "suwon_gym": return []
	if _collision_trees.has(area):
		return _collision_trees[area]
	var result: Array[Dictionary] = []
	for i in range(16):
		var x: float = 0.1 + i * 1.95
		if area != "suwon" or x < 4 or x > 25:
			result.append({"x": x, "y": 0.7 + _noise(i, 1) * 0.9, "pink": i % 3 != 0, "scale": 0.9 + _noise(i) * 0.25})
		result.append({"x": x, "y": 19.8 + _noise(i, 5) * 0.4, "pink": i % 4 != 0, "scale": 1 + _noise(i, 3) * 0.2})
	for i in range(7):
		var y: float = 2.5 + i * 2.3
		if absf(y - 10.0) > 1.8:
			result.append({"x": -0.2, "y": y, "pink": i % 2 == 0, "scale": 1.2})
			result.append({"x": 29.8, "y": y, "pink": i % 3 != 0, "scale": 1.15})
	for point in TREE_INTERIOR.get(area, []):
		result.append({"x": point[0], "y": point[1], "pink": point[2] == 1, "scale": 1.0})
	_collision_trees[area] = result
	return result


static func can_walk(area: String, x: float, y: float, gym_open: bool = false) -> bool:
	if not BUILDINGS.has(area) or not is_finite(x) or not is_finite(y):
		return false
	if area == "suwon_gym":
		if x < 0.65 or x > 28.45 or y < 1.2 or y > 18.45:
			return false
		if not gym_open and y < 5.15 and x > 10.8 and x < 18.5:
			return false
		return true
	if x < 0.65 or x > 28.45 or y < 1.9 or y > 18.45:
		return false
	for building in BUILDINGS[area]:
		if x > building.x - 0.12 and x < building.x + building.w + 0.12 and y > building.y - 0.12 and y < building.y + building.h + 0.12:
			return false
	for tree in _trees(area):
		if Vector2(x, y).distance_to(Vector2(tree.x, tree.y)) < 0.32 * tree.scale:
			return false
	if area == "incheon" and x > 18 and x < 20.6 and (y < 9 or y > 11.2): return false
	if area == "route" and x > 24.7 and x < 26.4 and (y < 9 or y > 11.2): return false
	if area == "suwon" and Vector2(x - 14.3, (y - 10.2) * 1.3).length() < 1.15: return false
	return true

static func is_grass(area: String, x: float, y: float) -> bool:
	return Placement.is_grass(area, Vector2(x, y))


static func interactions(game: Dictionary) -> Array[Dictionary]:
	var area: String = game.get("area", "incheon")
	var list: Array[Dictionary] = []
	if area == "incheon":
		list.assign([
			{"id": "lab", "label": "백서화 연구소", "x": 7.0, "y": 8.0, "kind": "building"},
			{"id": "harin", "label": "서하린", "x": 20.0, "y": 12.0, "kind": "person"},
			{"id": "gate", "label": "1번도로", "x": 28.0, "y": 10.0, "kind": "exit"}])
		if game.get("stage", "prologue") == "prologue":
			list.append({"id": "ralts", "label": "작은 울음소리", "x": 23.0, "y": 5.0, "kind": "quest"})
	elif area == "route":
		list.assign([
			{"id": "gateBack", "label": "인천으로", "x": 1.0, "y": 10.0, "kind": "exit"},
			{"id": "gate", "label": "수원 성곽 마을", "x": 28.0, "y": 10.0, "kind": "exit"},
			{"id": "healer", "label": "길 위의 쉼터", "x": 4.0, "y": 10.0, "kind": "person"}])
		for i in range(ROUTE_TRAINERS.size()):
			list.append({"id": "trainer%d" % i, "label": "도로 트레이너 %d" % (i + 1), "x": ROUTE_TRAINERS[i].x, "y": ROUTE_TRAINERS[i].y, "kind": "trainer"})
		if not game.get("flags", {}).get("routeItem", false):
			list.append({"id": "item", "label": "샛길의 여행 물품", "x": 21.0, "y": 16.0, "kind": "item"})
	elif area == "suwon_gym":
		list.assign([
			{"id":"gym_exit", "label":"수원 마을로", "x":14.0, "y":18.0, "kind":"exit"},
			{"id":"gym_guide", "label":"성곽 안내석", "x":4.0, "y":15.0, "kind":"person"},
			{"id":"gym_plate_sun", "label":"해 문양", "x":9.0, "y":10.0, "kind":"puzzle"},
			{"id":"gym_plate_mountain", "label":"산 문양", "x":15.0, "y":10.0, "kind":"puzzle"},
			{"id":"gym_plate_water", "label":"물 문양", "x":21.0, "y":10.0, "kind":"puzzle"},
			{"id":"gym_leader", "label":"관장 이도윤", "x":14.0, "y":3.0, "kind":"person"}])
		var gym_points: Array[Vector2] = [Vector2(6,6), Vector2(24,6), Vector2(24,12)]
		var gym_names := ["훈련생 민준", "안내원 지아", "순찰자 도윤"]
		for i in range(3): list.append({"id":"gym_trainer%d" % i, "label":gym_names[i], "x":gym_points[i].x, "y":gym_points[i].y, "kind":"trainer"})
	else:
		list.assign([
			{"id": "gateBack", "label": "1번도로 방면", "x": 1.0, "y": 10.0, "kind": "exit"},
			{"id": "gym", "label": "수원 체육관", "x": 24.5, "y": 11.1, "kind": "building"},
			{"id": "center", "label": "포켓몬 센터", "x": 10.1, "y": 9.1, "kind": "building"},
			{"id": "shop", "label": "여행 상점", "x": 15.5, "y": 15.8, "kind": "building"},
			{"id": "museum", "label": "유물 전시관", "x": 20.6, "y": 5.4, "kind": "building"}])
	for item in list:
		for placement in Placement.npcs(area):
			if item.id == placement.id:
				item.merge(placement, true)
	return list


func _color(value: String) -> Color:
	return Color(value)


func _box(x: float, y: float, w: float, h: float, color: String) -> void:
	_paint_target.draw_rect(Rect2(x, y, w, h), _color(color))


func _oval(x: float, y: float, rx: float, ry: float, color: String, detail: int = 24) -> void:
	var points := PackedVector2Array()
	for i in range(detail):
		var a: float = i * TAU / detail
		points.append(Vector2(x + cos(a) * rx, y + sin(a) * ry))
	_paint_target.draw_colored_polygon(points, _color(color))


func _poly(points: Array, color: String) -> void:
	var polygon := PackedVector2Array()
	for point in points:
		polygon.append(Vector2(point[0], point[1]))
	_paint_target.draw_colored_polygon(polygon, _color(color))


func _line(points: Array, color: String, width: float = 1.0) -> void:
	var line := PackedVector2Array()
	for point in points:
		line.append(Vector2(point[0], point[1]))
	_paint_target.draw_polyline(line, _color(color), width, false)


func _label(text: String, x: float, y: float, font_size: int = 12, color: String = "fff1d2") -> void:
	var font: Font = field_font if field_font else ThemeDB.fallback_font
	var size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	_paint_target.draw_string(font, Vector2(roundf(x - size.x / 2), roundf(y + size.y * 0.26)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _color(color))


func _flower(x: float, y: float, color: String, radius: float = 2.0) -> void:
	for i in range(5):
		var angle: float = i * TAU / 5
		_oval(x + cos(angle) * radius, y + sin(angle) * radius, radius, radius * 0.8, color, 8)
	_oval(x, y, radius * 0.6, radius * 0.6, "f9dc95", 8)


func _path(tx: float, ty: float, tw: float, th: float, stone: bool = true) -> void:
	var x: float = tx * TILE
	var y: float = ty * TILE
	var width: float = tw * TILE
	var height: float = th * TILE
	_box(x - 4, y - 4, width + 8, height + 8, "71866a")
	_box(x, y, width, height, "cfc5a8" if stone else "c4b78d")
	for row in range(int(height / 20)):
		for col in range(int(width / 28)):
			var xx: float = x + col * 28
			var yy: float = y + row * 20
			if stone:
				var colors: Array[String] = ["ddd3b9", "cec5ac", "e4d8bc", "d7ccaf"]
				_box(xx + 1, yy + 1, 26, 18, colors[int(_noise(xx, yy) * 4)])
				_line([[xx + 3, yy + 3], [xx + 24, yy + 3]], "f1e7ce88")
			elif _noise(xx, yy) > 0.5:
				_oval(xx + 12, yy + 6, 2, 1, "9a8e6b")


func _grass(x: int, y: int) -> void:
	var px: float = x * TILE
	var py: float = y * TILE
	_box(px, py, TILE + 1, TILE + 1, "64985c")
	for i in range(7):
		var gx: float = px + 3 + _noise(x * 7 + i, y) * 26
		var gy: float = py + 8 + _noise(x, y * 7 + i) * 24
		var h: float = 6 + _noise(i + y, x) * 7
		_line([[gx - 4, gy - h + 3], [gx, gy], [gx + 4, gy - h]], "3d774e", 2)
		_line([[gx, gy], [gx - 1, gy - h]], "a2c87c", 1)


func _ground(area: String) -> void:
	_box(0, 0, WORLD_SIZE.x, WORLD_SIZE.y, "83aa78")
	for i in range(800):
		var x: float = _noise(i, 3) * WORLD_SIZE.x
		var y: float = _noise(i, 9) * WORLD_SIZE.y
		_oval(x, y, 1 + _noise(i, 1) * 2, 1, "a9c18a66" if i % 3 else "3c775844", 6)
	if area == "route":
		_path(0, 9, 30, 3, false)
		_path(14, 2, 2.5, 17, false)
		for y in range(4, 17):
			if y > 8 and y < 12:
				continue
			for x in range(8, 23):
				_grass(x, y)
		# 남쪽 샛길에는 물품과 선택 트레이너가 있어 탐험 보상을 줍니다.
		_path(17.4, 16.8, 5.7, 0.8, false)
	else:
		_path(12.7, 2, 3.6, 18)
		_path(0, 9, 30, 3)
		_path(6, 7.3, 2.5, 3.2)
		if area == "incheon":
			_path(22, 4.8, 2.3, 6.1, false)
		else:
			_path(18.8, 7, 3, 3.5)
			_path(11, 13, 3, 3)
	for i in range(60):
		var x: float = 25 + _noise(i, 13) * 910
		var y: float = 50 + _noise(i, 14) * 545
		if _noise(i, 16) > 0.5:
			_flower(x, y, ["ffe8ea", "fff0b1", "e4c9f9"][i % 3], 1.4)


func _river(area: String) -> void:
	if area == "suwon":
		return
	var x: float = 18.2 * TILE if area == "incheon" else 24.9 * TILE
	var width: float = 2.5 * TILE if area == "incheon" else 1.65 * TILE
	_box(x - 8, 0, width + 16, WORLD_SIZE.y, "9caa8e")
	_box(x, 0, width, WORLD_SIZE.y, "65a8a7")
	_box(x, 0, 6, WORLD_SIZE.y, "478584")
	_box(x + width - 6, 0, 6, WORLD_SIZE.y, "4e9190")
	for y in range(0, 640, 25):
		_oval(x - 4, y, 9, 8, "b6b9a1", 10)
		_oval(x + width + 4, y + 12, 8, 7, "a6b09a", 10)
	for i in range(30):
		var wx: float = x + 8 + _noise(i, 29) * (width - 23)
		var wy: float = fposmod(_noise(i, 18) * 640 + _time * 7, 640)
		if wy < 280 or wy > 389:
			_line([[wx, wy], [wx + 5, wy - 1], [wx + 13, wy]], "d4ece188", 1)
	for i in range(12):
		var ly: float = _noise(i, 19) * 640
		var lx: float = x + 12 + _noise(i, 8) * (width - 24)
		if ly < 280 or ly > 389:
			_oval(lx, ly, 6, 3, "578d6c", 10)
			if i % 4 == 0:
				_flower(lx, ly - 2, "ffe1e8", 1.5)
	_bridge(x, 9 * TILE, width, 3 * TILE)


func _bridge(x: float, y: float, w: float, h: float) -> void:
	_box(x - 15, y + 5, w + 32, h + 2, "526d6244")
	_box(x - 12, y, w + 24, h, "d9d1b9")
	for i in range(0, int(h), 16):
		_line([[x - 10, y + i], [x + w + 10, y + i]], "bcb59f")
	for yy in [y - 2, y + h - 1]:
		_line([[x - 17, yy], [x + w + 17, yy]], "adb4a4", 6)
		_line([[x - 17, yy - 5], [x + w + 17, yy - 5]], "eee4cb", 4)
		for xx in range(int(x - 14), int(x + w + 16), 21):
			_box(xx - 3, yy - 15, 6, 18, "c5c5af")
			_oval(xx, yy - 16, 5, 3, "ece6d0", 12)


func _building(b: Dictionary) -> void:
	var x: float = b.x * TILE
	var y: float = b.y * TILE
	var w: float = b.w * TILE
	var h: float = b.h * TILE
	var roof_h: float = h * 0.58
	_oval(x + w / 2 + 10, y + h + 8, w * 0.61, 14, "294c4645")
	_box(x - 6, y + h - 12, w + 12, 21, "b7b6a3")
	_box(x - 9, y + h, w + 18, 7, "d9d5bf")
	_box(x, y + roof_h * 0.65, w, h - roof_h * 0.65 - 6, "e9dfc3")
	_box(x, y + roof_h + 5, w, 8, "8b5f49")
	var pillars: int = 6 if b.type == "gym" else 4
	for i in range(pillars):
		var px: float = x + 8 + i * (w - 16) / (pillars - 1)
		_box(px - 4, y + roof_h - 8, 8, h - roof_h + 2, "78533f")
		_box(px - 3, y + roof_h - 8, 2, h - roof_h + 2, "bc8860")
		_box(px - 7, y + h - 9, 14, 7, "c9c6af")
	for side in [-1, 1]:
		var wx: float = x + w / 2 + side * w * 0.31 - 14
		_box(wx - 1, y + h * 0.57 - 1, 30, h * 0.26 + 2, "795944")
		_box(wx, y + h * 0.57, 28, h * 0.26, "d8c798")
		for xx in range(int(wx + 6), int(wx + 28), 7):
			_line([[xx, y + h * 0.57], [xx, y + h * 0.83]], "927358")
		_line([[wx, y + h * 0.7], [wx + 28, y + h * 0.7]], "927358")
	_box(x + w / 2 - 19, y + h * 0.49, 38, h * 0.45, "524a3f")
	_line([[x + w / 2, y + h * 0.49], [x + w / 2, y + h * 0.94]], "bda379", 2)
	_oval(x + w / 2 - 5, y + h * 0.76, 1.7, 1.7, "e5c17a", 8)
	_oval(x + w / 2 + 5, y + h * 0.76, 1.7, 1.7, "e5c17a", 8)
	# 들린 처마, 기와 골, 단청을 별도 도형으로 쌓아 그립니다.
	_poly([[x - 18, y + roof_h + 3], [x - 8, y + roof_h - 11], [x + w * 0.23, y + 6], [x + w * 0.5, y], [x + w * 0.77, y + 6], [x + w + 8, y + roof_h - 11], [x + w + 18, y + roof_h + 3]], "735667" if b.type == "center" else "334d64")
	for i in range(26):
		var t: float = i / 25.0
		var top_x: float = x + w * (0.23 + t * 0.54)
		var bottom_x: float = x - 15 + t * (w + 30)
		_line([[top_x, y + 6], [bottom_x, y + roof_h - 1]], "628291" if i % 2 else "526d7e", 2)
		_oval(bottom_x, y + roof_h + 2, 2.3, 2.2, "89a0a2", 8)
	for i in range(1, 5):
		var t: float = i / 5.0
		var inset: float = (1 - t) * w * 0.2
		_line([[x + inset - 8 * t, y + roof_h * t + 5], [x + w - inset + 8 * t, y + roof_h * t + 5]], "20394b55")
	_line([[x - 18, y + roof_h + 3], [x + w / 2, y + roof_h + 9], [x + w + 18, y + roof_h + 3]], "233849", 5)
	_line([[x + w * 0.21, y + 5], [x + w / 2, y - 1], [x + w * 0.79, y + 5]], "97a8a6", 5)
	for i in range(4):
		var xx: float = x + 10 + i * (w - 20) / 3.0
		_box(xx - 8, y + roof_h + 6, 16, 9, "547f74")
		_oval(xx, y + roof_h + 11, 3, 2, "c4ac6e", 8)
	if not b.label.is_empty():
		var sign_w: float = minf(w - 15, b.label.length() * 11 + 20)
		_box(x + w / 2 - sign_w / 2 - 1, y + roof_h + 6, sign_w + 2, 22, "d9c598")
		_box(x + w / 2 - sign_w / 2, y + roof_h + 7, sign_w, 20, "263f46")
		_label(b.label, x + w / 2, y + roof_h + 17, 11)
	if b.type == "center":
		_oval(x + w / 2, y + roof_h * 0.43, 12, 10, "eee7d6", 20)
		_box(x + w / 2 - 2, y + roof_h * 0.43 - 7, 4, 14, "bc626d")
		_box(x + w / 2 - 7, y + roof_h * 0.43 - 2, 14, 4, "bc626d")
	if b.type == "gym":
		_oval(x + w / 2, y + roof_h * 0.4, 13, 10, "bca779", 20)
		_label("성", x + w / 2, y + roof_h * 0.4, 11, "3e5960")


func _tree(tree: Dictionary) -> void:
	var x: float = tree.x * TILE + 16
	var y: float = tree.y * TILE + 16
	var s: float = tree.scale
	_oval(x + 10, y + 4, 36 * s, 13 * s, "234a3c38")
	_poly([[x - 6, y], [x - 4, y - 40 * s], [x - 12, y - 66 * s], [x - 5, y - 53 * s], [x + 1, y - 34 * s], [x + 8, y - 58 * s], [x + 6, y - 24 * s], [x + 7, y]], "755744")
	_line([[x - 3, y - 2], [x - 1, y - 38 * s], [x - 8, y - 57 * s]], "a1815b", 2)
	var colors: Array = ["bf7698", "e89bb5", "f4bdd0", "ffdae4"] if tree.pink else ["2c654f", "3f8058", "589567", "82ae77"]
	var clusters: Array = [[-24, -49, 25], [23, -50, 23], [0, -71, 31], [-11, -40, 25], [16, -32, 24], [-31, -29, 16], [34, -32, 17], [0, -49, 29]]
	for i in range(clusters.size()):
		var cx: float = x + clusters[i][0] * s
		var cy: float = y + clusters[i][1] * s
		var r: float = clusters[i][2] * s
		_oval(cx, cy + 5, r, r * 0.72, colors[0], 18)
		_oval(cx, cy, r, r * 0.73, colors[1], 18)
		_oval(cx - 2, cy - 4, r * 0.88, r * 0.64, colors[2], 18)
		_oval(cx - 6, cy - 10, r * 0.38, r * 0.28, colors[3], 14)
		for j in range(5):
			var angle: float = _noise(i * 12 + j, 4) * TAU
			var rr: float = _noise(i, j) * r * 0.8
			var fx: float = cx + cos(angle) * rr
			var fy: float = cy + sin(angle) * rr * 0.7
			if tree.pink:
				_flower(fx, fy, "ffe7ed" if j % 2 else "eda2c0", 1.7)
			else:
				_oval(fx, fy, 4, 2, "a0be80" if j % 2 else "649f65", 8)


func _lantern(x: float, y: float) -> void:
	_oval(x + 3, y, 8, 3, "244c3f44")
	_box(x - 3, y - 35, 6, 35, "6f6554")
	_box(x - 8, y - 41, 16, 15, "f0dba3")
	_line([[x - 9, y - 42], [x, y - 47], [x + 9, y - 42]], "445b5e", 5)
	_line([[x, y - 40], [x, y - 27]], "baa373")
	if state.get("stage", "prologue") == "prologue":
		for i in range(5):
			var c := Color("ffda77")
			c.a = 0.018
			_paint_target.draw_circle(Vector2(x, y - 34), 14 + i * 6, c)


func _decoration(area: String) -> void:
	if area == "suwon_gym":
		_gym_props()
		return
	var lanterns: Array = [[12, 8], [16.7, 8], [21.5, 11.8], [6, 8.5], [8.4, 8.5]]
	if area == "suwon":
		lanterns = [[6, 8.5], [8.5, 8.5], [18.5, 8.5], [22, 8.5], [14, 6]]
		_box(68, 44, 824, 34, "9eaa9c")
		for yy in range(44, 78, 11):
			for xx in range(68, 890, 25):
				_box(xx + 1, yy + 1, 23, 9, "bcc2b0" if _noise(xx, yy) > 0.5 else "aeb7a7")
		for xx in range(65, 895, 27):
			_box(xx, 33, 17, 14, "d0d1bd")
		var x: float = 14.3 * TILE + 16
		var y: float = 10.2 * TILE + 16
		_oval(x + 6, y + 8, 40, 25, "47635440")
		_oval(x, y, 39, 26, "acae96")
		_oval(x, y - 4, 35, 23, "e0d9bc")
		_oval(x, y - 5, 29, 17, "74aaa3")
		_oval(x, y - 5, 22, 12, "a9d0c0")
		_box(x - 5, y - 25, 10, 20, "c4c6ac")
		_oval(x, y - 26, 17, 8, "e5dfc5")
		_oval(x, y - 28, 11, 4, "95c7bd")
	elif area == "route":
		lanterns = [[5.4, 9.3], [27.3, 9.3]]
		_box(2.8 * TILE, 8.6 * TILE, 65, 12, "987655")
		_box(2.9 * TILE, 8.6 * TILE + 12, 5, 12, "6e6246")
		_box(4.6 * TILE, 8.6 * TILE + 12, 5, 12, "6e6246")
	for point in lanterns:
		_lantern(point[0] * TILE, point[1] * TILE)
	var beds: Array = [[11, 12.5], [16.5, 12.5], [22, 7.5]]
	if area == "suwon":
		beds = [[4, 8.5], [24, 8.5], [8, 15.3], [21.8, 15]]
	elif area == "route":
		beds = [[5.3, 13.7], [22, 3.3]]
	for bed in beds:
		_box(bed[0] * TILE - 14, bed[1] * TILE - 8, 44, 21, "617a54")
		for i in range(7):
			_flower(bed[0] * TILE - 8 + i * 5, bed[1] * TILE + _noise(i, bed[1]) * 5, "f8dce5" if i % 2 else "dd94b6", 2.2)


func _gym_props() -> void:
	_box(0,0,WORLD_SIZE.x,34,"243d46")
	_box(0,34,WORLD_SIZE.x,8,"bdab82")
	for x in range(1,29,3): _box(x*TILE+5,44,12,5,"738287")
	for y in [5,14]:
		for x in [3,26]:
			_box(x*TILE,y*TILE,34,42,"526a65")
			_box(x*TILE+4,y*TILE+4,26,34,"c9b986")
			_line([[x*TILE+8,y*TILE+27],[x*TILE+26,y*TILE+11]],"8b5e51",3)
	var plates := [{"x":10,"symbol":"☼"},{"x":14,"symbol":"△"},{"x":18,"symbol":"≈"}]
	var step: int = int(state.get("gymPuzzleStep",0))
	for i in range(plates.size()):
		var px: float = plates[i].x*TILE+16
		var py: float = 10*TILE+16
		_box(px-19,py-19,38,38,"6c7169")
		_box(px-15,py-15,30,30,"d5c69f" if i >= step else "a6cba2")
		_oval(px,py,10,10,"d7bb79" if i >= step else "7ca68b",20)
		_label(plates[i].symbol,px,py,14,"fff5dc")
	var unlocked: bool = state.get("gymTrainerWins",[]).size() >= 3 and state.get("gymPuzzleSolved",false)
	if not unlocked:
		_box(11*TILE,4*TILE,8*TILE,8,"60463e")
		for x in range(11,20,2): _box(x*TILE,4*TILE-5,8,23,"d3bd87")
		_line([[11*TILE,4*TILE+18],[19*TILE,4*TILE+18]],"e9d6a3",3)
	else:
		_box(12*TILE,4*TILE,4*TILE,8,"86bc9a88")
	_box(12*TILE,2*TILE,4*TILE,18,"796b58")
	_box(12*TILE+5,2*TILE+5,4*TILE-10,8,"d6c69e")
	_oval(14*TILE+16,2*TILE+7,10,6,"5a8e81")
	_box(3*TILE,14*TILE,3*TILE,2*TILE,"725b4b")
	_box(3*TILE+4,14*TILE+4,3*TILE-8,2*TILE-8,"e4d7b7")
	_label("해 → 산 → 물",4.5*TILE,15*TILE,10,"354d4c")


func _person(tx: float, ty: float, kind: String, facing: String = "down", walking: bool = false) -> void:
	var x: float = tx * TILE + 16
	var y: float = ty * TILE + 16
	_oval(x + 1, y + 1, 10, 4, "203d484f")
	if walking and not reduced_motion:
		y += sin(_time * 10) * 1.1
	var harin: bool = kind == "harin"
	var seohwa: bool = kind == "seohwa"
	var hair: String = "dce2f2" if seohwa else ("2c2732" if harin else "26313c")
	var coat: String = "efeaf0" if seohwa else ("f1e1d9" if harin else "274857")
	var accent: String = "d881a4" if seohwa else "b84e5e"
	if harin or seohwa:
		_oval(x, y - 21, 11, 19, hair)
		# 양쪽 머리카락을 나누어 꼭짓점이 서로 교차하지 않도록 합니다.
		_poly([[x - 9, y - 24], [x - 15, y - 8], [x - 7, y - 11], [x, y - 25]], hair)
		_poly([[x, y - 25], [x + 7, y - 11], [x + 15, y - 8], [x + 9, y - 24]], hair)
	var stride: float = sin(_time * 12) * 2 if walking and not reduced_motion else 0.0
	_box(x - 7, y - 8 + stride, 5, 9, "253548")
	_box(x + 2, y - 8 - stride, 5, 9, "253548")
	_box(x - 8, y - 2 + stride, 7, 4, "293544")
	_box(x + 1, y - 2 - stride, 7, 4, "293544")
	if harin or seohwa:
		_poly([[x - 5, y - 21], [x + 5, y - 21], [x + 11, y - 6], [x - 11, y - 6]], "e28ba8" if seohwa else "332d3c")
		_poly([[x - 7, y - 21], [x - 11, y - 8], [x - 6, y - 7], [x - 1, y - 17], [x + 6, y - 7], [x + 12, y - 8], [x + 7, y - 21]], coat)
		_line([[x - 5, y - 16], [x + 6, y - 12]], accent, 2)
		_flower(x + 6, y - 9, "d8b66b", 0.9)
	else:
		_box(x - 7, y - 22, 14, 17, coat)
		_poly([[x - 5, y - 21], [x, y - 16], [x + 5, y - 21]], "f3e3c9")
		_box(x - 7, y - 12, 14, 3, "ad7d5b")
		if facing == "up":
			_box(x - 7, y - 20, 14, 14, "ad7953")
	_line([[x - 8, y - 20], [x - 11, y - 12 + stride]], coat, 5)
	_line([[x + 8, y - 20], [x + 11, y - 12 - stride]], coat, 5)
	_oval(x - 11, y - 11 + stride, 2.4, 2.7, "f3d6bd", 10)
	_oval(x + 11, y - 11 - stride, 2.4, 2.7, "f3d6bd", 10)
	_oval(x, y - 29, 11, 11.5, "f4d7bf", 20)
	if facing == "up":
		_oval(x, y - 31, 11.5, 11, hair, 20)
	else:
		_oval(x, y - 35, 11.5, 7, hair, 20)
		_poly([[x - 11, y - 35], [x + 11, y - 35], [x + 11, y - 27], [x + 7, y - 30], [x + 4, y - 24], [x + 1, y - 30], [x - 4, y - 25], [x - 7, y - 29], [x - 11, y - 25]], hair)
		var gaze: float = -2.0 if facing == "left" else (2.0 if facing == "right" else 0.0)
		_oval(x - 4 + gaze, y - 27, 1.8, 2.6, "343345", 10)
		_oval(x + 4 + gaze, y - 27, 1.8, 2.6, "343345", 10)
		_box(x - 5 + gaze, y - 29, 1, 2, "fff9ed")
		_box(x + 3 + gaze, y - 29, 1, 2, "fff9ed")
		_line([[x - 1, y - 22], [x + 1, y - 22]], "c1837d")
	if harin or seohwa:
		_flower(x + 9, y - 37, "f4e7dd" if harin else "efb9ce", 2.3)
		_line([[x + 10, y - 35], [x + 14, y - 24]], accent, 2)
		_oval(x + 12, y - 27, 1, 2, "d2ae64", 8)
	else:
		_oval(x, y - 36, 12, 6, "e8deca" if kind == "healer" else "b45161", 20)
		_box(x - 12, y - 35, 24, 5, "91a794" if kind == "healer" else "ead9ba")
		_oval(x + 5, y - 31, 10, 2.8, "568274" if kind == "healer" else "8e4055", 16)
		_oval(x, y - 37, 2.4, 2.4, "edd4a0", 10)


func _ralts_marker(tx: float, ty: float, rescue: bool = false) -> void:
	# 랄토스 원본 스프라이트가 없어 임시 빛 표식으로 명시합니다.
	var x: float = tx * TILE + 16
	var y: float = ty * TILE + 12 + (0.0 if reduced_motion else sin(_time * 2) * 2)
	for i in range(4):
		_oval(x, y - 9, 13 + i * 5, 13 + i * 4, "d8d3ff12", 20)
	_oval(x, y - 9, 9, 10, "d8ebf6", 16)
	_oval(x - 3, y - 13, 3, 4, "ffffff", 10)
	_label("랄토스" if not rescue else "?", x, y + 11, 10, "25485b")


func _trainer_done(id: String) -> bool:
	if id.begins_with("gym_trainer"):
		return state.get("gymTrainerWins", []).has(int(id.trim_prefix("gym_trainer")))
	var index: int = int(id.trim_prefix("trainer"))
	var wins: Array = state.get("flags", {}).get("trainerWins", state.get("trainerWins", []))
	return wins.has(index) or wins.has("trainer%d" % index)


func _marker(item: Dictionary) -> void:
	var x: float = item.x * TILE + 16
	var y: float = item.y * TILE + 16
	var player: Dictionary = state.get("player", {"x": 14, "y": 14})
	var nearby: bool = Vector2(player.x, player.y).distance_to(Vector2(item.x, item.y)) < 1.8
	var stage: String = state.get("stage", "prologue")
	var target: bool = (stage == "prologue" and item.id == "ralts") or (stage == "rescued" and item.id == "lab")
	if item.id == "harin" and stage == "journey" and not state.get("flags", {}).get("rivalWon", false):
		target = true
	if item.id == "gym" and state.get("badges", []).is_empty():
		target = true
	if item.kind == "exit":
		_box(x - 13, y - 11, 26, 22, "264f55dd")
		var direction: float = -1.0 if item.id == "gateBack" else 1.0
		_line([[x - direction * 5, y - 5], [x + direction * 4, y], [x - direction * 5, y + 5]], "fff4d0", 2)
	elif item.kind == "item":
		_box(x - 7, y - 11, 14, 12, "a87645")
		_box(x - 8, y - 13, 16, 5, "e6c87d")
		_box(x - 1, y - 11, 3, 10, "f5de98")
	elif target or nearby or item.kind == "trainer":
		var yy: float = y - (54.0 if item.kind in ["person", "quest", "trainer"] else 20.0)
		if not reduced_motion:
			yy += sin(_time * 2.5) * 2
		_oval(x, yy, 9, 9, "f8dea2" if target else "f6eddd", 16)
		var symbol: String = "!" if target else "···"
		if item.kind == "trainer":
			symbol = "✓" if _trainer_done(item.id) else "!"
		_label(symbol, x, yy, 11, "35505b")
	if nearby:
		var width: float = item.label.length() * 11 + 24
		_box(x - width / 2 - 1, y + 14, width + 2, 24, "dccb9c")
		_box(x - width / 2, y + 15, width, 22, "193f49ee")
		_label(item.label, x, y + 26, 11)


func _paint_layer(canvas: Node2D, callback: Callable) -> void:
	_paint_target = canvas
	callback.call()
	_paint_target = null


func _layer(id: String, depth: int, callback: Callable) -> PaintLayer:
	var layer: PaintLayer
	if _layers.has(id):
		layer = _layers[id]
	else:
		layer = PaintLayer.new()
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_layers[id] = layer
		add_child(layer)
	layer.z_index = depth
	layer.paint = _paint_layer.bind(callback)
	return layer


func _base_map(area: String) -> void:
	if map_backdrop != null and map_backdrop.visible: return
	_ground(area)
	_river(area)
	_decoration(area)


func _prepare_map(area: String) -> void:
	var key: String = area + ("-night" if state.get("stage", "prologue") == "prologue" else "-day")
	if key == _map_key:
		return
	_map_key = key
	for old in _layers.values():
		old.hide()
		old.queue_free()
	_layers.clear()
	# TileMapLayer holds the generated 32px terrain atlas; prop layers sort above it.
	_populate_tilemap(area)
	_layer("ground", -1000, _base_map.bind(area)).queue_redraw()
	var using_pixel_backdrop := map_backdrop != null and map_backdrop.visible
	if not using_pixel_backdrop:
		for i in range(BUILDINGS[area].size()):
			var building: Dictionary = BUILDINGS[area][i]
			_layer("building%d" % i, int((building.y + building.h) * TILE), _building.bind(building)).queue_redraw()
		if area == "suwon_gym":
			_layer("gym-props", -800, _decoration.bind(area)).queue_redraw()
		if not _tree_cache.has(area):
			_tree_cache[area] = _trees(area)
		for i in range(_tree_cache[area].size()):
			var tree: Dictionary = _tree_cache[area][i]
			_layer("tree%d" % i, int(tree.y * TILE + 16), _tree.bind(tree)).queue_redraw()


func _draw_field_sprite(sheet_id: String, tx: float, ty: float, facing: String, walking: bool) -> void:
	var sheet: Texture2D = actor_sheets.get(sheet_id)
	if sheet == null:
		_person(tx,ty,sheet_id,facing,walking)
		return
	var col: int = {"down":0,"left":1,"right":2,"up":3}.get(facing,0)
	var row: int = 0 if not walking else 1 + (int(_time*8.0)%2 if not reduced_motion else 0)
	var x: float = tx*TILE+16
	var y: float = ty*TILE+16
	_paint_target.draw_texture_rect_region(sheet,Rect2(x-20,y-31,40,48),Rect2(col*48,row*48,48,48),Color.WHITE)


func _actor(data: Dictionary) -> void:
	match data.kind:
		"person":
			var character_id: String = str(data.get("character_id", data.role))
			if actor_sheets.has(character_id):
				_draw_field_sprite(character_id, data.x, data.ty, str(data.get("facing", "down")), bool(data.get("walking", false)))
			elif data.role == "leader":
				_label("이도윤 · 시트 미연결", data.x*TILE-42, data.ty*TILE, 11)
			else:
				_person(data.x, data.ty, data.role)
		"ralts": _ralts_marker(data.x, data.ty, true)
		"player":
			var player: Dictionary = state.get("player", {"x":14.0,"y":14.0,"facing":"down"})
			_draw_field_sprite("player",player.x,player.y,player.get("facing","down"),moving)

func _water_motion(area: String) -> void:
	if (map_backdrop != null and map_backdrop.visible) or area in ["suwon", "suwon_gym"] or reduced_motion:
		return
	var x: float = 18.2 * TILE if area == "incheon" else 24.9 * TILE
	var width: float = 2.5 * TILE if area == "incheon" else 1.65 * TILE
	for i in range(16):
		var wx: float = x + 8 + _noise(i, 52) * (width - 23)
		var wy: float = fposmod(_noise(i, 43) * 640 + _time * 7, 640)
		if wy < 280 or wy > 389:
			_line([[wx, wy], [wx + 5, wy - 1], [wx + 13, wy]], "e5f3ea88", 1)


func _effects(area: String) -> void:
	if cinematic_mode in ["traces", "rescue"]:
		var cx: float = 23*TILE+16
		var cy: float = 5*TILE+16
		if cinematic_mode == "traces":
			for i in range(6):
				var drift: float = sin(_time*2.8+i*0.9)*9
				_oval(cx+drift,cy+cos(_time*2+i)*7,4,7,"7965c588",12)
				_line([[cx-35+i*12,cy+35],[cx-28+i*12,cy+28]],"a495c099",2)
			_label("?",cx,cy-40,18,"fff5d9")
		else:
			var pulse: float = 1.0 + (0.12 if reduced_motion else 0.2*sin(_time*4.0))
			for i in range(5): _oval(cx,cy,12+i*10*pulse,8+i*7*pulse,"c8eaff22",20)
			for i in range(8):
				var angle: float = _time*1.5+i*TAU/8
				_oval(cx+cos(angle)*34,cy+sin(angle)*22,2.4,2.4,"fff5c9",8)
	if state.get("stage", "prologue") == "prologue" and area == "incheon":
		_box(0, 0, WORLD_SIZE.x, WORLD_SIZE.y, "22335f15")
	if not reduced_motion:
		for i in range(24):
			var x: float = fposmod(_noise(i, 31) * 960 + _time * (8 + _noise(i, 4) * 7), 960)
			var y: float = fposmod(_noise(i, 32) * 640 + _time * (6 + _noise(i, 2) * 6), 640)
			_oval(x + sin(_time / 1.7 + i) * 12, y, 2.2, 1.1, "ffe0e9aa", 8)
	for item in interactions(state):
		_marker(item)
		if debug_positions:
			var p := Vector2(item.x, item.y)*TILE+Vector2(16,16)
			_paint_target.draw_arc(p, 10, 0, TAU, 16, Color.YELLOW, 2)
			_label("%s (%.1f,%.1f)" % [item.id,item.x,item.y],p.x-30,p.y+22,10)
	if debug_positions:
		for zone in Placement.grass_config(area).get("zones", []):
			_paint_target.draw_rect(Rect2(Vector2(zone[0],zone[1])*TILE+Vector2(16,16),Vector2(zone[2]-zone[0],zone[3]-zone[1])*TILE),Color.GREEN,false,2)



func _draw() -> void:
	if state.is_empty():
		return
	_time = 0.0 if reduced_motion else Time.get_ticks_msec() / 1000.0
	var area: String = state.get("area", "incheon")
	if not BUILDINGS.has(area):
		area = "incheon"
	_prepare_map(area)
	var actors: Array[Dictionary] = []
	for item in Placement.npcs(area):
		if item.get("after_rescue", false) and state.get("stage") == "prologue": continue
		var actor: Dictionary = item.duplicate(true)
		actor.ty = item.y
		actor.y = item.y * TILE + 16
		actor.kind = "person"
		actor.character_id = item.get("character_id", item.get("trainer_type", item.role))
		actors.append(actor)
	if area == "incheon" and state.get("stage") == "prologue":
		actors.append({"id":"ralts", "y":176.0, "kind":"ralts", "x":23.0, "ty":5.0})
	var player: Dictionary = state.get("player", {"x": 14.0, "y": 14.0, "facing": "down"})
	actors.append({"id": "player", "y": player.y * TILE + 16, "kind": "player"})
	# 발 위치의 깊이를 사용해 건물·나무 뒤를 자연스럽게 지나갑니다.
	for actor in actors:
		_layer("actor-" + actor.id, int(actor.y) + 1, _actor.bind(actor)).queue_redraw()
	_layer("grass-front", int(player.y*TILE+16)+2, _grass_front).queue_redraw()
	_layer("water", -900, _water_motion.bind(area)).queue_redraw()
	_layer("effects", 2000, _effects.bind(area)).queue_redraw()


# 원본 맵의 풀잎 픽셀을 발 앞에 다시 그립니다. 새 배경으로 덮어쓰지 않습니다.
func _grass_front() -> void:
	if map_backdrop == null or not map_backdrop.visible: return
	var p: Dictionary = state.player
	if not is_grass(state.area, p.x, p.y): return
	var foot := Vector2(p.x*TILE+16, p.y*TILE+16).round()
	for i in range(6):
		var sway := roundf(sin(_time*15.0+i)*2.0) if moving and not reduced_motion else 0.0
		var height := 8.0 + float(i%3)*2.0
		var rect := Rect2(foot+Vector2(-18+i*6,17-height),Vector2(6,height))
		_paint_target.draw_texture_rect_region(map_backdrop.texture,Rect2(rect.position+Vector2(sway,0),rect.size),rect)
