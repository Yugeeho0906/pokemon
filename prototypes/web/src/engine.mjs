// 첫 체육관까지의 게임 진행과 전투. 수치는 플레이 검증용 초기 밸런스다.
export const TYPE_CHART = {
  normal: { rock: 0.5, ghost: 0, steel: 0.5 },
  fire: { fire: 0.5, water: 0.5, grass: 2, ice: 2, bug: 2, rock: 0.5, dragon: 0.5, steel: 2 },
  water: { fire: 2, water: 0.5, grass: 0.5, ground: 2, rock: 2, dragon: 0.5 },
  electric: { water: 2, electric: 0.5, grass: 0.5, ground: 0, flying: 2, dragon: 0.5 },
  grass: { fire: 0.5, water: 2, grass: 0.5, poison: 0.5, ground: 2, flying: 0.5, bug: 0.5, rock: 2, dragon: 0.5, steel: 0.5 },
  ice: { fire: 0.5, water: 0.5, grass: 2, ice: 0.5, ground: 2, flying: 2, dragon: 2, steel: 0.5 },
  fighting: { normal: 2, ice: 2, poison: 0.5, flying: 0.5, psychic: 0.5, bug: 0.5, rock: 2, ghost: 0, dark: 2, steel: 2, fairy: 0.5 },
  poison: { grass: 2, poison: 0.5, ground: 0.5, rock: 0.5, ghost: 0.5, steel: 0, fairy: 2 },
  ground: { fire: 2, electric: 2, grass: 0.5, poison: 2, flying: 0, bug: 0.5, rock: 2, steel: 2 },
  flying: { electric: 0.5, grass: 2, fighting: 2, bug: 2, rock: 0.5, steel: 0.5 },
  psychic: { fighting: 2, poison: 2, psychic: 0.5, dark: 0, steel: 0.5 },
  bug: { fire: 0.5, grass: 2, fighting: 0.5, poison: 0.5, flying: 0.5, psychic: 2, ghost: 0.5, dark: 2, steel: 0.5, fairy: 0.5 },
  rock: { fire: 2, ice: 2, fighting: 0.5, ground: 0.5, flying: 2, bug: 2, steel: 0.5 },
  ghost: { normal: 0, psychic: 2, ghost: 2, dark: 0.5 },
  dragon: { dragon: 2, steel: 0.5, fairy: 0 },
  dark: { fighting: 0.5, psychic: 2, ghost: 2, dark: 0.5, fairy: 0.5 },
  steel: { fire: 0.5, water: 0.5, electric: 0.5, ice: 2, rock: 2, steel: 0.5, fairy: 2 },
  fairy: { fire: 0.5, fighting: 2, poison: 0.5, dragon: 2, dark: 2, steel: 0.5 }
};

export const MOVES = {
  tackle: { id: 'tackle', name: '몸통박치기', type: 'normal', power: 40, accuracy: 1, pp: 35, category: 'physical' },
  growl: { id: 'growl', name: '울음소리', type: 'normal', power: 0, accuracy: 1, pp: 40, category: 'status', effect: 'attackDown' },
  tailWhip: { id: 'tailWhip', name: '꼬리흔들기', type: 'normal', power: 0, accuracy: 1, pp: 30, category: 'status', effect: 'defenseDown' },
  confusion: { id: 'confusion', name: '염동력', type: 'psychic', power: 50, accuracy: 1, pp: 25, category: 'special' },
  disarmingVoice: { id: 'disarmingVoice', name: '차밍보이스', type: 'fairy', power: 40, accuracy: 1, pp: 15, category: 'special' },
  vineWhip: { id: 'vineWhip', name: '덩굴채찍', type: 'grass', power: 45, accuracy: 1, pp: 25, category: 'physical' },
  ember: { id: 'ember', name: '불꽃세례', type: 'fire', power: 40, accuracy: 1, pp: 25, category: 'special', effect: 'burn' },
  waterGun: { id: 'waterGun', name: '물대포', type: 'water', power: 40, accuracy: 1, pp: 25, category: 'special' },
  quickAttack: { id: 'quickAttack', name: '전광석화', type: 'normal', power: 40, accuracy: 1, pp: 30, category: 'physical', priority: 1 },
  gust: { id: 'gust', name: '바람일으키기', type: 'flying', power: 40, accuracy: 1, pp: 35, category: 'special' },
  stringShot: { id: 'stringShot', name: '실뿜기', type: 'bug', power: 0, accuracy: 0.95, pp: 40, category: 'status', effect: 'speedDown' },
  struggle: { id: 'struggle', name: '발버둥', type: 'normal', power: 50, accuracy: 1, pp: 1, category: 'physical', effect: 'recoil' }
};

export const SPECIES = {
  ralts: { id: 'ralts', name: '랄토스', types: ['psychic', 'fairy'], color: '#86bedf', hp: 22, attack: 11, defense: 10, speed: 12, moves: ['confusion', 'disarmingVoice', 'growl', 'tackle'] },
  purunae: { id: 'purunae', name: '푸르내', types: ['grass'], color: '#84b976', hp: 26, attack: 13, defense: 13, speed: 12, moves: ['vineWhip', 'tackle', 'growl', 'quickAttack'] },
  hwarangi: { id: 'hwarangi', name: '화랑이', types: ['fire'], color: '#ef965c', hp: 25, attack: 14, defense: 11, speed: 14, moves: ['ember', 'tackle', 'growl', 'quickAttack'] },
  padoring: { id: 'padoring', name: '파도링', types: ['water'], color: '#72b9e0', hp: 27, attack: 12, defense: 14, speed: 11, moves: ['waterGun', 'tackle', 'tailWhip', 'quickAttack'] },
  pidgey: { id: 'pidgey', name: '구구', types: ['normal', 'flying'], color: '#b88c65', hp: 17, attack: 9, defense: 8, speed: 12, moves: ['tackle', 'gust', 'growl', 'quickAttack'] },
  caterpie: { id: 'caterpie', name: '캐터피', types: ['bug'], color: '#8fbe62', hp: 18, attack: 8, defense: 8, speed: 8, moves: ['tackle', 'stringShot'] },
  pidgeotto: { id: 'pidgeotto', name: '피죤투', types: ['normal', 'flying'], color: '#b78257', hp: 33, attack: 13, defense: 12, speed: 13, moves: ['gust', 'tackle', 'quickAttack', 'growl'] }
};

const STARTERS = ['purunae', 'hwarangi', 'padoring'];
const MAX_LEVEL = 20;
const MAX_BOX = 120;
const BADGE = '성곽배지';
let creatureSequence = 0;

export function createGame() {
  return {
    version: 1,
    stage: 'prologue',
    area: 'incheon',
    player: { x: 14, y: 14, facing: 'down' },
    party: [],
    box: [],
    bag: { balls: 8, potions: 5 },
    money: 1500,
    badges: [],
    seen: [],
    caught: [],
    flags: { rescued: false, starterChosen: false, firstCapture: false, gymWon: false },
    steps: 0,
    battle: null
  };
}

function makeCreature(species, level, shiny = false) {
  const entry = SPECIES[species];
  const maxHp = entry.hp + level * 2;
  return {
    uid: `${species}-${Date.now().toString(36)}-${(++creatureSequence).toString(36)}-${Math.random().toString(36).slice(2, 9)}`,
    species,
    name: entry.name,
    level,
    hp: maxHp,
    maxHp,
    moves: entry.moves.map(id => ({ id, pp: MOVES[id].pp, maxPp: MOVES[id].pp })),
    xp: 0,
    shiny,
    status: null
  };
}

function addUnique(array, value) {
  if (!array.includes(value)) array.push(value);
}

function failure(message) {
  return { ok: false, message, logs: [message] };
}

function success(message, logs = [message]) {
  return { ok: true, message, logs };
}

export function rescueRalts(state) {
  if (state.stage !== 'prologue' || state.flags.rescued || state.battle) {
    return failure('랄토스는 이미 안전해졌어요.');
  }
  state.party.push(makeCreature('ralts', 5, true));
  state.stage = 'rescued';
  state.flags.rescued = true;
  addUnique(state.seen, 'ralts');
  addUnique(state.caught, 'ralts');
  return success('특별한 이로치 랄토스를 구조했습니다! 다음 날, 백서화 연구소로 가 보세요.');
}

export function chooseStarter(state, species) {
  if (state.stage !== 'rescued' || !state.flags.rescued || state.flags.starterChosen || state.battle) {
    return failure('먼저 숲에서 랄토스를 구조해야 해요.');
  }
  if (!STARTERS.includes(species)) return failure('세 스타팅 중 한 마리를 선택해 주세요.');
  state.party.push(makeCreature(species, 5));
  state.stage = 'journey';
  state.flags.starterChosen = true;
  addUnique(state.seen, species);
  addUnique(state.caught, species);
  return success(`${SPECIES[species].name}가 동료가 되었습니다! 랄토스와 함께 두 마리로 출발해요.`);
}

export function startBattle(state, kind, species) {
  if (state.battle) return failure('진행 중인 전투를 먼저 마쳐 주세요.');
  if (!state.flags.starterChosen) return failure('연구소에서 스타팅을 선택한 뒤 모험을 시작해요.');
  if (!['wild', 'gym'].includes(kind)) return failure('시작할 수 없는 전투입니다.');
  if (kind === 'gym' && !state.flags.firstCapture) return failure('먼저 풀숲에서 야생 포켓몬을 한 마리 잡아 보세요.');
  const active = state.party.findIndex(mon => mon.hp > 0);
  if (active === -1) return failure('포켓몬센터에서 동료들을 회복해 주세요.');
  if (kind === 'wild' && species && !['pidgey', 'caterpie'].includes(species)) {
    return failure('이 지역에서 만날 수 없는 포켓몬입니다.');
  }
  const selected = kind === 'gym' ? 'pidgeotto' : species || (state.steps % 2 === 0 ? 'pidgey' : 'caterpie');
  const enemy = makeCreature(selected, kind === 'gym' ? 8 : 4);
  addUnique(state.seen, selected);
  state.battle = {
    kind,
    enemy,
    active,
    turn: 0,
    logs: [kind === 'gym' ? '수원 체육관 관장 이도윤이 피죤투를 내보냈다!' : `야생 ${enemy.name}가 나타났다!`],
    outcome: null,
    stages: { player: { attack: 0, defense: 0, speed: 0 }, enemy: { attack: 0, defense: 0, speed: 0 } }
  };
  return success(state.battle.logs[0]);
}

function roll(rng) {
  const result = rng();
  return Number.isFinite(result) ? Math.max(0, Math.min(0.999999, result)) : 0.5;
}

function stageMultiplier(value) {
  return value >= 0 ? (2 + value) / 2 : 2 / (2 - value);
}

function typeMultiplier(type, defender) {
  return SPECIES[defender.species].types.reduce((value, target) => value * (TYPE_CHART[type][target] ?? 1), 1);
}

function stat(mon, key, stages) {
  const status = key === 'speed' && mon.status === 'paralysis' ? 0.5 : 1;
  return (SPECIES[mon.species][key] + mon.level) * stageMultiplier(stages[key]) * status;
}

function attack(state, isPlayer, moveId, rng, logs) {
  const battle = state.battle;
  const player = state.party[battle.active];
  const attacker = isPlayer ? player : battle.enemy;
  const defender = isPlayer ? battle.enemy : player;
  const ownStages = isPlayer ? battle.stages.player : battle.stages.enemy;
  const targetStages = isPlayer ? battle.stages.enemy : battle.stages.player;
  if (attacker.hp <= 0 || defender.hp <= 0) return;
  const move = MOVES[moveId];
  if (attacker.status === 'paralysis' && roll(rng) < 0.25) {
    logs.push(`${attacker.name}는 마비되어 움직일 수 없다!`);
    return;
  }
  const slot = attacker.moves.find(item => item.id === moveId);
  if (moveId !== 'struggle') slot.pp -= 1;
  logs.push(`${attacker.name}의 ${move.name}!`);
  if (roll(rng) >= move.accuracy) {
    logs.push('공격이 빗나갔다!');
    return;
  }
  if (move.category === 'status') {
    const key = { attackDown: 'attack', defenseDown: 'defense', speedDown: 'speed' }[move.effect];
    if (targetStages[key] <= -6) {
      logs.push('능력은 더 내려가지 않는다.');
    } else {
      targetStages[key] = Math.max(-6, targetStages[key] - (key === 'speed' ? 2 : 1));
      logs.push(`${defender.name}의 ${ { attack: '공격', defense: '방어', speed: '스피드' }[key]}이 내려갔다.`);
    }
    return;
  }
  const effectiveness = moveId === 'struggle' ? 1 : typeMultiplier(move.type, defender);
  if (effectiveness === 0) {
    logs.push(`${defender.name}에게는 효과가 없다!`);
    return;
  }
  const stab = SPECIES[attacker.species].types.includes(move.type) && moveId !== 'struggle' ? 1.5 : 1;
  const burn = attacker.status === 'burn' && move.category === 'physical' ? 0.5 : 1;
  // 울음소리와 꼬리흔들기는 물리 공격·방어에만 영향을 준다.
  const attackStages = move.category === 'physical' ? ownStages : { ...ownStages, attack: 0 };
  const defenseStages = move.category === 'physical' ? targetStages : { ...targetStages, defense: 0 };
  const base = ((2 * attacker.level / 5 + 2) * move.power * stat(attacker, 'attack', attackStages) / stat(defender, 'defense', defenseStages)) / 50 + 2;
  const damage = Math.max(1, Math.floor(base * effectiveness * stab * burn * (0.85 + 0.15 * roll(rng))));
  defender.hp = Math.max(0, defender.hp - damage);
  logs.push(`${defender.name}에게 ${damage}의 데미지!`);
  if (effectiveness > 1) logs.push('효과가 굉장했다!');
  if (effectiveness < 1) logs.push('효과가 별로인 듯하다…');
  if (move.effect === 'burn' && defender.hp > 0 && !defender.status && !SPECIES[defender.species].types.includes('fire') && roll(rng) < 0.1) {
    defender.status = 'burn';
    logs.push(`${defender.name}는 화상을 입었다!`);
  }
  if (move.effect === 'recoil') {
    attacker.hp = Math.max(0, attacker.hp - Math.max(1, Math.floor(attacker.maxHp / 4)));
    logs.push(`${attacker.name}는 반동을 받았다.`);
  }
}

function giveExperience(state, logs) {
  const reward = state.battle.kind === 'gym' ? 90 : 35;
  for (const mon of state.party) {
    mon.xp += reward;
    while (mon.level < MAX_LEVEL && mon.xp >= mon.level * 12) {
      mon.xp -= mon.level * 12;
      mon.level += 1;
      mon.maxHp += 2;
      if (mon.hp > 0) mon.hp += 2;
      logs.push(`${mon.name}의 레벨이 ${mon.level}이 되었다!`);
    }
    if (mon.level === MAX_LEVEL) mon.xp = 0;
  }
}

function finishIfNeeded(state, logs) {
  const battle = state.battle;
  if (battle.enemy.hp <= 0) {
    battle.outcome = 'won';
    logs.push(`${battle.enemy.name}는 쓰러졌다! 전투에서 승리했다.`);
    giveExperience(state, logs);
    state.money = Math.min(999999, state.money + (battle.kind === 'gym' ? 500 : 80));
    if (battle.kind === 'gym') {
      addUnique(state.badges, BADGE);
      state.flags.gymWon = true;
      state.stage = 'complete';
      logs.push('이도윤에게 성곽배지를 받았다! 첫 번째 여정을 마쳤다.');
    }
    return true;
  }
  const player = state.party[battle.active];
  if (player.hp > 0) return false;
  logs.push(`${player.name}는 쓰러졌다!`);
  const next = state.party.findIndex(mon => mon.hp > 0);
  if (next !== -1) {
    battle.active = next;
    battle.stages.player = { attack: 0, defense: 0, speed: 0 };
    logs.push(`${state.party[next].name}, 부탁해!`);
    return false;
  }
  battle.outcome = 'lost';
  restoreParty(state);
  state.area = state.area === 'suwon' ? 'suwon' : 'incheon';
  state.player = { x: 7, y: 9, facing: 'down' };
  logs.push('동료들을 포켓몬센터에서 회복했다. 준비해서 다시 도전하자!');
  return true;
}

function enemyMove(state, rng) {
  const moves = state.battle.enemy.moves.filter(move => move.pp > 0);
  if (moves.length === 0) return 'struggle';
  const attacking = moves.filter(move => MOVES[move.id].power > 0);
  const pool = attacking.length && roll(rng) < 0.8 ? attacking : moves;
  return pool[Math.floor(roll(rng) * pool.length)].id;
}

function statusDamage(state, logs) {
  for (const mon of [state.party[state.battle.active], state.battle.enemy]) {
    if (mon.hp <= 0 || !['burn', 'poison'].includes(mon.status)) continue;
    const amount = Math.max(1, Math.floor(mon.maxHp / (mon.status === 'burn' ? 16 : 8)));
    mon.hp = Math.max(0, mon.hp - amount);
    logs.push(`${mon.name}는 ${mon.status === 'burn' ? '화상' : '독'}으로 ${amount}의 데미지를 받았다.`);
  }
}

export function battleAction(state, action, rng = Math.random) {
  const battle = state.battle;
  if (!battle || battle.outcome) return failure('현재 행동할 수 있는 전투가 없습니다.');
  if (!action || typeof action !== 'object') return failure('행동을 선택해 주세요.');
  const player = state.party[battle.active];
  let moveId = null;
  switch (action.type) {
    case 'move': {
      const hasPp = player.moves.some(move => move.pp > 0);
      const slot = player.moves[action.index];
      if (!hasPp) {
        moveId = 'struggle';
      } else if (!Number.isInteger(action.index) || !slot || slot.pp <= 0) {
        return failure('사용할 기술이 없거나 PP가 부족해요.');
      } else {
        moveId = slot.id;
      }
      break;
    }
    case 'ball':
      if (battle.kind !== 'wild') return failure('다른 트레이너의 포켓몬은 잡을 수 없어요.');
      if (state.bag.balls < 1) return failure('몬스터볼이 없어요. 상점에서 구입해 주세요.');
      if (state.party.length >= 6 && state.box.length >= MAX_BOX) return failure('박스가 가득 찼어요.');
      break;
    case 'potion':
      if (state.bag.potions < 1) return failure('상처약이 없어요.');
      if (player.hp >= player.maxHp) return failure('체력이 이미 가득 차 있어요.');
      break;
    case 'switch':
      if (!Number.isInteger(action.index) || !state.party[action.index] || action.index === battle.active || state.party[action.index].hp <= 0) {
        return failure('교체할 수 있는 다른 동료를 선택해 주세요.');
      }
      break;
    case 'run':
      if (battle.kind !== 'wild') return failure('체육관 전투에서는 도망칠 수 없어요.');
      break;
    default:
      return failure('알 수 없는 행동입니다.');
  }

  const logs = [];
  battle.turn += 1;
  if (action.type === 'ball') {
    state.bag.balls -= 1;
    logs.push('몬스터볼을 던졌다!');
    const chance = Math.min(0.95, 0.22 + 0.65 * (1 - battle.enemy.hp / battle.enemy.maxHp) + (battle.enemy.status ? 0.12 : 0));
    if (roll(rng) < chance) {
      const caught = structuredClone(battle.enemy);
      const inBox = state.party.length >= 6;
      (inBox ? state.box : state.party).push(caught);
      addUnique(state.caught, caught.species);
      state.flags.firstCapture = true;
      battle.outcome = 'caught';
      logs.push(`${caught.name}를 잡았다!${inBox ? ' 박스로 보냈다.' : ' 동료가 되었다.'}`);
    } else {
      logs.push('아쉽다! 몬스터볼에서 빠져나왔다.');
    }
  } else if (action.type === 'potion') {
    state.bag.potions -= 1;
    const restored = Math.min(25, player.maxHp - player.hp);
    player.hp += restored;
    logs.push(`상처약으로 ${player.name}의 체력을 ${restored} 회복했다.`);
  } else if (action.type === 'switch') {
    battle.active = action.index;
    battle.stages.player = { attack: 0, defense: 0, speed: 0 };
    logs.push(`${state.party[action.index].name}, 부탁해!`);
  } else if (action.type === 'run') {
    if (roll(rng) < 0.85) {
      battle.outcome = 'escaped';
      logs.push('무사히 도망쳤다!');
    } else {
      logs.push('도망칠 수 없었다!');
    }
  }

  if (!battle.outcome) {
    const foeMove = enemyMove(state, rng);
    if (moveId) {
      const ownPriority = MOVES[moveId].priority || 0;
      const foePriority = MOVES[foeMove].priority || 0;
      const first = ownPriority !== foePriority ? ownPriority > foePriority : stat(player, 'speed', battle.stages.player) >= stat(battle.enemy, 'speed', battle.stages.enemy);
      const initialActive = battle.active;
      attack(state, first, first ? moveId : foeMove, rng, logs);
      if (!finishIfNeeded(state, logs) && battle.active === initialActive) {
        attack(state, !first, first ? foeMove : moveId, rng, logs);
        finishIfNeeded(state, logs);
      }
    } else {
      attack(state, false, foeMove, rng, logs);
      finishIfNeeded(state, logs);
    }
    if (!battle.outcome) {
      statusDamage(state, logs);
      finishIfNeeded(state, logs);
    }
  }
  battle.logs = [...battle.logs, ...logs].slice(-80);
  return success(logs[logs.length - 1] || '다음 행동을 선택해 주세요.', logs);
}

function restoreParty(state) {
  for (const mon of state.party) {
    mon.hp = mon.maxHp;
    mon.status = null;
    for (const move of mon.moves) move.pp = move.maxPp;
  }
}

export function healParty(state) {
  if (state.battle) return failure('전투를 마친 뒤 회복할 수 있어요.');
  restoreParty(state);
  return success('동료들의 체력과 PP를 모두 회복했습니다.');
}

export function buyItem(state, item) {
  if (state.battle) return failure('전투 중에는 상점을 이용할 수 없어요.');
  if (!['balls', 'potions'].includes(item)) return failure('판매하지 않는 물건입니다.');
  const price = item === 'balls' ? 200 : 300;
  if (state.money < price) return failure('돈이 부족해요.');
  if (state.bag[item] >= 999) return failure('가방이 가득 찼어요.');
  state.money -= price;
  state.bag[item] += 1;
  return success(`${item === 'balls' ? '몬스터볼' : '상처약'}을 구입했습니다.`);
}

export function getObjective(state) {
  if (state.stage === 'prologue') return '숲의 빛을 따라가 다친 랄토스를 찾아주세요.';
  if (state.stage === 'rescued') return '백서화 연구소에서 첫 파트너를 선택하세요.';
  if (!state.flags.firstCapture) return '수원 가는 길의 풀숲에서 야생 포켓몬을 잡아보세요.';
  if (!state.flags.gymWon) return '수원 체육관의 이도윤에게 도전하세요.';
  return '성곽배지 획득! 첫 여정을 마쳤습니다. 자유롭게 탐험해 보세요.';
}

function assertSave(condition, message) {
  if (!condition) throw new Error(`저장 파일을 불러올 수 없습니다: ${message}`);
}

function integer(value, min, max) {
  return Number.isInteger(value) && value >= min && value <= max;
}

function validateCreature(value) {
  assertSave(value && typeof value === 'object' && !Array.isArray(value), '잘못된 포켓몬 정보');
  assertSave(Object.hasOwn(SPECIES, value.species), '알 수 없는 포켓몬');
  assertSave(integer(value.level, 1, MAX_LEVEL), '잘못된 레벨');
  const maxHp = SPECIES[value.species].hp + value.level * 2;
  assertSave(value.maxHp === maxHp && integer(value.hp, 0, maxHp), '잘못된 체력');
  assertSave(typeof value.uid === 'string' && /^[a-z0-9-]{1,99}$/.test(value.uid), '잘못된 포켓몬 식별자');
  assertSave(Array.isArray(value.moves) && value.moves.length === SPECIES[value.species].moves.length, '잘못된 기술 목록');
  const moves = value.moves.map((move, index) => {
    const id = SPECIES[value.species].moves[index];
    assertSave(move && move.id === id && integer(move.pp, 0, MOVES[id].pp) && move.maxPp === MOVES[id].pp, '잘못된 기술 또는 PP');
    return { id, pp: move.pp, maxPp: MOVES[id].pp };
  });
  assertSave(integer(value.xp, 0, value.level === MAX_LEVEL ? 0 : value.level * 12 - 1), '잘못된 경험치');
  assertSave([null, 'burn', 'poison', 'paralysis'].includes(value.status), '잘못된 상태이상');
  assertSave(typeof value.shiny === 'boolean', '잘못된 이로치 정보');
  return {
    uid: value.uid,
    species: value.species,
    name: SPECIES[value.species].name,
    level: value.level,
    hp: value.hp,
    maxHp,
    moves,
    xp: value.xp,
    shiny: value.shiny,
    status: value.status
  };
}

export function validateSave(input) {
  assertSave(typeof input !== 'string' || input.length < 200000, '파일이 너무 큽니다');
  let value;
  try {
    value = typeof input === 'string' ? JSON.parse(input) : input;
  } catch {
    throw new Error('저장 파일을 불러올 수 없습니다: 올바른 JSON 파일이 아닙니다');
  }
  assertSave(value && typeof value === 'object' && !Array.isArray(value), '잘못된 파일 형식');
  assertSave(value.version === 1, '호환되지 않는 저장 버전');
  assertSave(value.battle === null, '전투 중 저장은 지원하지 않습니다');
  assertSave(['prologue', 'rescued', 'journey', 'complete'].includes(value.stage), '잘못된 진행 단계');
  assertSave(['incheon', 'route', 'suwon'].includes(value.area), '잘못된 지역');
  assertSave(value.player && Number.isFinite(value.player.x) && value.player.x >= 0 && value.player.x < 30 && Number.isFinite(value.player.y) && value.player.y >= 0 && value.player.y < 20 && ['up', 'down', 'left', 'right'].includes(value.player.facing), '잘못된 위치');
  assertSave(Array.isArray(value.party) && value.party.length <= 6 && Array.isArray(value.box) && value.box.length <= MAX_BOX, '잘못된 동료 또는 박스');
  const party = value.party.map(validateCreature);
  const box = value.box.map(validateCreature);
  const owned = [...party, ...box];
  assertSave(new Set(owned.map(mon => mon.uid)).size === owned.length, '중복된 포켓몬 식별자');
  assertSave(value.bag && integer(value.bag.balls, 0, 999) && integer(value.bag.potions, 0, 999), '잘못된 가방');
  assertSave(integer(value.money, 0, 999999) && integer(value.steps, 0, 100000000), '잘못된 소지금 또는 걸음 수');
  assertSave(value.flags && ['rescued', 'starterChosen', 'firstCapture', 'gymWon'].every(key => typeof value.flags[key] === 'boolean'), '잘못된 진행 기록');
  const flags = Object.fromEntries(['rescued', 'starterChosen', 'firstCapture', 'gymWon'].map(key => [key, value.flags[key]]));
  const stages = { prologue: [false, false, false], rescued: [true, false, false], journey: [true, true, false], complete: [true, true, true] };
  assertSave([flags.rescued, flags.starterChosen, flags.gymWon].every((flag, index) => flag === stages[value.stage][index]), '진행 단계와 기록이 일치하지 않습니다');
  assertSave(!flags.firstCapture || flags.starterChosen, '포획 순서가 맞지 않습니다');
  assertSave(!flags.gymWon || flags.firstCapture, '체육관 진행 순서가 맞지 않습니다');
  assertSave(value.stage === 'prologue' ? owned.length === 0 : owned.filter(mon => mon.species === 'ralts' && mon.shiny).length === 1, '랄토스 구조 기록이 없습니다');
  assertSave(!flags.starterChosen || (party.length > 0 && owned.filter(mon => STARTERS.includes(mon.species)).length === 1), '스타팅 선택 기록이 없습니다');
  assertSave(value.stage !== 'rescued' || (owned.length === 1 && value.area === 'incheon'), '프롤로그 진행이 맞지 않습니다');
  assertSave(value.stage !== 'prologue' || value.area === 'incheon', '프롤로그 지역이 맞지 않습니다');
  assertSave(!flags.firstCapture || owned.some(mon => ['pidgey', 'caterpie'].includes(mon.species)), '포획한 동료가 없습니다');
  assertSave(Array.isArray(value.badges) && value.badges.length === (flags.gymWon ? 1 : 0) && value.badges.every(badge => badge === BADGE), '잘못된 배지 기록');
  for (const key of ['seen', 'caught']) {
    assertSave(Array.isArray(value[key]) && value[key].length <= Object.keys(SPECIES).length && value[key].every(id => Object.hasOwn(SPECIES, id)) && new Set(value[key]).size === value[key].length, '잘못된 도감 기록');
  }
  assertSave(value.caught.every(id => value.seen.includes(id)) && owned.every(mon => value.caught.includes(mon.species)), '도감과 동료가 일치하지 않습니다');
  return {
    version: 1,
    stage: value.stage,
    area: value.area,
    player: { x: value.player.x, y: value.player.y, facing: value.player.facing },
    party,
    box,
    bag: { balls: value.bag.balls, potions: value.bag.potions },
    money: value.money,
    badges: [...value.badges],
    seen: [...value.seen],
    caught: [...value.caught],
    flags,
    steps: value.steps,
    battle: null
  };
}

export function serializeSave(state) {
  if (state.battle) throw new Error('전투를 마친 뒤 진행 상황을 저장해 주세요.');
  return JSON.stringify(validateSave(state), null, 2);
}
