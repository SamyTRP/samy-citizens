--[[
    Haftalık rutin şablonları. İlk açılışta veritabanına eklenir (INSERT IGNORE).

    Her şablonda 'workday' (sakinin job.workdays günleri) ve 'offday' blok listeleri bulunur.
    İsteğe bağlı 'days' = { [1..7] = {...} } ile belirli bir gün tamamen ezilebilir (1 = Pazartesi).

    Blok: { from, to, activity, location, firm?, roam? }
      from/to : 'HH:MM' (24:00 üstü = ertesi gün, örn '26:30') veya vardiya jetonları:
                'shift_start', 'shift_end', 'shift_mid' ve +/- dakika (örn 'shift_start-90')
                to <= from ise blok gece yarısını aşar.
      activity: SC.Activities anahtarı veya esnek 'lunch' / 'free'
      location: 'home' | 'work' | 'flex:lunch' | 'flex:free' | 'fav:<tip>' | konum id'si
      firm    : true ise sakin bu bloğu erken terk etmez (iş/ders varsayılan olarak firm)
      roam    : iş bloğunu dilimlere böler, her dilimin bir kısmında rastgele bir mekâna gider
                { types = {...}, slot = dk, away = dk, activity = 'deliver' }

    Her günün ilk bloğu "uyanış", son bloğu genelde gece yarısını aşan uykudur. Bir önceki günün
    gece yarısını aşan bloğu, bugünün ilk bloğuna kadar devam eder.
]]
SCData = SCData or {}

local roamSpec = {
    types = { 'shop', 'cafe', 'fastfood', 'park', 'bar', 'office', 'school', 'beach', 'hospital', 'garage' },
    slot = 150,
    away = 90,
    activity = 'deliver',
}

local standardOffday = {
    { from = '09:30', to = '12:00', activity = 'home_idle', location = 'home' },
    { from = '12:00', to = '14:00', activity = 'free', location = 'flex:free' },
    { from = '14:00', to = '16:30', activity = 'home_idle', location = 'home' },
    { from = '16:30', to = '23:00', activity = 'free', location = 'flex:free' },
    { from = '23:30', to = '09:30', activity = 'sleep', location = 'home' },
}

SCData.Routines = {
    day_worker = {
        label = 'Gündüz çalışanı',
        workday = {
            { from = 'shift_start-150', to = 'shift_start', activity = 'home_idle', location = 'home' },
            { from = 'shift_start', to = 'shift_mid', activity = 'work', location = 'work' },
            { from = 'shift_mid', to = 'shift_mid+60', activity = 'lunch', location = 'flex:lunch' },
            { from = 'shift_mid+60', to = 'shift_end', activity = 'work', location = 'work' },
            { from = 'shift_end', to = 'shift_end+240', activity = 'free', location = 'flex:free' },
            { from = 'shift_end+270', to = 'shift_start-150', activity = 'sleep', location = 'home' },
        },
        offday = standardOffday,
    },

    day_worker_roam = {
        label = 'Gezici çalışan (kurye / taksi)',
        workday = {
            { from = 'shift_start-120', to = 'shift_start', activity = 'home_idle', location = 'home' },
            { from = 'shift_start', to = 'shift_mid', activity = 'work', location = 'work', roam = roamSpec },
            { from = 'shift_mid', to = 'shift_mid+45', activity = 'lunch', location = 'flex:lunch' },
            { from = 'shift_mid+45', to = 'shift_end', activity = 'work', location = 'work', roam = roamSpec },
            { from = 'shift_end', to = 'shift_end+180', activity = 'free', location = 'flex:free' },
            { from = 'shift_end+210', to = 'shift_start-120', activity = 'sleep', location = 'home' },
        },
        offday = standardOffday,
    },

    night_bar = {
        label = 'Gece vardiyası (bar)',
        workday = {
            { from = '10:30', to = '13:00', activity = 'home_idle', location = 'home' },
            { from = '13:00', to = '16:00', activity = 'free', location = 'flex:free' },
            { from = '16:00', to = 'shift_start', activity = 'home_idle', location = 'home' },
            { from = 'shift_start', to = 'shift_end', activity = 'work', location = 'work' },
            { from = 'shift_end+20', to = '34:30', activity = 'sleep', location = 'home' },
        },
        offday = {
            { from = '11:00', to = '14:00', activity = 'home_idle', location = 'home' },
            { from = '14:00', to = '18:00', activity = 'free', location = 'flex:free' },
            { from = '18:00', to = '20:00', activity = 'home_idle', location = 'home' },
            { from = '20:00', to = '25:30', activity = 'free', location = 'flex:free' },
            { from = '25:45', to = '35:00', activity = 'sleep', location = 'home' },
        },
    },

    night_nurse = {
        label = 'Gece vardiyası (hastane)',
        workday = {
            { from = '07:30', to = '14:30', activity = 'sleep', location = 'home' },
            { from = '14:30', to = '18:15', activity = 'home_idle', location = 'home' },
            { from = 'shift_start', to = 'shift_mid', activity = 'work', location = 'work' },
            { from = 'shift_mid', to = 'shift_mid+40', activity = 'lunch_break', location = 'work' },
            { from = 'shift_mid+40', to = 'shift_end', activity = 'work', location = 'work' },
        },
        offday = {
            { from = '07:30', to = '11:30', activity = 'sleep', location = 'home' },
            { from = '11:30', to = '13:30', activity = 'home_idle', location = 'home' },
            { from = '13:30', to = '17:30', activity = 'free', location = 'flex:free' },
            { from = '17:30', to = '20:00', activity = 'home_idle', location = 'home' },
            { from = '20:00', to = '23:00', activity = 'free', location = 'flex:free' },
            { from = '23:30', to = '07:30', activity = 'sleep', location = 'home' },
        },
    },

    retiree = {
        label = 'Emekli',
        workday = {
            { from = '06:30', to = '09:00', activity = 'home_idle', location = 'home' },
            { from = '09:00', to = '12:00', activity = 'leisure', location = 'fav:park' },
            { from = '12:00', to = '13:30', activity = 'lunch', location = 'flex:lunch' },
            { from = '13:30', to = '15:30', activity = 'home_idle', location = 'home' },
            { from = '15:30', to = '18:30', activity = 'free', location = 'flex:free' },
            { from = '18:30', to = '21:30', activity = 'home_idle', location = 'home' },
            { from = '21:30', to = '06:30', activity = 'sleep', location = 'home' },
        },
        offday = {
            { from = '07:00', to = '09:30', activity = 'home_idle', location = 'home' },
            { from = '09:30', to = '12:30', activity = 'leisure', location = 'fav:park' },
            { from = '12:30', to = '14:00', activity = 'lunch', location = 'flex:lunch' },
            { from = '14:00', to = '16:00', activity = 'home_idle', location = 'home' },
            { from = '16:00', to = '19:00', activity = 'free', location = 'flex:free' },
            { from = '19:00', to = '22:00', activity = 'home_idle', location = 'home' },
            { from = '22:00', to = '07:00', activity = 'sleep', location = 'home' },
        },
    },

    student = {
        label = 'Öğrenci',
        workday = {
            { from = 'shift_start-120', to = 'shift_start', activity = 'home_idle', location = 'home' },
            { from = 'shift_start', to = 'shift_mid', activity = 'study', location = 'work' },
            { from = 'shift_mid', to = 'shift_mid+60', activity = 'lunch', location = 'flex:lunch' },
            { from = 'shift_mid+60', to = 'shift_end', activity = 'study', location = 'work' },
            { from = 'shift_end', to = '21:00', activity = 'free', location = 'flex:free' },
            { from = '21:00', to = '24:30', activity = 'home_idle', location = 'home' },
            { from = '24:30', to = 'shift_start-120', activity = 'sleep', location = 'home' },
        },
        offday = {
            { from = '10:30', to = '13:00', activity = 'home_idle', location = 'home' },
            { from = '13:00', to = '18:00', activity = 'free', location = 'flex:free' },
            { from = '18:00', to = '20:00', activity = 'home_idle', location = 'home' },
            { from = '20:00', to = '26:00', activity = 'free', location = 'flex:free' },
            { from = '26:15', to = '34:30', activity = 'sleep', location = 'home' },
        },
    },

    fisherman = {
        label = 'Balıkçı',
        workday = {
            { from = '04:00', to = 'shift_start', activity = 'home_idle', location = 'home' },
            { from = 'shift_start', to = 'shift_end', activity = 'fish', location = 'work', firm = true },
            { from = 'shift_end', to = 'shift_end+90', activity = 'lunch', location = 'flex:lunch' },
            { from = 'shift_end+90', to = '16:30', activity = 'home_idle', location = 'home' },
            { from = '16:30', to = '20:30', activity = 'free', location = 'flex:free' },
            { from = '21:00', to = '04:00', activity = 'sleep', location = 'home' },
        },
        offday = {
            { from = '07:00', to = '10:00', activity = 'home_idle', location = 'home' },
            { from = '10:00', to = '13:00', activity = 'fish', location = 'fav:pier' },
            { from = '13:00', to = '14:30', activity = 'lunch', location = 'flex:lunch' },
            { from = '14:30', to = '17:00', activity = 'home_idle', location = 'home' },
            { from = '17:00', to = '21:30', activity = 'free', location = 'flex:free' },
            { from = '22:00', to = '04:00', activity = 'sleep', location = 'home' },
        },
    },
}
