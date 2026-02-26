local hornActive       = false
local lastVehicle      = nil
local activeSoundId    = nil
local sirenIsOn        = false
local lightsAreOn      = false
local manualModeActive = false -- FIX BUG 4: Manuellen Modus verfolgen

-- ── Utility ───────────────────────────────────────────────────
local function getLocalVeh()
    return GetVehiclePedIsIn(PlayerPedId(), false)
end

local function isDriverOf(veh)
    return GetPedInVehicleSeat(veh, -1) == PlayerPedId()
end

local function applyNativeState(veh)
    if not DoesEntityExist(veh) then return end

    -- Blinker hängt NUR an lightsAreOn – Sirene hat keinen Einfluss
    SetVehicleSiren(veh, lightsAreOn)

    -- Nativer GTA-Ton stumm halten sobald irgendetwas von uns aktiv ist,
    -- damit GTA-Standard-Sirene nie durchkommt
    local needsMute = lightsAreOn or sirenIsOn or manualModeActive
    SetVehicleHasMutedSirens(veh, needsMute)
end

-- ── Sound Stop ────────────────────────────────────────────────
-- Stoppt nur den Custom-Sound und setzt Sound-Flags zurück.
-- Licht-State wird NICHT angetastet – Blaulicht läuft weiter falls aktiv.
local function stopSirenSound(veh)
    -- Custom Sound stoppen
    if activeSoundId ~= nil then
        StopSound(activeSoundId)
        ReleaseSoundId(activeSoundId)
        activeSoundId = nil
    end

    -- Sound-Flags zurücksetzen
    sirenIsOn        = false
    manualModeActive = false
    UseSirenAsHorn(veh and DoesEntityExist(veh) and veh or 0, false)

    -- Nativen State neu schreiben (Licht bleibt, Sound ist weg)
    applyNativeState(veh)
end

-- ── Apply Siren ───────────────────────────────────────────────
-- Steuert NUR den Ton – Blaulicht-Zustand wird nicht verändert.
local function applySiren(veh, toneEntry)
    if not DoesEntityExist(veh) then return end
    if not isDriverOf(veh) then return end

    -- Alten Sound sauber stoppen (lässt Licht in Ruhe)
    stopSirenSound(veh)

    if toneEntry == 'off' then
        -- Nichts zu tun – stopSirenSound hat alles erledigt
    elseif toneEntry == 'manual' then
        -- Horn-Taste spielt Sirene via GTA-System
        manualModeActive = true
        UseSirenAsHorn(veh, true)
    else
        local siren = Config.Sirens[toneEntry]
        if not siren then
            if Config.Debug then
                print('^1[SmartSiren]^7 Unbekannte Siren-ID: ' .. tostring(toneEntry))
            end
            return
        end

        -- DLC Audio Bank vorladen falls nötig
        if type(siren.Ref) == 'string' and siren.Ref ~= '' then
            RequestScriptAudioBank(siren.Ref, false)
        end

        sirenIsOn = true

        -- DLC/Server-Sided Audio Bank vorladen (VOR PlaySoundFromEntity!).
        -- Bei Vanilla-Sounds (Ref=0) passiert hier nichts.
        if type(siren.Ref) == 'string' and siren.Ref ~= '' then
            RequestScriptAudioBank(siren.Ref, false)
        end

        sirenIsOn = true

        -- isNetwork = true  → FiveM/GTA synct den Ton automatisch an ALLE Clients
        --                      in Netzwerk-Reichweite. StopSound() vom Fahrer
        --                      stoppt den Ton ebenfalls für alle anderen.
        -- isNetwork = false → nur der lokale Client hört den Ton (war der alte Fehler).
        --
        -- Ref = 0        → Vanilla GTA Sound
        -- Ref = "STRING" → DLC/Server-Sided Bank (WMServerSirens, fk-1997 usw.)
        activeSoundId = GetSoundId()
        PlaySoundFromEntity(
            activeSoundId, -- Handle zum späteren StopSound()
            siren.String,  -- Audio-Name  z.B. "VEHICLES_HORNS_SIREN_1"
            veh,           -- Entity von der der Sound ausgeht
            siren.Ref,     -- Audio-Bank: 0 = Vanilla, String = DLC (kein tostring!)
            true,          -- isNetwork = TRUE → alle Clients hören mit
            0              -- p5, immer 0
        )

        if Config.Debug then
            print('^3[SmartSiren]^7 Spiele: ' .. siren.Name
                .. ' [' .. siren.String .. '] Ref=' .. tostring(siren.Ref))
        end
    end

    -- Mute-State neu schreiben (Licht-Blinker BLEIBT wie er ist)
    applyNativeState(veh)

    local netId = NetworkGetNetworkIdFromEntity(veh)
    TriggerServerEvent('smartsiren:server:syncSiren', netId, toneEntry)
end

-- ── Apply Blaulicht ───────────────────────────────────────────
-- Steuert NUR das Blaulicht/Blinker – Sirenen-Ton wird nicht verändert.
-- isLocal=true  → lokaler Spieler, Server-Event wird gefeuert
-- isLocal=false → Remote-Sync, kein Retrigger (BUG 3 Fix)
local function applyBlaulicht(veh, on, isLocal)
    if not DoesEntityExist(veh) then return end

    lightsAreOn = on
    -- SetVehicleLights bewusst NICHT aufrufen:
    -- Blaulicht (Notlichter/Extras) ist unabhängig vom normalen Fahrlicht.

    -- Blinker + Mute-State neu schreiben (Sirene BLEIBT wie sie ist)
    applyNativeState(veh)

    -- GTA Extras (Lichtbalken, Frontblitzer etc.)
    local name    = GetDisplayNameFromVehicleModel(GetEntityModel(veh)):lower()
    local vehCfg  = Config.Vehicles[name] or Config.Vehicles['DEFAULT'] or {}
    local mapping = on and (vehCfg.extras or {}).on or (vehCfg.extras or {}).off

    if mapping then
        for _, extra in ipairs(mapping.extrasOn or {}) do SetVehicleExtra(veh, extra, false) end
        for _, extra in ipairs(mapping.extrasOff or {}) do SetVehicleExtra(veh, extra, true) end
    end

    if isLocal then
        local netId = NetworkGetNetworkIdFromEntity(veh)
        TriggerServerEvent('smartsiren:server:syncLights', netId, on)
    end
end

-- ── Horn ──────────────────────────────────────────────────────
-- SoundVehicleHornThisFrame → spielt die Hupe genau für diesen Frame.
-- Jeden Frame aufgerufen = nahtloser Dauerton ohne Duration-Probleme.
AddEventHandler('smartsiren:client:horn', function(pressed)
    local veh = getLocalVeh()
    if not DoesEntityExist(veh) then return end

    if pressed and not hornActive then
        hornActive = true
        SendNUIMessage({ action = 'horn', active = true })

        if not manualModeActive then
            Citizen.CreateThread(function()
                while hornActive do
                    local v = getLocalVeh()
                    if DoesEntityExist(v) and not manualModeActive then
                        SoundVehicleHornThisFrame(v)
                    end
                    Citizen.Wait(0)
                end
            end)
        end
    elseif not pressed and hornActive then
        hornActive = false
        SendNUIMessage({ action = 'horn', active = false })
        -- Loop verlässt sich selbst – kein Stop-Call nötig
    end
end)

-- ── Event Listeners ───────────────────────────────────────────
AddEventHandler('smartsiren:client:setSiren', function(toneEntry)
    local veh = getLocalVeh()
    if DoesEntityExist(veh) then applySiren(veh, toneEntry) end
end)

AddEventHandler('smartsiren:client:setLights', function(on)
    local veh = getLocalVeh()
    -- FIX BUG 3: isLocal=true → triggert Server-Event
    if DoesEntityExist(veh) then applyBlaulicht(veh, on, true) end
end)

AddEventHandler('smartsiren:client:vehicleLeft', function()
    local lv         = lastVehicle
    -- Flags zurücksetzen BEVOR applyNativeState, damit alles auf OFF geht
    lightsAreOn      = false
    sirenIsOn        = false
    manualModeActive = false
    -- Custom Sound stoppen und Fahrzeug sauber zurücksetzen
    if lv and DoesEntityExist(lv) then
        if activeSoundId ~= nil then
            StopSound(activeSoundId)
            ReleaseSoundId(activeSoundId)
            activeSoundId = nil
        end
        UseSirenAsHorn(lv, false)
        SetVehicleLights(lv, 0)
        applyNativeState(lv) -- setzt Siren=false, Mute=false
    end
end)

-- ── Vehicle Watch Thread ──────────────────────────────────────
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if DoesEntityExist(veh) then
            if veh ~= lastVehicle then
                lastVehicle      = veh
                -- Sauberer Reset beim Fahrzeugwechsel
                sirenIsOn        = false
                lightsAreOn      = false
                manualModeActive = false
                activeSoundId    = nil
                UseSirenAsHorn(veh, false)
                applyNativeState(veh) -- Siren=false, Mute=false

                if Config.Debug then
                    print('^3[SmartSiren]^7 Fahrzeug: '
                        .. GetDisplayNameFromVehicleModel(GetEntityModel(veh)):lower()
                        .. ' | Klasse: ' .. GetVehicleClass(veh))
                end
            end
        else
            if lastVehicle then
                local lv = lastVehicle
                lastVehicle = nil
                TriggerEvent('smartsiren:client:vehicleLeft')
            end
        end
    end
end)

-- ── Remote Sync ───────────────────────────────────────────────
-- FIX BUG 3: isLocal=false → triggert KEINEN Server-Event
AddEventHandler('smartsiren:client:applyRemoteLights', function(netId, on)
    local veh = NetToVeh(netId)
    if not DoesEntityExist(veh) then return end
    if GetPedInVehicleSeat(veh, -1) == PlayerPedId() then return end
    applyBlaulicht(veh, on, false) -- isLocal=false → kein Server-Retrigger
end)

-- ── Hilfsfunktion: Ist dieses Fahrzeug in der Config oder Klasse 18? ─────
-- Wird mehrfach verwendet (Radio, Control-Blocker).
-- Gecacht pro Fahrzeug-Handle um den pairs()-Loop nicht jeden Frame zu laufen.
local configVehCache = {} -- [entityHandle] = true/false

local function isConfiguredVehicle(veh)
    if not DoesEntityExist(veh) then return false end
    if configVehCache[veh] ~= nil then return configVehCache[veh] end

    local result = false
    -- Klasse 18 = Emergency Vehicle (immer erfasst)
    if GetVehicleClass(veh) == 18 then
        result = true
    else
        -- Explizit in Config.Vehicles eingetragen (non-emergency wie z.B. Zivilfahrzeuge mit Sondersignal)
        local modelHash = GetEntityModel(veh)
        for key, _ in pairs(Config.Vehicles) do
            if key ~= 'DEFAULT' and GetHashKey(key) == modelHash then
                result = true
                break
            end
        end
    end

    configVehCache[veh] = result
    return result
end

-- Cache invalidieren wenn Fahrzeug despawnt
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10000)
        for handle, _ in pairs(configVehCache) do
            if not DoesEntityExist(handle) then
                configVehCache[handle] = nil
            end
        end
    end
end)

-- ── Radio komplett deaktivieren ───────────────────────────────
-- Beim Einsteigen sofort ausschalten.
-- GTA schaltet das Radio manchmal selbst wieder ein (z.B. nach Werbung),
-- daher wird es auch im Control-Blocker-Loop jedes Frame erzwungen.
AddEventHandler('baseevents:enteredVehicle', function(vehicle, seat, displayName)
    if isConfiguredVehicle(vehicle) then
        SetVehRadioStation(vehicle, 'OFF')
        SetVehicleRadioEnabled(vehicle, false)
        if Config.Debug then
            print('^3[SmartSiren]^7 Radio deaktiviert für: '
                .. GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)):lower())
        end
    end
end)

-- ── GTA Default Control Blocker ───────────────────────────────
local BLOCKED_CONTROLS = {
    80,  -- INPUT_VEH_RADIO_WHEEL      ← Radiorad (Mausrad im Fahrzeug)
    81,  -- INPUT_VEH_NEXT_RADIO       ← nächster Radiosender
    82,  -- INPUT_VEH_PREV_RADIO       ← vorheriger Radiosender (oft vergessen!)
    86,  -- INPUT_VEH_HORN             ← GTA Siren/Horn-Toggle
    113, -- INPUT_VEH_SIREN            ← native Siren-Taste (N)
}

Citizen.CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)

        if DoesEntityExist(veh) and isConfiguredVehicle(veh) then
            -- Controls sperren
            for _, ctrl in ipairs(BLOCKED_CONTROLS) do
                DisableControlAction(0, ctrl, true)
            end

            -- Radio jeden Frame erzwingen – GTA kann es sonst wieder aktivieren
            -- (z.B. durch Musikevents, Missionen, oder nach einem Respawn)
            SetVehRadioStation(veh, 'OFF')
            SetVehicleRadioEnabled(veh, false)

            Citizen.Wait(0) -- jeden Frame prüfen solange im Fahrzeug
        else
            Citizen.Wait(500)
        end
    end
end)
