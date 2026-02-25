-- ============================================================
--  D4rk Smart Siren – Server / main.lua
-- ============================================================

-- Siren-State eines Fahrzeugs an alle anderen senden
RegisterNetEvent('smartsiren:server:syncSiren')
AddEventHandler('smartsiren:server:syncSiren', function(netId, toneId)
    local src = source
    TriggerClientEvent('smartsiren:client:remoteSiren', -1, netId, toneId)
end)

-- Licht-State eines Fahrzeugs an alle anderen senden
RegisterNetEvent('smartsiren:server:syncLights')
AddEventHandler('smartsiren:server:syncLights', function(netId, sceneId)
    local src = source
    TriggerClientEvent('smartsiren:client:remoteLights', -1, netId, sceneId)
end)
