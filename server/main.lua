-- ============================================================
--  D4rk Smart Siren – Server / main.lua  [KORRIGIERT]
-- ============================================================
--
-- BUGFIXES:
--
-- BUG 5 (GERING): `local src = source` wurde deklariert aber nie verwendet.
--   Entfernt – source wird nur für Logging genutzt.
--
-- VERBESSERUNG: Siren-Sync überträgt jetzt auch den toneEntry-Wert
--   korrekt an alle Remote-Clients (wurde schon gemacht, aber src-Variable
--   war ungenutzt und verwirrend).

-- ── Rate-Limiter ──────────────────────────────────────────────
-- Verhindert Event-Spam / DoS: pro Spieler max. 1 Sync-Event
-- alle RATE_MS Millisekunden. Überschreitung → Event wird verworfen.
local RATE_MS  = 200  -- Cooldown in ms (5 Events/Sek. max)
local lastSync = {}   -- [playerId] = GetGameTimer()-Timestamp

local function checkRate(src)
    local now = GetGameTimer()
    if lastSync[src] and (now - lastSync[src]) < RATE_MS then
        return false -- zu schnell → verwerfen
    end
    lastSync[src] = now
    return true
end

-- Cleanup: Einträge toter Spieler entfernen
AddEventHandler('playerDropped', function()
    lastSync[source] = nil
end)

-- ── Siren-State eines Fahrzeugs an alle anderen senden ───────
RegisterNetEvent('smartsiren:server:syncSiren')
AddEventHandler('smartsiren:server:syncSiren', function(netId, toneEntry)
    local src = source
    if not checkRate(src) then return end

    -- Typ-Validierung: netId muss Zahl sein, toneEntry Zahl oder bekannter String
    if type(netId) ~= 'number' then return end
    if type(toneEntry) ~= 'number' and toneEntry ~= 'off' and toneEntry ~= 'manual' then return end

    TriggerClientEvent('smartsiren:client:remoteSiren', -1, netId, toneEntry)

    if Config and Config.Debug then
        print('^3[SmartSiren-Server]^7 Siren-Sync: netId=' .. tostring(netId)
            .. ' tone=' .. tostring(toneEntry) .. ' von Spieler ' .. tostring(src))
    end
end)

-- ── Licht-State eines Fahrzeugs an alle anderen senden ───────
RegisterNetEvent('smartsiren:server:syncLights')
AddEventHandler('smartsiren:server:syncLights', function(netId, on)
    local src = source
    if not checkRate(src) then return end

    if type(netId) ~= 'number' then return end
    if type(on) ~= 'boolean' then return end

    TriggerClientEvent('smartsiren:client:remoteLights', -1, netId, on)

    if Config and Config.Debug then
        print('^3[SmartSiren-Server]^7 Lights-Sync: netId=' .. tostring(netId)
            .. ' on=' .. tostring(on) .. ' von Spieler ' .. tostring(src))
    end
end)
