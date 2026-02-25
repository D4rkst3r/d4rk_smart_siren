-- ============================================================
--  D4rk Smart Siren – Client / sync.lua
-- ============================================================

-- Siren-Sync von anderen Spielern
RegisterNetEvent('smartsiren:client:remoteSiren')
AddEventHandler('smartsiren:client:remoteSiren', function(netId, toneId)
    -- Direkt anwenden – kein TriggerEvent auf denselben Namen (würde Endlosschleife)
    local veh = NetToVeh(netId)
    if not DoesEntityExist(veh) then return end
    if GetPedInVehicleSeat(veh, -1) == PlayerPedId() then return end
    -- Für andere Spieler reicht es die Sirene nativ zu setzen (GTA synct Sound selbst)
    if toneId == 'off' then
        SetVehicleSiren(veh, false)
    else
        SetVehicleSiren(veh, true)
    end
end)

-- Licht-Sync von anderen Spielern
RegisterNetEvent('smartsiren:client:remoteLights')
AddEventHandler('smartsiren:client:remoteLights', function(netId, on)
    -- Separater interner Event → vehicle.lua wendet Extras an
    TriggerEvent('smartsiren:client:applyRemoteLights', netId, on)
end)
