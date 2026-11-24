// The website's theme: the game's three palettes. Loaded in the head, not
// deferred, so a page never flashes the wrong colours. The choice is kept in
// this browser only.
(function () {
  'use strict';
  const THEMES = {straw: 'Straw', night: 'Ink blue', grey: 'Grey'};
  const KEY = 'epn-theme';
  const root = document.documentElement;
  const set = name => { root.dataset.theme = THEMES[name] ? name : 'straw'; };
  let saved = null;
  try { saved = localStorage.getItem(KEY); } catch (e) { /* storage is blocked */ }
  set(saved);

  document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('[data-themes]').forEach(box => {
      const legend = document.createElement('legend');
      legend.textContent = 'Colours';
      box.append(legend);
      for (const name in THEMES) {
        const label = document.createElement('label'), input = document.createElement('input'), text = document.createElement('span');
        Object.assign(input, {type: 'radio', name: 'theme', value: name, checked: root.dataset.theme === name});
        input.addEventListener('change', () => {
          set(name);
          try { localStorage.setItem(KEY, name); } catch (e) { /* lasts for this page */ }
        });
        text.textContent = THEMES[name];
        label.className = 'swatch ' + name;
        label.append(input, text);
        box.append(label);
      }
      box.hidden = false;
    });
  });
})();
