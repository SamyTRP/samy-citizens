# samy-citizens

Kendi hayatı olan, konuşabilen, hatırlayan ve arkadaş olunabilen kalıcı "sakin" NPC sistemi (FiveM · QBX/QB/ESX · OneSync).

**Yapay zekâ yok.** Hiçbir dış servise, API anahtarına ya da Ollama'ya bağlanmaz; ek CPU/GPU yükü ve maliyeti yoktur. Konuşmalar
`data/dialogue.lua` içindeki hazır cümle/desen kütüphanesiyle, sunucuda çalışan kural tabanlı bir motorla yürür.

- Her sakinin adı, kişiliği, evi, işi, arabası ve haftalık rutini var; oyuncu bakmıyorken de yaşamaya (işe gitmeye, yemek yemeye, uyumaya) devam eder.
- Oyuncu serbestçe yazar; motor cümledeki niyeti (selam, meslek sorma, buluşma teklifi, tehdit…) ve bilgileri (yer, saat, gün, isim, meslek) algılar, sakinin kişiliğine ve ilişkinize uygun hazır cevabı seçer.
- Sakin oyuncuyu **karakter bazında** hatırlar (citizenid): adını, mesleğini, sevdiği şeyleri, son konuşmada neden bahsettiğinizi, ona silah doğrulttuğunu…
- Yabancı → Tanıdık → Arkadaş → Yakın arkadaş (ve Soğuk / Düşman). Numara verir, gksphone üzerinden SMS'leşir, buluşma ayarlar ve **gerçekten gelir**.
- Silah doğrultulunca eller yukarı, kaçar, polisi arar; olayı iş arkadaşlarına/komşularına anlatır, itibar mahallede yayılır.

---

## 1. Gereksinimler

| Kaynak | Not |
|---|---|
| OneSync | zorunlu (`onesync on` / Infinity) — sakinler sunucu tarafında oluşturulan network ped'leridir |
| `ox_lib`, `oxmysql`, `ox_target` | zorunlu |
| `qbx_core` / `qb-core` / `es_extended` | biri (varsayılan otomatik algılama, QBX öncelikli) |
| `gksphone` (v2) | SMS için (yoksa `Config.Phone.Provider = 'builtin'` ile yerleşik mini mesajlaşma) |
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
  locales/tr.lua, en.lua        -- arayüz, anı ve olay metinleri
  bridge/qbx.lua, qb.lua, esx.lua
  sql/install.sql               -- otomatik migrate
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
  server/admin.lua              -- yönetim paneli API'si, rastgele sakin üretici
  server/main.lua               -- başlatma, döngüler, export'lar
  client/main.lua               -- ox_target, snap/saat callback'leri, hediye
  client/tasks.lua              -- aktivite → GTA görev eşlemesi (sahip istemci)
  client/debug.lua              -- /citizensdebug
  client/conversation.lua       -- NUI paneli + 3D baloncuklar
  client/world.lua              -- nişan/ateş/çarpma algılama
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

## 11. Bilinen sınırlamalar

- Oyun içinde test edilmedi (bu ortamda FiveM sunucusu yok); tüm Lua dosyaları sözdizimi denetiminden ve modüller arası çağrı/yerelleştirme anahtarı çapraz kontrolünden geçti. İlk kurulumda `Config.Debug = true` ile izlemen ve "Diyalog testi" sekmesinde birkaç cümle denemen önerilir.
- Kural tabanlı motor, yazılmamış bir konuyu "anlayamaz": desenlerde karşılığı olmayan cümlelere kısa bir "anlamadım" cevabı verir. Sunucuna özel sık sorulanları `SCDialogue.Custom`'a eklemek en etkili iyileştirmedir.
- Diyalog verisi Türkçedir; `Config.Locale = 'en'` sadece arayüz/anı metinlerini İngilizce yapar.
- Örnek koordinatlar yaklaşıktır (bkz. Kurulum).
- Sakin ped'leri ambient modeldir (freemode değil); kıyafet ilk spawn'da rastgele seçilip kalıcı kaydedilir.
- Günlük hız sınırı sayaçları bellek içindedir; kaynak yeniden başlatılınca sıfırlanır.
