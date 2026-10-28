extends SceneTree

# 화면 연결 검증에서는 이동 거리를 줄이고 전투 상대 HP만 낮춥니다.
# 수정하지 않은 전투 수치의 완주 검증은 test_engine.gd에서 따로 수행합니다.
const Field = preload("res://game/field.gd")
const LegendEngine = preload("res://game/engine.gd")

var game: Node
var checks := 0
var failures := 0
var screenshots := 0
var artifacts := "/tmp/legend-scene-qa"
var original_save := PackedByteArray()
var had_original_save := false
var checked_save_path := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not OS.get_environment("GAME_TEST_ARTIFACTS").is_empty():
		artifacts = OS.get_environment("GAME_TEST_ARTIFACTS")
	DirAccess.make_dir_recursive_absolute(artifacts)
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		_expect(false, "메인 장면을 읽을 수 없음")
		_finish()
		return
	game = scene.instantiate()
	root.add_child(game)
	checked_save_path = ProjectSettings.globalize_path(game.SAVE_PATH)
	had_original_save = FileAccess.file_exists(checked_save_path)
	if had_original_save:
		original_save = FileAccess.get_file_as_bytes(checked_save_path)
	await process_frame
	await _capture("01-title")
	_expect(game.title_layer.visible and not game.active, "타이틀 초기 상태")
	if not _click("StartButton"):
		_finish()
		return
	_expect(game.active and game.dialogue_layer.visible, "새 모험 버튼 연결")
	_finish_dialogue()
	_expect(game.state.stage == "prologue" and game.state.party.is_empty(), "구조 이전 시작 상태")
	_test_battle_sprite_assets()
	_test_field_character_assets()
	await _capture("02-incheon")
	await _test_movement()
	_test_locked_actions()
	await _test_rescue_cancellation()
	await _test_rescue_and_starter()
	await _capture("03-starters")
	if not _click("Choice_hwarangi"):
		_finish()
		return
	_finish_dialogue()
	_expect(game.state.party.size() == 2 and game.state.starter == "hwarangi", "스타팅 선택으로 두 마리 출발")
	_interact_at("harin")
	await _capture("04-harin-dialogue")
	_finish_dialogue()
	_expect(game.state.battle != null and game.state.battle.kind == "rival", "대화 후 서하린 전투 진입")
	_expect(game.state.battle.enemy.species == "padoring", "라이벌이 유리한 스타팅 선택")
	_expect(not game.save_game(artifacts + "/forbidden-battle.json"), "전투 중 저장 금지")
	_click("MapButton")
	_expect(not game.menu.visible, "전투 중 지도 열기 차단")
	await _capture("05-rival-battle")
	await _test_battle_animation()
	_win_current_battle()
	_expect(game.state.flags.rivalWon, "서하린 승리 플래그")
	_finish_dialogue()
	_interact_at("gate")
	_expect(game.state.area == "route", "인천 출구에서 1번도로 진입")
	game.fast_travel("suwon")
	_expect(game.state.area == "route", "미방문 수원 빠른 이동 금지")
	await _capture("06-route")
	_test_wild_capture()
	_test_route_trainers()
	_interact_at("gate")
	_expect(game.state.area == "suwon", "도로 출구에서 수원 진입")
	_expect(not game.state.visited.has("suwon"), "단순 도시 진입만으로 센터 등록하지 않음")
	_interact_at("center")
	_finish_dialogue()
	_expect(game.state.visited.has("suwon"), "센터 방문으로 빠른 이동 등록")
	for mon in game.state.party:
		_expect(mon.hp == mon.maxHp, "센터에서 파티 회복")
	await _capture("07-suwon")
	_test_shop_and_box()
	await _test_gym_sequence()
	_expect(game.state.stage == "complete" and game.state.badges == ["성곽배지"], "첫 체육관 완주 배지 지급")
	_test_save_load()
	_test_fast_travel()
	await _capture("09-travel-map")
	_expect(not _visible_text(game).contains("흑월단 수장") and not _visible_text(game).contains("왕실 후예"), "초반 화면에 후반 반전 노출 없음")
	_click("CloseMenu")
	await _test_guardian_battle_art()
	await _test_special_form_battle_art()
	_click("SaveButton")
	await _capture("10-save-menu")
	_finish()


func _expect(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
	return condition


func _click(id: String) -> bool:
	var button: Button = game.find_child(id, true, false) as Button
	if not _expect(button != null, "버튼 존재: " + id):
		return false
	if not _expect(button.is_visible_in_tree() and not button.disabled, "버튼 사용 가능: " + id):
		return false
	button.pressed.emit()
	return true


func _finish_dialogue() -> void:
	var count := 0
	while game.dialogue_layer.visible and count < 16:
		if not _click("DialogueNext"):
			break
		count += 1
	_expect(not game.dialogue_layer.visible, "대화 종료와 후속 이벤트 연결")


func _interact_at(id: String) -> void:
	for point in Field.interactions(game.state):
		if point.id == id:
			game.state.player.x = point.x
			game.state.player.y = point.y
			game.interact(id)
			return
	_expect(false, "상호작용 지점 존재: " + id)


func _test_battle_sprite_assets() -> void:
	var species := ["ralts","purunae","hwarangi","padoring","pidgey","caterpie","pidgeotto","pidgeot","purusori","ulchangryeong","bulhoryeong","jinhwarang","mulgyeoldari","haeryushin","kirlia","gardevoir","metapod","butterfree","cheonhwagu","cheonhwarin","wolhwarok","cheonghaeryong","geumnyeonhwa","wolhaeryeong","ninetales_korean","arcanine_korean","bronzong_korean","lilligant_korean","noctowl_korean","rapidash_korean","chimecho_korean","absol_korean","lucario_korean","falinks_korean","decidueye_korean","milotic_korean","mega_ulchangryeong","mega_jinhwarang","mega_haeryushin","mega_cheonhwagu","mega_gardevoir_korean_shiny"]
	for id in species:
		_expect(ResourceLoader.exists("res://assets/generated/battle/%s_front.png" % id), "전투 앞면 스프라이트: "+id)
		_expect(ResourceLoader.exists("res://assets/generated/battle/%s_back.png" % id), "전투 뒷면 스프라이트: "+id)


func _test_field_character_assets() -> void:
	var expected := ["player", "harin", "seohwa", "seol_yuna", "yun_seorin", "moon_si_yeon", "hae_nari", "erika", "reina", "kaien", "shiori", "se_arin", "ren_kaito", "karen_yuzuhwa", "shin_tsukasa"]
	for id in expected:
		var texture: Texture2D = game.field.actor_sheets.get(id)
		_expect(texture != null, "필드 캐릭터 아틀라스 로딩: " + id)
		if texture != null:
			_expect(texture.get_width() == 192 and texture.get_height() == 144, "필드 캐릭터 4×3 48px 규격: " + id)


func _test_movement() -> void:
	var initial_x: float = game.state.player.x
	var press_key := InputEventKey.new()
	press_key.keycode = KEY_D
	press_key.physical_keycode = KEY_D
	press_key.pressed = true
	Input.parse_input_event(press_key)
	await process_frame
	await create_timer(0.12).timeout
	var release_key := InputEventKey.new()
	release_key.keycode = KEY_D
	release_key.physical_keycode = KEY_D
	release_key.pressed = false
	Input.parse_input_event(release_key)
	await process_frame
	_expect(game.state.player.x > initial_x, "D 키 입력으로 실제 프레임 이동")
	game.state.player.x = 17.95
	game.state.player.y = 6.0
	game._move(Vector2(0.2, 0))
	_expect(is_equal_approx(game.state.player.x, 17.95), "강물 충돌로 진입 차단")
	game.state.player.x = 4.3
	game.state.player.y = 5.0
	game._move(Vector2(0.3, 0))
	_expect(is_equal_approx(game.state.player.x, 4.3), "연구소 벽 충돌")
	game.state.player.x = 14.0
	game.state.player.y = 14.0
	game.set_destination(Vector2(23, 5))
	_expect(not game.walk_path.is_empty(), "클릭 이동 경로 탐색")
	for cell in game.walk_path:
		_expect(Field.can_walk(game.state.area, cell.x, cell.y), "클릭 경로가 충돌 영역을 통과하지 않음")
	game.walk_path.clear()
	game.auto_interaction = ""


func _test_locked_actions() -> void:
	game.interact("ralts")
	_expect(not game.dialogue_layer.visible and game.state.party.is_empty(), "멀리서 구조 상호작용 불가")
	_interact_at("gate")
	_expect(game.state.area == "incheon", "프롤로그 중 도로 진입 차단")
	_interact_at("lab")
	_finish_dialogue()
	_expect(game.state.party.is_empty() and not game.menu.visible, "구조 이전 스타팅 선택 차단")


func _test_rescue_cancellation() -> void:
	_interact_at("ralts")
	_expect(game.cinematic_active and game.dialogue_layer.visible, "랄토스 컷신이 활성화된 상태")
	game.open_save()
	_expect(not game.menu.visible, "컷신 중 저장 메뉴 차단")
	var reset_path := artifacts + "/cancel-rescue.json"
	var file := FileAccess.open(reset_path, FileAccess.WRITE)
	file.store_string(LegendEngine.serialize_save(LegendEngine.create_game()))
	file.close()
	_expect(game.load_game(reset_path), "컷신 중 불러오기가 연출을 정리하고 저장 상태 복원")
	_expect(not game.cinematic_active and game.field.cinematic_mode.is_empty() and game.field.scale == Vector2.ONE and game.field.position == Vector2.ZERO, "불러오기에서 컷신 임시 상태 원복")
	# 이전 코루틴이 기다리던 전역 dialogue_closed 신호를 새 대화로 발생시켜도 재개되지 않아야 합니다.
	game.show_dialogue([{"speaker":"회귀 검사", "text":"이전 컷신을 다시 시작하지 않습니다."}])
	_finish_dialogue()
	await process_frame
	_expect(game.state.stage == "prologue" and game.state.party.is_empty() and not game.cinematic_active, "무효화된 구조 코루틴이 새 저장 상태를 변경하지 않음")


func _wait_dialogue_open() -> void:
	for frame in range(1200):
		if game.dialogue_layer.visible: return
		await process_frame
	_expect(game.dialogue_layer.visible, "비동기 이벤트 다음 대화 표시")


func _test_rescue_and_starter() -> void:
	_interact_at("ralts")
	_expect(game.dialogue_layer.visible, "랄토스 구조 대화 시작")
	_finish_dialogue()
	await _wait_dialogue_open()
	await _capture("02a-ralts-traces")
	_finish_dialogue()
	await _wait_dialogue_open()
	await _capture("02b-ralts-rescue")
	_finish_dialogue()
	await game.rescue_event_finished
	_expect(game.state.stage == "rescued" and game.state.party.size() == 1, "구조 이벤트 상태 반영")
	_expect(game.state.party[0].shiny and game.state.party[0].source == "incheon-rescue", "특별한 이로치 랄토스 출처")
	_finish_dialogue()
	_interact_at("lab")
	_finish_dialogue()
	_expect(game.menu.visible, "연구소 대화에서 스타팅 메뉴 연결")
	for id in ["purunae", "hwarangi", "padoring"]:
		_expect(game.find_child("Choice_" + id, true, false) is Button, "세 스타팅 선택지: " + id)


func _win_current_battle() -> void:
	# UI 배선 검증을 위한 전투 단축이며 밸런스 테스트가 아닙니다.
	for enemy in game.state.battle.get("enemyParty", [game.state.battle.enemy]): enemy.hp = 1
	seed(42)
	_click("FightButton")
	var attempts := 0
	while game.state.battle != null and game.state.battle.outcome == "" and attempts < 12:
		_click("BattleMove_0")
		attempts += 1
	_expect(game.state.battle.outcome == "won", "기술 버튼에서 승리 처리")
	_click("BattleFinish")
	_expect(game.state.battle == null and not game.battle_layer.visible, "전투 종료 후 필드 복귀")


func _test_battle_animation() -> void:
	game.state.battle.enemy.maxHp = 999
	game.state.battle.enemy.hp = 999
	_click("FightButton")
	_click("BattleMove_0")
	await create_timer(0.15).timeout
	_expect(game.find_child("BattleImpact", true, false) != null, "기술 사용 시 타입별 타격 이펙트 표시")
	await _capture("05b-battle-impact")
	await create_timer(0.55).timeout
	_expect(game.find_child("BattleImpact", true, false) == null, "타격 이펙트가 종료 후 정리")
	game.battle_page = "main"
	game.render_battle()


func _test_gym_sequence() -> void:
	_interact_at("gym")
	for frame in range(8):
		if game.field.tile_map_layer.visible or game.field.map_backdrop.visible: break
		await process_frame
	_expect(game.state.area == "suwon_gym" and (game.field.tile_map_layer.visible or game.field.map_backdrop.visible), "수원 실내 픽셀맵 진입")
	await _capture("08-gym-interior")
	for index in range(3):
		_interact_at("gym_trainer%d" % index)
		_finish_dialogue()
		_expect(game.state.battle != null and game.state.battle.kind == "gym_trainer", "체육관 훈련생 전투 시작")
		_win_current_battle()
		_finish_dialogue()
	for plate in ["sun", "mountain", "water"]:
		_interact_at("gym_plate_"+plate)
		_finish_dialogue()
	_expect(game.state.gymPuzzleSolved and game.state.gymTrainerWins.size() == 3, "체육관 문양·훈련생 조건 완료")
	_interact_at("gym_leader")
	_finish_dialogue()
	_expect(game.state.battle != null and game.state.battle.enemyParty.size() == 3 and game.state.battle.enemy.species == "pidgey", "관장전 3마리 연속 파티 시작")
	await _capture("08-gym-battle")
	_win_current_battle()
	_finish_dialogue()
	_expect(game.state.area == "suwon_gym" and game.state.stage == "complete" and game.state.badges == ["성곽배지"], "관장 승리 및 배지 반영")


func _test_guardian_battle_art() -> void:
	if game.menu.visible:
		_click("CloseMenu")
	var start := LegendEngine.start_battle(game.state, "wild", "pidgey")
	_expect(start.ok, "수호자 스프라이트 테스트용 전투 시작")
	if not start.ok: return
	var active_index: int = int(game.state.battle.active)
	var original_lead: Dictionary = game.state.party[active_index].duplicate(true)
	var guardian_lead: Dictionary = original_lead.duplicate(true)
	var ally_data: Dictionary = LegendEngine.get_species("cheonhwagu")
	guardian_lead.species = "cheonhwagu"
	guardian_lead.name = ally_data.name
	guardian_lead.moves = []
	for move_id in ally_data.moves:
		guardian_lead.moves.append({"id": move_id, "pp": int(LegendEngine.get_move(move_id).pp), "maxPp": int(LegendEngine.get_move(move_id).pp)})
	game.state.party[active_index] = guardian_lead
	var enemy: Dictionary = game.state.battle.enemy
	enemy.species = "wolhaeryeong"
	enemy.name = LegendEngine.get_species("wolhaeryeong").name
	game.state.battle.enemy = enemy
	game.state.battle.enemyParty[0] = enemy
	game.render_battle()
	var ally_sprite := game.find_child("BattleAllySprite", true, false) as TextureRect
	var enemy_sprite := game.find_child("BattleEnemySprite", true, false) as TextureRect
	_expect(ally_sprite != null and ally_sprite.texture != null, "천화구 후면 스프라이트 렌더")
	_expect(enemy_sprite != null and enemy_sprite.texture != null, "월해령 전면 스프라이트 렌더")
	await _capture("11-guardian-battle")
	game.state.party[active_index] = original_lead
	game.state.battle = null
	game.render_battle()
	game.refresh_hud()


func _test_special_form_battle_art() -> void:
	var start := LegendEngine.start_battle(game.state, "wild", "pidgey")
	_expect(start.ok, "특수 폼 스프라이트 테스트용 전투 시작")
	if not start.ok: return
	var active_index: int = int(game.state.battle.active)
	var original_lead: Dictionary = game.state.party[active_index].duplicate(true)
	var regional_lead: Dictionary = original_lead.duplicate(true)
	var regional_data: Dictionary = LegendEngine.get_species("lilligant_korean")
	regional_lead.species = "lilligant_korean"
	regional_lead.name = regional_data.name
	regional_lead.moves = []
	for move_id in regional_data.moves:
		regional_lead.moves.append({"id": move_id, "pp": int(LegendEngine.get_move(move_id).pp), "maxPp": int(LegendEngine.get_move(move_id).pp)})
	game.state.party[active_index] = regional_lead
	var enemy: Dictionary = game.state.battle.enemy
	enemy.species = "mega_gardevoir_korean_shiny"
	enemy.name = LegendEngine.get_species("mega_gardevoir_korean_shiny").name
	game.state.battle.enemy = enemy
	game.state.battle.enemyParty[0] = enemy
	game.render_battle()
	var ally_sprite := game.find_child("BattleAllySprite", true, false) as TextureRect
	var enemy_sprite := game.find_child("BattleEnemySprite", true, false) as TextureRect
	_expect(ally_sprite != null and ally_sprite.texture != null, "드레디어 한국폼 후면 스프라이트 렌더")
	_expect(enemy_sprite != null and enemy_sprite.texture != null, "특수 이로치 메가가디안 전면 스프라이트 렌더")
	await _capture("12-special-forms-battle")
	game.state.party[active_index] = original_lead
	game.state.battle = null
	game.render_battle()
	game.refresh_hud()


func _test_wild_capture() -> void:
	game.state.player.x = 8.4
	game.state.player.y = 6.0
	game.grass_distance = 5.4
	game.encounter_cooldown = 0
	game._move(Vector2(0.2, 0))
	_expect(game.state.battle != null and game.state.battle.kind == "wild", "풀숲 실제 이동으로 야생 조우")
	var before: int = game.state.bag.balls
	game.state.battle.enemy.hp = 1
	seed(42)
	var attempts := 0
	while game.state.battle.outcome == "" and attempts < 5:
		_click("BattleBagButton")
		_click("UseBall")
		attempts += 1
	_expect(game.state.battle.outcome == "caught", "가방 몬스터볼 버튼으로 포획")
	_expect(game.state.bag.balls < before and game.state.party.size() == 3, "포획 아이템 소모와 동료 추가")
	_click("BattleFinish")
	_expect(game.state.flags.firstCapture, "첫 포획 기록")


func _test_route_trainers() -> void:
	for index in range(5):
		_interact_at("healer")
		_finish_dialogue()
		_interact_at("trainer%d" % index)
		_finish_dialogue()
		_expect(game.state.battle != null and game.state.battle.trainerId == index, "도로 트레이너 대화 연결 %d" % index)
		_win_current_battle()
	_expect(game.state.trainerWins.size() == 5, "다섯 트레이너 격파 저장")
	var before: int = game.state.bag.potions
	_interact_at("item")
	_expect(game.state.flags.routeItem and game.state.bag.potions == before + 3, "샛길 보상 한 번 지급")
	game.interact("item")
	_expect(game.state.bag.potions == before + 3, "샛길 보상 중복 차단")


func _test_shop_and_box() -> void:
	_interact_at("shop")
	var money: int = game.state.money
	var balls: int = game.state.bag.balls
	_click("BuyBall")
	_expect(game.state.money == money - 200 and game.state.bag.balls == balls + 1, "상점 버튼 결제와 상품 지급")
	_click("CloseMenu")
	_click("PartyButton")
	_click("BoxButton")
	_click("Deposit_2")
	_expect(game.state.party.size() == 2 and game.state.box.size() == 1, "원격 박스 맡기기 버튼")
	_click("Withdraw_0")
	_expect(game.state.party.size() == 3 and game.state.box.is_empty(), "박스에서 파티로 데려오기")
	_click("CloseMenu")


func _test_save_load() -> void:
	_click("SaveButton")
	_click("SaveLocal")
	_expect(FileAccess.file_exists(game.SAVE_PATH), "로컬 저장 버튼으로 실제 파일 작성")
	var expected_money: int = game.state.money
	game.state.money = 0
	_click("LoadLocal")
	_expect(game.state.money == expected_money and game.state.stage == "complete", "로컬 불러오기 버튼으로 복원")
	_click("SaveButton")
	_click("ExportSave")
	_expect(game.file_dialog.visible and not game.loading_save, "내보내기 파일 선택창")
	var path := artifacts + "/scene-export.json"
	game.file_dialog.file_selected.emit(path)
	game.file_dialog.hide()
	_expect(FileAccess.file_exists(path), "파일 선택 신호로 JSON 내보내기")
	game.state.money = 0
	_click("ImportSave")
	_expect(game.file_dialog.visible and game.loading_save, "가져오기 파일 선택창")
	game.file_dialog.file_selected.emit(path)
	game.file_dialog.hide()
	_expect(game.state.money == expected_money and game.state.trainerWins.size() == 5 and game.state.badges.size() == 1, "내보낸 파일 가져오기 상태 보존")
	var corrupted := artifacts + "/corrupted.json"
	var file := FileAccess.open(corrupted, FileAccess.WRITE)
	file.store_string("{invalid}")
	file.close()
	var before: String = JSON.stringify(game.state)
	_expect(not game.load_game(corrupted), "손상된 저장 파일 거부")
	_expect(JSON.stringify(game.state) == before, "손상된 저장 불러오기가 현재 진행 보존")


func _test_fast_travel() -> void:
	_click("MapButton")
	_click("TravelIncheon")
	_expect(game.state.area == "incheon", "방문한 인천 무료 빠른 이동")
	var money: int = game.state.money
	_click("MapButton")
	_click("TravelSuwon")
	_expect(game.state.area == "suwon" and game.state.money == money, "등록한 수원 무료 빠른 이동")
	game.fast_travel("seoul")
	_expect(game.state.area == "suwon", "미구현 서울 빠른 이동 차단")
	_click("MapButton")


func _visible_text(node: Node) -> String:
	var text := ""
	if node is Label and node.is_visible_in_tree():
		text += node.text + "\n"
	for child in node.get_children():
		text += _visible_text(child)
	return text


func _capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	_expect(not image.is_empty() and image.get_width() >= 960, "렌더링된 장면: " + name)
	var result := image.save_png(artifacts + "/" + name + ".png")
	_expect(result == OK, "장면 스크린샷 저장: " + name)
	screenshots += 1


func _finish() -> void:
	# 테스트가 개발자의 실제 모험 기록을 덮어쓴 채로 끝나지 않도록 복원합니다.
	if not checked_save_path.is_empty():
		if had_original_save:
			var file := FileAccess.open(checked_save_path, FileAccess.WRITE)
			if file != null:
				file.store_buffer(original_save)
				file.close()
			else:
				_expect(false, "기존 저장 기록 복원")
		elif FileAccess.file_exists(checked_save_path):
			_expect(DirAccess.remove_absolute(checked_save_path) == OK, "테스트 저장 기록 정리")
	print("SCENE_TEST_RESULT checks=%d failures=%d screenshots=%d" % [checks, failures, screenshots])
	print("NOTE: UI flow battles use enemy HP=1; unchanged-stat progression is tested separately.")
	quit(0 if failures == 0 else 1)
