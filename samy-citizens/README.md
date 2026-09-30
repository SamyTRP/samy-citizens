# samy-citizens

Kendi hayatı olan, konuşabilen, hatırlayan ve arkadaş olunabilen kalıcı "sakin" NPC sistemi (FiveM · QBX/QB/ESX · OneSync).

**Yapay zekâ yok.** Hiçbir dış servise, API anahtarına ya da Ollama'ya bağlanmaz; ek CPU/GPU yükü ve maliyeti yoktur. Konuşmalar
`data/dialogue.lua` içindeki hazır cümle/desen kütüphanesiyle, sunucuda çalışan kural tabanlı bir motorla yürür.

- Her sakinin adı, kişiliği, evi, işi, arabası ve haftalık rutini var; oyuncu bakmıyorken de yaşamaya (işe gitmeye, yemek yemeye, uyumaya) devam eder.
- Oyuncu serbestçe yazar; motor cümledeki niyeti (selam, meslek sorma, buluşma teklifi, tehdit…) ve bilgileri (yer, saat, gün, isim, meslek) algılar, sakinin kişiliğine ve ilişkinize uygun hazır cevabı seçer.
- Sakin oyuncuyu **karakter bazında** hatırlar (citizenid): adını, mesleğini, sevdiği şeyleri, son konuşmada neden bahsettiğinizi, ona silah doğrulttuğunu…
- Yabancı → Tanıdık → Arkadaş → Yakın arkadaş (ve Soğuk / Düşman). Numara verir, gksphone üzerinden SMS'leşir, buluşma ayarlar ve **gerçekten gelir**.
- Silah doğrultulunca eller yukarı, kaçar, polisi arar; olayı iş arkadaşlarına/komşularına anlatır, itibar mahallede yayılır.
- Silahlı oyuncu bir sakini **rehin alabilir** (kalkan / önünden yürütme / diz çöktürme / araca bindirme). Rehine yalvarır, fırsat bulursa kaçar, tanıklar polisi arar; sakin seni günlerce tanır.
- **v3 — yaşayan NPC katmanı:** kişilik puanları, ruh hâli, ilişki XP'si (Yabancı → Tanıdık → Arkadaş → Yakın Arkadaş → Flört → Sevgili), kısa süreli konuşma bağlamı, dinamik cümle üretici, çevre farkındalığı; **beraber yürüme**, **arabaya davet**, **beraber bir yere gitme** (NPC ya da oyuncu sürer), sosyal animasyonlar (tokalaşma, sarılma, dans, fotoğraf, yan yana oturma…), kendiliğinden konuşma/teklif/mesaj, telefon köprüsü (gksphone / lb-phone / npwd / qb-phone / custom / yerleşik) ve Vanilla Unicorn'a özel, kapatılabilir **yetişkin NPC** kategorisi. Ayrıntılar: **bölüm 12**.

---

## 1. Gereksinimler

| Kaynak | Not |
|---|---|
| OneSync | zorunlu (`onesync on` / Infinity) — sakinler sunucu tarafında oluşturulan network ped'leridir |
| `ox_lib`, `oxmysql`, `ox_target` | zorunlu |
| `qbx_core` / `qb-core` / `es_extended` | biri (varsayılan otomatik algılama, QBX öncelikli) |
| Telefon | opsiyonel — `gksphone` (v2), `lb-phone`, `npwd`, `qb-phone` otomatik algılanır (`Config.Phone.Provider = 'auto'`); hiçbiri yoksa yerleşik mini mesajlaşma |
| `ox_inventory` | opsiyonel — hediye verme |
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

**Eski (yapay zekâlı) sürümden geçiyorsan:** dosyaları değiştirip kaynağı yeniden başlatman yeterli. Eksik sütunlar (`residents.topics`, `relationships.facts`, `memories.data`) otomatik eklenir, mevcut sakinlerin boş "hazır cevap" konuları örnek verilerden doldurulur. İlişkiler ve anılar korunur. Eski `samy_citizens_apikey` / `voice_apikey` convar'larını silebilirsin; Ollama'yı kaldırabilir ya da durdurabilirsin.

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

- **Niyetler** (`SCDialogue.Intents`): 40 civarı hazır niyet — selam, hâl hatır, ad/meslek/yaş/memleket/aile/hayal/sır/yemek/müzik soruları, "ne yapıyorsun", "bugün/dün ne yaptın", "beni hatırlıyor musun", numara isteme, buluşma teklifi/iptali, yol tarifi, başka bir sakini sorma, dedikodu, hava, saat, iltifat, teşekkür, özür, flört, "benimle gel", hakaret, tehdit, vedalaşma, evet/hayır…
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

Sakine özel cevaplar (işi, ailesi, memleketi, hayali, sevdiği yemek/müzik, sırrı) ise panelden düzenlenir: `/citizensadmin → Sakin → Bilgi → Hazır cevaplar`. Sır sadece yakın arkadaşa söylenir; boş bırakılan konuda sakin kaçamak cevap verir.

Hazır niyetlerin cümlelerini değiştirmek için `SCDialogue.Lines` içindeki ilgili kovayı düzenle. Kova seçimi `<ton>_<aşama>` → `<aşama>` → `<ton>` → `default` sırasıyla yapılır (aşama: `stranger`, `known`, `friend`, `cold`). Kullanılabilir yer tutucular dosyanın başında listelidir (`%p%` oyuncuya hitap, `%job%`, `%work%`, `%time%` …).

### 4.2 Test

`/citizensadmin → Diyalog testi`: sakin ve ilişki aşaması seç, bir cümle yaz → hangi niyetin seçildiğini, ilk 5 niyet puanını, yakalanan bilgileri (yer/saat/isim…), ilişki etkisini ve cevabı görürsün. Hiçbir şey kaydedilmez. Yeni desen eklediğinde burada denemen önerilir; bir cümle yanlış niyete gidiyorsa ilgili desene `weight` ver ya da daha belirgin bir ifade ekle.

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
  data/dialogue_life.lua        -- v3: yeni niyetler, cümle parçaları, teklifler, menü soruları
  data/adult_npcs.lua           -- v3: Vanilla Unicorn konumu, 'entertainer' rutini, 6 yetişkin NPC
  locales/tr.lua, en.lua        -- arayüz, anı ve olay metinleri
  bridge/qbx.lua, qb.lua, esx.lua
  bridge/phone.lua              -- v3: telefon köprüsü (auto/gksphone/lb-phone/npwd/qb-phone/custom/builtin)
  sql/install.sql               -- otomatik migrate
  sql/upgrade_v3.sql            -- v3: elle yükseltme (otomatik migrate zaten yapar; sadece yedek/manuel kurulum için)
  server/db.lua                 -- migrate, tohumlama, toplu yazım
  server/clock.lua              -- oyun/gerçek saat, hava
  server/simulation.lua         -- SOYUT KATMAN: rutin motoru, ihtiyaçlar, ruh hâli
  server/spawner.lua            -- FİZİKSEL KATMAN: ped/araç, sahiplik, görevler
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
  server/npc_manager.lua        -- v3: merkezi NPC erişimi (SC.NPC)
  server/npc_state.lua          -- v3: öncelikli durum makinesi (scState)
  server/npc_personality.lua    -- v3: kişilik puanları, ton, ruh hâli etiketi, karar motoru
  server/npc_context.lua        -- v3: kısa süreli konuşma bağlamı (RAM, TTL ile temizlenir)
  server/npc_relationship.lua   -- v3: ilişki XP'si, istatistikler, flört/sevgili, kıskançlık
  server/npc_awareness.lua      -- v3: çevre farkındalığı (yağmur, gece, araç, yaralı, silah, polis, yer)
  server/npc_dialogue_gen.lua   -- v3: parçalardan cümle üretici + son kullanılan cümle geçmişi
  server/npc_intents.lua        -- v3: yeni niyet işleyicileri (Dialogue.Register)
  server/npc_companion.lua      -- v3: beraber yürüme, araca binme/inme, bir yere gitme, bekleme
  server/npc_interaction.lua    -- v3: sosyal + yetişkin etkileşim animasyonları (hizalama, senkron)
  server/adult_npc.lua          -- v3: yetişkin NPC kuralları, bölgeler, gizlilik
  server/npc_events.lua         -- v3: kendiliğinden konuşma, teklifler, yaklaşma, akıllı mesajlar
  server/npc_menu.lua           -- v3: konuşma paneli kategori menüsü + doğrulanan menü aksiyonları
  server/admin.lua              -- yönetim paneli API'si, rastgele sakin üretici
  server/main.lua               -- başlatma, döngüler, export'lar
  client/main.lua               -- ox_target, snap/saat callback'leri, hediye
  client/tasks.lua              -- aktivite → GTA görev eşlemesi (sahip istemci)
  client/npc_companion.lua      -- v3: takip, bekleme, araca binme/inme, sürüş görevleri (sahip istemci)
  client/npc_animation.lua      -- v3: etkileşim animasyonları (oyuncu + NPC), iptal tuşu
  client/debug.lua              -- /citizensdebug
  client/conversation.lua       -- NUI paneli + 3D baloncuklar
  client/world.lua              -- nişan/ateş/çarpma algılama
  client/hostage.lua            -- rehin alan oyuncu: tuşlar, kalkan animasyonu, ipucu metni
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
3. ESC ile vedalaş, sonra tekrar konuş: `Beni hatırlıyor musun?` → "Tabii! … konuşmuştuk, işimden ve senin işinden bahsetmiştik." Başka karakterinle git → seni tanımamalı.
4. Hafif hakaret → soğuk cevap, ilişki düşer. `Config.Moderation.SevereWords` içindeki ağır küfür → konuşmayı bitirir, loglanır.
5. `/citizensadmin → Sakin → İlişkiler → Anılar`: kaydedilen anılar; sil/sıfırla/puan düzenle çalışmalı.
6. Tanıdık bir sakinin yanından geç → bazen kendiliğinden selam verir ("Selam Ahmet!").

### Sosyal hayat
1. **Arkadaşlık:** eşikler `Config.Relationship.Stages`. Test için `İlişkiler → Düzenle` ile puanları ayarlayabilirsin.
2. **Numara:** Tanıdık aşamasında `Numaranı alabilir miyim?` → yeterli güven varsa verir; gksphone'a sakinin numarasından tanıtım SMS'i gelir.
3. **SMS:** O numaraya yaz; aynı diyalog motoru cevaplar (işteyse gecikmeli, uyuyorsa uyanınca).
4. **Randevu:** Arkadaş aşamasında (yüz yüze ya da SMS) `Yarın akşam 8'de Vespucci'de buluşalım mı?` → programına uygunsa kabul eder, sana bildirim düşer; değilse kendi uygun saatini önerir. Randevu saatinde sakin rutinini bırakıp oraya gider. Gelmezsen bekler, sonra serzeniş SMS'i atar ve bunu hatırlar.
5. **Tehdit:** Bir sakine silah doğrult → eller yukarı → kaçar → polis ihbarı (ps-dispatch/cd_dispatch). Sonraki görüşmede hesap sorar. Olay iş arkadaşlarına/komşularına yayılır: Selin'e silah doğrult → Elif (iş arkadaşı) seni "duymuş" olur ve ona sorarsan anlatır.
6. **NPC–NPC:** Aynı mekândaki sakinler zaman zaman sohbet eder; bir sakine başka bir sakini sorabilirsin (`Elif'i tanır mısın?`).

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

- **Sakinler:** canlı liste, ışınlan, yanına çağır, harita işaretleri, yeni sakin, **Rastgele üret** (isim/kişilik/meslek/geçmiş/hazır cevap havuzlarından taslak → düzenle → kaydet).
- **Sakin detayı:** kimlik/kişilik/**hazır cevaplar**/iş/araç/favoriler formu, günlük plan, bugünkü kayıt, dünün özeti, tanıdıklar, randevular, ilişkiler + anılar, durum (taburcu, hastane, hapis, taşındı).
- **Konumlar:** kapı/park/aktivite noktaları — "Bulunduğum yer" ve "Araçtaki yer" butonlarıyla; senaryo ve etiket seçimi.
- **Rutinler:** iş günü / tatil günü blokları, 24 saatlik önizleme, vardiya jetonları (`shift_start-150` gibi), `firm`, `roam`.
- **Diyalog testi:** bkz. 4.2.
- `/citizensdebug`: 3D metin (id, ad, aktivite, görev, ağ sahibi).

## 8. Güvenlik

- Tüm kararlar sunucuda: aksiyonlar ilişki aşamasına göre onaylanır, sakin asla eşya/para vermez; ilişki artışı mesaj başına ve günlük olarak sınırlıdır (spamla arkadaş olunamaz).
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

-- v3
exports['samy-citizens']:GetNPCData(npcId, citizenid)     -- profil, kişilik puanları, durum, ruh hâli (+ ilişki özeti)
exports['samy-citizens']:GetNPCState(npcId)               -- 'WORKING' | 'FOLLOWING' | 'TALKING' ...
exports['samy-citizens']:AnalyzeIntent(text, npcId)       -- { intent = 'ask_job', canonical = 'GET_JOB', score = ... }
exports['samy-citizens']:AddRelationshipXP(npcId, citizenid, 'gift', force)  -- Config.Relationship.XP.Sources anahtarı
exports['samy-citizens']:StartCompanion(npcId, src, force) -- force = true: NPC kararını atla
exports['samy-citizens']:StopCompanion(npcId)
exports['samy-citizens']:IsCompanion(npcId, src)
exports['samy-citizens']:PlayInteraction(npcId, src, animId) -- Config.Animation.Social / Config.AdultAnimations anahtarı
```

## 10. Entegrasyon notları

- **Telefon köprüsü (`bridge/phone.lua`):** `Config.Phone.Provider = 'auto'` sırasıyla `gksphone`, `lb-phone`, `npwd`, `qb-phone` kaynaklarından çalışanı seçer; kaynak sonradan başlar/durursa yeniden seçilir. `qb-phone` tek yönlüdür (NPC → oyuncu e-posta); cevap için yerleşik ekran (`/sakinmesaj`) açık kalır (`BuiltinFallback`). Kendi telefonun için `Provider = 'custom'` ve `Config.Phone.Custom.Send / GetNumber` fonksiyonlarını doldur; oyuncudan NPC'ye gelen mesajı sunucu tarafında `TriggerEvent('samy-citizens:phone:incoming', src, npcNumara, oyuncuNumara, metin)` ya da `exports['samy-citizens']:PhoneIncoming(src, npcNumara, oyuncuNumara, metin)` ile ilet (istemciden tetiklenemez).
- **gksphone v2:** NPC → oyuncu `exports.gksphone:SendMessage(npcNumara, oyuncuNumara, metin, { skipSIMUsage = true, saveSenderCopy = false })`; oyuncu → NPC `gksphone:messages:messageSent` event'i (alıcı numarası bir sakine aitse). Yol tarifi SMS'le `vector2` GPS mesajı olarak gider. gksphone kurulumun kayıtlı olmayan numaralara gönderimi engelliyorsa `Config.Phone.NumberPattern`'i telefonunun numara formatına uydur.
- **Dispatch:** `Config.Dispatch.System = 'ps-dispatch' | 'cd_dispatch' | 'custom' | 'none'`. `custom` için `Config.Dispatch.Custom(data)` fonksiyonunu doldur.
- **Hediye:** sakinlerde ox_target `Hediye ver` seçeneği vardır (sunucu `RemoveItem` ile eşyayı alır, günlük bonus sınırlıdır).
- **Saat senkronu:** qb-weathersync otomatik tanınır; başka bir sistemde `Config.TimeSource = 'client'` yeterlidir.
- **Rehine alma:** sunucunda başka bir rehine/kidnap script'i varsa `Config.Hostage.Enabled = false` ile kapat ya da `Config.Hostage.Keys` tuşlarını çakışmayacak şekilde değiştir (varsayılan `E/G/H/J/K`).

## 11. Bilinen sınırlamalar

- Oyun içinde test edilmedi (bu ortamda FiveM sunucusu yok); tüm Lua dosyaları sözdizimi denetiminden ve modüller arası çağrı/yerelleştirme anahtarı çapraz kontrolünden geçti. İlk kurulumda `Config.Debug = true` ile izlemen ve "Diyalog testi" sekmesinde birkaç cümle denemen önerilir.
- Kural tabanlı motor, yazılmamış bir konuyu "anlayamaz": desenlerde karşılığı olmayan cümlelere kısa bir "anlamadım" cevabı verir. Sunucuna özel sık sorulanları `SCDialogue.Custom`'a eklemek en etkili iyileştirmedir.
- Diyalog verisi Türkçedir; `Config.Locale = 'en'` sadece arayüz/anı metinlerini İngilizce yapar.
- Örnek koordinatlar yaklaşıktır (bkz. Kurulum).
- Sakin ped'leri ambient modeldir (freemode değil); kıyafet ilk spawn'da rastgele seçilip kalıcı kaydedilir.
- Günlük hız sınırı sayaçları bellek içindedir; kaynak yeniden başlatılınca sıfırlanır.
- v3 eşlikçi/araç/animasyon sistemi oyun içinde denenmedi; GTA görevleri (TaskGoToEntity, TaskEnterVehicle, TaskVehicleDriveToCoordLongrange…) ve animasyon hizalama ofsetleri gerçek sunucuda ince ayar isteyebilir (`Config.Animation.*.offset`, `Config.Follow.Offsets`).
- Vanilla Unicorn merkez/direk koordinatları yaklaşıktır; `/citizensadmin → Konumlar` ile düzelt.
- gksphone dışındaki telefon adaptörleri (lb-phone, npwd, qb-phone) resmî export'larına göre yazıldı ama bu ortamda denenmedi; sürüm farkında `Provider = 'custom'` ile kendi fonksiyonlarını bağla.
- Kısa süreli bağlam, teklifler, cümle geçmişi ve karar önbelleği RAM'dedir; kaynak yeniden başlayınca sıfırlanır (kalıcı olan: ilişki, XP, flört durumu, istatistikler, önemli anılar).

## 12. v3 — Yaşayan NPC katmanı

Mevcut sistem yeniden yazılmadı; tüm yeni özellikler mevcut simülasyon, diyalog, ilişki, anı, telefon ve spawner
modüllerinin üstüne ayrı modüller olarak eklendi. **Hiçbir harici yapay zekâ API'si kullanılmaz**; her şey sunucudaki
kural motorunda çalışır.

### 12.1 Kişilik, ruh hâli, durum
- Her sakinin `friendliness, humor, confidence, jealousy, patience, romantic, social, aggression` puanları (0–100) vardır.
  `data/residents.lua → SCData.Profiles` içindeki `stats` verilir; verilmezse mevcut `traits` listesinden türetilir
  (her sakin için sabit, kişiye özel küçük sapma ile). Admin panelinde sakin detayında görünür/düzenlenir.
- Profil ayrıca `likes, dislikes, favorite_areas, vehicle_pref, romance` (ilgi duyduğu cinsiyet), `schedule` (güne özel plan) içerir.
- Ruh hâli etiketi: `happy / normal / sad / angry / tired / excited / romantic` — ihtiyaçlar, saat, son olaylar ve o oyuncuya
  karşı anlık duygu birlikte hesaplanır; konuşma panelinde ve debug ekranında görünür.
- Merkezi durum makinesi (`Config.StateMachine.Priority`): `HOSTAGE > FLEEING > INTIMATE_INTERACTION > INTERACTING > TALKING >
  araç durumları > DATE > FOLLOWING > WAITING > SOCIALIZING > ... > IDLE`. Durum sadece değiştiğinde `scState` statebag'ine yazılır.

### 12.2 Niyet, bağlam, cümle üretici
- Yeni niyetler: `ask_where, ask_when, ask_relationship_status, ask_date, ask_stop, ask_ride, ask_go, ask_dislike,
  ask_activity, ask_touch, ask_us` (+ mevcutlar). Standart adlar `SCDialogue.Canonical` içinde (`GET_NAME, GET_JOB,
  ASK_FOLLOW, ASK_DATE, ...`).
- Desenler artık **kelime kombinasyonu** destekler: `{ 'sevgili', 'var mi|varmi|yok mu' }` — her grup cümlede (herhangi bir
  sırada) geçmeli, grup içinde `|` alternatif.
- Kısa süreli bağlam: "Nerede çalışıyorsun?" → "Kaçta gidiyorsun?" sorusu işe bağlanır; bağlam `Config.Intelligence`
  süresince RAM'de tutulur ve sonra temizlenir.
- Cümle üretici (`data/dialogue_life.lua → Parts`): selam + farkındalık + soru parçaları koşullu olarak birleştirilir.
  Her NPC son `Config.Dialogue.RecentHistorySize` cümlesini hatırlar, aynı cümleyi kısa sürede tekrar etmez.
- Kendi niyetini eklemek: `SC.Dialogue.Register('ask_xxx', function(ctx, out) ... end)` (örnekler: `server/npc_intents.lua`).

### 12.3 İlişki XP'si ve romantizm
- `Config.Relationship.Mode = 'hybrid'`: aşama = eski puan sistemi ile XP'nin **büyüğü** (mevcut oyuncular aşama kaybetmez;
  XP ilk açılışta mevcut aşamadan doldurulur). Seviyeler/etiketler `Config.Relationship.XP.Levels / Labels`.
- XP kaynakları (`Config.Relationship.XP.Sources`): konuşma, iyi sohbet, SMS, iltifat, hediye, beraber yürüme (dk),
  beraber araç yolculuğu, yer ziyareti, buluşma, etkileşim; cezalar: hakaret, kabalık, tehdit, bekletme, terk etme,
  buluşmaya gelmeme. Her kaynağın bekleme süresi ve günlük XP sınırı vardır (spamla ilerlenemez).
- Flört / sevgili: `ask_date` ile teklif; NPC'nin yaşı (`Romance.MinAge`), ilgi duyduğu cinsiyet, XP ve kişiliği
  değerlendirilir. Ağır olumsuz olaylar ayrılığa yol açabilir. Kıskanç NPC başka bir sakinle flört ettiğini duyarsa bozulur.

### 12.4 Beraber yürüme, araç, bir yere gitme
- Konuşmada "Benimle gel", "Burada bekle", "Gidebilirsin", "Arabama bin", "Vespucci'ye gidelim" ya da panel menüsü.
  Eşlikçi NPC yanındayken **`/sakinmenu` (varsayılan `F9`)** paneli açar (araçtayken de).
- Takip: oyuncunun yanında/arkasında ofsetle yürür, hızına göre yürür/koşar, durunca bekleme animasyonuna geçer;
  birden fazla NPC ofsetleri paylaşır. Işınlama **sadece son çare** ve NPC oyuncunun ekranında değilken yapılır.
- Araç: koltuklar sunucuda atanır (birden fazla NPC aynı aracı paylaşır, dolu koltuk seçilmez, yer yoksa "Yer yok");
  kapı kilitliyse bekler, başarısız binişte başka koltuk dener. Oyuncu inince NPC de iner.
- Bir Yere Git: listedeki yerler (`Config.Destinations.List`) ya da haritadaki işaret. NPC'nin arabası yakınsa kendisi sürer,
  oyuncu araçtaysa oyuncu sürer, yakınsa yürürsünüz. Varınca yer tipine göre beraber aktivite (içki, kahve, yemek…).
- İş/ders saati yaklaşınca NPC izin ister; uzun bekletilmek ve terk edilmek XP düşürür ve hatırlanır.

### 12.5 Sosyal ve yetişkin etkileşimler
- Sosyal (`Config.Animation.Social`): tokalaşma, sarılma, yanaktan öpme, omuza dokunma, çak bir beşlik, dans, beraber içki,
  fotoğraf/selfie, yan yana oturma (yakındaki banka otomatik hizalanır), öpüşme ve romantik sarılma (sadece flört/sevgili).
  NPC her teklifi ilişkiye, kişiliğe, ruh hâline ve duruma göre kabul/ret eder. İptal: `X` (tuş atamasından değişir).
- **Yetişkin kategori** (`Config.AdultNPC.Enabled = false` ile tamamen kapanır):
  - Sadece `AllowedTypes` (varsayılan `adult_entertainer`) ve yaşı `MinAge` (21) üstü NPC'lerde görünür; normal dünya NPC'lerinde
    hiçbir zaman görünmez. İstersen oyunculara ACE şartı: `RequireAce = true` + `add_ace group.vip samycitizens.adult allow`.
  - Her zaman oyuncu başlatır; NPC ret edebilir (ret sonrası `ConsentCooldownSec` bekleme). `private` etkileşimler çevrede
    başka oyuncu varsa başlamaz.
  - Animasyon kaydı `Config.AdultAnimations` (vanilla GTA V animasyonları: direk dansı, özel dans, araç içi yakın/samimi an —
    `mini@strip_club@...`, `mini@prostitutes@...`). Kendi animasyon paketini kullanmak için `Config.AdultNPC.ExternalPlayer`.
  - Vanilla Unicorn bölgesi (`Config.AdultNPCZones.VanillaUnicorn`) ve `data/adult_npcs.lua` içindeki 6 dansçı; bölge
    kapalıysa bu NPC'ler hiç oluşmaz.

### 12.6 Kendiliğinden davranışlar ve telefon
- `Config.AutoConversation`: konuşma sırasında sessiz kalınırsa NPC kendisi konu açar (kişiliğine göre sıklık).
- `Config.NPCEvents`: beraber gezerken kahve/sahil/bar teklifi ("olur" ya da ox_target `Teklifi kabul et`), arkadaşın seni
  görünce yanına gelip selam vermesi, geç saatte yorgunsa eve dönmek istemesi. Her tür için NPC–oyuncu çifti bekleme süresi.
- `Config.Phone.Proactive.Smart`: "Uzun süredir görmedim", "Dün güzel vakit geçirdik", "Bu akşam boş musun?" gibi mesajlar;
  NPC uyurken, çalışırken, gece geç saatte (oyun saati **ve** gerçek saat) yazmaz; günlük sınır ve aralık vardır.

### 12.7 Performans ve ağ
- Yeni NPC başına thread/0 ms döngü yok. Eşlikçi+etkileşim tek döngü (1 sn), olaylar tek döngü (5 sn), bağlam temizliği
  dakikada bir. İstemci tarafında görevler mevcut 1 sn'lik sahip döngüsünde; etkileşim sırasında sadece oyuncunun kendi
  kontrol kilidi için geçici döngü açılır ve biter.
- LOD: 0–150 m tam, 150–400 m azaltılmış (görev 3 sn'de bir izlenir), ötesi soyut rutin. Oyuncunun gözü önünde ped belirmez
  (spawn ertelenir), rutin ilerlemesi için ışınlama yapılmaz.
- Tüm yeni istemci event'leri sunucuda doğrulanır: menü aksiyonu (hız sınırı, konuşma sahipliği/mesafe), görev raporları
  (sadece ped'in network sahibi + sıra numarası), teklif kabulü (mesafe + bekleyen teklif), etkileşim iptali (sadece kendi
  etkileşimin), koltuk sayısı (sınırlandırılır), harita işareti (koordinat sınırı).
- Temizlik: oyuncu çıkınca eşlikçi/etkileşim/konuşma biter; kaynak durunca tüm eşlikçiler bırakılır, animasyonlar
  durdurulur; kaynak başlarken önceki çalışmadan kalan sakin ped/araçları süpürülür (`StartupSweep`); aynı sakin iki kez oluşmaz.

### 12.8 Veritabanı
- Otomatik migrate: `samy_citizens_residents.profile`, `samy_citizens_relationships.xp / romance / first_met / last_contact /
  daily_xp / stats` sütunları ve indeksler eklenir; XP ve `first_met` mevcut verilerden doldurulur. Elle kurulum için
  `sql/upgrade_v3.sql`. Sadece önemli olaylar anı olarak yazılır (ilk buluşma, flört başlangıcı, terk edilme, ayrılık…);
  küçük durumlar JSON sütunlarında tutulur.

### 12.9 Test adımları (v3)
1. Konsolda `hazır: 16 sakin (6 yetişkin) ...` satırı. `/citizensdebug` → ped üstünde `State, Mood, Relationship, XP,
   Destination, Vehicle, CurrentActivity, LastIntent, Schedule`.
2. Bir sakinle konuş: panelin üstünde kategoriler (Konuş, Soru Sor, Beraber Yürü, Araca Davet Et, Bir Yere Git, Telefon,
   Aktiviteler, Sosyal Etkileşimler). "Nerede çalışıyorsun?" → "Kaçta gidiyorsun?" bağlamı; "Sevgilin var mı?".
3. Tanıdık+ bir sakine "Benimle gel" → yanında yürür; koş, dur, "Burada bekle", "Hadi gel", "Gidebilirsin".
4. Arabaya bin, panelden "Araca Davet Et" (ya da "Arabama bin") → boş koltuğa biner; iki NPC ile dolu araçta "Yer yok".
   Araçtan in → NPC de iner.
5. "Bir Yere Git → Vespucci Plajı" → biri sürer, varınca beraber aktivite ve XP.
6. Sosyal menüden tokalaşma/sarılma/dans/fotoğraf; bank yanında "Yan yana otur".
7. Vanilla Unicorn'a git → dansçılar; birine konuş → "Yetişkin Etkileşimleri" kategorisi (sadece burada görünür).
   `Config.AdultNPC.Enabled = false` → kategori ve dansçılar tamamen kaybolur.
8. Numarasını al, oyundan ayrıl/geri gel: uygun saatte kendiliğinden mesaj (gece/uykuda gelmez).
