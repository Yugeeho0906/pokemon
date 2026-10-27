class_name LegendEngine
extends RefCounted

# 게임 화면과 분리한 첫 체육관 진행·전투·저장 로직. 밸런스 수치는 개발안이다.
const SAVE_VERSION := 2
const STARTERS := ["purunae", "hwarangi", "padoring"]
const STARTER_LINES := ["purunae", "purusori", "ulchangryeong", "hwarangi", "bulhoryeong", "jinhwarang", "padoring", "mulgyeoldari", "haeryushin"]
const RALTS_LINE := ["ralts", "kirlia", "gardevoir"]
const TRAINER_LEVELS := [7, 9, 11, 13, 14]
const TRAINER_SPECIES := ["caterpie", "pidgey", "butterfree", "pidgeotto", "pidgeotto"]
const BADGE := "성곽배지"
const MAX_LEVEL := 100
const MAX_BOX := 3000
static var _db: Dictionary = {}
static var _uid_sequence: int = 0

static func data() -> Dictionary:
	if _db.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://game/data.json"))
		if parsed is Dictionary:
			_db = parsed
	return _db

static func get_species(id: String) -> Dictionary:
	return data().get("species", {}).get(id, {})

static func get_move(id: String) -> Dictionary:
	return data().get("moves", {}).get(id, {})

static func all_species() -> Dictionary:
	return data().get("species", {})

static func create_game() -> Dictionary:
	return {
		"version": SAVE_VERSION, "stage": "prologue", "area": "incheon",
		"player": {"x": 14, "y": 14, "facing": "down"},
		"party": [], "box": [], "bag": {"balls": 12, "potions": 8},
		"money": 1500, "badges": [], "seen": [], "caught": [],
		"flags": {"rescued": false, "starterChosen": false, "firstCapture": false, "gymWon": false, "rivalWon": false, "routeItem": false},
		"steps": 0, "battle": null, "starter": "", "trainerWins": [],
		"visited": ["incheon"], "difficulty": "normal"
	}

static func _make_creature(species: String, level: int, source: String = "") -> Dictionary:
	_uid_sequence += 1
	var entry: Dictionary = get_species(species)
	var moves: Array = []
	for id in entry.moves:
		moves.append({"id": id, "pp": int(get_move(id).pp), "maxPp": int(get_move(id).pp)})
	var hp: int = int(entry.hp) + level * 3
	return {
		"uid": "%s-%d-%d" % [species, Time.get_unix_time_from_system() * 1000, _uid_sequence],
		"species": species, "name": entry.name, "level": level, "hp": hp, "maxHp": hp,
		"moves": moves, "xp": 0, "status": null, "shiny": source == "incheon-rescue", "source": source
	}

static func _ok(message: String, logs: Array = []) -> Dictionary:
	return {"ok": true, "message": message, "logs": logs if not logs.is_empty() else [message]}

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "message": message, "logs": [message]}

static func _add_unique(values: Array, value: Variant) -> void:
	if not values.has(value):
		values.append(value)

static func rescue_ralts(state: Dictionary) -> Dictionary:
	if state.stage != "prologue" or state.battle != null:
		return _fail("랄토스는 이미 안전해졌어요.")
	state.party.append(_make_creature("ralts", 5, "incheon-rescue"))
	state.stage = "rescued"
	state.flags.rescued = true
	_add_unique(state.seen, "ralts")
	_add_unique(state.caught, "ralts")
	return _ok("특별한 이로치 랄토스를 구조했습니다! 다음 날 백서화 연구소를 찾아가세요.")

static func choose_starter(state: Dictionary, species: String) -> Dictionary:
	if state.stage != "rescued" or state.battle != null:
		return _fail("먼저 랄토스를 구조하고 연구소를 찾아가세요.")
	if not STARTERS.has(species):
		return _fail("세 스타팅 중 한 마리를 선택해 주세요.")
	state.party.append(_make_creature(species, 5, "starter"))
	state.stage = "journey"
	state.starter = species
	state.flags.starterChosen = true
	_add_unique(state.seen, species)
	_add_unique(state.caught, species)
	return _ok("%s가 동료가 되었습니다! 랄토스와 함께 두 마리로 출발해요." % get_species(species).name)

static func start_battle(state: Dictionary, kind: String, species: String = "", trainer_id: int = -1) -> Dictionary:
	if state.battle != null:
		return _fail("진행 중인 전투를 먼저 마쳐 주세요.")
	if not state.flags.starterChosen:
		return _fail("연구소에서 스타팅을 선택한 뒤 모험을 시작해요.")
	if not ["wild", "rival", "trainer", "gym"].has(kind):
		return _fail("시작할 수 없는 전투입니다.")
	var active: int = _first_alive(state.party)
	if active < 0:
		return _fail("센터에서 동료들을 회복해 주세요.")
	var selected := species
	var level := 5
	var greeting := ""
	match kind:
		"wild":
			if selected == "":
				selected = "pidgey" if state.steps % 2 == 0 else "caterpie"
			if not ["pidgey", "caterpie"].has(selected):
				return _fail("이 지역에서 만날 수 없는 포켓몬입니다.")
			level = clampi(5 + state.trainerWins.size(), 5, 10)
			greeting = "야생 %s가 나타났다!" % get_species(selected).name
		"rival":
			selected = {"purunae": "hwarangi", "hwarangi": "padoring", "padoring": "purunae"}[state.starter]
			level = 6
			greeting = "서하린이 %s를 내보냈다!" % get_species(selected).name
		"trainer":
			if trainer_id < 0 or trainer_id >= 5:
				return _fail("존재하지 않는 트레이너입니다.")
			selected = TRAINER_SPECIES[trainer_id]
			level = TRAINER_LEVELS[trainer_id]
			greeting = "1번도로 트레이너 %d가 %s를 내보냈다!" % [trainer_id + 1, get_species(selected).name]
		"gym":
			selected = "pidgeot"
			level = 16
			greeting = "수원 체육관 관장 이도윤이 피죤투를 내보냈다!"
	if kind != "wild":
		level += {"easy": -2, "normal": 0, "hard": 2}.get(state.difficulty, 0)
	var enemy: Dictionary = _make_creature(selected, maxi(2, level))
	_add_unique(state.seen, selected)
	state.battle = {
		"kind": kind, "enemy": enemy, "active": active, "turn": 0, "logs": [greeting],
		"outcome": "", "trainerId": trainer_id, "participants": [active], "rewards": [],
		"stages": {"player": {"attack": 0, "defense": 0, "speed": 0}, "enemy": {"attack": 0, "defense": 0, "speed": 0}}
	}
	return _ok(greeting)

static func _first_alive(party: Array) -> int:
	for index in range(party.size()):
		if party[index].hp > 0:
			return index
	return -1

static func _roll(rng: Callable) -> float:
	if rng.is_valid():
		return clampf(float(rng.call()), 0.0, 0.999999)
	return randf()

static func _stage_multiplier(value: int) -> float:
	return (2.0 + value) / 2.0 if value >= 0 else 2.0 / (2.0 - value)

static func _stat(mon: Dictionary, key: String, stages: Dictionary) -> float:
	var paralysis: float = 0.5 if key == "speed" and mon.status == "paralysis" else 1.0
	return (float(get_species(mon.species)[key]) + mon.level) * _stage_multiplier(stages[key]) * paralysis

static func _effectiveness(move_type: String, defender: Dictionary) -> float:
	var value := 1.0
	for target in get_species(defender.species).types:
		value *= float(data().typeChart[move_type].get(target, 1))
	return value

static func _attack(state: Dictionary, is_player: bool, move_id: String, rng: Callable, logs: Array) -> void:
	var battle: Dictionary = state.battle
	var player: Dictionary = state.party[battle.active]
	var attacker: Dictionary = player if is_player else battle.enemy
	var defender: Dictionary = battle.enemy if is_player else player
	var own_stages: Dictionary = battle.stages.player if is_player else battle.stages.enemy
	var target_stages: Dictionary = battle.stages.enemy if is_player else battle.stages.player
	if attacker.hp <= 0 or defender.hp <= 0:
		return
	var move: Dictionary = get_move(move_id)
	if attacker.status == "paralysis" and _roll(rng) < 0.25:
		logs.append("%s는 마비되어 움직일 수 없다!" % attacker.name)
		return
	if move_id != "struggle":
		for slot in attacker.moves:
			if slot.id == move_id:
				slot.pp -= 1
				break
	logs.append("%s의 %s!" % [attacker.name, move.name])
	if _roll(rng) >= move.accuracy:
		logs.append("공격이 빗나갔다!")
		return
	if move.category == "status":
		var key: String = {"attackDown": "attack", "defenseDown": "defense", "speedDown": "speed"}.get(move.get("effect", ""), "")
		if key == "":
			return
		if target_stages[key] <= -6:
			logs.append("능력은 더 내려가지 않는다.")
		else:
			target_stages[key] = maxi(-6, target_stages[key] - (2 if key == "speed" else 1))
			logs.append("%s의 %s 능력이 내려갔다." % [defender.name, {"attack": "공격", "defense": "방어", "speed": "스피드"}[key]])
		return
	var effectiveness: float = 1.0 if move_id == "struggle" else _effectiveness(move.type, defender)
	if effectiveness == 0:
		logs.append("%s에게는 효과가 없다!" % defender.name)
		return
	var stab: float = 1.5 if get_species(attacker.species).types.has(move.type) and move_id != "struggle" else 1.0
	var burn: float = 0.5 if attacker.status == "burn" and move.category == "physical" else 1.0
	var attack_stages: Dictionary = own_stages.duplicate()
	var defense_stages: Dictionary = target_stages.duplicate()
	if move.category != "physical":
		attack_stages.attack = 0
		defense_stages.defense = 0
	var base: float = (2.0 * attacker.level / 5.0 + 2.0) * move.power * _stat(attacker, "attack", attack_stages) / _stat(defender, "defense", defense_stages) / 50.0 + 2.0
	var damage: int = maxi(1, floori(base * effectiveness * stab * burn * (0.85 + 0.15 * _roll(rng))))
	defender.hp = maxi(0, defender.hp - damage)
	logs.append("%s에게 %d의 데미지!" % [defender.name, damage])
	if effectiveness > 1:
		logs.append("효과가 굉장했다!")
	elif effectiveness < 1:
		logs.append("효과가 별로인 듯하다…")
	if move.get("effect") == "burn" and defender.hp > 0 and defender.status == null and not get_species(defender.species).types.has("fire") and _roll(rng) < 0.1:
		defender.status = "burn"
		logs.append("%s는 화상을 입었다!" % defender.name)
	if move.get("effect") == "recoil":
		attacker.hp = maxi(0, attacker.hp - maxi(1, int(attacker.maxHp / 4)))
		logs.append("%s는 반동을 받았다." % attacker.name)

static func _give_experience(state: Dictionary, logs: Array) -> void:
	var battle: Dictionary = state.battle
	var base: int = battle.enemy.level * (12 if battle.kind == "wild" else 24)
	for index in range(state.party.size()):
		var mon: Dictionary = state.party[index]
		if mon.hp <= 0:
			continue
		var participated: bool = battle.participants.has(index)
		var scaling: float = clampf((float(battle.enemy.level) + 5.0) / (float(mon.level) + 5.0), 0.35, 1.5)
		var amount: int = maxi(1, floori(base * scaling * (1.0 if participated else 0.5)))
		battle.rewards.append({"uid": mon.uid, "amount": amount, "participated": participated})
		mon.xp += amount
		logs.append("%s는 경험치를 %d 얻었다." % [mon.name, amount])
		while mon.level < MAX_LEVEL and mon.xp >= mon.level * 20:
			mon.xp -= mon.level * 20
			mon.level += 1
			mon.maxHp += 3
			mon.hp += 3
			logs.append("%s의 레벨이 %d이 되었다!" % [mon.name, mon.level])
			_evolve(state, mon, logs)
		if mon.level == MAX_LEVEL:
			mon.xp = 0

static func _evolve(state: Dictionary, mon: Dictionary, logs: Array) -> void:
	var species: Dictionary = get_species(mon.species)
	if not species.has("evolvesTo") or mon.level < species.evolvesAt:
		return
	var old_name: String = mon.name
	mon.species = species.evolvesTo
	var evolved: Dictionary = get_species(mon.species)
	mon.name = evolved.name
	var max_hp: int = int(evolved.hp) + mon.level * 3
	mon.hp += maxi(0, max_hp - mon.maxHp)
	mon.maxHp = max_hp
	_add_unique(state.seen, mon.species)
	_add_unique(state.caught, mon.species)
	logs.append("축하합니다! %s는 %s로 진화했습니다!" % [old_name, mon.name])

static func _finish_if_needed(state: Dictionary, logs: Array) -> bool:
	var battle: Dictionary = state.battle
	if battle.enemy.hp <= 0:
		battle.outcome = "won"
		logs.append("%s는 쓰러졌다! 전투에서 승리했다." % battle.enemy.name)
		_give_experience(state, logs)
		state.money = mini(999999, state.money + (600 if battle.kind == "gym" else 160 if battle.kind != "wild" else 80))
		match battle.kind:
			"gym":
				_add_unique(state.badges, BADGE)
				state.flags.gymWon = true
				state.stage = "complete"
				logs.append("이도윤에게 성곽배지를 받았다! 첫 번째 여정을 마쳤다.")
			"rival":
				state.flags.rivalWon = true
				logs.append("서하린: 다음에는 내가 이길 거야! 수원에서 다시 만나자.")
			"trainer":
				_add_unique(state.trainerWins, battle.trainerId)
		return true
	var player: Dictionary = state.party[battle.active]
	if player.hp > 0:
		return false
	logs.append("%s는 쓰러졌다!" % player.name)
	var next: int = _first_alive(state.party)
	if next >= 0:
		battle.active = next
		_add_unique(battle.participants, next)
		battle.stages.player = {"attack": 0, "defense": 0, "speed": 0}
		logs.append("%s, 부탁해!" % state.party[next].name)
		return false
	battle.outcome = "lost"
	_restore_party(state)
	state.area = "suwon" if state.area == "suwon" else "incheon"
	state.player = {"x": 7, "y": 9, "facing": "down"}
	logs.append("센터에서 동료들을 회복했다. 준비해서 다시 도전하자!")
	return true

static func _enemy_move(state: Dictionary, rng: Callable) -> String:
	var moves: Array = []
	var attacks: Array = []
	for slot in state.battle.enemy.moves:
		if slot.pp > 0:
			moves.append(slot.id)
			if get_move(slot.id).power > 0:
				attacks.append(slot.id)
	if moves.is_empty():
		return "struggle"
	if state.difficulty == "hard" and not attacks.is_empty():
		var best: String = attacks[0]
		var best_score := -1.0
		for id in attacks:
			var move: Dictionary = get_move(id)
			var score: float = move.power * _effectiveness(move.type, state.party[state.battle.active])
			if score > best_score:
				best = id
				best_score = score
		return best
	var chance: float = 0.6 if state.difficulty == "easy" else 0.85
	var pool: Array = attacks if not attacks.is_empty() and _roll(rng) < chance else moves
	return pool[mini(pool.size() - 1, int(_roll(rng) * pool.size()))]

static func _status_damage(state: Dictionary, logs: Array) -> void:
	for mon in [state.party[state.battle.active], state.battle.enemy]:
		if mon.hp <= 0 or not ["burn", "poison"].has(mon.status):
			continue
		var amount: int = maxi(1, int(mon.maxHp / (16 if mon.status == "burn" else 8)))
		mon.hp = maxi(0, mon.hp - amount)
		logs.append("%s는 %s으로 %d의 데미지를 받았다." % [mon.name, "화상" if mon.status == "burn" else "독", amount])

static func battle_action(state: Dictionary, action: Dictionary, rng: Callable = Callable()) -> Dictionary:
	if state.battle == null or state.battle.outcome != "":
		return _fail("현재 행동할 수 있는 전투가 없습니다.")
	var battle: Dictionary = state.battle
	var player: Dictionary = state.party[battle.active]
	var action_type: String = str(action.get("type", ""))
	var move_id := ""
	if action_type in ["move", "switch"] and not _integer(action.get("index"), 0, 100):
		return _fail("올바른 기술 또는 동료를 선택해 주세요.")
	var index: int = int(action.get("index", -1))
	match action_type:
		"move":
			var has_pp := false
			for slot in player.moves:
				if slot.pp > 0:
					has_pp = true
			if not has_pp:
				move_id = "struggle"
			elif index < 0 or index >= player.moves.size() or player.moves[index].pp <= 0:
				return _fail("사용할 기술이 없거나 PP가 부족해요.")
			else:
				move_id = player.moves[index].id
		"ball":
			if battle.kind != "wild":
				return _fail("다른 트레이너의 포켓몬은 잡을 수 없어요.")
			if state.bag.balls < 1:
				return _fail("몬스터볼이 없어요. 상점에서 구입해 주세요.")
			if state.party.size() >= 6 and state.box.size() >= MAX_BOX:
				return _fail("박스가 가득 찼어요.")
		"potion":
			if state.bag.potions < 1:
				return _fail("상처약이 없어요.")
			if player.hp >= player.maxHp:
				return _fail("체력이 이미 가득 차 있어요.")
		"switch":
			if index < 0 or index >= state.party.size() or index == battle.active or state.party[index].hp <= 0:
				return _fail("교체할 수 있는 다른 동료를 선택해 주세요.")
		"run":
			if battle.kind != "wild":
				return _fail("트레이너 전투에서는 도망칠 수 없어요.")
		_:
			return _fail("알 수 없는 행동입니다.")
	var logs: Array = []
	battle.turn += 1
	match action_type:
		"ball":
			state.bag.balls -= 1
			logs.append("몬스터볼을 던졌다!")
			var chance: float = minf(0.95, 0.22 + 0.65 * (1.0 - float(battle.enemy.hp) / battle.enemy.maxHp) + (0.12 if battle.enemy.status != null else 0.0))
			if _roll(rng) < chance:
				var caught: Dictionary = battle.enemy.duplicate(true)
				caught.source = "wild"
				var in_box: bool = state.party.size() >= 6
				if in_box:
					state.box.append(caught)
				else:
					state.party.append(caught)
				_add_unique(state.caught, caught.species)
				state.flags.firstCapture = true
				battle.outcome = "caught"
				logs.append("%s를 잡았다! %s" % [caught.name, "박스로 보냈다." if in_box else "동료가 되었다."])
			else:
				logs.append("아쉽다! 몬스터볼에서 빠져나왔다.")
		"potion":
			state.bag.potions -= 1
			var restored: int = mini(40, player.maxHp - player.hp)
			player.hp += restored
			logs.append("상처약으로 %s의 체력을 %d 회복했다." % [player.name, restored])
		"switch":
			battle.active = index
			_add_unique(battle.participants, index)
			battle.stages.player = {"attack": 0, "defense": 0, "speed": 0}
			logs.append("%s, 부탁해!" % state.party[index].name)
		"run":
			if _roll(rng) < 0.85:
				battle.outcome = "escaped"
				logs.append("무사히 도망쳤다!")
			else:
				logs.append("도망칠 수 없었다!")
	if battle.outcome == "":
		var foe_move: String = _enemy_move(state, rng)
		if move_id != "":
			var own_priority: int = int(get_move(move_id).get("priority", 0))
			var foe_priority: int = int(get_move(foe_move).get("priority", 0))
			var first: bool = own_priority > foe_priority if own_priority != foe_priority else _stat(player, "speed", battle.stages.player) >= _stat(battle.enemy, "speed", battle.stages.enemy)
			var initial_active: int = battle.active
			_attack(state, first, move_id if first else foe_move, rng, logs)
			if not _finish_if_needed(state, logs) and battle.active == initial_active:
				_attack(state, not first, foe_move if first else move_id, rng, logs)
				_finish_if_needed(state, logs)
		else:
			_attack(state, false, foe_move, rng, logs)
			_finish_if_needed(state, logs)
		if battle.outcome == "":
			_status_damage(state, logs)
			_finish_if_needed(state, logs)
	battle.logs.append_array(logs)
	if battle.logs.size() > 80:
		battle.logs = battle.logs.slice(-80)
	return _ok(str(logs.back()) if not logs.is_empty() else "다음 행동을 선택해 주세요.", logs)

static func _restore_party(state: Dictionary) -> void:
	for mon in state.party:
		mon.hp = mon.maxHp
		mon.status = null
		for move in mon.moves:
			move.pp = move.maxPp

static func heal_party(state: Dictionary) -> Dictionary:
	if state.battle != null:
		return _fail("전투를 마친 뒤 회복할 수 있어요.")
	_restore_party(state)
	return _ok("동료들의 체력과 PP를 모두 회복했습니다.")

static func buy_item(state: Dictionary, item: String) -> Dictionary:
	if state.battle != null:
		return _fail("전투 중에는 상점을 이용할 수 없어요.")
	if not ["balls", "potions"].has(item):
		return _fail("판매하지 않는 물건입니다.")
	var price: int = 200 if item == "balls" else 300
	if state.money < price:
		return _fail("돈이 부족해요.")
	if state.bag[item] >= 999:
		return _fail("가방이 가득 찼어요.")
	state.money -= price
	state.bag[item] += 1
	return _ok("%s을 구입했습니다." % ("몬스터볼" if item == "balls" else "상처약"))

static func get_objective(state: Dictionary) -> String:
	if state.stage == "prologue":
		return "숲의 빛을 따라가 다친 랄토스를 찾아주세요."
	if state.stage == "rescued":
		return "백서화 연구소에서 첫 파트너를 선택하세요."
	if not state.flags.rivalWon:
		return "서하린에게 말을 걸어 첫 라이벌 대결에 도전하세요."
	if state.trainerWins.size() < 5:
		return "1번도로를 탐험하며 트레이너에게 도전하세요. (%d/5)" % state.trainerWins.size()
	if not state.flags.gymWon:
		return "동료들을 회복하고 수원 체육관의 이도윤에게 도전하세요."
	return "성곽배지 획득! 첫 여정을 마쳤습니다. 자유롭게 탐험해 보세요."

# JSON은 읽기 성공 여부와 별개로 각 필드를 검증하고 새 사전으로 재구성한다.
static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum

static func _invalid(message: String) -> Dictionary:
	return {"ok": false, "state": {}, "error": "저장 파일을 불러올 수 없습니다: " + message}

static func _validate_creature(value: Variant) -> Dictionary:
	if not value is Dictionary or not value.get("species") is String:
		return {}
	var entry: Dictionary = get_species(value.species)
	if entry.is_empty() or not _integer(value.get("level"), 1, MAX_LEVEL):
		return {}
	var level: int = int(value.level)
	var max_hp: int = int(entry.hp) + level * 3
	if value.get("maxHp") != max_hp or not _integer(value.get("hp"), 0, max_hp):
		return {}
	if not value.get("uid") is String or value.uid.length() < 1 or value.uid.length() > 100:
		return {}
	if not value.get("moves") is Array or value.moves.size() != entry.moves.size():
		return {}
	var moves: Array = []
	for index in range(entry.moves.size()):
		var slot: Variant = value.moves[index]
		var id: String = entry.moves[index]
		var pp: int = int(get_move(id).pp)
		if not slot is Dictionary or slot.get("id") != id or not _integer(slot.get("pp"), 0, pp) or slot.get("maxPp") != pp:
			return {}
		moves.append({"id": id, "pp": int(slot.pp), "maxPp": pp})
	if not _integer(value.get("xp"), 0, 0 if level == MAX_LEVEL else level * 20 - 1):
		return {}
	if not [null, "burn", "poison", "paralysis"].has(value.get("status")) or not value.get("shiny") is bool:
		return {}
	if not ["incheon-rescue", "starter", "wild"].has(value.get("source")):
		return {}
	if value.source == "incheon-rescue" and (not RALTS_LINE.has(value.species) or not value.shiny):
		return {}
	if value.source == "starter" and not STARTER_LINES.has(value.species):
		return {}
	if value.source == "wild" and (RALTS_LINE.has(value.species) or STARTER_LINES.has(value.species)):
		return {}
	return {"uid": value.uid, "species": value.species, "name": entry.name, "level": level, "hp": int(value.hp), "maxHp": max_hp, "moves": moves, "xp": int(value.xp), "status": value.get("status"), "shiny": value.shiny, "source": value.source}

static func validate_save(input: Variant) -> Dictionary:
	var value: Variant = input
	if input is String:
		if input.length() > 3000000:
			return _invalid("파일이 너무 큽니다")
		var parser := JSON.new()
		if parser.parse(input) != OK:
			return _invalid("올바른 JSON 파일이 아닙니다")
		value = parser.data
	if not value is Dictionary:
		return _invalid("올바른 JSON 파일이 아닙니다")
	if value.get("version") != SAVE_VERSION:
		return _invalid("호환되지 않는 저장 버전")
	if not value.has("battle") or value.battle != null:
		return _invalid("전투 중 저장은 지원하지 않습니다")
	if not ["prologue", "rescued", "journey", "complete"].has(value.get("stage")) or not ["incheon", "route", "suwon"].has(value.get("area")):
		return _invalid("잘못된 진행 단계 또는 지역")
	if not value.get("player") is Dictionary:
		return _invalid("잘못된 위치")
	var p: Dictionary = value.player
	if not (p.get("x") is float or p.get("x") is int) or not (p.get("y") is float or p.get("y") is int):
		return _invalid("잘못된 위치")
	if not is_finite(float(p.x)) or not is_finite(float(p.y)) or p.x < 0 or p.x >= 30 or p.y < 0 or p.y >= 20 or not ["up", "down", "left", "right"].has(p.get("facing")):
		return _invalid("잘못된 위치")
	if not value.get("party") is Array or value.party.size() > 6 or not value.get("box") is Array or value.box.size() > MAX_BOX:
		return _invalid("잘못된 동료 또는 박스")
	var party: Array = []
	var box: Array = []
	var uids: Array = []
	var rescued_count := 0
	var starter_count := 0
	var wild_count := 0
	for group in ["party", "box"]:
		for raw in value[group]:
			var mon: Dictionary = _validate_creature(raw)
			if mon.is_empty() or uids.has(mon.uid):
				return _invalid("손상되었거나 중복된 포켓몬 정보")
			uids.append(mon.uid)
			if group == "party":
				party.append(mon)
			else:
				box.append(mon)
			rescued_count += 1 if mon.source == "incheon-rescue" else 0
			starter_count += 1 if mon.source == "starter" else 0
			wild_count += 1 if mon.source == "wild" else 0
	if not value.get("bag") is Dictionary or not _integer(value.bag.get("balls"), 0, 999) or not _integer(value.bag.get("potions"), 0, 999):
		return _invalid("잘못된 가방")
	if not _integer(value.get("money"), 0, 999999) or not _integer(value.get("steps"), 0, 100000000):
		return _invalid("잘못된 소지금 또는 걸음 수")
	if not value.get("flags") is Dictionary:
		return _invalid("잘못된 진행 기록")
	var flags: Dictionary = {}
	for key in ["rescued", "starterChosen", "firstCapture", "gymWon", "rivalWon"]:
		if not value.flags.get(key) is bool:
			return _invalid("잘못된 진행 기록")
		flags[key] = value.flags[key]
	if not value.flags.get("routeItem", false) is bool:
		return _invalid("잘못된 아이템 획득 기록")
	flags.routeItem = value.flags.get("routeItem", false)
	var expected: Array = {"prologue": [false, false, false], "rescued": [true, false, false], "journey": [true, true, false], "complete": [true, true, true]}[value.stage]
	if [flags.rescued, flags.starterChosen, flags.gymWon] != expected:
		return _invalid("진행 단계와 기록이 일치하지 않습니다")
	if rescued_count != (1 if flags.rescued else 0) or starter_count != (1 if flags.starterChosen else 0):
		return _invalid("랄토스 구조 또는 스타팅 기록이 없습니다")
	if flags.starterChosen and (party.is_empty() or not STARTERS.has(value.get("starter"))):
		return _invalid("스타팅 선택 기록이 없습니다")
	if flags.starterChosen:
		var starter_lines: Dictionary = {"purunae": ["purunae", "purusori", "ulchangryeong"], "hwarangi": ["hwarangi", "bulhoryeong", "jinhwarang"], "padoring": ["padoring", "mulgyeoldari", "haeryushin"]}
		for mon in party + box:
			if mon.source == "starter" and not starter_lines[value.starter].has(mon.species):
				return _invalid("선택한 스타팅과 동료가 일치하지 않습니다")
	if not flags.starterChosen and (value.get("starter") != "" or value.area != "incheon" or flags.rivalWon or flags.firstCapture):
		return _invalid("프롤로그 진행이 맞지 않습니다")
	if flags.firstCapture != (wild_count > 0):
		return _invalid("포획한 동료와 기록이 일치하지 않습니다")
	if not value.get("badges") is Array or value.badges != ([BADGE] if flags.gymWon else []):
		return _invalid("잘못된 배지 기록")
	for key in ["seen", "caught"]:
		if not value.get(key) is Array or value[key].size() > all_species().size():
			return _invalid("잘못된 도감")
		var unique: Array = []
		for id in value[key]:
			if not id is String or get_species(id).is_empty() or unique.has(id):
				return _invalid("잘못된 도감")
			unique.append(id)
	for id in value.caught:
		if not value.seen.has(id):
			return _invalid("발견하지 않은 포켓몬의 포획 기록")
	for mon in party + box:
		if not value.caught.has(mon.species):
			return _invalid("도감과 동료가 일치하지 않습니다")
	if not ["easy", "normal", "hard"].has(value.get("difficulty")):
		return _invalid("잘못된 난이도")
	if not value.get("trainerWins") is Array or value.trainerWins.size() > 5:
		return _invalid("잘못된 트레이너 기록")
	var wins: Array = []
	for id in value.trainerWins:
		if not _integer(id, 0, 4) or wins.has(int(id)):
			return _invalid("잘못된 트레이너 기록")
		wins.append(int(id))
	if not value.get("visited") is Array or not value.visited.has("incheon") or value.visited.size() > 3:
		return _invalid("잘못된 방문 기록")
	var visited: Array = []
	for place in value.visited:
		if not ["incheon", "route", "suwon"].has(place) or visited.has(place):
			return _invalid("잘못된 방문 기록")
		visited.append(place)
	var state: Dictionary = {"version": SAVE_VERSION, "stage": value.stage, "area": value.area, "player": {"x": float(p.x), "y": float(p.y), "facing": p.facing}, "party": party, "box": box, "bag": {"balls": int(value.bag.balls), "potions": int(value.bag.potions)}, "money": int(value.money), "badges": value.badges.duplicate(), "seen": value.seen.duplicate(), "caught": value.caught.duplicate(), "flags": flags, "steps": int(value.steps), "battle": null, "starter": value.starter, "trainerWins": wins, "visited": visited, "difficulty": value.difficulty}
	return {"ok": true, "state": state, "error": ""}

static func serialize_save(state: Dictionary) -> String:
	var result: Dictionary = validate_save(state)
	return JSON.stringify(result.state, "  ") if result.ok else ""
