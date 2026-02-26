'use strict';

const hud      = document.getElementById('hud');
const toneRow  = document.getElementById('toneRow');
const btnStop  = document.getElementById('btnStop');
const btnLight = document.getElementById('btnLight');
const btnHide  = document.getElementById('btnHide');

let panelHidden = false;
let state = { visible: false, sirenIndex: 1, lightsOn: false, sirenTones: [] };

function nuiPost(action, data) {
  fetch(`https://d4rk_smart_siren/${action}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data || {})
  }).catch(() => {});
}

// ── Render Tone Buttons ───────────────────────────────────────
function renderTones(tones, activeIdx) {
  toneRow.innerHTML =
    `<button class="btn btn-tone"><span class="btn-led"></span>MIX</button>` +
    `<button class="btn btn-tone"><span class="btn-led"></span>FAST</button>`;

  tones.forEach((t, i) => {
    const btn     = document.createElement('button');
    const isHorn  = t.id === 'manual';
    const isOff   = t.id === 'off';
    const isActive = (i + 1) === activeIdx;

    btn.className = 'btn btn-tone'
      + (isHorn  ? ' btn-horn'  : '')
      + (isActive ? ' active'   : '');

    btn.dataset.id  = t.id;
    btn.dataset.idx = i + 1;
    btn.innerHTML   = `<span class="btn-led"></span>${t.label.toUpperCase()}`;

    if (isHorn) {
      btn.addEventListener('mousedown',  () => { btn.classList.add('pressed');    nuiPost('hornPress'); });
      btn.addEventListener('mouseup',    () => { btn.classList.remove('pressed'); nuiPost('hornRelease'); });
      btn.addEventListener('mouseleave', () => { btn.classList.remove('pressed'); nuiPost('hornRelease'); });
    } else {
      btn.addEventListener('click', () => nuiPost('setSiren', { index: i + 1 }));
    }
    toneRow.appendChild(btn);
  });
}

// ── LIGHT ─────────────────────────────────────────────────────
btnLight.innerHTML = '<span class="btn-led"></span>LIGHT';
btnLight.addEventListener('click', () => nuiPost('toggleLights'));

// ── STOP ──────────────────────────────────────────────────────
btnStop.addEventListener('click', () => nuiPost('stop'));

// ── HIDE ──────────────────────────────────────────────────────
btnHide.addEventListener('click', () => {
  panelHidden = !panelHidden;
  hud.style.opacity = panelHidden ? '0' : '';
});

// ── Apply state ───────────────────────────────────────────────
function applyState(data) {
  if (data.visible    !== undefined) state.visible    = data.visible;
  if (data.sirenTones)               state.sirenTones = data.sirenTones;
  if (data.sirenIndex !== undefined) state.sirenIndex = data.sirenIndex;
  if (data.lightsOn   !== undefined) state.lightsOn   = data.lightsOn;

  hud.classList.toggle('hidden',  !state.visible);
  hud.classList.toggle('visible',  state.visible);
  if (panelHidden) hud.style.opacity = '0';

  if (data.vehicleLabel !== undefined)
    document.getElementById('lblVehicle').textContent = data.vehicleLabel || 'D4rk Smart Siren';

  if (data.lang && data.isDriver !== undefined)
    document.getElementById('lblSeat').textContent =
      data.isDriver ? (data.lang.driver || 'Fahrer') : (data.lang.passenger || 'Beifahrer');

  renderTones(state.sirenTones, state.sirenIndex);
  btnLight.classList.toggle('active', state.lightsOn);
}

// ── NUI Messages ─────────────────────────────────────────────
window.addEventListener('message', e => {
  const msg = e.data;
  if (!msg?.action) return;
  if (msg.action === 'update') applyState(msg);
  if (msg.action === 'horn') {
    const hornBtn = toneRow.querySelector('[data-id="manual"]');
    if (hornBtn) hornBtn.classList.toggle('pressed', !!msg.active);
  }
});
