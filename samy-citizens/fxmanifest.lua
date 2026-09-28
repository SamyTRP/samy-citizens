fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'samy-citizens'
author 'samy'
version '2.1.0'
description 'Kendi hayatı olan, konuşabilen ve arkadaş olunabilen kalıcı sakin NPC sistemi (yapay zekâsız, kural tabanlı diyalog)'

dependencies {
    '/onesync',
    'ox_lib',
    'oxmysql',
    'ox_target',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/utils.lua',
    'locales/tr.lua',
    'locales/en.lua',
    'shared/activities.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'data/locations.lua',
    'data/routines.lua',
    'data/residents.lua',
    'data/dialogue.lua',
    'bridge/qbx.lua',
    'bridge/qb.lua',
    'bridge/esx.lua',
    'server/db.lua',
    'server/log.lua',
    'server/clock.lua',
    'server/memory.lua',
    'server/relationships.lua',
    'server/simulation.lua',
    'server/spawner.lua',
    'server/appointments.lua',
    'server/dialogue.lua',
    'server/actions.lua',
    'server/conversation.lua',
    'server/phone.lua',
    'server/social.lua',
    'server/world.lua',
    'server/hostage.lua',
    'server/admin.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
    'client/tasks.lua',
    'client/conversation.lua',
    'client/world.lua',
    'client/hostage.lua',
    'client/phone.lua',
    'client/admin.lua',
    'client/debug.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
}
