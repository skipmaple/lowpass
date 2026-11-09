import { chromium } from '/Users/drewlee/.npm/_npx/e41f203b7505f1fb/node_modules/playwright/index.mjs';
import fs from 'node:fs/promises';
const root='/Users/drewlee/work/personal/lowpass';
const out=root+'/.impeccable/verification/components-implemented-2026-11-05/independent';
const results=[];
const browser=await chromium.launch({channel:'chrome',headless:true});
const themes=['daybreak','duet','unfold'];
const inspect=async(page)=>page.evaluate(()=>{
 const visible=e=>{const r=e.getBoundingClientRect(),s=getComputedStyle(e);return r.width>0&&r.height>0&&s.visibility!=='hidden'&&s.display!=='none'};
 const controls=Array.from(document.querySelectorAll('input:not([type=hidden]),select,textarea,button,a.ctrl,summary')).filter(visible).map(e=>{const r=e.getBoundingClientRect(),s=getComputedStyle(e);return {tag:e.tagName,type:e.type||null,label:e.getAttribute('aria-label')||e.textContent?.trim().slice(0,50)||e.name||null,left:r.left,right:r.right,width:r.width,height:r.height,scrollWidth:e.scrollWidth,clientWidth:e.clientWidth,radius:s.borderRadius,fontSize:s.fontSize,disabled:e.matches(':disabled'),clipped:r.left<-.5||r.right>innerWidth+.5}});
 const active=document.activeElement,s=active?getComputedStyle(active):null;
 return {width:innerWidth,docWidth:document.documentElement.scrollWidth,overflow:document.documentElement.scrollWidth>innerWidth+1,controls:controls.filter(c=>c.clipped),tinyControls:controls.filter(c=>c.height<43.5&&c.type!=='radio'&&c.type!=='checkbox'),focus:active?{tag:active.tagName,label:active.getAttribute('aria-label')||active.textContent?.trim().slice(0,45),visible:active.matches(':focus-visible'),outline:s.outline,offset:s.outlineOffset}:null};
});
for(const theme of themes)for(const width of [320,768]){
 const ctx=await browser.newContext({viewport:{width,height:1000},storageState:'/tmp/lowpass-theme-auth.json',isMobile:width===320,hasTouch:width===320});
 await ctx.addInitScript(t=>localStorage.setItem('lowpass-theme',t),theme);
 const blocked=[];await ctx.route('**/*',r=>{if(!['GET','HEAD'].includes(r.request().method())){blocked.push({method:r.request().method(),url:new URL(r.request().url()).pathname});return r.abort()}return r.continue()});
 const page=await ctx.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
 async function go(path){const res=await page.goto('http://127.0.0.1:3000'+path,{waitUntil:'networkidle'});await page.evaluate(()=>document.fonts.ready);return res.status()}
 async function shot(name){const current=await page.locator('html').getAttribute('data-theme');await page.screenshot({path:`${out}/${theme}-${width}-${name}-rendered-${current}.png`,fullPage:false})}
 async function switchTheme(target){await page.locator('.theme-menu>summary').click();await page.locator(`.theme-menu input[value="${target}"]`).check();await page.evaluate(()=>document.fonts.ready);await page.waitForTimeout(250);await page.keyboard.press('Escape');}
 for(const [name,path] of [['favorites','/favorites']]){
  const row={theme,width,name,status:await go(path)};
  row.base=await inspect(page);
  if(name==='search'){
   if(await page.locator('.filter-toggle').count())await page.locator('.filter-toggle').click();
   row.expanded=await inspect(page);await page.locator('.search-input').fill('保留未提交的搜索词');
   const url=page.url(),selected=await page.locator('.seg [aria-current]').allTextContents();
   await switchTheme(themes[(themes.indexOf(theme)+1)%3]);
   row.statePreserved=await page.locator('.search-input').inputValue()==='保留未提交的搜索词'&&page.url()===url&&JSON.stringify(await page.locator('.seg [aria-current]').allTextContents())===JSON.stringify(selected);
   row.afterSwitch=await inspect(page);
  }
  if(name==='favorites'){
   const sel=page.locator('[aria-label="收藏来源"]');
   if(await sel.count()){
    const val=await sel.locator('option').evaluateAll(es=>es.find(e=>e.value)?.value||'');
    if(val){await Promise.all([page.waitForURL(u=>u.searchParams.get('source')===val),sel.selectOption(val)]);await page.waitForFunction(()=>!document.querySelector('.collection-count')?.textContent.includes('正在'));await page.evaluate(()=>document.fonts.ready)}
   }
   const selected=await sel.count()?await sel.inputValue():null;
   await page.locator('#collection-query').fill('保留收藏查询草稿');const url=page.url();
   await switchTheme(themes[(themes.indexOf(theme)+1)%3]);
   row.favoriteState={value:await page.locator('#collection-query').inputValue(),url:page.url(),selected:await sel.count()?await sel.inputValue():null,expectedUrl:url,expectedSource:selected};row.statePreserved=await page.locator('#collection-query').inputValue()==='保留收藏查询草稿'&&page.url()===url&&(!selected||await sel.inputValue()===selected);
   row.afterSwitch=await inspect(page);
  }
  if(name==='settings'){
   const summary=page.locator('.theme-menu>summary'),account=page.getByRole('button',{name:'账户',exact:true});
   await summary.click();await page.waitForTimeout(250);row.themePanel=await page.locator('.theme-menu-panel').evaluate(e=>{const r=e.getBoundingClientRect();return{left:r.left,right:r.right,width:r.width,bottom:r.bottom,viewport:innerWidth}});
   await account.click();row.mutuallyExclusive=(await page.locator('.theme-menu[open]').count())===0&&await account.getAttribute('aria-expanded')==='true';
   await page.keyboard.press('Escape');row.accountEscape=await account.evaluate(e=>e===document.activeElement)&&await account.getAttribute('aria-expanded')==='false';
   await summary.click();await page.keyboard.press('Escape');row.themeEscape=await summary.evaluate(e=>e===document.activeElement)&&await summary.getAttribute('aria-expanded')==='false';
   await summary.click();await page.getByText('头像与显示名',{exact:true}).click();row.outsideClosed=(await page.locator('.theme-menu[open]').count())===0;
   await page.getByRole('button',{name:'注销',exact:true}).click();await page.waitForTimeout(250);row.dialog=await inspect(page);await page.keyboard.press('Tab');row.dialogKeyboard=await inspect(page);await page.keyboard.press('Escape');
  }
  if(name==='source-form'){
   const input=page.getByRole('textbox',{name:'名称',exact:true});await input.fill('组件主题验收草稿（不提交）');
   await input.focus();await page.keyboard.press('Shift+Tab');await page.keyboard.press('Tab');row.keyboard=await inspect(page);
   const node=await input.elementHandle();const url=page.url();await switchTheme(themes[(themes.indexOf(theme)+1)%3]);
   row.statePreserved=await input.inputValue()==='组件主题验收草稿（不提交）'&&page.url()===url&&await node.evaluate(e=>e.isConnected);
   row.afterSwitch=await inspect(page);
  }
  const fail=[row.base,row.expanded,row.afterSwitch,row.dialog,row.dialogKeyboard].some(x=>x&&(x.overflow||x.controls.length))||row.statePreserved===false||row.mutuallyExclusive===false||row.accountEscape===false||row.themeEscape===false||row.outsideClosed===false;
  row.failed=fail;if(fail||width===320&&['search','source-form'].includes(name))await shot(name+(fail?'-failure':'-representative'));
  row.errors=[...errors];row.blocked=[...blocked];row.capturedTheme=await page.locator('html').getAttribute('data-theme');results.push(row);await fs.writeFile(out+'/favorites-state-recheck.json',JSON.stringify(results,null,2));
 }
 await ctx.close();

}
await fs.writeFile(out+'/favorites-state-recheck.json',JSON.stringify(results,null,2));await browser.close();console.log(JSON.stringify({cases:results.length,failures:results.filter(r=>r.failed).map(r=>({theme:r.theme,width:r.width,name:r.name,base:r.base,after:r.afterSwitch})),errors:results.flatMap(r=>r.errors||[]),blocked:results.flatMap(r=>r.blocked||[])},null,2));
