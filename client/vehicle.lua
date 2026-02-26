-- ============================================================
--  D4rk Smart Siren – Client / vehicle.lua
-- ============================================================

local hornActive    = false
local lastVehicle   = nil
local activeSoundId = nil
local sirenIsOn     = false
local lightsAreOn   = false

-- ── Utility ───────────────────────────────────────────────────
local function getLocalVeh()
    return GetVehiclePedIsIn(PlayerPedId(), false)
end

local function isDriverOf(veh)
    return GetPedInVehicleSeat(veh, -1) == PlayerPedId()
end

-- ── Blaulicht-Blinken ─────────────────────────────────────────
-- SetVehicleSiren steuert das Blinken der Lichter.
-- Wir setzen es wenn Sirene ODER Licht aktiv ist.
local function updateSirenFlash(veh)
    SetVehicleSiren(veh, lightsAreOn or sirenIsOn)
end

-- ── Sound Stop ────────────────────────────────────────────────
local function stopSirenSound(veh)
    if activeSoundId ~= nil then
        StopSound(activeSoundId)
        ReleaseSoundId(activeSoundId)
        activeSoundId = nil
    end
    sirenIsOn = false
    if veh and DoesEntityExist(veh) then
        SetVehicleHasMutedSirens(veh, false)
        UseSirenAsHorn(veh, false)
        updateSirenFlash(veh)
    end
end

-- ── Apply Siren ───────────────────────────────────────────────
local function applySiren(veh, toneEntry)
    if not DoesEntityExist(veh) then return end
    if not isDriverOf(veh) then return end

    stopSirenSound(veh)

    if toneEntry == 'off' then
        -- alles bereits in stopSirenSound erledigt
    elseif toneEntry == 'manual' then
        -- E-Taste spielt Sirenenblip (UseSirenAsHorn)
        SetVehicleHasMutedSirens(veh, true)
        UseSirenAsHorn(veh, true)
    else
        local siren = Config.Sirens[toneEntry]
        if not siren then
            if Config.Debug then
                print('^1[SmartSiren]^7 Unbekannte Siren-ID: ' .. tostring(toneEntry))
            end
            return
        end

        -- Audio Bank vorladen (nötig für DLC-Sounds, schadet nicht bei vanilla)
        if type(siren.Ref) == 'string' and siren.Ref ~= '0' and siren.Ref ~= '' then
            RequestScriptAudioBank(siren.Ref, false)
        end

        SetVehicleHasMutedSirens(veh, true)
        UseSirenAsHorn(veh, false)
        sirenIsOn = true

        -- GetSoundId() + PlaySoundFromEntity = stoppbarer Loop-Sound (wie LVC)
        activeSoundId = GetSoundId()
        PlaySoundFromEntity(
            activeSoundId,
            siren.String,
            veh,
            type(siren.Ref) == 'string' and siren.Ref or tostring(siren.Ref),
            false, 0
        )

        if Config.Debug then
            print('^3[SmartSiren]^7 Spiele: ' .. siren.Name .. ' [' .. siren.String .. ']')
        end
    end

    updateSirenFlash(veh)

    local netId = NetworkGetNetworkIdFromEntity(veh)
    TriggerServerEvent('smartsiren:server:syncSiren', netId, toneEntry)
end

-- ── Apply Blaulicht ───────────────────────────────────────────
local function applyBlaulicht(veh, on)
    if not DoesEntityExist(veh) then return end

    lightsAreOn = on
    SetVehicleLights(veh, on and 2 or 0)
    updateSirenFlash(veh)

    local name    = GetDisplayNameFromVehicleModel(GetEntityModel(veh)):lower()
    local vehCfg  = Config.Vehicles[name] or Config.Vehicles['DEFAULT'] or {}
    local mapping = on and (vehCfg.extras or {}).on or (vehCfg.extras or {}).off

    if mapping then
        for _, extra in ipairs(mapping.extrasOn or {}) do SetVehicleExtra(veh, extra, false) end
        for _, extra in ipairs(mapping.extrasOff or {}) do SetVehicleExtra(veh, extra, true) end
    end

    local netId = NetworkGetNetworkIdFromEntity(veh)
    TriggerServerEvent('smartsiren:server:syncLights', netId, on)
end

-- ── Horn ──────────────────────────────────────────────────────
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
    end
end)

-- ── Event Listeners ───────────────────────────────────────────
AddEventHandler('smartsiren:client:setSiren', function(toneEntry)
    local veh = getLocalVeh()
    if DoesEntityExist(veh) then applySiren(veh, toneEntry) end
end)

AddEventHandler('smartsiren:client:setLights', function(on)
    local veh = getLocalVeh()
    if DoesEntityExist(veh) then applyBlaulicht(veh, on) end
end)

AddEventHandler('smartsiren:client:vehicleLeft', function()
    local veh = getLocalVeh()
    stopSirenSound(veh)
    lightsAreOn = false
end)

-- ── Vehicle Watch Thread ──────────────────────────────────────
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if DoesEntityExist(veh) then
            if veh ~= lastVehicle then
                lastVehicle = veh
                sirenIsOn   = false
                lightsAreOn = false
                if Config.Debug then
                    print('^3[SmartSiren]^7 Fahrzeug: ' .. GetDisplayNameFromVehicleModel(GetEntityModel(veh)):lower()
                        .. ' | Klasse: ' .. GetVehicleClass(veh))
                end
            end
        else
            if lastVehicle then
                lastVehicle = nil
                TriggerEvent('smartsiren:client:vehicleLeft')
            end
        end
    end
end)

-- ── Remote Sync ───────────────────────────────────────────────
AddEventHandler('smartsiren:client:applyRemoteLights', function(netId, on)
    local veh = NetToVeh(netId)
    if not DoesEntityExist(veh) then return end
    if GetPedInVehicleSeat(veh, -1) == PlayerPedId() then return end
    applyBlaulicht(veh, on)
end)

-- ── GTA Default Control Blocker ───────────────────────────────
-- Fahrzeugklasse 18 = Emergency Vehicles (zuverlässiger als Model-Hash-Check)
-- Radio beim Einsteigen in Einsatzfahrzeuge deaktivieren
AddEventHandler('baseevents:enteredVehicle', function(vehicle, seat, displayName)
    if GetVehicleClass(vehicle) == 18 then
        SetVehRadioStation(vehicle, 'OFF')
        SetVehicleRadioEnabled(vehicle, false)
    end
end)

-- Controls blockieren (jeden Frame im Loop, wie LVC es macht)
local BLOCKED_CONTROLS = {
    81,  -- INPUT_VEH_NEXT_RADIO      ← korrekte ID (LVC bestätigt)
    172, -- INPUT_CELLPHONE_UP
    86,  -- INPUT_VEH_HORN / GTA Siren-Toggle
    113, -- INPUT_VEH_SIREN
}

Citizen.CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        -- Klasse 18 = Emergency, ODER in konfiguriertem Fahrzeug
        local block = false
        if DoesEntityExist(veh) then
            local cls = GetVehicleClass(veh)
            if cls == 18 then
                block = true
            else
                -- Fallback: Config-Check per Hash
                local modelHash = GetEntityModel(veh)
                for key, _ in pairs(Config.Vehicles) do
                    if key ~= 'DEFAULT' and GetHashKey(key) == modelHash then
                        block = true
                        break
                    end
                end
            end
        end

        if block then
            for _, ctrl in ipairs(BLOCKED_CONTROLS) do
                DisableControlAction(0, ctrl, true)
            end
            Citizen.Wait(0)
        else
            Citizen.Wait(500)
        end
    end
end)
