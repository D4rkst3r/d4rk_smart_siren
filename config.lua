-- ============================================================
--  D4rk Smart Siren – Config
-- ============================================================

Config               = {}

Config.Language      = 'de'   -- 'de' | 'en'
Config.AllowedSeats  = 'both' -- 'driver' | 'passenger' | 'both'
Config.Debug         = false

-- ── Tastenbelegung ────────────────────────────────────────────
Config.Keys          = {
    LightsNext = 'q',        -- Blaulicht an/aus
    Horn       = 'e',        -- Tröte / Horn (halten)
    Interact   = 'CAPSLOCK', -- Panel Maus-Interaktion
    Tones      = {
        [1] = '1',
        [2] = '2',
        [3] = '3',
        [4] = '4',
        [5] = '5',
        [6] = '6',
        [7] = '7',
        [8] = '8',
        [9] = '9',
    },
}

-- ── Sirenen-Töne ──────────────────────────────────────────────
-- sirenId = Anzahl TriggerSiren()-Calls um diesen Ton zu erreichen
-- nil = kein Cycling (OFF und Tröte)
Config.SirenTones    = {
    { id = 'off', label = 'AUS', icon = '🔇' },
    {
        id = 'wail',
        label = 'Wail',
        icon = '〰',
        audioString = 'VEHICLES_HORNS_SIREN_1',
        audioRef = '0'
    },
    {
        id = 'yelp',
        label = 'Yelp',
        icon = '〽',
        audioString = 'VEHICLES_HORNS_SIREN_2',
        audioRef = '0'
    },
    {
        id = 'phaser',
        label = 'Phaser',
        icon = '🌀',
        audioString = 'RESIDENT_VEHICLES_SIREN_WAIL_01',
        audioRef = '0'
    },
    {
        id = 'hilo',
        label = 'Hi-Lo',
        icon = '🔔',
        audioString = 'RESIDENT_VEHICLES_SIREN_WAIL_02',
        audioRef = '0'
    },
    { id = 'manual', label = 'Tröte', icon = '📢' },
}

-- ── Standard-Preset ───────────────────────────────────────────
Config.DefaultPreset = {
    label             = nil,
    allowedSirenTones = { 'off', 'wail', 'yelp', 'phaser', 'hilo', 'manual' },
    -- lightExtras: Extras beim Blaulicht AN ('full') und AUS ('off')
    lightExtras       = {},
}

-- ── Fahrzeug-Configs ──────────────────────────────────────────
Config.Vehicles      = {

    ['police'] = {
        label             = 'Polizei Streifenwagen',
        allowedSirenTones = { 'off', 'wail', 'yelp', 'hilo', 'manual' },
        lightExtras       = {
            ['full'] = { extrasOn = { 1, 2 }, extrasOff = { 3, 4 } },
            ['off']  = { extrasOn = {}, extrasOff = { 1, 2, 3, 4 } },
        },
    },

    ['firetruk'] = {
        label             = 'Feuerwehr LF',
        allowedSirenTones = { 'off', 'wail', 'yelp', 'phaser', 'manual' },
        lightExtras       = {
            ['full'] = { extrasOn = { 1, 2, 3 }, extrasOff = { 4 } },
            ['off']  = { extrasOn = {}, extrasOff = { 1, 2, 3, 4 } },
        },
    },

    ['ambulance'] = {
        label             = 'RTW',
        allowedSirenTones = { 'off', 'wail', 'yelp', 'hilo', 'manual' },
        lightExtras       = {
            ['full'] = { extrasOn = { 1, 2 }, extrasOff = {} },
            ['off']  = { extrasOn = {}, extrasOff = { 1, 2 } },
        },
    },

    ['polmav'] = {
        label             = 'Polizei Heli',
        allowedSirenTones = { 'off', 'wail', 'manual' },
        lightExtras       = {},
    },

    -- Weiteres Fahrzeug:
    -- ['modelname'] = {
    --     label             = 'Anzeigename',
    --     allowedSirenTones = { 'off','wail','yelp','manual' },
    --     lightExtras = {
    --         ['full'] = { extrasOn={1}, extrasOff={2} },
    --         ['off']  = { extrasOn={},  extrasOff={1} },
    --     },
    -- },
}

-- ── Übersetzungen ─────────────────────────────────────────────
Config.Translations  = {
    de = {
        siren     = 'TON',
        lights    = 'LICHT',
        horn      = 'TRÖTE',
        driver    = 'Fahrer',
        passenger = 'Beifahrer',
        keyHints  = { lights = '[Q]', horn = '[E]', tones = '[1-9]' },
    },
    en = {
        siren     = 'TONE',
        lights    = 'LIGHTS',
        horn      = 'AIR HORN',
        driver    = 'Driver',
        passenger = 'Passenger',
        keyHints  = { lights = '[Q]', horn = '[E]', tones = '[1-9]' },
    },
}
