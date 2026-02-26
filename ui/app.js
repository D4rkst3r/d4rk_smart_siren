"use strict";

const hud = document.getElementById("hud");
const toneRow = document.getElementById("toneRow");
const bottomRow = document.getElementById("bottomRow");
const btnLight = document.getElementById("btnLight");
const btnStop = document.getElementById("btnStop");

let state = { visible: false, sirenIndex: 1, lightsOn: false, sirenTones: [] };

function nuiPost(action, data) {
  fetch(`https://d4rk_smart_siren/${action}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data || {}),
  }).catch(() => {});
}

// Letzter Tone-Key zum Vergleich – DOM nur neu bauen wenn sich die Töne ändern
let lastTonesKey = "";

function buildButtons(tones) {
  toneRow.innerHTML = "";
  bottomRow.querySelectorAll(".btn-horn").forEach((el) => el.remove());

  tones.forEach((t, i) => {
    if (t.id === "off") return;

    const btn = document.createElement("button");
    if (t.id === "manual") {
      btn.className = "btn btn-horn";
      btn.textContent = t.label.toUpperCase();
      btn.dataset.idx = i + 1;
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
      btnStop.before(btn);
    } else {
      btn.className = "btn btn-tone";
      btn.textContent = t.label.toUpperCase();
      btn.dataset.id = t.id;
      btn.dataset.idx = i + 1;
      btn.addEventListener("click", () =>
        nuiPost("setSiren", { index: i + 1 }),
      );
      toneRow.appendChild(btn);
    }
  });
}

function render(tones, activeIdx) {
  // DOM nur neu bauen wenn sich die Töne geändert haben (anderes Fahrzeug)
  const tonesKey = tones.map((t) => t.id).join(",");
  if (tonesKey !== lastTonesKey) {
    lastTonesKey = tonesKey;
    buildButtons(tones);
  }

  // Nur Klassen aktualisieren – kein DOM-Rebuild
  toneRow.querySelectorAll(".btn-tone").forEach((btn) => {
    btn.classList.toggle("active", Number(btn.dataset.idx) === activeIdx);
  });
  const hornBtn = bottomRow.querySelector(".btn-horn");
  if (hornBtn)
    hornBtn.classList.toggle(
      "active",
      Number(hornBtn.dataset.idx) === activeIdx,
    );
}

btnLight.addEventListener("click", () => nuiPost("toggleLights"));
btnStop.addEventListener("click", () => nuiPost("stop"));

function applyState(data) {
  if (data.visible !== undefined) state.visible = data.visible;
  if (data.sirenTones) state.sirenTones = data.sirenTones;
  if (data.sirenIndex !== undefined) state.sirenIndex = data.sirenIndex;
  if (data.lightsOn !== undefined) state.lightsOn = data.lightsOn;

  hud.classList.toggle("hidden", !state.visible);
  hud.classList.toggle("visible", state.visible);

  render(state.sirenTones, state.sirenIndex);
  btnLight.classList.toggle("active", state.lightsOn);
}

window.addEventListener("message", (e) => {
  const msg = e.data;
  if (!msg?.action) return;
  if (msg.action === "update") applyState(msg);
  if (msg.action === "horn") {
    const hornBtn = bottomRow.querySelector(".btn-horn");
    if (hornBtn) hornBtn.classList.toggle("pressed", !!msg.active);
  }
});
