fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'oxinv_custom_modules'
author 'Infamous Development Studios / Jordin B.'
description 'Combined ox_inventory custom modules resource: engraving machine and item labeler.'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'modules/engraving/config.lua',
    'modules/item_labeler/config.lua'
}

client_scripts {
    'modules/engraving/client.lua',
    'modules/item_labeler/client.lua'
}

server_scripts {
    'modules/engraving/server.lua',
    'modules/item_labeler/server.lua'
}

dependencies {
    'ox_lib',
    'ox_inventory'
}
