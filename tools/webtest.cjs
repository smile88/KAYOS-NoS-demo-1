// Load the web build in a phone-sized, touch-enabled Chromium; screenshot the stages.
const { chromium } = require(require('child_process').execSync('npm root -g').toString().trim() + '/playwright');
(async () => {
  const out = process.env.OUT || '/tmp/webshots';
  require('fs').mkdirSync(out, { recursive: true });
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const ctx = await b.newContext({ viewport: { width: 844, height: 390 }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
  const pg = await ctx.newPage();
  const logs = [];
  pg.on('console', m => logs.push(m.type() + ': ' + m.text()));
  pg.on('pageerror', e => logs.push('pageerror: ' + e));
  await pg.goto('http://localhost:8765/index.html?fps=1');
  const t0 = Date.now();
  for (const [ms, name] of JSON.parse(process.env.SHOTS || '[[20000,"a"],[40000,"b"]]')) {
    const wait = ms - (Date.now() - t0);
    if (wait > 0) await pg.waitForTimeout(wait);
    await pg.screenshot({ path: `${out}/${name}.png` });
  }
  console.log(logs.slice(0, 80).join('\n'));
  await b.close();
})();
