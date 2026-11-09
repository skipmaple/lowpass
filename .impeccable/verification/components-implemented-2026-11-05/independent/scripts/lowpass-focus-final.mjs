import { chromium } from '/Users/drewlee/.npm/_npx/e41f203b7505f1fb/node_modules/playwright/index.mjs';
import fs from 'node:fs/promises';
const out='/Users/drewlee/work/personal/lowpass/.impeccable/verification/components-implemented-2026-11-05/independent';
const browser=await chromium.launch({channel:'chrome',headless:true});const results=[];
for(const theme of ['daybreak','duet','unfold']){
 const c=await browser.newContext({viewport:{width:320,height:1000},storageState:'/tmp/lowpass-theme-auth.json'});await c.addInitScript(t=>localStorage.setItem('lowpass-theme',t),theme);await c.route('**/*',r=>['GET','HEAD'].includes(r.request().method())?r.continue():r.abort());const p=await c.newPage();
 await p.goto('http://127.0.0.1:3000/search',{waitUntil:'networkidle'});await p.evaluate(()=>document.fonts.ready);await p.locator('.theme-menu>summary').click();await p.keyboard.press('Escape');
 const focus=await p.locator('.theme-menu>summary').evaluate(e=>{const r=e.getBoundingClientRect(),s=getComputedStyle(e);const b=parseFloat(s.outlineWidth)+parseFloat(s.outlineOffset);return{rect:r.toJSON(),outline:s.outline,offset:s.outlineOffset,focusVisible:e.matches(':focus-visible'),visualTop:r.top-b,viewportHeight:innerHeight}});
 if(focus.visualTop<0)await p.screenshot({path:out+'/'+theme+'-320-focus-outline-clipping.png'});
 await p.goto('http://127.0.0.1:3000/admin/sources/new',{waitUntil:'networkidle'});await p.evaluate(()=>document.fonts.ready);
 const navs=await p.locator('nav').evaluateAll(es=>es.map(e=>({label:e.getAttribute('aria-label'),text:e.textContent,cls:e.className,scrollWidth:e.scrollWidth,clientWidth:e.clientWidth})));
 results.push({theme,focus,navs});await c.close();
}
await fs.writeFile(out+'/focus-final.json',JSON.stringify(results,null,2));console.log(JSON.stringify(results,null,2));await browser.close();
