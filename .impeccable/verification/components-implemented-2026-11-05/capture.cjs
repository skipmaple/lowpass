const { chromium } = require('/Users/drewlee/.npm/_npx/e41f203b7505f1fb/node_modules/playwright');
const fs = require('node:fs');
const path = require('node:path');
const out = __dirname;
const routes = { daily:'/daily/2026-11-04', weekly:'/weekly/2026-W45', favorites:'/favorites', search:'/search?q=AI', settings:'/settings', sources:'/admin/sources', form:'/admin/sources/new', adminSettings:'/admin/settings', issues:'/admin/issues' };
const themes = ['daybreak','duet','unfold'];
const expected = { daybreak:'8px',duet:'2px',unfold:'6px' };

(async () => {
  const browser = await chromium.launch({channel:'chrome',headless:true});
  const observations = [];
  await Promise.all(themes.map(async theme => {
    for (const width of [1440,390]) {
      const context = await browser.newContext({storageState:'/tmp/lowpass-theme-auth.json',viewport:{width,height:width===390?844:1000},isMobile:width===390,hasTouch:width===390});
      await context.addInitScript(t=>localStorage.setItem('lowpass-theme',t),theme);
      await context.route('**/*',r=>['GET','HEAD'].includes(r.request().method())?r.continue():r.abort());
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror',e=>errors.push(e.message));
      for (const [name,route] of Object.entries(routes)) {
        const response = await page.goto('http://127.0.0.1:3000'+route,{waitUntil:'networkidle'});
        await page.evaluate(()=>document.fonts.ready);
        if (name==='search' && width===390) { await page.locator('.filter-toggle').click(); await page.waitForTimeout(300); }
        await page.screenshot({path:path.join(out,`${theme}-${width}-${name}.png`)});
        const metrics = await page.evaluate(()=>{
          const visible=e=>{const r=e.getBoundingClientRect();return r.width&&r.height&&getComputedStyle(e).visibility!=='hidden'};
          const controls=[...document.querySelectorAll('.field-input,.date-field,.btn-primary,.ctrl,.collection-source-filter select,.seg-item')].filter(visible).map(e=>{
            const s=getComputedStyle(e);const r=e.getBoundingClientRect();
            return {cls:e.className,text:e.textContent.trim().slice(0,30),type:e.getAttribute('type'),radius:s.borderRadius,height:r.height,font:s.fontSize,color:s.color,bg:s.backgroundColor,border:s.borderColor,disabled:e.matches(':disabled')};
          });
          return {theme:document.documentElement.dataset.theme,width:innerWidth,scrollWidth:document.documentElement.scrollWidth,controls,overflow:[...document.querySelectorAll('body *')].filter(e=>visible(e)&&e.getBoundingClientRect().right>innerWidth+1).slice(0,8).map(e=>e.className)};
        });
        observations.push({theme,width,name,status:response.status(),url:page.url(),errors:[...errors],...metrics});
        if (name==='form') {
          await page.locator('.field-input').first().focus();
          await page.waitForTimeout(300);
          await page.screenshot({path:path.join(out,`${theme}-${width}-form-focus.png`)});
        }
        if (name==='settings') {
          await page.locator('.theme-menu>summary').click();
          await page.waitForTimeout(250);
          await page.screenshot({path:path.join(out,`${theme}-${width}-appearance.png`)});
          await page.getByRole('button',{name:'账户',exact:true}).click();
          const exclusive = !(await page.locator('.theme-menu').evaluate(e=>e.open)) && await page.locator('.menu-card').isVisible();
          await page.keyboard.press('Escape');
          const returned = await page.locator('.account-button').evaluate(e=>e===document.activeElement);
          await page.getByRole('button',{name:'注销',exact:true}).click();
          await page.waitForTimeout(250);
          await page.keyboard.press('Tab');await page.keyboard.press('Shift+Tab');
          await page.screenshot({path:path.join(out,`${theme}-${width}-dialog.png`)});
          const modal = await page.locator('.dialog').evaluate(e=>({radius:getComputedStyle(e).borderRadius,focus:e.contains(document.activeElement),danger:e.dataset.tone}));
          await page.keyboard.press('Escape');
          observations.push({theme,width,name:'overlays',exclusive,returned,modal});
        }
      }
      await context.close();
      const login = await browser.newContext({viewport:{width,height:width===390?844:1000},isMobile:width===390,hasTouch:width===390});
      await login.addInitScript(t=>localStorage.setItem('lowpass-theme',t),theme);
      const lp=await login.newPage();
      await lp.goto('http://127.0.0.1:3000/login',{waitUntil:'networkidle'});await lp.evaluate(()=>document.fonts.ready);
      await lp.screenshot({path:path.join(out,`${theme}-${width}-login.png`),fullPage:true});
      const radius=await lp.locator('.field-input').first().evaluate(e=>getComputedStyle(e).borderRadius);
      observations.push({theme,width,name:'login',radius,correct:radius===expected[theme],overflow:await lp.evaluate(()=>document.documentElement.scrollWidth>innerWidth)});
      await login.close();
    }
    console.log('Captured',theme);
  }));
  await browser.close();
  fs.writeFileSync(path.join(out,'browser-checks.json'),JSON.stringify(observations,null,2));
  const problems=observations.filter(r=>r.status&&r.status!==200||r.errors?.length||r.scrollWidth>r.width||r.correct===false||r.exclusive===false||r.returned===false||r.name==='login'&&r.overflow);
  console.log(JSON.stringify({checks:observations.length,problems},null,2));
  if(problems.length)process.exitCode=1;
})().catch(e=>{console.error(e);process.exit(1)});
