// Run with: node autocorrect-regression-tests.js
const fs = require("fs");

global.window = {};
eval(fs.readFileSync("words-db.js", "utf8"));
const memory = new Map();
global.localStorage = { getItem: key => memory.get(key) || null, setItem: (key, value) => memory.set(key, value) };
global.beforeCaret = () => "";
global.tokenize = () => [];
global.ADJACENT_KEYS = { q:["w","a"], w:["q","e","a","s"], e:["w","r","s","d"], r:["e","t","d","f"], t:["r","y","f","g"], y:["t","u","g","h"], u:["y","i","h","j"], i:["u","o","j","k"], o:["i","p","k","l"], p:["o","l"], a:["q","w","s","z"], s:["w","e","a","d","z","x"], d:["e","r","s","f","x","c"], f:["r","t","d","g","c","v"], g:["t","y","f","h","v","b"], h:["y","u","g","j","b","n"], j:["u","i","h","k","n","m"], k:["i","o","j","l","m"], l:["o","p","k"], z:["a","s","x"], x:["z","s","d","c"], c:["x","d","f","v"], v:["c","f","g","b"], b:["v","g","h","n"], n:["b","h","j","m"], m:["n","j","k"] };

const html = fs.readFileSync("ghostkeys-simulator.html", "utf8");
const engine = html.match(/const LEXICON_ENTRIES[\s\S]*?\n}\n\n\/\* ===================== EMOJI DATA/)[0].replace(/\n\/\* ===================== EMOJI DATA[\s\S]*/, "");
const autocorrect = new Function(`${engine}; return autocorrect;`)();
const cases = [["goodd","good"],["corrrected","corrected"],["wordss","words"],["nto","not"],["teh","the"],["simpel","simple"],["alot","a lot"],["aswell","as well"],["Lets","Let's"],["Alot","A lot"],["Goodd","Good"]];
for (const [typed, expected] of cases) {
  const actual = autocorrect(typed);
  if (actual !== expected) throw new Error(`${typed}: expected ${expected}, got ${actual}`);
  console.log(`${typed} -> ${actual}`);
}
console.log(`PASS: ${cases.length} autocorrect regressions`);
