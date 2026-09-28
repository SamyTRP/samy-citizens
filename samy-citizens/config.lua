Config = {}

--[[ =====================================================================
    GENEL
===================================================================== ]]
Config.Locale = 'tr'                -- 'tr' | 'en'  (arayüz dili; NPC diyalogları data/dialogue.lua'dadır)
Config.Framework = 'auto'           -- 'auto' | 'qbx' | 'qb' | 'esx'   [DEĞİŞTİR: QBCore/ESX ise]
Config.Debug = false                -- sunucu konsoluna ayrıntılı log

--[[ =====================================================================
    ZAMAN & HAVA
===================================================================== ]]
Config.TimeMode = 'game'            -- 'game' (oyun saati) | 'real' (gerçek saat)
Config.GameMinuteMs = 2000          -- 1 oyun dakikası kaç gerçek ms (GTA varsayılanı 2000 = 48 dk'lık gün)
Config.RealTimeUtcOffset = 3        -- 'real' modda saat dilimi (Europe/Istanbul = UTC+3, yaz saati yok)
-- Oyun saatinin kaynağı: 'auto' = bilinen weathersync export'larını dener, yoksa oyunculardan örnekler
-- 'client' = her zaman bir oyuncunun GetClockHours/Minutes değerini örnekler
-- 'internal' = kendi saatini işletir (sunucuda saat senkronu yoksa)
Config.TimeSource = 'auto'
Config.ClockSampleIntervalMs = 30000
Config.WeekStartOffset = 0          -- oyun modunda gün numarasına eklenen kaydırma (0 => gün%7==0 Pazartesi)
Config.RainWeathers = { RAIN = true, THUNDER = true, CLEARING = true, BLIZZARD = true, SNOW = true, SNOWLIGHT = true, XMAS = true }

--[[ =====================================================================
    SİMÜLASYON LOD
===================================================================== ]]
Config.SimTickMs = 2000             -- soyut katman tick'i (~1 oyun dakikası)
Config.SaveIntervalMs = 60000       -- DB toplu yazım aralığı
Config.SpawnRadius = 150.0          -- oyuncu bu mesafeye girince ped oluşur
Config.DespawnBuffer = 40.0         -- SpawnRadius + tampon dışına çıkınca ped silinir
Config.VehicleSpawnRadius = 130.0   -- park halindeki sakin araçları için
Config.MaxSpawnedResidents = 20     -- aynı anda fiziksel olabilecek en fazla sakin
Config.SpawnCheckMs = 1500
Config.SnapTimeoutMs = 2500         -- spawn konumunu yakın istemciye düzelttirme zaman aşımı
Config.PedCullingRadius = 350.0

Config.Travel = {
    WalkMaxDistance = 200.0,        -- bu mesafeden uzağa araçla/toplu taşımayla gider (oyun saati 30x hızlı akar!)
    WalkSpeed = 1.35,               -- m/sn (tahmini varış hesabı)
    CarSpeed = 13.0,                -- m/sn (şehir içi ortalama)
    TransitSpeed = 9.0,             -- m/sn (taksi/otobüs; fiziksel olarak görünmez)
    DetourFactor = 1.35,            -- kuş uçuşu mesafeye eklenen sapma
    DriveSpeed = 14.0,              -- fiziksel sürüşte hedef hız (m/sn)
    DrivingStyle = 786603,          -- sakin/normal sürüş
    ArrivalGraceMinutes = 120,      -- fiziksel ped tahmini varıştan bu kadar oyun dk geç kalabilir
    MinTravelMinutes = 5,
}

Config.Routine = {
    JitterMin = 10,                 -- her gün blok başlangıçlarına ±10–20 dk sapma
    JitterMax = 20,
    JitterOverrides = { work = 6, study = 6, sleep = 25 },
    GapFillMinutes = 60,            -- bloklar arası boşluk bundan uzunsa evde vakit geçirir
    OutsideChance = { home_idle = 0.35, idle = 1.0 },  -- noktası olan aktivitelerde dışarıda görünme olasılığı
    MaxLunchDistance = 1200.0,      -- öğle arası için gidilebilecek en uzak mekan
}

-- İhtiyaç değişim hızları aktivite tanımlarında (shared/activities.lua). Eşikler:
Config.Needs = {
    LunchOutHunger = 50,            -- açlık bunun üstündeyse öğle arası dışarı yemeğe gider
    EarlySleepEnergy = 25,          -- enerji bunun altındaysa akşam erken yatar
    LonelySocial = 40,              -- sosyal bunun altındaysa bara/parka gitmeyi tercih eder
    BoredFun = 40,
    MoodDriftPerHour = 6,           -- ruh hâli hedefe doğru saatte bu kadar kayar
}

--[[ =====================================================================
    KONUŞMA
===================================================================== ]]
Config.Conversation = {
    StartDistance = 3.0,
    MaxDistance = 5.0,              -- bu mesafeden uzaklaşınca konuşma biter
    IdleTimeoutSec = 150,
    BubbleDistance = 20.0,          -- 3D baloncuğu görecek oyuncuların mesafesi
    BubbleDurationMs = 7000,
    ShowPlayerBubble = true,        -- oyuncunun sözü de başının üstünde görünsün
    AllowWhileDriving = false,
    AmbientGreetings = true,        -- tanıdık sakin yanından geçerken selam verir
    AmbientDistance = 6.0,
    AmbientCooldownSec = 300,       -- aynı oyuncuya en erken tekrar selam
    NudgeAfterSec = 25,             -- oyuncu bu kadar sn susarsa sakin kendisi söz alır (soru sorar, bir şey anlatır)
    MaxNudges = 2,                  -- bir konuşmada en fazla kaç kez kendiliğinden söz alır
}

--[[ =====================================================================
    DİYALOG MOTORU (yapay zekâ yok; cümleler data/dialogue.lua)
===================================================================== ]]
Config.Dialogue = {
    MinScore = 1.0,                 -- niyet puanı bunun altındaysa "anlamadım" cevabı
    TypingDelayMs = { 600, 2200 },  -- cevap öncesi "düşünme" süresi (cevap uzunluğuna göre)
    AskBackChance = 0.6,            -- "Sen nasılsın?" gibi karşı soru olasılığı
    BusyMaxTurns = 6,               -- işteyken/yoldayken (arkadaş değilse) en fazla bu kadar cevap (müşteri siparişleri sayılmaz)
    PhoneTrust = 15,                -- numara vermek için gereken en az güven (şüpheci kişilikte +15)
    -- niyet başına ilişki etkisi { sevgi, güven } (günlük sınırlar yine geçerli)
    Deltas = {
        greet = { 0, 0 }, how_are_you = { 1, 0 }, ask_name = { 0, 1 }, introduce = { 1, 1 }, ask_job = { 1, 0 },
        ask_hobby = { 1, 0 }, ask_family = { 1, 1 }, ask_dream = { 1, 1 }, ask_origin = { 1, 0 }, ask_food = { 1, 0 },
        ask_music = { 1, 0 }, compliment = { 2, 0 }, thanks = { 1, 1 }, laugh = { 1, 0 }, insult = { -5, -3 },
        threat = { -5, -5 }, player_job = { 0, 1 }, player_like = { 1, 0 }, answer = { 1, 0 }, ask_news = { 0, 1 },
        goodbye = { 0, 0 }, fallback = { 0, 0 },
        ask_joke = { 1, 0 }, ask_feeling = { 1, 1 }, ask_plans = { 1, 0 }, sympathy = { 1, 1 }, agree = { 1, 0 },
        impressed = { 1, 0 }, me_too = { 1, 0 }, miss_you = { 1, 1 }, offer_drink = { 1, 1 }, player_origin = { 1, 1 },
        ask_advice = { 0, 1 }, ask_pet = { 1, 0 }, ask_movie = { 1, 0 }, ask_sport = { 1, 0 }, ask_favorite_place = { 1, 0 },
        banter = { 1, 0 }, hug = { 1, 1 }, kiss = { 1, 0 }, job_q = { 1, 1 }, ask_expertise = { 1, 1 }, player_dream = { 1, 1 },
        player_family = { 1, 1 }, player_food = { 1, 0 }, player_music = { 1, 0 }, player_pet = { 1, 0 }, player_secret = { 2, 3 },
    },
    GoodConversationBonus = { 2, 1 }, -- en az 3 mesajlık, olumsuzluksuz konuşma sonunda
    FuzzyMatch = true,              -- küçük yazım hatalarını tolere et ("nasilsn", "tesekurler")
    SecondIntent = true,            -- tek cümlede iki soru varsa ikisine de cevap ver ("adın ne, ne iş yapıyorsun?")
    NpcQuestionChance = 0.32,       -- sakinin sohbeti sürdürmek için kendisinin soru sorma olasılığı (konuşkanlarda x1.7)
    StoryChance = 0.18,             -- sakinin kendiliğinden başından geçen bir şeyi anlatma olasılığı
    MaxNpcQuestions = 5,            -- bir konuşmada sakinin en fazla soracağı soru
    FillerChance = 0.15,            -- "Valla", "Şey", "Hıh" gibi kişiliğe uygun dolgu sözcükleri
    FactRecallChance = 0.4,         -- tanıdık oyuncuyu karşılarken onun hakkında bildiklerinden bahsetme
}

Config.RateLimit = {
    PerMinute = 12,
    PerDay = 400,
    MaxChars = 300,
    SmsPerDay = 60,
}

--[[ =====================================================================
    HAFIZA
===================================================================== ]]
Config.Memory = {
    CompactThreshold = 30,          -- bir NPC–oyuncu çifti için aktif anı sayısı bunu aşınca eskiler arşivlenir
    CompactKeepRecent = 12,
    PermanentImportance = 8,        -- bu önem ve üstü asla unutulmaz
    ForgetMaxImportance = 4,        -- bu önem ve altı...
    ForgetAfterDays = 14,           -- ...bu kadar gerçek gün erişilmezse silinir
    ArchiveDeleteAfterDays = 60,
    MaxTextLength = 220,
}

--[[ =====================================================================
    İLİŞKİLER
===================================================================== ]]
Config.Relationship = {
    Stages = {
        enemy        = { maxAffinity = -60 },
        cold         = { maxAffinity = -20 },
        acquaintance = { familiarity = 15, timesMet = 2 },
        friend       = { familiarity = 40, affinity = 30, trust = 30, meetDays = 3 },
        close_friend = { familiarity = 70, affinity = 60, trust = 55, meetDays = 6 },
        -- sevgili: skorla değil, sakinin teklifi kabul etmesiyle olur (bkz. Config.Romance); bu değerlerin altına düşerse ayrılırlar
        lover        = { affinity = 25, trust = 20 },
    },
    MaxDeltaPerMessage = 5,
    DailyAffinityCap = 15,          -- günlük en fazla pozitif artış (spam koruması)
    DailyTrustCap = 12,
    DailyFamiliarityCap = 12,
    FamiliarityPerMessage = 1,
    FamiliarityPerNewDay = 5,
    DayUnit = 'real',               -- 'real' | 'game'  (görüşme günü sayımı; test için 'game' daha hızlıdır)
    DecayAfterDays = 5,             -- bu kadar gerçek gün görüşülmezse...
    DecayPerDay = 2,                -- ...familiarity günde bu kadar düşer
    LongAbsenceDays = 4,            -- "Uzun zamandır yoktun!" eşiği
}

--[[ =====================================================================
    AKSİYONLAR
===================================================================== ]]
Config.Actions = {
    -- sakinin "ne dersek yapması" için gereken en düşük ilişki aşaması
    MinStage = {
        give_phone_number = 'acquaintance',
        create_appointment = 'friend',
        follow_player = 'friend',       -- "benimle gel"
        wait = 'friend',                -- "burada bekle"
        goto_waypoint = 'friend',       -- "haritada işaretlediğim yere git"
        ride = 'friend',                -- "arabanla gezelim" / "beni oraya götür"
        outing = 'friend',              -- "hadi şimdi kahve içmeye gidelim"
        perform = 'friend',             -- "dans et", "otur", "sigara yak"...
        go_home = 'acquaintance',       -- "evine git", "işine dön"
        report_police = 'acquaintance', -- "polisi ara / polise şikayet et"
        busy_obey = 'close_friend',     -- işteyken bile söz dinler (bu aşama ve üstü)
    },
    FollowMaxMinutes = 10,          -- gerçek dakika
    AppointmentMaxDaysAhead = 3,    -- oyun/gerçek günü (TimeMode'a göre)
    AppointmentWaitMinutes = 30,    -- oyun dakikası: oyuncu gelmezse bekleme süresi
    AppointmentMeetMinutes = 90,    -- buluşma modu en fazla süre (oyun dk)
    AppointmentArriveDistance = 25.0,
    AppointmentMinGap = 90,         -- aynı sakinin randevuları arası en az oyun dk
    AppointmentReminderMinutes = 30,
    PoliceCooldownSec = 90,
    WaitMinutes = 8,                -- "burada bekle": gerçek dakika
    GotoWaitMinutes = 6,            -- işaretli yere vardıktan sonra orada bekleme süresi (gerçek dk)
    GotoWalkMaxDistance = 350.0,    -- bundan uzak hedefe arabası yoksa taksiyle (görünmez) gider
    GotoTimeoutMinutes = 6,         -- yürüyerek/arabayla gidiş en fazla (takılırsa bırakır)
    RideMaxMinutes = 12,            -- araba gezmesi en fazla (gerçek dk)
    RideBoardSeconds = 60,          -- oyuncunun arabaya binmesi için beklenen süre
    PerformMinutes = 3,             -- "dans et" gibi eylemler ne kadar sürer (gerçek dk)
    OutingMinutes = 25,             -- "hadi şimdi yemeğe gidelim": mekânda kalma süresi (oyun dk)
    ReportCooldownSec = 120,        -- aynı sakine arka arkaya polis ihbarı yaptırma sınırı
}

--[[ =====================================================================
    AŞK / SEVGİLİ
===================================================================== ]]
Config.Romance = {
    Enabled = true,
    MinStage = 'close_friend',      -- "sevgilim olur musun?" teklifi en az bu aşamada kabul edilebilir
    MinAffinity = 70,
    MinTrust = 60,
    AllowMultiple = false,          -- false: oyuncunun başka bir sakinle sevgili olduğunu duyan sakin kabul etmez / kıskanır
    CheatPenalty = { -35, -40 },    -- aldatıldığını öğrenince { sevgi, güven }
}

--[[ =====================================================================
    KÜFÜR / ARGO   (filtre yok: sakin karşılık verir ve hatırlar)
===================================================================== ]]
Config.Profanity = {
    Enabled = true,                 -- küfürlü cümleler algılanır (false: normal hakaret gibi davranır)
    SwearBack = true,               -- kişiliğine göre küfürle karşılık verir (çekingen/resmî olanlar alınır, kırılır)
    Remember = true,                -- küfredildiğini hatırlar, mahallede anlatır
    FriendlyBanter = true,          -- samimi arkadaşla "naber lan" tarzı şakalaşma (ilişki bozulmaz)
    NpcBanterChance = 0.35,         -- argo konuşan sakinin samimi arkadaşına kendiliğinden argo selam verme olasılığı
    MaxBeforeLeave = 3,             -- bir konuşmada bu kadar düşmanca küfürden sonra konuşmayı bitirir
}

--[[ =====================================================================
    MESLEK HİZMETLERİ   (barmen içki verir, hemşire iyileştirir, tamirci arabayı yapar...)
    Meslek, sakinin meslek adından otomatik algılanır (data/jobs.lua). Hizmetler sakin işbaşındayken tam,
    değilken (arkadaşsa) kısıtlı verilir.
===================================================================== ]]
Config.JobServices = {
    Enabled = true,
    Charge = true,                  -- hizmet ücretli (Account hesabından düşülür; yetmezse sakin reddeder)
    Account = 'cash',
    FriendDiscount = 0.5,           -- arkadaş ve üstüne indirim oranı (0.5 = yarı fiyat), sevgiliye bedava
    GiveItems = true,               -- ox_inventory varsa sipariş edilen eşya verilir (yoksa açlık/susuzluk metadata'sı artar)
    HealAmount = 60,                -- hemşire/doktorun geri verdiği can (0-200 ölçeği; oyuncu can 200 = tam)
    HealPrice = 50,
    HealCooldownSec = 300,
    OffDutyHeal = true,             -- mesaisi dışındaki sağlıkçı da (arkadaşsa) ilk yardım yapar (yarı can)
    HealClientEvent = nil,          -- tedaviden sonra oyuncuda tetiklenecek istemci event'i (örn. 'hospital:client:HealInjuries')
    RepairPrice = 250,
    RepairSeconds = 9,
    RepairCooldownSec = 300,
    ServiceCooldownSec = 20,        -- aynı sakinden art arda sipariş arası
}

--[[ =====================================================================
    TELEFON (gksphone v2)
===================================================================== ]]
Config.Phone = {
    Provider = 'gksphone',          -- 'gksphone' | 'builtin' (yerleşik mini mesajlaşma) | 'none'
    NumberPattern = '555#####',     -- sakin numarası üretim kalıbı (# = rakam)
    BuiltinCommand = 'sakinmesaj',
    CheckIntervalMs = 1000,         -- bekleyen cevaplar saniyede bir kontrol edilir (hafif)
    -- cevap gecikmesi (gerçek saniye, aralıktan rastgele + mesaj uzunluğuna göre birkaç sn okuma payı)
    ReplyDelaySec = { 3, 8 },       -- müsaitken
    BusyDelaySec = { 12, 35 },      -- işte / derste / yolda
    TalkingDelaySec = { 15, 40 },   -- biriyle yüz yüze konuşurken
    SleepMode = 'wake',             -- 'wake': uyurken de (uykulu) cevap verir | 'wait': uyanınca cevap verir
    SleepDelaySec = { 20, 60 },
    FriendDelayFactor = 0.6,        -- arkadaş / yakın arkadaşa daha çabuk döner
    MaxReplyDelaySec = 90,          -- art arda mesaj gelse de ilk mesajdan sonra en geç (uyku beklemesi hariç)
    SplitLongReplies = true,        -- uzun cevabı bazen iki ayrı mesaj olarak yollar
    ProactiveEnabled = true,
    ProactivePerDay = 1,            -- yakın arkadaş NPC günde en fazla kaç kez kendiliğinden yazar
    ProactiveChancePerHour = 0.10,  -- boş zamanda oyun saati başına olasılık
    MaxPendingPerThread = 5,
    ThreadMemoryMinutes = 30,       -- SMS'teki yarım kalan konuşma (ör. buluşma saati) bu kadar gerçek dk hatırlanır
}

--[[ =====================================================================
    NPC–NPC SOSYAL HAYAT
===================================================================== ]]
Config.Social = {
    ChatChancePer10Min = 0.12,
    SocialActivities = { work = true, eat = true, coffee = true, drink = true, leisure = true, idle = true, home_idle = true, exercise = true, lunch_break = true, study = true },
    GossipMinImportance = 7,
    GossipMaxImportance = 4,        -- dedikodu alıcıda en fazla bu önemle saklanır
    GossipAffinity = 6,             -- dedikodunun dinleyenin oyuncuya bakışına etkisi (valence ile çarpılır)
    PhysicalChatSeconds = 20,
    NeighborAreaMatch = true,       -- aynı 'area' etiketli evler komşu sayılır
}

--[[ =====================================================================
    DÜNYA OLAYLARI
===================================================================== ]]
Config.World = {
    GunshotRadius = 70.0,
    WitnessIdentifyRadius = 30.0,   -- bu mesafedeki sakin faili tanır
    ExplosionRadius = 90.0,
    FleeSeconds = 25,
    ShakenMinutes = 120,            -- korkan sakin bu kadar oyun dk evine kapanır
    HospitalDays = 1,               -- oyun günü
    PermaDeath = false,
    AimReportCooldownSec = 6,
    CarTheftDetection = true,
}

-- Oyun olaylarının anı/ilişki etkileri
Config.Events = {
    aim_weapon      = { importance = 8, valence = -1, affinity = -25, trust = -30, shareable = true, mood = -45 },
    threatened      = { importance = 7, valence = -1, affinity = -20, trust = -25, shareable = true, mood = -35 },
    gunshot_near    = { importance = 5, valence = -1, affinity = -8,  trust = -8,  shareable = true, mood = -25 },
    gunshot_witness = { importance = 4, valence = 0,  mood = -15 },
    explosion       = { importance = 5, valence = 0,  mood = -30 },
    hit_by_vehicle  = { importance = 7, valence = -1, affinity = -20, trust = -15, shareable = true, mood = -30 },
    assaulted       = { importance = 8, valence = -1, affinity = -35, trust = -35, shareable = true, mood = -40 },
    killed          = { importance = 10, valence = -1, affinity = -100, trust = -100, shareable = true, mood = -60 },
    car_stolen      = { importance = 8, valence = -1, affinity = -30, trust = -30, shareable = true, mood = -35 },
    missed_appointment = { importance = 6, valence = -1, affinity = -8, trust = -10, shareable = false, mood = -15 },
    met_appointment = { importance = 6, valence = 1, affinity = 4, trust = 5, shareable = false, mood = 15 },
    gift            = { importance = 5, valence = 1, shareable = false, mood = 12 },
    saved           = { importance = 9, valence = 1, affinity = 30, trust = 30, shareable = true, mood = 25 },
    harassment      = { importance = 6, valence = -1, affinity = -10, trust = -10, shareable = true, mood = -20 },
    cursed          = { importance = 5, valence = -1, affinity = -8,  trust = -5,  shareable = true, mood = -15 },
    became_lover    = { importance = 9, valence = 1, shareable = true, mood = 40 },
    broke_up        = { importance = 8, valence = -1, affinity = -20, trust = -15, shareable = true, mood = -45 },
    cheated         = { importance = 9, valence = -1, shareable = true, mood = -50 },
    served          = { importance = 2, valence = 1, shareable = false, mood = 3 },
    helped_heal     = { importance = 5, valence = 1, affinity = 3, trust = 3, shareable = false, mood = 8 },
    shared_secret   = { importance = 6, valence = 1, shareable = false, mood = 5 },
    kidnapped       = { importance = 10, valence = -1, affinity = -70, trust = -80, shareable = true, mood = -70 },
}

--[[ =====================================================================
    REHİNE ALMA
    Silahlıyken sakine yakından nişan al + [E] (ya da ox_target "Rehin al").
    Rehin tutarken: [G] bırak · [H] kalkan / yürüt · [J] diz çöktür · [K] araca bindir / indir
    (tuşları oyuncular GTA Ayarlar > Tuş Atamaları > FiveM bölümünden değiştirebilir)
===================================================================== ]]
Config.Hostage = {
    Enabled = true,
    AllowMelee = true,              -- bıçak, sopa vb. ile de rehin alınabilir (false: sadece ateşli silah)
    TakeDistance = 2.0,
    StartMode = 'hold',             -- ilk mod: 'hold' (kalkan, önünde tutar) | 'escort' (eller yukarı önünden yürür)
    Keys = { take = 'E', release = 'G', mode = 'H', kneel = 'J', vehicle = 'K' },
    LeashDistance = 25.0,           -- rehineden bu kadar uzaklaşırsan (aynı araçta değilse) kaçar
    EscapeCheckSec = 10,
    EscapeChance = 0.04,            -- her kontrolde kaçma denemesi (silah elindeyken); kalkan modunda kaçamaz
    EscapeChanceUnarmed = 0.35,     -- silahı indirdiysen
    MaxMinutes = 30,                -- gerçek dk; 0 = sınırsız. Süre dolunca bir fırsatını bulup kaçar
    PleadIntervalSec = { 10, 22 },  -- rehinenin yalvarma baloncukları
    WitnessRadius = 30.0,           -- bu mesafede olayı gören sakinler kaçar ve (aşağıdaki gecikmeyle) polisi arar
    WitnessPoliceDelaySec = 20,
    ReleasePoliceDelaySec = 8,      -- serbest kalan / kaçan rehine bu kadar sn sonra polisi arar
    FleeSeconds = 35,
    ShakenMinutes = 300,            -- sonra evine kapanır (oyun dk)
    RecognizeDays = 7,              -- rehin alanı bu kadar gerçek gün tanır: görünce bağırır, kaçar, polisi arar
}

--[[ =====================================================================
    POLİS / DISPATCH   [DEĞİŞTİR: kullandığın dispatch]
===================================================================== ]]
Config.Dispatch = {
    System = 'ps-dispatch',         -- 'ps-dispatch' | 'cd_dispatch' | 'custom' | 'none'
    Jobs = { 'police' },
    Code = '10-66',
    Blip = { sprite = 280, color = 1, scale = 1.0, length = 2 },
    -- System = 'custom' ise bu fonksiyon SUNUCUDA çağrılır
    Custom = function(data)
        -- data = { coords = vector3, message = string, residentName = string, street = string|nil }
        -- örn: exports['my-dispatch']:SendAlert(data)
    end,
}

--[[ =====================================================================
    GÜVENLİK / MODERASYON / LOG
===================================================================== ]]
Config.Moderation = {
    Enabled = false,                -- true: aşağıdaki kelimeler konuşmayı anında bitirir (eski davranış). false: sakin kendisi karşılık verir (Config.Profanity)
    -- ağır küfürler konuşmayı bitirir (hafif hakaretler data/dialogue.lua'daki 'insult' niyetiyle karşılanır)
    -- tek kelime veya kelime öbeği; büyük/küçük harf ve Türkçe karakter duyarsız, kelime sınırıyla eşleşir
    SevereWords = { 'orospu', 'orosbu', 'amına', 'amina', 'sikerim', 'siktir', 'yarrak', 'piç', 'pic kurusu', 'ananı', 'anani', 'amk', 'aq', 'fuck you', 'motherfucker', 'whore' },
}

Config.Logging = {
    Conversations = true,           -- samy_citizens_conversations tablosu
    Discord = true,                 -- webhook: set samy_citizens_webhook "https://discord.com/api/webhooks/..."
    DiscordFlushMs = 10000,
}

--[[ =====================================================================
    YÖNETİM
===================================================================== ]]
Config.Admin = {
    Ace = 'samycitizens.admin',     -- add_ace group.admin samycitizens.admin allow
    Command = 'citizensadmin',
    DebugCommand = 'citizensdebug',
    BlipRefreshMs = 5000,
}

--[[ =====================================================================
    HEDİYE (ox_inventory varsa)
===================================================================== ]]
Config.Gifts = {
    Enabled = true,
    AllowAnyItem = false,           -- false: sadece aşağıdaki listedeki eşyalar
    DailyBonusPerResident = 1,      -- aynı sakine günde kaç hediye ilişki bonusu verir
    Items = {
        coffee = { affinity = 3, trust = 1 },
        water_bottle = { affinity = 1, trust = 0 },
        sandwich = { affinity = 2, trust = 1 },
        burger = { affinity = 2, trust = 1 },
        donut = { affinity = 2, trust = 1 },
        beer = { affinity = 2, trust = 1 },
        flowers = { affinity = 5, trust = 2 },
        rose = { affinity = 5, trust = 2 },
        cigarettes = { affinity = 2, trust = 1 },
    },
    DefaultValue = { affinity = 1, trust = 0 },
}
