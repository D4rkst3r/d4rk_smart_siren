-- ============================================================
--  D4rk Smart Siren – Config
-- ============================================================

Config              = {}
Config.AllowedSeats = 'both'
Config.Debug        = false

Config.Keys         = {
    LightsNext = 'q',
    Horn       = 'e',
    Tones      = { [1] = '1', [2] = '2', [3] = '3', [4] = '4', [5] = '5', [6] = '6', [7] = '7', [8] = '8', [9] = '9' },
}

Config.Sirens       = {
    [1]  = { Name = 'Airhorn', String = 'SIRENS_AIRHORN', Ref = 0 },
    [2]  = { Name = 'Wail', String = 'VEHICLES_HORNS_SIREN_1', Ref = 0 },
    [3]  = { Name = 'Yelp', String = 'VEHICLES_HORNS_SIREN_2', Ref = 0 },
    [4]  = { Name = 'Priority', String = 'VEHICLES_HORNS_POLICE_WARNING', Ref = 0 },
    [5]  = { Name = 'CustomA', String = 'RESIDENT_VEHICLES_SIREN_WAIL_01', Ref = 0 },
    [6]  = { Name = 'CustomB', String = 'RESIDENT_VEHICLES_SIREN_WAIL_02', Ref = 0 },
    [7]  = { Name = 'CustomC', String = 'RESIDENT_VEHICLES_SIREN_WAIL_03', Ref = 0 },
    [8]  = { Name = 'CustomD', String = 'RESIDENT_VEHICLES_SIREN_QUICK_01', Ref = 0 },
    [9]  = { Name = 'CustomE', String = 'RESIDENT_VEHICLES_SIREN_QUICK_02', Ref = 0 },
    [10] = { Name = 'CustomF', String = 'RESIDENT_VEHICLES_SIREN_QUICK_03', Ref = 0 },
    [11] = { Name = 'Powercall', String = 'VEHICLES_HORNS_AMBULANCE_WARNING', Ref = 0 },
    [12] = { Name = 'Horn', String = 'VEHICLES_HORNS_FIRETRUCK_WARNING', Ref = 0 },           -- kein "Fire" davor
    [13] = { Name = 'Yelp', String = 'RESIDENT_VEHICLES_SIREN_FIRETRUCK_WAIL_01', Ref = 0 },  -- kein "Fire" davor
    [14] = { Name = 'Wail', String = 'RESIDENT_VEHICLES_SIREN_FIRETRUCK_QUICK_01', Ref = 0 }, -- kein "Fire" davor
}

Config.Vehicles     = {

    ['DEFAULT'] = {
        tones  = { 'off', 2, 3, 4, 'manual' },
        extras = {},
    },

    ['police'] = {
        tones  = { 'off', 2, 3, 4, 'manual' },
        extras = {
            on  = { extrasOn = { 1, 2 }, extrasOff = { 3, 4 } },
            off = { extrasOn = {}, extrasOff = { 1, 2, 3, 4 } },
        },
    },

    ['firetruk'] = {
        tones  = { 'off', 12, 13, 14, 'manual' },
        extras = {
            on  = { extrasOn = { 1, 2, 3 }, extrasOff = { 4 } },
            off = { extrasOn = {}, extrasOff = { 1, 2, 3, 4 } },
        },
    },

    ['ambulance'] = {
        tones  = { 'off', 2, 3, 11, 'manual' },
        extras = {
            on  = { extrasOn = { 1, 2 }, extrasOff = {} },
            off = { extrasOn = {}, extrasOff = { 1, 2 } },
        },
    },

    ['polmav'] = {
        tones  = { 'off', 2, 'manual' },
        extras = {},
    },
}
