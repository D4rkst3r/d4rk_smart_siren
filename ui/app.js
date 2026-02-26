"use strict";
//
// app.js – KORRIGIERT
//
// BUGFIXES gegenüber Original:
//
// BUG 10 (MITTEL): MIX / FAST Buttons ohne Handler
//   Original: Nur als HTML gerendert, kein addEventListener.
//   Fix: MIX toggled Ton-Mix-Funktion (sendet 'toggleMix' an NUI),
//        FAST schaltet in schnellen Ton-Modus (sendet 'toggleFast').
//   Hinweis: Lua-Seite muss diese Callbacks implementieren.
//
// BUG 11 (GERING): LAMP / MODE Buttons ohne Handler
//   Original: Statische Buttons ohne Funktion.
//   Fix: LAMP → toggleLamp (Innenbeleuchtung o.ä.), MODE → cycleMode.
//
// BUG 12 (GERING): panelHidden unterdrückt visible-Klasse nicht korrekt
//   Original: hud.style.opacity='0' konkurriert mit CSS-Transition.
//   Fix: Eigene CSS-Klasse 'panel-hidden' statt inline-style.
//
// BUG 13 (GERING): Ton-Buttons im initial-State zeigen kein Feedback
//   wenn sirenIndex=1 (OFF) → kein Button markiert als active.
//   Fix: Index 1 = OFF bleibt inaktiv (kein active-Style), ab Index 2
//   wird der entsprechende Button als active markiert.

const hud = document.getElementById("hud");
const toneRow = document.getElementById("toneRow");
const btnStop = document.getElementById("btnStop");
const btnLight = document.getElementById("btnLight");
const btnHide = document.getElementById("btnHide");
const btnLamp = document.getElementById("btnLamp");

// FIX BUG 12: Statt style.opacity direkt CSS-Klasse nutzen
let panelHidden = false;
let state = { visible: false, sirenIndex: 1, lightsOn: false, sirenTones: [] };

function nuiPost(action, data) {
  fetch(`https://d4rk_smart_siren/${action}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data || {}),
  }).catch(() => {});
}

// ── Render Tone Buttons ───────────────────────────────────────
function renderTones(tones, activeIdx) {
  toneRow.innerHTML = "";

  // FIX BUG 10: MIX und FAST mit korrekten Handlern
  const btnMix = document.createElement("button");
  btnMix.className = "btn btn-tone";
  btnMix.innerHTML = '<span class="btn-led"></span>MIX';
  btnMix.title = "Ton-Mix umschalten";
  btnMix.addEventListener("click", () => {
    btnMix.classList.toggle("active");
    nuiPost("toggleMix", { active: btnMix.classList.contains("active") });
  });
  toneRow.appendChild(btnMix);

  const btnFast = document.createElement("button");
  btnFast.className = "btn btn-tone";
  btnFast.innerHTML = '<span class="btn-led"></span>FAST';
  btnFast.title = "Schnell-Modus umschalten";
  btnFast.addEventListener("click", () => {
    btnFast.classList.toggle("active");
    nuiPost("toggleFast", { active: btnFast.classList.contains("active") });
  });
  toneRow.appendChild(btnFast);

  // Dynamische Ton-Buttons
  tones.forEach((t, i) => {
    const btn = document.createElement("button");
    const isHorn = t.id === "manual";
    const isOff = t.id === "off";
    // FIX BUG 13: OFF (Index 0 → sirenIndex 1) niemals als 'active' markieren
    const isActive = !isOff && i + 1 === activeIdx;

    btn.className =
      "btn btn-tone" +
      (isHorn ? " btn-horn" : "") +
      (isActive ? " active" : "");

    btn.dataset.id = t.id;
    btn.dataset.idx = i + 1;
    btn.innerHTML = `<span class="btn-led"></span>${t.label.toUpperCase()}`;

    if (isHorn) {
      btn.addEventListener("mousedown", () => {
        btn.classList.add("pressed");
        nuiPost("hornPress");
      });
      btn.addEventListener("mouseup", () => {
        btn.classList.remove("pressed");
        nuiPost("hornRelease");
      });
      btn.addEventListener("mouseleave", () => {
        btn.classList.remove("pressed");
        nuiPost("hornRelease");
      });
      // Touch-Events für Mobile
      btn.addEventListener("touchstart", (e) => {
        e.preventDefault();
        btn.classList.add("pressed");
        nuiPost("hornPress");
      });
      btn.addEventListener("touchend", (e) => {
        e.preventDefault();
        btn.classList.remove("pressed");
        nuiPost("hornRelease");
      });
    } else {
      btn.addEventListener("click", () =>
        nuiPost("setSiren", { index: i + 1 }),
      );
    }
    toneRow.appendChild(btn);
  });
}

// ── LIGHT ─────────────────────────────────────────────────────
btnLight.innerHTML = '<span class="btn-led"></span>LIGHT';
btnLight.addEventListener("click", () => nuiPost("toggleLights"));

// ── STOP ──────────────────────────────────────────────────────
btnStop.addEventListener("click", () => nuiPost("stop"));

// ── HIDE ──────────────────────────────────────────────────────
// FIX BUG 12: CSS-Klasse statt inline opacity
btnHide.addEventListener("click", () => {
  panelHidden = !panelHidden;
  hud.classList.toggle("panel-hidden", panelHidden);
  btnHide.classList.toggle("active", panelHidden);
});

// FIX BUG 11: LAMP Button Handler
if (btnLamp) {
  btnLamp.innerHTML = '<span class="btn-led"></span>LAMP';
  btnLamp.addEventListener("click", () => {
    btnLamp.classList.toggle("active");
    nuiPost("toggleLamp", { active: btnLamp.classList.contains("active") });
  });
}

// FIX BUG 11: MODE Button Handler
const btnMode = document.querySelector(".btn-util:nth-child(4)");
if (btnMode) {
  btnMode.innerHTML = '<span class="btn-led"></span>MODE';
  let modeIdx = 0;
  btnMode.addEventListener("click", () => {
    modeIdx = (modeIdx + 1) % 3;
    nuiPost("setMode", { mode: modeIdx });
  });
}

// ── Apply state ───────────────────────────────────────────────
function applyState(data) {
  if (data.visible !== undefined) state.visible = data.visible;
  if (data.sirenTones) state.sirenTones = data.sirenTones;
  if (data.sirenIndex !== undefined) state.sirenIndex = data.sirenIndex;
  if (data.lightsOn !== undefined) state.lightsOn = data.lightsOn;

  hud.classList.toggle("hidden", !state.visible);
  hud.classList.toggle("visible", state.visible);

  // FIX BUG 12: panel-hidden überschreibt visible nur per CSS, kein inline-style
  // (CSS: .panel-hidden { opacity: 0 !important; pointer-events: none; })

  if (data.vehicleLabel !== undefined)
    document.getElementById("lblVehicle").textContent =
      data.vehicleLabel || "D4rk Smart Siren";

  if (data.lang && data.isDriver !== undefined)
    document.getElementById("lblSeat").textContent = data.isDriver
      ? data.lang.driver || "Fahrer"
      : data.lang.passenger || "Beifahrer";

  renderTones(state.sirenTones, state.sirenIndex);
  btnLight.classList.toggle("active", state.lightsOn);
}

// ── NUI Messages ─────────────────────────────────────────────
window.addEventListener("message", (e) => {
  const msg = e.data;
  if (!msg?.action) return;
  if (msg.action === "update") applyState(msg);
  if (msg.action === "horn") {
    const hornBtn = toneRow.querySelector('[data-id="manual"]');
    if (hornBtn) hornBtn.classList.toggle("pressed", !!msg.active);
  }
});
