const {chromium}=require('/Users/drewlee/.npm/_npx/e41f203b7505f1fb/node_modules/playwright');
const fs=require('fs'); const path=require('path'); const out=__dirname;
(async()=>{const b=await chromium.launch({channel:'chrome',headless:true});const results=[];
for(const theme of ['daybreak','duet','unfold']){
 const c=await b.newContext({viewport:{width:1440,height:1000},storageState:'/tmp/lowpass-theme-auth.json'});
 await c.addInitScript(t=>localStorage.setItem('lowpass-theme',t),theme);
 let release;const gate=new Promise(r=>release=r);let inertiaPage;const blocked=[];
 await c.route('**/*',async route=>{const req=route.request();if(['GET','HEAD'].includes(req.method()))return route.continue();blocked.push({method:req.method(),path:new URL(req.url()).pathname,forwarded:false});if(req.method()==='POST'&&new URL(req.url()).pathname==='/admin/sources'){
  await gate; await route.fulfill({status:200,contentType:'application/json',headers:{'X-Inertia':'true'},body:JSON.stringify({...inertiaPage,url:'/admin/sources/new',props:{...inertiaPage.props,errors:{name:['名称已存在，请换一个名称'],'config.feed_url':['请填写可以公开访问的 feed 地址']},flash:{id:'browser-state-review-'+theme,alert:'保存未完成：请检查字段后重试。'}}})});
 }else await route.abort();});
 const p=await c.newPage();const errors=[];p.on('pageerror',e=>errors.push(String(e)));
 await p.goto('http://127.0.0.1:3000/admin/sources/new',{waitUntil:'networkidle'}); await p.evaluate(()=>document.fonts.ready);
 inertiaPage=await p.evaluate(()=>JSON.parse(document.querySelector('script[data-page]').textContent));
 await p.getByRole('button',{name:'阮一峰周刊',exact:true}).click();await p.waitForTimeout(300);const freshAdapter=await p.locator('.seg-button').evaluateAll(es=>es.filter(e=>['日刊','周刊'].includes(e.textContent)).map(e=>({text:e.textContent,disabled:e.disabled,selected:e.getAttribute('aria-pressed')})));await p.getByRole('button',{name:'RSS/Atom',exact:true}).click();await p.waitForTimeout(300);
 await p.getByRole('textbox',{name:'feed 地址',exact:true}).fill('https://example.com/feed.xml');await p.getByRole('textbox',{name:'名称',exact:true}).fill('浏览器验收示例');
 const styles=sel=>p.locator(sel).evaluateAll(es=>es.map(e=>{const s=getComputedStyle(e);return {tag:e.tagName,text:e.textContent?.slice(0,80),value:e.value,disabled:e.matches(':disabled'),readonly:e.readOnly,invalid:e.getAttribute('aria-invalid'),selected:e.getAttribute('aria-pressed'),busy:e.getAttribute('aria-busy'),radius:s.borderRadius,bg:s.backgroundColor,color:s.color,border:s.border,outline:s.outline,cursor:s.cursor};}));
 await p.getByRole('button',{name:'保存',exact:true}).click();await p.getByRole('button',{name:'正在保存…',exact:true}).waitFor();await p.waitForTimeout(300);
 const entry={theme,freshAdapter,pending:await styles('.admin-form .btn-primary,.admin-form .field-input,.admin-form .seg-button')};await p.screenshot({path:path.join(out,theme+'-pending.png'),fullPage:true});
 release();await p.locator('input[aria-invalid="true"]').first().waitFor();await p.waitForTimeout(400);
 entry.invalid=await styles('[aria-invalid="true"],.field-error,.field-error svg,.toast[data-kind="fail"],.toast[data-kind="fail"]>svg');entry.errorFocus=await p.evaluate(()=>({name:document.activeElement?.getAttribute('name'),invalid:document.activeElement?.getAttribute('aria-invalid')}));await p.screenshot({path:path.join(out,theme+'-invalid-toast.png'),fullPage:true});
 await p.getByRole('button',{name:'阮一峰周刊',exact:true}).click();await p.locator('input[readonly]').waitFor();await p.waitForTimeout(300);entry.readonly=await styles('input[readonly],.seg-button:disabled');await p.locator('input[readonly]').focus();entry.readonlyFocus=await p.locator('input[readonly]').evaluate(e=>document.activeElement===e);await p.screenshot({path:path.join(out,theme+'-readonly-disabled.png'),fullPage:true});
 entry.blocked=blocked;entry.errors=errors;entry.simulation='POST intercepted in browser; final Inertia validation errors and flash simulated; no non-GET request forwarded';results.push(entry);await c.close();}
await b.close();fs.writeFileSync(path.join(out,'states.json'),JSON.stringify(results,null,2));console.log(JSON.stringify(results.map(x=>({theme:x.theme,requests:x.blocked,errors:x.errors,errorFocus:x.errorFocus,readonlyFocus:x.readonlyFocus}))));})();
