--[[
    YAPAY ZEKÂSIZ DİYALOG VERİSİ (Türkçe)

    1) Intents  : oyuncunun cümlesinden algılanan niyetler. Desenler "katlanmış" yazılır
                  (küçük harf, Türkçe karakter yok: ş->s, ı->i, ğ->g, ç->c, ö->o, ü->u).
                    'kelime'   -> kök eşleşmesi: cümledeki bir kelime bununla BAŞLIYORSA eşleşir (calis -> çalışıyorum)
                    '=kelime'  -> birebir kelime (=sa sadece "sa" kelimesi)
                    'iki kelime' -> ifade (cümlede bu sırayla geçiyorsa)
                  weight: öncelik çarpanı. requires: gerekli bilgi (place/person).
                  Motor ayrıca: uzatılmış harfleri toparlar ("selaaam" -> "selam"), Slang tablosundaki kısaltmaları açar
                  ("nbr" -> "naber") ve 6+ harfli desenlerde tek harflik yazım hatasını tolere eder ("tesekurler").
    2) Lines    : cevap şablonları. Kova seçimi: <ton>_<aşama> -> <aşama> -> <ton> -> default
                  aşama: stranger | known (tanıdık) | friend (arkadaş/yakın) | cold (soğuk/düşman)
                  ton  : warm | formal | grumpy | shy | neutral (kişilik özelliklerinden otomatik)
                  Aynı konuşmada kullanılmış cümle tekrar seçilmez; bir yer tutucusu boş kalacak cümle atlanır.
    3) Yer tutucular: %p% (oyuncuya hitap; bilinmiyorsa silinir) %hello% %me% %job% %work% %doing% %reason% %here%
                  %hobbies% %hobby1% %age% %area% %home% %time% %weather% %loc% %when% %other% %other_rel% %other_where%
                  %fact_job% %fact_like% %fact_origin% %fact_fav% %topics% %ago% %phone% %dest% %news% %text% %item%
                  %plan% %years% %car% %t_work% %t_family% %t_dream% %t_origin% %t_food% %t_music%
    4) Followups: "neden?", "gerçekten mi?", "ben de", "anlat biraz" gibi tepkilerin SON KONUYA göre cevabı
    5) Custom   : sunucuna özel hazır soru-cevaplar (en altta). İstediğin kadar ekleyebilirsin.
]]
SCDialogue = SCDialogue or {}

-- =====================================================================
-- KISALTMA / AĞIZ (katlanmış kelime -> açılımı)
-- =====================================================================
SCDialogue.Slang = {
    slm = 'selam', slmlar = 'selamlar', selm = 'selam', slam = 'selam', mrb = 'merhaba', mrhb = 'merhaba', mrhba = 'merhaba',
    nbr = 'naber', nabr = 'naber', nber = 'naber', naberr = 'naber', nabre = 'naber',
    napiyon = 'ne yapiyorsun', napiyosun = 'ne yapiyorsun', napiyorsun = 'ne yapiyorsun', napion = 'ne yapiyorsun',
    nabiyon = 'ne yapiyorsun', napyon = 'ne yapiyorsun', naptin = 'ne yaptin', napcan = 'ne yapacaksin', napcaksin = 'ne yapacaksin',
    napim = 'ne yapayim', napayim = 'ne yapayim',
    nslsn = 'nasilsin', nasilsn = 'nasilsin', nasisin = 'nasilsin', nasi = 'nasil', nasilsiin = 'nasilsin',
    iyimsn = 'iyi misin', iyimisin = 'iyi misin', iyimisn = 'iyi misin',
    tmm = 'tamam', tm = 'tamam', tmam = 'tamam', tamm = 'tamam', okey = 'ok', oki = 'ok', okay = 'ok', okk = 'ok',
    tsk = 'tesekkur', tsklr = 'tesekkurler', tskler = 'tesekkurler', tskr = 'tesekkurler', saol = 'sag ol', sagol = 'sag ol',
    sagolun = 'sag olun', eyw = 'eyvallah', eyv = 'eyvallah', eywallah = 'eyvallah',
    kib = 'kendine iyi bak', bb = 'bay bay', bye = 'bye', gnydn = 'gunaydin', gunaydinn = 'gunaydin', grsrz = 'gorusuruz', gorsuruz = 'gorusuruz',
    evt = 'evet', hyr = 'hayir', yk = 'yok', he = 'evet', hee = 'evet', hi = 'evet', aynn = 'aynen',
    knk = 'kanka', kanki = 'kanka', cnm = 'canim', abicim = 'abi', ablacim = 'abla',
    bi = 'bir', bisey = 'bir sey', bisi = 'bir sey', birsey = 'bir sey', hersey = 'her sey', hicbisey = 'hic bir sey',
    nerdesin = 'neredesin', nerde = 'nerede', nerdeydin = 'neredeydin', nie = 'niye', nedn = 'neden', nicin = 'nicin',
    sn = 'sen', bn = 'ben', mrk = 'merak', slmn = 'selamun', ya = 'ya', yaa = 'ya',
    bilmiyom = 'bilmiyorum', bilmiom = 'bilmiyorum', bilmion = 'bilmiyorum', bilmyrm = 'bilmiyorum',
    gercekten = 'gercekten', cdn = 'cidden', valla = 'vallahi', vallaha = 'vallahi',
    hmm = 'hm', hmmm = 'hm', hmh = 'hm', mm = 'hm', aha = 'ha', ahaa = 'ha',
}

-- =====================================================================
-- NİYETLER
-- =====================================================================
SCDialogue.Intents = {
    { id = 'goodbye', weight = 1.6, patterns = { 'hosca kal', 'hoscakal', 'gorusuruz', 'gorusmek uzere', 'gule gule', 'bay bay', '=bye', 'kendine iyi bak', 'iyi geceler', 'allaha emanet', 'ben kacar', 'ben gideyim', 'gitmem lazim', 'gitmeliyim', 'sonra konusuruz', 'kacmam lazim', 'hadi bana eyvallah', 'gorusmek dilegiyle', 'kendine dikkat et', 'hadi ben kaciyorum', 'yine gorusuruz', 'sonra gorusuruz' } },
    { id = 'threat', weight = 2.0, exact = true, patterns = { 'oldururum', 'olduru', 'gebert', 'vururum', 'seni vurur', 'kafani', 'seni bulurum', 'pisman ederim', 'canini yakar', 'seni doverim', 'doverim', 'bicaklarim', 'seni yakarim', 'seni gomerim', 'mezara', 'seni oldur', 'canina okurum', 'seni mahvederim', 'dagitirim', 'kemiklerini', 'olmek mi istiyorsun', 'seni vuracag', 'kafana sikar', 'seni kesersem', 'boynunu' } },
    { id = 'insult', weight = 1.5, exact = true, patterns = { 'aptal', 'salak', 'gerizekali', 'geri zekali', '=mal', 'ezik', 'cirkin', 'kes sesini', 'defol', 'sus lan', 'serefsiz', 'pislik', 'hayvan herif', '=kopek', 'beyinsiz', 'dangalak', 'ahmak', 'embesil', 'kaybol', '=odun', 'sinir bozucu', 'yavsak', 'gerzek', 'mankafa', 'sersem', 'budala', 'enayi', '=keko', 'kafasiz', 'rezil', 'igrenc', 'cirkinsin', 'terbiyesiz', 'haddini bil' } },
    { id = 'greet', patterns = { 'selam', 'merhaba', '=slm', '=mrb', 'gunaydin', 'iyi aksamlar', 'iyi gunler', 'selamun aleykum', '=sa', '=hey', '=hello', '=hi', '=selamlar', '=merhabalar', 'aleykum selam', '=as', 'hayirli sabahlar', 'hayirli aksamlar', '=yo', 'hey sen' } },
    { id = 'how_are_you', patterns = { 'nasilsin', 'nasilsiniz', 'naber', 'ne haber', '=nbr', 'iyi misin', 'iyimisin', 'keyifler nasil', 'keyfin nasil', 'nasil gidiyor', 'ne alemde', 'naptin', 'ne var ne yok', 'hayat nasil', 'nasil gidiyor hayat', 'iyi misiniz', 'isler nasil', 'nasil bakalim' } },
    { id = 'ask_name', weight = 1.2, patterns = { 'adin ne', 'adiniz ne', 'adin nedir', 'ismin ne', 'isminiz', 'ismin', 'adini ogren', 'kimsin', 'sen kimsin', 'tanisalim', 'tanisabilir', 'kiminle konusuyorum', 'adini bilmiyorum', 'adin', 'sana ne diyeyim', 'sana nasil hitap' } },
    { id = 'ask_job', patterns = { 'ne is yap', 'ne iste calis', 'isin ne', 'meslegin', 'mesle', 'nerede calis', 'nerde calis', 'calisiyor musun', 'hangi iste', 'ne ile ugras', 'ne isle ugras', 'isin nasil', 'is guc', 'is nasil', 'is yerin', 'isten mi', 'mesai', 'ne is yaparsin', 'is yapiyor musun' } },
    { id = 'ask_doing', patterns = { 'ne yapiyorsun', 'napiyorsun', 'napiyon', 'ne yapiyon', 'noliyor', 'burada ne yap', 'burda ne yap', 'ne isin var', 'nereye gidiyorsun', 'nereye boyle', 'nereye gidiyon', 'ne yapmaktasin', 'mesgul musun', 'napiyosun', 'hayirdir', 'kimi bekliyorsun', 'ne bekliyorsun', 'ne ariyorsun', 'neredesin', 'musait misin' } },
    { id = 'ask_today', patterns = { 'neredeydin', 'nerdeydin', 'bugun ne yaptin', 'bugun neler', 'gunun nasil', 'bugun nasil gecti', 'neler yaptin', 'ne yaptin bugun', 'bugun ne yap', 'gunun nasil gecti', 'bugun nasildi' } },
    { id = 'ask_yesterday', patterns = { 'dun ne yaptin', 'dun neredeydin', 'dun nerdeydin', 'dun neler', 'dun nasil', 'dun ne yap' } },
    { id = 'ask_remember', weight = 1.3, patterns = { 'beni hatirl', 'hatirladin mi', 'hatirliyor musun', 'beni tanid', 'beni taniyor', 'ne konusmustuk', 'ne konustuk', 'en son ne', 'gecen sefer', 'son gorusmemiz', 'daha once konus', 'tanisiyor muyuz', 'unuttun mu', 'beni unuttun' } },
    { id = 'ask_hobby', patterns = { 'hobin', 'hobilerin', '=hobi', 'bos zaman', 'bos vakit', 'ne yapmayi sever', 'neyi sever', 'neler sever', 'ilgi alan', 'eglenmek icin', 'zevklerin', 'neden hoslanirsin', 'neyle ugrasirsin', 'bos zamanlarinda' } },
    { id = 'ask_age', patterns = { 'kac yasinda', 'yasin kac', 'yasiniz', 'kac yas', 'yasin ne' } },
    { id = 'ask_home', patterns = { 'nerede otur', 'nerde otur', 'nerede yasi', 'nerde yasi', 'evin nerede', 'evin nerde', 'hangi mahalle', 'adresin', 'evin nere' } },
    { id = 'ask_origin', patterns = { 'nerelisin', 'nereli', 'memleket', 'nerede buyu', 'nerde buyu', 'aslen', 'buralimisin', 'burali misin', 'nerede dogdun', 'nerde dogdun' } },
    { id = 'ask_family', patterns = { 'ailen', 'evli misin', 'evlisin', 'evli mi', 'cocugun', 'cocuklar', 'annen', 'baban', 'kardesin', 'bekar misin', 'esin var', 'kocan', 'karin', 'kiminle yasiyorsun', 'yalniz mi yasiyorsun' } },
    { id = 'ask_dream', patterns = { 'hayalin', 'hayallerin', 'gelecekte', 'ileride ne', 'amacin', 'hedefin', 'ne olmak ist', 'en buyuk istegin' } },
    { id = 'ask_secret', patterns = { 'sirrin', 'bir sir', 'sir ver', 'itiraf et', 'bana bir sey itiraf', 'kimsenin bilmedigi' } },
    { id = 'ask_food', patterns = { 'ne yemeyi', 'sevdigin yemek', 'yemek sever', 'favori yemek', 'yemek yedin', 'ne yersin', 'en sevdigin yemek', 'ne yemek' } },
    { id = 'ask_music', patterns = { 'muzik', 'sarki', 'ne dinliyorsun', 'hangi muzik', 'ne dinlersin' } },
    { id = 'ask_opinion_me', weight = 1.2, patterns = { 'beni sever misin', 'benden hoslan', 'arkadas miyiz', 'arkadasiz degil mi', 'bana guveniyor', 'hakkimda ne dusun', 'beni nasil buluyorsun', 'bana kizgin misin', 'benden nefret' } },
    { id = 'ask_phone', weight = 1.2, patterns = { 'numara', 'telefonun', 'telefon numaran', 'iletisim', 'seni nasil ararim', 'seni ararim', 'numarani ver', 'mesaj atayim' } },
    { id = 'ask_appointment', weight = 1.2, patterns = { 'bulusmamiz', 'ne zaman bulus', 'randevumuz', 'randevu ne zaman', 'saat kacta bulus', 'nerede bulusuyoruz' } },
    { id = 'propose_meet', weight = 1.1, patterns = { 'bulusal', 'bulusma', 'bulusur muyuz', 'gorusel', 'takilal', 'bir seyler icel', 'kahve icel', 'yemege cikal', 'disari cikal', 'bir ara gorus', 'bulusmaya ne dersin', 'birlikte gidel', 'beraber gidel', 'gel bulusalim', 'bir yere gidel' } },
    { id = 'cancel_meet', weight = 1.3, patterns = { 'iptal', 'gelemeyecegim', 'gelemem', 'gelemiyorum', 'erteleyel', 'ertele', 'yetisemem', 'bulusmayi iptal', 'gelmeyecegim' } },
    { id = 'ask_directions', requires = { 'place' }, patterns = { 'nerede', 'nerde', 'nasil gider', 'yol tarif', 'nasil gidebilirim', 'nereden gidil', 'yolu goster', 'neresi', 'bulamiyorum', 'yerini biliyor', 'nasil gidilir', 'nerededir' } },
    { id = 'ask_person', requires = { 'person' }, patterns = { 'tanir misin', 'taniyor musun', 'kimdir', 'nasil biri', 'nerede', 'nerde', 'hakkinda', 'gordun mu' } },
    { id = 'ask_news', patterns = { 'haber var', 'dedikodu', 'neler oluyor', 'yeni bir sey', 'olay var mi', 'bir sey duydun', 'duydun mu', 'mahallede', 'ilginc bir sey', 'neler olmus', 'ne olmus' } },
    { id = 'ask_weather', patterns = { 'hava nasil', 'havalar', 'yagmur', 'gunesli', 'hava cok', 'hava guzel', 'hava soguk', 'hava sicak', 'bu hava' } },
    { id = 'ask_time', patterns = { 'saat kac', 'kac saat', 'saati biliyor', 'saat ne' } },
    { id = 'compliment', patterns = { 'guzelsin', 'yakisikli', 'harikasin', 'cok iyisin', 'cok tatli', 'tatlisin', 'akillisin', 'komiksin', 'cok hos', 'iyi birisin', 'seni sevdim', 'bayildim sana', 'muhtesemsin', 'cok iyi birine', 'efsanesin', 'cok naziksin', 'kiyafetin guzel', 'saclarin', 'gozlerin' } },
    { id = 'thanks', patterns = { 'tesekkur', '=tsk', 'sagol', 'sag ol', 'sagolun', 'eyvallah', 'mersi', 'thanks', 'minnettar', 'cok sagol', 'eline saglik' } },
    { id = 'apology', patterns = { 'ozur', 'kusura bakma', '=pardon', 'affedersin', '=affet', 'yanlis anlama', 'kusura bakmayin', 'ozur dilerim' } },
    { id = 'flirt', weight = 1.1, exact = true, patterns = { 'sevgilin var', 'sevgili olal', 'cikalim mi', 'benimle cik', 'evlenel', 'hoslaniyorum', 'asigim', 'asik oldum', 'seni seviyorum', 'opucuk', 'beraber olal', 'kalbimi caldin', 'numarani alabilir miyim tatlim' } },
    { id = 'ask_follow', weight = 1.2, patterns = { 'benimle gel', 'pesimden gel', 'eslik et', 'takip et', 'gel benimle', 'benle gel', 'bizimle gel', 'beni takip' } },
    { id = 'laugh', patterns = { '=haha', '=hahaha', '=hahahaha', '=sjsj', '=ahah', 'cok komik', '=lol', '=ksksks', '=asdfg', '=hehe', '=jsjs', 'kahkaha', 'gulmekten', 'komikmis', '=xd' } },
    { id = 'yes', patterns = { '=evet', '=olur', '=tamam', '=tabii', '=tabi', '=kabul', 'anlastik', 'neden olmasin', '=uyar', 'olur tabii', '=elbette', '=kesinlikle olur', 'tabii ki', '=istiyorum' } },
    { id = 'no', patterns = { '=hayir', '=olmaz', '=yok', 'istemem', 'uymaz', 'olmasin', 'baska zaman', 'gerek yok', '=istemiyorum', 'hic sanmam', 'yok ya', '=asla' } },
    { id = 'player_mood_good', patterns = { 'iyiyim', 'harikayim', 'cok iyiyim', 'fena degil', 'idare eder', '=super', 'bomba gibi', 'bende iyiyim', 'ben de iyiyim', 'keyfim yerinde', 'mutluyum', 'cok mutluyum', 'coskuluyum', 'iyi gidiyor' } },
    { id = 'player_mood_bad', patterns = { 'kotuyum', 'berbatim', 'uzgunum', 'yorgunum', 'hastayim', 'moralim bozuk', 'pek iyi degil', 'cok kotu', 'iyi degilim', 'keyfim yok', 'mutsuzum', 'bunaldim', 'stresliyim', 'kafam bozuk', 'canim sikkin' } },

    -- ---------------- sohbet tepkileri (son konuya göre cevaplanır) ----------------
    { id = 'ask_back', weight = 0.9, patterns = { '=sen', '=sende', '=senden', 'ya sen', 'peki sen', 'ya senin', 'peki senin', 'sen ne dersin', 'sende mi', '=siz', 'ya siz', 'senin icin', 'ya sende' } },
    { id = 'why', weight = 0.9, patterns = { '=neden', '=niye', '=nicin', 'neden ki', 'niye ki', 'sebep', 'neden oyle', 'niye oyle', 'neden boyle' } },
    { id = 'really', patterns = { 'gercekten mi', 'cidden mi', '=cidden', 'yok artik', 'hadi ya', 'sahi mi', '=sahi', 'ciddi misin', 'vallahi mi', 'yemin et', 'inanmiyorum', 'dalga mi geciyorsun', 'saka mi', 'emin misin', 'olamaz ya', 'yapma ya' } },
    { id = 'agree', patterns = { 'haklisin', '=aynen', 'bence de', 'kesinlikle', 'cok dogru', 'katiliyorum', 'dogru soyluyorsun', 'aynen oyle', 'oyle tabii', 'dogrusu bu', 'ayni fikirdeyim', 'dogru diyorsun' } },
    { id = 'ack', weight = 0.8, patterns = { 'anladim', '=hm', '=peki', 'oyle mi', '=ha', 'tamamdir', 'anlasildi', '=ok', 'iyi bakalim', '=olsun', '=neyse', 'oyleymis', 'demek oyle', 'hm peki', '=oh' } },
    { id = 'impressed', patterns = { '=vay', 'vay be', 'harika', 'muhtesem', 'guzelmis', 'ne guzel', 'efsane', '=helal', 'helal olsun', 'bravo', 'tebrik', 'iyiymis', 'harikaymis', 'fena degilmis', 'ilginc', 'inanilmaz', '=oha', '=wow', 'cok guzelmis', 'ne hos' } },
    { id = 'sympathy', patterns = { 'yazik', 'uzuldum', 'gecmis olsun', 'kotu olmus', 'cok uzuldum', '=vah', '=tuh', 'canin sagolsun', 'insallah duzelir', 'moralini bozma', 'uzulme', 'sabret', 'gecer', 'kafana takma', 'dert etme' } },
    { id = 'me_too', patterns = { 'ben de', '=bende', 'ayni ben', 'bende oyle', 'ben de oyle', 'ben de severim', 'ayni sekilde', 'ben de ayni', 'benimki de' } },
    { id = 'tell_more', patterns = { '=anlat', 'biraz anlat', 'anlatsana', 'devam et', 'detay', 'ne gibi', '=mesela', 'daha fazla', 'nasil yani', 'nasil bir sey', 'acar misin', 'anlat bakalim', 'biraz daha' } },
    { id = 'dont_know', patterns = { 'bilmiyorum', '=bilmem', 'emin degilim', 'fikrim yok', 'hic bilmiyorum', 'bilemedim', 'hic fikrim', 'karar veremedim' } },
    { id = 'how_long', weight = 1.1, patterns = { 'ne zamandir', 'kac yildir', 'kac yil', 'ne kadar zamandir', 'ne zamandan beri', 'kac senedir', 'ne kadar oldu', 'ne kadardir' } },

    -- ---------------- yeni konular ----------------
    { id = 'ask_joke', weight = 1.2, patterns = { 'fikra', 'espri', 'komik bir sey', 'guldur beni', 'saka yap', 'beni guldur', 'bir saka', 'komiklik yap', 'beni eglendir' } },
    { id = 'ask_feeling', weight = 1.1, patterns = { 'mutlu musun', 'neden uzgunsun', 'neyin var', 'bir sey mi oldu', 'canin sikkin mi', 'keyfin yok', 'sinirli misin', 'yorgun musun', 'ne oldu sana', 'iyi gorunmuyorsun', 'moralin bozuk', 'uzgun musun', 'kizgin gorunuyorsun', 'dertli misin', 'derdin ne', 'neden boylesin', 'yorgun gorunuyorsun', 'keyifsiz misin', 'aciktin mi', 'ac misin' } },
    { id = 'ask_plans', weight = 1.1, patterns = { 'bu aksam ne', 'aksam ne yap', 'yarin ne yap', 'hafta sonu', 'planin var mi', 'ne yapacaksin', 'nereye gideceksin', 'sonra ne yap', 'isten sonra', 'is cikisi', 'planin ne', 'bu gece ne', 'yarin neredesin', 'aksam neredesin' } },
    { id = 'ask_city', patterns = { 'bu sehir', 'los santos', 'bu sehri', 'burasi nasil', 'bu mahalle', 'mahalle nasil', 'burayi sever', 'burada yasamak', 'sehir nasil', 'buralar nasil', 'burasi guzel mi', 'burasi tehlikeli', 'sehri sever', 'buralari sever' } },
    { id = 'ask_pet', patterns = { 'evcil', 'hayvanin', 'hayvan sever', '=kedi', 'kedin', '=kopek', 'kopegin', 'kopek sever', 'kedi sever', 'hayvanlari sever' } },
    { id = 'ask_sport', patterns = { 'hangi takim', 'takim tutar', 'mac izle', 'spor yapar', 'spor yap', 'basketbol', 'futbol sever', 'spor sever', 'takimin', 'mac var' } },
    { id = 'ask_movie', patterns = { '=film', 'filmler', 'dizi', 'sinema', 'ne izliyorsun', 'en sevdigin film', 'film izler', 'hangi film', 'ne izlersin' } },
    { id = 'ask_car', patterns = { 'araban', 'arabanin', 'araba kullan', 'ehliyet', 'ne suruyorsun', 'araban var mi', 'aracin', 'arabayla mi' } },
    { id = 'ask_smoke', patterns = { 'sigara', 'cakmak', 'atesin var mi', 'sigaran var', 'bir dal', 'sigara icer' } },
    { id = 'ask_money', weight = 1.2, patterns = { 'borc', 'para ver', 'paran var mi', 'bana para', 'bozuk para', 'harclik', 'biraz para', 'cuzdan', 'para lazim', '=paran', '=parani', 'parani ver', 'paranin hepsini', 'paralari ver', 'paralarini ver', 'ne kadar paran', 'neyin varsa ver' } },
    { id = 'ask_help', patterns = { 'yardim eder misin', 'yardimci olur musun', 'yardimina ihtiyacim', 'bir iyilik', 'yardim et', 'bana yardim' } },
    { id = 'offer_help', weight = 1.1, patterns = { 'yardim edebilir miyim', 'yardim lazim mi', 'bir sey lazim mi', 'yardima ihtiyacin', 'yardimci olayim', 'yardim edeyim', 'bir sey ister misin' } },
    { id = 'offer_drink', weight = 1.2, patterns = { 'ismarlayayim', 'ismarlarim', 'sana bir sey alayim', 'kahve ister misin', 'bir sey icer misin', 'cay ister misin', 'davet ediyorum', 'hesap benden', 'benden olsun' } },
    { id = 'player_bored', patterns = { 'sikildim', 'canim sikiliyor', 'cok sikici', 'yapacak bir sey yok', 'ne yapsam', 'sikintidan' } },
    { id = 'ask_advice', weight = 1.1, patterns = { 'nerede yemek', 'nerede yenir', 'ne yesem', 'iyi bir kafe', 'iyi bir yer', 'nereye gideyim', 'nerede eglen', 'onerin', 'tavsiye', 'onerir misin', 'nereye gidilir', 'nerede icki', 'guzel bir mekan', 'nerede takil', 'iyi bir bar', 'iyi bir restoran' } },
    { id = 'meta', weight = 1.3, patterns = { '=npc', 'bot musun', '=bot', 'robot', 'yapay zeka', 'gercek misin', 'gercek insan', 'script', 'oyun karakteri', '=admin', 'sunucu', 'fivem', '=gta', 'yazilim', 'kodlanmis', 'bilgisayar misin' } },
    { id = 'sensitive', weight = 1.2, patterns = { 'siyaset', '=secim', 'hangi parti', 'politika', 'dinin', 'hangi dinden', 'oy verdin', 'cumhurbaskani', 'hukumet' } },
    { id = 'miss_you', patterns = { 'ozledim', 'seni ozledim', 'ozlemisim', 'ozledin mi', 'ozlettin' } },
    { id = 'player_story', weight = 1.1, patterns = { 'sana bir sey anlatayim', 'biliyor musun ne oldu', 'bak ne oldu', '=dinle', 'ne oldu biliyor musun', 'sana bir sey soyleyeyim', 'anlatayim mi', 'bugun bana', 'basima gelen' } },
    { id = 'player_hungry', weight = 1.2, patterns = { '=acim', '=ackim', 'aciktim', 'karnim ac', 'cok acim', 'bir sey yemek istiyorum', 'acliktan' } },
    { id = 'player_tired', weight = 1.2, patterns = { 'uykum var', 'yoruldum', 'uykusuzum', 'bitkinim', 'cok yorgunum', 'uyumam lazim' } },
    { id = 'keep_secret', weight = 1.1, patterns = { 'kimseye soyleme', 'aramizda kalsin', 'kimseye anlatma', 'sir olarak', 'polise soyleme', 'polisi arama', 'kimseye bir sey deme', 'kimseye soylemeyeceksin', 'agzini kapali tut', 'kimseye bahsetme' } },
    { id = 'calm', weight = 1.1, patterns = { 'sakin ol', 'korkma', 'zarar vermeyecegim', 'sana bir sey yapmayacagim', 'bir sey olmayacak', 'rahat ol', 'panik yapma', 'endise etme', 'merak etme', 'sakin olursan', 'uslu durursan', 'kimse zarar gormeyecek' } },
    { id = 'release_promise', weight = 1.2, patterns = { 'birakacagim', 'seni birakacagim', 'gidebilirsin', 'serbestsin', 'birazdan birakirim', 'birakicam', 'salacagim', 'seni salarim', 'birakirim seni' } },
    { id = 'ask_favorite_place', weight = 1.1, patterns = { 'en sevdigin yer', 'favori mekan', 'nerede takilirsin', 'nereye takilirsin', 'en cok nereye', 'favori yerin', 'en sevdigin mekan', 'nerelere gidersin' } },
}

-- Konuşmada ele alınan konuların özet cümlesindeki karşılığı (ayrılma hâli: "...den/dan bahsettik")
SCDialogue.Topics = {
    how_are_you = 'hâl hatırdan', ask_job = 'işimden', ask_doing = 'ne yaptığımdan', ask_today = 'günümden',
    ask_yesterday = 'dünkü günümden', ask_hobby = 'hobilerimden', ask_family = 'ailemden', ask_dream = 'hayallerimden',
    ask_secret = 'bir sırdan', ask_food = 'yemekten', ask_music = 'müzikten', ask_weather = 'havadan',
    ask_news = 'mahalledeki olaylardan', propose_meet = 'buluşmaktan', ask_origin = 'memleketten',
    ask_home = 'nerede oturduğumdan', ask_person = 'tanıdıklardan', player_job = 'senin işinden', player_like = 'sevdiğin şeylerden',
    flirt = 'biraz da flörtten', compliment = 'güzel sözlerden',
    ask_joke = 'fıkralardan', ask_feeling = 'nasıl hissettiğimden', ask_plans = 'planlardan', ask_city = 'şehirden',
    ask_pet = 'evcil hayvanlardan', ask_sport = 'spordan', ask_movie = 'filmlerden', ask_car = 'arabalardan',
    ask_advice = 'gidilecek yerlerden', player_origin = 'senin memleketinden', ask_favorite_place = 'sevdiğim yerlerden',
    player_mood_bad = 'senin derdinden', player_story = 'senin başına gelenlerden',
}

-- Aktiviteye göre "şu an ne yapıyorsun" cevabı (birinci tekil şahıs)
SCDialogue.Doing = {
    sleep = { 'Uyuyordum aslında...', 'Uyumaya çalışıyordum.' },
    home_idle = { 'Evde biraz dinleniyordum.', 'Evdeyim, kafa dinliyorum.', 'Pek bir şey, evde oyalanıyorum.' },
    idle = { 'Öylesine takılıyorum.', 'Bir şey yapmıyorum, bekliyorum sadece.', 'Biraz soluklanıyorum, %here% güzel yer.' },
    work = { 'Çalışıyorum, burası iş yerim.', 'İş başındayım, bugün epey yoğun.', 'Mesaideyim, işler bitmek bilmiyor.', 'Ekmek parası işte, çalışıyorum.' },
    study = { 'Derslerle uğraşıyorum.', 'Okuldayım, ders arası.', 'Ödev yetiştirmeye çalışıyorum.' },
    deliver = { 'Teslimattayım, acelem var.', 'Paket yetiştiriyorum.', 'Bir teslimat daha var, sonra biraz nefes alacağım.' },
    lunch_break = { 'Öğle arası veriyorum, biraz nefes alıyorum.', 'Moladayım.', 'Mola verdim, birazdan işe döneceğim.' },
    eat = { 'Bir şeyler yiyorum.', 'Yemek yiyordum, %here% fena değil.', 'Karnımı doyuruyorum.' },
    coffee = { 'Kahvemi içiyorum, biraz kafa dinliyorum.', '%here% tarafında kahve molası.', 'Kahvesiz ayılamıyorum, ondan buradayım.' },
    drink = { 'Bir şeyler içiyorum, takılıyorum işte.', 'Günün yorgunluğunu atıyorum.', '%here% tarafında biraz eğleniyorum.' },
    leisure = { 'Biraz dolaşıyorum, hava alıyorum.', 'Yürüyüş yapıyorum.', 'Kafamı dağıtıyorum, %here% güzel.' },
    exercise = { 'Spor yapıyorum, formu korumak lazım.', 'Antrenmandayım.', 'Biraz ter atıyorum.' },
    shopping = { 'Alışveriş yapıyorum.', 'Birkaç eksik vardı, onları alıyorum.' },
    fish = { 'Balık tutuyorum, bakalım bugün vuracak mı.', 'Oltayı attım, bekliyorum.' },
    commute = { '%dest% tarafına gidiyorum.', 'Yoldayım, %dest% tarafına.', '%dest% tarafına yetişmem lazım.' },
    appointment = { 'Birini bekliyorum.', 'Buluşmam var, bekliyorum.' },
    follow = { 'Seninle geliyorum ya!' },
}

-- Plan cümleleri ("bu akşam ne yapıyorsun?"): plain / loc (%loc% ile)
SCDialogue.PlanPhrase = {
    work = { plain = 'işte olacağım', loc = '%loc% tarafında işte olacağım' },
    study = { plain = 'derste olacağım' },
    deliver = { plain = 'teslimat yetiştiriyor olacağım' },
    sleep = { plain = 'uyuyor olurum herhalde' },
    home_idle = { plain = 'evde dinlenirim' },
    idle = { plain = 'pek bir şey yapmam' },
    lunch_break = { plain = 'molada olurum' },
    lunch = { plain = 'öğle arası veririm' },
    free = { plain = 'boş vaktim olacak' },
    eat = { plain = 'bir şeyler yerim', loc = '%loc% tarafında bir şeyler yerim' },
    coffee = { plain = 'bir kahve içerim', loc = '%loc% tarafında kahve içerim' },
    drink = { plain = 'bir şeyler içmeye çıkarım', loc = '%loc% tarafına bir şeyler içmeye giderim' },
    leisure = { plain = 'biraz dolaşırım', loc = '%loc% civarında biraz dolaşırım' },
    exercise = { plain = 'spora giderim', loc = '%loc% tarafında spor yaparım' },
    shopping = { plain = 'alışverişe çıkarım' },
    fish = { plain = 'balığa giderim', loc = '%loc% tarafında balık tutarım' },
    appointment = { plain = 'biriyle buluşacağım' },
    hospital = { plain = 'hastanede olacağım' },
}

-- Ruh hâli sebebi (birinci tekil şahıs cümle)
SCDialogue.ReasonMe = {
    tired = 'Çok yorgunum.', hungry = 'Karnım aç.', lonely = 'Biraz yalnız hissediyorum.',
    bored = 'Canım sıkılıyor.', good = 'Keyfim yerinde.', ok = 'Her şey normal.',
    -- olay kodları
    recovering = 'Hastaneden yeni çıktım, hâlâ toparlanıyorum.', police = 'Polisle uğraşmak zorunda kaldım.',
    witness = 'Korkutucu bir şeye tanık oldum, hâlâ tedirginim.', car = 'Arabam çalındı!',
    kidnapped = 'Rehin alındım... hâlâ kendime gelemedim.', aim_weapon = 'Biri bana silah doğrulttu, hâlâ titriyorum.',
    assaulted = 'Biri bana saldırdı, canım yanıyor.', gift = 'Biri bana hediye verdi, çok sevindim.',
    met_appointment = 'Güzel bir buluşmadan geliyorum.', harassment = 'Biri bana çok kaba davrandı.',
}

-- Hitap sözcükleri (konuşma tarzındaki tırnaklı kelimelerden bunlar cümle sonuna eklenir, diğerleri başa)
SCDialogue.Vocatives = { kanka = true, evlat = true, ['evladım'] = true, ['yeğenim'] = true, abi = true, abla = true, hocam = true, efendim = true, dostum = true, kardo = true }

-- Konuşma tarzındaki tırnaklı sözlerden cümle başına eklenebilenler (katlanmış; diğerleri sadece karakteri tarif eder)
SCDialogue.PrefixOK = { yaa = true, ya = true, ['ay inanmiyorum'] = true, aciksi = true, ['acikcasi'] = true, bence = true, ['bak simdi'] = true, valla = true, vallahi = true, yani = true, sey = true, efendim = true }

-- Kişiliğe göre ayrı söylenen dolgu sözcükleri (cevabın başına, tek başına bir cümle olarak)
SCDialogue.Fillers = {
    warm = { 'Ya...', 'Valla.', 'Ay...', 'Hmm.', 'Bak şimdi...' },
    neutral = { 'Hmm.', 'Şey...', 'Evet...', 'Bakalım...' },
    formal = { 'Efendim...', 'Şöyle ki...', 'Hmm.' },
    grumpy = { 'Hıh.', 'Of...', 'Offf.', 'Ne diyeyim...' },
    shy = { 'Şey...', 'Iıı...', 'Ş-şey...', 'Hmm...' },
}

-- Mahalle etiketi -> okunur ad
SCDialogue.AreaLabels = {
    little_seoul = 'Little Seoul', morningwood = 'Morningwood', pillbox = 'Pillbox Hill', rockford = 'Rockford Hills',
    pillbox_south = 'Pillbox güneyi', davis = 'Davis', strawberry = 'Strawberry', vespucci = 'Vespucci',
    del_perro = 'Del Perro', downtown_vinewood = 'Downtown Vinewood', west_vinewood = 'West Vinewood',
    vinewood = 'Vinewood', richman = 'Richman', mirror_park = 'Mirror Park',
}

-- İsim / memleket sanılmaması gereken kelimeler
SCDialogue.NotNames = {
    iyi = true, de = true, da = true, burada = true, burdayim = true, geldim = true, gidiyorum = true, tamam = true,
    evet = true, hayir = true, polis = true, doktor = true, yeni = true, senin = true, onun = true, bir = true, hic = true,
    zaten = true, sadece = true, simdi = true, hep = true, cok = true, biraz = true, hazirim = true, yokum = true, varim = true,
    bilmiyorum = true, bilmem = true, soylemem = true, yok = true, sana = true, ne = true, sen = true, ben = true, bu = true,
    orasi = true, burasi = true, uzak = true, yakin = true, baska = true, bazen = true, genelde = true,
}

-- =====================================================================
-- CEVAP ŞABLONLARI
-- =====================================================================
SCDialogue.Lines = {
    greet = {
        stranger = { '%hello%. Buyurun?', '%hello%, bir şey mi lazım?', 'Evet? Yardımcı olabilir miyim?', '%hello%. Tanışıyor muyuz?', 'Hı? Bana mı dedin?', '%hello%, buyur.' },
        known = { '%hello% %p%! Nasılsın?', 'Aa, %p%! Ne haber?', 'Selam %p%, hoş geldin.', 'Bak sen, %p%! Nereden çıktın?', 'Oo %p%, naber bakalım?', '%p%! Seni gördüğüme sevindim.' },
        friend = { '%p%! Seni görmek ne güzel!', 'Hey %p%! Tam da seni düşünüyordum.', 'Oo %p%, gel bakalım!', '%p%! Nerelerdesin sen ya?', 'Gel gel %p%, özlettin kendini!', 'Kimleri görüyorum, %p%!' },
        cold = { 'Ne istiyorsun?', 'Hı? Söyle.', 'Yine mi sen...', 'Çabuk söyle, işim var.', 'Hıh. Sen.' },
        grumpy_stranger = { 'Ne var?', 'Hı? Buyur.', 'Evet? Çabuk olsun.' },
        formal_stranger = { '%hello%, buyurun efendim?', '%hello%. Size nasıl yardımcı olabilirim?', '%hello%, buyurun, dinliyorum.' },
        shy_stranger = { 'Ş-şey... %hello%?', 'Bana mı dediniz? %hello%.', 'Iıı... evet?' },
        warm_stranger = { '%hello%! Nasılsın bakalım?', 'Selam! Seni buralarda görmemiştim.', '%hello%! Yeni misin buralarda?' },
        grumpy_known = { 'Sen misin %p%. Ne var ne yok?', 'Hı, %p%. Söyle bakalım.' },
        warm_known = { '%p%! Gel buraya, ne haber?', 'Ooo %p%! Günüme renk kattın.' },
    },
    greet_busy = { default = { '%hello%, işteyim ama söyle.', 'Biraz meşgulüm, kısa kes lütfen.', 'Hızlıca söyle, acelem var.', 'Şu an biraz yoğunum ama dinliyorum.', 'Çok vaktim yok, ne oldu?' } },
    greet_absence = { default = { '%p%! Uzun zamandır yoktun, nerelerdeydin?', 'Vay %p%, seni görmeyeli çok oldu!', 'Nerelerdesin %p%? Kayıplara karıştın!', '%p%! Seni özlemişim, nerelerdeydin?' } },
    -- sakin selam verdikten sonra oyuncunun ilk selamına
    greet_back = {
        default = { 'Selam!', 'Merhaba, merhaba.', 'Selam, hoş geldin.' },
        friend = { 'Selaaam!', 'Selam canım!', 'Selam selam!' },
        formal = { 'Merhaba, buyurun.', 'Merhabalar.' },
        cold = { 'Hı.', 'Evet?' },
    },
    greet_again = {
        default = { 'Selam, selam.', 'Buradayım, söyle.', 'Selamlaştık ya, söyle bakalım.' },
        friend = { 'Selam selam, söyle bakalım.', 'Buradayım, anlat.', 'Heh, selam tekrar!' },
        cold = { 'Evet, evet. Ne istiyorsun?', 'Hı.' },
    },

    how_are_you = {
        great = { 'Harikayım, çok iyi bir gün!', 'Süperim! %reason%', 'Çok iyiyim valla, keyfime diyecek yok.', 'Bomba gibiyim!' },
        good = { 'İyiyim, sağ ol.', 'Fena değil, idare ediyoruz.', 'İyiyim iyiyim. %reason%', 'İyidir, şükür.', 'Gayet iyi, sağ ol sorduğun için.' },
        neutral = { 'Eh işte, idare eder.', 'Normal, her zamanki gibi.', 'Bildiğin gibi, bir gün daha.', 'Ne iyi ne kötü, öyle işte.' },
        bad = { 'Pek iyi değilim açıkçası. %reason%', 'Biraz keyifsizim. %reason%', 'Olsun bir şekilde... %reason%', 'Eh, pek sorma. %reason%' },
        awful = { 'Hiç iyi değilim. %reason%', 'Berbat bir gün geçiriyorum. %reason%', 'Sorma, hiç sorma. %reason%' },
        cold = { 'Sana ne?', 'İyiyim. Başka?', 'Seni ilgilendirmez.' },
    },
    askback_mood = { default = { 'Sen nasılsın?', 'Sen?', 'Senden ne haber?', 'Sen nasılsın bakalım?' } },
    player_mood_good = { default = { 'Sevindim!', 'Güzel, hep öyle ol.', 'Oh ne güzel.', 'Buna sevindim işte.', 'Keyfin yerinde olsun hep.' } },
    player_mood_bad = { default = { 'Geçmiş olsun, umarım düzelir.', 'Üzüldüm... Bir şey olursa söyle.', 'Hay aksi. Moralini bozma.', 'Olur öyle günler, geçer.', 'Tüh... Kafana takma, düzelir.' } },
    askwhy_bad = { default = { 'Neden, ne oldu?', 'Hayırdır, ne oldu?', 'Anlatmak ister misin?' } },
    player_hungry = {
        place = { 'Acıktıysan %loc% fena değil, bir bak derim.', '%loc% tarafına git, karnın doyar.', 'Ben olsam %loc% tarafına giderdim.' },
        default = { 'Ben de acıktım şimdi söyleyince.', 'Bir şeyler ye bence, aç kalma.' },
    },
    player_tired = { default = { 'Git biraz dinlen o zaman.', 'Uyku gibisi yok, eve gidip yat.', 'Bu şehir herkesi yoruyor, anlıyorum.', 'Kendini zorlama, biraz mola ver.' } },
    player_bored = {
        place = { 'Sıkıldıysan %loc% tarafına git, iyi gelir.', '%loc% bu saatte güzel oluyor, bir dene.', 'Ben sıkılınca %loc% tarafına giderim.' },
        default = { 'Sıkıldıysan bir yürüyüşe çık derim.', 'Bir hobi edin, zaman nasıl geçiyor anlamazsın.' },
    },
    player_day_good = { default = { 'Güzel, iyi geçmesine sevindim.', 'Oh ne güzel.', 'İyi günler hep böyle olsun.' } },

    ask_name = {
        stranger = { 'Ben %me%.', 'Adım %me%. Memnun oldum.', '%me%, memnun oldum.', 'Bana %me% derler.' },
        known = { 'Unuttun mu yoksa? %me%!', '%me% ben, %p%. Dalga mı geçiyorsun?', 'Hadi ama, %me%!' },
        friend = { '%p%, şaka mı yapıyorsun? %me% ben!', 'Adımı unuttuysan kırılırım, %me%!' },
        cold = { 'Bilmen gerekmiyor.', 'Sana ne benim adımdan.' },
        grumpy_stranger = { '%me%. Neden sordun?', '%me%. Başka?' },
        shy_stranger = { 'Ş-şey... %me%.', '%me%... memnun oldum.' },
        formal_stranger = { 'Adım %me%, memnun oldum.', '%me%, tanıştığımıza memnun oldum.' },
    },
    askback_name = { default = { 'Senin adın ne?', 'Peki sen kimsin?', 'Sen?', 'Senin adın neydi?' } },
    introduce_ok = { default = { 'Memnun oldum %p%!', 'Tanıştığımıza sevindim %p%.', '%p%... Güzel isim.', 'Tamam %p%, aklımda.' } },
    introduce_known = { default = { 'Biliyorum %p%, unutmadım ki.', 'Evet evet, %p%. Hatırlıyorum.', 'Seni unutur muyum %p%?' } },
    introduce_nick = { default = { 'Tamam, sana %p% diyeyim o zaman.', '%p% ha? Peki, öyle olsun.' } },

    ask_job = {
        default = { '%text%', '%job% olarak çalışıyorum. İş yerim %work%.' },
        cold = { 'Seni ilgilendirmez.', 'Neden soruyorsun?' },
    },
    askback_job = { default = { 'Sen ne iş yapıyorsun?', 'Peki sen ne iş yaparsın?', 'Sen ne işle uğraşıyorsun?' } },
    player_job = { default = { '%fact_job% ha? Güzel, kolay gelsin.', 'Vay, %fact_job%. Zor iş olmalı.', '%fact_job% demek. Aklımda tutarım.', 'Hiç tahmin etmezdim, %fact_job%! Nasıl, seviyor musun?' } },

    ask_doing = { default = { '%doing%' }, cold = { 'Seni ilgilendirmez.' } },
    ask_today = {
        default = { 'Bugün önce %text%. Şimdi de buradayım.', 'Bugün mü? %text%.', 'Sabahtan beri %text%. Yoruldum biraz.' },
        empty = { 'Pek bir şey yapmadım, sakin bir gündü.', 'Bugün mü? Sıradan bir gün işte.' },
        cold = { 'Sana hesap vermek zorunda değilim.' },
    },
    askback_day = { default = { 'Senin günün nasıl geçti?', 'Sen neler yaptın bugün?' } },
    ask_yesterday = {
        default = { 'Dün önce %text%.', 'Dün mü? %text%.' },
        empty = { 'Dün mü? Pek hatırlamıyorum, sıradan bir gündü.' },
        cold = { 'Sana ne dünden.' },
    },
    ask_remember = {
        convo = { 'Tabii hatırlıyorum! %ago% %loc% civarında konuşmuştuk, %topics% bahsetmiştik.', 'Unutur muyum! %ago% %loc% civarında sohbet etmiştik; %topics% bahsetmiştik.' },
        convo_nosum = { 'Tabii hatırlıyorum, %ago% konuşmuştuk.', 'Hatırlıyorum tabii, en son %ago% görüşmüştük.' },
        vague = { 'Yüzün tanıdık geliyor ama tam çıkaramadım.', 'Hmm... bir yerden tanıyorum ama nereden?' },
        stranger = { 'Hayır, daha önce tanıştığımızı sanmıyorum.', 'Tanışıyor muyuz? Hatırlamıyorum.' },
        fact_job = { 'Sen %fact_job% değil miydin?', '%fact_job% olarak çalışıyordun, değil mi?' },
        fact_like = { 'Hatta bana neyi sevdiğini de söylemiştin: %fact_like%.' },
    },
    ask_hobby = {
        default = { '%hobbies% severim.', 'Boş zamanlarımda %hobbies% ile uğraşırım.', 'Fırsat buldukça %hobby1%. Bir de %hobbies_rest%... uzun liste.', 'Beni en çok %hobby1% rahatlatır.' },
        cold = { 'Sana ne hobilerimden.' },
    },
    askback_likes = { default = { 'Sen neleri seversin?', 'Senin hobilerin neler?', 'Sen boş zamanlarında ne yaparsın?' } },
    player_like = { default = { 'Güzel zevk, aklımda!', 'Oo, demek öyle. Güzel!', 'Bak bunu bilmiyordum, güzel.', 'Hoşmuş, bir ara ben de denerim.' } },
    ask_age = {
        default = { '%age% yaşındayım.', '%age%. Neden sordun?', '%age% oldum, zaman nasıl geçiyor anlamadım.' },
        grumpy = { 'Yaş sorulur mu hiç? %age%.' },
        shy = { 'Şey... %age%.' },
        cold = { 'Sana ne.' },
    },
    ask_home = {
        stranger = { 'Buralarda oturuyorum, %area% taraflarında.', 'Onu yabancılarla paylaşmam, kusura bakma.' },
        known = { '%area% taraflarında oturuyorum.', '%area% tarafında bir evde kalıyorum.' },
        friend = { '%home% tarafında oturuyorum. İstersen bir ara uğra.', '%home%. Gelirsen çay demlerim.' },
        cold = { 'Neden bilmek istiyorsun? Hayır.' },
    },
    ask_origin = { default = { '%text%' }, empty = { 'Aslen buralı değilim, uzun hikâye.', 'Buralıyım sayılır artık.' }, cold = { 'Sana ne.' } },
    askback_origin = { default = { 'Sen nerelisin?', 'Sen buralı mısın?', 'Peki sen nerelisin?' } },
    player_origin = {
        default = { '%fact_origin% ha? Oraları hiç görmedim, güzel mi?', '%fact_origin% demek. Oralardan çok insan var burada.', 'Vay, %fact_origin%! Özlüyor musun?' },
        ['local'] = { 'Buralısın demek, o zaman buraları benden iyi bilirsin.', 'Tam buralısın yani, güzel.' },
        same = { 'Yok artık, ben de oralıyım! Hemşehriyiz!', 'Gerçekten mi? Ben de oralardanım! Dünya küçük.' },
    },
    ask_family = {
        default = { '%text%' },
        stranger = { 'Ailemi pek tanımadığım biriyle konuşmam, kusura bakma.', '%text%' },
        empty = { 'Ailem mi? Onlar başka şehirde, pek görüşemiyoruz.' },
        cold = { 'Ailemi karıştırma.' },
    },
    ask_dream = { default = { '%text%' }, empty = { 'Hayal mi? Şimdilik günü kurtarmaya bakıyorum.' }, cold = { 'Sana ne.' } },
    askback_dream = { default = { 'Senin hayalin ne peki?', 'Sen ne hayal ediyorsun?' } },
    ask_secret = {
        friend = { 'Aramızda kalsın ama... %text%', 'Sana güveniyorum, o yüzden söylüyorum: %text%' },
        default = { 'Sırlarımı herkesle paylaşmam.', 'Önce biraz daha tanışalım, sonra belki.', 'Sır dediğin söylenmez ki!' },
        cold = { 'Sana mı anlatacağım? Rüyanda görürsün.' },
        empty = { 'Pek sırrım yok aslında, açık kitabım.' },
    },
    ask_food = { default = { '%text%' }, empty = { 'Ev yemeğine hayır demem.' }, cold = { 'Sana ne yediğimden.' } },
    askback_food = { default = { 'Sen ne seversin?', 'Senin favorin ne?' } },
    ask_music = { default = { '%text%' }, empty = { 'Ne çıkarsa dinlerim, radyo açık kalır genelde.' }, cold = { 'Seni ilgilendirmez.' } },
    askback_music = { default = { 'Sen ne dinlersin?', 'Senin tarzın ne?' } },
    ask_opinion_me = {
        friend = { 'Tabii ki! Sen iyi bir arkadaşsın %p%.', 'Seni seviyorum, bunu biliyorsun.' },
        close = { 'Sen benim en iyi dostlarımdansın %p%.', 'Sana güveniyorum, bunu unutma.' },
        known = { 'Seni severim, iyi birine benziyorsun.', 'İyi anlaşıyoruz bence.' },
        stranger = { 'Seni daha yeni tanıyorum, bir şey diyemem.', 'Henüz bir fikrim yok, tanışalım bakalım.' },
        cold = { 'Açık konuşayım, sana pek güvenmiyorum.', 'Senden hoşlanmıyorum, belli değil mi?' },
    },
    ask_phone = {
        give = { 'Tabii, not al: %phone%.', 'Olur, numaram %phone%. Yazarsın.', 'Kaydet bakalım: %phone%.' },
        already = { 'Numaram zaten sende var ya.', 'Numaramı vermiştim, bir baksana.' },
        stranger = { 'Daha yeni tanıştık, kusura bakma.', 'Numaramı tanımadığım biriyle paylaşmam.' },
        known = { 'Biraz daha tanıyayım seni, sonra belki.', 'Şimdilik olmaz, kusura bakma.' },
        cold = { 'Asla.', 'Rüyanda görürsün.' },
        disabled = { 'Telefonum şu an yanımda değil, sonra.' },
    },
    ask_appointment = {
        has = { '%when%, %loc%. Unutma!', 'Buluşmamız %when%, yer %loc%.' },
        none = { 'Bir buluşma ayarlamadık ki.', 'Aramızda bir randevu yok.' },
    },

    -- buluşma akışı
    meet_refuse_stranger = { default = { 'Daha yeni tanıştık, biraz erken değil mi?', 'Seni tanımıyorum bile.' } },
    meet_refuse_known = { default = { 'Belki ileride, şimdilik olmaz.', 'Biraz daha tanışalım, sonra bakarız.' } },
    meet_refuse_cold = { default = { 'Seninle mi? Asla.', 'Hayır, teşekkürler.' } },
    meet_ask_place = { default = { 'Olur! Nerede buluşalım? %loc% olur mu?', 'Neden olmasın. %loc% nasıl?' } },
    meet_ask_time = { default = { 'Saat kaçta? %when% olur mu?', 'Ne zaman? Bana %when% uyar.' } },
    meet_accept = { default = { 'Tamam, %when%, %loc%. Görüşürüz!', 'Anlaştık: %when%, %loc%. Gelirim!', 'Süper, %when% %loc% civarında buluşuruz.' } },
    meet_conflict_work = { default = { 'O saatte işteyim. %when% olur mu?', 'Olmaz, o saat mesaideyim. %when% nasıl?' } },
    meet_conflict_sleep = { default = { 'O saatte uyuyor olurum. %when% olur mu?', 'Çok geç/erken o saat. %when% nasıl?' } },
    meet_conflict_busy = { default = { 'O saatlerde başka bir buluşmam var. %when% olur mu?' } },
    meet_bad_time = { default = { 'O saat olmaz, başka bir saat söyle.', 'Başka bir zaman söyle, o olmaz.' } },
    meet_unknown_place = { default = { 'Orayı bilmiyorum. Başka bir yer söyle.', 'Neresi orası? Bildiğim bir yer söyle.' } },
    meet_already = { default = { 'Zaten %when% %loc% civarında buluşacağız ya!' } },
    meet_declined = { default = { 'Peki, sen söyle o zaman.', 'Tamam, sen bir öneride bulun.' } },
    cancel_meet = {
        default = { 'Tamam, iptal edelim. Başka zaman.', 'Peki, sorun değil.' },
        none = { 'Zaten bir buluşmamız yoktu ki.' },
    },
    offer_drink = {
        stranger = { 'Çok naziksin ama tanımadığım birinden kabul edemem.', 'Sağ ol, başka zaman belki.' },
        known = { 'Çok naziksin! Şu an olmaz ama aklımda.', 'Sağ ol, bir dahakine ben ısmarlarım.' },
        cold = { 'Senden bir şey istemem.' },
    },

    ask_directions = {
        found = { '%loc% mı? Haritana işaretledim.', '%loc%... Şuradan git, haritana işaretledim.', '%loc% şu tarafta kalıyor, haritana işaretledim.' },
        stranger = { '%loc% mı? Haritana işaretledim, oradan bakarsın.' },
    },
    ask_advice = {
        found = { '%loc% fena değil, haritana işaretledim.', 'Bence %loc%. Bir dene, haritana işaretledim.', 'Ben olsam %loc% tarafına giderdim. İşaretledim.' },
        none = { 'Açıkçası iyi bir yer bilmiyorum.', 'Hmm, aklıma bir yer gelmedi.' },
    },
    ask_person = {
        coworker = { '%other% mı? İş arkadaşım, iyi biridir.', '%other% ile beraber çalışıyoruz.' },
        neighbor = { '%other% komşum sayılır.', '%other% mı? Aynı mahalledeyiz.' },
        friend = { '%other% mı? Tanırım tabii, eski dostum.', '%other% ile iyi anlaşırız.' },
        none = { '%other% mı? Tanımıyorum.', 'O ismi hiç duymadım.' },
        where = { 'Şu saatte muhtemelen %other_where%.' },
    },
    ask_news = {
        default = { 'Duydun mu? %news%', 'Geçenlerde %news%' },
        empty = { 'Sakin bir dönem, pek bir şey olmadı.', 'Yeni bir şey yok, her şey yolunda.', 'Valla bu ara sessiz sakin.' },
        stranger = { 'Pek bir şey bilmiyorum.', 'Buralarda yeniyim sayılır, bilmem.' },
        cold = { 'Sana dedikodu yapacak değilim.' },
    },
    ask_weather = {
        rain = { 'Bugün hava %weather%. Yağmur beni hep keyifsizleştirir.', 'Hava %weather%, şemsiyeyi unutma.', 'Şu yağmur bir dinse...' },
        default = { 'Bugün hava %weather%.', 'Hava %weather%, fena değil.', '%weather% bir gün, keyfini çıkar.' },
    },
    ask_time = { default = { 'Saat %time%.', '%time% oldu bile.', 'Saat %time%, zaman nasıl geçiyor!' } },
    ask_feeling = {
        great = { 'Hiç olmadığım kadar iyiyim! %reason%', 'Mutluyum, gerçekten. %reason%' },
        good = { 'İyiyim ya, neden sordun? %reason%', 'Gayet iyiyim. %reason%' },
        neutral = { 'Bir şeyim yok, sadece dalgınım.', 'Öyle işte, bildiğin gibi.' },
        bad = { 'Belli oluyor mu? %reason%', 'Biraz... %reason%', 'Pek iyi değilim. %reason%' },
        awful = { 'Hiç iyi değilim açıkçası. %reason%', 'Sorma... %reason%' },
        cold = { 'Seni ilgilendirmez.', 'Neyim olacak, bir şeyim yok.' },
    },
    ask_joke = {
        cold = { 'Sana fıkra anlatacak havamda değilim.' },
        grumpy = { 'Fıkra mı? Ben komik biri değilim ama... dinle bakalım.' },
    },
    ask_plans = {
        default = { '%when% büyük ihtimalle %plan%.', 'Şöyle söyleyeyim: %when% %plan%.', 'Hmm, %when% %plan%.' },
        nothing = { 'Henüz bir planım yok.', 'Bilmiyorum, bakalım ne olacak.', 'Planım yok, akışına bırakıyorum.' },
        cold = { 'Sana ne planlarımdan.' },
    },
    askback_plans = { default = { 'Sen ne yapıyorsun?', 'Senin planın ne?' } },
    player_plans = {
        default = { 'Güzel, iyi eğlenceler!', 'Hoş, keyfini çıkar.', 'İyi plan, bayağı güzel.' },
        work = { 'Kolay gelsin o zaman.', 'Çalışmak şart, kolay gelsin.' },
        none = { 'Boş ver, bazen planı olmamak iyidir.', 'Canın ne isterse onu yap o zaman.' },
    },
    ask_city = {
        warm = { 'Bu şehri seviyorum! Kalabalık ama canlı.', 'Los Santos başka, gece ışıkları bir harika.', 'Buralar güzel, insanları da fena değil.' },
        grumpy = { 'Bu şehir mi? Pahalı, gürültülü, trafik berbat.', 'Sevmiyorum desem yalan olur ama... çok yorucu.' },
        formal = { 'Güzel bir şehir, ama geceleri pek güvenli değil.', 'Fırsatlar şehri derler, bana göre biraz fazla hızlı.' },
        shy = { 'Kalabalık biraz... ama alıştım.', 'Bazen çok gürültülü geliyor bana.' },
        default = { 'Eh, her şehir gibi. İyisi de var kötüsü de.', 'Güzel ama her yerde silah sesi duyunca tedirgin oluyorsun.' },
        cold = { 'Sensiz daha güzeldi.' },
    },
    ask_car = {
        has = { 'Bir %car% kullanıyorum. Eski ama iş görür.', '%car% var, beni yolda bırakmaz.', 'Evet, bir %car%. Pek bakamıyorum ama idare ediyor.' },
        none = { 'Arabam yok, toplu taşımayla idare ediyorum.', 'Araba mı? Benzin parasına mı çalışacağım!', 'Yürürüm ben, sağlığa da iyi.' },
        stolen = { 'Arabam çalındı, hâlâ bulunamadı!', 'Sorma, arabamı çaldılar.' },
        cold = { 'Sana ne arabamdan.' },
    },
    ask_smoke = {
        yes = { 'Al bir tane, ama söyleme kimseye bırakmaya çalışıyorum.', 'Var, al. Ateş de var.', 'Son paketim... al bir tane bakalım.' },
        no = { 'Sigara içmem, kusura bakma.', 'Yok, bıraktım çoktan.', 'İçmiyorum, sen de bıraksan iyi olur.' },
    },
    ask_money = {
        stranger = { 'Kusura bakma, tanımadığım birine para vermem.', 'Param yok ki vereyim.', 'Ben de ay sonunu zor getiriyorum.' },
        known = { 'Valla bende de yok, maaşa daha var.', 'Ne kadar lazım? Şaka şaka, ben de dar boğazdayım.' },
        friend = { 'Başın mı dertte? Çok yoksa hallederiz ama ben de pek zengin değilim.', 'Kardeşim, keşke olsa. Bu ay ben de sıkışığım.' },
        cold = { 'Sana mı? Asla.' },
    },
    ask_help = {
        stranger = { 'Ne oldu? Elimden gelirse yardım ederim.', 'Ne lazım? Söyle bakalım.' },
        known = { 'Tabii, söyle ne lazım?', 'Elimden gelen bir şeyse yaparım.' },
        friend = { 'Sen iste yeter %p%, ne lazım?', 'Senin için her zaman, söyle.' },
        cold = { 'Sana yardım edeceğimi mi sanıyorsun?' },
    },
    offer_help = {
        default = { 'Sağ ol, gerek yok. Ama düşünmen güzel.', 'Teşekkürler, idare ediyorum.', 'Çok naziksin, iyiyim şimdilik.' },
        busy = { 'Sağ ol, işim var ama hallederim.', 'Teşekkürler, bu işi bir ben bilirim.' },
    },
    ask_favorite_place = {
        default = { 'En sevdiğim yer %loc%. Sık giderim.', '%loc%! Orada kendimi iyi hissediyorum.', 'Boş vaktim olunca %loc% tarafına kaçarım.' },
        none = { 'Pek bir yere gitmem, evim güzel.' },
    },
    askback_fav = { default = { 'Senin en sevdiğin yer neresi?', 'Sen nerede takılırsın?' } },
    player_fav = {
        same = { '%loc% mı? Ben de bayılırım oraya!', 'Ciddi misin? %loc% benim de favorim!' },
        default = { '%loc% ha? Bir ara ben de gideyim.', 'Hiç gitmedim %loc% tarafına, güzel mi?' },
    },
    meta = { default = { 'Ne? Ne diyorsun sen, anlamadım.', 'Garip sorular soruyorsun... İyi misin?', 'Ben mi? Ben %me%, gayet gerçeğim. Sen iyi misin?', 'Bu ne biçim soru şimdi?', 'Kafan mı güzel senin?' } },
    sensitive = { default = { 'O konulara hiç girmeyelim.', 'Siyaset, din... Bunları konuşmam, kavga çıkar.', 'Onu boş ver, başka bir şeyden konuşalım.' } },
    miss_you = {
        stranger = { 'Özlemek mi? Daha yeni tanıştık...', 'Pardon, tanışıyor muyuz?' },
        known = { 'Aa, ben de seni! Nerelerdeydin?', 'Ne tatlısın, ben de özledim.' },
        friend = { 'Ben de seni çok özledim %p%!', 'Asıl ben özledim! Bir ara oturup uzun uzun konuşalım.' },
        cold = { 'Ben hiç özlemedim.' },
    },
    listen = { default = { 'Anlat bakalım, dinliyorum.', 'Hayırdır? Anlat.', 'Merak ettim, anlat!', 'Dinliyorum, söyle.' } },
    share_ack = { default = { 'Hmm, anladım.', 'Vay be, öyle mi?', 'İlginç...', 'Anlıyorum seni.', 'Güzelmiş.' } },
    share_bad = { default = { 'Üzüldüm, gerçekten.', 'Geçmiş olsun... Umarım düzelir.', 'Zor bir durum, anlıyorum.' } },
    share_declined = { default = { 'Peki, sorun değil.', 'Tamam, söylemek zorunda değilsin.', 'Anladım, önemli değil.' } },
    why_asked = { default = { 'Merak ettim sadece.', 'Öylesine sordum.', 'Sohbet işte, merak ettim.' } },
    keep_secret = { default = { 'Merak etme, ağzım sıkıdır.', 'Tamam, kimseye söylemem.', 'Sırrın bende güvende.' }, cold = { 'Bir şey söz vermiyorum.' } },
    calm_normal = { default = { 'Sakinim zaten, sen iyi misin?', 'Ben sakinim, sende bir tuhaflık var.' } },
    compliment = {
        stranger = { 'Teşekkürler... ama daha yeni tanıştık.', 'Aa, sağ ol.', 'Oh, teşekkür ederim.' },
        known = { 'Aa, sağ ol! Sen de iyisin.', 'Çok naziksin.', 'Güldürdün beni, teşekkürler.' },
        friend = { 'Sen de çok iyisin %p%!', 'Utandırma beni şimdi.', 'Bunu senden duymak güzel.' },
        cold = { 'Bu bir şey değiştirmez.' },
    },
    insult = {
        default = { 'Bana böyle konuşamazsın!', 'Terbiyesizlik etme.', 'Ne demek istiyorsun sen?', 'Bunu hak edecek ne yaptım?' },
        grumpy = { 'Sensin o!', 'Ağzını topla!', 'Git başkasına sataş.' },
        shy = { 'Neden böyle konuşuyorsun ki...', 'Ben sana ne yaptım?' },
    },
    threat = { default = { 'Beni tehdit mi ediyorsun?! Polisi arıyorum!', 'Uzak dur benden! İmdat!' } },
    thanks = { default = { 'Rica ederim.', 'Ne demek!', 'Önemli değil.', 'Her zaman.' }, friend = { 'Lafı mı olur %p%.', 'Aramızda lafı mı olur!' } },
    apology = {
        forgive = { 'Tamam... bu seferlik affediyorum.', 'Peki, özrünü kabul ediyorum.' },
        default = { 'Özür dilenecek bir şey yok ki.', 'Önemli değil.', 'Dert etme, sorun yok.' },
    },
    flirt = {
        stranger = { 'Ee... daha adını bile bilmiyorum.', 'Biraz hızlı gitmiyor musun?' },
        known = { 'Hmm, bunu duymadım sayıyorum.', 'Şakacısın sen.', 'Kızardım şimdi, yapma.' },
        friend = { 'Utandırma beni şimdi %p%!', 'Sen de az değilsin ha!' },
        cold = { 'Rüyanda görürsün.' },
    },
    ask_follow = {
        yes = { 'Olur, biraz takılayım seninle.', 'Tamam, düş önüme!' },
        busy = { 'Şu an olmaz, işim var.' },
        stranger = { 'Seni tanımıyorum bile.' },
        default = { 'Şimdi olmaz, kusura bakma.' },
    },
    laugh = { default = { 'Haha, değil mi?', 'Gülmekten öldüm.', 'Hahaha!', 'Güldün ya, yeter bana.', 'Hehe, iyiydi.' } },
    yes = { default = { 'Neye evet?', 'Tamam...', 'Peki o zaman.' } },
    yes_q = { default = { 'Güzel!', 'Oh, sevindim.', 'Anladım.', 'Tamamdır.' } },
    no = { default = { 'Peki.', 'Tamam, sen bilirsin.', 'Olsun.' } },
    no_q = { default = { 'Peki, anladım.', 'Olsun, sorun değil.', 'Hmm, tamam.' } },
    repeat_answer = { default = { 'Az önce söyledim ya.', 'Dedim ya.', 'Tekrar mı soruyorsun?' } },
    repeat_same = { default = { 'Aynı şeyi söyledin az önce.', 'Bunu demiştin zaten.', 'Kendini tekrar ediyorsun.' } },
    ask_back_already = { default = { 'Az önce anlattım ya.', 'Dedim ya, ben de öyle.', 'Söyledim ya az önce!' } },
    ask_back_none = { default = { 'Ben mi? Ne soruyorsun, tam anlamadım.', 'Ne konuda?' } },
    fallback = {
        stranger = { 'Ne demek istediğini anlamadım.', 'Hmm?', 'Pardon, anlamadım.' },
        known = { 'Ne dedin? Tam anlamadım.', 'Hmm, emin değilim ne demek istediğine.' },
        friend = { 'Ne diyorsun sen %p%? Anlamadım ki.', 'Hah? Bir daha söyle.' },
        cold = { 'Ne saçmalıyorsun?', 'Anlamadım, anlamak da istemiyorum.' },
        grumpy = { 'Ne saçmalıyorsun?' },
        shy = { 'Şey... anlamadım.' },
    },
    -- anlaşılmayan ama soru olan cümleler: insan gibi "bilmiyorum" der
    fallback_question = {
        default = { 'Bilmem ki, hiç düşünmedim.', 'Valla fikrim yok.', 'Güzel soru... bilmiyorum.', 'Hmm, onu bilemeyeceğim.', 'Emin değilim açıkçası.' },
        cold = { 'Bilmiyorum, bilsem de söylemezdim.' },
    },
    fallback_short = {
        default = { 'Hı hı.', 'Hmm.', 'Evet?', 'Anladım...' },
        cold = { 'Hı.', '...' },
    },
    fallback_long = {
        default = { 'Vay, uzun hikâye... tam takip edemedim ama anladığım kadarıyla ilginç.', 'Hmm, ilginç. Ben pek anlamam bu işlerden.', 'Anlıyorum... sanırım. Biraz karışık geldi.' },
        cold = { 'Uzatma, ne istiyorsun?' },
    },
    fallback_hint = { default = { 'Bana işimi, hobilerimi ya da buraları sorabilirsin.', 'İstersen işimden, ailemden ya da buralardan konuşabiliriz.', 'Başka bir şeyden konuşalım mı? Mesela bu şehirden.' } },
    busy_end = { default = { 'Kusura bakma, işe dönmem lazım. Sonra konuşuruz.', 'Daha fazla duramam, işteyim.', 'Patron bakıyor, sonra konuşalım.' } },
    goodbye = {
        default = { 'Görüşürüz!', 'Hoşça kal.', 'Kendine iyi bak.', 'Güle güle, yine gel.', 'Hadi görüşürüz.' },
        friend = { 'Görüşürüz %p%, kendine iyi bak!', 'Hadi görüşürüz %p%!', 'Kaybolma yine %p%!' },
        cold = { 'Güle güle... nihayet.', 'Hı.' },
    },

    -- genel sohbet tepkileri (son konuya özel cevap yoksa)
    fu_why = { default = { 'Neden mi? Öyle denk geldi işte.', 'Bilmem, hayat işte.', 'Uzun hikâye, bir ara anlatırım.', 'Öyle olması gerekiyormuş demek.' } },
    fu_really = { default = { 'Valla! Neden yalan söyleyeyim?', 'Evet, gerçekten.', 'Ciddiyim, yemin ederim.', 'Şaşırdın değil mi? Ben de şaşırmıştım.' } },
    fu_agree = { default = { 'Değil mi? Bence de.', 'Aynen öyle.', 'Anlaştık o zaman.', 'Bak, aynı kafadayız.' } },
    fu_ack = { default = { 'Evet...', 'Öyle işte.', 'Hı hı.', 'Neyse...' } },
    fu_impressed = { default = { 'Değil mi? Ben de öyle düşünüyorum.', 'Sağ ol!', 'Hehe, öyledir.' } },
    fu_sympathy = { default = { 'Sağ ol, iyi olacak.', 'Olur öyle şeyler, geçer.', 'Teşekkürler, düşünmen güzel.' } },
    fu_me_too = { default = { 'Öyle mi? Ne güzel, ortak noktamız varmış.', 'Sen de mi? Dünya küçük.', 'Bak sen, anlaşacağız biz.' } },
    fu_tell_more = { default = { 'Ne anlatayım, fazlası yok.', 'Anlatacak pek bir şey yok aslında.', 'Başka ne diyeyim, öyle işte.' } },
    fu_dont_know = { default = { 'Olsun, sorun değil.', 'Bilmemek de bir cevap.', 'Düşünürsün bir ara.' } },
    fu_how_long = { default = { 'Epey oldu, saymadım açıkçası.', 'Uzun zamandır, alıştım artık.' } },

    -- konuşkan kişiliklerde bazen cevaba eklenir
    chatter = { default = { 'Bu arada hava %weather%, fark ettin mi?', 'Ha bu arada, %hobbies% severim; bir ara anlatırım.', 'Bugün epey koşturmaca vardı.', 'Bu şehirde hiç sıkılmıyor insan, değil mi?' } },

    -- yakından geçerken (baloncuk)
    ambient_known = { default = { 'Selam %p%!', 'Hey %p%, naber?', '%hello% %p%!', 'Selamlar %p%!' } },
    ambient_friend = { default = { '%p%! Nereye böyle?', 'Selaaam %p%!', '%p%! Uğrasana bir ara.', 'Hey %p%, bekle bir saniye!' } },
    ambient_cold = { default = { 'Hıh.', '...', 'Tsk.' } },

    -- SMS'e özel
    sms_unknown = { default = { 'Kimsiniz? Bu numarayı tanımıyorum.', 'Pardon, kim bu?', 'Numaran kayıtlı değil, kimsin?' } },
    sms_recognized = { default = { 'Aa, %p%! Numaranı kaydettim.', '%p% sen misin? Tamam, kaydettim.' } },
    sms_sleepy = { default = { 'Uyuyordum, telefonun sesine uyandım...', 'Uykuluyum, kusura bakma.', 'Gece gece... neyse.', 'Az önce uyandım.' } },

    -- =================================================================
    -- REHİNE
    -- =================================================================
    hostage_taken = { default = { 'Tamam tamam! Ne istersen yaparım, lütfen!', 'Yapma! Lütfen canımı yakma!', 'Ne istiyorsun?! Lütfen, ateş etme!', 'Tamam, sakin ol... bir şey yapmıyorum!' } },
    hostage_plead = {
        hold = { 'Lütfen... ailem var...', 'Silahı indir, lütfen...', 'Kimseye bir şey söylemem, yemin ederim!', 'Nefes alamıyorum... biraz gevşet.', 'Ne istiyorsan veririm!' },
        escort = { 'Tamam, yürüyorum... yürüyorum.', 'Nereye götürüyorsun beni?', 'Lütfen bırak beni, kimseye bir şey demem.', 'Ellerim yukarıda, bak!' },
        kneel = { 'Lütfen... bir şey yapma...', 'Dizlerim ağrıyor... ne zaman bitecek bu?', 'Ailemi bir daha görebilecek miyim?', 'Kıpırdamıyorum, bak kıpırdamıyorum!' },
        vehicle = { 'Nereye gidiyoruz? Lütfen söyle!', 'Beni bir yere bırak, kimseye bir şey demem!', 'Lütfen yavaş... korkuyorum.' },
    },
    hostage_greet = { default = { 'N-ne istiyorsun benden?!', 'Lütfen... ne istersen söyle, yeter ki canımı yakma.', 'Konuşuyorum, konuşuyorum! Ne istiyorsun?' } },
    hostage_threat = { default = { 'Hayır hayır hayır! Lütfen yapma!', 'Tamam! Ne dersen yaparım, yeter ki yapma!', 'Yalvarırım, yapma!' } },
    hostage_calm = { default = { 'S-sakin olmaya çalışıyorum... ama kafama silah dayamışsın!', 'Söz mü? Bana bir şey yapmayacak mısın?', 'Tamam... tamam. Nefes alıyorum.', 'Nasıl sakin olayım?! ...Peki, peki.' } },
    hostage_money = { default = { 'Param yok! Cüzdanım evde, yemin ederim!', 'Sadece üstümde biraz bozukluk var, al hepsini!', 'Para mı? Bende yok ama bulurum, yeter ki bırak!' } },
    hostage_silence = { default = { 'Kimseye söylemem! Yemin ederim, kimseye!', 'Polisi aramam, söz! Yeter ki bırak beni.', 'Ağzımı açmam, seni hiç görmedim, tamam mı?' } },
    hostage_name = { default = { 'A-adım %me%... lütfen...', '%me%! Adım %me%! Ne yapacaksın adımı?' } },
    hostage_phone = { default = { 'Telefonum mu? Al, al! Ne istersen!', 'Kimseyi aramıyorum, bak telefonum cebimde!' } },
    hostage_hope = { default = { 'Gerçekten mi? Bırakacak mısın? Lütfen...', 'Söz ver... lütfen söz ver.', 'Tamam, ne dersen yaparım, yeter ki bırak.' } },
    hostage_insult = { default = { 'Tamam... haklısın... lütfen...', 'Özür dilerim, ne yaptıysam özür dilerim!' } },
    hostage_how = { default = { 'Nasıl olayım?! Kafama silah dayamışsın!', 'Korkudan titriyorum, görmüyor musun?' } },
    hostage_family = { default = { '%t_family% Lütfen... beni bekliyorlar.', 'Ailem var... lütfen, onları bir daha görmek istiyorum.' } },
    hostage_job = { default = { 'Ben sadece bir %job%, kimseye bulaşmam!', 'Sıradan bir çalışanım, param da yok, lütfen!' } },
    hostage_hurt = { default = { 'Ah! Yapma, lütfen!', 'Tamam! Tamam, uslu duruyorum!', 'Canım yanıyor... lütfen!' } },
    hostage_escape = { default = { 'İmdat! Yardım edin!', 'Kurtuldum! Polis! Polis!', 'Yardım edin! Rehin alınmıştım!' } },
    hostage_freed = { default = { 'T-teşekkürler... gidiyorum, gidiyorum!', 'Kimseye söylemeyeceğim! ...İmdat!', 'Bırakıyor musun? Tamam, gidiyorum!' } },
    hostage_recognize = { default = { 'Sen! Beni rehin alan sendin! İmdat!', 'Bu o! Beni rehin alan kişi! Polis!', 'Uzak dur benden! Yardım edin!' } },
}

-- =====================================================================
-- SOHBET TEPKİLERİ — SON KONUYA GÖRE
-- anahtarlar: why, really, agree, ack, impressed, sympathy, me_too, tell_more, dont_know, how_long
-- (yer tutucusu boş kalacak cümle atlanır; hiç uygun cümle yoksa genel fu_* cümlesi kullanılır)
-- =====================================================================
SCDialogue.Followups = {
    job = {
        why = { 'Neden mi? %t_work%', 'Başka ne yapacaktım, alıştım artık bu işe.', 'Ekmek parası işte, seçme şansım pek olmadı.' },
        really = { 'Evet, %job%. Şaşırdın mı?', 'Valla, kaç yıldır bu işteyim.' },
        tell_more = { '%t_work%', 'Her gün aynı: sabah gel, akşam git. Ama arada güzel anlar da oluyor.', 'İşin iyi yanı insanlarla tanışmak, kötü yanı yorgunluk.' },
        how_long = { '%years% yıldır bu işteyim.', 'Yaklaşık %years% yıl oldu. Zaman nasıl geçti anlamadım.' },
        impressed = { 'Sağ ol, herkes öyle düşünmüyor ama.', 'Öyle söyleyince güzel oluyor, sağ ol.' },
        sympathy = { 'Evet, bazen çok yoruyor ama idare ediyorum.' },
        me_too = { 'Sen de mi aynı sektördesin? Dünya küçük!', 'Öyle mi? O zaman ne demek istediğimi anlarsın.' },
        agree = { 'Değil mi? Çalışmadan olmuyor.' },
    },
    pjob = {
        why = { 'Merak ettim sadece, zor bir iş gibi geldi.' },
        tell_more = { 'Anlatsana, nasıl bir iş bu?', 'Zor mu peki? Merak ettim.' },
        really = { 'Evet, gerçekten merak ettim. Nasıl gidiyor?' },
        agree = { 'Kolay değil tabii, kolay gelsin.' },
    },
    family = {
        why = { 'Hayat işte, herkes bir yere dağıldı.', 'Öyle denk geldi, ne yapalım.' },
        tell_more = { '%t_family%', 'Ailem benim her şeyim ama anlatması uzun sürer.' },
        sympathy = { 'Sağ ol... bazen özlüyorum.', 'Öyle işte, idare ediyoruz.' },
        me_too = { 'Seninkiler de mi uzakta? Zor oluyor değil mi?', 'Anlıyorsun o zaman beni.' },
        impressed = { 'Evet, iyi bir ailem var, şanslıyım.' },
    },
    hobby = {
        why = { 'Kafamı boşaltıyor, o yüzden.', 'Başka türlü bu şehrin stresine dayanılmaz.' },
        tell_more = { 'Özellikle %hobby1%... saatlerce yapabilirim.', 'Bir ara %hobby1% yaparken beni görmelisin, başka biri oluyorum.' },
        me_too = { 'Sen de mi? Bir ara beraber yapalım o zaman!', 'Harika! Nihayet anlayan biri.' },
        impressed = { 'Değil mi? Denemelisin.', 'Çok keyifli, gerçekten.' },
        really = { 'Evet, bayılırım. Neden şaşırdın?' },
        how_long = { 'Çocukluğumdan beri. Bırakamadım bir türlü.', 'Birkaç yıldır, ama bağımlısı oldum.' },
    },
    plike = {
        why = { 'Sorduğum için mi? Ben de merak ettim işte.' },
        tell_more = { 'Anlatsana, ne zamandır seviyorsun bunu?', 'Nasıl başladın buna?' },
        me_too = { 'Oo, anlaşacağız biz!' },
    },
    dream = {
        why = { 'Çünkü hayatta bir kez yaşıyoruz, değil mi?', 'Hep istedim, içimde kaldı.' },
        tell_more = { '%t_dream% Bir gün olacak, göreceksin.', 'Düşünüyorum, planlıyorum... bir gün.' },
        really = { 'Evet, gerçekten. Gülme ama!', 'Ciddiyim, bir gün olacak.' },
        impressed = { 'Sağ ol, destek olman güzel.' },
        agree = { 'Değil mi? Hayal kurmadan olmaz.' },
        me_too = { 'Senin de mi? O zaman birbirimize destek oluruz.' },
    },
    origin = {
        tell_more = { '%t_origin% Oraları özlüyorum bazen.', 'Küçük bir yer ama huzurlu. Burası gibi değil.' },
        why = { 'İş için geldim, sonra kaldım işte.', 'Fırsat için. Herkes gibi.' },
        me_too = { 'Hemşehri misin yoksa?', 'Sen de mi oralısın? Vay!' },
        really = { 'Evet, oralıyım. Şaşırdın mı?' },
    },
    porigin = {
        tell_more = { 'Oralar nasıl, anlatsana?', 'Neden taşındın buraya?' },
        why = { 'Merak ettim, sohbet işte.' },
    },
    food = {
        why = { 'Bilmem, çocukluktan kalma bir alışkanlık.', 'Tadı başka, ne diyeyim.' },
        me_too = { 'Sen de mi? Bir gün beraber yiyelim o zaman.' },
        tell_more = { '%t_food% Ama iyi yapılmışı lazım.' },
    },
    music = {
        why = { 'Ruhuma iyi geliyor.', 'Başka türlü trafik çekilmez.' },
        me_too = { 'Sen de mi? Güzel zevk!', 'Oo, playlistlerimizi değişelim o zaman.' },
        tell_more = { '%t_music% Sesini de sonuna kadar açarım.' },
    },
    weather = {
        agree = { 'Değil mi? Bu hava insanın modunu etkiliyor.' },
        really = { 'Evet, baksana dışarı.' },
    },
    news = {
        really = { 'Evet, ben de duyunca şaşırdım.', 'Valla herkes onu konuşuyor.' },
        tell_more = { 'Daha fazlasını bilmiyorum, duyduğum bu kadar.', 'Detayını bilmiyorum, dikkatli ol yeter.' },
        why = { 'Bilmiyorum, bu şehirde her şey olur.' },
        sympathy = { 'Evet, çok kötü. Bu şehir bazen korkutuyor beni.' },
    },
    today = {
        tell_more = { 'Başka pek bir şey yok, sıradan bir gün.', 'Bir de yolda trafiğe takıldım, o kadar.' },
        sympathy = { 'Evet, yorucu bir gündü ama geçti.' },
        me_too = { 'Senin günün de mi öyle geçti? Hepimiz aynı gemideyiz.' },
    },
    joke = {
        ack = { 'Güldün mü? Gülmedin... Neyse.', 'Tamam, çok komik değildi belki.' },
        why = { 'Nedeni yok, fıkra işte!' },
        agree = { 'Değil mi? Ben de her seferinde gülüyorum.' },
    },
    city = {
        why = { 'Her gün başka bir olay oluyor burada.', 'Trafiği, fiyatları... her şeyi.' },
        agree = { 'Değil mi? Herkes aynı şeyi söylüyor.' },
        tell_more = { 'Gece olunca şehir başka bir yere dönüşüyor, hem güzel hem tehlikeli.' },
    },
    plans = {
        why = { 'Öyle denk geldi, programım belli.' },
        me_too = { 'Sen de mi? Belki karşılaşırız.' },
    },
    pet = {
        why = { 'Hayvanlar insanlardan daha dürüst.' },
        me_too = { 'Senin de mi var? Resmini göster bir ara!' },
        impressed = { 'Değil mi? Çok tatlı.' },
    },
    sport = {
        me_too = { 'Oo, bir ara beraber izleyelim o zaman!' },
        why = { 'Heyecan veriyor, o yüzden.' },
    },
    movie = {
        me_too = { 'Sen de mi seversin? Bir ara film gecesi yapalım.' },
        why = { 'Gerçek hayattan biraz kaçmak iyi geliyor.' },
    },
    car = {
        why = { 'Bu şehirde arabasız yaşamak zor.' },
        impressed = { 'Değil mi? Eski ama iş görür.' },
    },
    mood = {
        why = { 'Neden mi? %reason%', 'Bilmem, bugün öyle bir gün. %reason%' },
        tell_more = { '%reason% Ama geçer, dert etme.', 'Anlatsam uzun... %reason%' },
        sympathy = { 'Sağ ol, iyi geldi sorman.', 'Teşekkürler, düzelirim.' },
        me_too = { 'Sen de mi? Hepimiz aynı durumdayız galiba.', 'Bak sen, ortak derdimiz varmış.' },
        really = { 'Evet, gerçekten. %reason%' },
    },
    feeling = {
        why = { '%reason%', 'Bilmiyorum... %reason%' },
        sympathy = { 'Sağ ol, sorman iyi geldi.', 'Teşekkürler, düzelirim inşallah.' },
        tell_more = { '%reason% Ama boş ver, sen nasılsın?' },
    },
    pmood_bad = {
        tell_more = { 'Anlat bakalım, ne oldu?', 'İçini dök, dinliyorum.' },
        why = { 'Merak ettim, belki yardımım dokunur.' },
    },
    pmood_good = {
        why = { 'Keyfin yerinde olunca insanın içi açılıyor, o yüzden sevindim.' },
    },
    doing = {
        why = { 'İş işte, yapmak zorundayım.', 'Canım öyle istedi.' },
        tell_more = { 'Başka bir şey yok, öyle takılıyorum.' },
    },
    fav = {
        why = { 'Orada kendimi rahat hissediyorum.', 'Atmosferi güzel, insanları da.' },
        me_too = { 'Sen de mi seviyorsun? Belki orada karşılaşırız.' },
    },
    pfav = {
        why = { 'Merak ettim, belki ben de giderim.' },
    },
    age = {
        really = { 'Evet, göstermiyorum değil mi?', 'Evet, şaşırdın mı?' },
    },
    home = {
        why = { 'İşe yakın, kirası da uygun.' },
    },
    secret = {
        really = { 'Evet... ama kimseye söyleme!', 'Gerçekten. Sana güvendiğim için söyledim.' },
        why = { 'Uzun hikâye, bir gün anlatırım.' },
    },
}

-- =====================================================================
-- SAKİNİN SOHBETİ SÜRDÜRMEK İÇİN SORDUĞU SORULAR
-- fact: bu bilgi zaten biliniyorsa sorulmaz; minStage: en az bu aşamada sorulur
-- =====================================================================
SCDialogue.NpcQuestions = {
    { kind = 'origin', fact = 'origin', lines = { 'Bu arada sen buralı mısın?', 'Sen nerelisin?', 'Aslen nerelisin sen?' } },
    { kind = 'likes', fact = 'likes', lines = { 'Sen boş zamanlarında ne yaparsın?', 'Senin hobilerin neler?', 'Sen neleri seversin?' } },
    { kind = 'job', fact = 'job', lines = { 'Sen ne iş yapıyorsun bu arada?', 'Peki sen ne iş yaparsın?' } },
    { kind = 'player_day', lines = { 'Senin günün nasıl geçti?', 'Senden ne haber, bugün neler yaptın?' } },
    { kind = 'plans', minStage = 'acquaintance', lines = { 'Bu akşam ne yapıyorsun?', 'Hafta sonu için planın var mı?' } },
    { kind = 'fav_place', fact = 'fav_place', lines = { 'Buralarda en sevdiğin yer neresi?', 'En çok nerede takılırsın?' } },
}

-- Tanıdığı oyuncuyu karşılarken onun hakkında bildiklerinden bahsetme
SCDialogue.FactRecall = {
    job = { 'İşler nasıl, hâlâ %fact_job% olarak mı çalışıyorsun?', '%fact_job% işleri nasıl gidiyor?' },
    like = { 'Geçen sefer "%fact_like%" demiştin, hâlâ öyle mi?' },
    origin = { '%fact_origin% tarafından haber var mı?', 'Memleketi özlüyor musun? %fact_origin% demiştin.' },
    mood_bad = { 'Geçen sefer keyfin yoktu, şimdi daha iyi misin?', 'Geçen görüşmemizde moralin bozuktu, düzeldi mi?' },
    fav = { 'Yine %fact_fav% tarafına gittin mi?' },
}

-- Fıkralar / espriler
SCDialogue.Jokes = {
    'Adamın biri gülmüş, saksıya dikmişler.',
    'Diyete başladım, üç günde kaybettiğim tek şey sabrım oldu.',
    'Trafik o kadar sıkışıktı ki yanımdaki adamla arkadaş olduk, düğününe davetliyim.',
    'Bu şehirde hava o kadar sıcak ki dün bir dondurma gördüm, gölgeye kaçıyordu.',
    'Temel doktora gitmiş: "Nereme dokunsam ağrıyor." Doktor bakmış: "Parmağın kırık Temel."',
    'Yolda bir dolar buldum, sevindim. Sonra fark ettim ki benimmiş.',
    'Balıkçıya sormuşlar: "Balıklar neden ağa takılıyor?" "İnternetleri yok, başka nereye takılsınlar?"',
    'Arkadaşım "Bana bir kelimeyle kendini anlat" dedi. "Kısa" dedim, anlamadı.',
    'Sabah alarmı kurmayı unuttum, alarm da beni unuttu. Karşılıklı anlaştık yani.',
    'Kira öyle arttı ki ev sahibi artık bana "kiracım" değil "sponsorum" diyor.',
    'Spor salonuna yazıldım, bir ay oldu. Hâlâ gitmedim ama kartım çok formda.',
    'Adam kör olmuş, gözlükçüye gitmiş. Gözlükçü "Bak şu levhaya" demiş. Adam: "Hangi levha?"',
    'Telefonum o kadar eski ki şarj aletini görünce heyecandan kapanıyor.',
    'Kahveyi bıraktım dedim, üç saat sonra kahve beni geri aldı.',
}

-- Sakin başına sabit (kimliğinden türetilen) kişisel cevaplar
SCDialogue.Personal = {
    pet = {
        'Bir kedim var, adı Pamuk. Evin asıl sahibi o.',
        'Evcil hayvanım yok ama bir köpek sahiplenmeyi çok istiyorum.',
        'Balkonda bir muhabbet kuşum var, sabahları beni o uyandırıyor.',
        'Hayvanlara bayılırım ama ev sahibi izin vermiyor.',
        'Köpeğim Karabaş var, benden daha çok kişisi var.',
        'Hayvanlardan biraz çekinirim açıkçası.',
    },
    sport = {
        'Futbol izlerim ama takım tutmam, iyi oynayan kazansın.',
        'Basketbol severim, hafta sonları sahada top atarım.',
        'Spor mu? Kumandayı kaldırmak sayılıyorsa evet.',
        'Sabahları koşuya çıkarım, günümü öyle açarım.',
        'Maçları kaçırmam, bağırmaktan sesim kısılır.',
        'Spordan çok anlamam ama arada yüzmeye giderim.',
    },
    movie = {
        'Aksiyon filmlerine bayılırım, patlama yoksa izlemem.',
        'Romantik komedi severim, gülmeye ihtiyacım var.',
        'Korku filmi izleyemem, gece uyuyamıyorum sonra.',
        'Belgesel izlerim genelde, bir şey öğrenmek hoşuma gidiyor.',
        'Eski filmleri severim, siyah beyaz olanları bile.',
        'Dizi bağımlısıyım, bir başlayınca sabahı ediyorum.',
    },
}

-- Oyuncunun sakine karşı geçmiş eylemleri (doğrudan yaşadığı) — ikinci şahısla hatırlatma
SCDialogue.Accuse = {
    aim_weapon = { 'Sen bana silah doğrultmuştun! Ne istiyorsun yine?', 'Bana silah doğrultan sen değil misin? Uzak dur!' },
    threatened = { 'Beni tehdit etmiştin, unutmadım.', 'Geçen sefer beni tehdit ettin, yaklaşma.' },
    gunshot_near = { 'Yanımda silah patlatan sendin, değil mi?' },
    hit_by_vehicle = { 'Bana arabayla çarpan sendin! Hâlâ canım acıyor.' },
    assaulted = { 'Bana saldıran sendin! Yaklaşma!' },
    killed = { 'Beni hastanelik eden sensin! Git buradan!' },
    car_stolen = { 'Arabamı çalan sendin! Polise bildirdim!' },
    missed_appointment = { 'Geçen sefer beni ektin, boşuna bekledim.' },
    harassment = { 'Bana hakaret eden sendin, unutmadım.' },
    kidnapped = { 'Beni silah zoruyla rehin alan sendin! Uzak dur!', 'Sen... Sen beni rehin almıştın! Yaklaşma bana!' },
    saw_aim = { 'Geçen gün birine silah doğrulttuğunu gördüm. Senden korkuyorum.' },
    saw_assault = { 'Birine saldırdığını gördüm, yaklaşma bana.' },
    saw_kill = { 'Birini yaraladığını gözümle gördüm! Git buradan!' },
    saw_hostage = { 'Birini rehin aldığını gördüm! Senden korkuyorum.', 'Sen o rehin alan kişisin! Uzak dur!' },
}

-- İyi anılar
SCDialogue.Recall = {
    gift = { 'Geçen sefer bana hediye vermiştin, çok sevinmiştim.' },
    met_appointment = { 'Geçen buluşmamız çok güzeldi.' },
    saved = { 'Sen hayatımı kurtardın, sana borçluyum.' },
}

-- Başkasından duyduğu (dedikodu) — %other% anlatan sakin
SCDialogue.GossipAccuse = {
    aim_weapon = { '%other% anlattı, ona silah doğrultmuşsun. Senden uzak durmam lazım.', '%other% ile aranızda ne oldu? Silah çekmişsin diyorlar.' },
    saw_aim = { '%other% anlattı, birine silah doğrultmuşsun. Uzak dur benden.' },
    saw_assault = { '%other% anlattı, birine saldırmışsın.' },
    saw_kill = { '%other% anlattı, birini yaralamışsın. Senden korkuyorum.' },
    threatened = { '%other% anlattı, onu tehdit etmişsin. Hiç hoş değil.' },
    assaulted = { '%other% anlattı, ona saldırmışsın!' },
    hit_by_vehicle = { '%other% anlattı, ona arabayla çarpmışsın.' },
    killed = { '%other% hastanelik olmuş, senin yüzünden diyorlar.' },
    car_stolen = { '%other% anlattı, arabasını sen çalmışsın!' },
    harassment = { '%other% anlattı, ona hakaret etmişsin.' },
    saved = { '%other% anlattı, onun hayatını kurtarmışsın. Helal olsun.' },
    kidnapped = { '%other% anlattı, onu rehin almışsın! Uzak dur benden.', 'Herkes konuşuyor, %other% rehin alınmış... sen yapmışsın!' },
    saw_hostage = { '%other% anlattı, birini silah zoruyla rehin almışsın.' },
}

-- =====================================================================
-- SUNUCUYA ÖZEL HAZIR SORU-CEVAPLAR
-- patterns: niyet desenleri (katlanmış). lines: cevaplar. stage: en az bu aşamada cevaplar (opsiyonel)
-- residents: sadece bu sakinler cevaplar (opsiyonel, id listesi)
-- =====================================================================
SCDialogue.Custom = {
    {
        id = 'ask_police',
        patterns = { 'polis nerede', 'karakol', 'polise nasil' },
        lines = { 'Karakol Mission Row tarafında. Başın dertte mi?' },
    },
    {
        id = 'ask_hospital',
        patterns = { 'hastane nerede', 'doktor lazim', 'yaraliyim' },
        lines = { 'Pillbox Hill Hastanesi en yakını. Acilse hemen git!' },
    },
    {
        id = 'ask_job_offer',
        patterns = { 'is ariyorum', 'is var mi', 'eleman ariyor' },
        lines = { 'İş mi arıyorsun? Şehir merkezindeki iş ilanlarına bir bak derim.', 'Bizim oralarda arada eleman arıyorlar, bir sor istersen.' },
    },
}

-- Konuşma panelindeki hızlı cevap düğmeleri
SCDialogue.Suggestions = {
    base = { 'Nasılsın?', 'Ne yapıyorsun?', 'Ne iş yapıyorsun?', 'Hobilerin neler?', 'Bir fıkra anlat', 'Bu akşam ne yapıyorsun?', 'Buralarda iyi bir yer önerir misin?', 'Nerelisin?' },
    stranger = { 'Adın ne?', 'Benim adım %name%.' },
    known = { 'Numaranı alabilir miyim?', 'Bugün ne yaptın?', 'Beni hatırlıyor musun?' },
    friend = { 'Buluşalım mı?', 'Ne var ne yok, yeni bir şey duydun mu?' },
    yesno = { 'Olur', 'Olmaz' },
    bye = { 'Görüşürüz' },
    -- sakin bir soru sorduysa önerilen cevaplar
    answer = {
        player_mood = { 'İyiyim, sen?', 'Fena değil', 'Pek iyi değilim' },
        name = { 'Benim adım %name%.' },
        origin = { 'Buralıyım.', 'Bilmiyorum' },
        player_day = { 'İyi geçti, seninki?', 'Yorucuydu' },
        plans = { 'Bir planım yok, sen?', 'Çalışacağım' },
        share = { 'Anlatayım', 'Boş ver' },
    },
    -- son konuya göre devam önerileri
    followup = {
        job = { 'Ne zamandır yapıyorsun?', 'Zor mu?' },
        family = { 'Sık görüşüyor musunuz?' },
        hobby = { 'Ben de severim!', 'Anlat biraz' },
        dream = { 'Neden?', 'Bence yaparsın!' },
        origin = { 'Oraları özlüyor musun?' },
        mood = { 'Neden?', 'Geçmiş olsun' },
        feeling = { 'Neden?', 'Geçmiş olsun' },
        joke = { 'Hahaha!', 'Bir tane daha anlat' },
        news = { 'Gerçekten mi?', 'Anlat biraz' },
        city = { 'Haklısın', 'Neden?' },
        pmood_bad = { 'Anlatayım', 'Boş ver' },
    },
    hostage = { 'Sakin ol', 'Paranı ver', 'Kimseye söylemeyeceksin', 'Adın ne?', 'Seni bırakacağım' },
}
