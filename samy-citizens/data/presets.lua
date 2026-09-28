--[[
    YENİ SAKİN KALIPLARI (yönetim paneli: Sakinler -> Yeni sakin -> Kalıp seç)
    Her kalıp seçildiğinde bu listelerden rastgele bir taslak üretilir; panelde istediğin gibi değiştirip kaydedersin.
    Pools: formdaki "hazır seçenek" listeleri (özellik / hobi / konuşma tarzı / hazır cevaplar). İstediğin kadar ekle.

    Kalıp alanları:
      gender   : 'male' | 'female' | nil (ikisi de olabilir)
      age      : { en az, en çok }
      models   : { male = {...}, female = {...} }   ped modelleri
      traits   : kişilik özelliği adayları (5 tanesi seçilir)
      speech   : konuşma tarzı adayları (biri seçilir)
      hobbies  : hobi adayları (3 tanesi seçilir)
      job      : { titles = {...}, types = { konum tipleri (iş yeri) }, routine, shift = { 'SS:DD', 'SS:DD' }, workdays = {...} }
      topics   : hazır cevap adayları (job, work_opinion, family, dream, food, music, secret)
      car      : araba olma olasılığı (0-1), cars: model adayları
]]
SCPresets = {}

SCPresets.Archetypes = {
    {
        id = 'cheerful_waiter', label = 'Neşeli garson', age = { 20, 32 },
        models = { male = { 'a_m_y_hipster_01', 'a_m_y_genstreet_01', 'a_m_y_stbla_02' }, female = { 'a_f_y_hipster_02', 'a_f_y_hipster_01', 'a_f_y_genhot_01' } },
        traits = { 'neşeli', 'konuşkan', 'enerjik', 'esprili', 'sabırsız', 'iyimser', 'sıcakkanlı', 'meraklı' },
        speech = { "Hızlı ve samimi konuşur; 'yaa', 'kanka' gibi sözler kullanır, takılmayı sever.", "Güler yüzlü konuşur, 'canım' diye hitap eder, çok soru sorar." },
        hobbies = { 'dans', 'fotoğraf çekmek', 'plaj voleybolu', 'konserlere gitmek', 'dizi izlemek', 'moda' },
        job = { titles = { 'Garson' }, types = { 'restaurant', 'cafe', 'bar' }, routine = 'day_worker', shift = { '10:00', '18:00' }, workdays = { 1, 2, 3, 5, 6 } },
        topics = {
            work_opinion = { 'Ayaklarım koptu ama müşterilerle takılmak çok eğlenceli.', 'Bahşişler iyi olunca dünya benim oluyor!' },
            dream = { 'Bir gün kendi kafemi açacağım, ismi bile hazır.', 'Dünyayı gezmek istiyorum, önce para biriktirmem lazım.' },
            secret = { 'Aslında gizli gizli oyunculuk seçmelerine gidiyorum.', 'Patronun kızıyla aramda bir şeyler var, kimse bilmiyor.' },
        },
        car = 0.2, cars = { 'blista', 'panto', 'issi2' },
    },
    {
        id = 'grumpy_mechanic', label = 'Huysuz tamirci', gender = 'male', age = { 35, 58 },
        models = { male = { 's_m_y_xmech_02', 's_m_m_autoshop_01', 'a_m_m_salton_02' } },
        traits = { 'huysuz', 'dürüst', 'sessiz', 'pratik', 'güvenilir', 'inatçı', 'sert' },
        speech = { "Az ve öz konuşur, lafı dolandırmaz; sinirlenince 'lan' der, homurdanır ama kalbi iyidir.", 'Teknik terimlerle konuşur, sabırsızdır, argo kaçırır.' },
        hobbies = { 'eski araba restore etmek', 'futbol izlemek', 'balık tutmak', 'motor yarışları', 'mangal' },
        job = { titles = { 'Oto tamircisi', 'Kaportacı', 'Motor ustası' }, types = { 'garage' }, routine = 'day_worker', shift = { '08:00', '17:00' }, workdays = { 1, 2, 3, 4, 5, 6 } },
        topics = {
            work_opinion = { 'Araba yalan söylemez, insanlardan iyidir.', 'İş iş. Yağ, benzin, ter.' },
            dream = { 'Eski Bison\'u toparlayıp oğlumla yola çıkmak.', 'Kendi dükkânımı açmak, kimseye hesap vermemek.' },
            secret = { 'Gençken sokak yarışlarına girerdim, bir kaza geçirdim.', 'Borcum var, dükkânı zor döndürüyorum.' },
        },
        car = 0.85, cars = { 'bison', 'sadler', 'rebel2', 'bobcatxl' },
    },
    {
        id = 'night_bartender', label = 'Gece barmeni', age = { 24, 40 },
        models = { male = { 'a_m_y_hipster_02', 'a_m_y_vinewood_01', 's_m_y_barman_01' }, female = { 'a_f_y_vinewood_04', 'a_f_y_hipster_04', 's_f_y_bartender_01' } },
        traits = { 'alaycı', 'sakin', 'iyi dinleyici', 'esprili', 'gececi', 'gizemli', 'soğukkanlı' },
        speech = { 'Dinlemeyi konuşmaktan çok sever; kısa, iğneleyici esprilerle cevap verir.', "Rahat ve samimi konuşur, 'dostum' diye hitap eder." },
        hobbies = { 'kokteyl denemek', 'plak toplamak', 'gece yürüyüşü', 'poker', 'gitar çalmak' },
        job = { titles = { 'Barmen' }, types = { 'bar' }, routine = 'night_bar', shift = { '18:00', '02:00' }, workdays = { 3, 4, 5, 6, 7 } },
        topics = {
            work_opinion = { 'Gece insanların gerçek yüzü çıkar, ben de izlerim.', 'Tezgâhın arkası en iyi psikoloğun koltuğudur.' },
            dream = { 'Kendi barımı açmak; küçük, loş, iyi müzikli.', 'Bir gün sahilde bir kulübe, gündüzleri uyku.' },
            secret = { 'Bir müşterinin sırrını biliyorum, söylesem şehir karışır.', 'Aslında alkol içmem, kimse inanmaz.' },
        },
        car = 0.5, cars = { 'buffalo', 'fugitive', 'kuruma' },
    },
    {
        id = 'tidy_accountant', label = 'Titiz memur / muhasebeci', age = { 28, 55 },
        models = { male = { 'a_m_y_business_02', 'a_m_m_business_01', 'a_m_y_business_01' }, female = { 'a_f_y_business_01', 'a_f_m_business_02', 'a_f_y_business_02' } },
        traits = { 'titiz', 'kibar', 'şüpheci', 'hırslı', 'içe dönük', 'ciddi', 'düzenli' },
        speech = { "Resmî ve ölçülü konuşur; 'açıkçası', 'efendim' gibi kalıplar kullanır.", 'Kibar ama mesafeli, cümlelerini tartarak kurar.' },
        hobbies = { 'fitness', 'borsa takibi', 'caz dinlemek', 'satranç', 'kitap okumak' },
        job = { titles = { 'Muhasebeci', 'Sigortacı', 'Banka memuru', 'Emlakçı' }, types = { 'office' }, routine = 'day_worker', shift = { '09:00', '18:00' }, workdays = { 1, 2, 3, 4, 5 } },
        topics = {
            work_opinion = { 'Rakamlar insanlar gibi değil, mantıklılar.', 'Terfi için akşamları da çalışıyorum açıkçası.' },
            dream = { 'Kırk yaşında emekli olup deniz kenarına yerleşmek.', 'Kendi danışmanlık firmamı kurmak.' },
            secret = { 'Aslında bu işten nefret ediyorum, müzisyen olmak istiyordum.', 'Borsada büyük para kaybettim, kimse bilmiyor.' },
        },
        car = 0.7, cars = { 'tailgater', 'schafter2', 'oracle', 'premier' },
    },
    {
        id = 'caring_nurse', label = 'Hemşire / sağlıkçı', age = { 24, 50 },
        models = { male = { 's_m_m_paramedic_01', 'a_m_y_business_03' }, female = { 's_f_y_scrubs_01', 'a_f_y_business_04' } },
        traits = { 'şefkatli', 'sabırlı', 'yorgun', 'dürüst', 'sakin', 'yardımsever', 'pratik' },
        speech = { 'Yumuşak ve sakin konuşur, karşısındakinin nasıl olduğunu hep sorar.', "Pratik ve net konuşur, 'geçmiş olsun' demeyi unutmaz." },
        hobbies = { 'yoga', 'kitap okumak', 'bahçecilik', 'yürüyüş', 'yemek yapmak' },
        job = { titles = { 'Hemşire', 'Paramedik', 'Doktor' }, types = { 'hospital' }, routine = 'night_nurse', shift = { '19:00', '07:00' }, workdays = { 1, 3, 5 } },
        topics = {
            work_opinion = { 'Nöbetler yorucu ama birinin hayatını kurtarınca her şeye değiyor.', 'Bu şehirde kurşun yarası artık sıradan oldu, üzücü.' },
            dream = { 'Bir gün köyümde küçük bir sağlık ocağı açmak.', 'Doktorluk okumak, hâlâ geç değil.' },
            secret = { 'Kan görünce hâlâ başım dönüyor, kimse bilmiyor.', 'Bir hastaya âşık olmuştum, hâlâ düşünüyorum.' },
        },
        car = 0.5, cars = { 'asea', 'ingot', 'primo' },
    },
    {
        id = 'taxi_driver', label = 'Geveze taksici / kurye', age = { 25, 60 },
        models = { male = { 'a_m_m_eastsa_01', 'a_m_m_socenlat_01', 'a_m_y_genstreet_01' }, female = { 'a_f_m_eastsa_01', 'a_f_y_eastsa_03' } },
        traits = { 'konuşkan', 'meraklı', 'esprili', 'sabırsız', 'sokak zekâlı', 'dedikoducu' },
        speech = { "Bol bol konuşur; 'bak şimdi' diye söze girer, 'abi/abla' diye hitap eder, argo kaçırır.", 'Her konuda fikri vardır, trafiğe söver, dedikoduya bayılır.' },
        hobbies = { 'futbol izlemek', 'radyo dinlemek', 'tavla', 'balık tutmak' },
        job = { titles = { 'Taksi şoförü', 'Kurye' }, types = { 'depot' }, routine = 'day_worker_roam', shift = { '10:00', '19:00' }, workdays = { 1, 2, 3, 4, 5, 6 } },
        topics = {
            work_opinion = { 'Şehrin her sokağını bilirim, trafiğin hepsini de.', 'Yolcusunu dinlersen hikâye biriktirirsin.' },
            dream = { 'Kendi plakamı almak, kimseye çalışmamak.', 'Emekli olunca memlekete dönmek.' },
            secret = { 'Bir yolcunun bıraktığı çantada para buldum, geri verdim ama pişmanım.', 'Ehliyetimin cezası var, polisten kaçıyorum.' },
        },
        car = 1.0, cars = { 'taxi', 'asea', 'emperor', 'stanier' },
    },
    {
        id = 'student', label = 'Genç öğrenci', age = { 18, 25 },
        models = { male = { 'a_m_y_hipster_01', 'a_m_y_beach_01', 'a_m_y_skater_01' }, female = { 'a_f_y_hipster_01', 'a_f_y_tourist_01', 'a_f_y_beach_01' } },
        traits = { 'meraklı', 'dağınık', 'hayalperest', 'enerjik', 'çekingen', 'idealist' },
        speech = { "Hızlı konuşur, İngilizce kelimeler karıştırır, 'aynen', 'resmen' der.", 'Çekingen konuşur, ısınınca çok konuşur.' },
        hobbies = { 'video oyunları', 'kaykay', 'müzik yapmak', 'anime izlemek', 'kodlama', 'basketbol' },
        job = { titles = { 'Üniversite öğrencisi' }, types = { 'school' }, routine = 'student', shift = { '09:00', '15:00' }, workdays = { 1, 2, 3, 4, 5 } },
        topics = {
            work_opinion = { 'Vizeler yaklaşınca resmen uyuyamıyorum.', 'Dersler sıkıcı ama kampüs güzel.' },
            dream = { 'Kendi oyunumu yapmak istiyorum.', 'Mezun olunca yurtdışına gideceğim.' },
            secret = { 'Aslında bölümümü sevmiyorum, ailem istedi diye okuyorum.', 'Bir derste kopya çekip yakalanmadım, hâlâ vicdan azabı.' },
        },
        car = 0.1, cars = { 'panto', 'faggio' },
    },
    {
        id = 'retired_teacher', label = 'Emekli öğretmen', age = { 62, 80 },
        models = { male = { 'a_m_o_genstreet_01', 'a_m_o_soucent_01', 'a_m_o_ktown_01' }, female = { 'a_f_o_genstreet_01', 'a_f_o_soucent_01', 'a_f_o_ktown_01' } },
        traits = { 'bilge', 'nazik', 'meraklı', 'nostaljik', 'sabırlı', 'dedikoducu' },
        speech = { "Ağır ve öğüt verircesine konuşur; 'evladım' diye hitap eder.", "Eski günleri anlatmayı sever, 'bizim zamanımızda' der." },
        hobbies = { 'bahçecilik', 'satranç', 'bulmaca çözmek', 'kuş beslemek', 'kitap okumak' },
        job = { titles = { 'Emekli öğretmen', 'Emekli memur' }, types = {}, routine = 'retiree', workdays = { 1, 2, 3, 4, 5 } },
        topics = {
            work_opinion = { 'Kırk yıl öğretmenlik yaptım, çocukların gözündeki ışığı özlüyorum.', 'Emeklilik güzel ama insan kendini boşta hissediyor.' },
            dream = { 'Torunlarımı okumuş, adam olmuş görmek.', 'Anılarımı kitap yapmak.' },
            secret = { 'Gençken bir öğrencimin sınav kâğıdını kaybettim, hâlâ unutamam.', 'Eşimden önce başka birine âşıktım.' },
        },
        car = 0.3, cars = { 'emperor', 'glendale', 'regina' },
    },
    {
        id = 'security_guard', label = 'Güvenlik görevlisi', gender = 'male', age = { 26, 55 },
        models = { male = { 's_m_m_security_01', 's_m_y_doorman_01', 'a_m_m_business_01' } },
        traits = { 'ciddi', 'soğukkanlı', 'sert', 'güvenilir', 'sessiz', 'dikkatli' },
        speech = { 'Kısa ve kesin konuşur, gözü hep etraftadır.', "Resmî konuşur, 'kardeşim' diye hitap eder." },
        hobbies = { 'fitness', 'boks', 'film izlemek', 'atış' },
        job = { titles = { 'Güvenlik görevlisi', 'Bekçi' }, types = { 'bar', 'office', 'shop' }, routine = 'night_bar', shift = { '18:00', '02:00' }, workdays = { 3, 4, 5, 6, 7 } },
        topics = {
            work_opinion = { 'Kapıda durmak kolay sanılır, her gece bir olay çıkar.', 'Bu işte gözün her şeyi görecek ama ağzın kapalı olacak.' },
            dream = { 'Kendi güvenlik şirketimi kurmak.', 'Polis olmak istiyordum, hâlâ düşünüyorum.' },
            secret = { 'Geçen ay kapıda tanıdığımı içeri aldım, kavga çıktı, kimse bilmiyor.', 'Karanlıktan korkarım, gülme.' },
        },
        car = 0.6, cars = { 'granger', 'baller', 'dubsta' },
    },
    {
        id = 'fisherman', label = 'Yaşlı balıkçı', gender = 'male', age = { 45, 72 },
        models = { male = { 'a_m_m_salton_01', 'a_m_o_salton_01', 'a_m_m_hillbilly_01' } },
        traits = { 'sabırlı', 'sakin', 'huysuz', 'doğa sever', 'az konuşan', 'dürüst' },
        speech = { "Ağır ağır konuşur, denizden örnekler verir, 'evlat' der.", 'Az konuşur ama söylediği yerine oturur.' },
        hobbies = { 'balık tutmak', 'ağ örmek', 'kuş gözlemek', 'radyo dinlemek' },
        job = { titles = { 'Balıkçı' }, types = { 'pier', 'beach' }, routine = 'fisherman', shift = { '05:00', '12:00' }, workdays = { 1, 2, 3, 4, 5, 6 } },
        topics = {
            work_opinion = { 'Deniz bana ekmek verdi, ben de ona saygı.', 'Eskisi gibi balık yok, deniz yoruldu.' },
            dream = { 'Kendi teknemi alıp açıklara gitmek.', 'Son günlerimi denize bakan bir evde geçirmek.' },
            secret = { 'Bir gece denizde bir şey gördüm, ne olduğunu hâlâ bilmiyorum.', 'Yüzme bilmiyorum, hiç öğrenemedim.' },
        },
        car = 0.4, cars = { 'bodhi2', 'rebel', 'sadler' },
    },
    {
        id = 'barista', label = 'Barista', age = { 19, 30 },
        models = { male = { 'a_m_y_hipster_03', 'a_m_y_hipster_02' }, female = { 'a_f_y_hipster_03', 'a_f_y_hipster_04' } },
        traits = { 'yaratıcı', 'rahat', 'sanatçı ruhlu', 'nazik', 'dalgın', 'iyimser' },
        speech = { "Sakin ve tatlı konuşur, 'ay çok iyi' der, kahveden bahsetmeye bayılır.", 'Esprili ve hafif alaycı konuşur.' },
        hobbies = { 'kahve demlemek', 'resim yapmak', 'plak dinlemek', 'bisiklet', 'fotoğraf çekmek' },
        job = { titles = { 'Barista' }, types = { 'cafe' }, routine = 'day_worker', shift = { '07:00', '15:00' }, workdays = { 1, 2, 3, 4, 6 } },
        topics = {
            work_opinion = { 'Güzel bir latte art yapınca günüm güzelleşiyor.', 'Sabah kuyruğu savaş gibi, sonra rahatlıyor.' },
            dream = { 'Kendi kavurmamı yaptığım küçük bir dükkân.', 'Resimlerimle bir sergi açmak.' },
            secret = { 'Aslında kahveyi sade sevmem, hep şekerli içerim.', 'Müşterilerin bardağına isimlerini yanlış yazıyorum, bilerek.' },
        },
        car = 0.15, cars = { 'faggio', 'panto' },
    },
    {
        id = 'gym_trainer', label = 'Spor hocası', age = { 22, 42 },
        models = { male = { 'a_m_y_musclbeac_01', 'a_m_y_musclbeac_02', 'a_m_y_beach_03' }, female = { 'a_f_y_fitness_01', 'a_f_y_fitness_02' } },
        traits = { 'enerjik', 'disiplinli', 'motive edici', 'kendini beğenmiş', 'dışa dönük', 'sabırsız' },
        speech = { "Enerjik konuşur, 'hadi', 'bir set daha' der, herkese spor önerir.", "Kendinden emin konuşur, 'kanka' diye hitap eder." },
        hobbies = { 'fitness', 'koşu', 'sağlıklı beslenme', 'plaj voleybolu', 'bisiklet' },
        job = { titles = { 'Antrenör', 'Spor hocası' }, types = { 'gym' }, routine = 'day_worker', shift = { '08:00', '16:00' }, workdays = { 1, 2, 3, 4, 5, 6 } },
        topics = {
            work_opinion = { 'İnsanların değiştiğini görmek gibisi yok.', 'Ocakta salon dolar, şubatta boşalır, her yıl aynı.' },
            dream = { 'Kendi salonumu açıp kendi programımı satmak.', 'Bir vücut geliştirme yarışması kazanmak.' },
            secret = { 'Gizlice abur cubur yiyorum, gece yarısı.', 'Aslında koşmaktan nefret ederim.' },
        },
        car = 0.6, cars = { 'sultan', 'buffalo', 'dominator' },
    },
    {
        id = 'street_hustler', label = 'Sokak çocuğu (argo)', gender = 'male', age = { 18, 30 },
        models = { male = { 'a_m_y_stbla_02', 'g_m_y_famca_01', 'a_m_y_stwhi_01', 'a_m_y_genstreet_02' } },
        traits = { 'argo', 'kaba', 'sokak zekâlı', 'sadık', 'dürtüsel', 'esprili', 'küfürbaz' },
        speech = { "Argo ve küfürlü konuşur; 'lan', 'kanka', 'amk' ağzından düşmez ama sadıktır.", "Sokak ağzıyla konuşur, 'birader' der, sataşmayı sever." },
        hobbies = { 'rap dinlemek', 'basketbol', 'araba modifiye', 'video oyunları', 'dövüş sporları' },
        job = { titles = { 'Kurye', 'Oto yıkamacı', 'Tezgâhtar' }, types = { 'depot', 'garage', 'shop' }, routine = 'day_worker_roam', shift = { '11:00', '19:00' }, workdays = { 1, 2, 3, 4, 5, 6 } },
        topics = {
            work_opinion = { 'İş iş lan, para kazanıyoz işte.', 'Patron salak ama maaşı veriyo, n\'apıcan.' },
            dream = { 'Bir gün rap albümü çıkarıcam, göreceksin.', 'Mahalleden çıkıp Vinewood\'da ev almak.' },
            secret = { 'Küçükken bir market soydum, ilk ve son. Kimseye deme lan.', 'Annemin haberi yok ama okulu bıraktım.' },
        },
        car = 0.35, cars = { 'blista2', 'futo', 'sultan', 'faction' },
    },
    {
        id = 'shy_artist', label = 'Çekingen sanatçı', age = { 20, 38 },
        models = { male = { 'a_m_y_hipster_01', 'a_m_y_indian_01' }, female = { 'a_f_y_hipster_01', 'a_f_y_indian_01' } },
        traits = { 'çekingen', 'hayalperest', 'duygusal', 'içe dönük', 'yaratıcı', 'utangaç' },
        speech = { 'Çekingen konuşur, cümlelerini yarım bırakır, ısınınca açılır.', "Yumuşak konuşur, 'şey...' diye söze başlar." },
        hobbies = { 'resim yapmak', 'gitar çalmak', 'şiir yazmak', 'fotoğraf çekmek', 'müze gezmek' },
        job = { titles = { 'Müzisyen', 'Ressam', 'Fotoğrafçı' }, types = { 'bar', 'cafe', 'park' }, routine = 'day_worker', shift = { '12:00', '20:00' }, workdays = { 2, 4, 5, 6 } },
        topics = {
            work_opinion = { 'Sanatla geçinmek zor ama başka türlü yaşayamam.', 'Barda çalınca kimse dinlemiyor, ama olsun.' },
            dream = { 'Bir gün kendi sergimi açmak.', 'Bir şarkımın radyoda çalması.' },
            secret = { 'Bir şarkıyı birine yazdım ama hiç veremedim.', 'Sahneye çıkmadan önce hep kusarım.' },
        },
        car = 0.2, cars = { 'faggio', 'issi2' },
    },
    {
        id = 'shopkeeper', label = 'Mahalle esnafı', age = { 40, 65 },
        models = { male = { 'a_m_m_indian_01', 'a_m_m_ktown_01', 'mp_m_shopkeep_01' }, female = { 'a_f_m_ktown_01', 'a_f_m_eastsa_02' } },
        traits = { 'cömert', 'konuşkan', 'dedikoducu', 'geleneksel', 'pazarlıkçı', 'sıcakkanlı' },
        speech = { "Esnaf ağzıyla konuşur; 'buyur abi', 'hoş geldin' der, herkesi tanır.", 'Pazarlık yapmayı sever, lafı uzatır.' },
        hobbies = { 'tavla', 'futbol izlemek', 'dedikodu', 'çay demlemek' },
        job = { titles = { 'Market sahibi', 'Kasiyer', 'Tezgâhtar' }, types = { 'shop' }, routine = 'day_worker', shift = { '08:00', '20:00' }, workdays = { 1, 2, 3, 4, 5, 6 } },
        topics = {
            work_opinion = { 'Bu mahallenin her şeyini bilirim, dükkân benim gözüm kulağım.', 'Büyük marketler bizi bitirdi ama müşterim sadık.' },
            dream = { 'Dükkânı oğluma devredip huzur içinde çay içmek.', 'Bir gün ikinci şubeyi açmak.' },
            secret = { 'Veresiye defterinde yarım mahallenin adı var, kimseye söylemem.', 'Bir gece kasadan para eksik çıktı, hâlâ kim aldı bilmiyorum.' },
        },
        car = 0.5, cars = { 'speedo', 'rumpo', 'emperor' },
    },
    {
        id = 'businessperson', label = 'Kibirli iş insanı', age = { 30, 55 },
        models = { male = { 'a_m_y_business_03', 'a_m_m_bevhills_01', 'a_m_m_bevhills_02' }, female = { 'a_f_m_bevhills_01', 'a_f_y_bevhills_01', 'a_f_m_business_02' } },
        traits = { 'hırslı', 'kendini beğenmiş', 'alaycı', 'kibar', 'soğuk', 'zeki' },
        speech = { 'Tepeden bakarak konuşur, vaktinin değerli olduğunu ima eder.', "Kurumsal konuşur, 'açıkçası', 'net olalım' der." },
        hobbies = { 'golf', 'şarap tatmak', 'yatçılık', 'borsa takibi', 'tenis' },
        job = { titles = { 'Yönetici', 'Avukat', 'Emlakçı' }, types = { 'office' }, routine = 'day_worker', shift = { '09:30', '19:00' }, workdays = { 1, 2, 3, 4, 5 } },
        topics = {
            work_opinion = { 'Bu şehirde para konuşur, gerisi susar.', 'Toplantılar, toplantılar... ama sonuç veriyor.' },
            dream = { 'Kendi gökdelenim, en üst katta ofisim.', 'Kırkımda emekli olup bir adada yaşamak.' },
            secret = { 'Şirket batmak üzere, herkes iyi gidiyor sanıyor.', 'Aslında yoksul bir mahallede büyüdüm, kimse bilmiyor.' },
        },
        car = 0.95, cars = { 'cognoscenti', 'baller2', 'felon', 'exemplar' },
    },
}

-- Formdaki hazır seçenek listeleri
SCPresets.Pools = {
    traits = { 'neşeli', 'sessiz', 'meraklı', 'şüpheci', 'esprili', 'sabırsız', 'sakin', 'konuşkan', 'çekingen', 'iyimser', 'alaycı',
        'titiz', 'dağınık', 'cömert', 'inatçı', 'duygusal', 'pratik', 'hayalperest', 'dürüst', 'huysuz', 'nazik', 'enerjik', 'kibar',
        'dışa dönük', 'içe dönük', 'sert', 'şefkatli', 'hırslı', 'tembel', 'dedikoducu', 'sadık', 'kıskanç', 'romantik', 'argo', 'kaba',
        'küfürbaz', 'utangaç', 'kendini beğenmiş', 'bilge', 'sokak zekâlı', 'soğukkanlı', 'yardımsever', 'yaratıcı', 'nostaljik' },
    hobbies = { 'futbol izlemek', 'kitap okumak', 'yemek yapmak', 'balık tutmak', 'fotoğraf çekmek', 'video oyunları', 'bahçecilik',
        'koşu', 'gitar çalmak', 'satranç', 'dans', 'film izlemek', 'araba modifiye', 'yürüyüş', 'yoga', 'resim yapmak', 'fitness',
        'tavla', 'rap dinlemek', 'basketbol', 'plaj voleybolu', 'golf', 'kahve demlemek', 'şiir yazmak', 'kuş gözlemek', 'boks',
        'konserlere gitmek', 'dizi izlemek', 'bisiklet', 'kodlama', 'kaykay', 'tenis', 'bulmaca çözmek', 'mangal' },
    speech = {
        'Sakin ve kısa konuşur, fazla detaya girmez.',
        "Hızlı ve samimi konuşur; 'yaa', 'kanka' gibi sözler kullanır.",
        "Kibar ve resmî konuşur; 'efendim' der.",
        'Esprili konuşur, her şeye bir laf yetiştirir.',
        'Çekingen konuşur, cümlelerini yarım bırakır.',
        "Bol bol konuşur; 'bak şimdi' diye söze girer, 'dostum' diye hitap eder.",
        "Argo ve küfürlü konuşur; 'lan', 'kanka' ağzından düşmez.",
        "Ağır ve öğüt verircesine konuşur; 'evladım' diye hitap eder.",
        "Esnaf ağzıyla konuşur; 'buyur abi', 'hoş geldin' der.",
        'Tepeden bakarak konuşur, vaktinin değerli olduğunu ima eder.',
        "Yumuşak ve tatlı konuşur, 'canım' diye hitap eder.",
        "Kurumsal konuşur, 'açıkçası', 'net olalım' der.",
    },
    values = { 'Aile, dürüstlük', 'Özgürlük, eğlence', 'Emek, sadakat', 'Başarı, düzen', 'Para, güç', 'Dostluk, vefa', 'Sanat, güzellik', 'Adalet, cesaret' },
    fears = { 'Yalnız kalmak', 'İşini kaybetmek', 'Hastalık', 'Borç', 'Karanlık', 'Unutulmak', 'Polis', 'Yaşlanmak', 'Başarısız görünmek' },
    origins = { 'Paleto Bay', 'Sandy Shores', 'Harmony', 'Chumash', 'Grapeseed', 'Liberty City', 'San Fierro', 'Vice City', 'Los Santos', 'Ludendorff' },
    family = { 'Ailem memlekette yaşıyor, sık sık arıyorum.', 'Bekârım, ailemle aram iyi.', 'Evliyim, küçük bir kızım var.', 'Boşandım, oğlumu hafta sonları görüyorum.',
        'Annemle yaşıyorum, babamı küçükken kaybettim.', 'Kalabalık bir aileden geliyorum, beş kardeşiz.', 'Ailemle aram pek iyi değil, konuşmuyoruz.' },
    dream = { 'Bir gün kendi işimi kurmak istiyorum.', 'Deniz kenarında küçük bir ev almak hayalim.', 'Dünyayı gezmek istiyorum.',
        'Biraz para biriktirip memlekete dönmek istiyorum.', 'Ünlü olmak, bir kere de olsa.', 'Çocuklarımı iyi okullarda okutmak.' },
    food = { 'Ev yemeği severim, özellikle kuru fasulye.', 'Hamburger derseniz hayır demem.', 'Deniz ürünlerine bayılırım.', 'Tatlıya zaafım var.',
        'Acılı taco, bol soslu.', 'Izgara et, yanında soğan.', 'Vejetaryenim, sebze yemekleri severim.' },
    music = { 'Arabesk dinlerim, dert ortağım.', 'Eski rock gruplarını severim.', 'Radyoda ne çıkarsa dinlerim.', 'Genelde rap dinliyorum.',
        'Caz, özellikle geceleri.', 'Pop, dans edebildiğim her şey.', 'Klasik müzik dinlerim, sakinleştiriyor.' },
    work_opinion = { 'İşim yorucu ama seviyorum.', 'Maaş az, iş çok... ama idare ediyoruz.', 'İş arkadaşlarım iyi, o yüzden katlanıyorum.',
        'Bu işi yıllardır yapıyorum, gözüm kapalı yaparım.', 'Patronum çekilmez biri ama ne yapalım.' },
    secret = { 'Aslında şarkı söylemeyi çok seviyorum ama kimse bilmiyor.', 'Bir süredir iş değiştirmeyi düşünüyorum, kimseye söyleme.',
        'Borçlarım var, biraz zor günler geçiriyorum.', 'Gençken yaptığım bir hatadan hâlâ utanıyorum.', 'Birine âşığım ama söyleyemiyorum.',
        'Evden kaçmıştım, ailemle yıllarca konuşmadım.', 'Geceleri uyuyamıyorum, kâbuslar görüyorum.', 'Piyangodan para çıktı, kimseye söylemedim.' },
    post_labels = { 'Kapı görevi', 'Bekçi kulübesi', 'Nöbet noktası', 'Resepsiyon', 'Otopark', 'Giriş kapısı', 'Seyyar satıcı tezgâhı' },
}
