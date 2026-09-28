--[[
    Başlangıç konumları. İlk açılışta veritabanına eklenir (INSERT IGNORE); sonrasında
    kaynak veritabanıdır ve /citizensadmin panelinden düzenlenir.

    NOT: Koordinatlar vanilla Los Santos için yaklaşık değerlerdir. Sunucundaki MLO'lara göre
    admin panelindeki "Bulunduğum yeri kaydet" butonuyla kapı/park/nokta ekleyip düzelt.
    Fiziksel ped oluşturulurken z değeri yakındaki istemcide zemine oturtulur.

    Alanlar:
      id, label, type (SC.LocationTypes), area (komşuluk etiketi), public (NPC'ler yol tarifi verebilir mi)
      door    : giriş noktası (vector4). Bina içindeki aktivitelerde ped buradan girip kaybolur.
      parking : araç park noktası (vector4, opsiyonel)
      points  : { coords = vector4, scenario = 'GTA_SCENARIO', tags = { aktivite tag'leri } }
      hours   : { open = 'HH:MM', close = 'HH:MM' } (opsiyonel; public mekanlar için)
      aliases : oyuncunun yazdığı yer adını eşleştirmek için alternatif adlar
]]
SCData = SCData or {}

SCData.Locations = {
    ------------------------------------------------------------------ EVLER
    {
        id = 'apt_south_rockford', label = 'South Rockford Dr. Apartmanı', type = 'home', area = 'little_seoul', public = false,
        door = vector4(-667.02, -1105.24, 14.63, 242.32),
        points = {
            { coords = vector4(-663.9, -1108.1, 14.6, 150.0), scenario = 'WORLD_HUMAN_SMOKING', tags = { 'home_idle', 'smoke' } },
        },
        aliases = { 'south rockford', 'little seoul' },
    },
    {
        id = 'apt_morningwood', label = 'Morningwood Blvd. Apartmanı', type = 'home', area = 'morningwood', public = false,
        door = vector4(-1288.52, -430.51, 35.15, 124.81),
        points = {
            { coords = vector4(-1291.6, -433.9, 34.95, 130.0), scenario = 'WORLD_HUMAN_STAND_MOBILE', tags = { 'home_idle' } },
        },
        aliases = { 'morningwood' },
    },
    {
        id = 'apt_integrity', label = 'Integrity Way Apartmanı', type = 'home', area = 'pillbox', public = false,
        door = vector4(269.73, -640.75, 42.02, 249.07),
        points = {
            { coords = vector4(272.6, -644.4, 42.02, 250.0), scenario = 'WORLD_HUMAN_SMOKING', tags = { 'home_idle', 'smoke' } },
        },
        aliases = { 'integrity way' },
    },
    {
        id = 'apt_tinsel', label = 'Tinsel Towers', type = 'home', area = 'rockford', public = false,
        door = vector4(-619.29, 37.69, 43.59, 181.03),
        parking = vector4(-632.2, 56.8, 43.7, 90.0),
        points = {
            { coords = vector4(-614.6, 36.2, 43.57, 180.0), scenario = 'WORLD_HUMAN_STAND_MOBILE', tags = { 'home_idle' } },
        },
        aliases = { 'tinsel', 'tinsel towers' },
    },
    {
        id = 'apt_fantastic', label = 'Fantastic Plaza', type = 'home', area = 'pillbox_south', public = false,
        door = vector4(291.52, -1078.67, 29.41, 270.75),
        points = {
            { coords = vector4(294.8, -1073.9, 29.4, 270.0), scenario = 'WORLD_HUMAN_SMOKING', tags = { 'home_idle', 'smoke' } },
        },
        aliases = { 'fantastic plaza' },
    },
    {
        id = 'house_forum_dr', label = 'Forum Drive Evi', type = 'home', area = 'davis', public = false,
        door = vector4(-14.08, -1441.18, 31.10, 180.0),
        parking = vector4(-24.9, -1438.6, 30.65, 180.0),
        points = {
            { coords = vector4(-15.4, -1445.2, 30.6, 180.0), scenario = 'WORLD_HUMAN_SMOKING', tags = { 'home_idle', 'smoke' } },
        },
        aliases = { 'forum drive', 'forum' },
    },
    {
        id = 'house_grove_st', label = 'Grove Street Evi', type = 'home', area = 'davis', public = false,
        door = vector4(126.72, -1929.88, 21.38, 210.0),
        parking = vector4(117.2, -1937.6, 20.75, 45.0),
        points = {
            { coords = vector4(121.9, -1933.2, 20.95, 210.0), scenario = 'WORLD_HUMAN_STAND_MOBILE', tags = { 'home_idle' } },
        },
        aliases = { 'grove street', 'grove' },
    },
    {
        id = 'apt_vespucci_beach', label = 'Vespucci Sahil Apartmanı', type = 'home', area = 'vespucci', public = false,
        door = vector4(-1150.7, -1520.7, 10.63, 35.0),
        parking = vector4(-1158.4, -1502.3, 4.35, 35.0),
        points = {
            { coords = vector4(-1146.9, -1517.1, 10.63, 35.0), scenario = 'WORLD_HUMAN_SMOKING', tags = { 'home_idle', 'smoke' } },
        },
        aliases = { 'vespucci sahil', 'sahil apartmanı' },
    },

    ------------------------------------------------------------------ İŞ YERLERİ
    {
        id = 'burgershot', label = 'Burger Shot', type = 'fastfood', area = 'del_perro', public = true,
        door = vector4(-1183.3, -884.1, 13.80, 305.0),
        parking = vector4(-1170.6, -891.9, 13.93, 35.0),
        hours = { open = '07:00', close = '23:59' },
        points = {
            { coords = vector4(-1181.0, -879.4, 13.87, 120.0), scenario = 'WORLD_HUMAN_CLIPBOARD', tags = { 'work' } },
            { coords = vector4(-1186.9, -878.7, 13.87, 210.0), scenario = 'WORLD_HUMAN_JANITOR', tags = { 'work' } },
            { coords = vector4(-1176.8, -886.5, 13.90, 305.0), scenario = 'WORLD_HUMAN_SMOKING', tags = { 'break', 'smoke' } },
            { coords = vector4(-1188.6, -886.0, 13.80, 305.0), scenario = 'WORLD_HUMAN_AA_COFFEE', tags = { 'eat', 'coffee', 'idle' } },
        },
        aliases = { 'burger shot', 'burgershot', 'burger' },
    },
    {
        id = 'maze_bank_tower', label = 'Maze Bank Tower', type = 'office', area = 'pillbox', public = true,
        door = vector4(-66.7, -802.4, 44.23, 340.0),
        parking = vector4(-84.6, -787.8, 38.3, 280.0),
        hours = { open = '07:00', close = '20:00' },
        points = {
            { coords = vector4(-72.4, -796.6, 44.23, 340.0), scenario = 'WORLD_HUMAN_SMOKING', tags = { 'break', 'smoke' } },
            { coords = vector4(-61.1, -797.8, 44.23, 340.0), scenario = 'WORLD_HUMAN_STAND_MOBILE', tags = { 'break', 'idle' } },
        },
        aliases = { 'maze bank', 'maze bank kulesi', 'ofis' },
    },
    {
        id = 'pillbox', label = 'Pillbox Hill Hastanesi', type = 'hospital', area = 'pillbox', public = true,
        door = vector4(298.9, -584.2, 43.26, 70.0),
        parking = vector4(294.58, -574.76, 43.18, 35.8),
        points = {
            { coords = vector4(302.9, -579.6, 43.28, 70.0), scenario = 'WORLD_HUMAN_SMOKING', tags = { 'break', 'smoke' } },
            { coords = vector4(296.6, -589.7, 43.26, 70.0), scenario = 'WORLD_HUMAN_CLIPBOARD', tags = { 'work' } },
        },
        aliases = { 'pillbox', 'hastane', 'pillbox hastanesi' },
    },
    {
        id = 'cab_co', label = 'Downtown Cab Co.', type = 'depot', area = 'downtown_vinewood', public = true,
        door = vector4(895.4, -179.3, 74.70, 240.0),
        parking = vector4(916.99, -170.68, 74.0, 240.0),
        points = {
            { coords = vector4(903.3, -170.5, 74.08, 240.0), scenario = 'WORLD_HUMAN_SMOKING', tags = { 'work', 'break', 'smoke' } },
            { coords = vector4(899.2, -174.8, 74.1, 150.0), scenario = 'WORLD_HUMAN_AA_COFFEE', tags = { 'work', 'idle' } },
        },
        aliases = { 'taksi durağı', 'cab co', 'downtown cab' },
    },
    {
        id = 'ulsa', label = 'Los Santos Üniversitesi (ULSA)', type = 'school', area = 'richman', public = true,
        door = vector4(-1655.4, 172.4, 61.76, 290.0),
        points = {
            { coords = vector4(-1636.0, 180.0, 61.75, 290.0), scenario = 'WORLD_HUMAN_STAND_MOBILE', tags = { 'study', 'idle' } },
            { coords = vector4(-1641.5, 188.2, 61.76, 200.0), scenario = 'WORLD_HUMAN_TOURIST_MAP', tags = { 'study' } },
            { coords = vector4(-1629.7, 186.9, 61.76, 110.0), scenario = 'WORLD_HUMAN_AA_COFFEE', tags = { 'break', 'eat', 'coffee' } },
        },
        aliases = { 'üniversite', 'ulsa', 'okul', 'kampüs' },
    },
    {
        id = 'benny', label = "Benny's Motorworks", type = 'garage', area = 'strawberry', public = true,
        door = vector4(-205.6, -1310.4, 31.29, 180.0),
        parking = vector4(-190.2, -1290.5, 31.29, 270.0),
        hours = { open = '08:00', close = '20:00' },
        points = {
            { coords = vector4(-212.0, -1325.0, 30.89, 0.0), scenario = 'WORLD_HUMAN_WELDING', tags = { 'work' } },
            { coords = vector4(-199.5, -1324.0, 31.09, 90.0), scenario = 'WORLD_HUMAN_CLIPBOARD', tags = { 'work' } },
            { coords = vector4(-203.4, -1304.6, 31.29, 180.0), scenario = 'WORLD_HUMAN_SMOKING', tags = { 'break', 'smoke' } },
        },
        aliases = { 'benny', "benny's", 'bennys', 'tamirhane', 'garaj' },
    },
    {
        id = 'tequilala', label = 'Tequi-la-la', type = 'bar', area = 'west_vinewood', public = true,
        door = vector4(-564.5, 274.8, 83.02, 175.0),
        hours = { open = '17:00', close = '04:00' },
        points = {
            { coords = vector4(-561.2, 271.6, 83.02, 175.0), scenario = 'WORLD_HUMAN_SMOKING', tags = { 'break', 'smoke', 'drink', 'socialize' } },
            { coords = vector4(-567.9, 271.1, 83.02, 175.0), scenario = 'WORLD_HUMAN_DRINKING', tags = { 'drink', 'socialize', 'wait' } },
            { coords = vector4(-563.0, 268.9, 83.02, 0.0), scenario = 'WORLD_HUMAN_GUARD_STAND', tags = { 'work' } },
        },
        aliases = { 'tequilala', 'tequi-la-la', 'tekila', 'bar' },
    },
    {
        id = 'del_perro_pier', label = 'Del Perro İskelesi', type = 'pier', area = 'del_perro', public = true,
        door = vector4(-1604.3, -1049.6, 13.02, 140.0),
        parking = vector4(-1615.4, -1026.2, 13.1, 50.0),
        points = {
            { coords = vector4(-1847.0, -1247.0, 8.62, 140.0), scenario = 'WORLD_HUMAN_STAND_FISHING', tags = { 'fish', 'work' } },
            { coords = vector4(-1838.4, -1255.4, 8.62, 230.0), scenario = 'WORLD_HUMAN_STAND_FISHING', tags = { 'fish', 'work' } },
            { coords = vector4(-1822.6, -1219.9, 13.02, 320.0), scenario = 'WORLD_HUMAN_BINOCULARS', tags = { 'leisure', 'wait' } },
            { coords = vector4(-1628.8, -1063.0, 13.1, 140.0), scenario = 'WORLD_HUMAN_TOURIST_MOBILE', tags = { 'leisure', 'wait', 'idle' } },
        },
        aliases = { 'iskele', 'del perro', 'pier', 'lunapark', 'del perro iskelesi' },
    },
    {
        id = 'gopostal', label = 'GoPostal Deposu', type = 'depot', area = 'downtown_vinewood', public = true,
        door = vector4(78.66, 111.95, 81.17, 160.0),
        parking = vector4(66.4, 121.1, 79.1, 160.0),
        points = {
            { coords = vector4(72.4, 116.5, 79.2, 160.0), scenario = 'WORLD_HUMAN_CLIPBOARD', tags = { 'work' } },
            { coords = vector4(84.8, 108.2, 79.2, 250.0), scenario = 'WORLD_HUMAN_SMOKING', tags = { 'break', 'smoke' } },
        },
        aliases = { 'gopostal', 'go postal', 'kargo', 'depo' },
    },

    ------------------------------------------------------------------ ORTAK ALANLAR
    {
        id = 'legion_square', label = 'Legion Meydanı', type = 'park', area = 'pillbox', public = true,
        door = vector4(195.17, -933.77, 30.69, 144.0),
        points = {
            { coords = vector4(195.17, -933.77, 30.69, 144.0), scenario = 'WORLD_HUMAN_TOURIST_MOBILE', tags = { 'leisure', 'wait', 'idle' } },
            { coords = vector4(181.4, -951.2, 30.09, 250.0), scenario = 'WORLD_HUMAN_STAND_IMPATIENT', tags = { 'leisure', 'wait', 'idle' } },
            { coords = vector4(214.7, -921.6, 30.69, 60.0), scenario = 'WORLD_HUMAN_SMOKING', tags = { 'leisure', 'smoke', 'idle' } },
            { coords = vector4(172.1, -925.9, 30.69, 300.0), scenario = 'WORLD_HUMAN_AA_COFFEE', tags = { 'eat', 'coffee', 'leisure' } },
        },
        aliases = { 'legion', 'meydan', 'legion square', 'legion meydanı' },
    },
    {
        id = 'legion_food_cart', label = 'Legion Seyyar Büfe', type = 'fastfood', area = 'pillbox', public = true,
        door = vector4(162.9, -946.9, 30.1, 70.0),
        points = {
            { coords = vector4(165.4, -948.6, 30.09, 340.0), scenario = 'WORLD_HUMAN_AA_COFFEE', tags = { 'eat', 'coffee', 'wait' } },
            { coords = vector4(160.2, -950.4, 30.1, 20.0), scenario = 'WORLD_HUMAN_STAND_MOBILE', tags = { 'eat', 'idle' } },
        },
        aliases = { 'büfe', 'seyyar büfe', 'sosisli' },
    },
    {
        id = 'muscle_beach', label = 'Muscle Sands Açık Spor Salonu', type = 'gym', area = 'vespucci', public = true,
        door = vector4(-1202.9, -1565.1, 4.61, 35.0),
        points = {
            { coords = vector4(-1200.08, -1571.15, 4.61, 215.0), scenario = 'PROP_HUMAN_MUSCLE_CHIN_UPS', tags = { 'exercise' } },
            { coords = vector4(-1206.2, -1565.4, 4.61, 35.0), scenario = 'WORLD_HUMAN_MUSCLE_FREE_WEIGHTS', tags = { 'exercise' } },
            { coords = vector4(-1196.6, -1566.5, 4.61, 125.0), scenario = 'WORLD_HUMAN_PUSH_UPS', tags = { 'exercise' } },
            { coords = vector4(-1209.4, -1560.2, 4.61, 35.0), scenario = 'WORLD_HUMAN_JOG_STANDING', tags = { 'exercise', 'wait' } },
        },
        aliases = { 'spor salonu', 'muscle beach', 'muscle sands', 'gym' },
    },
    {
        id = 'vespucci_beach', label = 'Vespucci Plajı', type = 'beach', area = 'vespucci', public = true,
        door = vector4(-1392.4, -1497.2, 4.62, 130.0),
        points = {
            { coords = vector4(-1392.4, -1497.2, 4.62, 130.0), scenario = 'WORLD_HUMAN_TOURIST_MOBILE', tags = { 'leisure', 'wait', 'idle' } },
            { coords = vector4(-1418.6, -1528.9, 2.0, 220.0), scenario = 'WORLD_HUMAN_SUNBATHE_BACK', tags = { 'leisure' } },
            { coords = vector4(-1370.9, -1475.2, 4.62, 40.0), scenario = 'WORLD_HUMAN_SMOKING', tags = { 'leisure', 'smoke', 'wait' } },
        },
        aliases = { 'plaj', 'vespucci', 'vespucci plajı', 'sahil', 'kumsal' },
    },
    {
        id = 'bean_machine', label = 'Bean Machine Kafe', type = 'cafe', area = 'west_vinewood', public = true,
        door = vector4(-628.3, 239.2, 81.9, 90.0),
        hours = { open = '06:30', close = '22:00' },
        points = {
            { coords = vector4(-631.9, 244.1, 81.89, 180.0), scenario = 'WORLD_HUMAN_AA_COFFEE', tags = { 'coffee', 'eat', 'wait' } },
            { coords = vector4(-625.5, 244.6, 81.89, 150.0), scenario = 'WORLD_HUMAN_STAND_MOBILE', tags = { 'coffee', 'idle' } },
        },
        aliases = { 'bean machine', 'kafe', 'kahveci', 'kahve' },
    },
    {
        id = 'bahama_mamas', label = 'Bahama Mamas', type = 'bar', area = 'del_perro', public = true,
        door = vector4(-1388.3, -586.4, 30.22, 30.0),
        hours = { open = '19:00', close = '04:00' },
        points = {
            { coords = vector4(-1392.4, -581.6, 30.2, 300.0), scenario = 'WORLD_HUMAN_DRINKING', tags = { 'drink', 'socialize', 'wait' } },
            { coords = vector4(-1384.2, -582.2, 30.2, 30.0), scenario = 'WORLD_HUMAN_SMOKING', tags = { 'drink', 'smoke', 'socialize' } },
        },
        aliases = { 'bahama', 'bahama mamas', 'kulüp', 'gece kulübü' },
    },
    {
        id = 'up_n_atom', label = "Up-n-Atom Burger", type = 'fastfood', area = 'vinewood', public = true,
        door = vector4(81.4, 274.3, 110.21, 160.0),
        hours = { open = '08:00', close = '23:00' },
        points = {
            { coords = vector4(88.1, 281.3, 110.21, 250.0), scenario = 'WORLD_HUMAN_AA_COFFEE', tags = { 'eat', 'coffee', 'wait' } },
        },
        aliases = { 'up n atom', 'upnatom', 'atom burger' },
    },
    {
        id = 'shop_strawberry', label = '24/7 Market (Innocence Blvd.)', type = 'shop', area = 'strawberry', public = true,
        door = vector4(29.2, -1349.2, 29.33, 180.0),
        points = {
            { coords = vector4(32.9, -1352.6, 29.33, 90.0), scenario = 'WORLD_HUMAN_STAND_MOBILE', tags = { 'shopping', 'idle', 'wait' } },
        },
        aliases = { '24/7', 'market', 'bakkal', 'innocence' },
    },
    {
        id = 'shop_mirror_park', label = 'LTD Benzinlik (Mirror Park)', type = 'shop', area = 'mirror_park', public = true,
        door = vector4(1163.4, -323.9, 69.2, 100.0),
        points = {
            { coords = vector4(1157.3, -330.4, 68.95, 190.0), scenario = 'WORLD_HUMAN_SMOKING', tags = { 'shopping', 'idle', 'wait' } },
        },
        aliases = { 'ltd', 'mirror park benzinlik', 'benzinlik' },
    },
    {
        id = 'mirror_park_lake', label = 'Mirror Park Gölü', type = 'park', area = 'mirror_park', public = true,
        door = vector4(1088.9, -690.3, 57.1, 0.0),
        points = {
            { coords = vector4(1088.9, -690.3, 57.1, 0.0), scenario = 'WORLD_HUMAN_TOURIST_MOBILE', tags = { 'leisure', 'wait', 'idle' } },
            { coords = vector4(1075.2, -677.8, 57.4, 300.0), scenario = 'WORLD_HUMAN_STAND_FISHING', tags = { 'fish', 'leisure' } },
        },
        aliases = { 'mirror park', 'göl', 'mirror park gölü' },
    },
}
