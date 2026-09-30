--[[
    Aktivite kataloğu
    tags     : konumdaki hangi "aktivite noktaları"nda yapılabileceği (nokta tag'leri ile eşleşir)
    inside   : noktası yoksa bina içinde sayılır (fiziksel ped oluşmaz)
    needs    : oyun saati başına ihtiyaç değişimi (energy/social/fun artı = iyi, hunger artı = acıkma)
    busy     : NPC meşgul sayılır (kısa konuşur, SMS'e geç döner)
    scenario : noktada senaryo tanımlı değilse kullanılacak varsayılan GTA senaryosu
    wander   : true ise NPC bu aktivitede Config.Schedule.WanderMinutes aralığıyla aynı konumdaki başka bir
               uygun noktaya yürür (parkta dolaşma, kulüpte masalar arası gezinme)
    anims    : nokta etiketine göre senaryo yerine oynatılacak animasyon { tag = { dict, anim } }
    adultAnims : true ise anims sadece Config.AdultNPC.Enabled iken kullanılır
]]
SC.Activities = {
    sleep       = { inside = true, needs = { energy = 13, hunger = 2, social = -0.5, fun = 0 }, sleeping = true },
    home_idle   = { tags = { 'home_idle', 'smoke' }, needs = { energy = -2, hunger = 4, social = -2, fun = 1 }, scenario = 'WORLD_HUMAN_STAND_MOBILE' },
    idle        = { tags = { 'idle', 'smoke', 'wait' }, needs = { energy = -2, hunger = 4, social = -1, fun = -1 }, scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
    work        = { tags = { 'work' }, busy = true, firm = true, needs = { energy = -6, hunger = 6, social = 1, fun = -3 }, scenario = 'WORLD_HUMAN_CLIPBOARD' },
    study       = { tags = { 'study', 'work' }, busy = true, firm = true, needs = { energy = -5, hunger = 6, social = 3, fun = -2 }, scenario = 'WORLD_HUMAN_STAND_MOBILE' },
    deliver     = { tags = { 'deliver', 'idle', 'wait' }, busy = true, needs = { energy = -6, hunger = 6, social = 1, fun = -2 }, scenario = 'WORLD_HUMAN_CLIPBOARD' },
    lunch_break = { tags = { 'break', 'eat', 'smoke' }, needs = { hunger = -30, energy = 2, social = 3, fun = 3 }, scenario = 'WORLD_HUMAN_SMOKING' },
    eat         = { tags = { 'eat', 'coffee' }, needs = { hunger = -45, energy = 3, social = 4, fun = 3 }, scenario = 'WORLD_HUMAN_AA_COFFEE' },
    coffee      = { tags = { 'coffee', 'eat' }, needs = { hunger = -12, energy = 6, social = 5, fun = 4 }, scenario = 'WORLD_HUMAN_AA_COFFEE' },
    drink       = { tags = { 'drink', 'socialize' }, needs = { energy = -3, hunger = 3, social = 12, fun = 9 }, scenario = 'WORLD_HUMAN_DRINKING' },
    leisure     = { tags = { 'leisure', 'walk' }, wander = true, needs = { energy = -2, hunger = 4, social = 2, fun = 9 }, scenario = 'WORLD_HUMAN_TOURIST_MOBILE' },
    exercise    = { tags = { 'exercise' }, needs = { energy = -9, hunger = 8, social = 2, fun = 7 }, scenario = 'WORLD_HUMAN_JOG_STANDING' },
    shopping    = { tags = { 'shopping' }, inside = true, needs = { energy = -3, hunger = 4, social = 2, fun = 5 }, scenario = 'WORLD_HUMAN_WINDOW_SHOP_BROWSE' },
    fish        = { tags = { 'fish' }, busy = false, needs = { energy = -2, hunger = 4, social = 1, fun = 10 }, scenario = 'WORLD_HUMAN_STAND_FISHING' },
    commute     = { needs = { energy = -3, hunger = 5, social = -1, fun = -2 }, busy = true },
    appointment = { tags = { 'wait', 'idle', 'leisure' }, neverInside = true, needs = { energy = -2, hunger = 3, social = 8, fun = 5 }, scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
    hospital    = { inside = true, needs = { energy = 4, hunger = 2, social = -3, fun = -4 } },
    follow      = { needs = { energy = -3, hunger = 4, social = 8, fun = 5 } },
    -- v3: eğlence çalışanı (Vanilla Unicorn vb.); direk ve dans pisti noktalarında animasyon, diğerlerinde senaryo
    entertain   = { tags = { 'pole', 'dance_floor', 'wait', 'smoke' }, busy = true, firm = true, wander = true,
                    needs = { energy = -5, hunger = 5, social = 6, fun = 3 }, scenario = 'WORLD_HUMAN_PARTYING',
                    anims = { pole = { 'mini@strip_club@pole_dance@pole_dance1', 'pd_dance_01' },
                              dance_floor = { 'mini@strip_club@idles@stripper', 'stripper_idle_02' } },
                    adultAnims = true },
}

-- Rutin şablonlarında kullanılabilen "esnek" aktiviteler (gün içinde ihtiyaca göre çözülür)
SC.FlexActivities = { lunch = true, free = true }

-- Esnek aktivitelerin gidebileceği konum tipleri
SC.LeisureTypes = {
    drink = { 'bar' },
    leisure = { 'park', 'beach' },
    coffee = { 'cafe' },
    eat = { 'cafe', 'restaurant', 'fastfood' },
    exercise = { 'gym' },
    shopping = { 'shop' },
    fish = { 'pier' },
}

SC.LocationTypes = { 'home', 'work', 'cafe', 'restaurant', 'fastfood', 'bar', 'club', 'gym', 'park', 'beach', 'shop', 'pier', 'hospital', 'office', 'school', 'garage', 'depot', 'other' }

-- Konuşma sırasındaki hareketler
SC.Gestures = {
    wave     = { dict = 'friends@frj@ig_1', anim = 'wave_a', dur = 2500 },
    shrug    = { dict = 'gestures@m@standing@casual', anim = 'gesture_shrug_hard', dur = 1800 },
    laugh    = { dict = 'anim@arena@celeb@flat@paired@no_props@', anim = 'laugh_a_player_b', dur = 3000 },
    facepalm = { dict = 'anim@mp_player_intcelebrationmale@face_palm', anim = 'face_palm', dur = 3000 },
    point    = { dict = 'gestures@m@standing@casual', anim = 'gesture_point', dur = 1800 },
    nod      = { dict = 'gestures@m@standing@casual', anim = 'gesture_nod_yes_soft', dur = 1500 },
    no       = { dict = 'gestures@m@standing@casual', anim = 'gesture_head_no', dur = 1500 },
    talk     = { dict = 'gestures@m@standing@casual', anim = 'gesture_easy_now', dur = 2000 },
    thanks   = { dict = 'mp_common', anim = 'givetake1_a', dur = 1800 },
}

SC.Emotions = {
    happy = 'mood_happy_1',
    neutral = 'mood_normal_1',
    sad = 'mood_sulk_1',
    angry = 'mood_angry_1',
    scared = 'mood_stressed_1',
    embarrassed = 'mood_frustrated_1',
    surprised = 'mood_excited_1',
}

SC.Scenarios = {
    'WORLD_HUMAN_STAND_IMPATIENT', 'WORLD_HUMAN_STAND_MOBILE', 'WORLD_HUMAN_SMOKING', 'WORLD_HUMAN_CLIPBOARD',
    'WORLD_HUMAN_AA_COFFEE', 'WORLD_HUMAN_DRINKING', 'WORLD_HUMAN_TOURIST_MOBILE', 'WORLD_HUMAN_TOURIST_MAP',
    'WORLD_HUMAN_JOG_STANDING', 'WORLD_HUMAN_PUSH_UPS', 'WORLD_HUMAN_SIT_UPS', 'WORLD_HUMAN_MUSCLE_FREE_WEIGHTS',
    'PROP_HUMAN_MUSCLE_CHIN_UPS', 'WORLD_HUMAN_YOGA', 'WORLD_HUMAN_STAND_FISHING', 'WORLD_HUMAN_LEANING',
    'WORLD_HUMAN_HANG_OUT_STREET', 'WORLD_HUMAN_PARTYING', 'WORLD_HUMAN_WELDING', 'WORLD_HUMAN_HAMMERING',
    'WORLD_HUMAN_VEHICLE_MECHANIC', 'WORLD_HUMAN_JANITOR', 'WORLD_HUMAN_MAID_CLEAN', 'WORLD_HUMAN_GARDENER_PLANT',
    'WORLD_HUMAN_GUARD_STAND', 'WORLD_HUMAN_WINDOW_SHOP_BROWSE', 'WORLD_HUMAN_CAR_PARK_ATTENDANT',
    'WORLD_HUMAN_MUSICIAN', 'WORLD_HUMAN_BINOCULARS', 'WORLD_HUMAN_PICNIC', 'WORLD_HUMAN_SUNBATHE',
    'WORLD_HUMAN_SEAT_LEDGE', 'WORLD_HUMAN_SEAT_STEPS', 'WORLD_HUMAN_SEAT_WALL', 'PROP_HUMAN_SEAT_BENCH',
    'PROP_HUMAN_SEAT_CHAIR', 'PROP_HUMAN_SEAT_CHAIR_DRINK', 'PROP_HUMAN_SEAT_CHAIR_FOOD', 'PROP_HUMAN_SEAT_BAR',
    'PROP_HUMAN_BBQ', 'CODE_HUMAN_MEDIC_TIME_OF_DEATH', 'WORLD_HUMAN_CHEERING',
}
