-- ============================================================
--  D4rk Smart Siren – Client / main.lua  [KORRIGIERT]
-- ============================================================
--
-- BUGFIXES:
--
-- BUG 9 (GERING): isDriver-Flag wurde nicht aktualisiert wenn Spieler
--   Sitz wechselt (z.B. von Beifahrer zu Fahrer nach Aussteigen des Fahrers).
--   Fix: Sitz-Check läuft in jedem Tick, Flag wird korrekt aktualisiert.
--
-- HINWEIS AllowedSeats='both':
--   Passagiere sehen das Panel, können aber keine Sirene aktivieren –
--   applySiren() in vehicle.lua prüft isDriverOf(). Das ist gewollt.
--   Nur Fahrer kann Töne/Lichter steuern. UI zeigt Passagier-Status an.

local inVehicle     = false
local currentVeh    = 0
local lastExitedVeh = 0 -- letztes verlassenes Fahrzeug (für Wiedereinstieg)
local isDriver      = false
local state         = {
    sirenIndex = 1,
    lightsOn   = false,
}

local activeVehCfg  = nil
local activeTones   = {}

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
    local vehLabel = ''
    if inVehicle and DoesEntityExist(currentVeh) then
        vehLabel = GetDisplayNameFromVehicleModel(GetEntityModel(currentVeh)):upper()
    end
    SendNUIMessage({
        action       = 'update',
        visible      = inVehicle,
        sirenIndex   = state.sirenIndex,
        lightsOn     = state.lightsOn,
        sirenTones   = activeTones,
        vehicleLabel = vehLabel,
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

RegisterCommand('+ss_qsiren', function()
    if not inVehicle then return end
    TriggerEvent('smartsiren:client:qsiren')
end, false)
RegisterCommand('-ss_qsiren', function() end, false)
RegisterKeyMapping('+ss_qsiren', 'Sirene: Q-Siren (Kurzstoß)', 'keyboard', Config.Keys.QSiren or 'r')

RegisterCommand('+ss_horn', function()
    if not inVehicle or not isDriver then return end
    TriggerEvent('smartsiren:client:horn', true)
end, false)
RegisterCommand('-ss_horn', function()
    TriggerEvent('smartsiren:client:horn', false)
end, false)
RegisterKeyMapping('+ss_horn', 'Sirene: Tröte / Horn halten', 'keyboard', Config.Keys.Horn)

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

RegisterNUICallback('qsirenPress', function(_, cb)
    TriggerEvent('smartsiren:client:qsiren')
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
                currentVeh = veh
                inVehicle  = true
                isDriver   = (seat == -1)

                if veh == lastExitedVeh then
                    -- Gleiches Fzg: Config + Töne sind noch gültig, nicht neu bauen
                    -- Gleiches Fahrzeug wieder betreten → State wiederherstellen.
                    -- RACE CONDITION FIX: vehicle.lua läuft mit 500ms, main.lua
                    -- mit 300ms. Wir spawnen einen eigenen Thread der 600ms wartet
                    -- (> 500ms) damit vehicle.lua suppressReset gesetzt + seinen
                    -- Tick fertig hat bevor wir setSiren/setLights triggern.
                    local savedSirenIdx = state.sirenIndex
                    local savedLightsOn = state.lightsOn
                    local savedVeh      = veh
                    Citizen.CreateThread(function()
                        Citizen.Wait(600)
                        -- Sicherstellen dass Spieler noch im selben Fzg sitzt
                        if GetVehiclePedIsIn(PlayerPedId(), false) ~= savedVeh then return end
                        local tone = activeTones[savedSirenIdx]
                        if tone and tone.entry ~= 'off' then
                            TriggerEvent('smartsiren:client:setSiren', tone.entry)
                        end
                        if savedLightsOn then
                            TriggerEvent('smartsiren:client:setLights', true)
                        end
                        dbg('Wiedereinstieg – State re-applied nach 600ms (sirenIndex='
                            .. tostring(savedSirenIdx) .. ' lightsOn='
                            .. tostring(savedLightsOn) .. ')')
                    end)
                else
                    -- Neues Fahrzeug → Config + Töne neu laden, State resetten
                    activeVehCfg = getVehicleConfig(GetEntityModel(veh))
                    buildActiveTones(activeVehCfg)
                    state = { sirenIndex = 1, lightsOn = false }
                    dbg('Eingestiegen (neu): ' .. GetDisplayNameFromVehicleModel(GetEntityModel(veh)))
                end
                lastExitedVeh = 0
                updateNUI()
            elseif (seat == -1) ~= isDriver then
                -- FIX BUG 9: Sitz-Wechsel (Fahrer ↔ Beifahrer) korrekt tracken
                isDriver = (seat == -1)
                dbg('Sitz gewechselt → isDriver=' .. tostring(isDriver))
                updateNUI()
            end
        else
            if inVehicle then
                inVehicle     = false
                lastExitedVeh = currentVeh   -- merken welches Fzg verlassen
                currentVeh    = 0
                isDriver      = false
                -- State NICHT nullen: Sirene/Licht laufen am Fahrzeug weiter.
                -- Beim Wiedereinsteigen zeigt die UI den korrekten Zustand.
                updateNUI()
                dbg('Ausgestiegen – State behalten (sirenIndex='
                    .. tostring(state.sirenIndex) .. ' lightsOn='
                    .. tostring(state.lightsOn) .. ')')
            end
        end
    end
end)
