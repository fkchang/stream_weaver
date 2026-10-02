// sw-replay.js -- client-side engine for the `replay` component.
// Vanilla JS, no dependencies: works offline, in an iframe, under a screen recorder.
// Config arrives as JSON in <script type="application/json" class="sw-replay__data">.
// Stages are initialized wherever they appear (first paint, canvas morphs, extension re-renders):
// a MutationObserver inits any new .sw-replay, so injected inline <script> tags (inert after a
// morph) are never needed. A stage removed from the DOM stops its own loop and key handler.
(function () {
  if (window.swReplayInit) return;
  var SPEEDS = [1, 2, 0.5];
  var GAP_MS = 2600;

  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }
  function pad(n) { return (n < 10 ? "0" : "") + n; }

  function init(root) {
    var cfg = JSON.parse(root.querySelector(".sw-replay__data").textContent);
    var $ = function (s) { return root.querySelector(s); };
    var tracks = {}, laneColor = {}, countEls = {}, counts = {};
    var dayEl = $(".sw-replay__day"), clockEl = $(".sw-replay__time"), card = $(".sw-replay__card");
    var playBtn = $(".sw-replay__play"), speedBtn = $(".sw-replay__speed");

    cfg.lanes.forEach(function (l) { laneColor[l.id] = l.color; });
    root.querySelectorAll(".sw-replay__track").forEach(function (t) { tracks[t.dataset.lane] = t; });
    root.querySelectorAll(".sw-replay__n").forEach(function (n) { countEls[n.dataset.key] = n; });

    var w, minute, idx, speed, playing, mode, modeUntil, last, raf;

    function showClock() {
      var d = Math.floor(minute / 1440), mm = Math.floor(minute % 1440);
      dayEl.textContent = cfg.days[d] || "";
      clockEl.textContent = pad(Math.floor(mm / 60)) + ":" + pad(mm % 60);
    }
    function emit(e) {
      var track = tracks[e.lane];
      Array.prototype.forEach.call(track.children, function (c) { c.classList.add("sw-replay__chip--old"); });
      var chip = el("div", "sw-replay__chip" + (e.human ? " sw-replay__chip--human" : ""));
      chip.style.setProperty("--c", laneColor[e.lane]);
      chip.appendChild(el("span", "sw-replay__t", e.t));
      chip.appendChild(document.createTextNode(e.text));
      track.appendChild(chip);
      while (track.children.length > cfg.maxVisible) track.removeChild(track.firstChild);
      Object.keys(e.inc).forEach(function (k) {
        counts[k] += e.inc[k];
        var n = countEls[k];
        n.textContent = counts[k];
        n.classList.add("sw-replay__n--bump");
        setTimeout(function () { n.classList.remove("sw-replay__n--bump"); }, 500);
      });
    }
    function showCard(c) {
      card.textContent = "";
      card.appendChild(el("div", "sw-replay__card-caption", c.caption));
      if (c.sub) card.appendChild(el("small", "sw-replay__card-sub", c.sub));
      card.classList.add("sw-replay__card--show");
    }
    function hideCard() { card.classList.remove("sw-replay__card--show"); }

    function frame(now) {
      if (!root.isConnected) { document.removeEventListener("keydown", onKey); return; }
      raf = requestAnimationFrame(frame);
      var dt = Math.min(now - last, 100);
      last = now;
      if (!playing) return;
      if (mode === "gap") {
        modeUntil -= dt * speed;
        if (modeUntil <= 0) { hideCard(); w++; minute = cfg.windows[w][0]; mode = "run"; showClock(); }
        return;
      }
      if (mode === "done") return;
      minute += dt * speed / cfg.msPerMinute;
      var whole = Math.floor(minute);
      while (idx < cfg.events.length && cfg.events[idx].m <= whole) emit(cfg.events[idx++]);
      if (minute >= cfg.windows[w][1]) {
        minute = cfg.windows[w][1];
        if (w + 1 < cfg.windows.length) {
          mode = "gap"; modeUntil = GAP_MS;
          showCard(cfg.gaps[w] || { caption: "" });
        } else {
          mode = "done";
          if (cfg.finale) showCard(cfg.finale);
        }
      }
      showClock();
    }

    function setPlaying(p) { playing = p; playBtn.textContent = p ? "Pause" : "Play"; }
    function restart() {
      Object.keys(tracks).forEach(function (k) { tracks[k].textContent = ""; });
      Object.keys(countEls).forEach(function (k) { counts[k] = 0; countEls[k].textContent = 0; });
      hideCard();
      w = 0; minute = cfg.windows[0][0]; idx = 0; mode = "run";
      showClock();
      setPlaying(true);
    }
    function cycleSpeed() {
      speed = SPEEDS[(SPEEDS.indexOf(speed) + 1) % SPEEDS.length];
      speedBtn.textContent = speed + "x";
    }

    speed = 1;
    counts = {};
    playBtn.onclick = function () { setPlaying(!playing); };
    $(".sw-replay__restart").onclick = restart;
    speedBtn.onclick = cycleSpeed;
    function onKey(e) {
      if (/^(INPUT|TEXTAREA|SELECT)$/.test(e.target.tagName) || e.target.isContentEditable) return;
      if (e.key === " ") { e.preventDefault(); setPlaying(!playing); }
      else if (e.key === "r") restart();
    }
    document.addEventListener("keydown", onKey);

    root.swReplay = { restart: restart, play: function () { setPlaying(true); }, pause: function () { setPlaying(false); },
                      state: function () { return { mode: mode, minute: minute, counts: counts, playing: playing }; } };
    restart();
    if (!cfg.autoplay) setPlaying(false);
    last = performance.now();
    raf = requestAnimationFrame(frame);
  }

  window.swReplayInit = function () {
    document.querySelectorAll(".sw-replay:not([data-sw-ready])").forEach(function (r) {
      r.setAttribute("data-sw-ready", "1");
      init(r);
    });
  };
  function watch() {
    window.swReplayInit();
    new MutationObserver(function () { window.swReplayInit(); })
      .observe(document.documentElement, { childList: true, subtree: true });
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", watch);
  else watch();
})();
