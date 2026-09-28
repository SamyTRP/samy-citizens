--[[
    GÜNLÜK HAYAT DİYALOG VERİSİ (data/dialogue.lua'nın devamı)
    - Aşk / sevgili: teklif, "seni seviyorum", sarılma, öpücük, ayrılık, kıskançlık
    - Küfür / argo: düşmanca küfre karşılık verme, samimi arkadaşla "naber lan" şakalaşması
    - Komutlar: benimle gel, burada bekle, işaretli yere git, arabayla gezelim, polisi ara, dans et / otur...
    - Meslek hizmetleri: sipariş (barmen/garson/barista/aşçı), tedavi & sağlık tavsiyesi, araba tamiri
    - Sırlar: birden çok sır, oyuncunun sırrını saklama
    - Karşılıklı sohbet: sakinin sorduğu yeni sorular, cevaplara tepkiler, başından geçenleri anlatma
    Desen yazımı data/dialogue.lua başındaki açıklamayla aynıdır (katlanmış: küçük harf, Türkçe karakter yok).
]]
SCDialogue = SCDialogue or {}
local D = SCDialogue

local function addIntents(list)
    for _, i in ipairs(list) do D.Intents[#D.Intents + 1] = i end
end

local function addLines(t)
    for k, v in pairs(t) do D.Lines[k] = v end
end

-- =====================================================================
-- YENİ NİYETLER
-- =====================================================================
addIntents({
    -- ---------------- aşk ----------------
    { id = 'ask_out', weight = 1.7, exact = true, patterns = { 'sevgilim olur musun', 'sevgilim ol', 'sevgili olalim', 'sevgili olal', 'benimle cikar misin', 'benimle cik', 'cikalim mi', 'beraber olalim', 'beraber olal', 'birlikte olalim', 'iliski yasayalim', 'bana bir sans ver', 'benimle sevgili', 'kiz arkadasim olur', 'erkek arkadasim olur', 'sevgilim olmak ister', 'benimle olur musun', 'evlenelim', 'benimle evlen' } },
    { id = 'love_you', weight = 1.5, exact = true, patterns = { 'seni seviyorum', 'seni cok seviyorum', 'sana asigim', 'sana asik oldum', 'asik oldum sana', 'senden hoslaniyorum', 'hoslaniyorum senden', 'kalbimi caldin', 'seni sevdim', 'sana vuruldum', 'aklim sende' } },
    { id = 'breakup', weight = 1.8, exact = true, patterns = { 'ayrilalim', 'ayriliyoruz', 'senden ayril', 'bitti aramizda', 'aramizda her sey bitti', 'artik sevgili degiliz', 'seni terk', 'iliskimiz bitti', 'bitirelim bu isi', 'bu iliski bitti', 'seninle bitti' } },
    { id = 'hug', weight = 1.4, patterns = { 'sarilalim', 'sarilabilir miyim', 'saril bana', 'gel sarilayim', 'kucaklayayim', 'bir sarilayim', 'sarilmak istiyorum', 'kucakla beni', 'sarilsana' } },
    { id = 'kiss', weight = 1.4, exact = true, patterns = { 'opebilir miyim', 'opeyim', 'opucuk ver', 'bir opucuk', 'opucuk', 'opusmek', 'opusel', 'opsene', 'opeyim mi', 'yanagindan' } },
    { id = 'high_five', weight = 1.3, patterns = { 'cak bir besli', 'cak besli', '=cak', 'bir besli', 'tokalasalim', 'elini sikayim', 'el sikisalim', 'yumruk tokusturalim', 'kafa tokusturalim' } },

    -- ---------------- küfür ----------------
    { id = 'swear', weight = 1.9, exact = true, patterns = { '=amk', '=aq', '=amq', 'amina', 'amcik', 'orospu', 'orosbu', '=pic', 'pic kurusu', 'sikerim', 'sikeyim', 'siktir', 'siktirgit', 'sikik', '=sikim', 'yarrak', '=yarak', 'gavat', 'kahpe', '=anani', 'anani sik', 'ananin ami', 'pezevenk', 'kaltak', 'surtuk', 'godos', 'amina koy', 'aminakoy', '=fuck', 'fucking', 'motherfucker', '=bitch', 'asshole', '=shit', '=dick' } },

    -- ---------------- komutlar ----------------
    { id = 'cmd_wait', weight = 1.4, patterns = { 'burada bekle', 'burda bekle', 'beni bekle', 'bekle burada', 'bekle beni', '=bekle', 'burada kal', 'kal burada', 'burdan ayrilma', 'buradan ayrilma', 'dur burada', 'oldugun yerde kal', 'yerinden kipirdama' } },
    { id = 'cmd_go_home', weight = 1.3, patterns = { 'evine git', 'eve git', 'evine don', 'isine don', 'isine git', 'git dinlen', 'artik gidebilirsin', 'gidebilirsin', 'serbestsin', 'takip etmeyi birak', 'beni takip etme', 'pesimi birak', 'pesimden ayril', 'yeter bu kadar', 'hadi sen git', 'sen git artik' } },
    { id = 'cmd_goto', weight = 1.6, patterns = { 'isaretledigim yere', 'isaretli yere', 'haritadaki yere', 'haritada isaretledigim', 'isaretledigim konuma', 'isaretli konuma', 'haritadaki noktaya', 'isarete git', 'konuma git', 'waypoint', 'suraya git', 'oraya git', 'gps', 'haritadaki yer', 'isaretledigim noktaya', 'haritada gosterdigim' } },
    { id = 'cmd_ride', weight = 1.5, patterns = { 'arabanla gezelim', 'arabayla gezelim', 'beni gezdir', 'tur atalim', 'bir tur atalim', 'arabana binelim', 'arabanla gidelim', 'beni gotur', 'beni oraya gotur', 'beni birakir misin', 'arabayla birak', 'gezmeye cikalim', 'arabanla beni', 'arabaya binelim', 'arabani al gel', 'bizi gotur', 'arabayla gidelim', 'arabayla tur' } },
    { id = 'cmd_report', weight = 1.6, patterns = { 'polisi ara', 'polise haber ver', 'polise sikayet', 'sikayet et', 'ihbar et', 'polis cagir', '=911', '=155', 'polise bildir', 'polisleri ara', 'polis cagirir misin', 'polise haber', 'jandarmayi ara', 'sikayetci ol' } },
    { id = 'cmd_perform', weight = 1.3, patterns = { 'dans et', 'dans edelim', 'oyna bakalim', 'gobek at', '=otur', 'oturalim', 'biraz oturalim', 'otursana', 'biraz otur', 'sigara yak', 'sigara ic', 'bir sigara icelim', 'sinav cek', 'mekik cek', 'yoga yap', 'gitar cal', 'muzik yap', 'alkisla', 'tezahurat', 'fotograf cek', 'resim cek', 'kaslarini goster', 'isinma yap', 'kos biraz', 'durbun', 'telefonla konus', 'kadeh kaldir', 'serefe', 'yaslan', 'egzersiz yap', 'spor yap biraz', 'guneslen', 'gunes banyosu' } },

    -- ---------------- meslek hizmetleri ----------------
    { id = 'order', weight = 1.4, patterns = { 'bir bira', 'bira ver', 'bira alabilir', 'bira alayim', 'icki ver', 'bir icki', 'icecek', 'bir kahve', 'kahve ver', 'kahve alabilir', 'kahve alayim', 'bir cay', 'cay ver', 'su ver', 'bir su', 'siparis', 'bir hamburger', 'hamburger ver', 'yemek ver', 'yemek alabilir', 'bir viski', 'viski', 'votka', 'sarap', 'kokteyl', 'bir duble', 'doldur', 'sandvic', 'tost', 'donut', 'latte', 'espresso', 'cappuccino', 'bir tane ver', 'patates', 'pizza', 'tekila', 'mojito', 'bir shot' } },
    { id = 'ask_menu', weight = 1.3, patterns = { 'menu', 'neler var', 'ne var icecek', 'ne alabilirim', 'fiyatlar', 'ne satiyorsun', 'ne ikram', 'icecek ne var', 'yiyecek ne var', 'ne onerirsin icmek' } },
    { id = 'ask_heal', weight = 1.6, patterns = { 'iyilestir', 'tedavi et', 'yaraliyim', 'yaralandim', 'kaniyorum', 'kan kaybed', 'bana bakar misin', 'pansuman', 'ilk yardim yap', 'vuruldum', 'bicaklandim', 'sargi', 'yaram var', 'kurtar beni', 'yarami sar', 'yarama bak', 'dikis at', 'muayene et', 'beni muayene' } },
    { id = 'ask_health', weight = 1.3, patterns = { 'basim agriyor', 'bas agrisi', 'midem', 'karnim agriyor', '=ates', 'atesim', 'atesim var', '=grip', 'gribim', 'nezle', 'oksuruk', 'oksuruyorum', 'bogazim', 'dis agrisi', 'disim agriyor', 'uyuyamiyorum', 'uykusuzluk', 'sirtim agriyor', 'belim agriyor', 'yandim', 'yanik', 'elimi kestim', 'kesik', 'bilegim burkuldu', 'burkuldu', 'ayagim burkuldu', 'tansiyon', 'sekerim', 'alerji', 'mide bulanti', 'midem bulaniyor', 'kustum', 'ishal', 'stresliyim cok', 'panik atak', 'nefes alamiyorum', 'hasta gibiyim', 'kendimi iyi hissetmiyorum', 'ne ilac', 'hangi ilac', 'ilac oner' } },
    { id = 'ask_repair', weight = 1.5, patterns = { 'arabami tamir', 'tamir et', 'arabam bozuldu', 'araba bozuk', 'arabaya bakar misin', 'arabama bakar misin', 'arabami yap', 'lastik patladi', 'lastigim', 'aku bitti', 'akum', 'frenler', 'fren tutmuyor', 'kaporta', 'arabam calismiyor', 'mars basmiyor', 'marsa basmiyor', 'motor ses', 'motordan ses', 'yag degis', 'arabam duman', 'hararet' } },
    { id = 'ask_expertise', weight = 1.2, patterns = { 'isinle ilgili', 'meslegin hakkinda', 'meslegini anlat', 'bir tavsiye ver', 'tavsiyen var mi', 'isin puf', 'bana ogret', 'ne bilmeliyim', 'isinden bahset', 'isini anlat', 'meslek sirri', 'is tavsiyesi', 'bu isin sirri' } },

    -- ---------------- sırlar ----------------
    { id = 'player_secret', weight = 1.5, patterns = { 'sana bir sir', 'sir vereyim', 'bir sirrim var', 'kimse bilmiyor ama', 'itiraf edeyim', 'bir itirafim var', 'sana bir sey itiraf', 'kimseye soylemedigim', 'sadece sana soyluyorum' } },
    { id = 'ask_more_secret', weight = 1.3, patterns = { 'baska sirrin', 'baska bir sir', 'bir sir daha', 'baska neler sakliyorsun', 'baska ne biliyorsun', 'daha fazla sir' } },
})

-- ask_remember'a ek ifadeler ("beni tanır mısın?")
for _, i in ipairs(D.Intents) do
    if i.id == 'ask_remember' then
        for _, p in ipairs({ 'beni tanir', 'beni biliyor musun', 'daha once gorustuk', 'daha once tanistik', 'daha once karsilastik', 'tanistik mi', 'biz tanisiyor muyuz', 'beni hatirlamiyor', 'kim oldugumu biliyor', 'ben kimim', 'beni gordun mu' }) do
            i.patterns[#i.patterns + 1] = p
        end
    elseif i.id == 'flirt' then
        -- teklif / itiraf artık ayrı niyetler (ask_out, love_you)
        local keep = {}
        local moved = { ['sevgili olal'] = true, ['cikalim mi'] = true, ['benimle cik'] = true, ['evlenel'] = true, ['hoslaniyorum'] = true,
            ['asigim'] = true, ['asik oldum'] = true, ['seni seviyorum'] = true, ['beraber olal'] = true, ['kalbimi caldin'] = true }
        for _, p in ipairs(i.patterns) do if not moved[p] then keep[#keep + 1] = p end end
        for _, p in ipairs({ 'cok tatlisin', 'gulusun', 'gulumsemen', 'cok cekicisin', 'yakisikli olmussun', 'guzel olmussun', 'bu aksam cok guzel', 'kalp atisim' }) do keep[#keep + 1] = p end
        i.patterns = keep
    elseif i.id == 'propose_meet' then
        for _, p in ipairs({ 'icmeye gidel', 'yemeye gidel', 'kahve icmeye', 'yemek yemeye', 'bir seyler yiyel', 'hadi gidelim', 'simdi gidelim', 'gidelim mi', 'takilmaya gidel', 'bara gidel', 'kafeye gidel', 'sahile gidel', 'parka gidel' }) do
            i.patterns[#i.patterns + 1] = p
        end
    elseif i.id == 'ask_follow' then
        for _, p in ipairs({ 'hadi gel', 'gel hadi', 'yanimda gel', 'benle takil', 'bana katil' }) do i.patterns[#i.patterns + 1] = p end
    end
end

-- Sabit görev noktasındaki sakin
D.Doing.guard = { 'Görev başındayım, burayı ben bekliyorum.', 'Nöbetteyim, gözüm her yerde.', 'Burada görevliyim, bir şey mi lazım?' }
D.PlanPhrase.guard = { plain = 'görev başında olurum', loc = '%loc% tarafında görevde olurum' }

-- Konuşma özeti konu adları
D.Topics.ask_out = 'birlikte olmaktan'
D.Topics.love_you = 'duygularımızdan'
D.Topics.order = 'siparişinden'
D.Topics.ask_heal = 'yarandan'
D.Topics.ask_health = 'sağlığından'
D.Topics.ask_repair = 'arabandan'
D.Topics.ask_expertise = 'işimin inceliklerinden'
D.Topics.job_q = 'işimle ilgili sorulardan'
D.Topics.player_secret = 'senin sırrından'
D.Topics.ask_more_secret = 'sırlardan'
D.Topics.cmd_ride = 'araba gezmesinden'
D.Topics.player_dream = 'senin hayallerinden'
D.Topics.player_family = 'senin ailenden'

-- Oyuncunun duygu durumu / olay kodları (ruh hâli sebebi)
D.ReasonMe.cursed = 'Biri bana küfretti, sinirim tepemde.'
D.ReasonMe.became_lover = 'Aşık oldum galiba, içim kıpır kıpır.'
D.ReasonMe.broke_up = 'Ayrıldık... hiç iyi değilim.'
D.ReasonMe.cheated = 'Aldatıldım. Başka bir şey sorma.'
D.ReasonMe.helped_heal = 'Bugün birine yardım ettim, iyi hissettiriyor.'

-- =====================================================================
-- CEVAP ŞABLONLARI
-- =====================================================================
addLines({
    -- -------------------------------------------------------------- tanıma
    ask_remember = {
        convo = { 'Tabii hatırlıyorum! %ago% %loc% civarında konuşmuştuk, %topics% bahsetmiştik.', 'Unutur muyum! %ago% %loc% civarında sohbet etmiştik; %topics% bahsetmiştik.', 'Hatırlamaz mıyım? %ago% %topics% konuşmuştuk.' },
        convo_nosum = { 'Tabii hatırlıyorum, %ago% konuşmuştuk.', 'Hatırlıyorum tabii, en son %ago% görüşmüştük.' },
        talked = { 'Tabii tanıyorum, daha önce konuşmuştuk.', 'Tanımaz olur muyum, konuşmuştuk ya seninle.' },
        just_met = { 'Az önce tanıştık ya, daha öncesinden tanımıyorum.', 'Şu an konuşuyoruz işte... ama öncesinden tanıştığımızı sanmıyorum.' },
        seen = { 'Seni buralarda gördüm galiba ama hiç konuşmadık.', 'Yüzün tanıdık geliyor ama hiç konuştuğumuzu hatırlamıyorum.' },
        heard = { 'Tanışmadık ama hakkında bir şeyler duydum.', 'Yüz yüze tanışmadık, ama birileri senden bahsetmişti.' },
        stranger = { 'Hayır, daha önce tanıştığımızı sanmıyorum.', 'Tanışıyor muyuz? Hatırlamıyorum.', 'Yok, seni ilk kez görüyorum.', 'Kusura bakma, çıkaramadım. Tanışıyor muyuz?' },
        vague = { 'Yüzün tanıdık geliyor ama tam çıkaramadım.', 'Hmm... bir yerden tanıyorum ama nereden?' },
        fact_job = { 'Sen %fact_job% değil miydin?', '%fact_job% olarak çalışıyordun, değil mi?' },
        fact_like = { 'Hatta bana neyi sevdiğini de söylemiştin: %fact_like%.' },
        lover = { 'Seni tanımaz mıyım hiç? Sen benim sevgilimsin!', 'Ne biçim soru bu? Seni unutur muyum hiç?' },
    },

    -- -------------------------------------------------------------- aşk
    ask_out = {
        accept = { 'Ben de... ben de bunu çok istiyordum. Evet!', 'Sonunda söyledin! Evet, tabii ki evet!', 'Kalbim duracak sandım... Evet, olalım.', 'Uzun zamandır bekliyordum bunu. Evet!' },
        already = { 'Zaten sevgiliyiz, unuttun mu?', 'Biz zaten birlikteyiz ya, şapşal!' },
        taken = { 'Bunu duymak güzel ama... benim hayatımda biri var.', 'Kusura bakma, evliyim. Biliyorsun.', 'Olmaz, benim bir ilişkim var.' },
        cold = { 'Rüyanda görürsün.', 'Seninle mi? Asla.', 'Güldürme beni.' },
        stranger = { 'Daha adını bile doğru dürüst bilmiyorum!', 'Biraz hızlı gitmiyor musun?', 'Seni tanımıyorum bile, ne sevgilisi?' },
        known = { 'Daha yeni tanışıyoruz, biraz erken değil mi?', 'Hmm... önce birbirimizi biraz tanıyalım.', 'Bilmiyorum, sana o gözle bakmadım hiç.' },
        friendzone = { 'Seni çok seviyorum ama... arkadaş olarak.', 'Aramızdaki arkadaşlığı bozmak istemem.', 'Bilmiyorum... biraz zaman ver bana, düşüneyim.' },
        soon = { 'Belki... biraz daha zaman ver bana.', 'Kalbim evet diyor ama aklım biraz bekle diyor.', 'Bana biraz daha kendini göster, olur mu?' },
        ex = { 'Daha yeni ayrıldık, bu kadar çabuk olmaz.', 'Önce geçenleri unutmam lazım.' },
        jealous = { 'Sen %other% ile birlikte değil misin? Duydum ben!', 'Önce %other% ile aranı düzelt, sonra gel.' },
        disabled = { 'Güzel bir teklif ama... hayır, kusura bakma.' },
    },
    love_you = {
        lover = { 'Ben de seni seviyorum, hem de çok.', 'Ben daha çok seviyorum!', 'Seni seviyorum, bunu hiç unutma.', 'Bunu her duyduğumda içim eriyor.' },
        close = { 'Ciddi misin? Ben de... sana karşı bir şeyler hissediyorum.', 'Of, yüzüm kızardı şimdi. Ben de seni çok seviyorum ama bilmiyorum...' },
        friend = { 'Ben de seni seviyorum, iyi bir dostsun.', 'Aa, çok tatlısın. Ben de seni seviyorum... arkadaş olarak.' },
        known = { 'Hmm, bunu nasıl karşılayacağımı bilemedim.', 'Daha birbirimizi yeni tanıyoruz ama.' },
        stranger = { 'Ne? Beni tanımıyorsun bile!', 'Pardon... ne?' },
        cold = { 'Ben senden nefret ediyorum, bilgin olsun.', 'Hıh.' },
    },
    breakup = {
        lover = { 'Ne?! Neden?! ...Peki. Madem öyle istiyorsun.', 'Bunu bana nasıl yaparsın? Git o zaman!', 'Kalbimi kırdın... Güle güle.', 'Anlıyorum... Umarım mutlu olursun.' },
        none = { 'Zaten sevgili değiliz ki.', 'Neyden ayrılıyoruz, anlamadım?' },
    },
    hug = {
        lover = { 'Gel buraya... Seni özlemiştim.', 'Sarıl bana sıkıca, bırakma.', 'Kokunu özlemişim.' },
        friend = { 'Gel bakalım, sarılalım!', 'Ooo, gel buraya dostum!', 'Hadi gel, kucaklaşalım.' },
        known = { 'Hehe, tamam, kısa bir tane.', 'Biraz garip ama olsun, gel.' },
        stranger = { 'Ee... tanımadığım biriyle sarılmam.', 'Pardon, biraz mesafe lütfen.' },
        cold = { 'Dokunma bana.', 'Uzak dur.' },
    },
    kiss = {
        lover = { 'Gel buraya... Mmh.', 'Tabii ki, sevgilim.', 'Bir tane değil, iki tane!' },
        close = { 'Yanağından olur, fazlası değil!', 'Hey hey, yavaş! Yanaktan bir tane, o kadar.' },
        friend = { 'Hop hop! Arkadaşız biz.', 'Yok artık, ciddi misin?' },
        known = { 'Ne? Olmaz!', 'Sen iyice şımardın.' },
        stranger = { 'Ne yapıyorsun sen?! Uzak dur!', 'Deli misin sen?' },
        cold = { 'Sana tokat atarım bak!', 'Defol.' },
    },
    high_five = {
        friend = { 'Çak bakalım!', 'Hehe, işte bu!', 'Ver elini!' },
        known = { 'Tamam, çak!', 'Olur, al bakalım.' },
        stranger = { 'Hıh... tamam, çak.', 'Ee, olur.' },
        cold = { 'Hayır.', 'Elini indir.' },
    },
    greet_lover = { default = { 'Aşkım! Gel buraya!', 'Canım benim, geldin mi?', 'Sevgilim! Tam da seni düşünüyordum.', 'Hayatım! Seni görünce günüm güzelleşti.', 'Kalbimin sahibi gelmiş!' } },
    goodbye_lover = { default = { 'Görüşürüz aşkım, kendine iyi bak.', 'Hemen özleyeceğim seni.', 'Git ama çabuk dön, tamam mı?', 'Seni seviyorum, yazarsın.' } },
    ambient_lover = { default = { 'Aşkım!', 'Canım, nereye?', 'Hey sevgilim!', 'Bir öpücük vermeden mi gidiyorsun?' } },
    lover_extra = { default = { 'Seni görünce daha iyi oldum.', 'Ama seninle konuşunca her şey düzeliyor.', 'Seni düşünüyordum bu arada.' } },
    cheated = { default = { 'Beni aldattın! %other% ile olduğunu duydum!', 'Duydum her şeyi. %other%... Nasıl yaparsın bunu bana?', 'Bitti! %other% ile mutlu ol sen!' } },

    -- -------------------------------------------------------------- küfür / argo
    swear_back = {
        default = { 'Sensin o lan!', 'Ağzını topla lan!', 'Kime küfrediyorsun sen?!', 'Adam gibi konuş yoksa fena olur!', 'Ağzından çıkanı kulağın duysun!', 'Terbiyesiz, defol git!' },
        grumpy = { 'Siktir git lan başımdan!', 'Sensin o, hıyar!', 'Bana bak, ağzını yüzünü kırarım!', 'Lan terbiyesiz, kimsin sen?!' },
        warm = { 'Vay vay, ağzı bozuk çıktı bu!', 'Lan ayıp be, ne oluyor?!', 'Sana ne yaptım da küfrediyorsun?' },
        shy = { 'N-neden küfrediyorsun ki...', 'Böyle konuşma benimle lütfen...', 'Ben sana ne yaptım?' },
        formal = { 'Lütfen ağzınızı toparlayın!', 'Böyle bir üslupla konuşmam.', 'Terbiyesizliğin bu kadarı!' },
        friend = { 'Oha, bana mı küfrettin sen şimdi?!', 'Lan ne oluyor, niye küfrediyorsun bana?', 'Ayıp oluyor ama, arkadaşız biz!' },
        cold = { 'Senin gibisine ancak bu yakışır.', 'Defol git lan!', 'Sen kendine bak önce!' },
    },
    swear_leave = { default = { 'Yeter! Seninle konuşmuyorum artık.', 'Siktir git, konuşmayacağım seninle.', 'Git başkasına küfret, ben gidiyorum.' }, shy = { 'Ben... gidiyorum.' }, formal = { 'Bu konuşma burada bitmiştir.' } },
    banter = {
        argo = { 'Naber lan, iyidir senden?', 'Ooo yarrak kafa, nerelerdesin lan?', 'Lan sen hâlâ yaşıyor musun? İyiyim be, sen?', 'Hah, geldi bizim hıyar! Naber?', 'Eyvallah lan, sen nasılsın?', 'Amk bugün öyle yorgunum ki... Sen napıyon?', 'Lan ne oldu sana, güzel güzel konuşuyordun!' },
        default = { 'Hahaha, ağzın bozulmuş bugün! İyiyim, sen?', 'Lan diye diye... İyiyim be, sen?', 'Seninle ağzımız bozuldu iyice, haha!' },
        shy = { 'Ağzını bozma ya... İyiyim, sen?', 'Hehe... sen de amma konuşuyorsun.' },
        lover = { 'Terbiyesiz! ...Ama seni yine de seviyorum.', 'Sevgiline böyle mi konuşulur? Hadi gel buraya.' },
    },
    greet_banter = { default = { 'Naber lan yarrak!', 'Oo kimler gelmiş, naber lan?', 'Lan nerelerdesin sen, kayboldun!', 'Hah, bizim hıyar geldi! Naber lan?', 'Ooo, geldi bizim eşek! Naber?' } },
    goodbye_banter = { default = { 'Hadi eyvallah lan!', 'Hadi siktir git! Şaka şaka, kendine iyi bak.', 'Görüşürüz lan, kaybolma!', 'Hadi yallah, görüşürüz!' } },

    -- -------------------------------------------------------------- komutlar
    cmd_refuse = {
        stranger = { 'Seni tanımıyorum bile, neden yapayım?', 'Pardon, sen kimsin ki?', 'Tanımadığım birinin dediğini yapmam.' },
        known = { 'Bunu senin için yapacak kadar yakın değiliz.', 'Kusura bakma, şimdi olmaz.', 'Hmm, yok. Başka zaman belki.' },
        cold = { 'Sana mı uyacağım? Hayal kur.', 'Hayır.', 'Sen kim oluyorsun da bana emir veriyorsun?' },
        busy = { 'İşteyim şu an, yapamam.', 'Mesaideyim, patron görürse yandım.', 'Şu an olmaz, iş başındayım.' },
        sms = { 'Bunu mesajla yapamam ki, yanıma gel.', 'Yanımda olsan olur, mesajla olmaz.' },
        mood = { 'Hiç havamda değilim, kusura bakma.', 'Bugün olmaz, kafam çok dolu.' },
        busy_task = { 'Zaten bir işin ortasındayım.', 'Az önce bir şey dedin ya, onu yapıyorum.' },
    },
    cmd_follow = {
        yes = { 'Olur, biraz takılayım seninle.', 'Tamam, düş önüme!', 'Hadi bakalım, peşindeyim.', 'Nereye gidiyoruz? Tamam, geliyorum.' },
        lover = { 'Seninle her yere gelirim.', 'Sen nereye ben oraya.' },
    },
    cmd_wait = {
        yes = { 'Tamam, burada bekliyorum.', 'Peki, buradayım. Çok bekletme ama.', 'Tamam, bir yere ayrılmıyorum.', 'Bekliyorum, hadi çabuk ol.' },
    },
    cmd_go_home = {
        yes = { 'Tamam, ben işime döneyim o zaman.', 'Peki, görüşürüz sonra.', 'Hadi ben kaçtım.', 'Tamam, kendi işime bakayım.' },
        none = { 'Zaten bir yere gitmiyordum ki.', 'Tamam da, zaten buradayım.' },
    },
    cmd_goto = {
        yes = { 'Tamam, işaretlediğin yere gidiyorum. Orada beklerim.', 'Oraya mı? Peki, gidiyorum.', 'Anlaştık, orada buluşuruz.' },
        drive = { 'Arabamla giderim, orada görüşürüz.', 'Uzakmış, arabayla gidiyorum. Orada beklerim.' },
        taxi = { 'Uzakmış, taksiyle giderim. Orada beklerim.', 'Yürüyerek olmaz oraya, taksi tutarım.' },
        nowp = { 'Haritada bir yer işaretlemedin ki.', 'Neresi? Haritana bir işaret koy da göreyim.', 'Nereye gideyim, bir yer işaretle önce.' },
    },
    cmd_ride = {
        yes = { 'Olur, atla arabaya!', 'Tamam, benim araba şurada. Hadi bin!', 'Biraz tur atalım o zaman, bin bakalım.' },
        dest = { 'Tamam, seni oraya bırakırım. Bin hadi.', 'Oraya mı? Bin, götüreyim.', 'Olur, işaretlediğin yere götürürüm.' },
        nocar = { 'Arabam yok ki.', 'Arabam yok, yürüyoruz mecburen.' },
        far = { 'Arabam burada değil, başka zaman.', 'Arabam evde kaldı, şimdi olmaz.' },
        stolen = { 'Arabamı çaldılar, hatırlasana!' },
    },
    ride_offer = { default = { 'Arabam şurada, biraz tur atalım mı?', 'Hadi arabayla bir tur atalım, ne dersin?', 'Canım sıkıldı, arabayla biraz dolaşalım mı?' } },
    ride_wait = { default = { 'Hadi binsene!', 'Bekliyorum, atla!', 'Kapı açık, gel hadi.' } },
    ride_arrived = { default = { 'Geldik işte!', 'Buyur, vardık.', 'İşte burası. Güzel yolculuktu.' } },
    ride_end = { default = { 'Hadi ben burada ineyim, tur güzeldi.', 'Yeter bu kadar gezdiğimiz, benzin de pahalı!', 'Güzel turdu, yine yaparız.' } },
    ride_chat = { default = { 'Şu müziği aç bakalım.', 'Bu şehir geceleri başka güzel, değil mi?', 'Emniyet kemerini tak bu arada!', 'Şu trafiğe bak ya...', 'Camı açayım mı, hava güzel.' } },
    cmd_report = {
        yes = { 'Tamam, hemen polisi arıyorum!', 'Arıyorum, sakin ol. Polis yolda.', 'Tamam, ihbar ediyorum.', 'Hemen arıyorum, sen de dikkatli ol!' },
        cooldown = { 'Az önce aradım ya, yoldalar.', 'Aradım zaten, gelmek üzereler.' },
    },
    cmd_perform = {
        dance = { 'Hadi bakalım, dans!', 'Müzik yok ama olsun!', 'İzle ve öğren!' },
        sit = { 'Oh, biraz oturalım.', 'İyi fikir, ayaklarım koptu.' },
        smoke = { 'Bir tane yakayım o zaman.', 'Tamam, bir sigara molası.' },
        drink = { 'Şerefe!', 'Kadehler havaya!' },
        pushups = { 'Şınav mı? Bak şimdi!', 'Say bakalım kaç tane çekeceğim!' },
        situps = { 'Mekik mi? Tamam, hadi.' },
        yoga = { 'Nefes al, nefes ver...', 'Yoga iyi gelir, bak.' },
        music = { 'Bir şarkı patlatayım o zaman!', 'Dinle bakalım.' },
        cheer = { 'Yaşasın! Hadi be!', 'Ooo, bravo!' },
        photo = { 'Gülümse! Çekiyorum.', 'Dur bir fotoğraf çekeyim.' },
        flex = { 'Bak şu kaslara!', 'Spor yapmak işe yarıyormuş, değil mi?' },
        jog = { 'Isınıyorum, sonra koşarım.', 'Biraz hareket iyi gelir.' },
        phone = { 'Dur bir telefon edeyim.', 'Bir arayayım şunu.' },
        binoculars = { 'Bakalım neler var uzakta...' },
        lean = { 'Şöyle bir yaslanayım.' },
        sunbathe = { 'Oh, güneş ne güzel.' },
        default = { 'Tamam!', 'Peki, bak.' },
        shy = { 'Utanırım ben, herkes bakıyor...', 'Burada mı? Olmaz, utanırım.' },
    },
    cmd_outing = {
        yes = { 'Olur, hadi %loc% tarafına gidelim! Haritana işaretledim.', 'Tamam, %loc%. Orada buluşalım, işaretledim.', 'Harika fikir! %loc%, önden gidiyorum.' },
    },

    -- -------------------------------------------------------------- meslek hizmetleri
    order = {
        served = { 'Buyur, %item% hazır. Afiyet olsun!', 'Al bakalım, %item%. %price_text%', 'Hemen hazırlıyorum... İşte %item%.', 'Senin için özel hazırladım: %item%. %price_text%' },
        ask = { 'Ne alırsın? Elimizde %menu% var.', 'Buyur, ne istersin? %menu%.', 'Söyle bakalım: %menu%?' },
        notwork = { 'Şu an mesaide değilim, dükkâna gel, hazırlarım.', 'İşte değilim şimdi, tezgâha geçince hallederiz.' },
        nomoney = { 'Kusura bakma, hesap %price%. Üstünde yok galiba.', 'Paran yetmiyor, %price% lazım.' },
        noservice = { 'Ben %job% olarak çalışıyorum, öyle bir şey satmıyorum ki.', 'Yanlış kişiye sordun, ben satış yapmıyorum.' },
        cooldown = { 'Dur bir nefes al, az önce aldın!', 'Yavaş ol biraz, daha yeni verdim.' },
        unknown = { 'Ondan yok bizde. %menu% var.', 'Onu bulamazsın burada, %menu% var ama.' },
        full = { 'Çantanda yer yok, sonra gel.', 'Taşıyamazsın bu kadar, üstün dolu.' },
    },
    ask_menu = {
        default = { 'Elimizde %menu% var.', 'Bak şimdi: %menu%. Hangisi?' },
        none = { 'Ben bir şey satmıyorum ki, %job% olarak çalışıyorum.' },
    },
    heal = {
        done = { 'Tamam, yaranı temizledim ve sardım. Birkaç gün dinlen.', 'Pansumanı yaptım. Bol su iç, yarayı ıslatma.', 'Kanamayı durdurdum. Yine de hastaneye bir uğra.', 'Bitti, iyisin artık. Bir dahaki sefere dikkat et.' },
        start = { 'Dur, bir bakayım... Kıpırdama.', 'Otur şöyle, yarana bakayım.', 'Göster bakalım neren yaralı.' },
        healthy = { 'Bir şeyin yok ki, gayet iyi görünüyorsun.', 'Nabzın normal, rengin yerinde. İyisin.', 'Sende bir şey göremiyorum, bir şikâyetin mi var?' },
        offduty = { 'Mesaide değilim ama ilk yardım yapayım... Şimdilik idare eder, hastaneye git.', 'Çantam yanımda değil ama elimden geleni yapayım.' },
        notwork = { 'Şu an mesaide değilim, malzemem de yok. Hemen hastaneye git, orada bakarlar.', 'Nöbette değilim ama... Pillbox\'a git, acil servis açık.' },
        notmedic = { 'Ben doktor değilim ki! Hemen hastaneye git.', 'Bu iş için bir doktora görünmelisin, Pillbox Hastanesi en yakını.', 'Ben anlamam bu işlerden, ambulans çağırayım mı?' },
        cooldown = { 'Az önce baktım ya, biraz dinlen.', 'Yarayı rahat bırak, iyileşmesi zaman alır.' },
        nomoney = { 'Tedavi %price%, ücretsiz değil maalesef.' },
    },
    repair = {
        start = { 'Dur bir bakayım... Kaputu aç bakalım.', 'Getir şöyle, bir bakalım neyi var.', 'Tamam, bakıyorum. Beş dakikaya hallederiz.' },
        done = { 'Tamam, çalışır hâle getirdim. Bir süre idare eder.', 'Oldu bu iş. Ama yağını da değiştir bir ara.', 'Bitti. Motor tıkır tıkır.' },
        novehicle = { 'Hangi araba? Yakında araba göremiyorum.', 'Arabanı yanıma getir de bakayım.' },
        notmech = { 'Ben tamirci değilim ki, bir tamirciye götür.', 'Arabadan anlamam, Benny\'s\'e götür derim.' },
        offduty = { 'Mesaide değilim ama madem arkadaşsın, bakarım.' },
        cooldown = { 'Az önce baktım ya, bir sorun olursa getir.' },
        nomoney = { 'İşçilik %price%, bedava olmaz.' },
    },
    ask_expertise = {
        default = { '%tip%', 'Bak sana bir şey söyleyeyim: %tip%', 'Yıllardır bu işteyim, şunu öğrendim: %tip%' },
        none = { 'Benim işimde öyle büyük sırlar yok, çalışıyorsun işte.', 'Ne diyeyim, her işin zorluğu var.' },
    },
    job_q_other = { default = { 'Bundan pek anlamam, bunu bir %cat% sor.', 'Valla ben %job% olarak çalışıyorum, o konuyu bir %cat% sor.', 'Hiç bilmem, bir %cat% sorsan daha iyi.' } },
    health_general = { default = { 'Bence bir doktora görün, şakaya gelmez.', 'Bol su iç, dinlen. Geçmezse doktora git.', 'Annem olsa ıhlamur iç derdi, ama sen yine de doktora görün.' } },

    -- -------------------------------------------------------------- sırlar
    ask_secret = {
        friend = { 'Aramızda kalsın ama... %text%', 'Sana güveniyorum, o yüzden söylüyorum: %text%', 'Kimseye söyleme ama... %text%' },
        more = { 'Bir tane daha mı? Peki... %text%', 'Madem öyle, bir şey daha söyleyeyim: %text%', 'Bunu kimseye anlatmadım ama... %text%' },
        lover = { 'Senden sır mı saklayacağım? %text%', 'Sana her şeyi anlatırım, biliyorsun: %text%' },
        none_left = { 'Sana bildiğim her şeyi anlattım artık.', 'Başka sırrım kalmadı, valla.', 'Hepsini biliyorsun artık, benden bu kadar.' },
        not_yet = { 'Sana güveniyorum ama... bunu henüz kimseye söyleyemem.', 'Bir gün anlatırım, şimdi değil.' },
        default = { 'Sırlarımı herkesle paylaşmam.', 'Önce biraz daha tanışalım, sonra belki.', 'Sır dediğin söylenmez ki!' },
        cold = { 'Sana mı anlatacağım? Rüyanda görürsün.' },
        empty = { 'Pek sırrım yok aslında, açık kitabım.' },
    },
    player_secret = {
        ask = { 'Söyle, kimseye söylemem.', 'Dinliyorum, aramızda kalacak.', 'Anlat bakalım, merak ettim.' },
        stored = { 'Sırrın bende güvende, merak etme.', 'Vay... Tamam, bu aramızda kalacak.', 'Bunu bana anlattığın için teşekkürler. Kimse duymayacak.' },
        cold = { 'Bana sır verme, saklamam.' },
        stranger = { 'Beni tanımıyorsun bile, neden bana anlatıyorsun?' },
    },

    -- -------------------------------------------------------------- karşılıklı sohbet
    player_dream = { default = { 'Güzel hayal! Umarım gerçekleşir.', 'Bence yaparsın, vazgeçme!', 'Vay, iddialı! Hayalsiz yaşanmaz zaten.' } },
    player_family = { default = { 'Ailen önemli, kıymetini bil.', 'Anlıyorum... Aile her şey demek.', 'Güzel, onlara selamımı söyle.' } },
    player_food = { default = { '%fact_food% mı? Ben de bayılırım!', 'Hmm, güzel seçim. Şimdi canım çekti.', 'Zevkine diyecek yok.' } },
    player_music = { default = { 'Güzel zevk! Bir ara bana da dinlet.', 'Oo, sen de mi? Güzel!', 'Hiç dinlemedim ama merak ettim şimdi.' } },
    player_pet = { default = { 'Ne tatlı! Adı ne?', 'Hayvanlar insanlardan iyidir bence.', 'Bir gün tanıştır bizi!' } },
    player_city = { default = { 'Bence de, bu şehrin iyisi de kötüsü de var.', 'Anlıyorum seni. Ben de bazen öyle düşünüyorum.' } },
    busy_later = { default = { 'Mesaim %shift_end% gibi bitiyor, sonra uzun uzun konuşuruz.', 'Şimdi işteyim, sonra uğrasana.', 'Patron bakıyor, sonra konuşalım. Ama gitme, merak ettim.' } },
    nudge = {
        default = { 'Sessizleştin, bir şey mi düşünüyorsun?', 'Ee, anlat bakalım, sende ne var ne yok?', 'Hâlâ burada mısın?', 'Bir şey mi oldu? Dalıp gittin.' },
        friend = { 'Hey, dalıp gittin! Neyin var?', 'Söylesene, ne düşünüyorsun?', 'Ee? Bir şey anlatacaktın galiba.' },
        cold = { 'Bir şey diyeceksen de, yoksa gidiyorum.', 'Ne bakıyorsun öyle?' },
    },
    story_react = { default = { 'Hayat işte...', 'Neyse, öyle bir şey oldu.' } },
})

-- Sevgiliye özel kovalar (Dialogue.Bucket önce 'lover' anahtarına bakar)
local function addSub(key, sub, lines)
    D.Lines[key] = D.Lines[key] or {}
    D.Lines[key][sub] = lines
end
addSub('greet', 'lover', D.Lines.greet_lover.default)
addSub('goodbye', 'lover', D.Lines.goodbye_lover.default)
addSub('miss_you', 'lover', { 'Ben seni daha çok özledim aşkım!', 'Gözümde tütüyordun!', 'Bir daha bu kadar uzun kaybolma.' })
addSub('compliment', 'lover', { 'Sen benim gözümde hep en güzelisin.', 'Bunu sen söyleyince bir başka oluyor.', 'Seninle olunca kendimi güzel hissediyorum.' })
addSub('flirt', 'lover', { 'Hehe, sen de az değilsin sevgilim.', 'Utandırma beni burada!', 'Akşama görüşelim mi, ne dersin?' })
addSub('thanks', 'lover', { 'Senin için her şey, aşkım.', 'Teşekküre gerek yok, sevgilim.' })
addSub('ask_opinion_me', 'lover', { 'Seni seviyorum, daha ne diyeyim?', 'Sen benim hayatımın en güzel şeysin.' })
addSub('ask_follow', 'lover', D.Lines.cmd_follow.lover)
addSub('greet_absence', 'lover', { 'Aşkım! Neredeydin bu kadar zaman? Çok özledim!', 'Sonunda geldin! Beni merak içinde bıraktın.' })

-- Suçlama & hatırlama
D.Accuse.cursed = { 'Geçen sefer bana küfreden sendin, unutmadım!', 'Ağzını bozan adam yine geldi... Ne var?' }
D.Accuse.cheated = { 'Beni aldatan sen değil misin? Ne yüzle geldin?', 'Beni aldattın, unuttun mu? Uzak dur!' }
D.Accuse.broke_up = { 'Benden ayrılan sendin. Ne istiyorsun şimdi?', 'Beni bırakıp gittin, hatırlıyor musun?' }
D.GossipAccuse.cursed = { '%other% anlattı, ona ağza alınmayacak laflar etmişsin.' }
D.GossipAccuse.became_lover = { '%other% ile birlikteymişsin, duydum. Hayırlı olsun!' }
D.GossipAccuse.broke_up = { '%other% ile ayrılmışsınız, duydum. Çok üzülmüş.' }
D.GossipAccuse.cheated = { '%other% anlattı, onu aldatmışsın. Ayıp.' }
D.Recall.became_lover = { 'Hâlâ inanamıyorum, biz sevgiliyiz!', 'Seninle olmak çok güzel.' }
D.Recall.helped_heal = { 'Geçen sefer yarana baktım, iyileşti mi?' }
D.Recall.shared_secret = { 'Geçen sana anlattığım şey... aramızda, değil mi?' }

-- =====================================================================
-- SAKİNİN SORDUĞU EK SORULAR (karşılıklı sohbet)
-- =====================================================================
for _, q in ipairs({
    { kind = 'dream', fact = 'dream', minStage = 'acquaintance', lines = { 'Senin bir hayalin var mı?', 'Hayatta en çok ne yapmak istersin?', 'Beş yıl sonra kendini nerede görüyorsun?' } },
    { kind = 'family', fact = 'family', minStage = 'acquaintance', lines = { 'Senin ailen burada mı?', 'Senin kardeşin var mı?', 'Evli misin, yoksa bekâr mı?' } },
    { kind = 'food', fact = 'food', lines = { 'Sen en çok ne yemeyi seversin?', 'Senin favori yemeğin ne?' } },
    { kind = 'music', fact = 'music', lines = { 'Sen ne tür müzik dinlersin?', 'Son zamanlarda ne dinliyorsun?' } },
    { kind = 'pet', fact = 'pet', minStage = 'acquaintance', lines = { 'Senin evcil hayvanın var mı?', 'Kedi mi köpek mi, sen hangisisin?' } },
    { kind = 'city', fact = 'city', lines = { 'Bu şehri seviyor musun?', 'Los Santos\'ta yaşamak nasıl sence?' } },
}) do
    D.NpcQuestions[#D.NpcQuestions + 1] = q
end

D.Suggestions.answer.dream = { 'Kendi işimi kurmak', 'Bilmiyorum' }
D.Suggestions.answer.family = { 'Ailem uzakta', 'Bekârım' }
D.Suggestions.answer.food = { 'Hamburger severim' }
D.Suggestions.answer.music = { 'Rap dinlerim', 'Rock severim' }
D.Suggestions.answer.pet = { 'Bir kedim var', 'Yok' }
D.Suggestions.answer.city = { 'Seviyorum', 'Çok tehlikeli' }
D.Suggestions.answer.ride = { 'Olur, bin!', 'Başka zaman' }
D.Suggestions.answer.player_secret = { 'Kimseye söyleme ama...' }
D.Suggestions.answer.order = { 'Bira', 'Kahve', 'Su' }
D.Suggestions.friend_cmds = { 'Benimle gel', 'Burada bekle', 'Haritada işaretlediğim yere git', 'Arabanla gezelim' }
D.Suggestions.lover = { 'Seni seviyorum', 'Sarılalım' }
D.Suggestions.service = {
    drinks = { 'Menüde ne var?', 'Bir bira alabilir miyim?' },
    coffee = { 'Bir kahve alabilir miyim?', 'Menüde ne var?' },
    food = { 'Menüde ne var?', 'Bir hamburger alayım' },
    medical = { 'Yaralıyım, bakar mısın?', 'Başım ağrıyor, ne yapmalıyım?' },
    mechanic = { 'Arabamı tamir eder misin?' },
    default = { 'İşinle ilgili bir tavsiye ver' },
}

-- Oyuncunun cevaplarından öğrenilenleri sonraki karşılaşmada hatırlama
D.FactRecall.dream = { 'Hayalin için bir adım attın mı? %fact_dream% demiştin.' }
D.FactRecall.food = { 'Hâlâ %fact_food% yiyor musun her gün?' }
D.FactRecall.music = { 'Yine %fact_music% mı dinliyorsun?' }
D.FactRecall.pet = { 'Bizim minik dost nasıl?' }

-- =====================================================================
-- SAKİNİN KENDİLİĞİNDEN ANLATTIKLARI (hikâyeler)
-- =====================================================================
D.Stories = {
    'Geçen gün markette kasadaki kadın bana "sizi bir yerden tanıyorum" dedi, yarım saat sohbet ettik, meğer tanımıyormuş.',
    'Dün gece rüyamda uçtuğumu gördüm, sabah kalkınca bir süre kendime gelemedim.',
    'Sabah otobüsü kaçırdım, yirmi dakika yürüdüm. Spor olsun dedim.',
    'Komşumun kedisi yine bizim balkona girmiş, sabah karşımda buldum.',
    'Geçenlerde yolda cüzdan buldum, sahibine ulaştırdım. Adam çok sevindi, içim rahatladı.',
    'Bu hafta kirayı ödedim, cebimde üç kuruş kaldı. Neyse, hayat devam ediyor.',
    'Dün plajda gün batımını izledim, uzun zamandır bu kadar huzurlu hissetmemiştim.',
    'Telefonum dün yere düştü, ekran paramparça. Yenisine para yok şimdi.',
    'Geçen gün bir turist bana yol sordu, ben de yanlış tarif ettim galiba. Hâlâ vicdan azabı çekiyorum.',
    'Annem aradı, "ne zaman evleneceksin" diye yine başladı. Her telefonda aynı soru!',
    'Dün trafikte bir adam öyle bir sollama yaptı ki kalbim ağzıma geldi.',
    'Bu sabah kahveyi üstüme döktüm, tüm gün lekeli gömlekle gezdim.',
}

D.Followups.story = {
    really = { 'Valla gerçek, yemin ederim!', 'Evet, ben de inanamadım.' },
    why = { 'Bilmem, hayat işte, böyle şeyler hep beni bulur.', 'Şans herhalde, ne diyeyim.' },
    tell_more = { 'Başka pek bir şey yok, öyle kaldı.', 'Sonra da güldük geçtik işte.' },
    sympathy = { 'Sağ ol, olur öyle şeyler.', 'Neyse, geçti gitti.' },
    impressed = { 'Değil mi? Ben de şaşırdım.' },
    ack = { 'Hayat işte...', 'Öyle işte.' },
    me_too = { 'Senin de başına geldi mi? Demek herkes yaşıyor.' },
    agree = { 'Değil mi? Aynen öyle.' },
}
D.Suggestions.followup.story = { 'Gerçekten mi?', 'Hahaha!', 'Başka?' }
D.Suggestions.followup.ride = { 'Müziği aç', 'Biraz daha hızlı' }
