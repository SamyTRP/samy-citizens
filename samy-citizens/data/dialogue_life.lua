--[[
    v3 DİYALOG VERİSİ — yaşayan NPC katmanı (yapay zekâ yok)

    1) Yeni niyetler SCDialogue.Intents listesine eklenir. Desen yazımı data/dialogue.lua ile aynıdır, ek olarak
       KELİME KOMBİNASYONU desteklenir: { 'grup1', 'grup2' } -> her grup cümlede (herhangi bir sırada) bulunmalı;
       grup içinde '|' ile alternatif kelimeler yazılır.  Örn: { 'ad|isim', 'ne|nedir|soyle' }
    2) SCDialogue.Canonical: motorun iç niyet adları -> standart niyet adları (GET_NAME, ASK_FOLLOW ...).
       Debug ekranında ve exports['samy-citizens']:AnalyzeIntent(text) sonucunda kullanılır.
    3) SCDialogue.Parts: dinamik cümle üretici parçaları. Her anahtar sıralı "slot"lardan oluşur; her slotta
       koşullu girdiler bulunur, uygun olanlardan ağırlıklı seçim yapılır ve parçalar birleştirilir:
           { chance = 0.7, list = { { w = 2, when = { group = 'friend' }, lines = { ... } }, ... } }
       when koşulları: tone (warm|formal|grumpy|shy|neutral), group (stranger|known|friend|cold), romance (true/false),
       mood ({ 'happy', 'tired' ...}), stat ({ humor = 60 } en az), statMax ({ confidence = 40 } en fazla),
       time ('morning'|'day'|'evening'|'night'), rain (true/false), type (NPC kategorisi), adult (true)
       Daha çok koşulu tutan girdi daha çok tercih edilir. Aynı NPC son kullandığı cümleleri bir süre tekrar etmez.
    Yer tutucular data/dialogue.lua ile aynı + %place% (bulunulan yer) %dest% %likes1% %dislike1% %mood% %xp_level%
]]
SCDialogue = SCDialogue or {}
SCDialogue.Intents = SCDialogue.Intents or {}
SCDialogue.Lines = SCDialogue.Lines or {}

local NEW_INTENTS = {
    { id = 'ask_where', weight = 1.3, patterns = { 'burasi neresi', 'neresi burasi', 'neredeyiz', 'nerdeyiz', 'su an neredeyiz', 'hangi semtteyiz', 'hangi bolgedeyiz', 'burasi hangi', { 'nere', 'simdi|suan' }, 'konumun ne', 'neredesin su an', 'su an neredesin' } },
    { id = 'ask_when', weight = 1.35, patterns = { '=kacta', '=kacda', 'saat kacta', 'kacta gid', 'kacta cik', 'kacta basl', 'kacta bit', 'kacta gel', 'ne zaman gid', 'ne zaman cik', 'ne zaman basl', 'ne zaman bit', 'ne zaman gel', 'hangi saatte' } },
    { id = 'ask_relationship_status', weight = 1.45, patterns = { 'sevgilin var', 'sevgilin mi var', 'iliskin var', 'biriyle cikiyor', 'kalbinde biri', 'flortun var', 'bekar misin', 'bosta misin', 'hayatinda biri', { 'sevgili', 'var mi|varmi|yok mu' } } },
    { id = 'ask_date', weight = 1.6, patterns = { 'sevgilim olur', 'sevgilim ol', 'benimle cikar', 'benimle ciksana', 'bir iliski', 'ciddi bir iliski', 'birlikte olalim', 'beraber olalim', 'benimle birlikte ol', 'benim ol', 'flort edelim', 'iliskiye basla', 'sevgili olalim', { 'sevgili', 'olalim|olur musun|olsana' } } },
    { id = 'ask_stop', weight = 1.3, patterns = { '=dur', 'burada bekle', 'burda bekle', '=bekle', 'beni bekle', 'takip etme', 'pesimden gelme', 'gelme artik', 'gidebilirsin', 'eve git', 'isine don', 'yeter bu kadar', 'ayrilalim', 'burada kal', 'burda kal', 'sen git', 'birak artik' } },
    { id = 'ask_ride', weight = 1.45, patterns = { 'arabama bin', 'arabaya bin', 'atla arabaya', 'gel arabaya', 'seni birakayim', 'seni goturayim', 'seni gotureyim', 'arabayla gidelim', 'arabamla gidelim', 'binsene', 'bin hadi', 'seni bir yere birakayim', 'arabaya gel' } },
    { id = 'ask_go', weight = 1.4, requires = { 'place' }, patterns = { 'gidelim', 'goturur musun', 'gotur beni', 'beni gotur', 'gidiyoruz', '=haydi', '=hadi', 'birlikte gidelim', 'beraber gidelim', 'takilalim', 'uzanalim', 'gecelim' } },
    { id = 'ask_dislike', weight = 1.3, patterns = { 'neyi sevmezsin', 'nelerden nefret', 'nefret ettigin', 'sevmedigin', 'hoslanmadigin', 'neden hoslanmazsin', 'sinir oldugun', 'tahammul edemedigin', 'seni ne kizdirir', 'neyden nefret', 'nelerden hoslanmazsin', 'sinirini bozan', 'neyi sevmiyorsun' } },
    { id = 'ask_activity', weight = 1.25, patterns = { 'ne yapalim', 'bir sey yapalim', 'bir seyler yapalim', 'ne yapsak', 'bir yere gidelim mi', 'canin ne istiyor', 'nereye gidelim', 'ne yapmak istersin', 'eglenelim', 'nereye gitsek', 'canim sikildi ne yapalim' } },
    { id = 'ask_touch', weight = 1.35, patterns = { 'sarilalim', 'sarilabilir miyim', 'sarilir misin', 'opebilir miyim', 'opucuk ver', 'bir opucuk', 'el sikisalim', 'elini sikayim', 'dans edelim', 'dans eder misin', 'dans et benimle', 'cak bir bes', 'beslik cak', 'fotograf cekilelim', 'fotograf cekelim', '=selfie', 'biraz oturalim', 'oturalim mi', 'beraber icelim' } },
    { id = 'ask_us', weight = 1.25, patterns = { 'biz neyiz', 'aramizda ne var', 'bizim durumumuz', 'bizim aramizda', 'ne tur bir iliski', 'benim icin ne hissediyorsun', 'beni ne kadar seviyorsun', 'aramiz nasil' } },
}
for _, it in ipairs(NEW_INTENTS) do SCDialogue.Intents[#SCDialogue.Intents + 1] = it end

-- "Benimle gel" niyetine eklenen yeni ifadeler (mevcut niyet genişletilir)
for _, it in ipairs(SCDialogue.Intents) do
    if it.id == 'ask_follow' then
        for _, p in ipairs({ 'beraber yuruyelim', 'birlikte yuruyelim', 'yuruyelim mi', 'gel gidelim', 'devam edelim', 'hadi gel', { 'benle|benimle', 'yuru|gel|takil' } }) do
            it.patterns[#it.patterns + 1] = p
        end
    elseif it.id == 'ask_name' then
        for _, p in ipairs({ 'hitap edeyim', { 'sana|size', 'ne diye|nasil' , 'hitap|seslen' } }) do
            it.patterns[#it.patterns + 1] = p
        end
    end
end

-- =====================================================================
-- STANDART NİYET ADLARI
-- =====================================================================
SCDialogue.Canonical = {
    ask_name = 'GET_NAME', ask_age = 'GET_AGE', ask_job = 'GET_JOB', ask_where = 'GET_LOCATION', ask_home = 'ASK_HOME',
    ask_relationship_status = 'GET_RELATIONSHIP', ask_family = 'GET_RELATIONSHIP', how_are_you = 'GET_MOOD', ask_feeling = 'GET_MOOD',
    ask_time = 'GET_TIME', ask_weather = 'GET_WEATHER', ask_opinion_me = 'GET_PLAYER_RELATIONSHIP', ask_us = 'GET_PLAYER_RELATIONSHIP',
    ask_follow = 'ASK_FOLLOW', ask_stop = 'ASK_STOP', ask_date = 'ASK_DATE', flirt = 'ASK_DATE', propose_meet = 'ASK_DATE',
    ask_ride = 'ASK_VEHICLE', ask_car = 'ASK_VEHICLE', ask_phone = 'ASK_PHONE', ask_favorite_place = 'ASK_FAVORITE',
    ask_hobby = 'ASK_FAVORITE', ask_food = 'ASK_FAVORITE', ask_music = 'ASK_FAVORITE', ask_dislike = 'ASK_DISLIKE',
    ask_activity = 'ASK_ACTIVITY', ask_doing = 'ASK_ACTIVITY', ask_go = 'ASK_GO_LOCATION', ask_directions = 'ASK_GO_LOCATION',
    greet = 'GREETING', goodbye = 'GOODBYE', compliment = 'COMPLIMENT', insult = 'INSULT', ask_joke = 'JOKE', laugh = 'JOKE',
    apology = 'APOLOGY', ask_when = 'GET_TIME', ask_touch = 'ASK_INTERACTION', threat = 'THREAT', thanks = 'THANKS',
}

-- "Dokunma" isteğindeki anahtar kelime -> etkileşim (Config.Animation.Social)
SCDialogue.TouchWords = {
    { 'saril', 'hug' }, { 'opucuk', 'cheek_kiss' }, { 'opeb', 'kiss' }, { 'el sik', 'handshake' }, { 'elini sik', 'handshake' },
    { 'dans', 'dance' }, { 'bes', 'highfive' }, { 'fotograf', 'photo' }, { 'selfie', 'photo' }, { 'otur', 'sit' }, { 'icel', 'drink' },
}

-- =====================================================================
-- YENİ CEVAP ŞABLONLARI (kova seçimi data/dialogue.lua ile aynı)
-- =====================================================================
local lines = {
    where_here = {
        default = { 'Şu an %place% civarındayız.', '%place% tarafındayız, bilmiyor muydun?', 'Burası %place% civarı.' },
        unknown = { 'Tam bilmiyorum açıkçası, şehrin bu tarafına pek gelmem.', 'Bilmem, bir yerlerdeyiz işte.' },
    },
    where_me = {
        default = { 'Şu an %here% tarafındayım.', '%here% civarındayım, %doing_short%.' },
        commute = { 'Yoldayım, %dest% tarafına gidiyorum.', '%dest% tarafına gidiyorum şu an.' },
        home = { 'Evdeyim.', 'Evdeyim, biraz dinleniyorum.' },
        cold = { 'Seni ilgilendirmez.' },
    },
    when_work = {
        default = { 'Genelde %shift_start% gibi işte olurum, %shift_end% civarı çıkarım.', 'Mesaim %shift_start% - %shift_end% arası.', '%shift_start%\'da başlıyorum, %shift_end% gibi biter.' },
        none = { 'Düzenli bir mesaim yok aslında.', 'Belli bir saatim yok, günüme göre değişiyor.' },
        cold = { 'Sana ne benim mesaimden.' },
    },
    when_plan = { default = { '%when% gibi, %plan%.', 'Muhtemelen %when%. %plan_cap%.' } },
    when_unknown = { default = { 'Ne için soruyorsun, neyin saati?', 'Kaçta derken? Neyi soruyorsun?', 'Hangi şeyin saatini soruyorsun?' } },
    rel_status = {
        you = { 'Var tabii, karşımda duruyor.', 'Bunu gerçekten soruyor musun? Sensin tabii.', 'Sensin işte, başka kim olacak?' },
        single_flirty = { 'Yok, bekarım... Neden sordun bakalım?', 'Şu an kimse yok. Aday mısın yoksa?', 'Kalbim boş şimdilik, merak ettin mi?' },
        single = { 'Yok, şu an kimse yok.', 'Bekarım, öyle idare ediyorum.', 'Hayatımda şu an biri yok.' },
        closed = { 'O konulara pek girmem.', 'Şu an ilişki falan düşünmüyorum.', 'Bu biraz özel bir soru, geçelim.' },
        cold = { 'Sana ne?', 'Bu seni ilgilendirmez.' },
    },
    date_accept = { default = { 'Açıkçası... ben de bunu düşünüyordum. Olur.', 'Evet. Evet, olur! Deneyelim.', 'Bunu söylemeni bekliyordum. Tamam.' } },
    partner_accept = { default = { 'Artık ciddiyiz o zaman. Seninleyim.', 'Evet. Seninle olmak istiyorum.', 'Buna hayır diyemem. Evet.' } },
    date_already = { default = { 'Zaten beraberiz ya, unuttun mu?', 'Biz zaten birlikteyiz, tatlı şey.' } },
    date_refuse_stage = { default = { 'Daha birbirimizi yeterince tanımıyoruz.', 'Bence biraz erken, önce birbirimizi tanıyalım.', 'Acele etme, zamanla görürüz.' } },
    date_refuse_closed = { default = { 'Kusura bakma, şu an ilişki düşünmüyorum.', 'Seni severim ama o şekilde değil.', 'Böyle kalsın, iyi arkadaş olalım.' } },
    date_refuse_pref = { default = { 'Seni çok severim ama benim tercihim farklı.', 'Aramızda öyle bir şey olmaz, kusura bakma.' } },
    date_refuse_mood = { default = { 'Şu an bunu konuşacak havada değilim.', 'Bugün değil, başka zaman konuşalım.' } },
    date_refuse_age = { default = { 'Bu konulara hiç girmeyelim.' } },
    partner_refuse = { default = { 'Bu kadar hızlı gitmeyelim, böyle iyi.', 'Biraz daha zaman lazım bana.' } },
    stop_wait = { default = { 'Tamam, burada bekliyorum.', 'Peki, buradayım. Çok gecikme.', 'Bekliyorum, sen işini hallet.' } },
    stop_leave = { default = { 'Peki, ben o zaman kendi yoluma.', 'Tamam, görüşürüz sonra.', 'Olur, ben de işlerime döneyim.' } },
    stop_none = { default = { 'Zaten bir yere gitmiyorum ki.', 'Bir yere gittiğim yok ki.' } },
    follow_accept = {
        default = { 'Olur, gel gidelim.', 'Tamam, seninleyim.', 'Neden olmasın, düş önüme.' },
        friend = { 'Tabii ki! Hadi.', 'Seninle her yere, yürü bakalım.', 'Ooo, hadi gel!' },
        shy = { 'Ş-şey... olur, gelirim.' },
    },
    follow_refuse = {
        default = { 'Kusura bakma, şimdi olmaz.', 'Pek sanmıyorum, başka zaman.' },
        stranger = { 'Seni tanımıyorum bile, neden seninle geleyim?', 'Yabancılarla bir yere gitmem.' },
        busy = { 'İşteyim, şu an çıkamam.', 'Şu an işim var, olmaz.' },
        tired = { 'Çok yorgunum, bugün olmaz.', 'Ayakta duracak halim yok, başka zaman.' },
        mood = { 'Hiç havamda değilim, kusura bakma.', 'Bugün kimseyle bir yere gitmek istemiyorum.' },
        cold = { 'Seninle mi? Hayır.', 'Asla.' },
        repeat_no = { 'Dedim ya, olmaz.', 'Az önce söyledim, hayır.' },
    },
    follow_already = { default = { 'Zaten seninleyim ya.', 'Buradayım, yanındayım.' } },
    ride_accept = { default = { 'Olur, atlıyorum.', 'Tamam, binelim.', 'Süper, yürümekten iyidir.' } },
    ride_refuse = {
        default = { 'Yok, teşekkürler. Ben kendim giderim.', 'Tanımadığım arabalara binmem.', 'Şimdi olmaz, sağ ol.' },
        busy = { 'İşteyim, çıkamam.', 'İşimi bırakamam şimdi.' },
    },
    ride_no_vehicle = { default = { 'Araban nerede ki?', 'Hangi araba? Göremiyorum.' } },
    ride_full = { default = { 'Arabada yer yok ki.', 'Yer yok, sığmam oraya.' } },
    ride_sms = { default = { 'Yanımda değilsin ki, yüz yüze söyle.' } },
    go_accept = { default = { 'Olur, %dest%! Gidelim.', 'Tamam, %dest% olsun. Hadi.', 'İyi fikir, %dest% tarafına gidelim.' } },
    go_like = { default = { 'Oraya mı? Bayılırım!', 'Harika seçim, %dest% favorimdir.' } },
    go_refuse = {
        default = { 'Şimdi %dest% tarafına gitmek istemiyorum.', 'Başka zaman, bugün olmaz.' },
        dislike = { 'Oraya mı? Orayı hiç sevmem.', 'Oraya gitmeyelim, hiç hoşlanmam.' },
        busy = { 'İşteyim, olmaz.' },
    },
    go_npc_drive = { default = { 'Benim arabayla gidelim, atla!', 'Ben sürerim, arabam şurada.' } },
    go_player_drive = { default = { 'Seninkiyle gidelim o zaman.', 'Sen sür, ben yol gösteririm.' } },
    go_walk = { default = { 'Yürüyerek gideriz, yakın zaten.', 'Yürüyelim, hava güzel.' } },
    go_unknown = { default = { 'Orası neresi? Bilmiyorum.', 'Öyle bir yer bilmiyorum.' } },
    go_arrive = { default = { 'Geldik!', 'İşte geldik.', 'Vardık, güzelmiş.' } },
    dislike = {
        default = { 'En çok %dislike1% sevmem.', '%dislike1%... işte ona hiç tahammül edemem.', 'Sevmediğim şey mi? %dislike1%, bir de %dislike2%.' },
        empty = { 'Pek bir şeyden nefret etmem, rahat insanımdır.' },
        cold = { 'Şu an seni sevmiyorum mesela.' },
    },
    touch_accept = { default = { 'Olur.', 'Gel bakalım.', 'Tabii.' } },
    touch_refuse = {
        default = { 'Pek sanmıyorum.', 'Bunu yapmayalım.', 'Şu an istemiyorum.' },
        romance = { 'Bu biraz fazla samimi olmaz mı?', 'Aramızda öyle bir şey yok, değil mi?' },
        vehicle = { 'Araçtayken mi? Önce inelim.' },
        busy = { 'Şu an olmaz, meşgulüm.' },
    },
    us = {
        default = { 'Bence %xp_level% sayılırız.', 'Bana sorarsan %xp_level% gibiyiz.' },
        romance = { 'Biz mi? Seninle birlikteyiz, bunu biliyorsun.', 'Seni önemsiyorum, bunu bil yeter.' },
        cold = { 'Aramızda bir şey yok.' },
    },
    jealous = {
        default = { 'O da kimdi? Pek samimi görünüyordunuz.', 'Başkasıyla gezmek hoşuna gidiyor demek...', 'Beni hiç bu kadar gezdirmedin ama.' },
    },
    duty_leave = { default = { 'İşe geç kalıyorum, benim gitmem lazım!', 'Mesaim başlıyor, kaçmam lazım. Görüşürüz!' } },
    timeout_leave = { default = { 'Epey gezdik, artık gitmem lazım.', 'Benim artık dönmem lazım, çok güzeldi.' } },
    waited_leave = { default = { 'Çok bekledim, ben gidiyorum.', 'Seni bekleye bekleye yoruldum, gidiyorum.' } },
    left_behind = { default = { 'Hey! Beni burada mı bırakıyorsun?!', 'Nereye? Beni unuttun!' } },
    lost_leave = { default = { 'Neredesin? Neyse, ben gidiyorum.' } },
    no_seat = { default = { 'Arabada yer yok ki.', 'Sığmam oraya, yer yok.' } },
    door_locked = { default = { 'Kapı kilitli, açsana!', 'Kilidi açar mısın?' } },
    boarded = { default = { 'Kemerimi takayım.', 'Tamam, hazırım.', 'Hadi bakalım, yola!' } },
    duty_drop = { default = { 'Beni burada indirebilir misin? İşe gitmem lazım.' } },
    npc_drive_wait = { default = { 'Hadi atla, bekliyorum!', 'Binsene, gidiyoruz.' } },
    greet_entertainer = {
        stranger = { '%hello%, bu gece yalnız mısın?', 'Selam yakışıklı, ilk defa mı geliyorsun?', 'Hoş geldin, keyfin nasıl bu gece?' },
        known = { 'Aa, %p%! Yine sen, hoş geldin.', '%p%, tatlım! Seni görmek güzel.' },
        friend = { '%p%! Tam da seni bekliyordum.', 'En sevdiğim müşteri geldi, %p%!' },
        cold = { 'Sen yine mi? Kuralları biliyorsun.', 'Uzak dur, tamam mı?' },
    },
    intimate_accept = { default = { 'Hmm, olur... ama kurallar belli.', 'Tamam tatlım, rahatla.', 'Peki, ama nazik ol.' } },
    intimate_refuse = {
        default = { 'Hayır, bugün olmaz.', 'Bunu istemiyorum.', 'Pek sanmıyorum tatlım.' },
        privacy = { 'Burada mı? Etrafta insanlar var.', 'Daha sakin bir yer olmaz mı?' },
        vehicle = { 'Önce güzel bir yere park edelim.' },
    },
}
for k, v in pairs(lines) do
    if SCDialogue.Lines[k] == nil then SCDialogue.Lines[k] = v end
end

-- Kıskançlık hatırlatması (anı kodu: jealous)
SCDialogue.Accuse = SCDialogue.Accuse or {}
SCDialogue.Accuse.jealous = SCDialogue.Accuse.jealous or { 'Seni başka biriyle gördüm. Açıklayacak mısın?', 'Başkasıyla gezdiğini biliyorum, kalbimi kırdın.' }
SCDialogue.Accuse.abandoned = SCDialogue.Accuse.abandoned or { 'Geçen sefer beni yolda bırakıp gittin, unutmadım.' }
SCDialogue.Accuse.made_wait = SCDialogue.Accuse.made_wait or { 'Geçen sefer beni saatlerce beklettin.' }
SCDialogue.GossipAccuse = SCDialogue.GossipAccuse or {}
SCDialogue.GossipAccuse.jealous = SCDialogue.GossipAccuse.jealous or { '%other% anlattı, başka biriyle geziyormuşsun...' }
SCDialogue.Recall = SCDialogue.Recall or {}
SCDialogue.Recall.visit_place = SCDialogue.Recall.visit_place or { 'Geçen beraber gezmemiz çok güzeldi.', 'Geçen sefer güzel vakit geçirdik, yine yapalım.' }
SCDialogue.Recall.ride = SCDialogue.Recall.ride or { 'Geçen arabayla gezmemiz güzeldi.' }
SCDialogue.Recall.intimate = SCDialogue.Recall.intimate or { 'Geçen seferi unutmadım...' }

-- Etkileşim sonrası kısa tepkiler (Config.Animation.Social / Config.AdultAnimations anahtarları)
SCDialogue.InteractLines = {
    handshake = { 'Memnun oldum.', 'Sağlam tokalaşıyorsun.' },
    hug = { 'Bu iyi geldi.', 'Sıkı sarıldın ha!' },
    cheek_kiss = { 'Sen de mi öyle selamlaşıyorsun?', 'Hoş geldin!' },
    shoulder = { 'Efendim?', 'Hı? Buradayım.' },
    highfive = { 'İşte bu!', 'Çaktık!' },
    sit = { 'Oh, oturmak iyi geldi.', 'Biraz soluklanalım.' },
    dance = { 'Fena dans etmiyorsun!', 'Ritmi yakaladın!' },
    drink = { 'Şerefe!', 'Buna ihtiyacım vardı.' },
    photo = { 'Güzel çıktım mı?', 'Bana da atarsın!' },
    kiss = { '...', 'Bunu bekliyordum.' },
    embrace = { 'Böyle kalsak keşke.', 'Seninle olmak güzel.' },
    pole_dance = { 'Beğendin mi?', 'Gözünü ayırma bakalım.' },
    private_dance = { 'Rahatla tatlım.', 'Keyfine bak.' },
    private_dance_2 = { 'Beğendin mi?' },
    tease = { 'Hmm, bakışlarını gördüm.' },
    car_close = { '...' },
    car_intimate = { '...' },
}

-- =====================================================================
-- DİNAMİK CÜMLE ÜRETİCİ PARÇALARI
-- =====================================================================
SCDialogue.Parts = {
    -- konuşma başında selam
    greet = {
        { list = {
            { when = { group = 'friend' }, lines = { 'Ooo,', 'Oo bak sen,', 'Heey', 'Vay vay,' } },
            { w = 2, when = { romance = true }, lines = { '%p%!', 'Sonunda...', 'Aa, %p%,' } },
            { when = { tone = 'warm' }, lines = { 'Selam %p%,', 'Merhaba %p%,', '%hello% %p%,' } },
            { when = { tone = 'formal' }, lines = { '%hello%,', 'Merhabalar,' } },
            { when = { tone = 'grumpy' }, lines = { 'Hı.', 'Sen misin.' } },
            { when = { tone = 'shy' }, lines = { 'Ş-şey, selam.', 'Iıı, merhaba.' } },
            { when = { group = 'stranger', statMax = { confidence = 40 } }, lines = { 'Selam.', 'Merhaba.' } },
            { lines = { 'Selam %p%,', '%hello%,', 'Hey %p%,' } },
        } },
        { list = {
            { w = 3, when = { romance = true }, lines = { 'bugün seni göremeyeceğim sandım.', 'seni özlemişim.', 'tam da seni düşünüyordum.' } },
            { w = 2, when = { group = 'friend' }, lines = { 'sonunda ortaya çıktın.', 'nerelerdesin sen?', 'gel bakalım, anlat.', 'seni görmek iyi geldi.' } },
            { when = { group = 'known' }, lines = { 'ne var ne yok?', 'bugün nasıl gidiyor?', 'yine karşılaştık.' } },
            { when = { group = 'stranger', tone = 'warm' }, lines = { 'bugün nasıl gidiyor?', 'seni buralarda görmemiştim.' } },
            { when = { group = 'stranger', statMax = { confidence = 45 } }, lines = { 'Bir şey mi vardı?', 'Yardımcı olabilir miyim?' } },
            { when = { group = 'stranger' }, lines = { 'buyur?', 'bir şey mi lazım?', 'tanışıyor muyuz?' } },
            { when = { group = 'cold' }, lines = { 'Ne istiyorsun?', 'Çabuk söyle.' } },
            { when = { mood = { 'tired' } }, lines = { 'biraz yorgunum ama söyle.', 'uykumu açtın, buyur.' } },
            { when = { mood = { 'happy', 'excited' } }, lines = { 'bugün keyfim yerinde!', 'güzel bir gün, değil mi?' } },
            { lines = { 'nasılsın?', 'ne haber?' } },
        } },
    },
    -- selama eklenen ortam gözlemi
    aware = {
        { list = {
            { w = 4, when = { injured = true }, lines = { 'İyi misin? Pek iyi görünmüyorsun.', 'Hey, kanıyor musun sen? Hastaneye gitsene.' } },
            { w = 3, when = { armed = true }, lines = { 'O silahı indirir misin? Tedirgin oluyorum.', 'Elindekini kaldırsan iyi olur.' } },
            { w = 2, when = { rain = true }, lines = { 'Şu havaya bak, bir yere geçsek iyi olacak.', 'Sırılsıklam olacağız bu yağmurda.' } },
            { w = 2, when = { fight = true }, lines = { 'Az önce silah sesleri duydum, sen de duydun mu?', 'Buralar biraz karıştı, dikkat et.' } },
            { when = { police = true }, lines = { 'Etrafta çok polis var bugün.', 'Polisler bir şey mi arıyor acaba?' } },
            { when = { time = 'night' }, lines = { 'Bu saatte ne arıyorsun dışarıda?', 'Gece geç oldu ama.' } },
            { when = { inVehicle = true }, lines = { 'Güzel araba bu arada.' } },
        } },
    },
    -- beraber yürürken kendiliğinden
    auto_walk = {
        { list = {
            { w = 3, when = { rain = true }, lines = { 'Yağmur iyice bastırdı, bir yere mi girsek?', 'Islanıyoruz, hızlanalım mı?' } },
            { w = 2, when = { time = 'night' }, lines = { 'Gece şehir başka güzel oluyor.', 'Bu saatte sokaklar bomboş.' } },
            { w = 2, when = { time = 'morning' }, lines = { 'Sabah havası iyi geliyor.', 'Kahve içmeden ayılamıyorum.' } },
            { w = 3, when = { romance = true }, lines = { 'Seninle yürümek güzel.', 'Elimi tutmak ister misin?', 'Böyle gezmeyi özlemişim.' } },
            { w = 2, when = { stat = { humor = 65 } }, lines = { 'Bu hızla yürürsek akşama varırız, haha.', 'Az önce bir güvercin bana kötü baktı, yemin ederim.' } },
            { when = { mood = { 'tired' } }, lines = { 'Biraz yavaşlasak mı? Yoruldum.', 'Ayaklarım koptu.' } },
            { when = { fight = true }, lines = { 'Buralarda bir şeyler oluyor, dikkatli olalım.' } },
            { when = { police = true }, lines = { 'Polis çok bugün, hayırdır?' } },
            { lines = { 'Bugün buralar bayağı sakin.', 'Şu binaya bak, hiç fark etmemiştim.', '%place% tarafını severim aslında.', 'Nereye gidiyoruz, bir planın var mı?' } },
        } },
    },
    -- araçta yolcuyken
    auto_ride = {
        { list = {
            { w = 3, when = { romance = true }, lines = { 'Seninle yolculuk yapmayı seviyorum.', 'Müziği aç da keyfimiz yerine gelsin.' } },
            { w = 2, when = { speeding = true }, lines = { 'Biraz yavaş! Daha yaşamak istiyorum!', 'Yavaşla, kalbim ağzımda!' } },
            { when = { rain = true }, lines = { 'Yollar kaygan, dikkatli sür.' } },
            { when = { stat = { humor = 60 } }, lines = { 'Ehliyetini çekilişten mi aldın? Şaka şaka.' } },
            { lines = { 'Güzel araba.', 'Radyoda güzel bir şey var mı?', 'Trafik bugün fena değil.', 'Nereye gidiyoruz?' } },
        } },
    },
    -- beraber bir yerdeyken (buluşma / gezilen yer)
    auto_date = {
        { list = {
            { w = 3, when = { romance = true }, lines = { 'Burası çok güzel, iyi ki geldik.', 'Seninle burada olmak güzel.' } },
            { lines = { '%place% bu saatte güzel oluyor.', 'İyi ki geldik buraya.', 'Burayı sevdim.' } },
        } },
    },
    -- oyuncu bir süredir hiç konuşmuyorsa (beraber gezerken)
    auto_silence = {
        { list = {
            { when = { tone = 'warm' }, lines = { 'Bir şey mi oldu, bugün sessizsin?', 'Hayırdır, dilini mi yuttun?' } },
            { when = { romance = true }, lines = { 'Bana kızgın mısın, hiç konuşmuyorsun?', 'Aklın başka yerde gibi...' } },
            { when = { tone = 'shy' }, lines = { 'Ş-şey... her şey yolunda mı?' } },
            { lines = { 'Çok sessizsin bugün.', 'Bir şey mi düşünüyorsun?' } },
        } },
    },
    -- konuşma paneli açıkken oyuncu uzun süre yazmazsa
    silence_talk = {
        { list = {
            { when = { group = 'friend' }, lines = { 'Hey, dalıp gittin. İyi misin?', 'Bir şey mi oldu, bugün sessizsin?' } },
            { when = { tone = 'grumpy' }, lines = { 'Konuşacak mısın yoksa gideyim mi?' } },
            { lines = { 'Söyleyecek bir şey var mı?', 'Hâlâ burada mısın?', 'Bir şey mi soracaktın?' } },
        } },
    },
    -- NPC'nin kendiliğinden teklifi (%dest% ve %offer%)
    propose = {
        { list = {
            { when = { romance = true }, lines = { 'Bak ne diyeceğim,', 'Aklıma bir şey geldi,' } },
            { when = { tone = 'warm' }, lines = { 'Hey,', 'Dinle,' } },
            { lines = { 'Ne dersin,', 'Baksana,' } },
        } },
        { list = {
            { lines = { '%offer%?', '%offer%, ne dersin?' } },
        } },
    },
    -- eve dönme isteği
    go_home = {
        { list = {
            { when = { mood = { 'tired' } }, lines = { 'Çok yoruldum, ben eve gideyim artık.', 'Gözlerim kapanıyor, eve gitmem lazım.' } },
            { lines = { 'Geç oldu, ben artık eve gideyim.', 'Benim artık dönmem lazım.' } },
        } },
    },
    -- yakınlaşma (arkadaş NPC oyuncuyu görünce yanına gelir)
    approach = {
        { list = {
            { when = { romance = true }, lines = { '%p%! Bekle, seni gördüm!', 'Hey %p%, dur!' } },
            { lines = { 'Hey %p%! Bir saniye!', '%p%! Seni gördüm, dur bakalım.', 'Aa, %p%! Bekle!' } },
        } },
    },
    -- humor yüksek NPC'lerin cevaba eklediği espri
    quip = {
        { list = {
            { lines = { 'Şaka şaka.', 'Hehe.', 'Ciddi olamam, biliyorsun.', 'Neyse, gülmeyi unutma.' } },
        } },
    },
    -- ===== telefon (kendiliğinden mesajlar) =====
    sms_miss = {
        { list = {
            { when = { romance = true }, lines = { 'Seni özledim.', 'Neredesin sen?' } },
            { lines = { 'Selam %p%!', 'Hey,' } },
        } },
        { list = {
            { w = 2, when = { romance = true }, lines = { 'Uzun zamandır görüşemedik, ne zaman geliyorsun?' } },
            { lines = { 'İyi misin? Uzun süredir görmedim seni.', 'Kayıplara karıştın, her şey yolunda mı?', 'Ne zamandır ses yok, merak ettim.' } },
        } },
    },
    sms_absent = {
        { list = {
            { lines = { 'Bugün ortalarda yoksun, ne yapıyorsun?', 'Bugün hiç görmedim seni, neredesin?', 'Naber, bugün neler yaptın?' } },
        } },
    },
    sms_yesterday = {
        { list = {
            { w = 2, when = { romance = true }, lines = { 'Dün çok güzeldi, teşekkür ederim.', 'Aklım hâlâ dünde.' } },
            { lines = { 'Dün güzel vakit geçirdik.', 'Geçen seferki gezmemiz çok iyiydi, yine yapalım.' } },
        } },
    },
    sms_invite = {
        { list = {
            { when = { time = 'evening' }, lines = { 'Akşam bir yerlere gidelim mi?', 'Bu akşam boşum, %dest% tarafına gidelim mi?' } },
            { lines = { 'Canım sıkıldı, %dest% tarafına gidelim mi?', 'Müsaitsen %dest% tarafında buluşalım mı?' } },
        } },
    },
    sms_romance = {
        { list = {
            { lines = { 'Seni düşünüyordum.', 'Günün nasıl geçiyor tatlım?', 'Az önce aklıma geldin, gülümsedim.' } },
        } },
    },
    sms_generic = {
        { list = {
            { when = { stat = { humor = 60 } }, lines = { 'Bugün bir adam köpeğini gezdiriyordu, köpek adamı gezdiriyordu desem daha doğru.' } },
            { when = { mood = { 'tired' } }, lines = { 'Günüm çok yorucu geçti, sen nasılsın?' } },
            { lines = { 'Selam! Naber, nasılsın?', 'Nasıl gidiyor?', '%here% taraflarındayım, uğrasana.' } },
        } },
    },
}

-- Teklif metinleri (Config.NPCEvents.Types anahtarları)
SCDialogue.Offers = {
    coffee = { 'bir kahve içelim mi', '%dest% tarafına kahveye gidelim mi' },
    beach = { 'sahile inelim mi', '%dest% tarafına gidip biraz deniz havası alalım mı' },
    walk = { 'biraz yürüyelim mi', '%dest% tarafında biraz dolaşalım mı' },
    bar = { 'bir şeyler içmeye gidelim mi', '%dest% tarafına gidelim mi, bir şeyler içeriz' },
    eat = { 'bir şeyler yiyelim mi', '%dest% tarafında karnımızı doyuralım mı' },
}

-- Hızlı cevap önerileri (v3)
SCDialogue.Suggestions = SCDialogue.Suggestions or {}
SCDialogue.Suggestions.companion = { 'Burada bekle', 'Hadi gel', 'Ne yapalım?' }
SCDialogue.Suggestions.romance = { 'Seni özledim', 'Sarılalım mı?' }
SCDialogue.Suggestions.proposal = { 'Olur, gidelim', 'Olmaz' }

-- Konuşma panelindeki "Soru Sor" menüsü (tıklanınca bu cümle NPC'ye söylenir)
SCDialogue.MenuQuestions = {
    'Adın ne?', 'Kaç yaşındasın?', 'Ne iş yapıyorsun?', 'Nerede çalışıyorsun?', 'Kaçta işe gidiyorsun?',
    'Nerede oturuyorsun?', 'Nasılsın?', 'Sevgilin var mı?', 'Neleri seversin?', 'Neyi sevmezsin?',
    'En sevdiğin yer neresi?', 'Burası neresi?', 'Saat kaç?', 'Hava nasıl?', 'Bu akşam ne yapıyorsun?',
    'Biz neyiz?', 'Bir fıkra anlat', 'Beni hatırlıyor musun?',
}
SCDialogue.MenuActivities = {
    { label = 'Ne yapalım?', text = 'Ne yapalım?' },
    { label = 'Kahve içelim mi?', text = 'Kahve içelim mi?' },
    { label = 'Buluşalım mı?', text = 'Buluşalım mı?' },
    { label = 'Bir fıkra anlat', text = 'Bir fıkra anlat' },
}
SCDialogue.MenuRomance = {
    { label = 'Flört teklif et', text = 'Benimle çıkar mısın?' },
    { label = 'Ciddi ilişki teklif et', text = 'Benimle ciddi bir ilişki ister misin?' },
    { label = 'Seni özledim', text = 'Seni özledim' },
}
SCDialogue.MenuPhone = {
    { label = 'Numaranı alabilir miyim?', text = 'Numaranı alabilir miyim?' },
}
