-- ============================================================
--  D4rk Smart Siren – Client / vehicle.lua
-- ============================================================

local sirenEnabled  = false
local activeSirenId = nil
local hornActive    = false
local lastVehicle   = nil
local playerState   = { sirenTone = 'off', lightsOn = false }

-- ── Utility ───────────────────────────────────────────────────
local function getLocalVeh()
    return GetVehiclePedIsIn(PlayerPedId(), false)
end

local function isDriver(veh)
    return GetPedInVehicleSeat(veh, -1) == PlayerPedId()
end

-- ── Siren Tone Tracking ───────────────────────────────────────
-- GTA cycles tones intern via TriggerSiren().
-- Wir tracken die aktuelle Position um gezielt springen zu können.
local currentTonePos = 0   -- 0 = aus / unbekannt, 1–N = aktiver Ton-Index

local function resetSirenTonePosition(veh)
    -- Sirene komplett aus- und wieder einschalten setzt den Ton auf Index 0 zurück.
    -- Danach ist der nächste TriggerSiren()-Aufruf Ton 1.
    SetVehicleSiren(veh, false)
    Citizen.Wait(50)
    SetVehicleSiren(veh, true)
    currentTonePos = 0
end

local function cycleSirenToIndex(veh, targetIndex)
    -- targetIndex: 1-basiert (1 = erster Ton nach Reset)
    -- Erst auf 0 zurücksetzen, dann targetIndex-mal TriggerSiren aufrufen
    resetSirenTonePosition(veh)
    Citizen.Wait(50)
    for i = 1, targetIndex do
        TriggerSiren(veh)
        Citizen.Wait(30)
    end
    currentTonePos = targetIndex
end

local function applySiren(veh, toneId)
    if not DoesEntityExist(veh) then return end
    if not isDriver(veh) then return end

    local tone = findToneConfig(toneId)
    if not tone then return end

    if toneId == 'off' then
        -- Alles deaktivieren
        SetVehicleSiren(veh, false)
        SetVehicleHasMutedSirens(veh, true)
        UseSirenAsHorn(veh, false)
        SetSirenKeepOn(veh, false)
        sirenEnabled  = false
        activeSirenId = nil
        currentTonePos = 0

    elseif toneId == 'manual' then
        -- Tröte-Modus: Sirene stumm, Horn spielt Sirenenton
        SetVehicleSiren(veh, false)
        SetVehicleHasMutedSirens(veh, true)
        UseSirenAsHorn(veh, true)   -- Hupe = Sirenenblip
        SetSirenKeepOn(veh, false)
        sirenEnabled  = false
        activeSirenId = 'manual'
        currentTonePos = 0

    else
        -- Normaler Dauerton
        UseSirenAsHorn(veh, false)
        SetVehicleHasMutedSirens(veh, false)
        SetSirenKeepOn(veh, true)   -- Ton bleibt auch ohne Tastendruck an

        -- Zum gewünschten Ton-Index cyclen (sirenId aus Config = Anzahl TriggerSiren-Calls)
        if tone.sirenId and tone.sirenId > 0 then
            Citizen.CreateThread(function()
                cycleSirenToIndex(veh, tone.sirenId)
            end)
        else
            SetVehicleSiren(veh, true)
        end

        sirenEnabled  = true
        activeSirenId = toneId
    end

    local netId = NetworkGetNetworkIdFromEntity(veh)
    TriggerServerEvent('smartsiren:server:syncSiren', netId, toneId)
end

-- ── Blaulicht (einfach an/aus) ────────────────────────────────
local function applyBlaulicht(veh, on)
    if not DoesEntityExist(veh) then return end

    if on then
        SetVehicleLights(veh, 2)
    else
        SetVehicleLights(veh, 0)
    end

    -- Extras aus Config anwenden
    local model   = GetEntityModel(veh)
    local name    = GetDisplayNameFromVehicleModel(model):lower()
    local vehCfg  = Config.Vehicles[name] or Config.DefaultPreset
    local extras  = vehCfg.lightExtras or {}
    local mapping = on and (extras['full'] or extras['on']) or (extras['off'] or nil)

    if mapping then
        for _, extra in ipairs(mapping.extrasOn  or {}) do SetVehicleExtra(veh, extra, false) end
        for _, extra in ipairs(mapping.extrasOff or {}) do SetVehicleExtra(veh, extra, true)  end
    end

    playerState.lightsOn = on

    local netId = NetworkGetNetworkIdFromEntity(veh)
    TriggerServerEvent('smartsiren:server:syncLights', netId, on)
end

-- ── Horn ──────────────────────────────────────────────────────
AddEventHandler('smartsiren:client:horn', function(pressed)
    local veh = getLocalVeh()
    if not DoesEntityExist(veh) then return end
    if pressed and not hornActive then
        hornActive = true
        StartVehicleHorn(veh, 99999, GetHashKey('HELDDOWN'), false)
    elseif not pressed and hornActive then
        hornActive = false
        StopVehicleHorn(veh, true)
    end
    SendNUIMessage({ action = 'horn', active = hornActive })
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
                lastVehicle   = veh
                playerState   = { sirenTone = 'off', lightsOn = false }
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

-- ── Remote Sync (andere Spieler empfangen) ────────────────────
AddEventHandler('smartsiren:client:remoteLights', function(netId, on)
    local veh = NetToVeh(netId)
    if not DoesEntityExist(veh) then return end
    if GetPedInVehicleSeat(veh, -1) == PlayerPedId() then return end
    applyBlaulicht(veh, on)
end)

-- ── GTA Default Control Blocker ───────────────────────────────
local BLOCKED_CONTROLS = {
    200,  -- Q  : Radio nächster Sender
    217,  -- Q  : Radio Wheel (halten)
     86,  -- E  : GTA Standard-Hupe / Siren-Toggle
    113,  -- CAPS: GTA Sirene an/aus
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
