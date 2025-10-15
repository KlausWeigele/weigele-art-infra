/* Auto Racing tribute game - core loop and drawing */

const canvas = document.getElementById('game');
const ctx = canvas.getContext('2d');

const hud = {
  score: document.getElementById('score'),
  time: document.getElementById('time'),
  speed: document.getElementById('speed')
};

const ROAD = {
  margin: 48,
  lineWidth: 6,
  laneCount: 3,
  lineDash: 24
};

const COLORS = {
  grass: '#1a2d13',
  asphalt: '#101820',
  laneLine: '#f5fbff',
  player: '#f8e34c',
  rivals: ['#5cdf68', '#54c8ff', '#b45dff', '#ff7b5c']
};

const GAME = {
  maxSpeed: 140,
  minSpeed: 40,
  startSpeed: 60,
  spawnInterval: 1.2,
  maxEnemies: 5,
  duration: 180
};

const state = {
  running: true,
  player: {
    lane: 1,
    y: canvas.height - 90,
    width: 32,
    height: 56
  },
  enemies: [],
  score: 0,
  timeLeft: GAME.duration,
  speed: GAME.startSpeed,
  spawnTimer: 0,
  lastTimestamp: performance.now()
};

const input = {
  left: false,
  right: false,
  up: false,
  down: false
};

function resetGame() {
  state.running = true;
  state.player.lane = 1;
  state.enemies = [];
  state.score = 0;
  state.timeLeft = GAME.duration;
  state.speed = GAME.startSpeed;
  state.spawnTimer = 0;
  state.lastTimestamp = performance.now();
}

function laneWidth() {
  return (canvas.width - ROAD.margin * 2) / ROAD.laneCount;
}

function laneCenter(laneIndex) {
  return ROAD.margin + laneWidth() * (laneIndex + 0.5);
}

function handleInput() {
  if (!state.running) return;
  if (input.left) {
    state.player.lane = Math.max(0, state.player.lane - 1);
    input.left = false;
  } else if (input.right) {
    state.player.lane = Math.min(ROAD.laneCount - 1, state.player.lane + 1);
    input.right = false;
  }

  if (input.up) {
    state.speed = Math.min(GAME.maxSpeed, state.speed + 0.6);
  }
  if (input.down) {
    state.speed = Math.max(GAME.minSpeed, state.speed - 0.8);
  }
}

function spawnEnemy(dt) {
  state.spawnTimer -= dt;
  if (state.spawnTimer > 0 || state.enemies.length >= GAME.maxEnemies) return;

  const availableLanes = [0, 1, 2].filter(lane => {
    return !state.enemies.some(enemy => enemy.lane === lane && enemy.y < 140);
  });

  if (availableLanes.length === 0) {
    state.spawnTimer = 0.4;
    return;
  }

  const lane = availableLanes[Math.floor(Math.random() * availableLanes.length)];
  const rivalSpeed = state.speed * (0.7 + Math.random() * 0.6);

  state.enemies.push({
    lane,
    y: -64,
    width: 32,
    height: 56,
    speed: rivalSpeed,
    color: COLORS.rivals[Math.floor(Math.random() * COLORS.rivals.length)]
  });

  const intervalScale = 1 - (state.speed - GAME.minSpeed) / (GAME.maxSpeed - GAME.minSpeed);
  state.spawnTimer = GAME.spawnInterval * (0.6 + intervalScale * 0.8);
}

function update(dt) {
  if (!state.running) return;

  state.timeLeft -= dt;
  if (state.timeLeft <= 0) {
    state.timeLeft = 0;
    state.running = false;
    return;
  }

  handleInput();
  spawnEnemy(dt);

  const roadSpeed = state.speed * dt * 1.2;
  state.score += roadSpeed * 0.4;

  state.enemies = state.enemies.filter(enemy => enemy.y < canvas.height + 80);
  for (const enemy of state.enemies) {
    enemy.y += roadSpeed - enemy.speed * dt;
  }

  for (const enemy of state.enemies) {
    if (checkCollision(state.player, enemy)) {
      state.running = false;
    }
  }
}

function checkCollision(player, enemy) {
  const px = laneCenter(player.lane) - player.width / 2;
  const py = player.y;
  const ex = laneCenter(enemy.lane) - enemy.width / 2;
  const ey = enemy.y;

  return !(
    px + player.width < ex ||
    px > ex + enemy.width ||
    py + player.height < ey ||
    py > ey + enemy.height
  );
}

function drawRoad() {
  ctx.fillStyle = COLORS.grass;
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  const roadX = ROAD.margin;
  const roadWidth = canvas.width - ROAD.margin * 2;
  ctx.fillStyle = COLORS.asphalt;
  ctx.fillRect(roadX, 0, roadWidth, canvas.height);

  ctx.strokeStyle = COLORS.laneLine;
  ctx.lineWidth = ROAD.lineWidth;
  ctx.setLineDash([ROAD.lineDash, ROAD.lineDash]);
  ctx.beginPath();
  const lanes = ROAD.laneCount - 1;
  for (let i = 1; i <= lanes; i += 1) {
    const x = roadX + (roadWidth / ROAD.laneCount) * i;
    ctx.moveTo(x, 0);
    ctx.lineTo(x, canvas.height);
  }
  ctx.stroke();
  ctx.setLineDash([]);
}

function drawCars() {
  const playerX = laneCenter(state.player.lane) - state.player.width / 2;
  ctx.fillStyle = COLORS.player;
  ctx.fillRect(playerX, state.player.y, state.player.width, state.player.height);

  for (const enemy of state.enemies) {
    const enemyX = laneCenter(enemy.lane) - enemy.width / 2;
    ctx.fillStyle = enemy.color;
    ctx.fillRect(enemyX, enemy.y, enemy.width, enemy.height);
  }
}

function drawGameOver() {
  if (state.running) return;
  ctx.fillStyle = 'rgba(0, 0, 0, 0.65)';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.fillStyle = '#ffefde';
  ctx.textAlign = 'center';
  ctx.font = '20px "Press Start 2P", monospace';
  const message = state.timeLeft <= 0 ? 'Time Up' : 'Crash!';
  ctx.fillText(message, canvas.width / 2, canvas.height / 2 - 16);
  ctx.font = '12px "Press Start 2P", monospace';
  ctx.fillText('Press R to Restart', canvas.width / 2, canvas.height / 2 + 12);
}

function draw(dt) {
  drawRoad();
  drawCars();
  drawHUD();
  drawGameOver();
}

function drawHUD() {
  hud.score.textContent = Math.floor(state.score).toString().padStart(4, '0');
  hud.time.textContent = Math.ceil(state.timeLeft).toString().padStart(3, '0');
  hud.speed.textContent = Math.round(state.speed).toString();
}

function gameLoop(timestamp) {
  const dt = Math.min((timestamp - state.lastTimestamp) / 1000, 0.1);
  state.lastTimestamp = timestamp;

  update(dt);
  draw(dt);

  requestAnimationFrame(gameLoop);
}

function bindInput() {
  window.addEventListener('keydown', event => {
    switch (event.key.toLowerCase()) {
      case 'arrowleft':
      case 'a':
        input.left = true;
        break;
      case 'arrowright':
      case 'd':
        input.right = true;
        break;
      case 'arrowup':
      case 'w':
        input.up = true;
        break;
      case 'arrowdown':
      case 's':
        input.down = true;
        break;
      case 'r':
        resetGame();
        break;
      default:
        break;
    }
  });

  window.addEventListener('keyup', event => {
    switch (event.key.toLowerCase()) {
      case 'arrowup':
      case 'w':
        input.up = false;
        break;
      case 'arrowdown':
      case 's':
        input.down = false;
        break;
      default:
        break;
    }
  });
}

bindInput();
resetGame();
requestAnimationFrame(gameLoop);
