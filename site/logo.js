// The logo: a cat in a badge. It hunts, eats and naps; between two of them the
// cat curls up and spins one full turn together with the badge.
//
//   <svg data-logo="solid"></svg>   pale cat on a dark badge
//   <svg data-logo="outline"></svg> dark cat in a line
//   <svg data-logo="curl"></svg>    the curled-up cat, still, for small sizes
//   <p data-logo-words></p>         the title, the word of the moment lit
//
// It also takes over Godot's web loading screen (#status) when it finds one.
// With reduced motion set, everything is the nap, standing still.
//
// The game draws the same logo: src/view/logo_poses.gd holds the same numbers
// as LOGO below, and tests/test_logo.gd fails if they differ.
(function (root) {
  'use strict';
  /* LOGO-BEGIN */
  const LOGO = {
    "speed": 1.35,
    "poses": [
      {"name": "crouch", "word": 1, "hold": 1.0, "go": 0.22,
        "body": [[52, 128], [38, 108], [48, 84], [76, 82], [104, 94], [124, 104], [124, 128], [88, 130]],
        "head": [140, 108, 19, 6], "tail": [[46, 108], [22, 114], [8, 100], [18, 84]],
        "legs": [[[56, 118], [50, 128]], [[70, 120], [74, 128]], [[108, 118], [128, 129]], [[116, 118], [140, 129]]],
        "eye": 1.0, "bowl": 0, "mouse": 1, "mx": 198, "chew": 0, "wiggle": 1, "sleep": 0},
      {"name": "leap", "word": 1, "hold": 0.1, "go": 0.2,
        "body": [[72, 96], [62, 78], [74, 62], [102, 50], [130, 50], [154, 60], [146, 80], [106, 86]],
        "head": [170, 58, 19, 16], "tail": [[68, 80], [46, 78], [28, 64], [34, 44]],
        "legs": [[[78, 88], [46, 112]], [[86, 88], [58, 118]], [[136, 74], [170, 98]], [[146, 70], [186, 94]]],
        "eye": 1.0, "bowl": 0, "mouse": 1, "mx": 204, "chew": 0, "wiggle": 0, "sleep": 0},
      {"name": "land", "word": 1, "hold": 0.4, "go": 0.95,
        "body": [[98, 100], [86, 82], [98, 64], [126, 64], [152, 80], [168, 98], [160, 116], [130, 108]],
        "head": [178, 92, 19, 30], "tail": [[94, 82], [76, 66], [70, 42], [88, 30]],
        "legs": [[[102, 94], [92, 128]], [[114, 100], [112, 128]], [[154, 106], [186, 127]], [[162, 106], [200, 124]]],
        "eye": 0.95, "bowl": 0, "mouse": 1, "mx": 210, "chew": 0, "wiggle": 0, "sleep": 0},
      {"name": "eat", "word": 0, "hold": 1.1, "go": 0.95,
        "body": [[70, 131], [58, 112], [66, 90], [90, 80], [118, 86], [144, 96], [148, 126], [108, 132]],
        "head": [168, 106, 19, 34], "tail": [[66, 120], [40, 126], [28, 100], [44, 84]],
        "legs": [[[78, 120], [76, 128]], [[90, 122], [96, 128]], [[132, 112], [134, 128]], [[140, 112], [144, 128]]],
        "eye": 0.15, "bowl": 1, "mouse": 0, "mx": 236, "chew": 1, "wiggle": 0, "sleep": 0},
      {"name": "nap", "word": 2, "hold": 1.6, "go": 0.95,
        "body": [[90, 130], [72, 112], [78, 88], [106, 74], [140, 76], [168, 94], [170, 122], [130, 131]],
        "head": [160, 113, 19, 16], "tail": [[77, 112], [74, 132], [112, 131], [148, 128]],
        "legs": [[[98, 118], [100, 124]], [[110, 120], [114, 124]], [[136, 116], [140, 124]], [[144, 116], [150, 124]]],
        "eye": 0.0, "bowl": 0, "mouse": 0, "mx": 300, "chew": 0, "wiggle": 0, "sleep": 1}
    ]
  };
  /* LOGO-END */
  const WORDS = ['Eat', 'Prey', 'Nap'];
  const KEYS = ['body', 'head', 'tail', 'legs', 'eye', 'bowl', 'mouse', 'mx', 'chew', 'wiggle', 'sleep'];
  const TOTAL = LOGO.poses.reduce((n, p) => n + p.hold + p.go, 0);
  const NAP = TOTAL - 0.95 - 0.8;            // half way through the nap
  const BX = 125, BY = 98, N = 96;           // the curled cat's middle; points on the badge

  const mix = (a, b, t) => Array.isArray(a) ? a.map((v, i) => mix(v, b[i], t)) : a + (b - a) * t;
  const inOut = t => t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
  const EASE = {crouch: t => 1 - Math.pow(1 - t, 3), leap: t => t * t};
  const over = t => 1 + 1.7 * Math.pow(t - 1, 3) + 0.7 * Math.pow(t - 1, 2);
  const r = n => n.toFixed(2);

  function pose(sec) {
    sec = ((sec % TOTAL) + TOTAL) % TOTAL;
    const ps = LOGO.poses;
    let i = 0;
    while (i < ps.length - 1 && sec >= ps[i].hold + ps[i].go) { sec -= ps[i].hold + ps[i].go; i++; }
    const a = ps[i], b = ps[(i + 1) % ps.length];
    const t = sec < a.hold ? 0 : (EASE[a.name] || inOut)(Math.min(1, (sec - a.hold) / a.go));
    const p = {};
    for (const k of KEYS) p[k] = mix(a[k], b[k], t);
    p.change = a.word === b.word ? 0 : t;    // how far into a turn
    p.from = a.word;
    p.to = b.word;
    p.words = WORDS.map((_, w) => (a.word === w ? 1 - t : 0) + (b.word === w ? t : 0));
    p.blob = p.change > 0 ? Math.pow(Math.max(0, Math.sin(Math.PI * t)), 0.55) : 0;
    return p;
  }

  // towards the curled-up cat, by p.blob
  function curl(p, sec) {
    const w = p.blob;
    if (w === 0) return p;
    const round = [135, 180, 225, 270, 315, 0, 45, 90].map(deg => {
      const a = deg * Math.PI / 180, rad = 43 + 2.5 * Math.sin(2 * a + sec * 7) + Math.sin(3 * a - sec * 5);
      return [BX + Math.cos(a) * rad, BY + Math.sin(a) * rad];
    });
    p.body = mix(p.body, round, w);
    p.head = mix(p.head, [BX + 19, BY - 8, 20, 24], w);
    p.tail = mix(p.tail, [[BX - 40, BY + 8], [BX - 34, BY + 40], [BX + 2, BY + 48], [BX + 28, BY + 27]], w);
    p.legs = mix(p.legs, [[[BX - 12, BY + 8], [BX - 12, BY + 16]], [[BX - 4, BY + 10], [BX - 4, BY + 18]],
      [[BX + 6, BY + 10], [BX + 6, BY + 18]], [[BX + 12, BY + 8], [BX + 12, BY + 16]]], w);
    p.eye *= Math.max(0, 1 - 1.6 * w);
    const gone = Math.max(0, 1 - 1.5 * w);
    for (const k of ['bowl', 'mouse', 'sleep', 'chew', 'wiggle']) p[k] *= gone;
    return p;
  }

  function smooth(p) {                       // a closed Catmull-Rom curve
    const n = p.length, g = i => p[(i + n) % n];
    let d = `M${r(p[0][0])} ${r(p[0][1])}`;
    for (let i = 0; i < n; i++) {
      const [a, b, c, e] = [g(i - 1), g(i), g(i + 1), g(i + 2)];
      d += `C${r(b[0] + (c[0] - a[0]) / 6)} ${r(b[1] + (c[1] - a[1]) / 6)} ${r(c[0] - (e[0] - b[0]) / 6)} ${r(c[1] - (e[1] - b[1]) / 6)} ${r(c[0])} ${r(c[1])}`;
    }
    return d + 'Z';
  }

  // eat a wide dish, prey a burst, nap a cushion: a radius for every angle
  const SHAPES = [
    a => 119 + 5 * Math.cos(2 * a),
    a => 116 + 12 * Math.cos(8 * a),
    a => 109.8 / Math.pow(Math.pow(Math.cos(a), 4) + Math.pow(Math.sin(a), 4), 0.25) + 2
  ];
  const spin = p => p.change > 0 ? (0.75 * p.change + 0.25 * over(p.change)) * 360 : 0;
  function shape(p) {
    const t = p.change, squeeze = 1 - 0.1 * Math.sin(Math.PI * t), turn = spin(p) * Math.PI / 180, pts = [];
    for (let i = 0; i < N; i++) {
      const a = i / N * 2 * Math.PI, rad = mix(SHAPES[p.from](a), SHAPES[t > 0 ? p.to : p.from](a), t) * squeeze;
      pts.push([150 + Math.cos(a + turn) * rad, 150 + Math.sin(a + turn) * rad]);
    }
    return smooth(pts);
  }

  function cat(p, sec, ink, field, soft) {
    const s = p.sleep, sway = p.wiggle * Math.sin(sec * 15) * 2.6, tip = p.wiggle * Math.sin(sec * 8) * 7;
    const line = (d, w, col, extra = '') => `<path d="${d}" fill="none" stroke="${col}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"${extra}/>`;
    const body = p.body.map(([x, y], i) => [x + (i < 4 || i === 7 ? sway * (i === 7 || i === 3 ? 0.5 : 1) : 0), y]);
    const t = p.tail.map(([x, y], i) => [x + (i === 0 ? sway : 0), y + (i === 3 ? tip : 0)]);
    const tail = `M${r(t[0][0])} ${r(t[0][1])}C${t.slice(1).map(q => r(q[0]) + ' ' + r(q[1])).join(' ')}`;
    const legs = p.legs.map(([a, b], i) => line(`M${r(a[0] + (i < 2 ? sway : 0))} ${r(a[1])}L${r(b[0])} ${r(b[1])}`, 10, ink)).join('');
    const breath = 1 + s * Math.sin(sec * 2.4) * 0.014, chew = p.chew * Math.sin(sec * 9) * 1.5;
    const eye = x => p.eye < 0.3
      ? line(`M${x - 4.4} -3Q${x} ${r(-3 + 4.5 * (1 - p.eye))} ${x + 4.4} -3`, 2.2, field)
      : `<ellipse cx="${x}" cy="-3" rx="4.4" ry="${r(5.06 * p.eye)}" fill="${field}"/><ellipse cx="${x + 0.8}" cy="-3" rx="2" ry="${r(3.74 * p.eye)}" fill="${ink}"/>`;
    const [hx, hy, hs, rot] = p.head;
    const head = `<g transform="translate(${r(hx)} ${r(hy + chew)}) rotate(${r(rot)}) scale(${r(hs / 19)})"><path d="M-17 -6L-15 -27Q-14 -30 -11 -28L-2 -18Q3 -19 6 -18L15 -27Q18 -29 18 -25L18 -5A19 18 0 1 1 -17 -6Z" fill="${ink}" stroke="${field}" stroke-width="5" stroke-linejoin="round" paint-order="stroke"/>${eye(-3)}${eye(11)}</g>`;
    const mouse = p.mouse < 0.01 ? '' : `<g transform="translate(${r(p.mx)} 134) scale(${r(Math.min(1, p.mouse * 1.6))})"><path d="M-16 0Q-16 -15 -2 -15Q10 -15 18 -2Q18 0 15 0Z" fill="${soft}"/><circle cx="3" cy="-15" r="6" fill="${soft}"/>${line('M-14 -3Q-25 -2 -24 -12', 3, soft)}</g>`;
    const bowl = p.bowl < 0.01 ? '' : `<g transform="translate(184 134) scale(${r(p.bowl)})"><path d="M-19 -13H19L14 0H-14Z" fill="${soft}" stroke="${soft}" stroke-width="3" stroke-linejoin="round"/></g>`;
    const z = s < 0.01 ? '' : [0, 1, 2].map(i => {
      const f = (sec * 0.35 + i / 3) % 1;
      return line('M-6 -6H6L-6 6H6', 3.4, ink, ` transform="translate(${r(184 + f * 22)} ${r(82 - f * 42)}) scale(${r((0.5 + f * 0.6) * s)})" opacity="${r(s * Math.sin(f * Math.PI))}"`);
    }).join('');
    return `${mouse}<g transform="translate(0 ${r(133 - 133 * breath)}) scale(1 ${r(breath)})">${legs}<path d="${smooth(body)}" fill="${ink}"/>`
      + line(tail, 14, field, ` opacity="${r(Math.max(Math.pow(s, 4), Math.pow(p.blob, 4)))}"`) + line(tail, 9, ink) + head + `</g>${bowl}${z}`;
  }

  // a camera that keeps the cat, and a little of the mouse, in the middle
  function camera(p) {
    const xs = p.body.map(q => q[0]).concat(p.head[0] + 14, p.tail[3][0]), lo = Math.min(...xs), hi = Math.max(...xs);
    return mix(mix((lo + hi) / 2, (lo + p.mx + 18) / 2, p.mouse * 0.9) + p.bowl * 8, BX, p.blob);
  }

  let ids = 0;
  const VIEW = '-12 -12 324 324';
  // the inside of the svg; colors: {ink, field, soft}
  function badge(sec, solid, colors) {
    const p = curl(pose(sec), sec), d = shape(p), id = 'epn' + (ids++ % 1000), c = colors, Z = 0.9;
    const art = solid ? cat(p, sec, c.field, c.ink, c.soft) : cat(p, sec, c.ink, c.field, c.soft);
    return `<clipPath id="${id}"><path d="${d}"/></clipPath><path d="${d}" fill="${solid ? c.ink : 'none'}" stroke="${c.ink}" stroke-width="${solid ? 0 : 9}"/>`
      + `<g clip-path="url(#${id})"><g transform="rotate(${r(spin(p))} 150 150) translate(${r(150 - camera(p) * Z)} 62) scale(${Z})">${art}</g></g>`;
  }
  // the curled-up cat alone in its cushion, bold enough for 16 px
  function curled(colors) {
    const p = pose(NAP);
    p.blob = 1;
    const c = colors, at = curl(p, 0);
    at.head[1] -= 5;                         // clear of the back, so no sliver between the ears
    return `<path d="${shape(pose(NAP))}" fill="${c.ink}"/><g transform="translate(150 152) scale(1.85) translate(${-BX} ${-BY})">${cat(at, 0, c.field, c.ink, c.soft)}</g>`;
  }
  root.EatPreyNap = {LOGO, badge, curled, pose, TOTAL, NAP, VIEW};

  if (typeof document === 'undefined') return;
  const COLORS = {ink: 'var(--logo-ink, #121b48)', field: 'var(--logo-field, #e9d9a0)', soft: 'var(--logo-soft, #b9a05a)'};

  function loadingScreen() {
    const status = document.getElementById('status');
    if (!status || !document.getElementById('status-progress')) return;
    const css = document.createElement('style');
    css.textContent = 'body{background:#e9d9a0}#status-splash{display:none}#status-progress{accent-color:#121b48;max-width:16rem}'
      + '#status svg[data-logo]{width:min(60vw,50vh,22rem);height:auto}'
      + '#status [data-logo-words]{margin:.5rem 0 0;color:#121b48;font:800 clamp(1.5rem,5vw,2.4rem)/1 system-ui,"Segoe UI",sans-serif;letter-spacing:-.02em;display:flex;gap:.35em}';
    document.head.append(css);
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg'), words = document.createElement('p');
    svg.dataset.logo = 'solid';
    words.dataset.logoWords = '';
    status.prepend(svg, words);
  }

  function start() {
    loadingScreen();
    const still = matchMedia('(prefers-reduced-motion: reduce)');
    const svgs = [...document.querySelectorAll('svg[data-logo]')], lines = [...document.querySelectorAll('[data-logo-words]')];
    svgs.forEach(e => { e.setAttribute('viewBox', VIEW); if (!e.hasAttribute('aria-label')) e.setAttribute('aria-hidden', 'true'); });
    lines.forEach(e => { e.replaceChildren(...WORDS.map(w => Object.assign(document.createElement('span'), {textContent: w + ' '}))); });
    svgs.filter(e => e.dataset.logo === 'curl').forEach(e => { e.innerHTML = curled(COLORS); });
    const moving = svgs.filter(e => e.dataset.logo !== 'curl');
    function draw(sec) {
      moving.forEach(e => { if (e.isConnected) e.innerHTML = badge(sec, e.dataset.logo === 'solid', COLORS); });
      const w = pose(sec).words;
      lines.forEach(e => [...e.children].forEach((c, i) => { c.style.opacity = still.matches ? 1 : 0.4 + 0.6 * w[i]; }));
    }
    let sec = 0, last = 0, shown = -1;
    function tick(now) {
      if (![...moving, ...lines].some(e => e.isConnected)) return;     // the loading screen is gone
      const dt = Math.min(0.05, (now - last) / 1000);
      last = now;
      if (still.matches) { if (shown !== NAP) draw(shown = NAP); }
      else { sec = (sec + dt * LOGO.speed) % TOTAL; draw(shown = sec); }
      requestAnimationFrame(tick);
    }
    draw(still.matches ? NAP : 0);
    requestAnimationFrame(tick);
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start); else start();
})(typeof globalThis !== 'undefined' ? globalThis : this);
