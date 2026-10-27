// 한국풍 필드. 지형과 건물은 한 번 그려 두고 물결·꽃잎·캐릭터만 갱신합니다.
export const WORLD_WIDTH = 960;
export const WORLD_HEIGHT = 640;
export const TILE = 32;

export const AREAS = {
  incheon: { name: '인천 · 벚꽃 마을', subtitle: '모든 인연이 시작되는 곳' },
  route: { name: '수원으로 가는 길', subtitle: '바람이 머무는 풀숲' },
  suwon: { name: '수원 · 성곽 마을', subtitle: '첫 번째 배지를 향하여' },
};

const BACKGROUNDS = new Map();
const TREE_LAYERS = new Map();
const TAU = Math.PI * 2;

const buildings = {
  incheon: [
    { x: 4.5, y: 3.6, w: 5.2, h: 3.8, label: '백서화 연구소', type: 'lab' },
    { x: 3.3, y: 14.2, w: 4.3, h: 3.6, label: '', type: 'house' },
    { x: 24.1, y: 13.2, w: 4.3, h: 3.6, label: '', type: 'house' },
  ],
  route: [],
  suwon: [
    { x: 4.4, y: 3.6, w: 5.2, h: 3.8, label: '포켓몬 센터', type: 'center' },
    { x: 17.1, y: 3.1, w: 6.4, h: 4.3, label: '수원 체육관', type: 'gym' },
    { x: 12.9, y: 1.6, w: 4.2, h: 2.9, label: '유물 전시관', type: 'museum' },
    { x: 10.3, y: 11.2, w: 3.5, h: 2.2, label: '여행 상점', type: 'shop' },
  ],
};

function noise(a, b = 0) {
  const v = Math.sin(a * 127.1 + b * 311.7) * 43758.5453;
  return v - Math.floor(v);
}

function rounded(ctx, x, y, w, h, r, fill, stroke) {
  ctx.beginPath();
  ctx.roundRect(x, y, w, h, r);
  if (fill) { ctx.fillStyle = fill; ctx.fill(); }
  if (stroke) { ctx.strokeStyle = stroke; ctx.stroke(); }
}

function ellipse(ctx, x, y, rx, ry, fill, rotation = 0) {
  ctx.beginPath();
  ctx.ellipse(x, y, rx, ry, rotation, 0, TAU);
  ctx.fillStyle = fill;
  ctx.fill();
}

function line(ctx, points, color, width = 1) {
  ctx.beginPath();
  points.forEach(([x, y], i) => i ? ctx.lineTo(x, y) : ctx.moveTo(x, y));
  ctx.strokeStyle = color;
  ctx.lineWidth = width;
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';
  ctx.stroke();
}

function polygon(ctx, points, fill, stroke) {
  ctx.beginPath();
  points.forEach(([x, y], i) => i ? ctx.lineTo(x, y) : ctx.moveTo(x, y));
  ctx.closePath();
  ctx.fillStyle = fill;
  ctx.fill();
  if (stroke) { ctx.strokeStyle = stroke; ctx.stroke(); }
}

function inRect(x, y, r, margin = 0) {
  return x > r.x - margin && x < r.x + r.w + margin &&
    y > r.y - margin && y < r.y + r.h + margin;
}

function getTrees(area) {
  const trees = [];
  // 맵 가장자리는 큰 나무로 감싸고 주요 통로는 비워 둡니다.
  for (let i = 0; i < 16; i++) {
    const x = 0.1 + i * 1.95;
    if (area !== 'suwon' || x < 4 || x > 25) {
      trees.push({ x, y: 0.7 + noise(i, 1) * 0.9, pink: i % 3 !== 0, scale: 0.9 + noise(i) * 0.25 });
    }
    trees.push({ x, y: 19.8 + noise(i, 5) * 0.4, pink: i % 4 !== 0, scale: 1 + noise(i, 3) * 0.2 });
  }
  for (let i = 0; i < 7; i++) {
    const y = 2.5 + i * 2.3;
    if (Math.abs(y - 10) > 1.8) {
      trees.push({ x: -0.2, y, pink: i % 2 === 0, scale: 1.2 });
      trees.push({ x: 29.8, y, pink: i % 3 !== 0, scale: 1.15 });
    }
  }
  const interior = {
    incheon: [[2.5, 5, 1], [10.8, 4.8, 1], [3, 10, 1], [10.3, 16.7, 1], [16.3, 5.5, 1],
      [22.5, 3, 0], [27, 4.1, 1], [26.7, 7.7, 0], [22.1, 15.8, 1], [16, 17.7, 0]],
    route: [[3, 4.7, 0], [5.4, 6, 1], [2.7, 15.6, 0], [6, 17, 1], [10, 2.2, 0],
      [17, 2.9, 1], [23.4, 4, 0], [27.7, 6, 1], [25, 16.7, 0], [20, 18, 1], [13, 18.2, 0]],
    suwon: [[2.7, 4.7, 1], [10.5, 5.5, 1], [25.5, 5.2, 1], [3, 14.8, 1],
      [6.5, 16.9, 0], [17.5, 16.8, 1], [25.7, 16, 1], [21, 12.9, 1]],
  };
  for (const [x, y, pink] of interior[area] || []) trees.push({ x, y, pink: !!pink, scale: 1 });
  return trees;
}

const TREES = Object.fromEntries(Object.keys(AREAS).map(area => [area, getTrees(area)]));

export function getInteractions(state) {
  if (state.area === 'incheon') {
    const list = [
      { id: 'lab', label: '백서화 연구소', x: 7, y: 8, kind: 'building' },
      { id: 'harin', label: '서하린', x: 15, y: 12, kind: 'person' },
      { id: 'gate', label: '수원으로 가는 길', x: 28, y: 10, kind: 'exit' },
    ];
    if (state.stage === 'prologue') list.push({ id: 'ralts', label: '작은 울음소리', x: 23, y: 5, kind: 'quest' });
    return list;
  }
  if (state.area === 'route') return [
    { id: 'gateBack', label: '인천으로', x: 1, y: 10, kind: 'exit' },
    { id: 'gate', label: '수원 성곽 마을', x: 28, y: 10, kind: 'exit' },
    { id: 'healer', label: '길 위의 쉼터', x: 4, y: 10, kind: 'person' },
  ];
  return [
    { id: 'gateBack', label: '인천 방면', x: 1, y: 10, kind: 'exit' },
    { id: 'gym', label: '수원 체육관', x: 20, y: 8, kind: 'building' },
    { id: 'center', label: '포켓몬 센터', x: 7, y: 8, kind: 'building' },
    { id: 'shop', label: '여행 상점', x: 12, y: 14, kind: 'building' },
    { id: 'museum', label: '유물 전시관', x: 15, y: 5, kind: 'building' },
  ];
}

export function canWalk(area, x, y) {
  if (!AREAS[area] || !Number.isFinite(x) || !Number.isFinite(y)) return false;
  if (x < 0.65 || x > 28.45 || y < 1.9 || y > 18.45) return false;
  for (const building of buildings[area]) {
    if (inRect(x, y, building, 0.12)) return false;
  }
  for (const tree of TREES[area]) {
    if (Math.hypot(x - tree.x, y - tree.y) < 0.32 * tree.scale) return false;
  }
  if (area === 'incheon' && x > 18 && x < 20.6 && (y < 9 || y > 11.2)) return false;
  if (area === 'route' && x > 24.7 && x < 26.4 && (y < 9 || y > 11.2)) return false;
  if (area === 'suwon' && Math.hypot(x - 14.3, (y - 10.2) * 1.3) < 1.15) return false;
  return true;
}

export function isGrass(area, x, y) {
  return area === 'route' && x >= 8 && x <= 22 && ((y >= 4 && y <= 8) || (y >= 12 && y <= 16));
}

function drawGround(ctx, area) {
  const grad = ctx.createLinearGradient(0, 0, WORLD_WIDTH, WORLD_HEIGHT);
  grad.addColorStop(0, '#5b9270');
  grad.addColorStop(0.45, '#91b77b');
  grad.addColorStop(1, '#497f65');
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, WORLD_WIDTH, WORLD_HEIGHT);
  for (let i = 0; i < 2200; i++) {
    const x = noise(i, 3) * WORLD_WIDTH;
    const y = noise(i, 9) * WORLD_HEIGHT;
    ellipse(ctx, x, y, 1 + noise(i, 1) * 2, 0.5 + noise(i, 2), i % 3 ? '#a8c48a36' : '#245d4f25');
  }
  if (area === 'route') {
    drawPath(ctx, 0, 9, 30, 3, false);
    drawPath(ctx, 14, 2, 2.5, 17, false);
    for (let y = 4; y <= 16; y++) {
      if (y > 8 && y < 12) continue;
      for (let x = 8; x <= 22; x++) drawGrassTile(ctx, x, y);
    }
  } else {
    drawPath(ctx, 12.7, 2, 3.6, 18, true);
    drawPath(ctx, 0, 9, 30, 3, true);
    drawPath(ctx, 6, 7.3, 2.5, 3.2, true);
    if (area === 'incheon') drawPath(ctx, 22, 4.8, 2.3, 6.1, false);
    if (area === 'suwon') {
      drawPath(ctx, 18.8, 7, 3, 3.5, true);
      drawPath(ctx, 11, 13, 3, 3, true);
    }
  }
  for (let i = 0; i < 150; i++) {
    const x = 20 + noise(i, 13) * 920;
    const y = 44 + noise(i, 14) * 560;
    if (noise(i, 16) > 0.5 && canWalk(area, x / TILE, y / TILE)) {
      drawFlower(ctx, x, y, ['#ffe8ea', '#fff0b1', '#e4c9f9'][i % 3], 1.4);
    }
  }
}

function drawPath(ctx, tx, ty, tw, th, stone) {
  const x = tx * TILE, y = ty * TILE, w = tw * TILE, h = th * TILE;
  rounded(ctx, x - 5, y - 5, w + 10, h + 10, 16, '#61775364');
  rounded(ctx, x, y, w, h, 10, stone ? '#d4c9ac' : '#c5b78d');
  ctx.save();
  ctx.beginPath();ctx.roundRect(x, y, w, h, 10);ctx.clip();
  for (let yy = y; yy < y + h; yy += 21) {
    for (let xx = x - 20; xx < x + w; xx += 29) {
      const offset = Math.round(yy / 21) % 2 ? 14 : 0;
      const n = noise(xx, yy);
      if (stone) {
        rounded(ctx, xx + offset + 1, yy + 1, 27, 19, 3,
          ['#ddd3b9', '#cec5ac', '#e4d8bc', '#d7ccaf'][Math.floor(n * 4)], '#b3aa914a');
        line(ctx, [[xx + offset + 5, yy + 3], [xx + offset + 24, yy + 3]], '#f1e7ce80');
      } else if (n > 0.5) {
        ellipse(ctx, xx + offset, yy, 1.8, 1, '#897f5e50');
      }
    }
  }
  ctx.restore();
}

function drawGrassTile(ctx, x, y) {
  const px = x * TILE, py = y * TILE;
  rounded(ctx, px, py, TILE + 1, TILE + 1, 3, '#63965a');
  for (let i = 0; i < 7; i++) {
    const gx = px + 3 + noise(x * 7 + i, y) * 26;
    const gy = py + 8 + noise(x, y * 7 + i) * 24;
    const h = 6 + noise(i + y, x) * 7;
    line(ctx, [[gx - 4, gy - h + 3], [gx, gy], [gx + 4, gy - h]], '#3b764c', 2);
    line(ctx, [[gx, gy], [gx - 1, gy - h]], '#a3c578', 1.5);
  }
}

function drawFlower(ctx, x, y, color = '#f5b6ca', r = 2.3) {
  for (let j = 0; j < 5; j++) {
    const a = j / 5 * TAU;
    ellipse(ctx, x + Math.cos(a) * r, y + Math.sin(a) * r, r, r * 0.75, color, a);
  }
  ellipse(ctx, x, y, r * 0.65, r * 0.65, '#f8dc8d');
}

function drawRiver(ctx, area) {
  if (area === 'suwon') return;
  const x = area === 'incheon' ? 18.2 * TILE : 24.9 * TILE;
  const width = area === 'incheon' ? 2.5 * TILE : 1.65 * TILE;
  const water = ctx.createLinearGradient(x, 0, x + width, 0);
  water.addColorStop(0, '#365e63');water.addColorStop(0.22, '#589b9a');
  water.addColorStop(0.65, '#72b6b2');water.addColorStop(1, '#3f8086');
  ctx.fillStyle = '#8d967a';ctx.fillRect(x - 10, 0, width + 20, WORLD_HEIGHT);
  ctx.fillStyle = water;ctx.fillRect(x, 0, width, WORLD_HEIGHT);
  for (let y = 0; y < WORLD_HEIGHT; y += 25) {
    ellipse(ctx, x - 4, y, 10, 9, y % 2 ? '#929a84' : '#b8b6a0');
    ellipse(ctx, x + width + 4, y + 12, 9, 8, '#9ca38d');
  }
  for (let i = 0; i < 16; i++) {
    const lx = x + 12 + noise(i, 8) * (width - 24);
    const ly = noise(i, 19) * WORLD_HEIGHT;
    if (ly > 280 && ly < 370) continue;
    ellipse(ctx, lx, ly, 6, 3, '#558d6e');
    if (i % 4 === 0) drawFlower(ctx, lx, ly - 2, '#ffe1e8', 1.6);
  }
  drawBridge(ctx, x, 9 * TILE, width, 3 * TILE);
}

function drawBridge(ctx, x, y, w, h) {
  rounded(ctx, x - 19, y + 3, w + 38, h + 4, 7, '#314d4e44');
  rounded(ctx, x - 12, y, w + 24, h, 5, '#d9d1b9');
  for (let i = 0; i < h; i += 16) line(ctx, [[x - 10, y + i], [x + w + 10, y + i]], '#bcb59f', 1);
  for (const yy of [y - 2, y + h - 1]) {
    line(ctx, [[x - 18, yy], [x + w + 18, yy]], '#b5b6a5', 6);
    line(ctx, [[x - 18, yy - 5], [x + w + 18, yy - 5]], '#eee4cb', 5);
    for (let xx = x - 14; xx <= x + w + 15; xx += 21) {
      rounded(ctx, xx - 3, yy - 15, 6, 18, 1, '#c5c5af');
      ellipse(ctx, xx, yy - 16, 5, 3, '#ece6d0');
    }
  }
}

function drawBuilding(ctx, b) {
  const x = b.x * TILE, y = b.y * TILE, w = b.w * TILE, h = b.h * TILE;
  const roofH = h * 0.58;
  ctx.save();
  ellipse(ctx, x + w / 2 + 10, y + h + 8, w * 0.61, 14, '#294c4645');
  rounded(ctx, x - 6, y + h - 12, w + 12, 21, 3, '#b7b6a3');
  rounded(ctx, x - 9, y + h, w + 18, 7, 2, '#d9d5bf');
  rounded(ctx, x, y + roofH * 0.65, w, h - roofH * 0.65 - 6, 2, '#e9dfc3');
  ctx.fillStyle = '#8b5f49';ctx.fillRect(x, y + roofH + 5, w, 8);
  const pillars = b.type === 'gym' ? 6 : 4;
  for (let i = 0; i < pillars; i++) {
    const px = x + 8 + i * (w - 16) / (pillars - 1);
    ctx.fillStyle = '#78533f';ctx.fillRect(px - 4, y + roofH - 8, 8, h - roofH + 2);
    ctx.fillStyle = '#bc8860';ctx.fillRect(px - 3, y + roofH - 8, 2, h - roofH + 2);
    rounded(ctx, px - 7, y + h - 9, 14, 7, 2, '#c9c6af');
  }
  for (const side of [-1, 1]) {
    const wx = x + w / 2 + side * w * 0.31 - 14;
    rounded(ctx, wx, y + h * 0.57, 28, h * 0.26, 1, '#d8c798', '#795944');
    for (let xx = wx + 6; xx < wx + 28; xx += 7) line(ctx, [[xx, y + h * 0.57], [xx, y + h * 0.83]], '#927358', 1.5);
    line(ctx, [[wx, y + h * 0.7], [wx + 28, y + h * 0.7]], '#927358', 1.5);
  }
  rounded(ctx, x + w / 2 - 19, y + h * 0.49, 38, h * 0.45, 2, '#524a3f', '#b8875b');
  line(ctx, [[x + w / 2, y + h * 0.49], [x + w / 2, y + h * 0.94]], '#bda379', 2);
  ellipse(ctx, x + w / 2 - 5, y + h * 0.76, 1.7, 1.7, '#e5c17a');
  ellipse(ctx, x + w / 2 + 5, y + h * 0.76, 1.7, 1.7, '#e5c17a');
  // 완만하게 들린 처마와 기와 선이 한옥 실루엣을 만듭니다.
  const roofColor = b.type === 'center' ? '#735667' : '#334d64';
  const roof = [[x - 18, y + roofH + 3], [x - 8, y + roofH - 11], [x + w * 0.23, y + 6],
    [x + w * 0.5, y], [x + w * 0.77, y + 6], [x + w + 8, y + roofH - 11], [x + w + 18, y + roofH + 3]];
  polygon(ctx, roof, roofColor, '#243a4c');
  for (let i = 0; i < 26; i++) {
    const t = i / 25;
    const topX = x + w * (0.23 + t * 0.54);
    const bottomX = x - 15 + t * (w + 30);
    line(ctx, [[topX, y + 6], [bottomX, y + roofH - 1]], i % 2 ? '#628291' : '#526d7e', 2);
    ellipse(ctx, bottomX, y + roofH + 2, 2.3, 2.2, '#89a0a2');
  }
  for (let i = 1; i <= 4; i++) {
    const t = i / 5;
    const inset = (1 - t) * w * 0.2;
    line(ctx, [[x + inset - 8 * t, y + roofH * t + 5], [x + w - inset + 8 * t, y + roofH * t + 5]], '#20394b55', 1);
  }
  line(ctx, [[x - 18, y + roofH + 3], [x + w / 2, y + roofH + 9], [x + w + 18, y + roofH + 3]], '#233849', 5);
  line(ctx, [[x + w * 0.21, y + 5], [x + w / 2, y - 1], [x + w * 0.79, y + 5]], '#97a8a6', 5);
  for (let i = 0; i < 4; i++) {
    const xx = x + 10 + i * (w - 20) / 3;
    rounded(ctx, xx - 8, y + roofH + 6, 16, 9, 2, '#547f74');
    ellipse(ctx, xx, y + roofH + 11, 3, 2, '#c4ac6e');
  }
  if (b.label) {
    const signW = Math.min(w - 15, b.label.length * 10 + 20);
    rounded(ctx, x + w / 2 - signW / 2, y + roofH + 7, signW, 20, 3, '#263f46', '#d9c598');
    ctx.font = '600 11px sans-serif';ctx.textAlign = 'center';ctx.textBaseline = 'middle';
    ctx.fillStyle = '#fff0c9';ctx.fillText(b.label, x + w / 2, y + roofH + 17);
  }
  if (b.type === 'center') {
    ellipse(ctx, x + w / 2, y + roofH * 0.43, 12, 10, '#eee7d6');
    ctx.fillStyle = '#bc626d';ctx.fillRect(x + w / 2 - 2, y + roofH * 0.43 - 7, 4, 14);
    ctx.fillRect(x + w / 2 - 7, y + roofH * 0.43 - 2, 14, 4);
  }
  if (b.type === 'gym') {
    ellipse(ctx, x + w / 2, y + roofH * 0.4, 13, 10, '#bca779');
    polygon(ctx, [[x + w / 2 - 7, y + roofH * 0.4 + 5], [x + w / 2 - 7, y + roofH * 0.4 - 5],
      [x + w / 2 - 2, y + roofH * 0.4 - 5], [x + w / 2 - 2, y + roofH * 0.4 - 1],
      [x + w / 2 + 2, y + roofH * 0.4 - 1], [x + w / 2 + 2, y + roofH * 0.4 - 5],
      [x + w / 2 + 7, y + roofH * 0.4 - 5], [x + w / 2 + 7, y + roofH * 0.4 + 5]], '#3e5960');
  }
  ctx.restore();
}

function drawTree(ctx, tree, local = false) {
  const x = local ? 58 : tree.x * TILE + 16;
  const y = local ? 112 : tree.y * TILE + 16;
  const s = tree.scale;
  ctx.save();ctx.translate(x, y);ctx.scale(s, s);
  ellipse(ctx, 10, 4, 36, 13, '#234a3c38');
  polygon(ctx, [[-6, 0], [-4, -40], [-12, -66], [-5, -53], [1, -34], [8, -58], [6, -24], [7, 0]], '#755744');
  line(ctx, [[-3, -2], [-1, -38], [-8, -57]], '#a1815b', 2);
  const colors = tree.pink ? ['#c47b99', '#e89bb5', '#f4bdd0', '#ffdae4', '#ffe9e8'] : ['#2c654f', '#3f8058', '#589567', '#7ca974', '#9abd81'];
  const clusters = [[-24, -49, 25], [23, -50, 23], [0, -71, 31], [-11, -40, 25], [16, -32, 24], [-31, -29, 16], [34, -32, 17], [0, -49, 29]];
  clusters.forEach(([cx, cy, r], i) => {
    ellipse(ctx, cx, cy + 5, r, r * 0.72, colors[0]);
    const grad = ctx.createRadialGradient(cx - 7, cy - 8, 2, cx, cy, r);
    grad.addColorStop(0, colors[3]);grad.addColorStop(0.7, colors[2]);grad.addColorStop(1, colors[1]);
    ellipse(ctx, cx, cy, r, r * 0.73, grad);
    for (let j = 0; j < 12; j++) {
      const a = noise(i * 12 + j, 4) * TAU;
      const rr = noise(i, j) * r * 0.8;
      const fx = cx + Math.cos(a) * rr, fy = cy + Math.sin(a) * rr * 0.7;
      if (tree.pink) drawFlower(ctx, fx, fy, j % 2 ? '#ffe7ed' : '#eda2c0', 1.7);
      else ellipse(ctx, fx, fy, 4, 2, j % 2 ? '#a0be80' : '#649f65', -0.4);
    }
  });
  ctx.restore();
}

function treeLayer(tree) {
  const key = `${tree.pink}-${tree.scale.toFixed(2)}`;
  if (TREE_LAYERS.has(key)) return TREE_LAYERS.get(key);
  const canvas = document.createElement('canvas');
  canvas.width = 128;canvas.height = 140;
  drawTree(canvas.getContext('2d'), tree, true);
  TREE_LAYERS.set(key, canvas);
  return canvas;
}

function drawLantern(ctx, x, y, night = false) {
  ellipse(ctx, x + 3, y, 8, 3, '#244c3f44');
  rounded(ctx, x - 3, y - 35, 6, 35, 2, '#6f6554');
  rounded(ctx, x - 8, y - 41, 16, 15, 3, '#f0dba3', '#9e8965');
  line(ctx, [[x - 9, y - 42], [x, y - 47], [x + 9, y - 42]], '#445b5e', 5);
  line(ctx, [[x, y - 40], [x, y - 27]], '#baa373', 1);
  if (night) {
    const glow = ctx.createRadialGradient(x, y - 34, 1, x, y - 34, 42);
    glow.addColorStop(0, '#ffda7770');glow.addColorStop(1, '#ffcc6600');
    ellipse(ctx, x, y - 34, 42, 42, glow);
  }
}

function drawWall(ctx) {
  const y = 44;
  rounded(ctx, 68, y, 824, 34, 2, '#9eaa9c');
  for (let yy = y; yy < y + 34; yy += 11) {
    for (let x = 68 + (yy % 2) * 10; x < 890; x += 25) {
      rounded(ctx, x, yy, 23, 10, 1, noise(x, yy) > 0.5 ? '#bcc2b0' : '#aeb7a7', '#83988a50');
    }
  }
  for (let x = 65; x < 895; x += 27) rounded(ctx, x, y - 11, 17, 14, 1, '#d0d1bd');
  line(ctx, [[65, y + 34], [895, y + 34]], '#698274', 3);
}

function drawFountain(ctx) {
  const x = 14.3 * TILE + 16, y = 10.2 * TILE + 16;
  ellipse(ctx, x + 6, y + 8, 40, 25, '#47635440');
  ellipse(ctx, x, y, 39, 26, '#acae96');
  ellipse(ctx, x, y - 4, 35, 23, '#e0d9bc');
  ellipse(ctx, x, y - 5, 29, 17, '#74aaa3');
  ellipse(ctx, x, y - 5, 22, 12, '#a9d0c0');
  rounded(ctx, x - 5, y - 25, 10, 20, 3, '#c4c6ac');
  ellipse(ctx, x, y - 26, 17, 8, '#e5dfc5');
  ellipse(ctx, x, y - 28, 11, 4, '#95c7bd');
}

function drawDecoration(ctx, area) {
  const lanterns = area === 'incheon' ? [[12, 8], [16.7, 8], [21.5, 11.8], [6, 8.5], [8.4, 8.5]] :
    area === 'suwon' ? [[6, 8.5], [8.5, 8.5], [18.5, 8.5], [22, 8.5], [14, 6]] : [[5.4, 9.3], [27.3, 9.3]];
  for (const [x, y] of lanterns) drawLantern(ctx, x * TILE, y * TILE);
  if (area === 'suwon') { drawWall(ctx);drawFountain(ctx); }
  const beds = area === 'incheon' ? [[11, 12.5], [16.5, 12.5], [22, 7.5]] :
    area === 'suwon' ? [[4, 8.5], [24, 8.5], [8, 15.3], [21.8, 15]] : [[5.3, 13.7], [22, 3.3]];
  for (const [x, y] of beds) {
    rounded(ctx, x * TILE - 14, y * TILE - 8, 44, 21, 7, '#617a54');
    for (let i = 0; i < 7; i++) drawFlower(ctx, x * TILE - 8 + i * 5, y * TILE + noise(i, y) * 5, i % 2 ? '#f8dce5' : '#dd94b6', 2.2);
  }
  if (area === 'route') {
    // 쉼터의 좌석과 안내판.
    rounded(ctx, 2.8 * TILE, 8.6 * TILE, 65, 12, 3, '#987655');
    rounded(ctx, 2.9 * TILE, 8.6 * TILE + 12, 5, 12, 1, '#6e6246');
    rounded(ctx, 4.6 * TILE, 8.6 * TILE + 12, 5, 12, 1, '#6e6246');
  }
}

function getBackground(area) {
  if (BACKGROUNDS.has(area)) return BACKGROUNDS.get(area);
  const canvas = document.createElement('canvas');canvas.width = WORLD_WIDTH;canvas.height = WORLD_HEIGHT;
  const ctx = canvas.getContext('2d');
  drawGround(ctx, area);drawRiver(ctx, area);drawDecoration(ctx, area);
  BACKGROUNDS.set(area, canvas);
  return canvas;
}

function drawPerson(ctx, tx, ty, kind = 'player', facing = 'down', walking = 0) {
  const x = tx * TILE + 16, y = ty * TILE + 16;
  const bounce = Math.sin(walking * 10) * (walking ? 1.1 : 0);
  ctx.save();ctx.translate(x, y);
  ellipse(ctx, 1, 1, 10, 4.3, '#203d484f');
  ctx.translate(0, bounce);
  const harin = kind === 'harin', seohwa = kind === 'seohwa';
  const hair = seohwa ? '#dce2f2' : harin ? '#2c2732' : '#26313c';
  const coat = seohwa ? '#efeaf0' : harin ? '#f1e1d9' : '#274857';
  const accent = seohwa ? '#d881a4' : '#b84e5e';
  if (harin || seohwa) {
    rounded(ctx, -10, -30, 20, 24, 7, hair, '#30344566');
    polygon(ctx, [[-9, -24], [-15, -8], [-7, -11], [0, -25], [7, -11], [15, -8], [9, -24]], hair);
  }
  const stride = walking ? Math.sin(walking * 12) * 2 : 0;
  rounded(ctx, -7, -8 + stride, 5, 9, 2, '#253548');
  rounded(ctx, 2, -8 - stride, 5, 9, 2, '#253548');
  rounded(ctx, -8, -2 + stride, 7, 4, 2, '#293544');
  rounded(ctx, 1, -2 - stride, 7, 4, 2, '#293544');
  if (harin || seohwa) {
    polygon(ctx, [[-5, -21], [5, -21], [11, -6], [-11, -6]], seohwa ? '#e28ba8' : '#332d3c', '#283746');
    polygon(ctx, [[-7, -21], [-11, -8], [-6, -7], [-1, -17], [6, -7], [12, -8], [7, -21]], coat);
    line(ctx, [[-5, -16], [6, -12]], accent, 2);
    drawFlower(ctx, 6, -9, '#d8b66b', 0.9);
  } else {
    rounded(ctx, -7, -22, 14, 17, 4, coat, '#1d3441');
    polygon(ctx, [[-5, -21], [0, -16], [5, -21]], '#f3e3c9');
    rounded(ctx, -7, -12, 14, 3, 1, '#ad7d5b');
    if (facing === 'up') rounded(ctx, -7, -20, 14, 14, 4, '#ad7953', '#694f3e');
  }
  line(ctx, [[-8, -20], [-11, -12 + stride]], coat, 5);
  line(ctx, [[8, -20], [11, -12 - stride]], coat, 5);
  ellipse(ctx, -11, -11 + stride, 2.4, 2.7, '#f3d6bd');
  ellipse(ctx, 11, -11 - stride, 2.4, 2.7, '#f3d6bd');
  ellipse(ctx, 0, -29, 11.2, 11.5, '#f4d7bf');
  ellipse(ctx, -10.5, -27, 2, 3, '#e9bba4');ellipse(ctx, 10.5, -27, 2, 3, '#e9bba4');
  if (facing === 'up') ellipse(ctx, 0, -31, 11.5, 11, hair);
  else {
    ctx.fillStyle = hair;ctx.beginPath();ctx.arc(0, -31, 11.6, Math.PI, TAU);ctx.lineTo(11, -27);ctx.lineTo(7, -30);
    ctx.lineTo(4, -24);ctx.lineTo(1, -30);ctx.lineTo(-4, -25);ctx.lineTo(-7, -29);ctx.lineTo(-11, -25);ctx.closePath();ctx.fill();
    const gaze = facing === 'left' ? -2 : facing === 'right' ? 2 : 0;
    ellipse(ctx, -4 + gaze, -27, 1.8, 2.6, '#343345');ellipse(ctx, 4 + gaze, -27, 1.8, 2.6, '#343345');
    ellipse(ctx, -4.5 + gaze, -28, 0.6, 0.9, '#fff9ed');ellipse(ctx, 3.5 + gaze, -28, 0.6, 0.9, '#fff9ed');
    line(ctx, [[-1, -22], [1, -22]], '#c1837d');
    ellipse(ctx, -7, -23.5, 2, 1, '#e7a29d77');ellipse(ctx, 7, -23.5, 2, 1, '#e7a29d77');
  }
  if (harin || seohwa) {
    drawFlower(ctx, 9, -37, harin ? '#f4e7dd' : '#efb9ce', 2.3);
    line(ctx, [[10, -35], [14, -24]], accent, 2);
    ellipse(ctx, 12, -27, 1, 2, '#d2ae64');
  } else {
    ctx.beginPath();ctx.ellipse(0, -34, 12, 7, 0, Math.PI, TAU);ctx.fillStyle = kind === 'healer' ? '#e8deca' : '#b45161';ctx.fill();
    rounded(ctx, -12, -35, 24, 5, 2, kind === 'healer' ? '#91a794' : '#ead9ba');
    ellipse(ctx, facing === 'up' ? 0 : 5, -31, 10, 2.8, kind === 'healer' ? '#568274' : '#8e4055');
    if (kind !== 'healer') ellipse(ctx, 0, -37, 2.4, 2.4, '#edd4a0');
  }
  ctx.restore();
}

function drawRalts(ctx, tx, ty, time, glowing = false) {
  const x = tx * TILE + 16, y = ty * TILE + 16;
  ctx.save();ctx.translate(x, y + Math.sin(time * 0.002) * 1.2);
  if (glowing) {
    const glow = ctx.createRadialGradient(0, -10, 0, 0, -10, 32);
    glow.addColorStop(0, '#f9daff70');glow.addColorStop(1, '#f4d5ff00');
    ellipse(ctx, 0, -10, 32, 30, glow);
  }
  ellipse(ctx, 0, 0, 9, 3, '#35505b40');
  polygon(ctx, [[-4, -15], [4, -15], [7, -1], [0, -4], [-6, -1]], '#f1e9e9', '#8ca7b6');
  line(ctx, [[-3, -12], [-9, -8]], '#f1e9e9', 3);line(ctx, [[3, -12], [8, -9]], '#f1e9e9', 3);
  ellipse(ctx, 0, -19, 8, 8, '#ede8ee');
  ctx.beginPath();ctx.arc(0, -21, 9, Math.PI, TAU);ctx.lineTo(8, -17);ctx.lineTo(-9, -16);ctx.closePath();ctx.fillStyle = '#91b9d2';ctx.fill();
  polygon(ctx, [[-1, -23], [2, -32], [5, -23]], '#e9a5be');
  if (glowing) for (let i = 0; i < 4; i++) {
    const a = time * 0.0006 + i * Math.PI / 2;
    const sx = Math.cos(a) * 22, sy = -16 + Math.sin(a) * 17;
    line(ctx, [[sx - 2, sy], [sx + 2, sy]], '#fff3c4', 1);
    line(ctx, [[sx, sy - 2], [sx, sy + 2]], '#fff3c4', 1);
  }
  ctx.restore();
}

function drawWaterAnimation(ctx, area, time) {
  if (area === 'suwon') {
    const x = 14.3 * TILE + 16, y = 10.2 * TILE + 16;
    ctx.strokeStyle = '#e1f3df66';ctx.lineWidth = 1;
    ctx.beginPath();ctx.ellipse(x, y - 6, 14 + Math.sin(time / 700) * 4, 7, 0, 0, TAU);ctx.stroke();
    return;
  }
  const x = area === 'incheon' ? 18.2 * TILE : 24.9 * TILE;
  const width = area === 'incheon' ? 2.5 * TILE : 1.65 * TILE;
  ctx.save();ctx.beginPath();ctx.rect(x, 0, width, 9 * TILE - 8);ctx.rect(x, 12 * TILE + 6, width, WORLD_HEIGHT);ctx.clip();
  for (let i = 0; i < 34; i++) {
    const wx = x + 9 + noise(i, 29) * (width - 25);
    const wy = (noise(i, 18) * WORLD_HEIGHT + time * 0.007) % WORLD_HEIGHT;
    ctx.globalAlpha = 0.2 + Math.sin(time / 1000 + i) * 0.12;
    line(ctx, [[wx, wy], [wx + 5, wy - 1], [wx + 14, wy]], '#e6f6e3', 1.5);
  }
  ctx.restore();
}

function drawInteractionMarker(ctx, item, state, time) {
  const x = item.x * TILE + 16, y = item.y * TILE + 16;
  const nearby = Math.hypot(state.player.x - item.x, state.player.y - item.y) < 1.8;
  const isTarget = (state.stage === 'prologue' && item.id === 'ralts') ||
    (state.stage === 'rescued' && item.id === 'lab') ||
    (state.stage === 'journey' && state.area === 'suwon' && item.id === 'gym' && !state.badges?.length);
  if (item.kind === 'exit') {
    const direction = item.id === 'gateBack' ? -1 : 1;
    ctx.save();ctx.translate(x, y);
    rounded(ctx, -13, -10, 26, 21, 7, '#264f55cc', '#d8d5ac');
    line(ctx, [[-direction * 5, -5], [direction * 4, 0], [-direction * 5, 5]], '#fff4d0', 2);
    ctx.restore();
  } else if (isTarget || nearby) {
    const yy = y - (item.kind === 'person' || item.kind === 'quest' ? 54 : 20) + Math.sin(time / 400) * 2;
    ellipse(ctx, x, yy, 9, 9, isTarget ? '#f8dea2' : '#f6eddd');
    ctx.fillStyle = '#35505b';ctx.font = 'bold 12px sans-serif';ctx.textAlign = 'center';ctx.textBaseline = 'middle';
    ctx.fillText(isTarget ? '!' : '···', x, yy + 0.5);
  }
  if (nearby) {
    const width = item.label.length * 11 + 25;
    rounded(ctx, x - width / 2, y + 14, width, 23, 7, '#193f49e8', '#dccb9c');
    ctx.font = '500 11px sans-serif';ctx.textAlign = 'center';ctx.textBaseline = 'middle';
    ctx.fillStyle = '#fff3d9';ctx.fillText(item.label, x, y + 26);
  }
}

export function drawWorld(ctx, state, time = 0, options = {}) {
  const area = AREAS[state.area] ? state.area : 'incheon';
  ctx.save();
  ctx.clearRect(0, 0, WORLD_WIDTH, WORLD_HEIGHT);
  ctx.drawImage(getBackground(area), 0, 0);
  drawWaterAnimation(ctx, area, time);

  // 발밑의 y 좌표를 기준으로 정렬하여 나무·건물 뒤로 걸어갈 수 있습니다.
  const layers = [];
  for (const b of buildings[area]) layers.push({ y: (b.y + b.h) * TILE, draw: () => drawBuilding(ctx, b) });
  for (const tree of TREES[area]) layers.push({ y: tree.y * TILE + 16, draw: () => {
    ctx.drawImage(treeLayer(tree), tree.x * TILE + 16 - 58, tree.y * TILE + 16 - 112);
  } });
  if (area === 'incheon') {
    layers.push({ y: 12 * TILE + 16, draw: () => drawPerson(ctx, 15, 12, 'harin') });
    if (state.stage !== 'prologue') layers.push({ y: 8 * TILE + 16, draw: () => drawPerson(ctx, 7, 8, 'seohwa') });
    if (state.stage === 'prologue') layers.push({ y: 5 * TILE + 16, draw: () => drawRalts(ctx, 23, 5, time, true) });
  }
  if (area === 'route') layers.push({ y: 10 * TILE + 16, draw: () => drawPerson(ctx, 4, 10, 'healer') });
  const player = state.player;
  if (state.party?.length) {
    const offsetX = player.facing === 'left' ? 0.7 : player.facing === 'right' ? -0.7 : 0.65;
    const offsetY = player.facing === 'up' ? 0.7 : 0.45;
    layers.push({ y: (player.y + offsetY) * TILE + 16, draw: () => drawRalts(ctx, player.x + offsetX, player.y + offsetY, time) });
  }
  layers.push({ y: player.y * TILE + 16, draw: () => drawPerson(ctx, player.x, player.y, 'player', player.facing, options.moving ? time / 1000 : 0) });
  layers.sort((a, b) => a.y - b.y).forEach(layer => layer.draw());

  if (state.stage === 'prologue' && area === 'incheon') {
    ctx.fillStyle = '#22335f1a';ctx.fillRect(0, 0, WORLD_WIDTH, WORLD_HEIGHT);
    for (const [x, y] of [[12, 8], [16.7, 8], [21.5, 11.8], [6, 8.5], [8.4, 8.5]]) drawLantern(ctx, x * TILE, y * TILE, true);
  }
  for (let i = 0; i < (options.reducedMotion ? 0 : 28); i++) {
    const x = (noise(i, 31) * WORLD_WIDTH + time * (0.008 + noise(i, 4) * 0.007)) % WORLD_WIDTH;
    const y = (noise(i, 32) * WORLD_HEIGHT + time * (0.006 + noise(i, 2) * 0.006)) % WORLD_HEIGHT;
    ctx.globalAlpha = 0.35 + noise(i, 5) * 0.4;
    ellipse(ctx, x + Math.sin(time / 1700 + i) * 12, y, 2.2, 1.1, '#ffe0e9', time / 1600 + i);
  }
  ctx.globalAlpha = 1;
  const vignette = ctx.createRadialGradient(480, 320, 240, 480, 320, 570);
  vignette.addColorStop(0, '#132e3500');vignette.addColorStop(1, '#193d4538');
  ctx.fillStyle = vignette;ctx.fillRect(0, 0, WORLD_WIDTH, WORLD_HEIGHT);
  for (const item of getInteractions(state)) drawInteractionMarker(ctx, item, state, time);
  ctx.restore();
}
