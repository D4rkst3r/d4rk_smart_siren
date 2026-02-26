-- ============================================================
--  D4rk Smart Siren – Client / main.lua  [KORRIGIERT]
-- ============================================================
--
-- BUGFIXES:
--
-- BUG 8 (MITTEL): NUI-Panel blieb nach Fahrzeugwechsel im falschen
--   Zustand. Der interactMode wurde beim Aussteigen zwar auf false gesetzt,
--   aber SetNuiFocusKeepInput(false) fehlte → Maus blieb gesperrt.
--   Fix: Beide NUI-Fokus-Calls beim Aussteigen.
--
-- BUG 9 (GERING): isDriver-Flag wurde nicht aktualisiert wenn Spieler
--   Sitz wechselt (z.B. von Beifahrer zu Fahrer nach Aussteigen des Fahrers).
--   Fix: Sitz-Check läuft in jedem Tick, Flag wird korrekt aktualisiert.
--
-- HINWEIS AllowedSeats='both':
--   Passagiere sehen das Panel, können aber keine Sirene aktivieren –
--   applySiren() in vehicle.lua prüft isDriverOf(). Das ist gewollt.
--   Nur Fahrer kann Töne/Lichter steuern. UI zeigt Passagier-Status an.

local inVehicle    = false
local currentVeh   = 0
local isDriver     = false
local interactMode = false

local state        = {
    sirenIndex = 1,
    lightsOn   = false,
}

local activeVehCfg = nil
local activeTones  = {}

-- ── Helpers ───────────────────────────────────────────────────
local function dbg(msg)
    if Config.Debug then print('^3[SmartSiren]^7 ' .. tostring(msg)) end
end

local function getPedSeat(ped, veh)
    if GetPedInVehicleSeat(veh, -1) == ped then return -1 end
    if GetPedInVehicleSeat(veh, 0) == ped then return 0 end
    for i = 1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
        if GetPedInVehicleSeat(veh, i) == ped then return i end
    end
    return -2
end

local function getVehicleConfig(model)
    local name = GetDisplayNameFromVehicleModel(model):lower()
    for k, cfg in pairs(Config.Vehicles) do
        if k ~= 'DEFAULT' and k:lower() == name then return cfg end
    end
    return Config.Vehicles['DEFAULT'] or { tones = { 'off', 2, 3, 4, 'manual' }, extras = {} }
end

local function buildActiveTones(cfg)
    activeTones = {}
    for _, toneEntry in ipairs(cfg.tones or {}) do
        if toneEntry == 'off' then
            activeTones[#activeTones + 1] = { entry = 'off', id = 'off', label = 'OFF' }
        elseif toneEntry == 'manual' then
            activeTones[#activeTones + 1] = { entry = 'manual', id = 'manual', label = 'HORN' }
        else
            local siren = Config.Sirens[toneEntry]
            if siren then
                activeTones[#activeTones + 1] = {
                    entry = toneEntry,
                    id    = 'siren_' .. toneEntry,
                    label = siren.Name,
                }
            end
        end
    end
end

-- ── NUI Update ────────────────────────────────────────────────
local function updateNUI()
    SendNUIMessage({
        action       = 'update',
        visible      = inVehicle,
        sirenIndex   = state.sirenIndex,
        lightsOn     = state.lightsOn,
        sirenTones   = activeTones,
        vehicleLabel = activeVehCfg and (activeVehCfg.label or 'D4rk Smart Siren') or 'D4rk Smart Siren',
        isDriver     = isDriver,
        lang         = Config.Translations[Config.Language],
    })
end

-- ── Siren ─────────────────────────────────────────────────────
local function setSirenByIndex(idx)
    if #activeTones == 0 then return end
    idx = math.max(1, math.min(idx, #activeTones))

    -- Toggle: denselben Ton nochmal drücken → zurück auf OFF (Index 1)
    -- Index 1 ist immer 'off' (buildActiveTones garantiert das)
    if state.sirenIndex == idx and idx ~= 1 then
        idx = 1
    end

    state.sirenIndex = idx
    local tone = activeTones[idx]
    TriggerEvent('smartsiren:client:setSiren', tone.entry)
    dbg('Siren → ' .. tostring(tone.entry) .. ' (' .. tone.label .. ')')
    updateNUI()
end

-- ── Blaulicht toggle ──────────────────────────────────────────
local function toggleLights()
    state.lightsOn = not state.lightsOn
    TriggerEvent('smartsiren:client:setLights', state.lightsOn)
    dbg('Lights → ' .. tostring(state.lightsOn))
    updateNUI()
end

-- ── NUI-Fokus aufräumen ───────────────────────────────────────
-- FIX BUG 8: Beide NUI-Fokus-Calls beim Verlassen
local function closeInteract()
    if interactMode then
        interactMode = false
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false) -- War im Original vergessen!
    end
end

-- ── Keybinds ──────────────────────────────────────────────────
RegisterCommand('ss_lights', function()
    if not inVehicle then return end
    toggleLights()
end, false)
RegisterKeyMapping('ss_lights', 'Sirene: Blaulicht an/aus', 'keyboard', Config.Keys.LightsNext)

for i = 1, 9 do
    local slot = i
    RegisterCommand('ss_tone_' .. slot, function()
        if not inVehicle then return end
        if slot <= #activeTones then setSirenByIndex(slot) end
    end, false)
    RegisterKeyMapping('ss_tone_' .. slot, 'Sirene: Ton ' .. slot, 'keyboard', Config.Keys.Tones[slot] or '')
end

RegisterCommand('+ss_horn', function()
    if not inVehicle or not isDriver then return end
    TriggerEvent('smartsiren:client:horn', true)
end, false)
RegisterCommand('-ss_horn', function()
    TriggerEvent('smartsiren:client:horn', false)
end, false)
RegisterKeyMapping('+ss_horn', 'Sirene: Tröte / Horn halten', 'keyboard', Config.Keys.Horn)

RegisterCommand('ss_interact', function()
    if not inVehicle then return end
    interactMode = not interactMode
    SetNuiFocus(interactMode, interactMode)
    SetNuiFocusKeepInput(interactMode)
end, false)
RegisterKeyMapping('ss_interact', 'Sirene: Panel Maus-Interaktion', 'keyboard', Config.Keys.Interact or 'CAPSLOCK')

-- ── NUI Callbacks ─────────────────────────────────────────────
RegisterNUICallback('setSiren', function(data, cb)
    if not inVehicle then
        cb({})
        return
    end
    local idx = tonumber(data.index)
    if idx then setSirenByIndex(idx) end
    cb({})
end)

RegisterNUICallback('toggleLights', function(_, cb)
    if not inVehicle then
        cb({})
        return
    end
    toggleLights()
    cb({})
end)

RegisterNUICallback('hornPress', function(_, cb)
    TriggerEvent('smartsiren:client:horn', true)
    cb({})
end)

RegisterNUICallback('hornRelease', function(_, cb)
    TriggerEvent('smartsiren:client:horn', false)
    cb({})
end)

RegisterNUICallback('stop', function(_, cb)
    if not inVehicle then
        cb({})
        return
    end
    state.sirenIndex = 1
    state.lightsOn   = false
    TriggerEvent('smartsiren:client:setSiren', 'off')
    TriggerEvent('smartsiren:client:setLights', false)
    updateNUI()
    cb({})
end)

-- ── Vehicle Watch Thread ──────────────────────────────────────
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(300)
        local ped  = PlayerPedId()
        local veh  = GetVehiclePedIsIn(ped, false)
        local seat = -2
        if DoesEntityExist(veh) then seat = getPedSeat(ped, veh) end

        local allowed = false
        if Config.AllowedSeats == 'driver' then
            allowed = seat == -1
        elseif Config.AllowedSeats == 'passenger' then
            allowed = seat == 0
        else
            allowed = seat == -1 or seat == 0
        end

        if DoesEntityExist(veh) and allowed then
            if veh ~= currentVeh then
                currentVeh   = veh
                inVehicle    = true
                isDriver     = (seat == -1)
                state        = { sirenIndex = 1, lightsOn = false }
                activeVehCfg = getVehicleConfig(GetEntityModel(veh))
                buildActiveTones(activeVehCfg)
                dbg('Eingestiegen: ' .. GetDisplayNameFromVehicleModel(GetEntityModel(veh)))
                updateNUI()
            elseif (seat == -1) ~= isDriver then
                -- FIX BUG 9: Sitz-Wechsel (Fahrer ↔ Beifahrer) korrekt tracken
                isDriver = (seat == -1)
                dbg('Sitz gewechselt → isDriver=' .. tostring(isDriver))
                updateNUI()
            end
        else
            if inVehicle then
                inVehicle  = false
                currentVeh = 0
                isDriver   = false
                state      = { sirenIndex = 1, lightsOn = false }
                -- FIX BUG 8: closeInteract statt inline-Code
                closeInteract()
                updateNUI()
                dbg('Ausgestiegen')
            end
        end
    end
end)
