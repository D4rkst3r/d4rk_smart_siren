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

-- ── Siren-State eines Fahrzeugs an alle anderen senden ───────
RegisterNetEvent('smartsiren:server:syncSiren')
AddEventHandler('smartsiren:server:syncSiren', function(netId, toneEntry)
    -- FIX BUG 5: src-Variable entfernt (war ungenutzt)
    -- -1 = an alle Clients senden; sync.lua filtert den Fahrer selbst heraus
    TriggerClientEvent('smartsiren:client:remoteSiren', -1, netId, toneEntry)

    if Config and Config.Debug then
        print('^3[SmartSiren-Server]^7 Siren-Sync: netId=' .. tostring(netId)
            .. ' tone=' .. tostring(toneEntry) .. ' von Spieler ' .. tostring(source))
    end
end)

-- ── Licht-State eines Fahrzeugs an alle anderen senden ───────
RegisterNetEvent('smartsiren:server:syncLights')
AddEventHandler('smartsiren:server:syncLights', function(netId, on)
    -- FIX BUG 3: Dieser Event wird nur von isLocal=true ausgelöst (vehicle.lua)
    -- → kein Retrigger-Problem mehr durch Remote-Clients
    TriggerClientEvent('smartsiren:client:remoteLights', -1, netId, on)

    if Config and Config.Debug then
        print('^3[SmartSiren-Server]^7 Lights-Sync: netId=' .. tostring(netId)
            .. ' on=' .. tostring(on) .. ' von Spieler ' .. tostring(source))
    end
end)
