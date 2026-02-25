-- ============================================================
--  D4rk Smart Siren – Client / main.lua
-- ============================================================

local inVehicle  = false
local currentVeh = 0
local isDriver   = false

local state = {
    sirenIndex = 1,   -- 1 = erste Tone (OFF)
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
    if GetPedInVehicleSeat(veh,  0) == ped then return  0 end
    for i = 1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
        if GetPedInVehicleSeat(veh, i) == ped then return i end
    end
    return -2
end

local function getVehicleConfig(model)
    local name = GetDisplayNameFromVehicleModel(model):lower()
    for k, cfg in pairs(Config.Vehicles) do
        if k:lower() == name or GetHashKey(k) == model then return cfg end
    end
    return Config.DefaultPreset
end

local function buildFilteredTones(cfg)
    activeTones = {}
    for _, tone in ipairs(Config.SirenTones) do
        for _, allowed in ipairs(cfg.allowedSirenTones) do
            if tone.id == allowed then activeTones[#activeTones+1] = tone end
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
        vehicleLabel = activeVehCfg and (activeVehCfg.label or '') or '',
        isDriver     = isDriver,
        lang         = Config.Translations[Config.Language],
    })
end

-- ── Siren ─────────────────────────────────────────────────────
local function setSirenByIndex(idx)
    if #activeTones == 0 then return end
    idx = math.max(1, math.min(idx, #activeTones))
    state.sirenIndex = idx
    TriggerEvent('smartsiren:client:setSiren', activeTones[idx].id)
    dbg('Siren → ' .. activeTones[idx].id)
    updateNUI()
end

local function cycleSiren(dir)
    local next = state.sirenIndex + dir
    if next > #activeTones then next = 1 end
    if next < 1             then next = #activeTones end
    setSirenByIndex(next)
end

-- ── Blaulicht toggle ──────────────────────────────────────────
local function toggleLights()
    state.lightsOn = not state.lightsOn
    TriggerEvent('smartsiren:client:setLights', state.lightsOn)
    dbg('Lights → ' .. tostring(state.lightsOn))
    updateNUI()
end

-- ── Keybinds ──────────────────────────────────────────────────
-- Q = Blaulicht an/aus
RegisterCommand('ss_lights', function()
    if not inVehicle then return end
    toggleLights()
end, false)
RegisterKeyMapping('ss_lights', 'Sirene: Blaulicht an/aus', 'keyboard', Config.Keys.LightsNext)

-- Direkte Siren-Slots 1–9
for i = 1, 9 do
    local slot = i
    RegisterCommand('ss_tone_' .. slot, function()
        if not inVehicle then return end
        if slot <= #activeTones then setSirenByIndex(slot) end
    end, false)
    RegisterKeyMapping('ss_tone_' .. slot, 'Sirene: Ton ' .. slot, 'keyboard', Config.Keys.Tones[slot] or '')
end

-- E = Horn (halten)
RegisterCommand('+ss_horn', function()
    if not inVehicle or not isDriver then return end
    TriggerEvent('smartsiren:client:horn', true)
    updateNUI()
end, false)
RegisterCommand('-ss_horn', function()
    TriggerEvent('smartsiren:client:horn', false)
    updateNUI()
end, false)
RegisterKeyMapping('+ss_horn', 'Sirene: Tröte / Horn halten', 'keyboard', Config.Keys.Horn)

-- CAPSLOCK = Maus-Interaktion Panel
local interactMode = false
RegisterCommand('ss_interact', function()
    if not inVehicle then return end
    interactMode = not interactMode
    SetNuiFocus(interactMode, interactMode)
    SetNuiFocusKeepInput(interactMode)
end, false)
RegisterKeyMapping('ss_interact', 'Sirene: Panel Maus-Interaktion', 'keyboard', Config.Keys.Interact or 'CAPSLOCK')

-- ── NUI Callbacks (Panel-Klicks) ──────────────────────────────
RegisterNUICallback('setSiren', function(data, cb)
    if not inVehicle then cb({}) return end
    local idx = tonumber(data.index)
    if idx then setSirenByIndex(idx) end
    cb({})
end)

RegisterNUICallback('toggleLights', function(_, cb)
    if not inVehicle then cb({}) return end
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
    if not inVehicle then cb({}) return end
    state.sirenIndex = 1
    state.lightsOn   = false
    TriggerEvent('smartsiren:client:setSiren', activeTones[1] and activeTones[1].id or 'off')
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
        if Config.AllowedSeats == 'driver'    then allowed = seat == -1
        elseif Config.AllowedSeats == 'passenger' then allowed = seat == 0
        else allowed = seat == -1 or seat == 0 end

        if DoesEntityExist(veh) and allowed then
            if veh ~= currentVeh then
                currentVeh   = veh
                inVehicle    = true
                isDriver     = (seat == -1)
                state        = { sirenIndex = 1, lightsOn = false }
                activeVehCfg = getVehicleConfig(GetEntityModel(veh))
                buildFilteredTones(activeVehCfg)
                dbg('Eingestiegen: ' .. GetDisplayNameFromVehicleModel(GetEntityModel(veh)))
                updateNUI()
            elseif (seat == -1) ~= isDriver then
                isDriver = (seat == -1)
                updateNUI()
            end
        else
            if inVehicle then
                inVehicle  = false
                currentVeh = 0
                isDriver   = false
                state      = { sirenIndex = 1, lightsOn = false }
                if interactMode then
                    interactMode = false
                    SetNuiFocus(false, false)
                end
                updateNUI()
                dbg('Ausgestiegen')
            end
        end
    end
end)
