// Prints each step's narration of a scene as JSON: [{ "k": 0, "title": "...", "say": "..." }, ...]
import fs from 'node:fs';
import vm from 'node:vm';

const file = process.argv[2];
let spec = null;
const context = vm.createContext({ Motion: { scene: s => { spec = s; } }, console });
vm.runInContext(fs.readFileSync(file, 'utf8'), context, { filename: file });
if (!spec) {
  console.error(`narration: ${file} has no Motion.scene({...}) call`);
  process.exit(1);
}
console.log(JSON.stringify((spec.steps || []).map((s, k) => ({ k, title: s.title || '', say: s.say || '' }))));
