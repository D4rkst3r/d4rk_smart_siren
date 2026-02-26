-- ============================================================
--  D4rk Smart Siren – Client / sync.lua 
-- ============================================================

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
