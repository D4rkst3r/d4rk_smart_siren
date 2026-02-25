-- ============================================================
--  D4rk Smart Siren – Client / sync.lua
--  Empfängt Sync-Events vom Server und leitet sie an vehicle.lua weiter
-- ============================================================

-- Siren-Sync von anderen Spielern empfangen
RegisterNetEvent('smartsiren:client:remoteSiren')
AddEventHandler('smartsiren:client:remoteSiren', function(netId, toneId)
    TriggerEvent('smartsiren:client:remoteSiren', netId, toneId)
end)

-- Licht-Sync von anderen Spielern empfangen
RegisterNetEvent('smartsiren:client:remoteLights')
AddEventHandler('smartsiren:client:remoteLights', function(netId, sceneId)
    TriggerEvent('smartsiren:client:remoteLights', netId, sceneId)
end)
