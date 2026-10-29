// Real Web export clients, one native host, isolated local HTTP/WebSocket listeners.
const {chromium,devices}=require('playwright');
const fs=require('fs'),http=require('http'),path=require('path'),{spawn}=require('child_process');
(async()=>{
 const project=process.cwd(),out=process.env.APEX_QA_OUT||'visual-qa';fs.mkdirSync(out,{recursive:true});
 const host=spawn(process.env.GODOT_BINARY||'./Godot_v4.7.2-stable_linux.x86_64',['--headless','--path',project,'--','--serve=19081']);
 const hostLog=[];host.on('exit',(code,signal)=>console.log('COOP HOST EXIT '+JSON.stringify({code,signal})));host.stdout.on('data',b=>hostLog.push(b.toString()));host.stderr.on('data',b=>hostLog.push(b.toString()));
 const mime={'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png'};
 const web=process.env.APEX_WEB_ROOT||path.join(project,'web');
 const server=http.createServer((req,res)=>{const u=new URL(req.url,'http://localhost');const file=path.join(web,u.pathname==='/'?'index.html':u.pathname);try{res.setHeader('Content-Type',mime[path.extname(file)]||'application/octet-stream');res.end(fs.readFileSync(file));}catch{res.statusCode=404;res.end()}});
 let browser,stage='host startup';
 const errors=[];const states=[[],[]];
 try{
  await new Promise(r=>server.listen(8767,'127.0.0.1',r));
  const executablePath=process.env.APEX_CHROMIUM;
  const args=['--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'];
  if(executablePath)args.push('--no-sandbox','--no-zygote','--single-process','--in-process-gpu','--ignore-gpu-blocklist');
  browser=await chromium.launch({headless:true,...(executablePath?{executablePath}:{}),args});
  const pages=[];
  const waitFor=async(fn,timeout=60000)=>{const until=Date.now()+timeout;while(!fn()){if(Date.now()>until)throw Error('Timed out waiting for '+stage+'; host exit='+host.exitCode+'; host errors='+hostLog.join('').split('\n').filter(s=>/ERROR|failed/i.test(s)).slice(-4).join(' | ')+'; browser errors='+errors.join(' | '));await new Promise(r=>setTimeout(r,250));}};
  await waitFor(()=>hostLog.join('').includes('APEX FORCE TRIAL ON'),10000);
  for(let i=0;i<2;i++){
   const page=await browser.newPage({...devices['Pixel 7'],viewport:{width:960,height:540},deviceScaleFactor:1});pages.push(page);
   let ready=false,panelOpen=false,endpointFocused=false;
   page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{const s=m.text();if(m.type()==='error')errors.push(s);if(s.includes('COOP'))console.log(i+': '+s);if(s==='APEX COOP PANEL true')panelOpen=true;if(s==='APEX COOP ENDPOINT FOCUSED')endpointFocused=true;if(s.startsWith('APEX FORCE SAMPLE '))ready=true;if(s.startsWith('APEX COOP STATE '))states[i].push(JSON.parse(s.slice('APEX COOP STATE '.length)));});
   stage='browser '+i+' force readiness';await page.goto('http://127.0.0.1:8767/?simulation=forces',{waitUntil:'domcontentloaded'});await waitFor(()=>ready);
   stage='browser '+i+' join panel';await page.mouse.click(350,80);await waitFor(()=>panelOpen);
   await waitFor(()=>endpointFocused);await page.keyboard.press('ControlOrMeta+A');await page.keyboard.type('ws://127.0.0.1:19081',{delay:30});await page.keyboard.press('Enter');
   stage='browser '+i+' authoritative snapshot';await page.screenshot({path:path.join(out,'coop-join-'+i+'.png')}); await waitFor(()=>states[i].some(s=>s.crew>=2));
  }
  stage='three shared participants';await waitFor(()=>states.every(s=>s.some(v=>v.crew===3)));
  await pages[0].bringToFront();await pages[0].mouse.click(350,80);await pages[0].mouse.click(732,40);
  stage='shared helm command';await waitFor(()=>states.every(s=>s.some(v=>v.rudder_input>0.1)));
  await pages[0].screenshot({path:path.join(out,'coop-shared-ship.png')});
  const report={pass:true,errors,states,hostErrors:hostLog.join('').split('\n').filter(s=>/SCRIPT ERROR|ERROR:/.test(s))};
  fs.writeFileSync(path.join(out,'coop-browser.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify({pass:!errors.length&&!report.hostErrors.length,stateCounts:states.map(s=>s.length),errors,hostErrors:report.hostErrors}));
  if(errors.length||report.hostErrors.length)process.exitCode=1;
 }finally{fs.writeFileSync(path.join(out,'coop-host.log'),hostLog.join(''));fs.writeFileSync(path.join(out,'coop-diagnostics.json'),JSON.stringify({stage,hostExit:host.exitCode,hostSignal:host.signalCode,errors,states},null,2));if(browser)await browser.close();server.close();host.kill('SIGTERM');}
})().catch(e=>{console.error(e);process.exit(1)});
