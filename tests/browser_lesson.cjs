// A real browser lesson: use rendered controls and walk between physical deck stations.
const {chromium}=require('playwright'),fs=require('fs'),http=require('http'),path=require('path');
const project=process.cwd(),out=process.env.APEX_QA_OUT||'visual-qa',web=process.env.APEX_WEB_ROOT||path.join(project,'web');
fs.mkdirSync(out,{recursive:true});
const mime={'.wasm':'application/wasm','.js':'text/javascript','.png':'image/png','.pck':'application/octet-stream','.html':'text/html'};
const server=http.createServer((q,r)=>{const u=new URL(q.url,'http://localhost'),p=path.join(web,u.pathname==='/'?'index.html':u.pathname);try{r.setHeader('Content-Type',mime[path.extname(p)]||'application/octet-stream');r.end(fs.readFileSync(p));}catch{r.statusCode=404;r.end();}});
let browser,stage='boot',states=[],errors=[],ready=false,welcome=null,menu=null;
const wait=async(fn,ms=60000)=>{const until=Date.now()+ms;while(!fn()){if(Date.now()>until)throw Error('Timed out '+stage+': '+JSON.stringify({last:states.at(-1),errors}));await new Promise(r=>setTimeout(r,150));}};
const angle=a=>Math.atan2(Math.sin(a),Math.cos(a));
(async()=>{
 await new Promise(r=>server.listen(8769,'127.0.0.1',r));
 try{
  browser=await chromium.launch({headless:true,...(process.env.APEX_CHROMIUM?{executablePath:process.env.APEX_CHROMIUM}:{}),args:['--no-sandbox','--no-zygote','--single-process','--in-process-gpu','--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--ignore-gpu-blocklist']});
  const page=await browser.newPage({viewport:{width:960,height:540},deviceScaleFactor:1});
  page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{const s=m.text();if(m.type()==='error')errors.push(s);if(s==='APEX TRAINER READY')ready=true;if(s.startsWith('APEX LESSON MENU '))menu=JSON.parse(s.slice('APEX LESSON MENU '.length));if(s.startsWith('APEX LESSON WELCOME '))welcome=JSON.parse(s.slice('APEX LESSON WELCOME '.length));if(s.startsWith('APEX LESSON STATE ')){states.push(JSON.parse(s.slice('APEX LESSON STATE '.length)));fs.writeFileSync(path.join(out,'lesson-live.json'),JSON.stringify({stage,state:states.at(-1)}));}});
  await page.goto('http://127.0.0.1:8769/',{waitUntil:'domcontentloaded'});await wait(()=>ready&&welcome);
  await page.screenshot({path:path.join(out,'first-watch-welcome.png'),timeout:60000});
  // Welcome button position is retained in the real 960x540 layout.
  await page.mouse.click(...welcome.start);stage='start lesson';await wait(()=>states.length>1);
  if(!states.at(-1).force_trial)throw Error('Lesson did not enable mechanical physics');
  await page.screenshot({path:path.join(out,'first-watch-deck.png'),timeout:60000});
  // Point the eye camera and walk using keyboard input. No position/state assignment.
  const go=async(x,z,tolerance=.30,station=-1)=>{
   stage='walk to '+x+','+z;const until=Date.now()+120000;
   while(Date.now()<until){
    const state=states.at(-1),dx=x-state.player[0],dz=z-state.player[2];
    if((station>=0&&state.nearby===station)||Math.hypot(dx,dz)<tolerance){await page.keyboard.up('ArrowUp');return;}
    const yaw=Math.atan2(-dx,-dz),difference=angle(yaw-state.yaw),turn=Math.max(-.5,Math.min(.5,difference));
    await page.keyboard.up('ArrowUp');
    if(Math.abs(difference)>.10){
     const wanted=state.yaw+turn;
     await page.mouse.move(600,220);await page.mouse.down({button:'right'});await page.mouse.move(600-turn/.004,220,{steps:2});
     await wait(()=>Math.abs(angle(states.at(-1).yaw-wanted))<.04,15000);
     await page.mouse.up({button:'right'});continue;
    }
    const start=states.at(-1).player;await page.keyboard.down('ArrowUp');
    await wait(()=>Math.hypot(states.at(-1).player[0]-start[0],states.at(-1).player[2]-start[2])>=.3,15000);
    await page.keyboard.up('ArrowUp');
   }
   await page.keyboard.up('ArrowUp');throw Error('Deck walk failed: '+stage+' '+JSON.stringify(states.at(-1)));
  };
  await go(-1.4,-2.5,.6,1);
  stage='take nearby clew';await wait(()=>states.at(-1).nearby===1&&states.at(-1).use[1]>0&&states.at(-1).use[1]<520);
  await page.mouse.click(...states.at(-1).use);await wait(()=>states.at(-1).stage===1);
  stage='haul actual clew';await wait(()=>states.at(-1).hold_buttons.every(p=>p[0]>0&&p[0]<960&&p[1]>0&&p[1]<520));
  await page.mouse.move(...states.at(-1).hold_buttons[0]);await page.mouse.down();await wait(()=>states.at(-1).stage>=2);await page.mouse.up();
  stage='belay actual clew';await page.mouse.click(...states.at(-1).hold_buttons[2]);await wait(()=>states.at(-1).stage===3&&states.at(-1).sheet_mode===0);
  await page.screenshot({path:path.join(out,'first-watch-sheet.png'),timeout:60000});
  await page.keyboard.press('r');
  const full=process.env.APEX_FULL_LESSON==='1';
  if(full){
  for(const p of [[-1.2,0],[-1.2,5.9],[0,6.3],[0,9.7],[1,9.8],[1,11.35]])await go(...p);
  stage='take quarterdeck wheel';await page.keyboard.press('r');await wait(()=>states.at(-1).stage===4&&states.at(-1).station===0);
  await page.keyboard.down('d');stage='turn actual rudder';await wait(()=>states.at(-1).stage>=5);await page.keyboard.up('d');
  await page.screenshot({path:path.join(out,'first-watch-wheel.png'),timeout:60000});
  // Counter-steer using measured rudder samples, as a person observing the readout.
  stage='center actual rudder';const until=Date.now()+90000;let last=null;
  while(states.at(-1).stage<6&&Date.now()<until){
   const s=states.at(-1),rate=last?(s.rudder_deg-last.rudder_deg)/.5:0;
   const demand=-s.rudder_deg*.2-rate*.35;
   await page.keyboard.up('a');await page.keyboard.up('d');
   if(demand<-.08)await page.keyboard.down('a');else if(demand>.08)await page.keyboard.down('d');
   last=s;const n=states.length;await wait(()=>states.length>n,15000);
  }
  await page.keyboard.up('a');await page.keyboard.up('d');
  if(states.at(-1).stage!==6)throw Error('Rudder did not center through real controls');
  await page.screenshot({path:path.join(out,'first-watch-complete.png'),timeout:60000});
  } else {
   // Full collision route and centering are covered natively; keep routine browser QA bounded.
   const rudder=states.at(-1).rudder_deg;
   await page.keyboard.press('d');await page.waitForTimeout(700);
   if(states.at(-1).station!==-1||Math.abs(states.at(-1).rudder_deg-rudder)>1)throw Error('Distant key acquired the wheel');
  }
  stage='lesson menu';menu=null;await page.mouse.click(...states.at(-1).menu_button);await wait(()=>menu);
  await page.screenshot({path:path.join(out,'first-watch-menu.png'),timeout:60000});
  await page.mouse.click(...menu.touch);const n=states.length;await page.mouse.click(...menu.resume);
  await wait(()=>states.length>n&&states.at(-1).touch_mode);
  const beforeLandscape=states.length;await page.setViewportSize({width:800,height:360});
  await wait(()=>states.length>beforeLandscape+3&&Math.abs(states.at(-1).menu_button[0]-744)<1);
  // Exercise the actual two-finger move/look path, including one-finger release.
  stage='simultaneous phone move/look';const cdp=await page.context().newCDPSession(page);
  await cdp.send('Emulation.setTouchEmulationEnabled',{enabled:true,maxTouchPoints:2});
  const point=(id,x,y)=>({id,x,y,radiusX:10,radiusY:10,force:1});
  const left=point(7,78,282),right=point(8,580,150);
  const touch=async(type,points)=>cdp.send('Input.dispatchTouchEvent',{type,touchPoints:points});
  const yaw=states.at(-1).yaw;
  await touch('touchStart',[left]);await touch('touchStart',[left,right]);
  const movedLeft=point(7,78,250),movedRight=point(8,620,150);
  await touch('touchMove',[movedLeft,movedRight]);
  await wait(()=>states.at(-1).touch_owner===7&&states.at(-1).look_owner===8&&Math.abs(states.at(-1).move_axis[1])>.2&&Math.abs(angle(states.at(-1).yaw-yaw)+.16)<.04);
  stage='independent phone finger release';await touch('touchEnd',[movedLeft]);
  await wait(()=>states.at(-1).touch_owner===-1&&states.at(-1).look_owner===8);
  await touch('touchEnd',[]);await wait(()=>states.at(-1).look_owner===-1);
  await page.screenshot({path:path.join(out,'first-watch-phone-landscape.png'),timeout:60000});
  const beforePortrait=states.length;await page.setViewportSize({width:390,height:844});
  await wait(()=>states.length>beforePortrait+3&&Math.abs(states.at(-1).menu_button[0]-334)<1);
  await page.screenshot({path:path.join(out,'first-watch-portrait.png'),timeout:60000});
  if(errors.length)throw Error(errors.join('\n'));
  stage='complete';console.log(JSON.stringify({pass:true,full,stages:[...new Set(states.map(s=>s.stage))],errors}));
 }finally{
  fs.writeFileSync(path.join(out,'lesson-browser.json'),JSON.stringify({pass:stage==='complete',stage,states,errors},null,2));
  if(browser)await browser.close();server.close();
 }
})().catch(e=>{console.error(e);process.exit(1)});
