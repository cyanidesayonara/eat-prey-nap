// Keeps a cat in the web game while it plays. src/guard.gd calls on() when
// play starts and off() when the human leaves.
//
// - fullscreen, and back into it at the next paw if something ends it
// - Back (button, gesture, key) is swallowed
// - closing or reloading the tab asks first
// - Esc reaches the game where the browser allows it (Chromium, fullscreen)
// - landscape, screen kept on, no long-press menu, no pull to refresh
//
// A page cannot block the system: home and app-switch gestures, or a tab's
// own close button. For those: Android's screen pinning, iPad's Guided Access.
(function () {
  'use strict';
  let active = false, trapped = false, lock = null;
  const quiet = p => { if (p && p.catch) p.catch(() => {}); };

  function fullscreen() {
    const el = document.documentElement;
    if (document.fullscreenElement || !el.requestFullscreen) return;
    const done = () => {
      if (screen.orientation && screen.orientation.lock) quiet(screen.orientation.lock('landscape'));
      if (navigator.keyboard && navigator.keyboard.lock) quiet(navigator.keyboard.lock(['Escape']));
    };
    const p = el.requestFullscreen({navigationUI: 'hide'});
    if (p && p.then) p.then(done, () => {}); else done();
  }

  async function awake() {
    if (!active || lock || !navigator.wakeLock || document.visibilityState !== 'visible') return;
    try {
      const got = await navigator.wakeLock.request('screen');
      if (!active) { quiet(got.release()); return; }
      lock = got;
      lock.addEventListener('release', () => { lock = null; });
    } catch (e) { /* low battery, or not allowed here */ }
  }

  function trap() {
    if (trapped) return;
    history.pushState({epn: true}, '');
    trapped = true;
  }

  window.addEventListener('popstate', () => {
    trapped = false;
    if (active) trap();
  });
  window.addEventListener('beforeunload', e => {
    if (!active) return;
    e.preventDefault();
    e.returnValue = '';
  });
  // a browser grants fullscreen on a finger lifted, not on one put down
  window.addEventListener('pointerup', () => { if (active) { fullscreen(); awake(); } }, true);
  window.addEventListener('touchend', () => { if (active) fullscreen(); }, true);
  document.addEventListener('visibilitychange', awake);
  document.addEventListener('contextmenu', e => e.preventDefault());

  const css = document.createElement('style');
  css.textContent = 'html,body{overscroll-behavior:none;-webkit-touch-callout:none;-webkit-user-select:none;user-select:none}';
  document.head.append(css);

  window.EPNGuard = {
    on() { active = true; trap(); fullscreen(); awake(); },
    off() {
      active = false;
      if (navigator.keyboard && navigator.keyboard.unlock) navigator.keyboard.unlock();
      if (document.fullscreenElement) quiet(document.exitFullscreen());
      if (lock) { quiet(lock.release()); lock = null; }
      if (trapped) history.back();
    },
    get active() { return active; }
  };
})();
