"use strict";

const hud = document.getElementById("hud");
const toneRow = document.getElementById("toneRow");
const bottomRow = document.getElementById("bottomRow");
const btnLight = document.getElementById("btnLight");
const btnStop = document.getElementById("btnStop");
const statusTone = document.getElementById("statusTone");
const statusLights = document.getElementById("statusLights");
const statusVeh = document.getElementById("statusVeh");

let state = {
  visible: false,
  sirenIndex: 1,
  lightsOn: false,
  sirenTones: [],
  vehicleLabel: "",
};

function nuiPost(action, data) {
  fetch(`https://d4rk_smart_siren/${action}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data || {}),
  }).catch(() => {});
}

let lastTonesKey = "";

function buildButtons(tones) {
  toneRow.innerHTML = "";
  bottomRow
    .querySelectorAll(".btn-horn, .btn-qsiren")
    .forEach((el) => el.remove());

  // Tone-Index-Zähler (für Tastenkürzel 1..n, 'off' wird übersprungen)
  let keyIdx = 0;

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
    } else if (t.id === "qsiren") {
      btn.className = "btn btn-qsiren";
      btn.textContent = "Q-SIR";
      btn.dataset.idx = i + 1;
      btn.addEventListener("mousedown", () => {
        btn.classList.add("pressed");
        nuiPost("qsirenPress");
      });
      btn.addEventListener("mouseup", () => btn.classList.remove("pressed"));
      btn.addEventListener("mouseleave", () => btn.classList.remove("pressed"));
      btnStop.before(btn);
    } else {
      keyIdx++;
      btn.className = "btn btn-tone";
      btn.dataset.id = t.id;
      btn.dataset.idx = i + 1;
      // Label + Tastenkürzel-Hint
      btn.innerHTML = `${t.label.toUpperCase()}<span class="key-hint">${keyIdx}</span>`;
      btn.addEventListener("click", () =>
        nuiPost("setSiren", { index: i + 1 }),
      );
      toneRow.appendChild(btn);
    }
  });
}

function render(tones, activeIdx) {
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

function updateStatus(tones, activeIdx, lightsOn, vehicleLabel) {
  // Aktiver Ton
  const tone = tones[activeIdx - 1];
  const isOff = !tone || tone.id === "off";

  if (isOff) {
    statusTone.classList.remove("active");
    statusTone.innerHTML = '<span class="status-dot dot-off"></span>OFF';
  } else {
    statusTone.classList.add("active");
    statusTone.innerHTML = `<span class="status-dot dot-siren"></span>${(tone.label || "").toUpperCase()}`;
  }

  // Blaulicht
  if (lightsOn) {
    statusLights.classList.add("active");
    statusLights.innerHTML = '<span class="status-dot dot-on"></span>BLK AN';
  } else {
    statusLights.classList.remove("active");
    statusLights.innerHTML = '<span class="status-dot dot-off"></span>BLK AUS';
  }

  // Fahrzeugname
  if (statusVeh) statusVeh.textContent = (vehicleLabel || "—").toUpperCase();
}

btnLight.addEventListener("click", () => nuiPost("toggleLights"));
btnStop.addEventListener("click", () => nuiPost("stop"));

function applyState(data) {
  if (data.visible !== undefined) state.visible = data.visible;
  if (data.sirenTones) state.sirenTones = data.sirenTones;
  if (data.sirenIndex !== undefined) state.sirenIndex = data.sirenIndex;
  if (data.lightsOn !== undefined) state.lightsOn = data.lightsOn;
  if (data.vehicleLabel !== undefined) state.vehicleLabel = data.vehicleLabel;

  hud.classList.toggle("hidden", !state.visible);
  hud.classList.toggle("visible", state.visible);

  render(state.sirenTones, state.sirenIndex);
  btnLight.classList.toggle("active", state.lightsOn);
  updateStatus(
    state.sirenTones,
    state.sirenIndex,
    state.lightsOn,
    state.vehicleLabel,
  );
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
