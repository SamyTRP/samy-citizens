--[[
    MESLEK BİLGİSİ VE HİZMETLERİ
    Sakinin mesleği, meslek adından (job.title) anahtar kelimelerle otomatik algılanır.
      keywords : katlanmış (küçük harf, Türkçe karaktersiz) meslek adı parçaları
      services : 'order' (sipariş), 'heal' (tedavi), 'repair' (tamir), 'ride' (arabayla götürme)
      askLabel : "bunu bir ___ sor" cümlesi için (yönelme hâli)
      tips     : "işinle ilgili bir tavsiye ver" cevapları
      qa       : meslek soruları { patterns = {...}, lines = {...} } (desen yazımı data/dialogue.lua ile aynı)
      stories  : sakinin kendiliğinden anlattığı iş anıları
    Menüler iş yerinin konum tipine göre seçilir (bar, cafe, restaurant, fastfood, shop).
      item  : ox_inventory eşya adı (yoksa/verilemezse açlık-susuzluk metadata'sı artırılır)
      price : Config.JobServices.Charge açıksa ücret; kind: 'drink' | 'food'
]]
SCJobs = {}

SCJobs.Menus = {
    bar = {
        { key = 'bira', label = 'Bira', item = 'beer', price = 15, kind = 'drink', words = { 'bira', 'beer' } },
        { key = 'viski', label = 'Viski', item = 'whiskey', price = 35, kind = 'drink', words = { 'viski', 'whisk' } },
        { key = 'votka', label = 'Votka', item = 'vodka', price = 30, kind = 'drink', words = { 'votka', 'vodka' } },
        { key = 'sarap', label = 'Şarap', item = 'wine', price = 30, kind = 'drink', words = { 'sarap', 'wine' } },
        { key = 'tekila', label = 'Tekila', item = 'tequila', price = 30, kind = 'drink', words = { 'tekila', 'tequila', 'shot' } },
        { key = 'kokteyl', label = 'Kokteyl', item = 'cocktail', price = 40, kind = 'drink', words = { 'kokteyl', 'mojito', 'margarita', 'cocktail' } },
        { key = 'su', label = 'Su', item = 'water_bottle', price = 5, kind = 'drink', words = { 'su', 'suyu', 'water' } },
        { key = 'kola', label = 'Kola', item = 'ecola', price = 8, kind = 'drink', words = { 'kola', 'cola', 'gazoz' } },
    },
    cafe = {
        { key = 'kahve', label = 'Kahve', item = 'coffee', price = 10, kind = 'drink', words = { 'kahve', 'coffee', 'latte', 'espresso', 'cappuccino', 'americano', 'filtre' } },
        { key = 'cay', label = 'Çay', item = 'tea', price = 6, kind = 'drink', words = { 'cay', 'tea' } },
        { key = 'donut', label = 'Donut', item = 'donut', price = 8, kind = 'food', words = { 'donut', 'corek', 'tatli' } },
        { key = 'sandvic', label = 'Sandviç', item = 'sandwich', price = 12, kind = 'food', words = { 'sandvic', 'tost', 'sandwich' } },
        { key = 'su', label = 'Su', item = 'water_bottle', price = 5, kind = 'drink', words = { 'su', 'suyu', 'water' } },
    },
    restaurant = {
        { key = 'yemek', label = 'Günün yemeği', item = 'sandwich', price = 25, kind = 'food', words = { 'yemek', 'gunun', 'et', 'tavuk', 'balik', 'makarna', 'pizza' } },
        { key = 'corba', label = 'Çorba', item = 'sandwich', price = 12, kind = 'food', words = { 'corba' } },
        { key = 'sarap', label = 'Şarap', item = 'wine', price = 30, kind = 'drink', words = { 'sarap', 'wine' } },
        { key = 'su', label = 'Su', item = 'water_bottle', price = 5, kind = 'drink', words = { 'su', 'suyu', 'water' } },
    },
    fastfood = {
        { key = 'hamburger', label = 'Hamburger', item = 'burger', price = 15, kind = 'food', words = { 'hamburger', 'burger', 'kofte' } },
        { key = 'patates', label = 'Patates kızartması', item = 'fries', price = 8, kind = 'food', words = { 'patates', 'fries', 'cips' } },
        { key = 'kola', label = 'Kola', item = 'ecola', price = 6, kind = 'drink', words = { 'kola', 'cola', 'gazoz', 'sprunk' } },
        { key = 'su', label = 'Su', item = 'water_bottle', price = 5, kind = 'drink', words = { 'su', 'suyu', 'water' } },
    },
    shop = {
        { key = 'su', label = 'Su', item = 'water_bottle', price = 5, kind = 'drink', words = { 'su', 'suyu', 'water' } },
        { key = 'sandvic', label = 'Sandviç', item = 'sandwich', price = 10, kind = 'food', words = { 'sandvic', 'tost', 'sandwich' } },
        { key = 'sigara', label = 'Sigara', item = 'cigarettes', price = 12, kind = 'other', words = { 'sigara', 'cigarette' } },
        { key = 'kola', label = 'Kola', item = 'ecola', price = 6, kind = 'drink', words = { 'kola', 'cola', 'gazoz' } },
    },
}

-- Belirti -> tavsiye (sağlıkçı sakin ayrıntılı, diğerleri halk ağzıyla cevaplar)
SCJobs.Health = {
    { key = 'head', words = { 'basim', 'bas agri', 'migren', 'kafam agri' },
      medic = { 'Baş ağrısı için önce bol su iç, ekrandan uzak dur. Parasetamol alabilirsin ama günde dört tabletten fazla değil.', 'Tansiyonun da olabilir. Karanlık bir odada yarım saat uzan, geçmezse ölçtür.' },
      folk = { 'Başım ağrıyınca bir bardak su, biraz uyku. Bir de şakaklarını ovala.', 'Kahveyi azalt bence, bende öyle geçti.' } },
    { key = 'stomach', words = { 'midem', 'karnim', 'mide', 'bulan', 'kustum', 'ishal' },
      medic = { 'Mide için bugün hafif beslen: pirinç, muz, yoğurt. Bol sıvı al ki susuz kalmasın vücudun.', 'Kusma ya da ishal varsa en büyük tehlike susuzluk. Azar azar su iç, 24 saatte geçmezse gel muayene olalım.' },
      folk = { 'Nane-limon iç, iyi gelir.', 'Ağır yemek yeme bugün, yoğurt ye.' } },
    { key = 'fever', words = { 'ates', 'grip', 'nezle', 'oksur', 'bogaz', 'titriyorum' },
      medic = { 'Grip gibi görünüyor. Bol sıvı, dinlenme; ateş 38.5\'i geçerse ateş düşürücü al. Üç günde geçmezse gel.', 'Boğazın için tuzlu suyla gargara yap, ılık içecekler iç. Antibiyotiği kendi kafana göre alma!' },
      folk = { 'Ihlamur iç, sıkı giyin, yorgana gir. Sabaha bir şeyin kalmaz.', 'Bal-limon karışımı iç derim, annemin tarifi.' } },
    { key = 'sleep', words = { 'uyuyamiyorum', 'uykusuz', 'uyku' },
      medic = { 'Yatmadan bir saat önce telefonu bırak, kafein alma. Her gün aynı saatte yatıp kalkmaya çalış.', 'Uykusuzluk uzun sürüyorsa stresle ilgili olabilir. Akşam hafif bir yürüyüş iyi gelir.' },
      folk = { 'Ilık süt iç yatmadan önce, mışıl mışıl uyursun.', 'Ben de uyuyamıyorum bazen, kitap okuyunca geçiyor.' } },
    { key = 'back', words = { 'sirtim', 'belim', 'boynum', 'tutuldu' },
      medic = { 'Bel ağrısında ilk gün soğuk, sonra sıcak uygula. Ağır kaldırma, çok uzun da yatma, hafif hareket et.', 'Duruşuna dikkat et. Ağrı bacağına vuruyorsa mutlaka muayene olmalısın.' },
      folk = { 'Sıcak su torbası koy, rahatlarsın.', 'Masa başında çok oturuyorsun galiba, biraz yürü.' } },
    { key = 'burn', words = { 'yandim', 'yanik', 'haslandi' },
      medic = { 'Yanığı hemen 10-15 dakika soğuk (buzlu değil) suyun altında tut. Diş macunu, yoğurt sürme! Su toplarsa patlatma.', 'Yanık büyükse ya da yüzdeyse hemen acile git. Küçükse temiz bir gazlı bezle ört.' },
      folk = { 'Hemen soğuk suya tut, bir şey sürme bence.', 'Ay geçmiş olsun! Soğuk su, soğuk su.' } },
    { key = 'cut', words = { 'kestim', 'kesik', 'kaniyor', 'kanama' },
      medic = { 'Kesiği temiz bir bezle 10 dakika bastırarak tut, kanama durunca bol suyla yıka. Derinse dikiş gerekebilir.', 'Paslı bir şeyle kestiysen tetanos aşısı yaptırman lazım.' },
      folk = { 'Bastır bir bezle, yara bandı yapıştır. Geçer.', 'Kanıyorsa hastaneye git, şakaya gelmez.' } },
    { key = 'sprain', words = { 'burkuldu', 'bilegim', 'ayagim', 'kolum', 'bacagim', 'dizim' },
      medic = { 'Burkulmada kural basit: dinlendir, buz koy, sar ve yukarıda tut. Yirmi dakika buz, sonra ara ver.', 'Şişlik çok fazlaysa ya da üstüne basamıyorsan kırık olabilir, röntgen çekilmeli.' },
      folk = { 'Buz koy, fazla yürüme.', 'Sarkıt aşağı değil, yastığın üstüne koy ayağını.' } },
    { key = 'stress', words = { 'stres', 'panik', 'depresyon', 'bunaldim', 'kaygi', 'nefes alamiyorum' },
      medic = { 'Panik anında dört saniye nefes al, dört tut, dört saniyede ver. Yavaşlayınca geçer. Sık oluyorsa bir uzmana görün.', 'Stres bedene de vurur. Uyku, yürüyüş ve konuşabileceğin biri çok önemli.' },
      folk = { 'Derin nefes al, biraz deniz kenarında yürü.', 'Bazen konuşmak iyi gelir, anlat istersen.' } },
    { key = 'tooth', words = { 'disim', 'dis agri', 'dis eti' },
      medic = { 'Diş ağrısında ılık tuzlu suyla çalkala, ağrı kesici alabilirsin ama dişçiye gitmen şart.' },
      folk = { 'Karanfil çiğne, annemin yöntemi.', 'Dişçiye git, bekledikçe kötüleşir.' } },
    { key = 'allergy', words = { 'alerji', 'kasinti', 'hapsir' },
      medic = { 'Alerji için antihistaminik işe yarar. Nefes darlığı olursa hemen acile!' },
      folk = { 'Polenler uçuşuyor bu ara, bende de var.' } },
}

SCJobs.Categories = {
    {
        id = 'bar', keywords = { 'barmen', 'barmaid', 'bartender', 'barmeyd' }, askLabel = 'barmene', services = { 'order' }, suggest = 'drinks',
        tips = { 'Müşterinin ne içeceğini yüzünden anlarsın; yorgun olana bira, kutlama yapana kokteyl.', 'İyi barmen dinlemeyi bilir. İçki ikinci planda kalır.', 'Kokteylde denge önemli: tatlı, ekşi, sert. Biri fazla kaçarsa berbat olur.', 'Sarhoş müşteriye bir bardak su vermek en iyi hizmettir.' },
        qa = {
            { patterns = { 'hangi icki', 'ne icsem', 'ne onerirsin', 'en iyi icki', 'guzel bir icki' }, lines = { 'Yorgunsan soğuk bir bira; kutlama varsa mojito derim.', 'İlk kez geliyorsan evin kokteyline bir şans ver.' } },
            { patterns = { 'aksamdan kalma', 'hangover', 'kafam agir', 'basim dondu' }, lines = { 'Akşamdan kalmaya bol su, tuzlu bir şeyler ve uyku. Mucize yok.', 'Sabah bir çorba iç, bol su, ağrı kesici. Bir daha karıştırma içkileri!' } },
            { patterns = { 'kokteyl nasil', 'mojito nasil', 'kokteyl tarifi', 'kokteyl yap' }, lines = { 'Mojito: nane, lime, şeker, beyaz rom, soda. Naneyi ezme, hafif bastır yeter.', 'Kokteylin sırrı buz. Bol buz koy, çabuk sulanmaz.' } },
            { patterns = { 'bahsis' }, lines = { 'Bahşiş bu işin tuzu biberi. Gülümsemek bedava ama bahşişi getiriyor.' } },
        },
        stories = { 'Geçen gece bir müşteri on iki kokteyl içti, sonra bana evlenme teklif etti. Adını bile bilmiyordum!', 'Dün tezgâhta iki kişi kavga etti, araya girdim, sonra ikisi de bana içki ısmarladı.' },
    },
    {
        id = 'waiter', keywords = { 'garson', 'servis eleman', 'komi' }, askLabel = 'garsona', services = { 'order' }, suggest = 'food',
        tips = { 'Tabakları taşırken sırtını dik tut, yoksa akşama belin kopar.', 'Müşteri siparişini tekrar et, yanlış gelirse suç hep garsonda.', 'Mutfakla iyi geçin, en sıcak yemek ona göre çıkar.' },
        qa = {
            { patterns = { 'ne onerirsin', 'en guzel yemek', 'ne yesem burada', 'en iyi ne' }, lines = { 'Bugün günün yemeği çok iyi, ben de öğlen yedim.', 'Tatlısını kaçırma, burada en çok o satıyor.' } },
            { patterns = { 'bahsis' }, lines = { 'Bahşiş olmasa bu maaşla geçinemem, açık konuşayım.' } },
        },
        stories = { 'Bugün bir müşteri çorbasında sinek var diye bağırdı, meğer karabibermiş.', 'Geçen hafta tepsiyi düşürdüm, altı bardak kırıldı. Herkes alkışladı, yerin dibine girdim.' },
    },
    {
        id = 'barista', keywords = { 'barista', 'kafe', 'kahveci' }, askLabel = 'baristaya', services = { 'order' }, suggest = 'coffee',
        tips = { 'İyi kahvenin sırrı taze çekilmiş çekirdek ve doğru su sıcaklığı: kaynamış değil, 92-96 derece.', 'Sütü köpürtürken sesi dinle; tıslama sesi doğru, çığlık gibi sesse fazla ısıtmışsın.', 'Kahveyi aç karnına içme, mideyi yakar.' },
        qa = {
            { patterns = { 'hangi kahve', 'kahve oner', 'en iyi kahve', 'guclu kahve' }, lines = { 'Uyanmak istiyorsan çift shot espresso. Keyif için latte.', 'Soğuk demlemeyi dene, daha yumuşak ama güçlü.' } },
            { patterns = { 'kafein', 'kac kahve', 'cok kahve' }, lines = { 'Günde üç-dört fincanı geçme derim. Akşamüstünden sonra da içme, uyuyamazsın.' } },
            { patterns = { 'kahve nasil', 'evde kahve', 'demleme' }, lines = { 'Evde French press yeter: iri çekilmiş kahve, dört dakika demle, bastır.' } },
        },
        stories = { 'Bugün biri gelip "kahvesiz kahve" istedi. Hâlâ ne demek istediğini düşünüyorum.', 'Sabah makine bozuldu, kuyruk kapıya kadar uzadı. Hayatımın en uzun saatiydi.' },
    },
    {
        id = 'cook', keywords = { 'asci', 'sef', 'mutfak', 'pisirici' }, askLabel = 'aşçıya', services = { 'order' }, suggest = 'food',
        tips = { 'Tuzu en başta değil, pişerken azar azar ver.', 'Keskin bıçak kör bıçaktan daha güvenlidir.', 'Eti pişirdikten sonra birkaç dakika dinlendir, suyu içinde kalsın.', 'Soğanı sabırla kavur; aceleye gelirse yemek tatsız olur.' },
        qa = {
            { patterns = { 'ne pisireyim', 'yemek tarifi', 'tarif ver', 'ne yapsam aksam' }, lines = { 'Kolay bir şey: fırında tavuk, patates, biraz kekik. Kırk dakikada hazır.', 'Makarna yap, sosu bol sarımsaklı domates olsun. Asla yanlış gitmez.' } },
            { patterns = { 'pilav nasil', 'pilav tarif' }, lines = { 'Pirinci önce yıka, tereyağında kavur, bir ölçü pirince bir buçuk ölçü sıcak su. Kısık ateş, demlenmeyi unutma.' } },
            { patterns = { 'et nasil', 'biftek', 'steak' }, lines = { 'Tavayı iyice kızdır, eti oda sıcaklığında koy. Her yüzü üç dakika, sonra dinlendir.' } },
        },
        stories = { 'Bugün mutfakta yangın çıkıyordu az kalsın, alev tavadan tavana çıktı.', 'Bir müşteri yemeği geri gönderdi, sonra tarifini istedi. Karar veremedi herhalde.' },
    },
    {
        id = 'cashier', keywords = { 'kasiyer', 'tezgahtar', 'satis', 'market' }, askLabel = 'kasiyere', services = { 'order' }, suggest = 'food',
        tips = { 'Para üstünü her zaman iki kez say.', 'Gece vardiyasında kapıya sırtını dönme.' },
        qa = { { patterns = { 'indirim', 'kampanya' }, lines = { 'Akşamüstü taze ürünlerde indirim oluyor, o saatte gel.' } } },
        stories = { 'Bugün bir adam elli kuruş için yarım saat tartıştı benimle.' },
    },
    {
        id = 'medical', keywords = { 'hemsire', 'doktor', 'hekim', 'paramedik', 'saglik', 'ambulans', 'cerrah', 'eczaci', 'acil tip' }, askLabel = 'doktora', services = { 'heal' }, suggest = 'medical',
        tips = { 'Kanamayı durdurmanın ilk kuralı: temiz bir bezle bastır ve bırakma.', 'Bol su iç; insanların yarısı aslında susuz kaldığı için halsiz.', 'Antibiyotiği kendi kafana göre alma, işe yaramaz ve zarar verir.', 'Kalp masajında dakikada yüz-yüz yirmi baskı; göğsün ortasına, kollar dik.', 'Baş yaralanmasından sonra kusma ya da uyku hâli varsa hemen acile.' },
        qa = {
            { patterns = { 'ilk yardim', 'kalp masaji', 'cpr', 'suni teneffus' }, lines = { 'Önce güvenliği sağla, sonra 112\'yi ara. Nefes almıyorsa göğüs ortasına dakikada yüz-yüz yirmi baskı yap.', 'Bilinci kapalı ama nefes alıyorsa yan yatır, dilinin geriye kaçmasını önle.' } },
            { patterns = { 'vuruldu', 'kursun', 'silah yarasi' }, lines = { 'Kurşun yarasında yarayı bastır, kurşunu çıkarmaya çalışma! Hemen ambulans.', 'Kol ya da bacaktan vurulduysa yaranın üstünden sıkıca bağla, ama gevşetmeyi unutma.' } },
            { patterns = { 'ilac', 'agri kesici', 'hangi hap' }, lines = { 'Basit ağrılara parasetamol ya da ibuprofen yeter. Midende sorun varsa ibuprofeni aç karnına alma.', 'İlacı reçetesiz, bilinçsiz kullanma. Eczacıya danış.' } },
            { patterns = { 'saglikli', 'diyet', 'kilo ver', 'nasil beslen' }, lines = { 'Az şeker, bol sebze, günde yarım saat yürüyüş. Sihirli hap yok.', 'Akşam geç saatte yeme, su içmeyi ihmal etme.' } },
            { patterns = { 'hastane', 'acil nerede', 'muayene' }, lines = { 'Pillbox Hill Hastanesi en büyüğü, acil servisi yirmi dört saat açık.' } },
        },
        stories = { 'Dün gece nöbette üç kurşun yarası geldi. Bu şehir bazen beni gerçekten yoruyor.', 'Bir hasta bana teşekkür için kurabiye getirdi. Bu işin en güzel anları böyle.' },
    },
    {
        id = 'mechanic', keywords = { 'tamirci', 'kaportaci', 'mekanik', 'oto usta', 'motor ustasi', 'lastikci' }, askLabel = 'tamirciye', services = { 'repair' }, suggest = 'mechanic',
        tips = { 'Motor yağını her on bin kilometrede değiştir, gerisi kendiliğinden gelir.', 'Lastik basıncını ayda bir kontrol et, yakıttan kazanırsın.', 'Fren sesi gelirse bekleme; balata ucuz, disk pahalı.', 'Aracı ısınmadan zorlama, motor teşekkür eder.' },
        qa = {
            { patterns = { 'yag ne zaman', 'yag degisimi', 'motor yagi' }, lines = { 'Motor yağını on bin kilometrede ya da yılda bir değiştir, hangisi önce gelirse.' } },
            { patterns = { 'lastik', 'patlak', 'hava basinci' }, lines = { 'Lastik basıncını soğukken ölç. Patlak varsa ve jant zarar görmediyse yaması yapılır.' } },
            { patterns = { 'aku', 'mars basmiyor', 'calismiyor' }, lines = { 'Marşa basmıyorsa önce aküye bak. Kutup başları oksitlendiyse temizle, sıkıştır.', 'Akü üç-dört yılda bir biter. Kışın daha çabuk.' } },
            { patterns = { 'hararet', 'su kaynatti', 'motor isiniyor' }, lines = { 'Hararet yaptıysa hemen dur, motoru kapat. Soğumadan radyatör kapağını açma, yüzüne fışkırır!' } },
            { patterns = { 'hangi araba', 'araba al', 'ikinci el' }, lines = { 'İkinci el alırken şasiye ve motor yağına bak. Bir de mutlaka bir ustaya göster.', 'Yedek parçası bol olan araba al, sonra ağlarsın yoksa.' } },
            { patterns = { 'fren', 'balata' }, lines = { 'Frende titreme varsa disk eğrilmiş olabilir. Ses geliyorsa balata bitmek üzere.' } },
        },
        stories = { 'Bugün biri arabasını getirdi "tuhaf ses geliyor" diye. Torpidoda unutulmuş bir kedi yavrusu çıktı!', 'Geçen hafta bir müşteri frenini tamir ettirmedi, ertesi gün çekiciyle geldi. Dinlemiyorlar.' },
    },
    {
        id = 'driver', keywords = { 'taksi', 'sofor', 'kurye', 'surucu', 'dolmus', 'kamyon' }, askLabel = 'taksiciye', services = { 'ride' },
        tips = { 'Bu şehirde Del Perro Otoyolu akşam altıda felç olur, arka yollardan git.', 'Taksiye binerken plakayı aklında tut, her ihtimale karşı.', 'Gece Grove Street tarafında dikkatli ol, oralar karışık.' },
        qa = {
            { patterns = { 'trafik', 'hangi yol', 'kestirme', 'en hizli yol' }, lines = { 'Sabah Vinewood\'dan inme, Rockford üzerinden git.', 'Akşam saatlerinde otoyoldan uzak dur, sahil yolu daha rahat.' } },
            { patterns = { 'ne kadar tutar', 'taksi ucreti', 'fiyat' }, lines = { 'Şehir içi bir tur genelde ceptekini boşaltmaz ama havaalanı pahalı.' } },
            { patterns = { 'nereye gideyim', 'gezilecek', 'gorulecek' }, lines = { 'Gece Vinewood Tepesi\'ne çık, şehir ayaklarının altında.', 'Vespucci sahili gün batımında çok güzel.' } },
        },
        stories = { 'Bugün arka koltuğa bir yolcu bindi, yol boyunca şarkı söyledi. Bahşişi de iyiydi ama.', 'Dün bir yolcu cüzdanını unuttu, bir saat onu aradım.' },
    },
    {
        id = 'police', keywords = { 'polis', 'komiser', 'serif', 'jandarma' }, askLabel = 'polise',
        tips = { 'Olay yerinde ilk iş: kendi güvenliğin. Kahramanlık değil sağduyu.', 'Gördüğün plakayı hemen not al, hafıza yanıltır.' },
        qa = {
            { patterns = { 'sikayet', 'ihbar', 'suc', 'hirsiz' }, lines = { 'Bir şey gördüysen yeri, saati ve kişinin tarifini not al. İhbarı en kısa sürede yap.', 'Hırsızlık olduysa hiçbir şeye dokunma, parmak izi kalsın.' } },
            { patterns = { 'ceza', 'hiz siniri', 'radar' }, lines = { 'Şehir içinde hız sınırına uy, radarlar her yerde.' } },
        },
        stories = { 'Bugün bir kediyi ağaçtan indirdim. Polislik bu mu diye düşündüm, ama çocuk çok sevindi.' },
    },
    {
        id = 'office', keywords = { 'muhasebe', 'sekreter', 'sigorta', 'emlak', 'banka', 'finans', 'avukat', 'danisman', 'yonetici', 'mudur' }, askLabel = 'muhasebeciye',
        tips = { 'Maaş yatınca önce kendine öde: en az yüzde onu kenara koy.', 'Kredi kartının asgarisini ödeyip rahatlama, faiz seni yer.', 'Sözleşmeyi imzalamadan önce küçük harfleri oku.', 'Kira kontratında depozito şartlarını mutlaka yazılı al.' },
        qa = {
            { patterns = { 'para biriktir', 'birikim', 'yatirim', 'borsa' }, lines = { 'Önce acil durum fonu: üç aylık gideri kenara koy. Sonra yatırım düşün.', 'Borsada kısa vadeli zengin olunmaz. Uzun vade, çeşitlendirme.' } },
            { patterns = { 'vergi', 'fatura' }, lines = { 'Faturalarını sakla, yıl sonunda işine yarar.' } },
            { patterns = { 'ev al', 'kira', 'emlak' }, lines = { 'Ev alırken tapuyu kontrol et, borç ipotek var mı bak.', 'Kira öderken hep dekont al, elden verme.' } },
            { patterns = { 'dava', 'avukat', 'hukuk' }, lines = { 'Hukuki bir derdin varsa önce yazılı kanıt topla. Sözlü anlaşma havada kalır.' } },
        },
        stories = { 'Bugün patron aynı raporu dört kez düzelttirdi, beşinci halini ilk hâline döndürdüm, "mükemmel" dedi.' },
    },
    {
        id = 'education', keywords = { 'ogretmen', 'ogrenci', 'hoca', 'akademisyen', 'egitmen' }, askLabel = 'öğretmene',
        tips = { 'Ders çalışırken telefonu başka odaya koy, yarı sürede bitirirsin.', 'Bir şeyi öğrendiğini anlamak için başkasına anlatmayı dene.', 'Sınavdan önceki gece uyumak, sabaha kadar çalışmaktan iyidir.' },
        qa = {
            { patterns = { 'nasil calis', 'ders calis', 'sinav', 'odak' }, lines = { 'Yirmi beş dakika çalış, beş dakika mola. Dört turdan sonra uzun ara ver.', 'Not alırken kendi cümlelerinle yaz, ezber değil anlama.' } },
            { patterns = { 'hangi bolum', 'universite', 'meslek sec' }, lines = { 'Sevdiğin ve iş bulabileceğin şeyin kesişimini ara. Bir de staj yap, görmeden karar verme.' } },
        },
        stories = { 'Bugün bir öğrenci ödevini köpeğin yediğini söyledi. Köpeği yokmuş.' },
    },
    {
        id = 'security', keywords = { 'guvenlik', 'bekci', 'koruma', 'nobetci' }, askLabel = 'güvenlikçiye',
        tips = { 'Bir yere girerken hep çıkışı aklında tut.', 'Kalabalıkta cüzdanı arka cepte taşıma.', 'Kavgayı büyütmemek, kazanmaktan iyidir.' },
        qa = { { patterns = { 'guvenli mi', 'tehlikeli mi', 'gece' }, lines = { 'Gece ana caddelerden ayrılma, ışıklı yerlerde yürü.', 'Grove Street ve Davis tarafı geceleri pek güvenli değil.' } } },
        stories = { 'Dün gece kapıda biri beni tanıdık sandı, yarım saat sohbet etti. Sonra yanlış adam olduğunu anladı.' },
    },
    {
        id = 'fisher', keywords = { 'balikci' }, askLabel = 'balıkçıya',
        tips = { 'Balık sabahın ilk ışığında ve gün batımında daha çok vurur.', 'Rüzgâr denizden karaya esiyorsa balık kıyıya yakın olur.', 'Sabır, balıkçılığın yarısıdır.' },
        qa = {
            { patterns = { 'nerede balik', 'balik tut', 'yem', 'olta' }, lines = { 'Del Perro İskelesi\'nin ucu iyi yerdir. Yem olarak karides kullan.', 'Oltanın ucuna ağır kurşun takma, balık hisseder.' } },
            { patterns = { 'hangi balik', 'balik pisir' }, lines = { 'Levrek ızgara, yanına roka. Başka bir şeye gerek yok.' } },
        },
        stories = { 'Bu sabah öyle bir balık tuttum ki oltam kırılıyordu. Tabii kaçtı, kimse inanmıyor.' },
    },
    {
        id = 'retired', keywords = { 'emekli' }, askLabel = 'yaşlılara',
        tips = { 'Hayatta en önemli şey sağlık evladım, gerisi gelir geçer.', 'Tasarruf etmeyi gençken öğren, sonra zor.', 'Komşunla iyi geçin, akrabadan önce o yetişir.' },
        qa = { { patterns = { 'eskiden', 'gencken', 'eski gunler' }, lines = { 'Eskiden bu şehir bu kadar kalabalık değildi. Herkes birbirini tanırdı.', 'Gençken her akşam sahilde yürürdük, şimdi araba sesinden duyamıyorsun dalgayı.' } } },
        stories = { 'Bugün torunum aradı, yeni bir telefon almış bana. Nasıl açılıyor hâlâ bilmiyorum.' },
    },
    {
        id = 'hair', keywords = { 'kuafor', 'berber', 'sac' }, askLabel = 'kuaföre',
        tips = { 'Saçını her gün yıkama, doğal yağını kaybeder.', 'Uçlarını iki ayda bir aldır, saç daha sağlıklı uzar.' },
        qa = { { patterns = { 'sac', 'model', 'sakal' }, lines = { 'Yüz şekline göre kesim seçmek lazım. Yuvarlak yüze yanlar kısa, üstü hacimli yakışır.', 'Sakalını boynundan değil çene hattından şekillendir.' } } },
        stories = { 'Bugün bir müşteri "biraz alın" dedi, sonra ağladı. Bu işte psikolog da olmak gerekiyor.' },
    },
    {
        id = 'trainer', keywords = { 'antrenor', 'spor hoca', 'fitness', 'personal trainer' }, askLabel = 'antrenöre',
        tips = { 'Isınmadan ağırlık kaldırma, sakatlık kapıda.', 'Kas salonda değil, uykuda ve mutfakta yapılır.', 'Haftada üç gün düzenli spor, yedi gün bir haftalık hevesten iyidir.' },
        qa = {
            { patterns = { 'kilo ver', 'zayifla', 'yag yak' }, lines = { 'Kalori açığı olmadan kilo verilmez. Günde yarım saat tempolu yürüyüş, şekeri kes.' } },
            { patterns = { 'kas yap', 'protein', 'antrenman program' }, lines = { 'Kilo başına yaklaşık 1.6 gram protein al, büyük hareketlere odaklan: squat, bench, deadlift.' } },
        },
        stories = { 'Bugün salonda biri yüz kiloyu ısınmadan kaldırmaya çalıştı. Sonuç tahmin ettiğin gibi.' },
    },
    {
        id = 'artist', keywords = { 'muzisyen', 'sanatci', 'ressam', 'dj', 'sarkici', 'oyuncu', 'fotografci' }, askLabel = 'sanatçıya',
        tips = { 'Her gün biraz çalış; ilham çalışırken gelir.', 'Eleştiriden korkma, en çok onlardan öğrenirsin.' },
        qa = { { patterns = { 'nasil baslarim', 'enstruman', 'gitar ogren', 'resim ogren' }, lines = { 'Gitara başlıyorsan önce dört akor öğren, yüzlerce şarkı çalarsın.', 'Her gün on beş dakika, bir yıl sonra kendine şaşırırsın.' } } },
        stories = { 'Dün gece küçük bir barda çaldım, üç kişi dinledi. Ama biri ağladı, bence başarılıydı.' },
    },
}
