const {chromium}=require('/Users/drewlee/.npm/_npx/e41f203b7505f1fb/node_modules/playwright');
const fs=require('fs');
(async()=>{const browser=await chromium.launch({channel:'chrome',headless:true});const results=[];
for(const width of [1440,390])for(const theme of ['daybreak','duet','unfold']){
const context=await browser.newContext({viewport:{width,height:1000},hasTouch:width===390,storageState:'/tmp/lowpass-theme-auth.json'});
await context.addInitScript(t=>localStorage.setItem('lowpass-theme',t),theme);
const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
await page.goto('http://127.0.0.1:3000/settings',{waitUntil:'networkidle'});
const appearance=page.locator('summary[aria-label="切换阅读主题"]');const account=page.getByRole('button',{name:'账户',exact:true});const details=page.locator('details.theme-menu');
const assert=async(ok,label)=>{if(!ok)throw new Error(`${theme}/${width}: ${label}`)};
await appearance.click();await assert(await details.evaluate(el=>el.open),'theme opens');
await account.click();await assert(!(await details.evaluate(el=>el.open)),'theme mutually excluded');await assert(await account.getAttribute('aria-expanded')==='true','account opens');
await page.keyboard.press('Escape');await assert(await account.evaluate(el=>el===document.activeElement),'account Escape focus');
await appearance.focus();await page.keyboard.press('Enter');await page.keyboard.press('Tab');
await assert(await page.locator('.theme-menu input:checked').evaluate(el=>el===document.activeElement),'native Tab enters selected radio');
await page.keyboard.press('Escape');await assert(await appearance.evaluate(el=>el===document.activeElement),'appearance Escape focus');
if(width===390){await appearance.tap();await page.touchscreen.tap(6,950);}else{await appearance.click();await page.getByRole('heading',{name:'账户信息',exact:true}).click();}
await assert(!(await details.evaluate(el=>el.open)),'outside closes');
await appearance.click();await page.keyboard.press('Tab');await page.keyboard.press('Tab');await assert(!(await details.evaluate(el=>el.open)),'Tab exits theme');await assert(await account.evaluate(el=>el===document.activeElement),'Tab reaches account');
await account.click();await page.keyboard.press('Tab');await assert(await account.getAttribute('aria-expanded')==='false','Tab closes account');await assert(await page.evaluate(()=>document.activeElement!==document.body),'Tab retains next focus');
await account.click();await page.keyboard.press('Shift+Tab');await page.waitForFunction(()=>document.querySelector('.account-button').getAttribute('aria-expanded')==='false');await assert(await account.getAttribute('aria-expanded')==='false','ShiftTab closes account');await assert(await account.evaluate(el=>el===document.activeElement),'ShiftTab reaches account');
results.push({theme,width,passed:true,pageErrors:errors});await context.close();}
await browser.close();fs.writeFileSync('/tmp/lowpass-menu-behavior-results.json',JSON.stringify(results,null,2));console.log(JSON.stringify(results,null,2));})().catch(e=>{console.error(e);process.exit(1)});
