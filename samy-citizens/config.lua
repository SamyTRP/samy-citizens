Config = {}

--[[ =====================================================================
    GENEL
===================================================================== ]]
Config.Locale = 'tr'                -- 'tr' | 'en'  (arayüz dili; NPC diyalogları data/dialogue.lua'dadır)
Config.Framework = 'auto'           -- 'auto' | 'qbx' | 'qb' | 'esx'   [DEĞİŞTİR: QBCore/ESX ise]
-- true: sunucu konsoluna ayrıntılı log + durum geçişleri; /citizensdebug üstündeki bilgiler zaten sadece açıkken çizilir.
-- false iken hiçbir debug thread'i çalışmaz.
Config.Debug = false

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
}

--[[ =====================================================================
    DİYALOG MOTORU (yapay zekâ yok; cümleler data/dialogue.lua)
===================================================================== ]]
Config.Dialogue = {
    MinScore = 1.0,                 -- niyet puanı bunun altındaysa "anlamadım" cevabı
    TypingDelayMs = { 600, 2200 },  -- cevap öncesi "düşünme" süresi (cevap uzunluğuna göre)
    AskBackChance = 0.6,            -- "Sen nasılsın?" gibi karşı soru olasılığı
    BusyMaxTurns = 3,               -- işteyken/yoldayken (arkadaş değilse) en fazla bu kadar cevap
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
        -- v3 niyetleri
        ask_dislike = { 1, 0 }, ask_activity = { 1, 0 }, ask_where = { 0, 0 }, ask_when = { 0, 0 },
        ask_relationship_status = { 0, 0 }, ask_date = { 0, 0 }, ask_stop = { 0, 0 }, ask_ride = { 0, 0 }, ask_go = { 0, 0 },
        ask_touch = { 0, 0 },
    },
    GoodConversationBonus = { 2, 1 }, -- en az 3 mesajlık, olumsuzluksuz konuşma sonunda
    FuzzyMatch = true,              -- küçük yazım hatalarını tolere et ("nasilsn", "tesekurler")
    SecondIntent = true,            -- tek cümlede iki soru varsa ikisine de cevap ver ("adın ne, ne iş yapıyorsun?")
    NpcQuestionChance = 0.22,       -- sakinin sohbeti sürdürmek için kendisinin soru sorma olasılığı (konuşkanlarda x1.7)
    FillerChance = 0.15,            -- "Valla", "Şey", "Hıh" gibi kişiliğe uygun dolgu sözcükleri
    FactRecallChance = 0.4,         -- tanıdık oyuncuyu karşılarken onun hakkında bildiklerinden bahsetme
    -- Dinamik cümle üretici (data/dialogue_life.lua > SCDialogue.Parts): cümleyi ön ek + gövde + son ek parçalarından
    -- kişilik, ilişki, ruh hâli ve ortama göre birleştirir.
    Generator = {
        Enabled = true,
        GreetingChance = 0.55,      -- konuşma başındaki selamın parçalardan üretilme olasılığı (kalanı klasik şablon)
        AwarenessChance = 0.6,      -- selama ortam gözlemi eklenme olasılığı (yağmur, yaralı oyuncu, silah...)
    },
    RecentHistorySize = 40,         -- NPC başına son kullanılan cümle hafızası (aynı cümleyi sürekli tekrarlamasın)
    RecentHistoryMinutes = 45,      -- bu kadar gerçek dakika sonra eski cümle tekrar kullanılabilir
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
    -- Kısa süreli konuşma bağlamı (RAM): son konu, önceki konular, son soru/cevap, oyuncuya karşı geçici ruh hâli.
    -- Veritabanına yazılmaz; süre dolunca temizlenir.
    ContextTTLMinutes = 20,
    ContextMaxTopics = 5,
    ContextCleanupSec = 60,
    -- İlişki istatistiklerinde (beraber gidilen yerler) tutulacak en fazla farklı yer
    TrackPlacesMax = 20,
    -- Aynı yere beraber gitme anısı en erken bu kadar gerçek saatte bir yazılır (DB şişmesin)
    PlaceMemoryCooldownHours = 12,
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

    --[[ İlişki aşaması hesabı
         'classic' : sadece yukarıdaki samimiyet/sevgi/güven eşikleri (eski davranış)
         'xp'      : sadece ilişki XP'si (aşağıdaki XP.Levels); soğuk/düşman yine sevgi puanından
         'hybrid'  : ikisinden YÜKSEK olan (varsayılan; güncellemede kimse aşama kaybetmez) ]]
    Mode = 'hybrid',
    -- Aşama adları (boş bırakılırsa locales dosyasındaki adlar kullanılır)
    Labels = {
        stranger = 'Yabancı', acquaintance = 'Tanıdık', friend = 'Arkadaş', close_friend = 'Yakın arkadaş',
        dating = 'Flört', partner = 'Sevgili', cold = 'Soğuk', enemy = 'Düşman',
    },
    XP = {
        Enabled = true,
        -- XP -> arkadaşlık aşaması (min değerler). Sırayla artan olmalı.
        Levels = {
            { id = 'stranger', min = 0 },
            { id = 'acquaintance', min = 100 },
            { id = 'friend', min = 300 },
            { id = 'close_friend', min = 700 },
        },
        DatingXP = 1200,            -- flört teklifinin kabul edilebilmesi için en az XP
        PartnerXP = 2000,           -- "sevgili/partner" için en az XP
        PartnerMinDates = 3,        -- partner olmak için en az bu kadar buluşma/beraber yer gezme
        MaxXP = 5000,
        DailyCap = 220,             -- günlük en fazla POZİTİF XP (spamla ilişki kurulamaz; negatifler sınırsız)
        -- Kaynak başına XP ve bekleme süresi (gerçek saniye). cooldown içinde tekrar eden kaynak XP vermez.
        Sources = {
            talk = { xp = 2, cooldown = 25 },               -- yüz yüze mesaj
            good_conversation = { xp = 12, cooldown = 900 },-- olumsuzluksuz, en az 3 mesajlık sohbet
            phone_chat = { xp = 1, cooldown = 90 },         -- SMS
            compliment = { xp = 6, cooldown = 300 },
            gift = { xp = 25, cooldown = 1800 },
            walk_minute = { xp = 3, cooldown = 55 },        -- beraber yürürken dakikada bir
            ride = { xp = 18, cooldown = 900 },             -- en az 1 dk süren araç yolculuğu
            visit_place = { xp = 25, cooldown = 1800 },     -- beraber bir yere gitmek
            date = { xp = 60, cooldown = 3600 },            -- randevuya gelmek / flörtle bir yere gitmek
            interaction = { xp = 8, cooldown = 300 },       -- sosyal animasyon (el sıkışma, sarılma...)
            intimate = { xp = 20, cooldown = 1800 },        -- yetişkin etkileşimi (sadece yetişkin NPC)
            insult = { xp = -25, cooldown = 0 },
            rude = { xp = -10, cooldown = 0 },              -- tersleme, kabalık
            threat = { xp = -120, cooldown = 0 },
            made_wait = { xp = -30, cooldown = 0 },         -- NPC'yi uzun süre bekletmek
            abandon = { xp = -35, cooldown = 0 },           -- NPC'yi yolda bırakıp gitmek
            missed_date = { xp = -60, cooldown = 0 },       -- buluşmaya gelmemek
        },
    },
    Romance = {
        Enabled = true,
        MinAge = 21,                -- romantik/flört sistemi sadece bu yaş ve üstü NPC'lerde
        RequireOpen = true,         -- profile.romance.open = false olan NPC flört teklifini her zaman reddeder
        JealousyRadius = 50.0,      -- flörtün, oyuncuyu başka bir NPC ile bu mesafede görürse kıskanır
        JealousyGossipChance = 0.004, -- (x kıskançlık puanı) başka NPC'yle vakit geçirdiğini dedikodudan duyma olasılığı
        BreakupAffinity = -30,      -- sevgi bu değerin altına düşerse flört/ilişki biter
    },
}

--[[ =====================================================================
    AKSİYONLAR
===================================================================== ]]
Config.Actions = {
    MinStage = {
        give_phone_number = 'acquaintance',
        create_appointment = 'friend',
        follow_player = 'close_friend',
    },
    FollowMaxMinutes = 5,           -- gerçek dakika
    AppointmentMaxDaysAhead = 3,    -- oyun/gerçek günü (TimeMode'a göre)
    AppointmentWaitMinutes = 30,    -- oyun dakikası: oyuncu gelmezse bekleme süresi
    AppointmentMeetMinutes = 90,    -- buluşma modu en fazla süre (oyun dk)
    AppointmentArriveDistance = 25.0,
    AppointmentMinGap = 90,         -- aynı sakinin randevuları arası en az oyun dk
    AppointmentReminderMinutes = 30,
    PoliceCooldownSec = 90,
}

--[[ =====================================================================
    TELEFON  (bridge/phone.lua)
    Provider:
      'auto'      : AutoDetect sırasına göre başlamış ilk telefon kaynağını seçer; hiçbiri yoksa 'builtin'
      'gksphone'  : gksphone v2 (iki yönlü SMS)
      'lb-phone'  : lb-phone (iki yönlü SMS)
      'npwd'      : NPWD (iki yönlü SMS)
      'qb-phone'  : qb-phone (NPC -> oyuncu e-posta; oyuncunun cevabı yerleşik /sakinmesaj ekranından)
      'custom'    : Config.Phone.Custom fonksiyonları
      'builtin'   : yerleşik mini mesajlaşma (/sakinmesaj)
      'none'      : telefon kapalı
===================================================================== ]]
Config.Phone = {
    Provider = 'auto',
    AutoDetect = { 'gksphone', 'lb-phone', 'npwd', 'qb-phone' },
    -- Tek yönlü sağlayıcılarda (qb-phone) ya da oyuncu telefonsuzken cevap için yerleşik ekran da açık kalsın
    BuiltinFallback = true,
    -- Provider = 'custom' ise SUNUCUDA çağrılır
    Custom = {
        -- npcNumber: sakinin numarası, playerNumber: oyuncunun numarası, text: mesaj, src: oyuncu (çevrimiçiyse)
        Send = function(npcNumber, playerNumber, text, src, npcName) return false end,
        -- oyuncunun telefon numarası
        GetNumber = function(src) return nil end,
    },
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
    ProactivePerDay = 1,            -- (klasik mod) yakın arkadaş NPC günde en fazla kaç kez kendiliğinden yazar
    ProactiveChancePerHour = 0.10,  -- boş zamanda oyun saati başına olasılık
    MaxPendingPerThread = 5,
    ThreadMemoryMinutes = 30,       -- SMS'teki yarım kalan konuşma (ör. buluşma saati) bu kadar gerçek dk hatırlanır
    --[[ Akıllı kendiliğinden mesaj (Smart = true ise klasik proaktif SMS yerine bu çalışır)
         Mesajın gelmesi rastgele değil: son görüşme, ilişki, kişilik, NPC'nin o anki programı (uyku/iş),
         oyun saati, gerçek saat ve ruh hâli birlikte değerlendirilir. ]]
    Proactive = {
        Smart = true,
        CheckEverySec = 20,         -- değerlendirme aralığı (NPC başına değil, toplam)
        GameHours = { 9, 23 },      -- NPC sadece bu oyun saatleri arasında yazar (uyuyorsa hiç yazmaz)
        RealQuietHours = { 2, 9 },  -- gerçek saatle bu aralıkta kimse yazmaz (Config.RealTimeUtcOffset'e göre)
        MinStage = 'acquaintance',  -- en az bu aşamadaki (ve numarası olan) oyunculara yazar
        MinIntervalHours = 3,       -- aynı oyuncuya iki kendiliğinden mesaj arası en az (gerçek saat)
        PerDay = { acquaintance = 1, friend = 1, close_friend = 2, dating = 3, partner = 3 },
        BaseChance = 0.02,          -- her değerlendirmede temel olasılık (sosyallik, romantiklik, özlem ile artar)
        MissAfterHours = 30,        -- bu kadar süredir görüşmediyse "Uzun süredir görmedim" türü mesaj
        AbsentAfterHours = 8,       -- "Bugün ortalarda yoksun" türü mesaj
        RecentFunHours = 20,        -- beraber gezme/buluşma bu kadar yeni ise "Dün güzel vakit geçirdik"
        InviteChance = 0.35,        -- mesaj bir davete dönüşme olasılığı (akşam, boş zaman)
    },
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
    Enabled = true,
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

--[[ #####################################################################
    YAŞAYAN NPC KATMANI (v3)
    Aşağıdaki bölümler kişilik, ilişki XP'si, beraber gezme, araç, etkileşim animasyonları,
    yetişkin NPC kategorisi, kendiliğinden konuşma/olaylar ve performans ayarlarıdır.
    Hiçbiri harici yapay zekâ kullanmaz; hepsi sunucuda deterministik kurallarla çalışır.
##################################################################### ]]

--[[ =====================================================================
    NPC KATEGORİLERİ
    Her sakinin profile.type alanı buradaki anahtarlardan biridir (yoksa 'citizen').
    rules: etkileşim kabul kuralları
      minStage : en az bu ilişki aşaması (stranger/acquaintance/friend/close_friend)
      bonus    : kabul puanına eklenen değer (kişilik + ruh hâli + ilişki + durumdan hesaplanan puana)
===================================================================== ]]
Config.NPCTypes = {
    citizen = {
        label = 'Sakin',
        rules = {
            follow = { minStage = 'acquaintance', bonus = 0 },   -- beraber yürü
            ride = { minStage = 'acquaintance', bonus = 0 },     -- arabama davet
            go = { minStage = 'friend', bonus = 0 },           -- beraber bir yere gitmek
            touch = { minStage = 'acquaintance', bonus = 0 },    -- el sıkışma, omuza dokunma, dans, fotoğraf
            romantic = { minStage = 'close_friend', bonus = 0 }, -- sarılma, öpme, romantik etkileşim
            phone = { minStage = 'acquaintance', bonus = 0 },
            date = { minStage = 'close_friend', bonus = 0 },     -- flört teklifi
        },
    },
    adult_entertainer = {
        label = 'Eğlence çalışanı',
        zone = 'VanillaUnicorn',
        rules = {
            follow = { minStage = 'stranger', bonus = 25 },
            ride = { minStage = 'stranger', bonus = 20 },
            go = { minStage = 'stranger', bonus = 15 },
            touch = { minStage = 'stranger', bonus = 20 },
            romantic = { minStage = 'acquaintance', bonus = 15 },
            phone = { minStage = 'stranger', bonus = 25 },
            date = { minStage = 'acquaintance', bonus = 10 },
            intimate = { minStage = 'stranger', bonus = 20 },    -- yetişkin etkileşimleri (Config.AdultNPC)
        },
    },
}

--[[ =====================================================================
    ZEKÂ / KİŞİLİK
    Her NPC'nin profile.stats değerleri (0-100): friendliness, humor, confidence, jealousy, patience,
    romantic, social, aggression. Tanımlı değilse kişilik özelliklerinden (traits) türetilir.
===================================================================== ]]
Config.Intelligence = {
    DefaultStats = { friendliness = 55, humor = 45, confidence = 55, jealousy = 30, patience = 55, romantic = 40, social = 55, aggression = 20 },
    DeriveFromTraits = true,        -- profile.stats yoksa traits'ten türet ('esprili' -> humor+, 'huysuz' -> friendliness-...)
    StatJitter = 8,                 -- türetilen değerlere sakin kimliğinden deterministik ± sapma (herkes farklı olsun)
    AcceptThreshold = 50,           -- teklif (takip, araç, buluşma, etkileşim) kabul puanı eşiği
    DecisionCooldownSec = 90,       -- aynı teklife verilen karar bu süre değişmez (ısrarla "evet" koparılamaz)
    HumorQuipChance = 0.35,         -- humor puanı yüksek NPC'nin cevabına espri ekleme olasılığı (x humor/100)
    FriendlinessGain = true,        -- friendliness yüksek NPC'lerde ilişki daha kolay artar
}

--[[ =====================================================================
    BERABER YÜRÜME / GEZME (companion)
===================================================================== ]]
Config.Follow = {
    Enabled = true,
    MaxMinutes = 30,                -- en uzun beraber gezme süresi (gerçek dk); dolunca NPC nazikçe ayrılır
    MaxCompanionsPerPlayer = 3,
    StartDistance = 6.0,            -- teklif için NPC'ye en fazla uzaklık
    -- oyuncuya göre konum (yan, ileri) metre; birden fazla NPC sırayla bunları kullanır
    Offsets = { { 1.1, -0.9 }, { -1.1, -0.9 }, { 0.0, -1.9 }, { 1.6, -2.2 } },
    StoppingRange = 1.4,            -- robot gibi yapışmasın: bu mesafede durur
    WalkSpeed = 1.0, JogSpeed = 2.0, RunSpeed = 3.0,
    JogPlayerSpeed = 2.4,           -- oyuncu bundan hızlıysa NPC hızlanır (m/s)
    RunPlayerSpeed = 4.8,           -- oyuncu bundan hızlıysa (koşuyorsa) NPC de koşar
    CatchUpDistance = 14.0,         -- bundan uzaksa koşarak yetişir
    IdleScenarioAfterSec = 20,      -- oyuncu durunca bu kadar sonra NPC bir bekleme animasyonuna geçer
    LostDistance = 160.0,           -- oyuncu (araçsız) bu kadar uzaklaşırsa takip biter
    WarpFailsafeDistance = 110.0,   -- SON ÇARE: oyuncu bu kadar uzak ve NPC ekranda değilse yakına alınır
    WaitMaxMinutes = 10,            -- "burada bekle" denince en fazla bekleme (gerçek dk)
    WaitPenaltyAfterMinutes = 5,    -- bundan uzun bekletilirse XP cezası (made_wait)
    LeaveForDutyMinutes = 30,       -- iş/ders gibi zorunlu bloğa bu kadar oyun dk kala izin ister
    LeftBehindDistance = 90.0,      -- araç doluyken ya da NPC binmeden oyuncu bu kadar uzaklaşırsa "terk" sayılır
    MenuCommand = 'sakinmenu',      -- yanındaki (araçtaki dahil) eşlikçi NPC ile etkileşim panelini açar
    MenuKey = 'F9',                 -- oyuncu GTA Ayarlar > Tuş Atamaları > FiveM'den değiştirebilir
}

--[[ =====================================================================
    ARAÇ
===================================================================== ]]
Config.Vehicle = {
    EnterTimeoutMs = 16000,         -- kapıya ulaşıp binme denemesi süresi
    EnterRetries = 3,               -- bu kadar başarısız denemeden sonra başka koltuk aranır
    WarpFailsafe = true,            -- SON ÇARE: tüm denemeler başarısızsa ve NPC kapının dibindeyse koltuğa yerleştir
    ExitTimeoutMs = 9000,
    InviteDistance = 12.0,          -- "Arabama davet et" için aracın oyuncuya en fazla uzaklığı
    AllowNpcDriver = true,          -- NPC kendi arabasıyla şoförlük yapabilsin
    NpcCarMaxDistance = 70.0,       -- NPC şoför olacaksa kendi arabası en fazla bu uzaklıkta olmalı
    DriveSpeed = 15.0,              -- m/sn
    DrivingStyle = 786603,          -- sakin sürüş
    ParkDistance = 24.0,            -- hedefe bu kadar kala park etmeye çalışır
    RideMinSeconds = 60,            -- XP için en kısa yolculuk
    SeatCacheSec = 3600,            -- model başına koltuk sayısı önbelleği
}

--[[ =====================================================================
    BERABER GİDİLECEK YERLER ("Bir Yere Git" menüsü)
    location : Sim konumu (data/locations.lua / admin paneli)
    types    : o tipteki en uygun (favori ya da en yakın) konum seçilir
===================================================================== ]]
Config.Destinations = {
    AllowWaypoint = true,           -- oyuncunun haritada işaretlediği nokta
    MaxDistance = 9000.0,
    ArriveRadius = 32.0,
    List = {
        { id = 'vanilla_unicorn', label = 'Vanilla Unicorn', location = 'vanilla_unicorn' },
        { id = 'vespucci_beach', label = 'Vespucci Plajı', location = 'vespucci_beach' },
        { id = 'del_perro_pier', label = 'Del Perro İskelesi', location = 'del_perro_pier' },
        { id = 'mirror_park', label = 'Mirror Park', location = 'mirror_park_lake' },
        { id = 'legion_square', label = 'Legion Meydanı', location = 'legion_square' },
        { id = 'restaurant', label = 'Bir restoran', types = { 'restaurant', 'fastfood' } },
        { id = 'bar', label = 'Bir bar', types = { 'bar' } },
        { id = 'cafe', label = 'Kahve içmeye', types = { 'cafe' } },
    },
    -- varılan konum tipine göre birlikte yapılan aktivite
    ActivityByType = {
        bar = 'drink', club = 'drink', cafe = 'coffee', restaurant = 'eat', fastfood = 'eat', beach = 'leisure',
        park = 'leisure', pier = 'leisure', gym = 'exercise', shop = 'shopping',
    },
}

--[[ =====================================================================
    GÜNLÜK RUTİN EKLERİ
    Rutin bloklarında 'alt' ile ağırlıklı alternatif kullanılabilir:
      { from = '18:00', to = '23:00', alt = { 'bar', 'restaurant', 'home' } }
      { from = '18:00', to = '23:00', alt = { { activity = 'drink', location = 'fav:bar', weight = 3 }, ... } }
    Sakine özel gün planı: profile.schedule = { ['5'] = { ...bloklar } }  (1 = Pazartesi; anahtar metin olmalı, JSON için)
===================================================================== ]]
Config.Schedule = {
    WanderMinutes = { 25, 60 },     -- 'wander' aktivitelerde (ör. entertain) NPC bu aralıkta başka noktaya yürür (oyun dk)
    AltTypeActivity = {             -- 'alt' kısaltmaları: konum tipi -> aktivite
        bar = 'drink', club = 'drink', restaurant = 'eat', fastfood = 'eat', cafe = 'coffee', home = 'home_idle',
        park = 'leisure', beach = 'leisure', gym = 'exercise', shop = 'shopping', pier = 'fish',
    },
}

--[[ =====================================================================
    SOSYAL ETKİLEŞİM ANİMASYONLARI (registry)
    player / npc : { dict, anim, flag } ya da { scenario }; false = o taraf animasyon oynatmaz
    offset       : NPC'nin oyuncuya göre hizalanacağı konum (front: ileri m, side: sağ m, heading: oyuncunun
                   yönüne eklenen açı). Karakterlerin iç içe girmemesi için değerleri animasyona göre ayarla.
    rule         : Config.NPCTypes[..].rules anahtarı (kabul kuralı)
    romance      : true ise sadece flört/sevgili ya da romantik kişilikli yakın arkadaş kabul eder
    loop         : true ise duration boyunca döngü (oyuncu iptal edebilir)
    swapByGender : oyuncu kadın ve NPC erkekse roller yer değiştirir
    special      : 'sit' -> yakındaki bank/sandalyeyi bulup yan yana oturur, yoksa yere oturur
===================================================================== ]]
Config.Animation = {
    AlignTimeoutMs = 6000,          -- NPC'nin hizalanma noktasına yürümesi için en fazla süre
    MaxDistance = 3.5,              -- etkileşim başlatmak için en fazla uzaklık
    MaxLoopSeconds = 30,
    CancelKey = 'X',                -- oyuncu döngülü etkileşimi bu tuşla bitirir
    Social = {
        handshake = {
            label = 'El sıkış', rule = 'touch', duration = 3500,
            offset = { front = 0.95, side = 0.0, heading = 180.0 },
            player = { dict = 'mp_ped_interaction', anim = 'handshake_guy_a', flag = 0 },
            npc = { dict = 'mp_ped_interaction', anim = 'handshake_guy_b', flag = 0 },
        },
        hug = {
            label = 'Sarıl', rule = 'touch', minStage = 'friend', duration = 4500,
            offset = { front = 1.1, side = 0.0, heading = 180.0 },
            player = { dict = 'mp_ped_interaction', anim = 'hugs_guy_a', flag = 0 },
            npc = { dict = 'mp_ped_interaction', anim = 'hugs_guy_b', flag = 0 },
        },
        cheek_kiss = {
            label = 'Yanaktan öp', rule = 'touch', minStage = 'close_friend', duration = 5000,
            offset = { front = 1.05, side = 0.0, heading = 180.0 },
            player = { dict = 'mp_ped_interaction', anim = 'kisses_guy_a', flag = 0 },
            npc = { dict = 'mp_ped_interaction', anim = 'kisses_guy_b', flag = 0 },
        },
        shoulder = {
            label = 'Omzuna dokun', rule = 'touch', duration = 2500,
            offset = { front = 0.75, side = 0.35, heading = 180.0 },
            player = { dict = 'mp_common', anim = 'givetake1_a', flag = 48 },
            npc = { dict = 'gestures@m@standing@casual', anim = 'gesture_nod_yes_soft', flag = 48 },
        },
        highfive = {
            label = 'Çak bir beşlik', rule = 'touch', duration = 2500,
            offset = { front = 0.9, side = 0.0, heading = 180.0 },
            player = { dict = 'mp_ped_interaction', anim = 'highfive_guy_a', flag = 0 },
            npc = { dict = 'mp_ped_interaction', anim = 'highfive_guy_b', flag = 0 },
        },
        sit = {
            label = 'Yan yana otur', rule = 'touch', special = 'sit', loop = true, duration = 30000,
            offset = { front = 0.0, side = 0.75, heading = 0.0 },
            player = { scenario = 'PROP_HUMAN_SEAT_BENCH' },
            npc = { scenario = 'PROP_HUMAN_SEAT_BENCH' },
            ground = { scenario = 'WORLD_HUMAN_PICNIC' },   -- yakında bank yoksa
        },
        dance = {
            label = 'Dans et', rule = 'touch', loop = true, duration = 20000,
            offset = { front = 1.3, side = 0.0, heading = 180.0 },
            player = { dict = 'anim@amb@nightclub@mini@dance@dance_solo@male@var_a@', anim = 'high_center', flag = 1,
                female = { dict = 'anim@amb@nightclub@mini@dance@dance_solo@female@var_a@', anim = 'high_center', flag = 1 } },
            npc = { dict = 'anim@amb@nightclub@mini@dance@dance_solo@male@var_a@', anim = 'high_center', flag = 1,
                female = { dict = 'anim@amb@nightclub@mini@dance@dance_solo@female@var_a@', anim = 'high_center', flag = 1 } },
        },
        drink = {
            label = 'Beraber içki iç', rule = 'touch', minStage = 'acquaintance', loop = true, duration = 25000,
            offset = { front = 1.2, side = 0.0, heading = 180.0 },
            player = { scenario = 'WORLD_HUMAN_DRINKING' },
            npc = { scenario = 'WORLD_HUMAN_DRINKING' },
        },
        photo = {
            label = 'Fotoğraf pozu', rule = 'touch', duration = 9000,
            offset = { front = 2.3, side = 0.0, heading = 180.0 },
            player = { scenario = 'WORLD_HUMAN_TOURIST_MOBILE' },
            npc = { dict = 'mp_player_int_upperpeace_sign', anim = 'mp_player_int_peace_sign', flag = 49 },
        },
        kiss = {
            label = 'Öp', rule = 'romantic', romance = true, duration = 9000, swapByGender = true,
            offset = { front = 0.08, side = 0.0, heading = 180.0 },
            player = { dict = 'hs3_ext-20', anim = 'cs_lestercrest_3_dual-20', flag = 0 },
            npc = { dict = 'hs3_ext-20', anim = 'csb_georginacheng_dual-20', flag = 0 },
        },
        embrace = {
            label = 'Romantik sarılma', rule = 'romantic', romance = true, loop = true, duration = 15000, swapByGender = true,
            offset = { front = 0.05, side = 0.0, heading = 180.0 },
            player = { dict = 'misscarsteal2chad_goodbye', anim = 'chad_armsaround_chad', flag = 1 },
            npc = { dict = 'misscarsteal2chad_goodbye', anim = 'chad_armsaround_girl', flag = 1 },
        },
    },
}

--[[ =====================================================================
    YETİŞKİN NPC ETKİLEŞİMLERİ
    - Sadece profile.adult = true, yaşı >= MinAge ve tipi AllowedTypes içinde olan NPC'lerde görünür.
    - Normal NPC'lerle tamamen ayrıdır; menüde ayrı kategori ("Yetişkin Etkileşimleri").
    - Her zaman oyuncu başlatır; NPC kişiliğine/ilişkiye/ruh hâline göre kabul eder ya da reddeder (rıza).
    - Enabled = false ile kategori, animasyonlar ve ilgili diyaloglar tamamen kapanır.
    - RequireAce = true ise sadece bu ace'e sahip oyuncular görür (ör. 18+ doğrulanmış oyuncu grubu).
===================================================================== ]]
Config.AdultNPC = {
    Enabled = true,
    MinAge = 21,
    AllowedTypes = { adult_entertainer = true },
    RequireAce = false,
    Ace = 'samycitizens.adult',
    PrivacyRadius = 20.0,           -- 'private' etkileşimlerde bu mesafede başka oyuncu varsa başlamaz
    FadeScreen = false,             -- true: özel anlarda ekran kararır (sadece metin görünür)
    MaxDurationSec = 45,
    ConsentCooldownSec = 120,       -- reddedilen teklif bu süre tekrar denenemez
    -- Animasyonları başka bir kaynaktan oynatmak için (ör. kendi emote/animasyon paketin).
    -- İstemcide çağrılır: function(role, def, ped, otherPed) return true (oynattıysa) end   role = 'player'|'npc'
    ExternalPlayer = nil,
}

-- Yetişkin NPC bölgeleri. Bu bölgelerdeki NPC'ler (profile.zone) normal dünya NPC'lerinden ayrı tutulur.
Config.AdultNPCZones = {
    VanillaUnicorn = {
        enabled = true,
        label = 'Vanilla Unicorn',
        center = vector3(116.5, -1291.5, 29.25),
        radius = 80.0,
        maxNPCs = 6,                -- bölgede aynı anda fiziksel en fazla yetişkin NPC
        location = 'vanilla_unicorn',
        -- direk dansı noktaları (yaklaşık; admin panelindeki konum noktalarına 'pole' etiketiyle de eklenebilir)
        poles = {
            vector4(112.60, -1286.76, 28.46, 30.0),
            vector4(104.18, -1293.94, 29.26, 300.0),
            vector4(102.24, -1290.54, 29.26, 240.0),
        },
    },
}

--[[ Yetişkin animasyon registry'si (Config.Animation.Social ile aynı alanlar +)
     zone       : true -> sadece yetişkin NPC bölgesi içinde
     vehicle    : true -> ikisi aynı araçta ve araç durmuşken (NPC yolcu koltuğunda)
     private    : true -> PrivacyRadius içinde başka oyuncu yokken
     npcFemale  : true -> sadece kadın model NPC'lerde
     pole       : true -> en yakın direk noktasında (NPC tek başına)
     lowVariant : alçak araçlarda (spor/süper) kullanılacak alternatif
     Varsayılanlar GTA V'nin kendi dosyalarındaki (striptiz kulübü ve araç içi) animasyonlardır. ]]
Config.AdultAnimations = {
    pole_dance = {
        label = 'Direk dansı izle', rule = 'intimate', zone = true, pole = true, npcFemale = true, loop = true, duration = 30000,
        player = false,
        npc = { dict = 'mini@strip_club@pole_dance@pole_dance1', anim = 'pd_dance_01', flag = 1 },
    },
    private_dance = {
        label = 'Özel dans', rule = 'intimate', zone = true, npcFemale = true, loop = true, duration = 30000, xp = 'intimate',
        offset = { front = 0.9, side = 0.0, heading = 180.0 },
        player = false,
        npc = { dict = 'mini@strip_club@private_dance@part1', anim = 'priv_dance_p1', flag = 1 },
    },
    private_dance_2 = {
        label = 'Özel dans (2)', rule = 'intimate', zone = true, npcFemale = true, loop = true, duration = 30000, xp = 'intimate',
        offset = { front = 0.9, side = 0.0, heading = 180.0 },
        player = false,
        npc = { dict = 'mini@strip_club@private_dance@part2', anim = 'priv_dance_p2', flag = 1 },
    },
    tease = {
        label = 'Flörtöz poz', rule = 'intimate', npcFemale = true, duration = 8000,
        offset = { front = 1.2, side = 0.0, heading = 180.0 },
        player = false,
        npc = { dict = 'mini@strip_club@idles@stripper', anim = 'stripper_idle_02', flag = 1 },
    },
    car_close = {
        label = 'Araçta yakınlaşma', rule = 'intimate', vehicle = true, private = true, npcFemale = true, loop = true,
        duration = 30000, xp = 'intimate', memory = true,
        player = { dict = 'mini@prostitutes@sexnorm_veh', anim = 'bj_loop_male', flag = 1 },
        npc = { dict = 'mini@prostitutes@sexnorm_veh', anim = 'bj_loop_prostitute', flag = 1 },
        lowVariant = {
            player = { dict = 'mini@prostitutes@sexlow_veh', anim = 'low_car_bj_loop_player', flag = 1 },
            npc = { dict = 'mini@prostitutes@sexlow_veh', anim = 'low_car_bj_loop_female', flag = 1 },
        },
    },
    car_intimate = {
        label = 'Araçta özel an', rule = 'intimate', vehicle = true, private = true, npcFemale = true, loop = true,
        duration = 35000, xp = 'intimate', memory = true, minStage = 'acquaintance',
        player = { dict = 'mini@prostitutes@sexnorm_veh', anim = 'sex_loop_male', flag = 1 },
        npc = { dict = 'mini@prostitutes@sexnorm_veh', anim = 'sex_loop_prostitute', flag = 1 },
        lowVariant = {
            player = { dict = 'mini@prostitutes@sexlow_veh', anim = 'low_car_sex_loop_player', flag = 1 },
            npc = { dict = 'mini@prostitutes@sexlow_veh', anim = 'low_car_sex_loop_female', flag = 1 },
        },
    },
}

--[[ =====================================================================
    KENDİLİĞİNDEN KONUŞMA
    Beraber yürürken/gezerken NPC arada bir kendisi konuşur (ortam, ruh hâli, ilişki, kişiliğe göre).
    Konuşma paneli açıkken oyuncu uzun süre susarsa NPC bir şey sorar (konuşma başına bir kez).
===================================================================== ]]
Config.AutoConversation = {
    enabled = true,
    minInterval = 120,              -- sn
    maxInterval = 420,              -- sn (sosyal NPC'ler aralığın başına, içe dönükler sonuna yakın konuşur)
    silenceSec = 70,
}

--[[ =====================================================================
    NPC OLAYLARI (spam korumalı)
    - Teklif: beraber gezerken kahve/sahil/bar/yürüyüş teklif eder; "olur" dersen birlikte gidersiniz
    - Yaklaşma: arkadaşın seni yakında görünce yanına gelip selam verir
    - Eve dönme: geç saatte ve yorgunsa eve gitmek ister
    - Telefon mesajları: Config.Phone.Proactive
===================================================================== ]]
Config.NPCEvents = {
    Enabled = true,
    ProposalTTL = 120,              -- sn: teklif bu süre geçerli (konuşma panelinde "olur" / "Teklifi kabul et")
    ProposeChance = 0.3,            -- kendiliğinden konuşma anlarında teklif olasılığı
    Cooldowns = { propose = 900, approach = 1800, go_home = 600 },   -- aynı NPC-oyuncu çifti için (sn)
    ApproachMinStage = 'friend',
    ApproachRadius = 18.0,
    ApproachChance = 0.08,          -- her kontrolde (15 sn)
    GoHomeHour = 23,                -- bu oyun saatinden sonra yorgunsa eve gitmek ister
    Types = {
        coffee = { types = { 'cafe' }, weight = 3, day = true },
        beach = { types = { 'beach' }, weight = 2, noRain = true, day = true },
        walk = { types = { 'park', 'pier' }, weight = 2, noRain = true },
        bar = { types = { 'bar' }, weight = 2, evening = true },
        eat = { types = { 'restaurant', 'fastfood' }, weight = 2 },
    },
}

--[[ =====================================================================
    DURUM MAKİNESİ
    NPC'nin tek bir merkezi durumu vardır; yüksek öncelikli durum düşük öncelikli olanı keser.
    Örn. TALKING (80) iken rutin (WORKING 30, GOING_HOME 40...) onu götüremez.
===================================================================== ]]
Config.StateMachine = {
    Priority = {
        HOSTAGE = 100, FLEEING = 95, INTIMATE_INTERACTION = 90, INTERACTING = 85, TALKING = 80,
        ENTERING_VEHICLE = 75, IN_VEHICLE = 74, DRIVING = 73, DATE = 70, FOLLOWING = 65, WAITING = 60,
        SOCIALIZING = 50, GOING_TO_WORK = 40, GOING_HOME = 40, WALKING = 35, WORKING = 30, SLEEPING = 20, IDLE = 10,
    },
    Publish = true,                 -- durum değişince ped statebag'ine (scState) yazılır; sadece değişimde, ağ yükü yok denecek kadar az
}

--[[ =====================================================================
    PERFORMANS / LOD
    0 - FullRadius        : tam simülasyon (ped var, görev 1 sn'de bir izlenir)
    FullRadius - Reduced  : azaltılmış simülasyon (ped var, görev ReducedMonitorMs'de bir izlenir)
    Reduced +             : sadece rutin (soyut katman, ped yok)
    FullRadius, Config.SpawnRadius'un yerine geçer.
    Not: OneSync'in varsayılan culling mesafesi ~424 m'dir; bunun ötesinde ped'in sahibi olan istemci kalmaz ve
    görev yürütülemez. Bu yüzden ReducedRadius'u 424'ün üstüne çıkarmak (ör. 500) işe yaramaz, sadece boşta
    bekleyen ağ varlığı tutar. Toplam ped sayısı her durumda Config.MaxSpawnedResidents ile sınırlıdır.
===================================================================== ]]
Config.Performance = {
    LOD = { FullRadius = 150.0, ReducedRadius = 400.0 },
    ReducedMonitorMs = 3000,
    SpawnVisibilityCheck = true,    -- oyuncunun gözü önünde (ekranda, yakında) aniden ped belirmesin
    SpawnDeferDistance = 90.0,
    SpawnDeferMax = 3,              -- en fazla bu kadar spawn turu ertelenir, sonra yine de oluşur
    CompanionTickMs = 1000,
    EventsTickMs = 5000,
    StartupSweep = true,            -- kaynak başlarken önceki çalışmadan kalmış sakin ped/araçlarını temizle
}
