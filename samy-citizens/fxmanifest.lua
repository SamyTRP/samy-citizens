fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'samy-citizens'
author 'samy'
version '3.0.0'
description 'Kendi hayatı olan, konuşabilen, hatırlayan, beraber gezilebilen kalıcı sakin NPC sistemi (yapay zekâsız, kural tabanlı)'

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
    'data/adult_npcs.lua',          -- v3: Vanilla Unicorn yetişkin NPC kategorisi
    'data/dialogue.lua',
    'data/dialogue_life.lua',       -- v3: yeni niyetler, cümle üretici parçaları
    'bridge/qbx.lua',
    'bridge/qb.lua',
    'bridge/esx.lua',
    'bridge/phone.lua',             -- v3: telefon köprüsü (auto / gksphone / lb-phone / npwd / qb-phone / custom / builtin)
    'server/db.lua',
    'server/log.lua',
    'server/clock.lua',
    'server/memory.lua',
    'server/relationships.lua',
    'server/simulation.lua',
    'server/spawner.lua',
    'server/npc_manager.lua',       -- v3: merkezi NPC erişimi
    'server/npc_state.lua',         -- v3: durum makinesi
    'server/npc_personality.lua',   -- v3: kişilik puanları, ton, ruh hâli, karar motoru
    'server/npc_context.lua',       -- v3: kısa süreli konuşma bağlamı
    'server/npc_relationship.lua',  -- v3: ilişki XP'si, istatistikler, romantizm, kıskançlık
    'server/npc_awareness.lua',     -- v3: çevre farkındalığı
    'server/appointments.lua',
    'server/dialogue.lua',
    'server/npc_dialogue_gen.lua',  -- v3: dinamik cümle üretici
    'server/npc_intents.lua',       -- v3: yeni niyet işleyicileri
    'server/actions.lua',
    'server/conversation.lua',
    'server/phone.lua',
    'server/social.lua',
    'server/world.lua',
    'server/hostage.lua',
    'server/npc_companion.lua',     -- v3: beraber yürüme / araç / bir yere gitme
    'server/adult_npc.lua',         -- v3: yetişkin NPC kuralları ve bölgeleri
    'server/npc_interaction.lua',   -- v3: sosyal + yetişkin etkileşim animasyonları
    'server/npc_events.lua',        -- v3: kendiliğinden konuşma, teklifler, akıllı mesajlar
    'server/npc_menu.lua',          -- v3: konuşma paneli kategori menüsü
    'server/admin.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
    'client/tasks.lua',
    'client/npc_companion.lua',     -- v3
    'client/npc_animation.lua',     -- v3
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
