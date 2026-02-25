fx_version 'cerulean'
game 'gta5'

name        'D4rk Smart Siren'
description 'Standalone Emergency Vehicle Siren & Light Control System'
author      'D4rk'
version     '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/vehicle.lua',
    'client/sync.lua'
}

server_scripts {
    'server/main.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/app.js'
}
