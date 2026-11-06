// Accessibility (axe-core, WCAG 2.1 AA) + CSP + hydration check for public pages.
// Usage: npm run build && npx next start -p 3103 &  then: node scripts/a11y-check.cjs node_modules/axe-core/axe.min.js
const { chromium, devices } = require('playwright');
const fs = require('fs');
(async () => {
  const axe = fs.readFileSync(process.argv[2], 'utf8');
  const b = await chromium.launch();
  const results = {};
  for (const [label, ctxOpts] of [['desktop', { viewport: { width: 1280, height: 800 } }], ['mobile', { ...devices['Pixel 7'] }]]) {
    const ctx = await b.newContext(ctxOpts);
    for (const path of ['/login', '/activate', '/setup', '/forbidden']) {
      const p = await ctx.newPage();
      const cspErrors = [];
      p.on('console', (m) => { if (/Content Security Policy|Refused to/i.test(m.text())) cspErrors.push(m.text()); });
      p.on('pageerror', (e) => cspErrors.push('pageerror: ' + e.message));
      await p.goto('http://localhost:3103' + path, { waitUntil: 'networkidle' });
      // hydration check: the password show/hide toggle must work (needs JS that passed CSP)
      let hydrated = null;
      const toggle = p.getByRole('button', { name: /Onyesha|Show/ }).first();
      if (await toggle.count()) { await toggle.click(); hydrated = (await p.locator('input[name="password"]').getAttribute('type')) === 'text'; }
      await p.addScriptTag({ content: axe });
      const r = await p.evaluate(async () => await window.axe.run(document, { runOnly: ['wcag2a', 'wcag2aa', 'wcag21aa'] }));
      results[`${label} ${path}`] = { violations: r.violations.map((v) => `${v.id} (${v.impact}) x${v.nodes.length}`), passes: r.passes.length, cspErrors, hydrated };
      await p.close();
    }
  }
  console.log(JSON.stringify(results, null, 1));
  await b.close();
})();
