extends Node2D

signal dialogue_closed
signal rescue_event_finished

# 인천부터 수원까지의 화면, 입력, 이벤트 연결을 담당합니다.
const GameEngine = preload("res://game/engine.gd")
const Field = preload("res://game/field.gd")
const FONT = preload("res://assets/fonts/NotoSansKR.otf")
const SAVE_PATH = "user://adventure_v1.json"
const INK = Color("24473f")
const MUTED = Color("7d8e7b")
const PAPER = Color("fffdf4")
const GOLD = Color("c1a06c")
const TYPES = {"normal":"노말", "fire":"불꽃", "water":"물", "grass":"풀", "psychic":"에스퍼", "fairy":"페어리", "flying":"비행", "bug":"벌레", "poison":"독", "electric":"전기", "ice":"얼음", "fighting":"격투", "ground":"땅", "rock":"바위", "ghost":"고스트", "dragon":"드래곤", "dark":"악", "steel":"강철"}

var state: Dictionary
var field: Node2D
var hud: Control
var side: Control
var menu: Control
var dialogue_layer: Control
var battle_layer: Control
var title_layer: Control
var file_dialog: FileDialog
var status_label: Label
var hint_label: Label
var active := false
var dialogue_lines: Array = []
var dialogue_index := 0
var dialogue_callback: Callable
var battle_page := "main"
var walk_path: Array[Vector2] = []
var auto_interaction := ""
var grass_distance := 0.0
var encounter_cooldown := 0.0
var toast_time := 0.0
var last_save := "아직 저장하지 않았습니다"
var loading_save := false
var cinematic_active := false
var scripted_moving := false
var cinematic_generation := 0
var cinematic_tweens: Array[Tween] = []
var event_wash: ColorRect
var event_sfx: AudioStreamPlayer
var battle_sprites: Dictionary = {}
var battle_backgrounds: Dictionary = {}
var battle_animation_generation := 0


func _ready() -> void:
	state = GameEngine.create_game()
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 15
	ThemeDB.fallback_font = FONT
	var field_frame := Control.new()
	field_frame.position = Vector2(20, 100)
	field_frame.size = Vector2(960, 640)
	field_frame.clip_contents = true
	field_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(field_frame)
	field = Field.new()
	field.state = state
	field_frame.add_child(field)
	event_wash = ColorRect.new()
	event_wash.color = Color("b9c7ff",0.0)
	event_wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	event_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	event_wash.z_index = 20
	field_frame.add_child(event_wash)
	event_sfx = AudioStreamPlayer.new()
	event_sfx.stream = load("res://assets/generated/forest_anomaly.mp3") if ResourceLoader.exists("res://assets/generated/forest_anomaly.mp3") else null
	add_child(event_sfx)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = theme
	layer.add_child(hud)
	_label(hud, "포켓몬스터", Rect2(25, 14, 330, 22), 11, GOLD)
	_label(hud, "천년의 전설", Rect2(24, 32, 330, 40), 30)
	_label(hud, "첫 번째 여정   /   인천 — 수원", Rect2(490, 29, 450, 28), 14, MUTED)
	_button(hud, "도움말", Rect2(1176, 27, 80, 35), open_help, "HelpButton")
	side = Control.new()
	side.position = Vector2(1004, 100)
	hud.add_child(side)
	_label(hud, "WASD / 방향키  이동     E / Space  대화·조사     마우스 클릭  목적지 이동", Rect2(24, 754, 795, 22), 12, MUTED)
	_label(hud, "개발판 v0.2 · 픽셀 필드·배틀 스프라이트", Rect2(995, 754, 280, 22), 11, MUTED)
	hint_label = _label(hud, "", Rect2(260, 706, 550, 28), 15, PAPER)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label = _label(hud, "", Rect2(24, 777, 1150, 22), 11, INK)
	menu = Control.new()
	menu.z_index = 20
	hud.add_child(menu)
	menu.visible = false
	battle_layer = Control.new()
	hud.add_child(battle_layer)
	battle_layer.visible = false
	dialogue_layer = Control.new()
	hud.add_child(dialogue_layer)
	dialogue_layer.visible = false
	title_layer = Control.new()
	hud.add_child(title_layer)
	file_dialog = FileDialog.new()
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PackedStringArray(["*.json ; 모험 저장 파일"])
	file_dialog.file_selected.connect(_file_selected)
	hud.add_child(file_dialog)
	refresh_hud()
	show_title()


func _process(delta: float) -> void:
	if not is_instance_valid(field):
		return
	field.state = state
	field.moving = scripted_moving
	encounter_cooldown = maxf(0, encounter_cooldown - delta)
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0:
			status_label.text = last_save
	if _can_move():
		var direction := Vector2.ZERO
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): direction.y -= 1
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): direction.y += 1
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): direction.x -= 1
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): direction.x += 1
		if direction != Vector2.ZERO:
			walk_path.clear()
			auto_interaction = ""
		elif not walk_path.is_empty():
			var here := Vector2(state.player.x, state.player.y)
			direction = walk_path[0] - here
			if direction.length() < 0.10:
				state.player.x = walk_path[0].x
				state.player.y = walk_path[0].y
				walk_path.pop_front()
				if walk_path.is_empty() and not auto_interaction.is_empty():
					var target := auto_interaction
					auto_interaction = ""
					interact(target)
				direction = Vector2.ZERO
		if direction != Vector2.ZERO:
			_move(direction.normalized() * minf(delta, 0.05) * 4.8)
		var nearest := nearest_interaction()
		hint_label.text = "[E]  " + str(nearest.label) if not nearest.is_empty() else ""
	else:
		hint_label.text = ""
	field.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if file_dialog.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_E, KEY_SPACE, KEY_ENTER]:
			if dialogue_layer.visible: advance_dialogue()
			elif _can_move(): interact()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if menu.visible: close_menu()
			elif _can_move(): open_save()
		elif event.keycode == KEY_F5 and _can_move(): save_game()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _can_move():
		var point: Vector2 = (event.position - field.global_position) / 32.0 - Vector2(0.5, 0.5)
		if point.x >= 0 and point.x < 30 and point.y >= 0 and point.y < 20:
			set_destination(point)


func _can_move() -> bool:
	return active and not cinematic_active and not menu.visible and not dialogue_layer.visible and not battle_layer.visible and not file_dialog.visible


func _gym_open() -> bool:
	return GameEngine.gym_leader_unlocked(state)


func _can_walk(x: float, y: float) -> bool:
	return Field.can_walk(state.area,x,y,_gym_open())


func _move(offset: Vector2) -> void:
	var before := Vector2(state.player.x, state.player.y)
	if _can_walk(state.player.x + offset.x, state.player.y): state.player.x += offset.x
	if _can_walk(state.player.x, state.player.y + offset.y): state.player.y += offset.y
	var after := Vector2(state.player.x, state.player.y)
	if after.distance_to(before) < 0.001:
		walk_path.clear()
		return
	field.moving = true
	if absf(offset.x) > absf(offset.y): state.player.facing = "right" if offset.x > 0 else "left"
	else: state.player.facing = "down" if offset.y > 0 else "up"
	if state.area == "route" and Field.is_grass(state.area, state.player.x, state.player.y):
		grass_distance += after.distance_to(before)
		if grass_distance >= 5.5 and encounter_cooldown <= 0:
			grass_distance = 0
			state.steps += 1
			start_battle("wild")


# 클릭 이동도 키보드 이동과 같은 충돌 판정을 사용합니다.
func set_destination(point: Vector2) -> void:
	var target := Vector2i(roundi(point.x), roundi(point.y))
	auto_interaction = ""
	for item in Field.interactions(state):
		if point.distance_to(Vector2(item.x, item.y)) < 1.5:
			target = Vector2i(int(item.x), int(item.y))
			auto_interaction = item.id
			break
	if not _can_walk(target.x, target.y): return
	var origin := Vector2i(roundi(state.player.x), roundi(state.player.y))
	var queue: Array[Vector2i] = [origin]
	var previous := {origin: origin}
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		if cell == target: break
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + offset
			if not previous.has(next) and _can_walk(next.x, next.y):
				previous[next] = cell
				queue.append(next)
	if not previous.has(target): return
	walk_path.clear()
	var current := target
	while current != origin:
		walk_path.push_front(Vector2(current))
		current = previous[current]
	if walk_path.is_empty() and not auto_interaction.is_empty(): interact(auto_interaction)


func nearest_interaction() -> Dictionary:
	var best: Dictionary = {}
	var distance := 1.65
	for item in Field.interactions(state):
		var value := Vector2(state.player.x, state.player.y).distance_to(Vector2(item.x, item.y))
		if value < distance:
			distance = value
			best = item
	return best


func interact(id: String = "") -> void:
	if not _can_move(): return
	var nearest := nearest_interaction()
	if nearest.is_empty(): return
	if id.is_empty(): id = nearest.id
	var point: Dictionary = {}
	for item in Field.interactions(state):
		if item.id == id: point = item
	if point.is_empty() or Vector2(state.player.x,state.player.y).distance_to(Vector2(point.x,point.y)) > 1.75: return
	walk_path.clear()
	match id:
		"ralts": _run_ralts_rescue_event()
		"lab":
			if state.stage == "prologue": show_dialogue([{"speaker":"연구소 안내", "text":"백서화는 현장 조사를 나갔습니다. 먼저 동쪽 숲을 살펴보세요."}])
			elif not state.flags.starterChosen:
				show_dialogue([{"speaker":"백서화", "text":"이 아이가 당신을 믿고 있네요. 어젯밤의 용기가 새로운 인연이 되었어요. 이제 함께 여행할 친구도 만나 볼까요?", "portrait":"seohwa"}], open_starters)
			else:
				GameEngine.heal_party(state)
				show_dialogue([{"speaker":"백서화", "text":"동료들을 건강하게 돌봐 주었어요. 서하린과 실력을 겨뤄 보고 수원의 첫 체육관으로 떠나 보세요.", "portrait":"seohwa"}])
		"harin":
			if not state.flags.starterChosen: show_dialogue([{"speaker":"서하린", "text":"모험을 시작하기 전에 연구소에 들러야지. 랄토스도 너와 함께 가고 싶은가 봐!", "portrait":"harin"}])
			elif not state.flags.get("rivalWon",false):
				GameEngine.heal_party(state)
				show_dialogue([{"speaker":"서하린", "text":"드디어 출발이네! 여행 전에 첫 배틀, 어때? 서로의 새 친구를 소개해 주자!", "portrait":"harin"}], func(): start_battle("rival"))
			else: show_dialogue([{"speaker":"서하린", "text":"다음에는 내가 이길 거야! 1번도로에서 만나는 트레이너들과 실력을 쌓아 봐. 수원에서 다시 만나자.", "portrait":"harin"}])
		"gate":
			if not state.flags.get("rivalWon",false): toast("연구소에서 친구를 선택한 뒤 서하린과 첫 배틀을 마쳐 주세요.")
			elif state.area == "incheon": change_area("route",Vector2(2,10))
			elif state.area == "route": change_area("suwon",Vector2(2,10))
		"gateBack": change_area("incheon" if state.area == "route" else "route",Vector2(27,10))
		"healer", "center":
			GameEngine.heal_party(state)
			if state.area == "suwon" and not state.visited.has("suwon"):
				state.visited.append("suwon")
			show_dialogue([{"speaker":"포켓몬 돌봄 안내", "text":"모든 동료의 체력과 기술 PP를 회복했습니다. 도시 포켓몬센터를 방문하면 여행 지도에서 무료 빠른 이동을 이용할 수 있어요."}])
		"gym":
			if not state.flags.get("rivalWon",false): toast("먼저 서하린과 첫 배틀을 마쳐 주세요.")
			else: change_area("suwon_gym",Vector2(14,17))
		"gym_exit": change_area("suwon",Vector2(20,8))
		"gym_guide": show_dialogue([{"speaker":"성곽 안내석", "text":"성벽의 옛 문장은 말합니다. 해가 길을 열고, 산을 지나, 물로 흘러간다. 세 문양을 그 차례대로 밟으세요."}])
		"gym_plate_sun", "gym_plate_mountain", "gym_plate_water":
			var plate := id.trim_prefix("gym_plate_")
			var result: Dictionary = GameEngine.record_gym_plate(state,plate)
			field.queue_redraw()
			show_dialogue([{"speaker":"체육관 문양", "text":result.message}])
		"gym_leader":
			if not _gym_open():
				show_dialogue([{"speaker":"닫힌 성문", "text":"세 훈련생과 겨루고, 해 → 산 → 물 문양을 순서대로 밝혀야 관장 구역이 열립니다. 현재 훈련생 %d/3 · 퍼즐 %s" % [state.gymTrainerWins.size(),"완료" if state.gymPuzzleSolved else "미완료"]}])
			else:
				show_dialogue([{"speaker":"이도윤 · 수원 체육관", "text":"성곽의 단단함은 동료를 믿는 데서 나오지. 구구, 피죤, 피죤투—세 동료의 연계를 보여 주마!"}], func(): start_battle("gym"))
		"shop": open_shop()
		"museum": show_dialogue([{"speaker":"전시관 관리인", "text":"오래된 유물 하나가 사라졌습니다. 누군가 고대 문양을 조사하러 왔다는데… 여행 중 수상한 흔적을 보거든 알려 주세요."}])
		"item":
			if not state.flags.get("routeItem",false):
				state.flags.routeItem = true
				state.bag.potions += 3
				toast("샛길에서 상처약 3개를 찾았습니다!")
			else: toast("이미 조사한 샛길입니다.")
		_:
			if id.begins_with("gym_trainer"):
				var number := int(id.trim_prefix("gym_trainer"))
				var names := ["수비대 훈련생 민준", "성문 안내원 지아", "성곽 순찰자 도윤"]
				show_dialogue([{"speaker":names[number], "text":"문양 수련의 마지막 단계는 동료와 호흡을 맞추는 것. 정정당당하게 승부하자!"}], func(): start_battle("gym_trainer","",number))
			elif id.begins_with("trainer"):
				var number := int(id.trim_prefix("trainer"))
				show_dialogue([{"speaker":"1번도로 트레이너 %d" % (number+1), "text":"모험은 함께 성장하는 거야. 파티의 동료들도 경험치를 나눠 받아! 한 판 겨뤄 볼까?"}], func(): start_battle("trainer","",number))
	refresh_hud()


func change_area(area: String, point: Vector2) -> void:
	state.area = area
	state.player.x = point.x
	state.player.y = point.y
	walk_path.clear()
	encounter_cooldown = 2.0
	refresh_hud()
	toast(Field.area_info(area).name)


func _cinematic_is_current(token: int) -> bool:
	return cinematic_active and token == cinematic_generation


func _new_cinematic_tween(parallel: bool = false) -> Tween:
	var tween := create_tween()
	if parallel:
		tween.set_parallel(true)
	cinematic_tweens.append(tween)
	return tween


func _cancel_cinematic() -> void:
	# 세이브 불러오기·새 게임·타이틀 전환 후 이전 await가 새 상태를 바꾸지 않게 합니다.
	cinematic_generation += 1
	for tween in cinematic_tweens:
		if is_instance_valid(tween): tween.kill()
	cinematic_tweens.clear()
	cinematic_active = false
	scripted_moving = false
	walk_path.clear()
	if is_instance_valid(field):
		field.cinematic_mode = ""
		field.position = Vector2.ZERO
		field.scale = Vector2.ONE
		field.moving = false
		field.queue_redraw()
	if is_instance_valid(event_wash): event_wash.modulate.a = 0.0
	if is_instance_valid(event_sfx): event_sfx.stop()


func _set_scripted_player_position(point: Vector2) -> void:
	state.player.x = point.x
	state.player.y = point.y
	field.queue_redraw()


func _cinematic_walk_to(destination: Vector2, token: int) -> bool:
	if not _cinematic_is_current(token): return false
	var target := Vector2i(roundi(destination.x),roundi(destination.y))
	var origin := Vector2i(roundi(state.player.x),roundi(state.player.y))
	var queue: Array[Vector2i] = [origin]
	var previous := {origin:origin}
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		if cell == target: break
		for offset in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var next: Vector2i = cell+offset
			if not previous.has(next) and Field.can_walk(state.area,next.x,next.y,_gym_open()):
				previous[next] = cell
				queue.append(next)
	if not previous.has(target): return false
	var steps: Array[Vector2i] = []
	var current: Vector2i = target
	while current != origin:
		steps.push_front(current)
		current = previous[current]
	scripted_moving = true
	for cell in steps:
		if not _cinematic_is_current(token): return false
		var from := Vector2(state.player.x,state.player.y)
		var to := Vector2(cell)
		var direction := to-from
		state.player.facing = "right" if direction.x > 0 else ("left" if direction.x < 0 else ("down" if direction.y > 0 else "up"))
		var tween := _new_cinematic_tween()
		tween.tween_method(_set_scripted_player_position,from,to,0.10)
		await tween.finished
		if not _cinematic_is_current(token): return false
	scripted_moving = false
	field.moving = false
	return true


func _cinematic_camera(target: Vector2, zoom: float, duration: float, token: int) -> bool:
	if not _cinematic_is_current(token): return false
	var center := Vector2(480,320)
	var offset := center-target*zoom
	var tween := _new_cinematic_tween(true)
	tween.tween_property(field,"scale",Vector2(zoom,zoom),duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(field,"position",offset,duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	return _cinematic_is_current(token)


func _reset_cinematic_camera(token: int) -> bool:
	if not _cinematic_is_current(token): return false
	var tween := _new_cinematic_tween(true)
	tween.tween_property(field,"scale",Vector2.ONE,0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(field,"position",Vector2.ZERO,0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	return _cinematic_is_current(token)


func _event_flash(color: Color, strength: float, token: int) -> bool:
	if not _cinematic_is_current(token): return false
	event_wash.color = color
	event_wash.modulate.a = 0.0
	var tween := _new_cinematic_tween()
	tween.tween_property(event_wash,"modulate:a",strength,0.2)
	tween.tween_property(event_wash,"modulate:a",0.0,0.65)
	await tween.finished
	return _cinematic_is_current(token)


func _event_sound() -> void:
	if event_sfx != null and event_sfx.stream != null:
		event_sfx.stop()
		event_sfx.play()


func _run_ralts_rescue_event() -> void:
	if cinematic_active or state.stage != "prologue": return
	cinematic_generation += 1
	var token := cinematic_generation
	cinematic_active = true
	field.cinematic_mode = "traces"
	_event_sound()
	show_dialogue([
		{"speaker":"서하린", "text":"저기, 나뭇가지 사이에 작은 포켓몬이 있어! 다친 것 같아. 같이 도와주자.", "portrait":"harin"},
		{"speaker":"숲속의 작은 만남", "text":"숲의 소리가 잠시 멎었다. 나무 사이로 보랏빛 발자국이 희미하게 이어진다."}
	])
	await dialogue_closed
	if not _cinematic_is_current(token): return
	var walked := await _cinematic_walk_to(Vector2(21,7),token)
	if not walked: return
	var focused := await _cinematic_camera(Vector2(736,176),1.18,0.55,token)
	if not focused: return
	var flashed := await _event_flash(Color("9e91ef"),0.17,token)
	if not flashed: return
	show_dialogue([
		{"speaker":"서하린", "text":"이 흔적… 포켓몬의 발자국이라기보다 빛이 땅에 남긴 자국 같아.", "portrait":"harin"},
		{"speaker":"숲의 메아리", "text":"덤불 아래서 작은 숨소리가 들린다. 누군가 곁을 지키며 조심스럽게 가지를 치운다."}
	])
	await dialogue_closed
	if not _cinematic_is_current(token): return
	walked = await _cinematic_walk_to(Vector2(23,5),token)
	if not walked: return
	focused = await _cinematic_camera(Vector2(752,176),1.27,0.48,token)
	if not focused: return
	field.cinematic_mode = "rescue"
	_event_sound()
	flashed = await _event_flash(Color("e6edff"),0.48,token)
	if not flashed: return
	show_dialogue([
		{"speaker":"서하린", "text":"괜찮아, 이제 안전해. …방금 나무 뒤에 검은 그림자가 스쳐 간 것 같아.", "portrait":"harin"},
		{"speaker":"숲속의 작은 만남", "text":"빛이 잦아들자 이로치 랄토스가 조심스레 손을 내밀었다. 멀리서 낯선 발자국 소리가 사라진다."}
	])
	await dialogue_closed
	if not _cinematic_is_current(token): return
	var result: Dictionary = GameEngine.rescue_ralts(state)
	if not result.ok:
		toast(result.message)
		_cancel_cinematic()
		return
	toast(result.message)
	refresh_hud()
	field.cinematic_mode = ""
	var restored := await _reset_cinematic_camera(token)
	if not restored: return
	cinematic_active = false
	cinematic_tweens.clear()
	field.queue_redraw()
	show_dialogue([{"speaker":"다음 날 아침", "text":"랄토스가 당신 곁을 따라온다. 서쪽의 백서화 연구소에서 함께할 스타팅 파트너를 선택하자."}])
	rescue_event_finished.emit()


func show_title() -> void:
	_clear(title_layer)
	title_layer.show()
	_panel(title_layer, Rect2(20,100,960,640), Color("204c42"))
	_portrait(title_layer, "harin", Rect2(580,110,360,630))
	_label(title_layer, "POKÉMON · A THOUSAND-YEAR LEGEND", Rect2(67,145,520,28), 11, GOLD)
	_label(title_layer, "우리의 이야기가 시작되는 곳", Rect2(67,225,460,30), 17, Color("c5d7c3"))
	_label(title_layer, "천년의\n전설", Rect2(60,264,480,190), 70, PAPER)
	_label(title_layer, "벚꽃이 흩날리는 길 위에서,\n당신을 기다리는 작은 인연을 만나세요.", Rect2(68,475,455,70), 17, Color("c5d7c3"))
	_button(title_layer, "새로운 모험  →", Rect2(68,576,230,48), start_new_game, "StartButton", true)
	_button(title_layer, "이어서 하기", Rect2(68,636,140,40), load_game, "ContinueButton")
	_button(title_layer, "파일 불러오기", Rect2(220,636,150,40), func(): choose_save_file(true), "LoadFileButton")
	_label(title_layer, "인천 → 수원 · 첫 체육관까지의 플레이 가능한 개발판", Rect2(68,698,500,25), 11, Color("bdd1b9"))


func start_new_game() -> void:
	_cancel_cinematic()
	state = GameEngine.create_game()
	active = true
	title_layer.hide()
	menu.hide()
	battle_layer.hide()
	walk_path.clear()
	refresh_hud()
	show_dialogue([{"speaker":"인천, 봄의 저녁", "text":"익숙한 마을에 봄바람이 분다. 동쪽 숲에서 작은 울음소리가 들려왔다. 길을 따라 숲속의 빛나는 표시를 찾아보자."}])


func show_dialogue(lines: Array, callback: Callable = Callable()) -> void:
	dialogue_lines = lines
	dialogue_index = 0
	dialogue_callback = callback
	walk_path.clear()
	_render_dialogue()


func _render_dialogue() -> void:
	_clear(dialogue_layer)
	dialogue_layer.show()
	var entry: Dictionary = dialogue_lines[dialogue_index]
	var has_portrait: bool = entry.has("portrait")
	if has_portrait: _portrait(dialogue_layer, entry.portrait, Rect2(28,332,220,393))
	_panel(dialogue_layer, Rect2(248 if has_portrait else 40,540,712 if has_portrait else 920,182), PAPER)
	var left := 271 if has_portrait else 64
	_label(dialogue_layer, entry.speaker, Rect2(left,558,640,30), 18, INK)
	_label(dialogue_layer, entry.text, Rect2(left,599,650 if has_portrait else 850,81), 16)
	_button(dialogue_layer, "다음  ▸  [E]", Rect2(800,678,135,32), advance_dialogue, "DialogueNext")


func advance_dialogue() -> void:
	if not dialogue_layer.visible: return
	dialogue_index += 1
	if dialogue_index < dialogue_lines.size(): _render_dialogue()
	else:
		dialogue_layer.hide()
		dialogue_closed.emit()
		var callback := dialogue_callback
		dialogue_callback = Callable()
		if callback.is_valid(): callback.call()


func open_starters() -> void:
	open_menu("새로운 동료를 만나세요")
	_label(menu, "랄토스와 함께 여행할 친구를 한 마리 골라 주세요.", Rect2(279,180,740,40), 16, MUTED)
	var ids := ["purunae","hwarangi","padoring"]
	for i in range(3):
		var id: String = ids[i]
		var mon: Dictionary = GameEngine.get_species(id)
		var x := 278 + i*241
		_panel(menu, Rect2(x,245,224,330), Color("edf0e1"))
		_starter_art(menu, id, Rect2(x+15,263,194,170))
		_label(menu, mon.name, Rect2(x+15,445,194,35), 25)
		_label(menu, TYPES.get(mon.types[0],mon.types[0]) + " 타입", Rect2(x+15,487,194,25), 13, MUTED)
		_button(menu, "함께 모험하기", Rect2(x+15,530,194,34), func(): select_starter(id), "Choice_"+id, true)
	_label(menu, "스타팅 모습은 제공된 콘셉트 원본의 해당 부분을 표시합니다.", Rect2(280,610,740,35), 12, MUTED)


func select_starter(id: String) -> void:
	var result: Dictionary = GameEngine.choose_starter(state,id)
	if not result.ok:
		toast(result.message)
		return
	close_menu()
	refresh_hud()
	show_dialogue([{"speaker":"백서화", "text":result.message + " 서하린이 마을 광장에서 기다리고 있어요.", "portrait":"seohwa"}])


func start_battle(kind: String, species: String = "", trainer_id: int = -1) -> void:
	var result: Dictionary = GameEngine.start_battle(state,kind,species,trainer_id)
	if not result.ok:
		toast(result.message)
		return
	walk_path.clear()
	battle_page = "main"
	render_battle()
	refresh_hud()


func render_battle() -> void:
	battle_animation_generation += 1
	if state.battle == null:
		battle_layer.hide()
		return
	_clear(battle_layer)
	battle_layer.show()
	_panel(battle_layer, Rect2(20,100,960,640), Color("d8e5ce"))
	_panel(battle_layer, Rect2(20,100,960,225), Color("b3d0cb"))
	_panel(battle_layer, Rect2(20,557,960,183), PAPER)
	var battle: Dictionary = state.battle
	var ally: Dictionary = state.party[battle.active]
	var enemy: Dictionary = battle.enemy
	_battle_backdrop(battle_layer,battle.kind)
	var trainer_name: String = {"wild":"야생 포켓몬", "rival":"라이벌 서하린", "trainer":"1번도로 트레이너", "gym_trainer":"수원 체육관 트레이너", "gym":"수원 체육관 · 이도윤"}.get(battle.kind,"배틀")
	var enemy_order := "  ·  %d / %d" % [int(battle.get("enemyIndex",0))+1,battle.get("enemyParty",[enemy]).size()] if battle.get("enemyParty",[]).size() > 1 else ""
	_label(battle_layer, str(trainer_name)+enemy_order, Rect2(48,118,550,28), 17, INK)
	_mon_card(battle_layer,enemy,Rect2(60,175,330,93))
	_mon_card(battle_layer,ally,Rect2(600,427,340,102))
	_mon_display(battle_layer,enemy,Rect2(632,206,234,200),false)
	_mon_display(battle_layer,ally,Rect2(157,346,240,190),true)
	if battle.kind == "rival": _portrait(battle_layer,"harin",Rect2(858,125,105,250))
	var logs: Array = battle.logs
	var recent := ""
	for line in logs.slice(maxi(0,logs.size()-4)):
		recent += str(line) + "\n"
	_label(battle_layer,recent,Rect2(47,576,470,151),14,INK)
	var outcome: String = str(battle.get("outcome",""))
	if not outcome.is_empty():
		var names := {"won":"배틀에서 승리했습니다!", "caught":"새로운 동료를 만났습니다!", "escaped":"무사히 돌아왔습니다.", "lost":"동료들과 다시 준비해요."}
		_label(battle_layer,names.get(outcome,"배틀 종료"),Rect2(560,584,380,42),21)
		_button(battle_layer,"모험으로 돌아가기",Rect2(560,652,380,49),finish_battle,"BattleFinish",true)
		return
	match battle_page:
		"moves":
			for i in range(ally.moves.size()):
				var slot: Dictionary = ally.moves[i]
				var move: Dictionary = GameEngine.get_move(slot.id)
				var text := "%s · %s\nPP %d / %d" % [move.name,TYPES.get(move.type,move.type),slot.pp,slot.maxPp]
				var button := _button(battle_layer,text,Rect2(545+(i%2)*204,570+(i/2)*59,195,52),func(): perform_battle_action({"type":"move","index":i}),"BattleMove_"+str(i))
				button.disabled = slot.pp <= 0 and ally.moves.any(func(item): return item.pp > 0)
			_button(battle_layer,"← 돌아가기",Rect2(545,698,399,29),func(): battle_page="main"; render_battle())
		"switch":
			for i in range(state.party.size()):
				var mon: Dictionary = state.party[i]
				var b := _button(battle_layer,"%s  %d/%d" % [mon.name,mon.hp,mon.maxHp],Rect2(545+(i%2)*204,570+(i/2)*45,195,40),func(): perform_battle_action({"type":"switch","index":i}),"Switch_"+str(i))
				b.disabled = mon.hp <= 0 or i == battle.active
			_button(battle_layer,"← 돌아가기",Rect2(545,709,399,25),func(): battle_page="main"; render_battle())
		"bag":
			_button(battle_layer,"몬스터볼 × %d" % state.bag.balls,Rect2(545,579,195,60),func(): perform_battle_action({"type":"ball"}),"UseBall",true)
			_button(battle_layer,"상처약 × %d" % state.bag.potions,Rect2(750,579,195,60),func(): perform_battle_action({"type":"potion"}),"UsePotion")
			_button(battle_layer,"← 돌아가기",Rect2(545,658,399,45),func(): battle_page="main"; render_battle())
		_:
			_button(battle_layer,"싸운다",Rect2(545,575,195,64),func(): battle_page="moves"; render_battle(),"FightButton",true)
			_button(battle_layer,"가방",Rect2(750,575,195,64),func(): battle_page="bag"; render_battle(),"BattleBagButton")
			_button(battle_layer,"교체",Rect2(545,649,195,64),func(): battle_page="switch"; render_battle(),"BattleSwitchButton")
			_button(battle_layer,"도망",Rect2(750,649,195,64),func(): perform_battle_action({"type":"run"}),"RunButton")


func perform_battle_action(action: Dictionary) -> void:
	if state.battle == null or not str(state.battle.get("outcome","")).is_empty(): return
	var move_type := "normal"
	if action.type == "move":
		var active_index: int = int(state.battle.active)
		var move_index: int = int(action.get("index",-1))
		if active_index >= 0 and active_index < state.party.size() and move_index >= 0 and move_index < state.party[active_index].moves.size():
			move_type = str(GameEngine.get_move(state.party[active_index].moves[move_index].id).type)
	var result: Dictionary = GameEngine.battle_action(state,action)
	if not result.ok: toast(result.message)
	if action.type != "move": battle_page = "main"
	render_battle()
	if result.ok and action.type == "move" and state.battle != null and str(state.battle.get("outcome","")).is_empty():
		_play_battle_move_animation(move_type)
	refresh_hud()


func _move_effect_color(move_type: String) -> Color:
	return {
		"fire": Color("f26b44"), "water": Color("57b8e5"), "grass": Color("6abf66"),
		"electric": Color("f5ca43"), "psychic": Color("d472b6"), "fairy": Color("f0a4ca"),
		"flying": Color("91b8e9"), "bug": Color("9db84d"), "ice": Color("9be1ed"),
		"fighting": Color("d96b57"), "ground": Color("c99a60"), "rock": Color("a99a70"),
		"poison": Color("a875bd"), "ghost": Color("765d9e"), "dragon": Color("7287d6"),
		"dark": Color("755e59"), "steel": Color("aeb7c8")
	}.get(move_type, Color("e6c75d"))


func _spawn_battle_impact(effect_color: Color, token: int) -> void:
	if token != battle_animation_generation: return
	var defender := battle_layer.get_node_or_null("BattleEnemySprite") as TextureRect
	if defender == null: return
	var impact := Label.new()
	impact.name = "BattleImpact"
	impact.text = "✦"
	impact.position = defender.position + defender.size * 0.34
	impact.size = Vector2(88,88)
	impact.pivot_offset = impact.size * 0.5
	impact.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	impact.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	impact.add_theme_font_size_override("font_size",70)
	impact.add_theme_color_override("font_color",effect_color)
	impact.add_theme_color_override("font_shadow_color",Color("24342f"))
	impact.add_theme_constant_override("shadow_offset_x",2)
	impact.add_theme_constant_override("shadow_offset_y",2)
	impact.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_layer.add_child(impact)
	var defender_start := defender.position
	var effect_tween := create_tween().set_parallel(true)
	effect_tween.tween_property(impact,"scale",Vector2(1.55,1.55),0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	effect_tween.tween_property(impact,"modulate:a",0.0,0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	effect_tween.tween_property(defender,"position",defender_start+Vector2(-12,3),0.06)
	effect_tween.chain().tween_property(defender,"position",defender_start+Vector2(10,-2),0.06)
	effect_tween.chain().tween_property(defender,"position",defender_start,0.08)
	var impact_ref: WeakRef = weakref(impact)
	effect_tween.finished.connect(func():
		var finished_impact: Node = impact_ref.get_ref() as Node
		if finished_impact != null: finished_impact.queue_free()
	)


func _play_battle_move_animation(move_type: String) -> void:
	var attacker := battle_layer.get_node_or_null("BattleAllySprite") as TextureRect
	var defender := battle_layer.get_node_or_null("BattleEnemySprite") as TextureRect
	if attacker == null or defender == null: return
	var token := battle_animation_generation
	var attacker_start := attacker.position
	var lunge := Vector2(42,-14)
	var move_tween := create_tween()
	move_tween.tween_property(attacker,"position",attacker_start+lunge,0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	move_tween.tween_callback(_spawn_battle_impact.bind(_move_effect_color(move_type),token))
	move_tween.tween_property(attacker,"position",attacker_start,0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func finish_battle() -> void:
	if state.battle == null or str(state.battle.get("outcome","")).is_empty(): return
	var kind: String = state.battle.kind
	var outcome: String = state.battle.outcome
	state.battle = null
	battle_layer.hide()
	encounter_cooldown = 4
	grass_distance = 0
	refresh_hud()
	if outcome == "won" and kind == "rival":
		GameEngine.heal_party(state)
		show_dialogue([{"speaker":"서하린", "text":"좋아, 이번에는 네가 이겼어! 동료들도 회복됐으니 동쪽 1번도로로 출발하자. 다음엔 절대 안 져!", "portrait":"harin"}])
	elif outcome == "won" and kind == "gym":
		show_dialogue([{"speaker":"이도윤", "text":"훌륭한 호흡이었다. 성곽배지는 너의 것이다! 이 개발판의 첫 여정을 완주했다. 자유롭게 탐험하고 기록을 저장해 두렴."}])
	elif outcome == "won" and kind == "gym_trainer":
		show_dialogue([{"speaker":"수원 체육관", "text":"승부에서 배운 점을 기억해. 관장 구역은 세 훈련생과 문양을 모두 마쳐야 열린다. (%d/3)" % state.gymTrainerWins.size()}])


func refresh_hud() -> void:
	_clear(side)
	var info: Dictionary = Field.area_info(state.area)
	_label(side,info.name,Rect2(0,-24,260,26),15,INK)
	_panel(side,Rect2(0,0,252,183),Color("275347"))
	_label(side,"지금의 이야기",Rect2(18,17,215,25),12,GOLD)
	_label(side,GameEngine.get_objective(state),Rect2(18,53,216,105),18,PAPER)
	_label(side,"함께하는 친구들",Rect2(0,207,250,28),16)
	for i in range(mini(state.party.size(),3)):
		var mon: Dictionary = state.party[i]
		_panel(side,Rect2(0,245+i*67,252,60),PAPER)
		_label(side,"%s%s   Lv.%d" % ["✦ " if mon.get("shiny",false) else "",mon.name,mon.level],Rect2(12,250+i*67,225,23),14)
		_bar(side,Rect2(12,279+i*67,183,5),float(mon.hp)/maxf(1,mon.maxHp))
		_label(side,"%d/%d" % [mon.hp,mon.maxHp],Rect2(197,270+i*67,52,22),10,MUTED)
	if state.party.is_empty(): _label(side,"아직 동료가 없습니다.\n동쪽 숲의 작은 목소리를 찾아보세요.",Rect2(8,255,235,90),14,MUTED)
	_label(side,"배지 %d개      ₽ %s" % [state.badges.size(),str(state.money)],Rect2(0,463,252,30),16,INK)
	_button(side,"파티 / 박스",Rect2(0,512,122,42),open_party,"PartyButton")
	_button(side,"가방",Rect2(130,512,122,42),open_bag,"BagButton")
	_button(side,"여행 지도",Rect2(0,564,122,42),open_map,"MapButton")
	_button(side,"저장 / 설정",Rect2(130,564,122,42),open_save,"SaveButton")
	_label(side,"자동 경험치 공유 · ON",Rect2(0,623,252,24),11,MUTED)


func open_menu(title: String) -> void:
	if cinematic_active:
		toast("이벤트 연출이 끝난 뒤 메뉴를 열 수 있습니다.")
		return
	_clear(menu)
	menu.show()
	walk_path.clear()
	var backdrop := _panel(menu,Rect2(0,0,1280,800),Color(0.08,0.19,0.16,0.68))
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel(menu,Rect2(250,105,780,600),PAPER)
	_label(menu,title,Rect2(278,128,665,42),26)
	_button(menu,"닫기 ×",Rect2(931,125,76,37),close_menu,"CloseMenu")


func close_menu() -> void:
	menu.hide()


func _return_to_title() -> void:
	_cancel_cinematic()
	close_menu()
	active = false
	show_title()


func open_party() -> void:
	if state.battle != null:
		toast("전투 중 교체는 배틀 화면에서 선택해 주세요.")
		return
	open_menu("함께하는 친구들 · 파티 %d/6" % state.party.size())
	for i in range(state.party.size()):
		var mon: Dictionary = state.party[i]
		var y := 185+i*73
		_label(menu,"%s%s   Lv.%d  HP %d/%d" % ["특별한 이로치 " if mon.get("source","")=="incheon-rescue" else "",mon.name,mon.level,mon.hp,mon.maxHp],Rect2(280,y,535,25),16)
		var moves: Array[String] = []
		for slot in mon.moves: moves.append("%s %d/%d" % [GameEngine.get_move(slot.id).name,slot.pp,slot.maxPp])
		_label(menu," · ".join(moves),Rect2(280,y+28,600,26),11,MUTED)
		if i > 0: _button(menu,"선두로",Rect2(895,y,100,34),func(): state.party.push_front(state.party.pop_at(i)); open_party(); refresh_hud(),"Lead_"+str(i))
	_label(menu,"박스 보관: %d마리 · 자동 경험치 공유는 살아 있는 파티원에게 적용" % state.box.size(),Rect2(280,642,710,25),12,MUTED)
	_button(menu,"박스 열기",Rect2(849,663,145,29),open_box,"BoxButton")


func open_box(page: int = 0) -> void:
	if state.battle != null: return
	open_menu("포켓몬 박스")
	_label(menu,"파티가 가득 차면 포획한 포켓몬은 박스에 보관됩니다.",Rect2(280,183,710,30),14,MUTED)
	page = clampi(page, 0, maxi(0, (state.box.size() - 1) / 5))
	var y := 232
	for i in range(page * 5, mini(state.box.size(), page * 5 + 5)):
		var mon: Dictionary = state.box[i]
		_label(menu,"%s  Lv.%d" % [mon.name,mon.level],Rect2(280,y,425,30),17)
		_button(menu,"파티로 데려오기",Rect2(750,y,245,35),func():
			if state.party.size() >= 6: toast("파티에서 먼저 한 마리를 맡겨 주세요.")
			else: state.party.append(state.box.pop_at(i)); open_box(page); refresh_hud()
		,"Withdraw_"+str(i))
		y += 52
	if state.box.is_empty(): _label(menu,"박스가 비어 있습니다.",Rect2(280,240,700,45),18,MUTED)
	if page > 0: _button(menu,"← 이전",Rect2(280,478,110,30),func(): open_box(page - 1),"PreviousBoxPage")
	if (page + 1) * 5 < state.box.size(): _button(menu,"다음 →",Rect2(875,478,120,30),func(): open_box(page + 1),"NextBoxPage")
	_label(menu,"맡길 파티원 선택 (최소 한 마리는 함께 여행합니다)",Rect2(280,514,710,30),13,MUTED)
	for i in range(state.party.size()):
		_button(menu,state.party[i].name,Rect2(280+(i%3)*238,555+(i/3)*48,222,40),func():
			if state.party.size() <= 1: toast("여행을 함께할 동료 한 마리는 필요합니다.")
			else: state.box.append(state.party.pop_at(i)); open_box(page); refresh_hud()
		,"Deposit_"+str(i))


func open_bag() -> void:
	if state.battle != null: toast("전투 중에는 배틀 화면의 가방을 사용해 주세요."); return
	open_menu("여행 가방")
	_label(menu,"몬스터볼  × %d" % state.bag.balls,Rect2(285,202,650,40),24)
	_label(menu,"야생 포켓몬과의 배틀 중 사용할 수 있습니다.",Rect2(285,249,650,33),14,MUTED)
	_label(menu,"상처약  × %d" % state.bag.potions,Rect2(285,313,650,40),24)
	_label(menu,"동료의 체력을 회복합니다. 사용할 대상을 고르세요.",Rect2(285,360,650,33),14,MUTED)
	for i in range(state.party.size()):
		var mon: Dictionary = state.party[i]
		_button(menu,"%s  %d/%d" % [mon.name,mon.hp,mon.maxHp],Rect2(285+(i%3)*237,411+(i/3)*53,220,43),func():
			if state.bag.potions <= 0: toast("상처약이 없습니다.")
			elif mon.hp <= 0: toast("기절한 동료는 센터에서 회복해 주세요.")
			elif mon.hp >= mon.maxHp: toast("이미 건강한 상태입니다.")
			else: state.bag.potions -= 1; mon.hp = mini(mon.maxHp,mon.hp+40); open_bag(); refresh_hud()
		,"FieldPotion_"+str(i))
	_label(menu,"도감: 발견 %d종 · 동료로 만난 %d종" % [state.seen.size(),state.caught.size()],Rect2(285,579,670,35),17)
	_label(menu,"성곽배지: " + ("획득" if not state.badges.is_empty() else "미획득"),Rect2(285,625,670,30),16,GOLD)


func open_shop() -> void:
	open_menu("수원 여행 상점")
	_label(menu,"보유 금액  ₽ %d" % state.money,Rect2(285,192,650,40),22)
	_button(menu,"몬스터볼 구매  ·  ₽ 200",Rect2(285,280,710,63),func(): toast(GameEngine.buy_item(state,"balls").message); open_shop(); refresh_hud(),"BuyBall")
	_button(menu,"상처약 구매  ·  ₽ 300",Rect2(285,365,710,63),func(): toast(GameEngine.buy_item(state,"potions").message); open_shop(); refresh_hud(),"BuyPotion")
	_label(menu,"다음 모험을 위해 가방을 준비하세요. 센터 회복은 무료입니다.",Rect2(285,487,710,70),17,MUTED)


func open_map() -> void:
	if state.battle != null: toast("전투 중에는 이동할 수 없습니다."); return
	open_menu("여행 지도 · 방문한 도시 빠른 이동")
	_label(menu,"인천  →  1번도로  →  수원",Rect2(285,190,710,45),26)
	_label(menu,"1번도로 트레이너: %d / 5명과 승부\n도시 포켓몬센터를 방문하면 무료 빠른 이동이 등록됩니다." % state.trainerWins.size(),Rect2(285,257,710,70),16,MUTED)
	_button(menu,"인천으로 이동",Rect2(285,374,340,55),func(): fast_travel("incheon"),"TravelIncheon")
	var b := _button(menu,"수원으로 이동",Rect2(655,374,340,55),func(): fast_travel("suwon"),"TravelSuwon")
	b.disabled = not state.visited.has("suwon")
	_label(menu,"앞으로의 여정",Rect2(285,474,710,30),18,GOLD)
	_label(menu,"설악산 → 대전 → 전주 → 광주 → 대구\n→ 경주 → 부산 → 제주 → 서울",Rect2(285,520,710,90),20)
	_label(menu,"이번 개발판은 수원까지 구현되어 있습니다. 이후 지역은 아직 입장할 수 없습니다.",Rect2(285,635,710,42),12,MUTED)


func fast_travel(area: String) -> void:
	if state.battle != null or not state.visited.has(area) or not area in ["incheon","suwon"]: return
	close_menu()
	change_area(area,Vector2(7,9))


func open_save() -> void:
	if cinematic_active: toast("이벤트 연출이 끝난 뒤 저장 메뉴를 열 수 있습니다."); return
	if state.battle != null: toast("전투를 마친 뒤 저장해 주세요."); return
	open_menu("모험 기록 · 저장 / 불러오기")
	_label(menu,"이 기기에 저장",Rect2(285,193,710,30),20)
	_label(menu,"자동 저장하지 않습니다. F5 또는 저장 버튼으로 직접 기록해 주세요.",Rect2(285,236,710,50),14,MUTED)
	_button(menu,"진행 상황 저장",Rect2(285,305,340,52),save_game,"SaveLocal",true)
	_button(menu,"저장 기록 불러오기",Rect2(655,305,340,52),load_game,"LoadLocal")
	_button(menu,"파일로 내보내기",Rect2(285,381,340,52),func(): choose_save_file(false),"ExportSave")
	_button(menu,"저장 파일 가져오기",Rect2(655,381,340,52),func(): choose_save_file(true),"ImportSave")
	_label(menu,"게임 ZIP과 내보낸 JSON 파일을 카톡에 보관하면 다른 PC로 옮길 수 있습니다.\n설치 파일, 저장 파일과 회사 측 접속 기록은 서로 별개입니다.",Rect2(285,466,710,80),14,MUTED)
	_button(menu,"아트 원본 / 제작 현황",Rect2(285,573,340,44),open_art,"ArtButton")
	_button(menu,"타이틀로 돌아가기",Rect2(655,573,340,44),_return_to_title,"TitleButton")
	_label(menu,last_save,Rect2(285,646,710,28),12,GOLD)


func save_game(path: String = SAVE_PATH) -> bool:
	if cinematic_active: toast("이벤트 연출이 끝난 뒤 저장해 주세요."); return false
	if state.battle != null: toast("전투가 끝난 뒤 저장해 주세요."); return false
	var text: String = GameEngine.serialize_save(state)
	if text.is_empty(): toast("저장할 수 없는 상태입니다."); return false
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: toast("파일을 저장하지 못했습니다. 쓰기 권한과 경로를 확인해 주세요."); return false
	file.store_string(text)
	file.flush()
	if file.get_error() != OK: toast("기록 중 오류가 발생했습니다. 저장 파일을 확인해 주세요."); return false
	file.close()
	var korea_time := Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()) + 9 * 3600)
	last_save = "모험 기록 저장 완료 · " + korea_time.replace("T"," ") + " (한국 시간)"
	toast(last_save)
	return true


func load_game(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path): toast("저장된 기록이 없습니다. 먼저 새 모험을 시작해 주세요."); return false
	if FileAccess.get_file_as_bytes(path).size() > 2_000_000: toast("저장 파일이 너무 큽니다."); return false
	var result: Dictionary = GameEngine.validate_save(FileAccess.get_file_as_string(path))
	if not result.ok: toast("저장 파일을 불러오지 못했습니다: " + str(result.get("error","형식 오류"))); return false
	_cancel_cinematic()
	state = result.state
	if not Field.can_walk(state.area,state.player.x,state.player.y,_gym_open()):
		state.player.x = 14
		state.player.y = 10
	active = true
	title_layer.hide()
	menu.hide()
	dialogue_layer.hide()
	battle_layer.hide()
	walk_path.clear()
	encounter_cooldown = 4
	refresh_hud()
	toast("저장한 모험을 불러왔습니다.")
	return true


func choose_save_file(load_mode: bool) -> void:
	if cinematic_active: toast("이벤트 연출이 끝난 뒤 이용해 주세요."); return
	if state.battle != null: toast("전투가 끝난 뒤 이용해 주세요."); return
	loading_save = load_mode
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE if load_mode else FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.title = "모험 기록 가져오기" if load_mode else "모험 기록 내보내기"
	file_dialog.current_file = "천년의전설_모험기록.json"
	file_dialog.popup_centered_ratio(0.7)


func _file_selected(path: String) -> void:
	if loading_save: load_game(path)
	else: save_game(path)


func open_help() -> void:
	open_menu("모험 안내")
	_label(menu,"이동  WASD / 방향키 / 지면 클릭\n대화·조사  E / Space / Enter / 대상 클릭\n저장  F5 또는 저장 메뉴\n메뉴 닫기  Esc",Rect2(285,191,710,160),19)
	_label(menu,"첫 모험의 순서",Rect2(285,378,710,30),21,GOLD)
	_label(menu,"동쪽 숲에서 랄토스 구조 → 서쪽 연구소에서 스타팅 선택\n→ 광장의 서하린과 배틀 → 동쪽 1번도로 탐험\n→ 트레이너와 성장·야생 포켓몬 포획 → 수원 센터·체육관",Rect2(285,426,710,130),17)
	_label(menu,"필드 SD·타일은 임시 제작 그래픽입니다. 제공되지 않은 전투 스프라이트는\n이름표로 표시하며, 승인 일러스트와 설정은 별도로 보존했습니다.",Rect2(285,602,710,65),13,MUTED)


func open_art(selected: String = "gardevoir") -> void:
	open_menu("승인 일러스트 · 원본 보존")
	var entries := {"gardevoir":"메가가디안", "falinks":"대여르", "lilligant":"드레디어", "harin":"서하린", "seohwa":"백서화"}
	var index := 0
	for key in entries:
		_button(menu,entries[key],Rect2(280+index*145,181,136,33),func(): open_art(key))
		index += 1
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.texture = load("res://assets/"+selected+".webp")
	image.position = Vector2(280,228)
	image.size = Vector2(720,405)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	menu.add_child(image)
	_label(menu,"최신 개별 승인 원본 · 필드 SD와 구분 · 이미지 속 자동 생성 수치는 게임 데이터로 사용하지 않습니다.",Rect2(280,651,720,36),11,MUTED)


func toast(text: String) -> void:
	status_label.text = text
	toast_time = 7.0


func _panel(parent: Node, rect: Rect2, color: Color) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel",style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	return panel


func _label(parent: Node, text: String, rect: Rect2, size: int = 16, color: Color = INK) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font",FONT)
	label.add_theme_font_size_override("font_size",size)
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font",FONT)
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, rect: Rect2, callback: Callable, id: String = "", primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	if not id.is_empty(): button.name = id
	button.add_theme_font_override("font",FONT)
	button.add_theme_font_size_override("font_size",14)
	button.add_theme_color_override("font_color",INK)
	button.add_theme_color_override("font_hover_color",INK)
	button.add_theme_color_override("font_pressed_color",INK)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("d9bf8f") if primary else Color("e7eddd")
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	button.add_theme_stylebox_override("normal",style)
	var hover := style.duplicate()
	hover.bg_color = style.bg_color.lightened(0.08)
	button.add_theme_stylebox_override("hover",hover)
	button.add_theme_stylebox_override("pressed",style)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _bar(parent: Node, rect: Rect2, amount: float) -> void:
	_panel(parent,rect,Color("dce4d2"))
	_panel(parent,Rect2(rect.position,Vector2(rect.size.x*clampf(amount,0,1),rect.size.y)),Color("76a37c") if amount > 0.25 else Color("ca806c"))


func _portrait(parent: Node, id: String, rect: Rect2) -> void:
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var texture: Texture2D = load("res://assets/"+id+".webp")
	if id == "harin":
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(0,0,535,1295)
		image.texture = atlas
	else: image.texture = texture
	image.position = rect.position
	image.size = rect.size
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)


func _starter_art(parent: Node, id: String, rect: Rect2) -> void:
	# 합본의 자동 생성 이름·레벨 문구는 제외하고 실제 그림 부분만 표시합니다.
	var crops := {"purunae":Rect2(516,830,65,76),"hwarangi":Rect2(790,834,65,76),"padoring":Rect2(1042,835,70,72)}
	if not crops.has(id): return
	var atlas := AtlasTexture.new()
	atlas.atlas = load("res://assets/starters.webp")
	atlas.region = crops[id]
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.texture = atlas
	image.position = rect.position
	image.size = rect.size
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)


func _mon_card(parent: Node, mon: Dictionary, rect: Rect2) -> void:
	_panel(parent,rect,PAPER)
	_label(parent,"%s%s    Lv.%d" % ["✦ " if mon.get("shiny",false) else "",mon.name,mon.level],Rect2(rect.position+Vector2(14,10),Vector2(rect.size.x-20,28)),17)
	_bar(parent,Rect2(rect.position+Vector2(14,49),Vector2(rect.size.x-28,7)),float(mon.hp)/maxf(1,mon.maxHp))
	_label(parent,"HP  %d / %d%s" % [mon.hp,mon.maxHp,"   화상" if str(mon.get("status",""))=="burn" else ""],Rect2(rect.position+Vector2(14,63),Vector2(rect.size.x-20,24)),12,MUTED)


func _battle_texture(species: String, rear: bool) -> Texture2D:
	var pose := "back" if rear else "front"
	var paths := [
		"res://assets/catalog/pokemon/%s/%s.png" % [species,pose],
		"res://assets/generated/battle/%s_%s.png" % [species,pose]
	]
	for path in paths:
		if not battle_sprites.has(path) and ResourceLoader.exists(path):
			battle_sprites[path] = load(path) as Texture2D
		if battle_sprites.has(path): return battle_sprites[path] as Texture2D
	return null


func _battle_backdrop(parent: Node, kind: String) -> void:
	var path := "res://assets/generated/maps/suwon_gym_battle_bg_960.png" if kind in ["gym","gym_trainer"] else ""
	if path.is_empty() or not ResourceLoader.exists(path): return
	if not battle_backgrounds.has(path): battle_backgrounds[path] = load(path) as Texture2D
	var image := TextureRect.new()
	image.texture = battle_backgrounds[path] as Texture2D
	image.position = Vector2(20,100)
	image.size = Vector2(960,457)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.modulate = Color(1,1,1,0.9)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)


func _mon_display(parent: Node, mon: Dictionary, rect: Rect2, rear: bool = false) -> void:
	var texture := _battle_texture(str(mon.species),rear)
	if texture != null:
		var image := TextureRect.new()
		image.name = "BattleAllySprite" if rear else "BattleEnemySprite"
		image.texture = texture
		image.position = rect.position
		image.size = rect.size
		image.pivot_offset = rect.size * 0.5
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(image)
		return
	# 생성 스프라이트가 빠진 개발 환경에서도 전투 자체는 깨지지 않도록 유지하는 폴백입니다.
	_panel(parent,Rect2(rect.position+Vector2(20,35),rect.size-Vector2(40,45)),Color("ecf2df"))
	_label(parent,mon.name,Rect2(rect.position+Vector2(30,107),Vector2(rect.size.x-50,35)),24,INK)


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
