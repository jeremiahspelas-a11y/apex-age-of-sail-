"""Package an unchanged Godot Web export for hosts with a 25 MiB per-file limit.

The wasm bytes are streamed from two chunks. Gameplay stays in the exported Godot
project; this loader does not replace the simulation. No server-side dependencies.
"""
from pathlib import Path
import argparse, hashlib, json, shutil, subprocess
parser = argparse.ArgumentParser()
parser.add_argument('export_directory', type=Path)
parser.add_argument('output_directory', type=Path)
args = parser.parse_args()
source = args.export_directory.resolve()
out = args.output_directory.resolve()
if source == out or source in out.parents:
    raise SystemExit('Output must be separate from the original Web export')
out.mkdir(parents=True, exist_ok=True)
for f in source.iterdir():
    if f.is_file() and f.name != 'index.wasm':
        shutil.copy2(f, out / f.name)
wasm = (source / 'index.wasm').read_bytes()
parts = []
for i, start in enumerate(range(0, len(wasm), 20*1024*1024)):
    name = f'index.wasm.part{i}'
    (out / name).write_bytes(wasm[start:start+20*1024*1024])
    parts.append(name)
loader = r'''// Reassemble the original engine bytes as a stream; retain native Godot loading.
(() => {
 const nativeFetch = globalThis.fetch.bind(globalThis);
 const target = new URL('index.wasm', location.href);
 const parts = PARTS;
 globalThis.fetch = async function(input, init) {
  const url = new URL(input instanceof Request ? input.url : input, location.href);
  if (url.origin !== target.origin || url.pathname !== target.pathname) return nativeFetch(input,init);
  let index = 0, reader = null;
  const stream = new ReadableStream({
   async pull(controller) {
    try {
     for (;;) {
      if (!reader) {
       if (index === parts.length) { controller.close(); return; }
       const response = await nativeFetch(new URL(parts[index++],target),init);
       if (!response.ok) throw Error('Could not load sailing engine: '+response.status);
       reader = response.body.getReader();
      }
      const chunk = await reader.read();
      if (chunk.done) { reader.releaseLock(); reader=null; continue; }
      controller.enqueue(chunk.value); return;
     }
    } catch (error) { controller.error(error); }
   },
   async cancel(reason) { if(reader) await reader.cancel(reason); }
  });
  return new Response(stream,{headers:{'Content-Type':'application/wasm','Content-Length':'SIZE'}});
 };
})();
'''.replace('PARTS', json.dumps(parts)).replace('SIZE', str(len(wasm)))
(out / 'engine-stream.js').write_text(loader)
html = (out / 'index.html').read_text()
html = html.replace('<script src="index.js"></script>', '<script src="engine-stream.js"></script>\n\t<script src="index.js"></script>')
if 'engine-stream.js' not in html:
    raise SystemExit('Export shell changed: engine loader insertion point missing')
(out / 'index.html').write_text(html)
repo = Path(__file__).resolve().parents[1]
head = subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip()
(out/'build-info.json').write_text(json.dumps({'project':'APEX First Watch','source_commit':head,'engine_sha256':hashlib.sha256(wasm).hexdigest(),'engine_bytes':len(wasm),'parts':parts},indent=2)+'\n')
assert b''.join((out/name).read_bytes() for name in parts) == wasm
assert all(f.stat().st_size <= 25*1024*1024 for f in out.iterdir() if f.is_file())
print(json.dumps({'output':str(out),'parts':parts,'bytes':len(wasm),'source_commit':head}))
