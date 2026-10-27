import test from 'node:test';
import assert from 'node:assert/strict';
import {
  TYPE_CHART, SPECIES, MOVES, createGame, rescueRalts, chooseStarter,
  startBattle, battleAction, healParty, buyItem, validateSave, serializeSave, getObjective
} from '../src/engine.mjs';

function journey(starter = 'hwarangi') {
  const state = createGame();
  rescueRalts(state);
  chooseStarter(state, starter);
  return state;
}

function caughtState() {
  const state = journey();
  startBattle(state, 'wild', 'pidgey');
  battleAction(state, { type: 'ball' }, () => 0);
  state.battle = null;
  return state;
}

test('프롤로그는 랄토스 구조 후 스타팅 한 마리를 선택하여 두 마리로 출발한다', () => {
  const state = createGame();
  assert.equal(chooseStarter(state, 'hwarangi').ok, false);
  assert.equal(startBattle(state, 'wild').ok, false);
  assert.equal(rescueRalts(state).ok, true);
  assert.equal(state.party[0].species, 'ralts');
  assert.equal(state.party[0].shiny, true);
  assert.equal(rescueRalts(state).ok, false);
  assert.equal(chooseStarter(state, 'pidgey').ok, false);
  assert.equal(chooseStarter(state, 'purunae').ok, true);
  assert.deepEqual(state.party.map(mon => mon.species), ['ralts', 'purunae']);
  assert.equal(chooseStarter(state, 'padoring').ok, false);
  assert.equal(state.stage, 'journey');
});

test('18타입 상성은 무효와 배율을 구분한다', () => {
  assert.equal(Object.keys(TYPE_CHART).length, 18);
  assert.equal(TYPE_CHART.normal.ghost, 0);
  assert.equal(TYPE_CHART.electric.ground, 0);
  assert.equal(TYPE_CHART.dragon.fairy, 0);
  assert.equal(TYPE_CHART.fire.grass, 2);
  assert.equal(TYPE_CHART.fairy.steel, 0.5);
  assert.equal(TYPE_CHART.ghost.psychic, 2);
});

test('첫 포획 전 체육관이 잠겨 있고 잘못된 야생 종류를 거부한다', () => {
  const state = journey();
  assert.equal(startBattle(state, 'gym').ok, false);
  assert.equal(startBattle(state, 'wild', 'pidgeotto').ok, false);
  assert.equal(startBattle(state, 'unknown').ok, false);
  assert.equal(state.battle, null);
});

test('전투에서 PP를 소모하고 양쪽 체력이 줄며 중복 전투를 막는다', () => {
  const state = journey();
  startBattle(state, 'wild', 'pidgey');
  const pp = state.party[0].moves[0].pp;
  assert.equal(startBattle(state, 'wild').ok, false);
  const result = battleAction(state, { type: 'move', index: 0 }, () => 0.5);
  assert.equal(result.ok, true);
  assert.equal(state.party[0].moves[0].pp, pp - 1);
  assert.ok(state.party[0].hp < state.party[0].maxHp);
  assert.ok(state.battle.enemy.hp < state.battle.enemy.maxHp);
  assert.equal(state.battle.turn, 1);
  assert.ok(result.logs.some(line => line.includes('염동력')));
});

test('효과가 좋은 불꽃 공격은 벌레에게 더 큰 데미지를 준다', () => {
  const state = journey();
  startBattle(state, 'wild', 'caterpie');
  state.battle.active = 1;
  const result = battleAction(state, { type: 'move', index: 0 }, () => 0.5);
  assert.ok(result.logs.includes('효과가 굉장했다!'));
});

test('PP 부족과 잘못된 행동은 턴과 상대 공격을 발생시키지 않는다', () => {
  const state = journey();
  startBattle(state, 'wild', 'caterpie');
  state.party[0].moves[0].pp = 0;
  const before = structuredClone(state);
  for (const action of [null, { type: 'move', index: 0 }, { type: 'move', index: 99 }, { type: 'switch', index: 0 }, { type: 'switch', index: 99 }, { type: 'oops' }]) {
    assert.equal(battleAction(state, action).ok, false);
    assert.deepEqual(state, before);
  }
});

test('모든 PP가 소진되면 발버둥과 반동으로 전투를 계속할 수 있다', () => {
  const state = journey();
  startBattle(state, 'wild', 'caterpie');
  state.party[0].moves.forEach(move => { move.pp = 0; });
  const result = battleAction(state, { type: 'move', index: 0 }, () => 0.5);
  assert.ok(result.logs.some(line => line.includes('발버둥')));
  assert.ok(result.logs.some(line => line.includes('반동')));
  assert.ok(state.party[0].hp < state.party[0].maxHp);
});

test('포획 실패는 볼을 소모하고 반격하며 성공하면 동료와 기록에 추가된다', () => {
  const state = journey();
  startBattle(state, 'wild', 'pidgey');
  assert.equal(battleAction(state, { type: 'ball' }, () => 0.99).ok, true);
  assert.equal(state.bag.balls, 7);
  assert.equal(state.battle.outcome, null);
  assert.ok(state.party[0].hp < state.party[0].maxHp);
  battleAction(state, { type: 'ball' }, () => 0);
  assert.equal(state.bag.balls, 6);
  assert.equal(state.battle.outcome, 'caught');
  assert.equal(state.party.length, 3);
  assert.equal(state.flags.firstCapture, true);
  assert.ok(state.seen.includes('pidgey'));
  assert.ok(state.caught.includes('pidgey'));
  assert.equal(battleAction(state, { type: 'move', index: 0 }).ok, false);
});

test('동료 6마리 이후 포획은 박스로 보내며 모두 저장 검증을 통과한다', () => {
  const state = journey();
  for (let index = 0; index < 5; index += 1) {
    state.steps += 1;
    startBattle(state, 'wild', index % 2 === 0 ? 'pidgey' : 'caterpie');
    battleAction(state, { type: 'ball' }, () => 0);
    state.battle = null;
  }
  assert.equal(state.party.length, 6);
  assert.equal(state.box.length, 1);
  assert.doesNotThrow(() => validateSave(serializeSave(state)));
});

test('체육관에서는 포획과 도주가 금지되며 볼과 턴을 소모하지 않는다', () => {
  const state = caughtState();
  startBattle(state, 'gym');
  const before = structuredClone(state);
  assert.equal(battleAction(state, { type: 'ball' }).ok, false);
  assert.equal(battleAction(state, { type: 'run' }).ok, false);
  assert.deepEqual(state, before);
});

test('상처약은 소모되며 회복 상한을 넘지 않고 반격이 이어진다', () => {
  const state = journey();
  startBattle(state, 'wild', 'caterpie');
  assert.equal(battleAction(state, { type: 'potion' }).ok, false);
  state.party[0].hp = 5;
  const result = battleAction(state, { type: 'potion' }, () => 0.5);
  assert.equal(state.bag.potions, 4);
  assert.ok(state.party[0].hp > 5);
  assert.ok(state.party[0].hp <= state.party[0].maxHp);
  assert.ok(result.logs.some(line => line.includes('회복')));
});

test('교체하면 능력 단계가 초기화되고 새 동료가 반격을 받는다', () => {
  const state = journey();
  startBattle(state, 'wild', 'pidgey');
  state.battle.stages.player.attack = -4;
  battleAction(state, { type: 'switch', index: 1 }, () => 0.5);
  assert.equal(state.battle.active, 1);
  assert.equal(state.battle.stages.player.attack, 0);
  assert.equal(state.party[0].hp, state.party[0].maxHp);
  assert.ok(state.party[1].hp < state.party[1].maxHp);
});

test('능력 저하 기술과 화상 피해가 전투 상태에 적용된다', () => {
  const state = journey();
  startBattle(state, 'wild', 'pidgey');
  battleAction(state, { type: 'move', index: 2 }, () => 0.5);
  assert.equal(state.battle.stages.enemy.attack, -1);
  state.party[0].status = 'burn';
  const result = battleAction(state, { type: 'move', index: 2 }, () => 0.5);
  assert.ok(result.logs.some(line => line.includes('화상')));
});

test('기절한 동료 대신 살아 있는 동료가 나오고 이전 동료의 기술은 발동하지 않는다', () => {
  const state = caughtState();
  startBattle(state, 'gym');
  state.party[0].hp = 1;
  const pp = state.party[1].moves[0].pp;
  battleAction(state, { type: 'move', index: 0 }, () => 0.5);
  assert.equal(state.party[0].hp, 0);
  assert.equal(state.battle.active, 1);
  assert.equal(state.party[1].moves[0].pp, pp);
  assert.equal(state.battle.outcome, null);
});

test('전멸하면 돈을 잃지 않고 센터에서 회복하여 재도전할 수 있다', () => {
  const state = caughtState();
  state.area = 'suwon';
  startBattle(state, 'gym');
  state.party.forEach(mon => { mon.hp = 0; });
  state.party[0].hp = 1;
  const money = state.money;
  battleAction(state, { type: 'move', index: 0 }, () => 0.5);
  assert.equal(state.battle.outcome, 'lost');
  assert.equal(state.money, money);
  assert.ok(state.party.every(mon => mon.hp === mon.maxHp));
  assert.equal(state.area, 'suwon');
  state.battle = null;
  assert.equal(startBattle(state, 'gym').ok, true);
});

test('승리 시 경험치·보상·배지를 지급하고 같은 배지를 중복 지급하지 않는다', () => {
  const state = caughtState();
  for (let index = 0; index < 2; index += 1) {
    startBattle(state, 'gym');
    state.battle.enemy.hp = 1;
    battleAction(state, { type: 'move', index: 0 }, () => 0.5);
    assert.equal(state.battle.outcome, 'won');
    state.battle = null;
    healParty(state);
  }
  assert.deepEqual(state.badges, ['성곽배지']);
  assert.equal(state.stage, 'complete');
  assert.equal(state.flags.gymWon, true);
  assert.ok(state.party[0].level > 5);
  assert.equal(state.money, 2500);
  assert.doesNotThrow(() => validateSave(serializeSave(state)));
});

test('세 스타팅 모두 체육관을 정상 행동으로 이길 수 있다', () => {
  for (const starter of ['purunae', 'hwarangi', 'padoring']) {
    const state = journey(starter);
    startBattle(state, 'wild', 'caterpie');
    battleAction(state, { type: 'ball' }, () => 0);
    state.battle = null;
    startBattle(state, 'gym');
    for (let turn = 0; turn < 50 && !state.battle.outcome; turn += 1) {
      const active = state.party[state.battle.active];
      const action = active.hp < 15 && state.bag.potions > 0 ? { type: 'potion' } : { type: 'move', index: 0 };
      battleAction(state, action, () => 0.5);
    }
    assert.equal(state.battle.outcome, 'won', starter);
  }
});

test('도주 성공은 반격 없이 끝나고 실패는 반격을 받는다', () => {
  const state = journey();
  startBattle(state, 'wild', 'pidgey');
  battleAction(state, { type: 'run' }, () => 0.99);
  assert.equal(state.battle.outcome, null);
  const hp = state.party[0].hp;
  battleAction(state, { type: 'run' }, () => 0);
  assert.equal(state.battle.outcome, 'escaped');
  assert.equal(state.party[0].hp, hp);
});

test('센터는 HP·PP·상태이상을 회복하고 상점은 잔액과 가방을 변경한다', () => {
  const state = journey();
  state.party[0].hp = 0;
  state.party[0].moves[0].pp = 0;
  state.party[0].status = 'poison';
  healParty(state);
  assert.equal(state.party[0].hp, state.party[0].maxHp);
  assert.equal(state.party[0].moves[0].pp, MOVES.confusion.pp);
  assert.equal(state.party[0].status, null);
  assert.equal(buyItem(state, 'balls').ok, true);
  assert.equal(state.money, 1300);
  assert.equal(state.bag.balls, 9);
  assert.equal(buyItem(state, 'bad').ok, false);
  assert.equal(buyItem(state, '__proto__').ok, false);
  assert.equal(buyItem(state, 'constructor').ok, false);
  state.money = 0;
  assert.equal(buyItem(state, 'potions').ok, false);
  startBattle(state, 'wild');
  assert.equal(healParty(state).ok, false);
  assert.equal(buyItem(state, 'balls').ok, false);
});

test('저장 파일은 새 객체로 복구되고 알 수 없는 필드와 이름을 보존하지 않는다', () => {
  const state = caughtState();
  state.extra = 'not persisted';
  state.party[0].name = '<script>bad</script>';
  state.flags.extra = true;
  const decoded = validateSave(serializeSave(state));
  assert.equal(decoded.party[0].name, SPECIES.ralts.name);
  assert.equal(decoded.extra, undefined);
  assert.equal(decoded.flags.extra, undefined);
  decoded.bag.balls = 0;
  assert.notEqual(state.bag.balls, decoded.bag.balls);
  assert.doesNotThrow(() => validateSave(serializeSave(createGame())));
  const rescued = createGame();
  rescueRalts(rescued);
  assert.doesNotThrow(() => validateSave(serializeSave(rescued)));
});

test('전투 중 저장을 거부한다', () => {
  const state = journey();
  startBattle(state, 'wild');
  assert.throws(() => serializeSave(state), /전투/);
  assert.throws(() => validateSave(JSON.stringify(state)), /전투/);
});

test('손상·조작·버전 불일치 저장 파일을 구체적으로 거부한다', () => {
  assert.throws(() => validateSave('{broken'), /JSON/);
  assert.throws(() => validateSave(null));
  assert.throws(() => validateSave(' '.repeat(200001)), /너무 큽니다/);
  const mutations = [
    state => { state.version = 99; },
    state => { state.stage = 'complete'; },
    state => { state.area = '__proto__'; },
    state => { state.player.x = Infinity; },
    state => { state.player.facing = 'elsewhere'; },
    state => { state.party[0].species = '__proto__'; },
    state => { state.party[0].hp = 999; },
    state => { state.party[0].level = 100; },
    state => { state.party[0].moves[0].id = 'ember'; },
    state => { state.party[0].moves[0].pp = -1; },
    state => { state.party[0].xp = -1; },
    state => { state.party[0].status = 'unknown'; },
    state => { state.party[0].shiny = false; },
    state => { state.party[1].uid = state.party[0].uid; },
    state => { state.bag.balls = -1; },
    state => { state.money = 1.2; },
    state => { state.flags.rescued = false; },
    state => { state.badges.push('가짜배지'); },
    state => { state.seen = []; },
    state => { state.caught.push('missing'); },
    state => { state.party = []; }
  ];
  for (const mutate of mutations) {
    const state = caughtState();
    mutate(state);
    assert.throws(() => validateSave(state), mutate.toString());
  }
});

test('진행 목표는 현재 단계에 맞게 바뀐다', () => {
  const state = createGame();
  assert.match(getObjective(state), /랄토스/);
  rescueRalts(state);
  assert.match(getObjective(state), /연구소/);
  chooseStarter(state, 'padoring');
  assert.match(getObjective(state), /잡아/);
  startBattle(state, 'wild', 'caterpie');
  battleAction(state, { type: 'ball' }, () => 0);
  state.battle = null;
  assert.match(getObjective(state), /이도윤/);
});
