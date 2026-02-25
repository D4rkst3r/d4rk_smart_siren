-- ============================================================
--  D4rk Smart Siren – Client / vehicle.lua
-- ============================================================

local hornActive    = false
local lastVehicle   = nil
local playerState   = { sirenTone = 'off', lightsOn = false }

-- aktiver Sound-Handle (einer pro Fahrzeug reicht)
local activeSoundId = nil

local function getLocalVeh()
    return GetVehiclePedIsIn(PlayerPedId(), false)
end

local function isDriver(veh)
    return GetPedInVehicleSeat(veh, -1) == PlayerPedId()
end

local function findToneConfig(toneId)
    for _, t in ipairs(Config.SirenTones) do
        if t.id == toneId then return t end
    end
end

-- ── Siren stoppen ─────────────────────────────────────────────
local function stopSirenSound()
    if activeSoundId ~= nil then
        StopSound(activeSoundId)
        ReleaseSoundId(activeSoundId)
        stopSirenSound()
        SetVehicleHasMutedSirens(veh, false)
        activeSoundId = nil
    end
end

-- ── Siren abspielen ───────────────────────────────────────────
local function applySiren(veh, toneId)
    if not DoesEntityExist(veh) then return end
    if not isDriver(veh) then return end

    local tone = findToneConfig(toneId)
    if not tone then return end

    stopSirenSound()

    if toneId == 'off' then
        SetVehicleSiren(veh, false)
        SetVehicleHasMutedSirens(veh, true)
        UseSirenAsHorn(veh, false)
    elseif toneId == 'manual' then
        -- Tröte: Hupe spielt Sirenenblip beim Drücken
        SetVehicleSiren(veh, false)
        SetVehicleHasMutedSirens(veh, true)
        UseSirenAsHorn(veh, true)
    else
        -- GTA nativen Siren-Sound stumm schalten, eigenen abspielen
        SetVehicleHasMutedSirens(veh, true)
        SetVehicleSiren(veh, true) -- Lichter aktivieren (Blaulicht-Blinken)

        if tone.audioString then
            activeSoundId = GetSoundId()
            PlaySoundFromEntity(
                activeSoundId,
                tone.audioString,
                veh,
                tone.audioRef or '0',
                false, 0
            )
        end
    end

    local netId = NetworkGetNetworkIdFromEntity(veh)
    TriggerServerEvent('smartsiren:server:syncSiren', netId, toneId)
end

-- ── Apply Blaulicht ───────────────────────────────────────────
local function applyBlaulicht(veh, on)
    if not DoesEntityExist(veh) then return end

    SetVehicleLights(veh, on and 2 or 0)

    local name    = GetDisplayNameFromVehicleModel(GetEntityModel(veh)):lower()
    local vehCfg  = Config.Vehicles[name] or Config.DefaultPreset
    local extras  = vehCfg.lightExtras or {}
    local mapping = on and (extras['full'] or extras['on']) or (extras['off'] or nil)

    if mapping then
        for _, extra in ipairs(mapping.extrasOn or {}) do SetVehicleExtra(veh, extra, false) end
        for _, extra in ipairs(mapping.extrasOff or {}) do SetVehicleExtra(veh, extra, true) end
    end

    playerState.lightsOn = on

    local netId = NetworkGetNetworkIdFromEntity(veh)
    TriggerServerEvent('smartsiren:server:syncLights', netId, on)
end

-- ── Horn ──────────────────────────────────────────────────────
-- StopVehicleHorn existiert nicht in FiveM.
-- Stattdessen: kurze Dauer im Loop wiederholen solange gehalten.
AddEventHandler('smartsiren:client:horn', function(pressed)
    local veh = getLocalVeh()
    if not DoesEntityExist(veh) then return end

    if pressed and not hornActive then
        hornActive = true
        SendNUIMessage({ action = 'horn', active = true })
        Citizen.CreateThread(function()
            while hornActive do
                local v = getLocalVeh()
                if DoesEntityExist(v) then
                    StartVehicleHorn(v, 250, GetHashKey('HELDDOWN'), false)
                end
                Citizen.Wait(200)
            end
        end)
    elseif not pressed and hornActive then
        hornActive = false
        SendNUIMessage({ action = 'horn', active = false })
        -- Horn stoppt automatisch wenn keine neuen StartVehicleHorn-Calls kommen
    end
end)

-- ── Event Listeners ───────────────────────────────────────────
AddEventHandler('smartsiren:client:setSiren', function(toneId)
    playerState.sirenTone = toneId
    local veh = getLocalVeh()
    if DoesEntityExist(veh) then applySiren(veh, toneId) end
end)

AddEventHandler('smartsiren:client:setLights', function(on)
    local veh = getLocalVeh()
    if DoesEntityExist(veh) then applyBlaulicht(veh, on) end
end)

-- ── Vehicle Watch Thread ──────────────────────────────────────
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if DoesEntityExist(veh) then
            if veh ~= lastVehicle then
                lastVehicle    = veh
                playerState    = { sirenTone = 'off', lightsOn = false }
                currentTonePos = 0
                if Config.Debug then print('^3[SmartSiren]^7 Neues Fahrzeug erkannt') end
            end
        else
            if lastVehicle then
                lastVehicle = nil
                TriggerEvent('smartsiren:client:vehicleLeft')
            end
        end
    end
end)

-- ── Remote Sync (andere Spieler) ──────────────────────────────
AddEventHandler('smartsiren:client:applyRemoteLights', function(netId, on)
    local veh = NetToVeh(netId)
    if not DoesEntityExist(veh) then return end
    if GetPedInVehicleSeat(veh, -1) == PlayerPedId() then return end
    applyBlaulicht(veh, on)
end)

-- ── GTA Default Control Blocker ───────────────────────────────
local BLOCKED_CONTROLS = {
    200, -- Q    : Radio nächster Sender
    217, -- Q    : Radio Wheel
    86,  -- E    : GTA Hupe / Siren-Toggle
    113, -- CAPS : GTA Sirene an/aus
}

local function isConfiguredVehicle(veh)
    if not DoesEntityExist(veh) then return false end
    local name = GetDisplayNameFromVehicleModel(GetEntityModel(veh)):lower()
    for key, _ in pairs(Config.Vehicles) do
        if key:lower() == name or GetHashKey(key) == GetEntityModel(veh) then
            return true
        end
    end
    return false
end

Citizen.CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if DoesEntityExist(veh) and isConfiguredVehicle(veh) then
            for _, ctrl in ipairs(BLOCKED_CONTROLS) do
                DisableControlAction(0, ctrl, true)
            end
            Citizen.Wait(0)
        else
            Citizen.Wait(500)
        end
    end
end)
