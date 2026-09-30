--[[
    YETİŞKİN NPC KATEGORİSİ — Vanilla Unicorn eğlence çalışanları (profile.type = 'adult_entertainer')
    - Normal dünya sakinlerinden ayrı bir kategoridir: kendi kabul kuralları (Config.NPCTypes.adult_entertainer),
      kendi bölgesi (Config.AdultNPCZones.VanillaUnicorn, aynı anda en fazla maxNPCs fiziksel) ve ayrı
      "Yetişkin Etkileşimleri" menüsü vardır. NPC–NPC dedikodu/komşuluk ağına normal sakinlerle karışmazlar.
    - Hepsi açıkça yetişkin olarak işaretlidir (adult = true, yaş >= Config.AdultNPC.MinAge).
    - İlk açılışta veritabanına eklenir (INSERT IGNORE); sonrasında /citizensadmin panelinden düzenlenir.
    - Config.AdultNPC.Enabled = false iken bu NPC'ler sıradan kulüp çalışanı gibi davranır (yetişkin menüsü görünmez).

    NOT: Kulüp içi koordinatlar yaklaşıktır; admin panelinden (Konumlar > Vanilla Unicorn) noktaları düzeltebilirsin.
    Nokta etiketleri: 'pole' (direk dansı), 'dance_floor' (dans/poz), 'wait' (bekleme), 'smoke' (dışarıda sigara).
]]
SCData = SCData or {}
SCData.Locations = SCData.Locations or {}
SCData.Routines = SCData.Routines or {}
SCData.Residents = SCData.Residents or {}

local function hasLocation(id)
    for _, loc in ipairs(SCData.Locations) do
        if loc.id == id then return true end
    end
    return false
end

if not hasLocation('vanilla_unicorn') then
    SCData.Locations[#SCData.Locations + 1] = {
        id = 'vanilla_unicorn', label = 'Vanilla Unicorn', type = 'club', area = 'strawberry', public = true,
        door = vector4(128.95, -1298.06, 29.23, 210.0),
        parking = vector4(143.40, -1283.10, 29.34, 300.0),
        points = {
            { coords = vector4(112.60, -1286.76, 28.46, 30.0), scenario = 'WORLD_HUMAN_PARTYING', tags = { 'pole' } },
            { coords = vector4(104.18, -1293.94, 29.26, 300.0), scenario = 'WORLD_HUMAN_PARTYING', tags = { 'pole' } },
            { coords = vector4(102.24, -1290.54, 29.26, 240.0), scenario = 'WORLD_HUMAN_PARTYING', tags = { 'pole' } },
            { coords = vector4(118.30, -1287.60, 28.26, 120.0), scenario = 'WORLD_HUMAN_PARTYING', tags = { 'dance_floor' } },
            { coords = vector4(114.90, -1295.10, 28.26, 330.0), scenario = 'WORLD_HUMAN_PARTYING', tags = { 'dance_floor' } },
            { coords = vector4(127.20, -1285.10, 29.28, 200.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT', tags = { 'wait' } },
            { coords = vector4(120.40, -1296.30, 29.27, 60.0), scenario = 'WORLD_HUMAN_STAND_MOBILE', tags = { 'wait' } },
            { coords = vector4(132.30, -1303.60, 29.21, 210.0), scenario = 'WORLD_HUMAN_SMOKING', tags = { 'smoke', 'wait' } },
            { coords = vector4(95.90, -1286.20, 29.29, 120.0), scenario = 'WORLD_HUMAN_SMOKING', tags = { 'smoke' } },
        },
        hours = { open = '18:00', close = '06:00' },
        aliases = { 'vanilla unicorn', 'vanilla', 'unicorn', 'striptiz kulubu', 'strip kulup', 'kulup' },
    }
end

-- Gece çalışan eğlence çalışanı rutini (vardiya: job.shift). Tatil günlerinde akşamları bar/sahil/ev arasında seçer.
SCData.Routines.entertainer = SCData.Routines.entertainer or {
    label = 'Gece eğlence çalışanı',
    workday = {
        { from = '12:00', to = '14:00', activity = 'home_idle', location = 'home' },
        { from = '14:00', to = '17:30', activity = 'free', location = 'flex:free' },
        { from = '17:30', to = 'shift_start', activity = 'home_idle', location = 'home' },
        { from = 'shift_start', to = 'shift_end', activity = 'entertain', location = 'work' },
        { from = 'shift_end+20', to = '36:00', activity = 'sleep', location = 'home' },
    },
    offday = {
        { from = '12:30', to = '15:00', activity = 'home_idle', location = 'home' },
        { from = '15:00', to = '19:00', activity = 'free', location = 'flex:free' },
        { from = '19:00', to = '20:30', activity = 'home_idle', location = 'home' },
        { from = '20:30', to = '25:00', alt = { 'bar', 'beach', 'home' } },
        { from = '25:15', to = '36:30', activity = 'sleep', location = 'home' },
    },
}

local function entertainer(def)
    def.routine_id = 'entertainer'
    def.job = def.job or {}
    def.job.workplaceId = 'vanilla_unicorn'
    def.acquaintances = def.acquaintances or {}
    def.profile = def.profile or {}
    def.profile.type = 'adult_entertainer'
    def.profile.adult = true
    def.profile.zone = 'VanillaUnicorn'
    SCData.Residents[#SCData.Residents + 1] = def
end

entertainer({
    id = 'vu_lara', firstname = 'Lara', lastname = 'Vance', age = 27, gender = 'female', model = 's_f_y_stripper_01',
    personality = {
        traits = { 'özgüvenli', 'esprili', 'dışa dönük', 'flörtöz', 'zeki' },
        speech_style = "Rahat ve alaycı konuşur; 'tatlım', 'canım' der, iltifatlara esprili karşılık verir.",
        values = 'Bağımsızlık, para biriktirmek', fears = 'Yaşlanıp hiçbir şey başaramamak',
        hobbies = { 'dans', 'moda', 'gece sürüşü' },
    },
    backstory = "Vice City'den geldi, beş yıldır Vanilla Unicorn'da sahneye çıkıyor. Biriktirdiği parayla kendi dans stüdyosunu açmak istiyor.",
    topics = {
        job = "Vanilla Unicorn'da dansçıyım tatlım. Sahne benim işim.", work_opinion = 'Gece uzun ama bahşişler fena değil.',
        family = 'Annem Vice City\'de, sık sık arıyorum.', origin = 'Vice City kızıyım, sıcağa alışkınım.',
        dream = 'Kendi dans stüdyomu açmak.', food = 'Sushi, bir de gece yarısı pizzası.', music = 'R&B, biraz da house.',
        secret = 'Aslında çok utangacım, sahnede başka biri oluyorum.',
    },
    job = { title = 'Dansçı', shift = { start = '20:00', ['end'] = '04:00' }, workdays = { 3, 4, 5, 6, 7 } },
    homeId = 'apt_vespucci_beach',
    vehicle = { model = 'blista', plate = 'LARA 27', color = { 135, 0 }, type = 'automobile' },
    favorite_places = { 'vespucci_beach', 'bahama_mamas', 'bean_machine' },
    acquaintances = { 'vu_nina', 'vu_jade' },
    profile = {
        stats = { friendliness = 70, humor = 75, confidence = 90, jealousy = 35, patience = 50, romantic = 60, social = 85, aggression = 20 },
        likes = { 'dans', 'iltifat', 'gece sürüşü', 'kokteyl' }, dislikes = { 'kabalık', 'cimrilik', 'erken kalkmak' },
        romance = { open = true, prefers = 'any' }, favorite_areas = { 'strawberry', 'vespucci' }, vehicle_pref = 'car',
    },
})

entertainer({
    id = 'vu_nina', firstname = 'Nina', lastname = 'Cruz', age = 24, gender = 'female', model = 's_f_y_stripper_02',
    personality = {
        traits = { 'neşeli', 'konuşkan', 'enerjik', 'meraklı', 'sabırsız' },
        speech_style = "Enerjik ve samimi konuşur; 'yaa', 'aşkım' gibi sözler kullanır, çok güler.",
        values = 'Eğlence, arkadaşlık', fears = 'Yalnız kalmak',
        hobbies = { 'dans', 'alışveriş', 'karaoke' },
    },
    backstory = 'Los Santos doğumlu. Üniversiteyi yarıda bırakıp dansa başladı; kulübün en neşeli yüzü.',
    topics = {
        job = "Unicorn'da dans ediyorum yaa, en eğlenceli iş!", work_opinion = 'Müzik güzelse gece su gibi geçiyor.',
        family = 'Ablamla yaşıyorum sayılır, her gün görüşürüz.', origin = 'Buralıyım, Strawberry\'de büyüdüm.',
        dream = 'Bir klipte dans etmek!', food = 'Taco, taco, taco.', music = 'Latin pop, reggaeton!',
        secret = 'Hâlâ üniversiteyi bitirmeyi düşünüyorum.',
    },
    job = { title = 'Dansçı', shift = { start = '20:00', ['end'] = '04:00' }, workdays = { 1, 2, 5, 6, 7 } },
    homeId = 'apt_south_rockford',
    favorite_places = { 'burgershot', 'vespucci_beach', 'bahama_mamas' },
    acquaintances = { 'vu_lara', 'vu_mira' },
    profile = {
        stats = { friendliness = 85, humor = 80, confidence = 70, jealousy = 45, patience = 35, romantic = 65, social = 90, aggression = 10 },
        likes = { 'karaoke', 'taco', 'plaj', 'dans' }, dislikes = { 'sıkıcı insanlar', 'yağmur', 'kıskançlık krizleri' },
        romance = { open = true, prefers = 'male' }, favorite_areas = { 'strawberry', 'del_perro' }, vehicle_pref = 'transit',
    },
})

entertainer({
    id = 'vu_mira', firstname = 'Mira', lastname = 'Holt', age = 29, gender = 'female', model = 's_f_y_stripper_01',
    personality = {
        traits = { 'sakin', 'gözlemci', 'kibar', 'mesafeli', 'zeki' },
        speech_style = 'Yavaş ve ölçülü konuşur; tanımadığı kişiye mesafelidir, ısınınca çok sıcaktır.',
        values = 'Güven, saygı', fears = 'Güvendiği birinin onu kandırması',
        hobbies = { 'kitap okumak', 'yoga', 'resim' },
    },
    backstory = 'San Fierro\'dan geldi. Sanat okulunun masraflarını çıkarmak için başladığı işte kaldı; boş zamanlarında resim yapıyor.',
    topics = {
        job = 'Vanilla Unicorn\'da çalışıyorum. Sahne ve özel danslar.', work_opinion = 'İşimi ciddiye alırım, saygı görmek önemli.',
        family = 'Ailemle aram mesafeli, bir erkek kardeşim var.', origin = 'San Fierro\'luyum.',
        dream = 'Kendi resim sergimi açmak.', food = 'Akdeniz mutfağı.', music = 'Caz ve soul.',
        secret = 'Tablolarımdan birini bir galeriye sattım, kimse bilmiyor.',
    },
    job = { title = 'Dansçı', shift = { start = '21:00', ['end'] = '05:00' }, workdays = { 2, 3, 4, 6 } },
    homeId = 'apt_morningwood',
    vehicle = { model = 'premier', plate = 'MIRA 29', color = { 0, 0 }, type = 'automobile' },
    favorite_places = { 'bean_machine', 'mirror_park_lake', 'legion_square' },
    acquaintances = { 'vu_nina' },
    profile = {
        stats = { friendliness = 50, humor = 40, confidence = 45, jealousy = 30, patience = 75, romantic = 55, social = 45, aggression = 10 },
        likes = { 'resim', 'caz', 'sessiz kafeler', 'kibar insanlar' }, dislikes = { 'kabalık', 'ısrar', 'gürültü' },
        romance = { open = true, prefers = 'any' }, favorite_areas = { 'morningwood', 'mirror_park' }, vehicle_pref = 'car',
    },
})

entertainer({
    id = 'vu_jade', firstname = 'Jade', lastname = 'Monroe', age = 31, gender = 'female', model = 's_f_y_stripper_02',
    personality = {
        traits = { 'özgüvenli', 'alaycı', 'koruyucu', 'dürüst', 'sert' },
        speech_style = "Dobra konuşur; 'bak tatlım' diye söze girer, saçmalığa tahammülü yoktur.",
        values = 'Dürüstlük, sadakat', fears = 'Kontrolü kaybetmek',
        hobbies = { 'boks', 'motosiklet', 'poker' },
    },
    backstory = 'Kulübün en kıdemlisi; yeni gelenlere abla gibi bakar. Bir boks salonunda amatör olarak dövüşüyor.',
    topics = {
        job = 'Unicorn\'un en eskisiyim tatlım. Sahne de benim, kurallar da.', work_opinion = 'Kurallara uyan herkesle iyi anlaşırım.',
        family = 'Kendi ailemi kendim kurdum: buradaki kızlar.', origin = 'Liberty City\'den geldim.',
        dream = 'Bir gün kendi kulübümü işletmek.', food = 'Biftek, az pişmiş.', music = 'Rock, bir de eski hip-hop.',
        secret = 'Kulübün sahibiyle ortaklık için konuşuyorum.',
    },
    job = { title = 'Kıdemli dansçı', shift = { start = '20:00', ['end'] = '04:00' }, workdays = { 1, 3, 4, 5, 6 } },
    homeId = 'apt_fantastic',
    vehicle = { model = 'bati', plate = 'JADE 31', color = { 12, 0 }, type = 'bike' },
    favorite_places = { 'tequilala', 'muscle_beach', 'legion_food_cart' },
    acquaintances = { 'vu_lara', 'vu_roxy' },
    profile = {
        stats = { friendliness = 45, humor = 60, confidence = 95, jealousy = 50, patience = 35, romantic = 40, social = 65, aggression = 45 },
        likes = { 'motosiklet', 'poker', 'dürüst insanlar', 'boks' }, dislikes = { 'yalancılar', 'ısrarcı müşteriler', 'sızlanmak' },
        romance = { open = true, prefers = 'any' }, favorite_areas = { 'strawberry', 'west_vinewood' }, vehicle_pref = 'car',
    },
})

entertainer({
    id = 'vu_roxy', firstname = 'Roxy', lastname = 'Hale', age = 26, gender = 'female', model = 's_f_y_stripperlite',
    personality = {
        traits = { 'hayalperest', 'duygusal', 'neşeli', 'çekingen', 'iyimser' },
        speech_style = "Tatlı ve biraz çekingen konuşur; 'şey...' diye başlar, güldüğünde açılır.",
        values = 'Sevgi, sadakat', fears = 'Terk edilmek',
        hobbies = { 'şarkı söylemek', 'fal', 'kedi beslemek' },
    },
    backstory = 'Grapeseed\'de bir çiftlikte büyüdü; şarkıcı olmak için şehre geldi, şimdilik kulüpte dans ediyor ve geceleri şarkı yazıyor.',
    topics = {
        job = 'Şey... Vanilla Unicorn\'da dans ediyorum. Aslında şarkıcıyım ama.', work_opinion = 'Bazı geceler zor ama kızlar çok iyi.',
        family = 'Ailem Grapeseed\'de, çiftlikleri var.', origin = 'Grapeseed\'liyim, taşralı kızım.',
        dream = 'Bir albüm çıkarmak.', food = 'Annemin elmalı turtası.', music = 'Country ve pop balad.',
        secret = 'Gece yazdığım şarkıları kimseye dinletmedim.',
    },
    job = { title = 'Dansçı', shift = { start = '20:00', ['end'] = '03:30' }, workdays = { 2, 4, 5, 6, 7 } },
    homeId = 'apt_vespucci_beach',
    favorite_places = { 'vespucci_beach', 'bean_machine', 'del_perro_pier' },
    acquaintances = { 'vu_jade', 'vu_bella' },
    profile = {
        stats = { friendliness = 80, humor = 50, confidence = 35, jealousy = 65, patience = 60, romantic = 85, social = 60, aggression = 5 },
        likes = { 'şarkılar', 'kediler', 'gün batımı', 'romantik sözler' }, dislikes = { 'bağırmak', 'yalan', 'kalabalık' },
        romance = { open = true, prefers = 'male' }, favorite_areas = { 'vespucci', 'del_perro' }, vehicle_pref = 'transit',
    },
})

entertainer({
    id = 'vu_bella', firstname = 'Bella', lastname = 'Reyes', age = 23, gender = 'female', model = 's_f_y_stripperlite',
    personality = {
        traits = { 'enerjik', 'flörtöz', 'dışa dönük', 'sabırsız', 'meraklı' },
        speech_style = "Hızlı ve cilveli konuşur; 'canım' der, sürekli bir yerlere gitmek ister.",
        values = 'Macera, özgürlük', fears = 'Sıkıcı bir hayat',
        hobbies = { 'araba gezmek', 'parti', 'fotoğraf' },
    },
    backstory = 'Kulübün en yenisi; Los Santos\'un gece hayatını keşfetmeye bayılıyor, hep bir sonraki maceranın peşinde.',
    topics = {
        job = 'Unicorn\'da yeniyim canım, dans ediyorum.', work_opinion = 'Daha öğreniyorum ama çok eğleniyorum!',
        family = 'Babam Paleto\'da, çok korumacı.', origin = 'Paleto Bay\'den kaçıp geldim sayılır.',
        dream = 'Bütün şehri gezmek, her kulüpte bir gece geçirmek.', food = 'Hamburger ve milkshake.', music = 'EDM, yüksek sesle!',
        secret = 'Babam burada çalıştığımı bilmiyor.',
    },
    job = { title = 'Dansçı', shift = { start = '21:00', ['end'] = '04:30' }, workdays = { 1, 3, 5, 6 } },
    homeId = 'apt_integrity',
    favorite_places = { 'bahama_mamas', 'up_n_atom', 'vespucci_beach' },
    acquaintances = { 'vu_roxy', 'vu_nina' },
    profile = {
        stats = { friendliness = 75, humor = 65, confidence = 75, jealousy = 40, patience = 25, romantic = 70, social = 90, aggression = 15 },
        likes = { 'araba gezmek', 'parti', 'milkshake', 'iltifat' }, dislikes = { 'beklemek', 'sıkıcı geceler', 'cimrilik' },
        romance = { open = true, prefers = 'any' }, favorite_areas = { 'del_perro', 'strawberry' }, vehicle_pref = 'transit',
    },
})
