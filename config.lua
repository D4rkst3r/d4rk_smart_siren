-- ============================================================
--  D4rk Smart Siren – Config
-- ============================================================

Config = {}

Config.Language     = 'de'    -- 'de' | 'en'
Config.AllowedSeats = 'both'  -- 'driver' | 'passenger' | 'both'
Config.Debug        = false

-- ── Tastenbelegung ────────────────────────────────────────────
Config.Keys = {
    LightsNext = 'q',         -- Blaulicht an/aus
    Horn       = 'e',         -- Tröte / Horn (halten)
    Interact   = 'CAPSLOCK',  -- Panel Maus-Interaktion
    Tones = {
        [1]='1',[2]='2',[3]='3',
        [4]='4',[5]='5',[6]='6',
        [7]='7',[8]='8',[9]='9',
    },
}

-- ── Sirenen-Töne ──────────────────────────────────────────────
Config.SirenTones = {
    -- sirenId = Anzahl TriggerSiren()-Calls um diesen Ton zu erreichen
    -- (0/nil = kein Cycling, Sirene bleibt auf Standard-Ton)
    { id='off',    label='AUS',    icon='🔇', sirenId=nil },
    { id='wail',   label='Wail',   icon='〰',  sirenId=1   },  -- GTA Ton 1
    { id='yelp',   label='Yelp',   icon='〽',  sirenId=2   },  -- GTA Ton 2
    { id='phaser', label='Phaser', icon='🌀',  sirenId=3   },  -- GTA Ton 3
    { id='hilo',   label='Hi-Lo',  icon='🔔',  sirenId=4   },  -- GTA Ton 4
    { id='manual', label='Tröte',  icon='📢',  sirenId=nil },  -- Horn-Modus
},
    { id='wail',   label='Wail',   icon='〰'  },
    { id='yelp',   label='Yelp',   icon='〽'  },
    { id='phaser', label='Phaser', icon='🌀'  },
    { id='hilo',   label='Hi-Lo',  icon='🔔'  },
    { id='manual', label='Tröte',  icon='📢'  },
}

-- ── Standard-Preset ───────────────────────────────────────────
Config.DefaultPreset = {
    label             = nil,
    allowedSirenTones = { 'off','wail','yelp','phaser','hilo','manual' },
    -- lightExtras: Welche Extras beim Blaulicht AN/AUS geschaltet werden
    -- 'full' = Blaulicht an, 'off' = Blaulicht aus
    lightExtras       = {},
}

-- ── Fahrzeug-Configs ──────────────────────────────────────────
Config.Vehicles = {

    ['police'] = {
        label             = 'Polizei Streifenwagen',
        allowedSirenTones = { 'off','wail','yelp','hilo','manual' },
        lightExtras = {
            ['full'] = { extrasOn={1,2}, extrasOff={3,4} },
            ['off']  = { extrasOn={},    extrasOff={1,2,3,4} },
        },
    },

    ['firetruk'] = {
        label             = 'Feuerwehr LF',
        allowedSirenTones = { 'off','wail','yelp','phaser','manual' },
        lightExtras = {
            ['full'] = { extrasOn={1,2,3}, extrasOff={4} },
            ['off']  = { extrasOn={},      extrasOff={1,2,3,4} },
        },
    },

    ['ambulance'] = {
        label             = 'RTW',
        allowedSirenTones = { 'off','wail','yelp','hilo','manual' },
        lightExtras = {
            ['full'] = { extrasOn={1,2}, extrasOff={} },
            ['off']  = { extrasOn={},    extrasOff={1,2} },
        },
    },

    ['polmav'] = {
        label             = 'Polizei Heli',
        allowedSirenTones = { 'off','wail','manual' },
        lightExtras       = {},
    },

    -- Weiteres Fahrzeug hinzufügen:
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
Config.Translations = {
    de = {
        siren     = 'TON',
        lights    = 'LICHT',
        horn      = 'TRÖTE',
        driver    = 'Fahrer',
        passenger = 'Beifahrer',
        keyHints  = { lights='[Q]', horn='[E]', tones='[1-9]' },
    },
    en = {
        siren     = 'TONE',
        lights    = 'LIGHTS',
        horn      = 'AIR HORN',
        driver    = 'Driver',
        passenger = 'Passenger',
        keyHints  = { lights='[Q]', horn='[E]', tones='[1-9]' },
    },
}
