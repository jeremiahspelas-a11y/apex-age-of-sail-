// Operate the clew circuit through the exported touch UI and retain rendered evidence.
const {chromium,devices}=require('playwright');
const fs=require('fs'),http=require('http'),path=require('path');
(async()=>{
 const project=process.cwd(),out=process.env.APEX_QA_OUT||'visual-qa';fs.mkdirSync(out,{recursive:true});
 const web=process.env.APEX_WEB_ROOT||path.join(project,'web');
 const mime={'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png'};
 const server=http.createServer((req,res)=>{const u=new URL(req.url,'http://localhost');const file=path.join(web,u.pathname==='/'?'index.html':u.pathname);try{res.setHeader('Content-Type',mime[path.extname(file)]||'application/octet-stream');res.end(fs.readFileSync(file));}catch{res.statusCode=404;res.end();}});
 let browser;
 try{
  await new Promise(r=>server.listen(8768,'127.0.0.1',r));
  const executablePath=process.env.APEX_CHROMIUM;
  const args=['--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-sandbox','--no-zygote','--single-process','--in-process-gpu','--ignore-gpu-blocklist'];
  browser=await chromium.launch({headless:true,...(executablePath?{executablePath}:{}),args});
  const page=await browser.newPage({...devices['Pixel 7'],viewport:{width:960,height:540},deviceScaleFactor:1});
  const errors=[],samples=[],controls=[];let selected=false;
  const waitFor=async(fn,timeout=60000)=>{const until=Date.now()+timeout;while(!fn()){if(Date.now()>until)throw Error('Timed out waiting for cloth UI state: '+errors.join('\n'));await new Promise(r=>setTimeout(r,200));}};
  page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{const s=m.text();if(m.type()==='error')errors.push(s);if(s.startsWith('APEX FORCE SAMPLE '))samples.push(JSON.parse(s.slice('APEX FORCE SAMPLE '.length)));if(s==='APEX RIG CIRCUIT CLEW SHEETS')selected=true;if(s.startsWith('APEX BRACE CONTROL '))controls.push(JSON.parse(s.slice('APEX BRACE CONTROL '.length)));});
  await page.goto('http://127.0.0.1:8768/?simulation=forces',{waitUntil:'domcontentloaded'});
  await waitFor(()=>samples.length);
  if(!samples[0].finite||samples[0].cloth.nodes!==35)throw Error('Force trial did not activate the membrane');
  await page.mouse.click(780,417);await waitFor(()=>selected);
  await page.mouse.click(780,267);await waitFor(()=>controls.some(c=>c.clew&&c.action==='BELAY'));
  const initial=controls.findLast(c=>c.clew&&c.action==='BELAY').sheets[0].length;
  await page.mouse.move(660,307);await page.mouse.down();await page.waitForTimeout(2500);await page.mouse.up();
  const count=controls.length;await page.mouse.click(780,267);await waitFor(()=>controls.length>count);
  const belayed=controls.findLast(c=>c.clew&&c.action==='BELAY');
  if(belayed.sheets[0].mode!==0||belayed.sheets[0].length>initial-0.05)throw Error('Clew UI did not haul and belay the actual sheet');
  await page.screenshot({path:path.join(out,'cloth-controls.png'),timeout:60000});
  const freeCount=controls.length;await page.mouse.click(900,267);await waitFor(()=>controls.length>freeCount);
  if(controls.at(-1).sheets[0].mode!==2)throw Error('FREE did not release the sheet');
  const cutCount=controls.length;await page.mouse.click(900,307);await waitFor(()=>controls.length>cutCount);
  if(controls.at(-1).sheets[0].mode!==3||controls.at(-1).sheets[0].tension!==0)throw Error('CUT did not remove the sheet load');
  // Reload the intact rig for an unobstructed view of the solved sail.
  samples.length=0;await page.goto('http://127.0.0.1:8768/?simulation=forces',{waitUntil:'domcontentloaded'});await waitFor(()=>samples.length);
  await page.mouse.click(80,80);await page.waitForTimeout(400);await page.mouse.click(80,133);await page.waitForTimeout(1000);
  await page.screenshot({path:path.join(out,'cloth-sail.png'),timeout:60000});
  const report={pass:!errors.length,errors,initialLength:initial,belayedLength:belayed.sheets[0].length,samples,controls};
  fs.writeFileSync(path.join(out,'cloth-browser.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify({pass:report.pass,errors,initialLength:initial,belayedLength:belayed.sheets[0].length}));
  if(errors.length)process.exitCode=1;
 }finally{if(browser)await browser.close();server.close();}
})().catch(e=>{console.error(e);process.exit(1)});
