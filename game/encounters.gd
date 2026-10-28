extends RefCounted

const Placement = preload("res://game/field_data.gd")
var distance := 0.0
var area_key := ""
var debug_guaranteed := false

func reset() -> void:
	distance = 0.0
	area_key = ""

# 실제 이동한 풀숲 거리 1타일마다 한 번 판정합니다. 정지·충돌·쿨다운에는 누적하지 않습니다.
func advance(area: String, before: Vector2, after: Vector2, cooldown: float, rng: Callable = Callable()) -> Dictionary:
	if area_key != area:
		distance = 0.0
		area_key = area
	if cooldown > 0 or not Placement.is_grass(area, after):
		distance = 0.0
		return {}
	if not Placement.is_grass(area, before): return {}
	distance += before.distance_to(after)
	var config := Placement.grass_config(area)
	while distance >= 1.0:
		distance -= 1.0
		if _roll(rng) >= (1.0 if debug_guaranteed else float(config.chance)): continue
		var total := 0.0
		for entry in config.species: total += float(entry.weight)
		var choice := _roll(rng)*total
		for entry in config.species:
			choice -= float(entry.weight)
			if choice < 0:
				distance = 0.0
				return {"species":entry.id}
	return {}

func _roll(rng: Callable) -> float:
	return clampf(float(rng.call()) if rng.is_valid() else randf(), 0.0, 0.999999)
