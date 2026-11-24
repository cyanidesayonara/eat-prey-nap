// Writes site/img/favicon.svg, the curled-up cat, from site/logo.js:
//   node tools/make_favicon.mjs
import fs from 'node:fs';
import vm from 'node:vm';

const here = new URL('../site/', import.meta.url);
const ctx = {};
ctx.globalThis = ctx;
vm.runInNewContext(fs.readFileSync(new URL('logo.js', here), 'utf8'), ctx);
const {curled, VIEW} = ctx.EatPreyNap;
const art = curled({ink: '#121b48', field: '#e9d9a0', soft: '#b9a05a'});
fs.writeFileSync(new URL('img/favicon.svg', here), `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${VIEW}">${art}</svg>\n`);
