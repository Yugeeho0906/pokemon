extends SceneTree
const Field = preload("res://game/field.gd")
const Data = preload("res://game/field_data.gd")
const Encounters = preload("res://game/encounters.gd")
const Transition = preload("res://game/battle_transition.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	for area in Data.data().areas:
		var origin := Vector2i(14,17) if area == "suwon_gym" else Vector2i(14,10)
		var reachable := {origin:true}
		var queue := [origin]
		var head := 0
		while head < queue.size():
			var p: Vector2i = queue[head]
			head += 1
			for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
				var n: Vector2i = p+d
				if not reachable.has(n) and Field.can_walk(area,n.x,n.y,true):
					reachable[n] = true
					queue.append(n)
		var positions := []
		for npc in Data.npcs(area):
			var point := Vector2(npc.x,npc.y)
			check(Field.can_walk(area,point.x,point.y,true),area+" NPC 충돌: "+npc.id)
			check(not positions.has(point),"NPC 중복: "+npc.id)
			positions.append(point)
			var access := false
			for cell in reachable:
				if Vector2(cell).distance_to(point) < 1.75: access = true; break
			check(access,"NPC 대화 접근: "+npc.id)
			var found := false
			for target in Field.interactions({"area":area,"stage":"journey"}):
				if target.id == npc.id:
					found = target.x == npc.x and target.y == npc.y
			check(found,"표시/대화 좌표 일치: "+npc.id)
	check(not Field.can_walk("incheon",20,12),"서하린 이전 좌표가 강 충돌임을 재현")
	check(Data.npcs("suwon_gym").back().role == "leader","관장 healer 역할 제거")
	var e := Encounters.new()
	check(not e.debug_guaranteed,"일반 실행은 10%")
	for i in range(9): check(e.advance("route",Vector2(10,5),Vector2(10.1,5),0,func():return 0.0).is_empty(),"1타일 미만 조우 없음")
	check(not e.advance("route",Vector2(10,5),Vector2(10.2,5),0,func():return 0.0).is_empty(),"누적 1타일 조우")
	check(e.advance("route",Vector2(10,5),Vector2(11,5),0,func():return 0.11).is_empty(),"10% 확률 실패")
	e.debug_guaranteed = true
	check(not e.advance("route",Vector2(10,5),Vector2(11,5),0,func():return 0.99).is_empty(),"디버그 100%")
	check(e.advance("route",Vector2(10,10),Vector2(11,10),0).is_empty(),"일반 도로 제외")
	check(e.advance("incheon",Vector2(10,5),Vector2(11,5),0).is_empty(),"마을 제외")
	check(e.advance("route",Vector2(10,5),Vector2(11,5),4).is_empty(),"복귀 쿨다운")
	check(e.advance("route",Vector2(10,5),Vector2(10,5),0).is_empty(),"정지 중 조우 없음")
	var t := Transition.new()
	root.add_child(t)
	check(await t.cover(Transition.Kind.WILD),"야생 전환 완료")
	check(t.active and t.coverage > 0.99,"전환 중 입력 잠금 상태")
	check(not await t.cover(Transition.Kind.GYM),"중복 전환 거부")
	check(await t.reveal(),"필드/배틀 표시 복구")
	check(not t.active and not t.visible,"입력 해제")
	t.cover(Transition.Kind.TRAINER)
	t.cancel()
	await create_timer(0.4).timeout
	check(not t.active and not t.visible,"취소 후 이전 코루틴이 복구하지 않음")
	var trainers = preload("res://game/trainers.gd")
	for id in trainers.IDS:
		var art: AtlasTexture = trainers.battle_texture(id)
		check(art != null and Rect2(Vector2.ZERO,art.atlas.get_size()).encloses(art.region),"트레이너 아틀라스 경계: "+id)
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game = scene.instantiate()
	root.add_child(game)
	game.start_new_game()
	while game.dialogue_layer.visible: game.advance_dialogue()
	var engine = preload("res://game/engine.gd")
	engine.rescue_ralts(game.state)
	engine.choose_starter(game.state,"hwarangi")
	var previous: Dictionary = game.state.player.duplicate(true)
	game.start_battle("wild","pidgey")
	var first_uid: String = game.state.battle.enemy.uid
	game.start_battle("wild","caterpie")
	check(game.state.battle.enemy.uid == first_uid,"전환 도중 중복 배틀 생성 차단")
	game.perform_battle_action({"type":"move","index":0})
	check(game.state.battle.turn == 0,"전환 도중 기술 입력 차단")
	check(not game._can_move(),"전환 도중 필드 이동 차단")
	await wait_transition(game)
	check(game.battle_layer.visible and not game.transition.active,"배틀 표시 후 입력 복구")
	game.state.battle.outcome = "escaped"
	game.finish_battle()
	await wait_transition(game)
	check(game.state.battle == null and game._can_move(),"배틀 종료 후 필드 입력 복구")
	check(game.state.player == previous,"복귀 위치와 방향 유지")
	check(game.encounter_cooldown > 0,"복귀 후 조우 쿨다운 적용")
	game.start_battle("wild","pidgey")
	game.start_new_game()
	await create_timer(0.7).timeout
	check(game.state.battle == null and not game.battle_layer.visible,"새 게임 시 진행 중 전환 취소")
	game.queue_free()
	print("BETA3_TEST_RESULT checks=%d failures=%d" % [checks,failures])
	t.queue_free()
	quit(1 if failures else 0)


func wait_transition(game: Node) -> void:
	var deadline := Time.get_ticks_msec()+8000
	while game.transition.active and Time.get_ticks_msec() < deadline:
		await process_frame
