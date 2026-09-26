// Drive the web build with real touch events in a phone-sized Chromium: joystick, look-drag, USE.
const { chromium } = require(require('child_process').execSync('npm root -g').toString().trim() + '/playwright');
const W = 844, H = 390;
(async () => {
  const out = process.env.OUT || '/tmp/touch';
  require('fs').mkdirSync(out, { recursive: true });
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const ctx = await b.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
  const pg = await ctx.newPage();
  const logs = [];
  pg.on('console', m => { if (!m.text().includes('AudioContext')) logs.push(m.type() + ': ' + m.text()); });
  pg.on('pageerror', e => logs.push('pageerror: ' + e));
  const cdp = await ctx.newCDPSession(pg);
  const touch = (type, pts) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: pts });
  const shot = n => pg.screenshot({ path: `${out}/${n}.png` });
  await pg.goto('http://localhost:8765/index.html?fps=1');
  await pg.waitForFunction(() => window.__ready === true || document.title.length > 0, null, { timeout: 60000 });
  // wait for the opening card to clear
  const until = async (re, ms) => { const t = Date.now(); while (Date.now() - t < ms) { if (logs.some(l => re.test(l))) return true; await pg.waitForTimeout(500); } return false; };
  await until(/scene ready/, 90000);
  await pg.waitForTimeout(parseInt(process.env.OPEN_WAIT || '25000'));
  await shot('1_start');
  // joystick: press on the left, push up (forward)
  await touch('touchStart', [{ x: 120, y: 290, id: 1 }]);
  for (let i = 1; i <= 6; i++) { await touch('touchMove', [{ x: 120, y: 290 - i * 10, id: 1 }]); await pg.waitForTimeout(80); }
  await pg.waitForTimeout(4000);
  await shot('2_walking');
  await touch('touchEnd', []);
  // look: drag with the right thumb
  await touch('touchStart', [{ x: 600, y: 180, id: 2 }]);
  for (let i = 1; i <= 8; i++) { await touch('touchMove', [{ x: 600 - i * 15, y: 180, id: 2 }]); await pg.waitForTimeout(120); }
  await touch('touchEnd', []);
  await pg.waitForTimeout(3000);
  await shot('3_looked');
  // USE
  await touch('touchStart', [{ x: W - 92, y: H - 96, id: 3 }]);
  await pg.waitForTimeout(300);
  await touch('touchEnd', []);
  await pg.waitForTimeout(6000);
  await shot('4_use');
  await touch('touchStart', [{ x: W - 92, y: H - 96, id: 4 }]);
  await pg.waitForTimeout(300);
  await touch('touchEnd', []);
  await pg.waitForTimeout(4000);
  await shot('5_next');
  console.log(logs.filter(l => !/fps/.test(l)).slice(0, 60).join('\n'));
  console.log(logs.filter(l => /fps/.test(l)).slice(-3).join('\n'));
  await b.close();
})();
