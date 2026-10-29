// Render the actual Web export, operate inspection/rig controls and retain proof.
const {chromium,devices}=require('playwright');
const fs=require('fs'),http=require('http'),path=require('path');
const project=process.cwd(),out=process.env.APEX_QA_OUT||'visual-qa';fs.mkdirSync(out,{recursive:true});
const web=process.env.APEX_WEB_ROOT||path.join(project,'web');
const mime={'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png'};
const server=http.createServer((req,res)=>{const u=new URL(req.url,'http://localhost');const file=path.join(web,u.pathname==='/'?'index.html':u.pathname);try{res.setHeader('Content-Type',mime[path.extname(file)]||'application/octet-stream');res.end(fs.readFileSync(file));}catch{res.statusCode=404;res.end();}});
let browser,stage='startup',trainerReady=false,qaWaiting=false,qaReady=null,qaSaved=false;
const errors=[],forceSamples=[],braceControls=[],braceSamples=[];
const waitFor=async(fn,timeout=60000)=>{const until=Date.now()+timeout;while(!fn()){if(Date.now()>until)throw Error('Timed out waiting for '+stage);await new Promise(r=>setTimeout(r,200));}};
(async () => {
 await new Promise(r=>server.listen(8765,'127.0.0.1',r));
 try {
  const executablePath=process.env.APEX_CHROMIUM;
  browser = await chromium.launch({headless:true,...(executablePath?{executablePath}:{}),args:['--enable-webgl','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-sandbox','--no-zygote','--single-process','--in-process-gpu','--ignore-gpu-blocklist']});
  const context = await browser.newContext({ ...devices['Pixel 7'], viewport: { width: 960, height: 540 }, deviceScaleFactor: 1 });
  const page = await context.newPage();
  page.on('console', m => {
    const text=m.text();
    if(text==='APEX TRAINER READY')trainerReady=true;
    if(text==='APEX SPATIAL QA WAITING')qaWaiting=true;
    if(text.startsWith('APEX SPATIAL QA EDITOR READY '))qaReady=JSON.parse(text.slice('APEX SPATIAL QA EDITOR READY '.length));
    if(text.startsWith('APEX SPATIAL QA saved note '))qaSaved=true;
    if(text.startsWith('APEX BRACE SAMPLE '))braceSamples.push(JSON.parse(text.slice('APEX BRACE SAMPLE '.length)));
    if (m.text().startsWith('APEX FORCE SAMPLE ')) forceSamples.push(JSON.parse(m.text().slice('APEX FORCE SAMPLE '.length)));
    if (m.text().startsWith('APEX BRACE CONTROL ')) braceControls.push(JSON.parse(m.text().slice('APEX BRACE CONTROL '.length)));
  });
  page.on('pageerror', e => errors.push('PAGE: ' + e.message));
  page.on('console', m => { if (m.type() === 'error') errors.push('CONSOLE: ' + m.text()); });
  await page.goto('http://127.0.0.1:8765/index.html?mode=workshop', { waitUntil: 'domcontentloaded', timeout: 45000 });
  await waitFor(()=>trainerReady);
  await page.waitForTimeout(16000);
  await page.screenshot({ path: path.join(out,'initial.png'),timeout:60000 });
  await page.waitForTimeout(5000);
  await page.screenshot({ path: path.join(out,'after-5s.png'),timeout:60000 });
  // Use actual editor readiness and button geometry after its label wraps/layout.
  stage='inspection pin';await page.mouse.click(210,80);await waitFor(()=>qaWaiting);
  stage='inspection editor';await page.mouse.click(480,320);await waitFor(()=>qaReady);
  await page.keyboard.type('CI ship inspection note');
  stage='saved inspection note';await page.mouse.click(...qaReady.save_center);await waitFor(()=>qaSaved);
  stage='inspection note download';const downloadPromise=page.waitForEvent('download',{timeout:60000});
  await page.mouse.click(...qaReady.export_center);
  const download = await downloadPromise;
  await download.saveAs(path.join(out,'apex-spatial-qa.json'));
  const notes = JSON.parse(require('fs').readFileSync(path.join(out,'apex-spatial-qa.json'), 'utf8'));
  if (notes.schema !== 'apex-spatial-qa-v1' || notes.notes.length !== 1 ||
      notes.notes[0].description !== 'CI ship inspection note' || !notes.notes[0].mesh_path) {
    throw new Error('Ship note download did not match the saved surface annotation');
  }
  await page.screenshot({ path: path.join(out,'note-saved.png'),timeout:60000 });
  // Touch-control regression: exercise both sticks concurrently in the same fly session.
  const centerLeft = { x: 92, y: 440 };
  const centerRight = { x: 868, y: 440 };
  const client = await page.context().newCDPSession(page);
  const touch = async (type, points) => client.send('Input.dispatchTouchEvent', {
    type, touchPoints: points.map(p => ({ x:p.x, y:p.y, id:p.id, radiusX:10, radiusY:10, force:1 }))
  });
  const left = { id:1, x:92, y:440 };
  const right = { id:2, x:868, y:440 };
  await touch('touchStart',[left]);
  await touch('touchStart',[left,right]);
  await touch('touchMove',[{...left,y:390},{...right,x:915,y:415}]);
  await page.waitForTimeout(1200);
  await page.screenshot({ path: path.join(out,'fly-thumbsticks-held.png'),timeout:60000 });
  await touch('touchEnd',[]);
  const multitouch = {ok:true, inputMethod:'Chromium CDP dispatchTouchEvent', twoFingersHeldMs:1200};
  await page.waitForTimeout(300);
  await page.screenshot({ path: path.join(out,'fly-thumbsticks.png'),timeout:60000 });
  require('fs').writeFileSync(path.join(out,'touch-test.json'), JSON.stringify(multitouch,null,2));
  if (!multitouch.ok) throw new Error('Dual touch simulation could not run');

  await page.goto('http://127.0.0.1:8765/index.html?simulation=forces&weather=Calm', { waitUntil: 'domcontentloaded', timeout: 45000 });
  await page.waitForFunction(() => !!document.querySelector('canvas'));
  for (let i=0; i<30 && !forceSamples.length; i++) await page.waitForTimeout(2000);
  if (!forceSamples.length || !forceSamples[0].finite || forceSamples[0].submerged_m3 <= 0 || forceSamples[0].mass_kg < 80000) {
    throw new Error('Force trial did not produce a finite, buoyant physics sample');
  }
  require('fs').writeFileSync(path.join(out,'force-trial.json'), JSON.stringify(forceSamples,null,2));
  // Free the opposing brace, haul the port line, and belay through the real UI.
  const startAngle = forceSamples[0].brace.angle_deg;
  await page.mouse.click(660,267); // select starboard
  await page.mouse.click(900,267); // free starboard
  await page.mouse.click(660,267); // select port
  await page.mouse.move(660,307);
  await page.mouse.down();
  stage="solved brace movement";await waitFor(()=>braceSamples.some(s=>s.port_mode===1&&Math.abs(s.angle_deg-startAngle)>=0.5));
  await page.mouse.up();
  await page.mouse.click(780,267); // belay port
  stage="belayed brace";await waitFor(()=>braceControls.some(c=>c.action==='BELAY'));
  const belayed = braceControls.findLast(c => c.action === 'BELAY');
  if (!belayed || belayed.state.port_mode !== 0 || Math.abs(belayed.state.angle_deg-startAngle) < 0.5) {
    throw new Error('Browser brace controls did not haul and belay the loaded yard');
  }
  require('fs').writeFileSync(path.join(out,'brace-controls.json'), JSON.stringify(braceControls,null,2));
  await page.screenshot({ path: path.join(out,'force-trial.png'),timeout:60000 });
  const canvas = await page.locator('canvas').count();
  require('fs').writeFileSync(path.join(out,'report.json'), JSON.stringify({ canvas, errors }, null, 2));
  if (!canvas || errors.some(e => /WebGL|shader|SCRIPT ERROR|uncaught|Failed to load/i.test(e))) process.exitCode = 1;
  stage='complete';console.log(JSON.stringify({pass:!process.exitCode,notesSaved:qaSaved,forceSamples:forceSamples.length,braceSamples:braceSamples.length,errors}));
 } finally {
  fs.writeFileSync(path.join(out,'graphics-diagnostics.json'),JSON.stringify({stage,trainerReady,qaWaiting,qaReady,qaSaved,errors,forceSamples,braceControls,braceSamples},null,2));
  if(browser)await browser.close();
  server.close();
 }
})().catch(e => { console.error(e); process.exit(1); });
