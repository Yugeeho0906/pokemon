extends SceneTree

const GameEngine = preload("res://game/engine.gd")

var checks := 0
var failures := 0
var groups := 0


func _initialize() -> void:
	_run("프롤로그와 두 마리 출발", test_progression)
	_run("서하린의 상성 우위 스타팅", test_rival_starter)
	_run("18타입 데이터와 피죤투 이름", test_data)
	_run("한국 전설 수호자 6종 도감 데이터", test_guardian_catalog)
	_run("한국 리전폼 12종과 신규 메가진화 5종", test_special_form_catalog)
	_run("5명 트레이너와 재대결", test_trainers)
	_run("전투 HP와 PP", test_move)
	_run("불법 행동은 상태를 바꾸지 않음", test_invalid_actions)
	_run("모든 PP 소진 시 발버둥", test_struggle)
	_run("포획 성공과 실패", test_capture)
	_run("파티 여섯 마리 이후 박스", test_box)
	_run("트레이너 포획 및 도주 금지", test_trainer_restrictions)
	_run("상처약과 교체", test_potion_and_switch)
	_run("기절 자동 교체", test_faint_switch)
	_run("전멸 후 재도전", test_defeat)
	_run("승리 보상과 중복 배지 방지", test_rewards)
	_run("참여 100%, 대기 50%, 기절과 박스 0%", test_experience_share)
	_run("동일 레벨 다수 참여 경험치", test_multiple_participants)
	_run("센터와 상점", test_heal_and_shop)
	_run("저장 왕복과 고유 랄토스 출처", test_save_roundtrip)
	_run("손상된 저장 거부", test_bad_saves)
	_run("전투 중 저장 금지", test_battle_save)
	_run("현재 목표의 단계별 변화", test_objective)
	_run("세 스타팅의 정상 첫 체육관 진행", test_normal_progression)
	_run("수원 체육관 3인 훈련과 문양 퍼즐", test_gym_puzzle_and_trainers)
	_run("진화와 박스 이동 후 고유 출처 저장", test_evolution_and_box_save)
	_run("일회성 도로 아이템 저장 유지", test_pickup_save)
	print("ENGINE_TEST_RESULT groups=%d checks=%d failures=%d" % [groups, checks, failures])
	quit(0 if failures == 0 else 1)


func _run(label: String, action: Callable) -> void:
	groups += 1
	var before := failures
	action.call()
	print("%s %s" % ["PASS" if failures == before else "FAIL", label])


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _rng_zero() -> float:
	return 0.0


func _rng_middle() -> float:
	return 0.5


func _rng_high() -> float:
	return 0.99


func _journey(starter: String = "hwarangi") -> Dictionary:
	var state: Dictionary = GameEngine.create_game()
	GameEngine.rescue_ralts(state)
	GameEngine.choose_starter(state, starter)
	return state


func _won_rival(starter: String = "hwarangi") -> Dictionary:
	var state := _journey(starter)
	GameEngine.start_battle(state, "rival")
	state.battle.enemy.hp = 1
	GameEngine.battle_action(state, {"type": "move", "index": 0}, _rng_middle)
	state.battle = null
	GameEngine.heal_party(state)
	return state


func _caught_state() -> Dictionary:
	var state := _won_rival()
	GameEngine.start_battle(state, "wild", "pidgey")
	GameEngine.battle_action(state, {"type": "ball"}, _rng_zero)
	state.battle = null
	return state


func test_progression() -> void:
	var state: Dictionary = GameEngine.create_game()
	_expect(not GameEngine.choose_starter(state, "hwarangi").ok, "구조 이전 스타팅 선택 허용")
	_expect(not GameEngine.start_battle(state, "wild").ok, "여행 이전 전투 허용")
	_expect(GameEngine.rescue_ralts(state).ok, "랄토스 구조 실패")
	_expect(state.party.size() == 1 and state.party[0].species == "ralts", "첫 동료가 랄토스가 아님")
	_expect(state.party[0].shiny == true, "특별 랄토스가 이로치가 아님")
	_expect(not str(state.party[0].get("source", "")).is_empty(), "랄토스 고유 출처 누락")
	_expect(not GameEngine.rescue_ralts(state).ok, "랄토스 중복 구조 허용")
	_expect(not GameEngine.choose_starter(state, "pidgey").ok, "임의 스타팅 허용")
	_expect(GameEngine.choose_starter(state, "purunae").ok, "스타팅 선택 실패")
	_expect(state.party.size() == 2 and state.party[1].species == "purunae", "두 마리로 출발하지 않음")
	_expect(not GameEngine.choose_starter(state, "padoring").ok, "스타팅 중복 선택 허용")


func test_rival_starter() -> void:
	var advantage := {"purunae": "hwarangi", "hwarangi": "padoring", "padoring": "purunae"}
	for starter in advantage:
		var state := _journey(starter)
		_expect(GameEngine.start_battle(state, "rival").ok, "서하린 전투 시작 실패")
		_expect(state.battle.enemy.species == advantage[starter], "서하린이 유리한 스타팅을 고르지 않음")
		state.battle.enemy.hp = 1
		GameEngine.battle_action(state, {"type": "move", "index": 0}, _rng_middle)
		_expect(state.battle.outcome == "won" and state.flags.rivalWon, "서하린 승리 기록 누락")


func test_guardian_catalog() -> void:
	var expected := {
		"cheonhwagu": ["fairy", "dark"], "cheonhwarin": ["fairy", "flying"],
		"wolhwarok": ["grass", "fairy"], "cheonghaeryong": ["water", "dragon"],
		"geumnyeonhwa": ["ground", "fairy"], "wolhaeryeong": ["ghost", "water"]
	}
	for id in expected:
		var guardian: Dictionary = GameEngine.get_species(id)
		_expect(not guardian.is_empty(), "%s 수호자 데이터 누락" % id)
		_expect(guardian.get("types", []) == expected[id], "%s 타입이 기획서와 다름" % id)
		_expect(bool(guardian.get("storyOnly", false)), "%s가 이후 지역 스토리 전용으로 표시되지 않음" % id)
		_expect(guardian.get("moves", []).size() == 4, "%s의 수호자 기술 4개 누락" % id)


func test_special_form_catalog() -> void:
	var regional := {
		"ninetales_korean": ["ghost", "fairy"], "arcanine_korean": ["fire", "rock"],
		"bronzong_korean": ["steel", "ghost"], "lilligant_korean": ["grass", "fairy"],
		"noctowl_korean": ["psychic", "flying"], "rapidash_korean": ["water", "fairy"],
		"chimecho_korean": ["psychic", "fairy"], "absol_korean": ["dark", "ice"],
		"lucario_korean": ["fighting", "steel"], "falinks_korean": ["fighting", "steel"],
		"decidueye_korean": ["grass", "ghost"], "milotic_korean": ["water", "dragon"]
	}
	var megas := {
		"mega_ulchangryeong": ["grass", "fairy"], "mega_jinhwarang": ["fire", "fighting"],
		"mega_haeryushin": ["water", "dragon"], "mega_cheonhwagu": ["fairy", "dark"],
		"mega_gardevoir_korean_shiny": ["psychic", "fairy"]
	}
	for id in regional:
		var form: Dictionary = GameEngine.get_species(id)
		_expect(not form.is_empty(), "%s 리전폼 데이터 누락" % id)
		_expect(form.get("types", []) == regional[id], "%s 리전폼 타입 불일치" % id)
		_expect(form.get("formKind", "") == "korean-regional" and bool(form.get("storyOnly", false)), "%s 리전폼 잠금 메타데이터 누락" % id)
		_expect(form.get("assetStatus", "") == "ready", "%s 리전폼 스프라이트 준비 상태 오류" % id)
	for id in megas:
		var mega: Dictionary = GameEngine.get_species(id)
		_expect(not mega.is_empty(), "%s 메가진화 데이터 누락" % id)
		_expect(mega.get("types", []) == megas[id], "%s 메가진화 타입 불일치" % id)
		_expect(mega.get("formKind", "") == "mega" and bool(mega.get("requiresMega", false)), "%s 메가진화 조건 메타데이터 누락" % id)
		_expect(bool(mega.get("storyOnly", false)) and mega.get("assetStatus", "") == "ready", "%s 메가진화 스프라이트 준비 상태 오류" % id)
	_expect(bool(GameEngine.get_species("mega_gardevoir_korean_shiny").get("requiresShiny", false)), "특수 이로치 메가가디안의 이로치 조건 누락")


func test_data() -> void:
	_expect(GameEngine.get_species("pidgeot").name == "피죤투", "피죤투와 피죤 명칭 오류")
	_expect(GameEngine.get_move("ember").type == "fire", "불꽃세례 타입 오류")
	_expect(GameEngine.get_move("confusion").type == "psychic", "염동력 타입 오류")
	_expect(GameEngine.all_species().size() >= 7, "기본 포켓몬 데이터 누락")


func test_trainers() -> void:
	var state := _won_rival()
	var levels := [7, 9, 11, 13, 14]
	for trainer_id in range(5):
		_expect(GameEngine.start_battle(state, "trainer", "", trainer_id).ok, "도로 트레이너 시작 실패")
		_expect(int(state.battle.enemy.level) == levels[trainer_id], "트레이너 레벨 계획 불일치")
		state.battle.enemy.hp = 1
		GameEngine.battle_action(state, {"type": "move", "index": 0}, _rng_middle)
		_expect(state.trainerWins.has(trainer_id), "트레이너 격파 기록 누락")
		state.battle = null
		GameEngine.heal_party(state)
	_expect(state.trainerWins.size() == 5, "다섯 명의 기록이 저장되지 않음")
	_expect(GameEngine.start_battle(state, "trainer", "", 0).ok, "트레이너 재대결 불가")
	state.battle.enemy.hp = 1
	GameEngine.battle_action(state, {"type": "move", "index": 0}, _rng_middle)
	_expect(state.trainerWins.size() == 5, "트레이너 재대결 기록 중복")


func test_move() -> void:
	var state := _won_rival()
	GameEngine.start_battle(state, "wild", "pidgey")
	var pp := int(state.party[0].moves[0].pp)
	_expect(not GameEngine.start_battle(state, "wild").ok, "동시에 두 전투 시작")
	var result: Dictionary = GameEngine.battle_action(state, {"type": "move", "index": 0}, _rng_middle)
	_expect(result.ok, "기술 실행 실패")
	_expect(state.party[0].moves[0].pp == pp - 1, "PP 소모 누락")
	_expect(state.battle.enemy.hp < state.battle.enemy.maxHp, "상대 피해 누락")
	_expect(state.battle.turn == 1, "턴 증가 오류")


func test_invalid_actions() -> void:
	var state := _won_rival()
	GameEngine.start_battle(state, "wild", "pidgey")
	state.party[0].moves[0].pp = 0
	var original := JSON.stringify(state)
	for action in [{"type": "move", "index": 0}, {"type": "move", "index": 99}, {"type": "switch", "index": 0}, {"type": "switch", "index": 99}, {"type": "missing"}]:
		_expect(not GameEngine.battle_action(state, action).ok, "잘못된 행동 허용")
		_expect(JSON.stringify(state) == original, "잘못된 행동이 상태나 턴을 변경")


func test_struggle() -> void:
	var state := _won_rival()
	GameEngine.start_battle(state, "wild", "pidgey")
	for move in state.party[0].moves:
		move.pp = 0
	var result: Dictionary = GameEngine.battle_action(state, {"type": "move", "index": 0}, _rng_middle)
	_expect(result.ok, "발버둥 사용 불가")
	_expect(str(result.logs).contains("발버둥"), "발버둥 기록 누락")
	_expect(state.party[0].hp < state.party[0].maxHp, "발버둥 반동 누락")


func test_capture() -> void:
	var state := _won_rival()
	GameEngine.start_battle(state, "wild", "pidgey")
	var balls := int(state.bag.balls)
	GameEngine.battle_action(state, {"type": "ball"}, _rng_high)
	_expect(state.bag.balls == balls - 1, "실패한 포획에 볼이 소모되지 않음")
	_expect(str(state.battle.outcome).is_empty(), "높은 난수로 전 체력 포획 성공")
	GameEngine.battle_action(state, {"type": "ball"}, _rng_zero)
	_expect(state.battle.outcome == "caught", "포획 성공 처리 실패")
	_expect(state.party.size() == 3 and state.flags.firstCapture, "포획 동료 또는 플래그 누락")
	_expect(state.caught.has("pidgey") and state.seen.has("pidgey"), "도감 기록 누락")
	_expect(not GameEngine.battle_action(state, {"type": "move", "index": 0}).ok, "종료된 전투에서 행동")


func test_box() -> void:
	var state := _won_rival()
	for index in range(5):
		state.steps += 1
		GameEngine.start_battle(state, "wild", "pidgey" if index % 2 == 0 else "caterpie")
		GameEngine.battle_action(state, {"type": "ball"}, _rng_zero)
		state.battle = null
	_expect(state.party.size() == 6 and state.box.size() == 1, "여섯 마리 이후 박스 이동 실패")
	_expect(GameEngine.validate_save(GameEngine.serialize_save(state)).ok, "박스 포함 저장 왕복 실패")


func test_trainer_restrictions() -> void:
	for kind in ["rival", "trainer", "gym"]:
		var state := _caught_state()
		GameEngine.start_battle(state, kind, "", 0)
		var original := JSON.stringify(state)
		_expect(not GameEngine.battle_action(state, {"type": "ball"}).ok, "트레이너 포획 허용")
		_expect(not GameEngine.battle_action(state, {"type": "run"}).ok, "트레이너 도주 허용")
		_expect(JSON.stringify(state) == original, "트레이너 불법 행동에 자원 소모")


func test_potion_and_switch() -> void:
	var state := _won_rival()
	GameEngine.start_battle(state, "wild", "pidgey")
	_expect(not GameEngine.battle_action(state, {"type": "potion"}).ok, "전 체력 상처약 사용")
	state.party[0].hp = 5
	var potions := int(state.bag.potions)
	GameEngine.battle_action(state, {"type": "potion"}, _rng_middle)
	_expect(state.bag.potions == potions - 1, "상처약 미소모")
	_expect(state.party[0].hp > 5 and state.party[0].hp <= state.party[0].maxHp, "회복량 오류")
	GameEngine.battle_action(state, {"type": "switch", "index": 1}, _rng_middle)
	_expect(state.battle.active == 1, "교체 실패")
	_expect(state.battle.participants.has(0) and state.battle.participants.has(1), "교체 참여자 누락")


func test_faint_switch() -> void:
	var state := _caught_state()
	GameEngine.start_battle(state, "gym")
	state.party[0].hp = 1
	var pp := int(state.party[1].moves[0].pp)
	GameEngine.battle_action(state, {"type": "move", "index": 0}, _rng_middle)
	_expect(state.party[0].hp == 0, "기절 처리 실패")
	_expect(state.battle.active == 1, "자동 교체 실패")
	_expect(state.party[1].moves[0].pp == pp, "이전 포켓몬의 명령이 새 동료에 적용됨")


func test_defeat() -> void:
	var state := _caught_state()
	state.area = "suwon"
	GameEngine.start_battle(state, "gym")
	for mon in state.party:
		mon.hp = 0
	state.party[0].hp = 1
	GameEngine.battle_action(state, {"type": "move", "index": 0}, _rng_middle)
	_expect(state.battle.outcome == "lost", "패배 결과 누락")
	for mon in state.party:
		_expect(mon.hp == mon.maxHp, "패배 후 회복 누락")
	state.battle = null
	_expect(GameEngine.start_battle(state, "gym").ok, "패배 후 재도전 불가")


func test_rewards() -> void:
	var state := _caught_state()
	var money := int(state.money)
	for index in range(2):
		GameEngine.start_battle(state, "gym")
		_expect(state.battle.enemyParty.size() == 3, "체육관 관장 3마리 파티 누락")
		_expect(state.battle.enemyParty.map(func(mon): return int(mon.level)) == [12,14,16], "관장 파티 레벨 계획 불일치")
		_defeat_all_enemies(state)
		_expect(state.battle.outcome == "won", "체육관 승리 실패")
		state.battle = null
		GameEngine.heal_party(state)
	_expect(state.badges.size() == 1 and state.badges[0] == "성곽배지", "배지 누락 또는 중복")
	_expect(state.flags.gymWon and state.stage == "complete", "첫 구간 완료 기록 누락")
	_expect(state.money > money, "승리 보상 누락")
	_expect(GameEngine.validate_save(GameEngine.serialize_save(state)).ok, "체육관 완료 저장 검증 실패")


func test_gym_puzzle_and_trainers() -> void:
	var state := _caught_state()
	state.area = "suwon_gym"
	_expect(not GameEngine.gym_leader_unlocked(state), "체육관 사전 조건 없이 관장 구역 개방")
	_expect(GameEngine.record_gym_plate(state,"sun").ok and state.gymPuzzleStep == 1, "해 문양 첫 단계 실패")
	_expect(not GameEngine.record_gym_plate(state,"water").ok and state.gymPuzzleStep == 0, "순서가 틀린 문양 입력을 거부하지 않음")
	for plate in ["sun", "mountain", "water"]:
		_expect(GameEngine.record_gym_plate(state,plate).ok, "해→산→물 문양 순서 입력 실패: "+plate)
	_expect(state.gymPuzzleSolved and state.gymPuzzleStep == 3, "문양 퍼즐 완료 상태 누락")
	for trainer_id in range(3):
		_expect(GameEngine.start_battle(state,"gym_trainer","",trainer_id).ok, "체육관 트레이너 전투 시작 실패")
		_defeat_all_enemies(state)
		_expect(state.battle.outcome == "won" and state.gymTrainerWins.has(trainer_id), "체육관 트레이너 승리 기록 누락")
		state.battle = null
		GameEngine.heal_party(state)
	_expect(GameEngine.gym_leader_unlocked(state), "세 전투와 퍼즐 해결 뒤 관장 구역 미개방")
	_expect(GameEngine.validate_save(GameEngine.serialize_save(state)).ok, "체육관 진행 저장 왕복 실패")


func test_experience_share() -> void:
	var state := _caught_state()
	# 같은 종·같은 레벨 동료를 복제하여 타입별 성장 차이 없이 비율을 검증한다.
	var participant: Dictionary = state.party[0].duplicate(true)
	participant.level = 50
	participant.xp = 0
	participant.hp = 100
	participant.maxHp = 100
	var waiting := participant.duplicate(true)
	var fainted := participant.duplicate(true)
	fainted.hp = 0
	var boxed := participant.duplicate(true)
	state.party = [participant, waiting, fainted]
	state.box = [boxed]
	GameEngine.start_battle(state, "wild", "pidgey")
	state.battle.enemy.hp = 1
	GameEngine.battle_action(state, {"type": "move", "index": 0}, _rng_middle)
	_expect(state.party[0].xp > 0, "참여 경험치 미지급")
	_expect(int(state.party[1].xp) == int(floor(float(state.party[0].xp) / 2.0)), "미참여 경험치 50% 불일치")
	_expect(state.party[2].xp == 0, "기절 포켓몬에게 경험치 지급")
	_expect(state.box[0].xp == 0, "박스 포켓몬에게 경험치 지급")


func test_multiple_participants() -> void:
	var state := _caught_state()
	var participant: Dictionary = state.party[0].duplicate(true)
	participant.level = 50
	participant.xp = 0
	participant.hp = 100
	participant.maxHp = 100
	state.party = [participant, participant.duplicate(true), participant.duplicate(true)]
	GameEngine.start_battle(state, "wild", "pidgey")
	GameEngine.battle_action(state, {"type": "switch", "index": 1}, _rng_middle)
	state.battle.enemy.hp = 1
	GameEngine.battle_action(state, {"type": "move", "index": 0}, _rng_middle)
	_expect(state.party[0].xp > 0 and state.party[0].xp == state.party[1].xp, "여러 참여자가 기준 경험치를 각각 받지 못함")
	_expect(int(state.party[2].xp) == int(floor(float(state.party[1].xp) / 2.0)), "미참여 동료 경험치 불일치")


func test_heal_and_shop() -> void:
	var state := _won_rival()
	state.party[0].hp = 0
	state.party[0].moves[0].pp = 0
	state.party[0].status = "burn"
	_expect(GameEngine.heal_party(state).ok, "센터 회복 실패")
	_expect(state.party[0].hp == state.party[0].maxHp and state.party[0].moves[0].pp == state.party[0].moves[0].maxPp, "센터 HP/PP 미회복")
	_expect(state.party[0].status == null or state.party[0].status == "", "상태이상 미회복")
	var before := int(state.bag.balls)
	_expect(GameEngine.buy_item(state, "balls").ok, "몬스터볼 구입 실패")
	_expect(state.bag.balls == before + 1, "구매 아이템 미지급")
	_expect(not GameEngine.buy_item(state, "missing").ok, "없는 아이템 구매 허용")
	state.money = 0
	_expect(not GameEngine.buy_item(state, "potions").ok, "잔액 부족 구매 허용")
	GameEngine.start_battle(state, "wild")
	_expect(not GameEngine.heal_party(state).ok, "전투 중 센터 사용")
	_expect(not GameEngine.buy_item(state, "balls").ok, "전투 중 상점 사용")


func test_save_roundtrip() -> void:
	for state in [GameEngine.create_game(), _journey(), _caught_state()]:
		var serialized: String = GameEngine.serialize_save(state)
		_expect(not serialized.is_empty(), "저장 문자열 생성 실패")
		var result: Dictionary = GameEngine.validate_save(serialized)
		_expect(result.ok, "저장 왕복 검증 실패: " + str(result.get("error", "")))
		if not result.ok:
			continue
		_expect(result.state.party.size() == state.party.size(), "저장 왕복 동료 수 변경")
		_expect(result.state.visited == state.visited, "방문 기록 미보존")
		_expect(result.state.difficulty == state.difficulty, "난이도 미보존")
		if not state.party.is_empty():
			_expect(result.state.party[0].source == state.party[0].source, "랄토스 고유 출처 미보존")
		result.state.bag.balls = 0
		_expect(state.bag.balls != 0, "검증 결과가 원본 상태와 참조 공유")


func test_bad_saves() -> void:
	_expect(not GameEngine.validate_save("{broken").ok, "손상 JSON 허용")
	_expect(not GameEngine.validate_save({}).ok, "빈 저장 허용")
	var changes := [
		func(s: Dictionary) -> void: s.version = 99,
		func(s: Dictionary) -> void: s.area = "unknown",
		func(s: Dictionary) -> void: s.player.x = -500,
		func(s: Dictionary) -> void: s.party[0].species = "missing",
		func(s: Dictionary) -> void: s.party[0].hp = 99999,
		func(s: Dictionary) -> void: s.party[0].moves[0].pp = -1,
		func(s: Dictionary) -> void: s.party[0].moves[0].id = "missing",
		func(s: Dictionary) -> void: s.party[0].source = "ordinary",
		func(s: Dictionary) -> void: s.bag.balls = -1,
		func(s: Dictionary) -> void: s.money = -1,
		func(s: Dictionary) -> void: s.flags.rescued = false,
		func(s: Dictionary) -> void: s.stage = "complete",
		func(s: Dictionary) -> void: s.difficulty = "impossible",
		func(s: Dictionary) -> void: s.visited.append("seoul"),
		func(s: Dictionary) -> void: s.flags.routeItem = "true",
		func(s: Dictionary) -> void: s.starter = "purunae",
		func(s: Dictionary) -> void: s.party[0].source = "wild",
		func(s: Dictionary) -> void: s.party[0].level = 3.5,
		func(s: Dictionary) -> void: s.bag.potions = 1.5,
	]
	for change in changes:
		var state := _caught_state()
		change.call(state)
		_expect(not GameEngine.validate_save(state).ok, "손상된 필드 허용: " + str(change))


func test_battle_save() -> void:
	var state := _won_rival()
	GameEngine.start_battle(state, "wild")
	_expect(GameEngine.serialize_save(state).is_empty(), "전투 중 저장 허용")
	_expect(not GameEngine.validate_save(state).ok, "진행 중 전투가 저장 파일에 포함됨")


func test_objective() -> void:
	var state: Dictionary = GameEngine.create_game()
	_expect(GameEngine.get_objective(state).contains("랄토스"), "프롤로그 목표 오류")
	GameEngine.rescue_ralts(state)
	_expect(GameEngine.get_objective(state).contains("연구소"), "구조 후 목표 오류")
	GameEngine.choose_starter(state, "padoring")
	_expect(GameEngine.get_objective(state).contains("서하린"), "스타팅 후 라이벌 목표 누락")


func _defeat_all_enemies(state: Dictionary) -> void:
	for enemy in state.battle.get("enemyParty", [state.battle.enemy]):
		enemy.hp = 1
	var turns := 0
	while state.battle.outcome == "" and turns < 12:
		GameEngine.battle_action(state, {"type":"move", "index":0}, _rng_middle)
		turns += 1


func _play_battle(state: Dictionary) -> void:
	for turn in range(100):
		if not str(state.battle.outcome).is_empty():
			return
		var active: Dictionary = state.party[int(state.battle.active)]
		var action := {"type": "move", "index": 0}
		if active.hp < active.maxHp * 0.45 and state.bag.potions > 0:
			action = {"type": "potion"}
		else:
			var best_score := -1.0
			for index in range(active.moves.size()):
				var slot: Dictionary = active.moves[index]
				var move: Dictionary = GameEngine.get_move(slot.id)
				var score: float = float(move.power) * GameEngine._effectiveness(move.type, state.battle.enemy)
				if GameEngine.get_species(active.species).types.has(move.type):
					score *= 1.5
				if slot.pp > 0 and score > best_score:
					best_score = score
					action.index = index
		GameEngine.battle_action(state, action, _rng_middle)


func test_normal_progression() -> void:
	for starter in ["purunae", "hwarangi", "padoring"]:
		var state := _journey(starter)
		GameEngine.start_battle(state, "rival")
		_play_battle(state)
		_expect(state.battle.outcome == "won", starter + " 라이벌 정상 전투 패배")
		if state.battle.outcome != "won":
			continue
		state.battle = null
		GameEngine.heal_party(state)
		for trainer_id in range(5):
			GameEngine.start_battle(state, "trainer", "", trainer_id)
			_play_battle(state)
			_expect(state.battle.outcome == "won", "%s 트레이너 %d 정상 전투 패배" % [starter, trainer_id])
			state.battle = null
			GameEngine.heal_party(state)
			GameEngine.start_battle(state, "wild", "caterpie" if trainer_id % 2 == 0 else "pidgey")
			_play_battle(state)
			state.battle = null
			GameEngine.heal_party(state)
		var lead_level := int(state.party[0].level)
		print("BALANCE %s before gym levels=%s" % [starter, str(state.party.map(func(mon: Dictionary) -> int: return int(mon.level)))])
		_expect(lead_level >= 14 and lead_level <= 16, starter + " 일반 탐험 시 선두 레벨이 14~16 밖임")
		# 도로에서 번 돈으로 상점을 이용하는 정상 준비 과정도 검증한다.
		while state.bag.potions < 5 and state.money >= 300:
			_expect(GameEngine.buy_item(state, "potions").ok, starter + " 체육관 준비용 상처약 구매 실패")
		GameEngine.start_battle(state, "gym")
		_play_battle(state)
		if state.battle.outcome != "won":
			print("GYM_DIAGNOSTIC %s potions=%s logs=%s" % [starter, state.bag.potions, state.battle.logs])
		_expect(state.battle.outcome == "won", starter + " 첫 체육관 정상 전투 패배")
		state.battle = null
		_expect(GameEngine.validate_save(GameEngine.serialize_save(state)).ok, starter + " 정상 완료 후 저장 왕복 실패")


func test_evolution_and_box_save() -> void:
	var state := _caught_state()
	var ralts: Dictionary = state.party[0]
	ralts.level = 19
	ralts.xp = 379
	ralts.maxHp = int(GameEngine.get_species("ralts").hp) + 19 * 3
	ralts.hp = ralts.maxHp
	GameEngine.start_battle(state, "wild", "caterpie")
	state.battle.enemy.hp = 1
	GameEngine.battle_action(state, {"type":"move", "index":0}, _rng_middle)
	_expect(ralts.species == "kirlia" and ralts.level == 20, "랄토스 Lv20 진화 누락")
	_expect(ralts.source == "incheon-rescue" and ralts.shiny, "진화 후 특별 출처 변경")
	state.battle = null
	state.box.append(state.party.pop_at(0))
	var result: Dictionary = GameEngine.validate_save(GameEngine.serialize_save(state))
	_expect(result.ok, "랄토스 계열을 박스로 옮긴 뒤 저장 실패")
	if result.ok:
		_expect(result.state.box[0].source == "incheon-rescue", "박스 저장에서 고유 출처 누락")
	var starter: Dictionary = state.party[0]
	starter.level = 15
	starter.xp = 299
	starter.maxHp = int(GameEngine.get_species(starter.species).hp) + 15 * 3
	starter.hp = starter.maxHp
	GameEngine.start_battle(state, "wild", "caterpie")
	state.battle.enemy.hp = 1
	GameEngine.battle_action(state, {"type":"move", "index":0}, _rng_middle)
	_expect(starter.species == "bulhoryeong", "스타팅 Lv16 진화 누락")
	state.battle = null
	_expect(GameEngine.validate_save(GameEngine.serialize_save(state)).ok, "스타팅 진화 후 저장 실패")


func test_pickup_save() -> void:
	var state := _won_rival()
	state.flags.routeItem = true
	state.bag.potions += 3
	var result: Dictionary = GameEngine.validate_save(GameEngine.serialize_save(state))
	_expect(result.ok and result.state.flags.routeItem, "일회성 아이템 획득 기록이 저장에서 유실됨")
