-- ============================================================
--  D4rk Smart Siren – Client / sync.lua  [KORRIGIERT v2]
-- ============================================================
--
-- Warum dieser Code nach isNetwork=true (vehicle.lua) noch existiert:
--
-- PlaySoundFromEntity(..., isNetwork=true, ...) lässt FiveM/GTA den Ton
-- automatisch an alle Clients in Audio-Reichweite senden.
-- Das ersetzt den manuellen Remote-Sound für Spieler in der Nähe.
--
-- Dieser Handler wird aber noch benötigt für:
--
--   1. DLC/Server-Sided Banks (RequestScriptAudioBank) – muss auf JEDEM
--      Client geladen sein, bevor der isNetwork-Sound empfangen werden kann.
--      Ohne diesen Call: kein Ton bei fk-1997 / WMServerSirens etc.
--
--   2. Spieler die NEU in den Bereich joinen nachdem die Sirene bereits
--      lief (isNetwork-Sound ist dann schon weg, State wird neu gesetzt).
--
--   3. SetVehicleSiren / SetVehicleHasMutedSirens korrekt setzen, damit
--      Notlichter blinken und kein nativer GTA-Ton durchkommt.
--
-- Kein eigenes PlaySoundFromEntity mehr nötig:
--   Der Ton kommt via isNetwork=true vom Fahrer automatisch.
--   Ein zweites PlaySoundFromEntity hier wäre eine Überlagerung.

-- ── Siren-Sync von anderen Spielern ──────────────────────────
RegisterNetEvent('smartsiren:client:remoteSiren')
AddEventHandler('smartsiren:client:remoteSiren', function(netId, toneEntry)
    local veh = NetToVeh(netId)
    if not DoesEntityExist(veh) then return end
    -- Eigenes Fahrzeug: Fahrer steuert selbst via vehicle.lua
    if GetPedInVehicleSeat(veh, -1) == PlayerPedId() then return end

    if toneEntry == 'off' then
        -- Siren aus → natives GTA-System deaktivieren
        -- (isNetwork-Sound wird vom Fahrer via StopSound gestoppt)
        SetVehicleSiren(veh, false)
        SetVehicleHasMutedSirens(veh, false)
    elseif toneEntry == 'manual' then
        -- Manual/Horn-Modus: kein Custom-Sound aktiv
        SetVehicleSiren(veh, true)
        SetVehicleHasMutedSirens(veh, true)
    else
        local siren = Config.Sirens[toneEntry]
        if not siren then return end

        -- DLC/Server-Sided Bank auf diesem Client vorladen.
        -- PFLICHT für alle Server-Sided Sounds (fk-1997, WMServerSirens, etc.).
        -- Ohne diesen Call empfängt der Client den isNetwork-Ton nicht.
        if type(siren.Ref) == 'string' and siren.Ref ~= '' then
            RequestScriptAudioBank(siren.Ref, false)
        end

        -- Notlichter blinken + nativen GTA-Ton muten.
        -- Der eigentliche Custom-Ton kommt via isNetwork=true automatisch.
        SetVehicleHasMutedSirens(veh, true)
        SetVehicleSiren(veh, true)
    end
end)

-- ── Licht-Sync von anderen Spielern ──────────────────────────
RegisterNetEvent('smartsiren:client:remoteLights')
AddEventHandler('smartsiren:client:remoteLights', function(netId, on)
    -- vehicle.lua's applyBlaulicht mit isLocal=false → kein Sync-Loop (BUG 3)
    TriggerEvent('smartsiren:client:applyRemoteLights', netId, on)
end)
