# samy-citizens

Kendi hayatı olan, konuşabilen, hatırlayan ve arkadaş olunabilen kalıcı "sakin" NPC sistemi (FiveM · QBX/QB/ESX · OneSync).

**Yapay zekâ yok.** Hiçbir dış servise, API anahtarına ya da Ollama'ya bağlanmaz; ek CPU/GPU yükü ve maliyeti yoktur. Konuşmalar
`data/dialogue.lua` içindeki hazır cümle/desen kütüphanesiyle, sunucuda çalışan kural tabanlı bir motorla yürür.

- Her sakinin adı, kişiliği, evi, işi, arabası ve haftalık rutini var; oyuncu bakmıyorken de yaşamaya (işe gitmeye, yemek yemeye, uyumaya) devam eder.
- Oyuncu serbestçe yazar; motor cümledeki niyeti (selam, meslek sorma, buluşma teklifi, tehdit…) ve bilgileri (yer, saat, gün, isim, meslek) algılar, sakinin kişiliğine ve ilişkinize uygun hazır cevabı seçer.
- Sakin oyuncuyu **karakter bazında** hatırlar (citizenid): adını, mesleğini, sevdiği şeyleri, son konuşmada neden bahsettiğinizi, ona silah doğrulttuğunu…
- Yabancı → Tanıdık → Arkadaş → Yakın arkadaş → **Sevgili** (ve Soğuk / Düşman). Numara verir, gksphone üzerinden SMS'leşir, buluşma ayarlar ve **gerçekten gelir**. Sevgili olursanız sarılır, öper, özlediğini yazar; başkasıyla birlikte olduğunu duyarsa kıskanır, aldatıldığını öğrenirse ayrılır.
- Arası iyi olan sakin **dediğini yapar**: benimle gel, burada bekle, haritada işaretlediğim yere git, arabanla gezelim / beni oraya götür, hadi şimdi kahve içmeye gidelim, polisi ara, dans et / otur / sigara yak…
- **Meslek hizmetleri:** barmen içki, barista kahve, garson yemek verir (ücretli); hemşire yaranı sarar ve sağlık tavsiyesi verir; tamirci arabanı tamir eder. Her meslek kendi alanındaki sorulara cevap verir ("yağ ne zaman değişir?").
- **Karşılıklı sohbet:** sakin de soru sorar (hayalin, ailen, sevdiğin yemek…), cevabını hatırlar ve tepki verir, başından geçenleri anlatır, sen susarsan kendisi söz alır; konuşurken dudakları kıpırdar.
- **Küfür filtresi yok:** küfredersen kişiliğine göre karşılık verir (ya da kırılır) ve bunu hatırlar; samimi arkadaşınla "naber lan" diye şakalaşır.
- Admin panelinden **kalıplarla** (garson, huysuz tamirci, gece barmeni, hemşire, sokak çocuğu…) sakin oluşturma, **çoklu sırlar**, **sabit görev noktası** (bekçi, kapı görevlisi gibi bir yere dikme).
- Silah doğrultulunca eller yukarı, kaçar, polisi arar; olayı iş arkadaşlarına/komşularına anlatır, itibar mahallede yayılır.
- Silahlı oyuncu bir sakini **rehin alabilir** (kalkan / önünden yürütme / diz çöktürme / araca bindirme). Rehine yalvarır, fırsat bulursa kaçar, tanıklar polisi arar; sakin seni günlerce tanır.

---

## 1. Gereksinimler

| Kaynak | Not |
|---|---|
| OneSync | zorunlu (`onesync on` / Infinity) — sakinler sunucu tarafında oluşturulan network ped'leridir |
| `ox_lib`, `oxmysql`, `ox_target` | zorunlu |
| `qbx_core` / `qb-core` / `es_extended` | biri (varsayılan otomatik algılama, QBX öncelikli) |
| `gksphone` (v2) | SMS için (yoksa `Config.Phone.Provider = 'builtin'` ile yerleşik mini mesajlaşma) |
| `ox_inventory` | opsiyonel — hediye verme, meslek hizmetlerinde eşya (yoksa açlık/susuzluk metadata'sı artar) |
| `ps-dispatch` / `cd_dispatch` | opsiyonel — polis ihbarı |
| Güncel FXServer artifact | `SetEntityOrphanMode`, `CreateVehicleServerSetter` gibi sunucu native'leri |

## 2. Kurulum

1. Klasörü `resources/[samy]/samy-citizens` olarak kopyala.
2. `server.cfg`:

```cfg
ensure ox_lib
ensure oxmysql
ensure ox_target
ensure qbx_core          # veya qb-core / es_extended
ensure gksphone          # opsiyonel
ensure samy-citizens

# opsiyonel: konuşma logları Discord'a
set samy_citizens_webhook "https://discord.com/api/webhooks/..."

# yönetim yetkisi
add_ace group.admin samycitizens.admin allow
```

3. İlk açılışta tablolar otomatik oluşturulur (`sql/install.sql`) ve 10 örnek sakin, 27 konum, 7 rutin şablonu eklenir. Sonrasında kaynak veri **veritabanıdır**; `data/*.lua` sadece eksik kayıtları tohumlar (admin düzenlemelerin korunur).

**Eski (yapay zekâlı) sürümden geçiyorsan:** dosyaları değiştirip kaynağı yeniden başlatman yeterli. Eksik sütunlar (`residents.topics`, `residents.settings`, `relationships.facts`, `memories.data`) otomatik eklenir, mevcut sakinlerin boş "hazır cevap" konuları örnek verilerden doldurulur. İlişkiler ve anılar korunur. Eski `samy_citizens_apikey` / `voice_apikey` convar'larını silebilirsin; Ollama'yı kaldırabilir ya da durdurabilirsin.

> **Koordinatlar hakkında dürüst not:** Örnek konumlar vanilla Los Santos için yaklaşık değerlerdir ve oyun içinde doğrulanmadı. Spawn sırasında z değeri yakındaki istemcide zemine/yola/navmesh'e oturtulur, ama kapı/nokta konumlarını kendi haritana (MLO'lar dahil) göre `/citizensadmin → Konumlar → "Bulunduğum yer"` ile düzeltmen önerilir.

## 3. Mimari — Simülasyon LOD

```
               ┌───────────── SOYUT KATMAN (sunucu, her zaman) ─────────────┐
 rutin şablonu │ plan(gün) = önceki günden sarkan blok + günün blokları      │
 + vardiya     │ + ±10–20 dk sapma + boşluk doldurma + roam dilimleri         │
 + ihtiyaçlar  │ esnek bloklar (flex:lunch / flex:free) o an çözülür:         │
 + hava        │   açlık, sosyal, eğlence, enerji, yağmur, saat, hobiler      │
 + randevular  │ state = { activity, locationId, from→to, eta, mode, ... }     │
               │ yolda: konum = rota ilerleme yüzdesiyle interpolasyon       │
               └───────────────┬──────────────────────────────────────────────┘
                               │ oyuncu ≤ SpawnRadius (150 m)
               ┌───────────────▼────────────── FİZİKSEL KATMAN ──────────────┐
               │ sunucu CreatePed/CreateVehicleServerSetter (network)         │
               │ görev tanımı → Entity(ped).state.scTask = {seq, kind, ...}   │
               │ ped'in network SAHİBİ istemci görevi yürütür (1 sn döngü)    │
               │ sahiplik değişince yeni sahip statebag'den devam ettirir     │
               │ varış/park/binaya giriş olayları → sunucu doğrular (sahip mi)│
               └──────────────────────────────────────────────────────────────┘
                 tüm oyuncular SpawnRadius+40 m dışına çıkınca ped silinir,
                 ilerleme gerçek konumdan soyut katmana devredilir.
```

- **Zaman:** `Config.TimeMode = 'game'` (varsayılan; 1 oyun günü ≈ 48 dk). Saat `qb-weathersync`/GlobalState'ten, yoksa rastgele bir oyuncunun istemci saatinden 30 sn'de bir örneklenir. `'real'` modunda Europe/Istanbul (UTC+3) gerçek saat.
- **Ulaşım:** ≤ 200 m yürür; arabası o konumdaysa arabayla gider (kalıcı araç, plaka/renk); yoksa toplu taşıma/taksi (görünmez, varışta kapıdan çıkar).
- **Erken varış:** Sakin gideceği bloğun başlangıcından önce varırsa orada bekler (işe erken gelen işçi gibi).
- **Performans:** istemcide her karede çalışan döngü yok (sahiplik 1 sn, silah kontrolü sadece silahlıyken ve sakin yakındayken). Sunucu tick'i 2 sn, spawn kontrolü 1.5 sn, DB yazımları 60 sn'de bir toplu (+ kapanışta). Diyalog motoru saf Lua metin işleme; bir cevap mikrosaniyeler sürer.

## 4. Diyalog motoru nasıl çalışır?

```
oyuncu: "Yarın akşam 8'de Vespucci'de buluşalım mı?"
   │ 1. katla: küçük harf, ş→s ı→i ğ→g ç→c ö→o ü→u, noktalama temizlenir
   │ 2. bilgi yakala: yer = Vespucci Plajı · gün = yarın · saat = 20:00
   │ 3. niyet puanla: her niyetin desenleri cümleyle karşılaştırılır → en yüksek: propose_meet
   │ 4. durum: ilişki aşaması yeterli mi? sakin o saatte boş mu? (rutin + uyku + diğer randevular)
   ▼ 5. cevap: kişilik tonu + ilişki aşamasına uygun kovadan rastgele bir cümle
aksiyon: create_appointment · anı: "Ahmet ile … buluşmak için sözleştik" · oyuncuya bildirim
```

- **Niyetler** (`SCDialogue.Intents` + `data/dialogue_life.lua`): 100'e yakın hazır niyet — selam, hâl hatır, ad/meslek/yaş/memleket/aile/hayal/sır/yemek/müzik soruları, "ne yapıyorsun", "bugün/dün ne yaptın", "beni hatırlıyor musun", numara isteme, buluşma teklifi/iptali, yol tarifi, başka bir sakini sorma, dedikodu, hava, saat, iltifat, teşekkür, özür, flört, sevgili teklifi, "seni seviyorum", sarılma/öpücük/çak bir beşlik, ayrılık, küfür/argo, komutlar (gel, bekle, git, gezelim, polisi ara, dans et…), sipariş/menü, tedavi, sağlık tavsiyesi, tamir, meslek soruları, sır verme/isteme, hakaret, tehdit, vedalaşma, evet/hayır…
- **"Beni tanıyor musun?"** sadece gerçekten konuştuysanız (en az bir mesaj) "evet" der; paneli açıp kapatmak, yanından geçmek tanışmak sayılmaz. Hiç konuşmadıysanız "tanımıyorum", sadece görmüşse "yüzün tanıdık ama konuşmadık", dedikodudan duymuşsa "tanışmadık ama hakkında bir şeyler duydum" der.
- **Bilgi yakalama:** yer (konum adları + diğer adları), saat ("8'de", "20:30", "akşam 8"), gün ("yarın", "cuma"), isim ("Ben Ahmet", "adım Ahmet"), meslek ("polisim", "tamirci olarak çalışıyorum"), sevdiği şey ("futbolu severim").
- **Çok adımlı konuşma:** sakin bir soru sorduysa ("Sen ne iş yapıyorsun?", "Nerede buluşalım?") bir sonraki cevabın o soruya yanıt olarak yorumlanır. Buluşmada yer ya da saat eksikse sakin sorar; o saatte işte/uykudaysa kendi uygun saatini önerir, "olur" dersen randevu kurulur.
- **Kişilik:** kişilik özelliklerinden ton seçilir (sıcak / resmî / huysuz / çekingen); konuşma tarzındaki tırnak içindeki sözler ("'kanka'", "'evladım'") cevaplara serpiştirilir. Aynı soruya her seferinde farklı cümle gelir.
- **Hafıza:** anılar kodlu tutulur (`aim_weapon`, `gift`, `missed_appointment`, `convo` özeti…). Sakin seni görünce "Geçen gün bana silah doğrultan sen değil misin?!" diye hesap sorabilir, dedikodudan duyduğunu söyleyebilir, hediyeni hatırlayabilir, son konuşmanızı özetleyebilir.
- **Anlamazsa:** kısa ve karakterine uygun bir "anlamadım" cevabı verir ve bazen sorabileceğin şeyleri ima eder. Paneldeki **öneri düğmeleri** (Nasılsın? · Ne iş yapıyorsun? · Buluşalım mı? …) tıklanınca doğrudan gönderilir.

### 4.1 Kendi hazır soru-cevaplarını ekleme

`data/dialogue.lua` en altındaki `SCDialogue.Custom` listesine ekle (sunucu yeniden başlatınca devreye girer):

```lua
SCDialogue.Custom = {
    {
        id = 'ask_mechanic',
        -- desenler katlanmış yazılır: küçük harf, Türkçe karakter yok
        --   'tamirci'      -> kök: "tamirciye", "tamircinin" ile de eşleşir
        --   '=lastik'      -> birebir kelime
        --   'araba bozuldu'-> ifade (bu sırayla geçmeli)
        patterns = { 'tamirci', 'araba bozuldu', '=lastik' },
        lines = { "Benny's'e git derim, Murat usta işini bilir.", 'Tamirci mi? Strawberry tarafında bir yer var.' },
    },
}
```

Sakine özel cevaplar (işi, ailesi, memleketi, hayali, sevdiği yemek/müzik, sırları) ise panelden düzenlenir: `/citizensadmin → Sakin → Bilgi → Hazır cevaplar` (her alanın altında "hazır seçeneklerden seç" listesi var). **Sırlar:** her satıra bir sır yaz; sakin her sorulduğunda bir yenisini anlatır ("başka sırrın var mı?"), hepsi bitince "sana her şeyi anlattım" der. Kime anlatacağı "Sırlarını kime söyler" ayarından seçilir (arkadaş / yakın arkadaş / sevgili / hiç kimse); yakın arkadaşına bazen kendiliğinden de açılır. Oyuncu da ona sır verebilir ("sana bir sır vereyim: …") — sakin saklar, dedikodusunu yapmaz.

Meslek bilgisi `data/jobs.lua`'dadır: meslek adına göre kategori (barmen, garson, barista, aşçı, sağlıkçı, tamirci, taksici, polis, ofis, öğretmen, güvenlik, balıkçı, emekli, kuaför, antrenör, sanatçı), iş yerine göre menüler (bar, kafe, restoran, fastfood, market; ox_inventory eşya adı ve fiyat), sağlık tavsiyeleri ve meslek soru-cevapları. Sunucuna göre eşya adlarını ve fiyatları düzenle.

Hazır niyetlerin cümlelerini değiştirmek için `SCDialogue.Lines` içindeki ilgili kovayı düzenle. Kova seçimi `<ton>_<aşama>` → `<aşama>` → `<ton>` → `default` sırasıyla yapılır (aşama: `stranger`, `known`, `friend`, `cold`). Kullanılabilir yer tutucular dosyanın başında listelidir (`%p%` oyuncuya hitap, `%job%`, `%work%`, `%time%` …).

### 4.2 Test

`/citizensadmin → Diyalog testi`: sakin ve ilişki aşaması seç, bir cümle yaz → hangi niyetin seçildiğini, ilk 5 niyet puanını, yakalanan bilgileri (yer/saat/isim…), ilişki etkisini ve cevabı görürsün. Hiçbir şey kaydedilmez. Yeni desen eklediğinde burada denemen önerilir; bir cümle yanlış niyete gidiyorsa ilgili desene `weight` ver ya da daha belirgin bir ifade ekle.

### 4.3 Günlük hayat: komutlar, hizmetler, aşk, argo

| Oyuncu | Sakin | En az aşama (`Config.Actions.MinStage`) |
|---|---|---|
| `benimle gel` | peşinden gelir, arabana da biner (`FollowMaxMinutes`) | arkadaş |
| `burada bekle` | olduğu yerde bekler (`WaitMinutes`) | arkadaş |
| `haritada işaretlediğim yere git` | işaretli yere gider: yakınsa yürür, uzaksa arabasıyla ya da (görünmez) taksiyle; varınca orada bekler | arkadaş |
| `arabanla gezelim` / `beni oraya götür` | arabasına biner, sen yolcu koltuğuna binince şehri gezdirir ya da işaretli yere götürür; yolda yeni işaret koyarsan oraya döner; inersen tur biter | arkadaş (arabası yakında olmalı) |
| `hadi şimdi kahve içmeye gidelim` | o tür bir mekâna (favorilerinden) gider, haritana işaretler, orada bir süre kalır | arkadaş |
| `dans et`, `otur`, `sigara yak`, `şınav çek`, `gitar çal`, `fotoğraf çek`… | o eylemi yapar (senaryo/animasyon) | arkadaş |
| `evine git`, `gidebilirsin`, `peşimi bırak` | yaptığını bırakıp rutinine / evine döner | tanıdık |
| `polisi ara`, `polise şikayet et …` | dispatch'e senin bulunduğun yeri bildirir (SMS'le de olur) | tanıdık |

- İşteyken (mesai) sadece yakın arkadaş ve sevgili sözünü dinler (`busy_obey`); ruh hâli çok kötüyse reddedebilir. Arkadaşın arabası yakındaysa bazen kendisi "biraz tur atalım mı?" diye teklif eder.
- **Hizmetler** (`Config.JobServices`): barmen/garson/barista/aşçı/kasiyer sipariş alır (`Menüde ne var?`, `Bir bira alabilir miyim?`) — ücret düşülür, eşya verilir, sen de içme/yeme animasyonu yaparsın. Sağlıkçıya `Yaralıyım, bakar mısın?` → yaranı inceler, can verir; `Başım ağrıyor` gibi şikâyetlere tavsiye verir. Tamirciye yanındaki araçla `Arabamı tamir eder misin?` → arabanın önüne yürür, tamir animasyonuyla onarır. Mesai dışındayken sadece arkadaşlarına (yarım) hizmet verir; arkadaşa indirim, sevgiliye bedava.
- **Aşk** (`Config.Romance`): yakın arkadaşken yeterli sevgi/güven varsa `Sevgilim olur musun?` kabul edilir (evli ya da "aşka kapalı" ayarlı sakin reddeder). Sevgili aşamasında özel selamlar, sarılma/öpücük (karşılıklı animasyon), özlem SMS'leri. `AllowMultiple = false` iken: başka bir sakinle sevgili olduğunu **tanıdıkları** hemen bilir ve reddeder; dedikodu ile öğrenen sevgili aldatıldığını anlar, ayrılır, SMS'le hesap sorar ve unutmaz. `Ayrılalım` ile ayrılabilirsin; sevgi/güven çok düşerse ilişki kendiliğinden biter.
- **Küfür / argo** (`Config.Profanity`): filtre yok (`Config.Moderation.Enabled = false`). Düşmanca küfre kişiliğine göre küfürle karşılık verir (huysuz/argo olan sert, çekingen olan kırılır, resmî olan uyarır), ilişki düşer, "bana küfretti" diye hatırlar ve anlatır; `MaxBeforeLeave` küfürden sonra konuşmayı bitirir. Arkadaşınla "naber lan", "amk ne haber" gibi şakalaşma kırılmadan cevaplanır; argo konuşan sakin (özelliklerde `argo`/`kaba` ya da genç huysuz) yakınlarına kendiliğinden "Naber lan yarrak!" diye selam verebilir.
- **Doğallık:** sakin `NpcQuestionChance` ile soru sorar, verdiğin cevaba tepki verip hatırlar (bir dahaki sefere "hayalin için bir adım attın mı?"), `StoryChance` ile başından geçenleri anlatır, sen `NudgeAfterSec` sn susarsan kendisi konuşur; işteyken birkaç cevaptan sonra "mesaim şu saatte bitiyor, sonra konuşalım" der.

## 5. Dosya yapısı

```
samy-citizens/
  fxmanifest.lua
  config.lua                    -- tüm ayarlar (Config.Dialogue: eşik, yazma gecikmesi, ilişki etkileri)
  shared/utils.lua              -- Türkçe metin, PRNG, JSON, zaman yardımcıları
  shared/activities.lua         -- aktivite kataloğu, jest & duygu tabloları
  data/locations.lua            -- 27 örnek konum
  data/routines.lua             -- 7 rutin şablonu (vardiya jetonlu)
  data/residents.lua            -- 10 örnek sakin (+ hazır cevap konuları)
  data/dialogue.lua             -- NİYETLER, CEVAP ŞABLONLARI, özel soru-cevaplar
  data/dialogue_life.lua        -- aşk, argo, komutlar, hizmetler, sırlar, karşılıklı sohbet niyetleri/cümleleri
  data/jobs.lua                 -- meslek kategorileri, menüler, sağlık tavsiyeleri, meslek soru-cevapları
  data/presets.lua              -- yeni sakin kalıpları ve paneldeki hazır seçenek havuzları
  locales/tr.lua, en.lua        -- arayüz, anı ve olay metinleri
  bridge/qbx.lua, qb.lua, esx.lua
  sql/install.sql               -- otomatik migrate
  server/db.lua                 -- migrate, tohumlama, toplu yazım
  server/clock.lua              -- oyun/gerçek saat, hava
  server/simulation.lua         -- SOYUT KATMAN: rutin motoru, ihtiyaçlar, ruh hâli
  server/spawner.lua            -- FİZİKSEL KATMAN: ped/araç, sahiplik, görevler
  server/jobs.lua               -- meslek algılama, menü, tavsiye, soru-cevap eşleme
  server/dialogue.lua           -- kural tabanlı diyalog motoru (niyet, bilgi yakalama, cevap)
  server/memory.lua             -- kodlu anılar, arşivleme, unutma
  server/relationships.lua      -- ilişki puanları, aşamalar, oyuncu hakkında öğrenilenler
  server/actions.lua            -- aksiyonlar (numara, randevu, yol tarifi, eşlik, kaçma, polis)
  server/conversation.lua       -- konuşma akışı, hediye, moderasyon, hız sınırı, ortam selamları
  server/log.lua                -- konuşma logu (DB + Discord)
  server/appointments.lua       -- randevular
  server/phone.lua              -- gksphone / yerleşik SMS
  server/social.lua             -- NPC–NPC ilişkileri, dedikodu
  server/world.lua              -- silah/patlama/ölüm/hırsızlık, dispatch
  server/hostage.lua            -- rehine alma: doğrulama, modlar, kaçma, tanık/polis, anı etkileri
  server/life.lua               -- komutlar (takip/bekle/git/gezme/eylem), hizmetler, polis ihbarı, aldatılma
  server/admin.lua              -- yönetim paneli API'si, rastgele sakin üretici
  server/main.lua               -- başlatma, döngüler, export'lar
  client/main.lua               -- ox_target, snap/saat callback'leri, hediye
  client/tasks.lua              -- aktivite → GTA görev eşlemesi (sahip istemci)
  client/debug.lua              -- /citizensdebug
  client/conversation.lua       -- NUI paneli + 3D baloncuklar
  client/world.lua              -- nişan/ateş/çarpma algılama
  client/hostage.lua            -- rehin alan oyuncu: tuşlar, kalkan animasyonu, ipucu metni
  client/life.lua               -- karşılık animasyonları, tedavi, tamir, gezmede yeni işaret
  client/phone.lua              -- yerleşik mini mesajlaşma
  client/admin.lua              -- panel köprüsü, ışınlanma, harita işaretleri
  web/index.html, style.css, app.js  -- konuşma, baloncuk, telefon, admin NUI
```

> NUI CSS kuralı: `backdrop-filter` hiç kullanılmıyor (FiveM CEF'te `border-radius` ile birlikte köşe/siyah kare hatası). "Cam" görünüm = gradient + `inset box-shadow`.

## 6. Test adımları

### Rutin ve simülasyon
1. Sunucuyu başlat; konsolda `[samy-citizens] hazır: 10 sakin, 27 konum, 7 rutin | ... | diyalog: kural tabanlı (N niyet)` satırını gör.
2. `/citizensadmin → Sakinler`: her sakinin anlık aktivitesi, konumu (ör. "yolda: Forum Drive Evi → Benny's"), ruh hâli ve ihtiyaçları görünmeli; liste 5 sn'de bir yenilenir.
3. `Harita işaretleri` → tüm sakinler haritada (yeşil = fiziksel, mavi = soyut, sarı = yolda, gri = içeride).
4. Murat Demir'e (tamirci, Forum Drive → Benny's) ışınlan. Saat ~07:30–08:00 iken evinin önünde bekle: kapıdan çıkıp Benny's'e gider, `WORLD_HUMAN_WELDING` senaryosuyla çalışır.
5. `/citizensdebug`: ped üstünde `id · ad · aktivite · görev · sahip`. Başka bir oyuncu yaklaşınca sahiplik değişse bile görev devam etmeli.
6. 200+ m uzaklaş (ped silinir), birkaç dakika sonra dön: sakin plana göre ya hâlâ işte ya da öğle arasında.

### Konuşma ve hafıza
1. Sakine yaklaş → ox_target `Konuş`. Başlıkta "Tanımadığın biri", ilişki aşaması, çubuklar ve ruh hâli ikonu görünür. Cevaplar panelde ve NPC'nin başının üstünde baloncuk olarak (20 m) çıkar.
2. `Selam, adın ne?` → kendini tanıtır. `Benim adım Ahmet` → seni adınla anmaya başlar. `Ne iş yapıyorsun?` → işini söyler, bazen "Sen ne iş yapıyorsun?" diye sorar; `Polisim` de.
3. Hiç konuşmadığın bir sakine `Beni tanıyor musun?` → "Hayır, seni ilk kez görüyorum." Paneli açıp hiçbir şey yazmadan kapat, tekrar aç: yine tanımamalı. Bir şeyler konuşup ESC ile vedalaş, tekrar konuş: `Beni hatırlıyor musun?` → "Tabii! … konuşmuştuk, işimden ve senin işinden bahsetmiştik." Başka karakterinle git → seni tanımamalı.
4. Hafif hakaret → soğuk cevap, ilişki düşer. Küfür (`amk`, `siktir git`…) → kişiliğine göre küfürle karşılık verir ya da kırılır; üç düşmanca küfürden sonra konuşmayı bitirir, bir dahaki sefere "Geçen sefer bana küfreden sendin!" der. Arkadaşına `naber lan` → şakayla karşılık.
5. 25 sn hiçbir şey yazma → sakin kendiliğinden bir şey sorar ya da anlatır.
6. `/citizensadmin → Sakin → İlişkiler → Anılar`: kaydedilen anılar; sil/sıfırla/puan düzenle çalışmalı.
7. Tanıdık bir sakinin yanından geç → bazen kendiliğinden selam verir ("Selam Ahmet!").

### Sosyal hayat
1. **Arkadaşlık:** eşikler `Config.Relationship.Stages`. Test için `İlişkiler → Düzenle` ile puanları ayarlayabilirsin.
2. **Numara:** Tanıdık aşamasında `Numaranı alabilir miyim?` → yeterli güven varsa verir; gksphone'a sakinin numarasından tanıtım SMS'i gelir.
3. **SMS:** O numaraya yaz; aynı diyalog motoru cevaplar (işteyse gecikmeli, uyuyorsa uyanınca).
4. **Randevu:** Arkadaş aşamasında (yüz yüze ya da SMS) `Yarın akşam 8'de Vespucci'de buluşalım mı?` → programına uygunsa kabul eder, sana bildirim düşer; değilse kendi uygun saatini önerir. Randevu saatinde sakin rutinini bırakıp oraya gider. Gelmezsen bekler, sonra serzeniş SMS'i atar ve bunu hatırlar.
5. **Tehdit:** Bir sakine silah doğrult → eller yukarı → kaçar → polis ihbarı (ps-dispatch/cd_dispatch). Sonraki görüşmede hesap sorar. Olay iş arkadaşlarına/komşularına yayılır: Selin'e silah doğrult → Elif (iş arkadaşı) seni "duymuş" olur ve ona sorarsan anlatır.
6. **NPC–NPC:** Aynı mekândaki sakinler zaman zaman sohbet eder; bir sakine başka bir sakini sorabilirsin (`Elif'i tanır mısın?`).

### Komutlar, hizmetler, aşk (test için `İlişkiler → Düzenle` ile aşamayı yükselt)
1. Arkadaş aşamasında `Benimle gel` → peşinden gelir; `Burada bekle` → bekler; haritada bir yer işaretle, `İşaretlediğim yere git` → oraya yürür/sürer, varınca bekler; uzak bir yer işaretle → taksiyle gider (uzaklaşınca görünmez, sonra orada belirir).
2. Arabası olan bir arkadaş (ör. Murat, mesai dışında) arabasının yanındayken `Arabanla gezelim` → sürücü koltuğuna geçer, sen yolcu koltuğuna binince sürer; gezerken haritada yeni bir yer işaretle → oraya döner; varınca "Geldik işte!" der.
3. `Dans et`, `Otur`, `Sigara yak`, `Şınav çek` → yapar; `Gidebilirsin` → rutinine döner. `Polisi ara, burada kavga var` → dispatch'e düşer.
4. Selin'e (barmen) mesaideyken `Menüde ne var?` → `Bir bira` → ücret düşer, eşya gelir / içme animasyonu. Zeynep'e (hemşire) canın eksikken `Yaralıyım, bakar mısın?` → birkaç saniye inceler, can gelir. Murat'a yanındaki arabayla `Arabamı tamir eder misin?` → arabanın önüne gider, tamir eder. `Yağ ne zaman değişir?` → tamirci bilgisini verir; başka bir sakin "bunu bir tamirciye sor" der.
5. Yakın arkadaşken `Sevgilim olur musun?` → kabul eder (sarılma animasyonu, "💕 artık sevgilisiniz"). `Seni seviyorum`, `Sarılalım`, `Öpebilir miyim` → sevgiliye özel cevap + karşılıklı animasyon. Onun tanıdığı biriyle de sevgili olmaya çalış → "Sen X ile birlikte değil misin?". `Ayrılalım` → ilişki biter.
6. Yakın arkadaşa `Bir sırrını söyle` → ilk sırrı; `Başka sırrın var mı?` → sıradakini anlatır.

### Rehine alma (`Config.Hostage`)
1. Elinde silah varken bir sakine 2 m'den nişan al → ekranda `[E] Rehin al` ipucu çıkar; `E`'ye bas (ya da ox_target `Rehin al`). Araçtaki bir sakin ya da araçtayken rehin alınamaz. `AllowMelee = false` ise sadece ateşli silahla.
2. Rehin tutarken: `G` bırak · `H` kalkan ↔ yürüt · `J` diz çöktür · `K` yakındaki araca bindir / indir (boş yolcu koltuğu, önce arka). Tuşlar oyuncu tarafından GTA Ayarlar → Tuş Atamaları → FiveM'den değiştirilebilir.
   - **Kalkan (`hold`):** sakin önünde, silah başında; koşamaz, zıplayamaz, ateş edemezsin; rehine kaçamaz.
   - **Yürüt (`escort`):** eller yukarı önünden yürür. **Diz çöktür (`kneel`)**, **araç (`vehicle`)**: aynı araçtayken kaçamaz.
3. Kaçma: kalkan modu ve aynı araç dışında her `EscapeCheckSec` (10 sn) bir deneme — silah elindeyken %4, silahı indirdiysen %35; sen araçtayken o dışarıdaysa en az %50; aradaki mesafe `LeashDistance`'ın (25 m) yarısını geçerse +%15, tamamını geçerse hemen kaçar. `MaxMinutes` (30 gerçek dk) dolunca da kaçar. Sen ölürsen ya da oyundan çıkarsan rehine kurtulur.
4. Rehineyle konuşabilirsin (sadece rehin alan): korkuyla cevap verir; `Sakin ol`, `Paranı ver`, `Kimseye söylemeyeceksin`, `Adın ne?`, `Seni bırakacağım` gibi öneri düğmeleri çıkar. Bu konuşma "görüşme" sayılmaz. Rehineye vurursan kaçamaz ama unutmaz; SMS'lere serbest kalana kadar cevap vermez.
5. 30 m içinde olayı gören sakinler kaçar, biri 20 sn sonra rehinenin yerini polise bildirir. Bırakılan/kaçan rehine kaçar, 8 sn sonra polisi arar, sonra saatlerce (`ShakenMinutes`) evine kapanır.
6. Sonrası: "rehin alındım" anısı (ilişki büyük ölçüde düşer, genelde **Düşman**), olay mahallede yayılır. `RecognizeDays` (7 gerçek gün) boyunca seni yakınında görünce bağırır, kaçar ve polisi arar. `/citizensadmin → Sakinler` listesinde rehine `[hostage]` etiketiyle görünür.

## 7. Yönetim paneli (`/citizensadmin`)

- **Sakinler:** canlı liste, ışınlan, yanına çağır, harita işaretleri, yeni sakin, **Rastgele üret**.
- **Kalıptan oluştur:** yeni sakin formunun üstünde kalıp (16 arketip: neşeli garson, huysuz tamirci, gece barmeni, titiz memur, hemşire, geveze taksici, öğrenci, emekli öğretmen, güvenlik görevlisi, yaşlı balıkçı, barista, spor hocası, sokak çocuğu (argo), çekingen sanatçı, mahalle esnafı, kibirli iş insanı) + cinsiyet seç → kişilik, konuşma tarzı, hobiler, meslek, iş yeri, rutin, vardiya, araba, hazır cevaplar ve sırlar dolar. Özellik ve hobiler tıklanabilir düğmelerle, konuşma tarzı/değerler/korkular/hazır cevaplar "hazır seçeneklerden seç" listeleriyle seçilir (`data/presets.lua`'dan genişletilebilir).
- **Sakin detayı:** kimlik/kişilik/**hazır cevaplar**/**sırlar**/iş/araç/favoriler formu, "sırlarını kime söyler", "sevgili olabilir", günlük plan, bugünkü kayıt, dünün özeti, tanıdıklar, randevular, ilişkiler + anılar (sevgili işareti düzenlenebilir), durum (taburcu, hastane, hapis, taşındı).
- **Sabit görev noktası:** sakin formunda "Görev noktası açık" → konum ("Bulunduğum yer"), senaryo (ör. `WORLD_HUMAN_GUARD_STAND`, `WORLD_HUMAN_COP_IDLES`), isteğe bağlı saatler (boş = 7/24, "22:00–06:00" gibi gece vardiyası olur) ve görev adı. O saatlerde sakin rutinini bırakıp oraya gider ve orada görev yapar (bekçi, kapı görevlisi, seyyar satıcı…).
- **Konumlar:** kapı/park/aktivite noktaları — "Bulunduğum yer" ve "Araçtaki yer" butonlarıyla; senaryo ve etiket seçimi.
- **Rutinler:** iş günü / tatil günü blokları, 24 saatlik önizleme, vardiya jetonları (`shift_start-150` gibi), `firm`, `roam`.
- **Diyalog testi:** bkz. 4.2.
- `/citizensdebug`: 3D metin (id, ad, aktivite, görev, ağ sahibi).

## 8. Güvenlik

- Tüm kararlar sunucuda: aksiyonlar ve komutlar ilişki aşamasına göre tekrar onaylanır; sakin para vermez, eşyayı sadece meslek hizmeti olarak ücret karşılığında (`Config.JobServices`) verir; hizmetlerin bekleme süresi vardır. İlişki artışı mesaj başına ve günlük olarak sınırlıdır (spamla arkadaş olunamaz).
- Konuşmayla gelen harita işareti ve araç bilgisi sunucuda doğrulanır (koordinat sınırları, aracın oyuncuya ≤ 10 m olması).
- Hız sınırı: oyuncu başına 12 mesaj/dk, 400 mesaj/gün, 60 SMS/gün, mesaj ≤ 300 karakter (`Config.RateLimit`).
- İstemciden gelen hiçbir veri doğrulanmadan kabul edilmez: mesafe/sahiplik/silah durumu sunucuda kontrol edilir; istemci raporları sadece raporlayanın kendisi hakkında olay üretebilir.
- Oyuncu ve NPC metinleri NUI'da her zaman `textContent` ile basılır (HTML enjeksiyonu yok).
- Tüm konuşmalar `samy_citizens_conversations` tablosuna ve (convar tanımlıysa) Discord'a loglanır.

## 9. Export'lar (sunucu)

```lua
exports['samy-citizens']:GetResident(id)                 -- sakin özeti
exports['samy-citizens']:GetResidents()
exports['samy-citizens']:GetResidentByEntity(entity)
exports['samy-citizens']:IsResidentEntity(entity)
exports['samy-citizens']:IsHostage(npcId)                -- true, rehinAlanSrc | false
exports['samy-citizens']:ReportEvent(npcId, citizenid, 'saved', 'Ahmet beni hastaneye yetiştirdi.')  -- Config.Events anahtarları
exports['samy-citizens']:AddMemory(npcId, citizenid, text, importance, { valence = 1, shareable = true })
exports['samy-citizens']:ModifyRelationship(npcId, citizenid, dAffinity, dTrust)
exports['samy-citizens']:GetRelationship(npcId, citizenid) -- önbellekteki ilişki
```

## 10. Entegrasyon notları

- **gksphone v2:** NPC → oyuncu `exports.gksphone:SendMessage(npcNumara, oyuncuNumara, metin, { skipSIMUsage = true, saveSenderCopy = false })`; oyuncu → NPC `gksphone:messages:messageSent` event'i (alıcı numarası bir sakine aitse). Yol tarifi SMS'le `vector2` GPS mesajı olarak gider. gksphone kurulumun kayıtlı olmayan numaralara gönderimi engelliyorsa `Config.Phone.NumberPattern`'i telefonunun numara formatına uydur.
- **Dispatch:** `Config.Dispatch.System = 'ps-dispatch' | 'cd_dispatch' | 'custom' | 'none'`. `custom` için `Config.Dispatch.Custom(data)` fonksiyonunu doldur.
- **Hediye:** sakinlerde ox_target `Hediye ver` seçeneği vardır (sunucu `RemoveItem` ile eşyayı alır, günlük bonus sınırlıdır).
- **Saat senkronu:** qb-weathersync otomatik tanınır; başka bir sistemde `Config.TimeSource = 'client'` yeterlidir.
- **Rehine alma:** sunucunda başka bir rehine/kidnap script'i varsa `Config.Hostage.Enabled = false` ile kapat ya da `Config.Hostage.Keys` tuşlarını çakışmayacak şekilde değiştir (varsayılan `E/G/H/J/K`).

## 11. Bilinen sınırlamalar

- Oyun içinde test edilmedi (bu ortamda FiveM sunucusu yok); tüm Lua dosyaları sözdizimi denetiminden, modüller arası çağrı/yerelleştirme anahtarı çapraz kontrolünden ve sahte bir FiveM ortamında sunucu tarafı senaryo testlerinden (diyalog, komutlar, hizmetler, aşk, görev noktası) geçti. Animasyonların oyundaki görünümü (özellikle sarılma/öpücük gibi karşılıklı animasyonlarda iki karakterin hizalanması) doğrulanmadı. İlk kurulumda `Config.Debug = true` ile izlemen ve "Diyalog testi" sekmesinde birkaç cümle denemen önerilir.
- Menülerdeki eşya adları (`beer`, `coffee`, `burger`…) sunucundaki ox_inventory eşyalarıyla aynı olmalı; olmayan eşya yerine açlık/susuzluk metadata'sı artırılır. Tedavi sadece canı yeniler; sunucunun kendi ambulans script'i yaralanmaları ayrıca tutuyorsa `Config.JobServices.HealClientEvent`'e o script'in istemci event adını yaz.
- Kural tabanlı motor, yazılmamış bir konuyu "anlayamaz": desenlerde karşılığı olmayan cümlelere kısa bir "anlamadım" cevabı verir. Sunucuna özel sık sorulanları `SCDialogue.Custom`'a eklemek en etkili iyileştirmedir.
- Diyalog verisi Türkçedir; `Config.Locale = 'en'` sadece arayüz/anı metinlerini İngilizce yapar.
- Örnek koordinatlar yaklaşıktır (bkz. Kurulum).
- Sakin ped'leri ambient modeldir (freemode değil); kıyafet ilk spawn'da rastgele seçilip kalıcı kaydedilir.
- Günlük hız sınırı sayaçları bellek içindedir; kaynak yeniden başlatılınca sıfırlanır.
