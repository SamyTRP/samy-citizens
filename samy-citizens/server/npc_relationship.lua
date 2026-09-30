--[[
    İLİŞKİ XP'Sİ, İSTATİSTİKLERİ VE ROMANTİZM
    Mevcut ilişki sistemi (samimiyet/sevgi/güven + aşamalar) korunur; üzerine:
      - XP: sohbet, beraber yürüme, araç yolculuğu, bir yere gitme, hediye, iltifat (+) / hakaret, bekletme, terk (-)
            Her kaynağın bekleme süresi ve günlük pozitif üst sınırı vardır (spamla ilişki kurulamaz).
            Config.Relationship.Mode = 'hybrid' iken aşama = max(klasik aşama, XP aşaması).
      - İstatistik (stats JSON): beraber yolculuk, yürüyüş dakikası, buluşma, hediye, hakaret, iltifat, bekletme,
            terk, gidilen yerler { [konum] = sayı }, son yolculuk/buluşma zamanları
      - Romantizm (romance sütunu): none -> dating -> partner. Sadece yetişkin, flörte açık ve tercihi uyan NPC'lerde;
            yeterli XP ve rıza (kişilik/ruh hâli kararı) gerekir. Sevgi çok düşerse ilişki biter.
      - Kıskançlık: flörtün, seni başka bir NPC ile yakında görürse (ya da dedikodudan duyarsa) tepki verir.
    Veritabanına sadece önemli durum değişiklikleri yazılır (ilişki satırı zaten 60 sn'de bir toplu yazılıyor).
]]
local Utils = SC.Utils
local Sim = SC.Sim

local RelXP = {}
SC.RelXP = RelXP

local cooldowns = {}       -- 'npc|cid|kaynak' -> os.time()
local romanceIndex = {}    -- cid -> { at, map = { [npcId] = romance } }
local jealousyThrottle = {}

local function XPC() return Config.Relationship.XP or {} end
local function RC() return Config.Relationship.Romance or {} end

function RelXP.Enabled()
    return XPC().Enabled ~= false
end

-- ---------------------------------------------------------------------
-- İstatistikler
-- ---------------------------------------------------------------------
function RelXP.Stats(rel)
    if type(rel.stats) ~= 'table' then
        local decoded = type(rel.stats) == 'string' and Utils.JsonDecode(rel.stats) or nil
        rel.stats = type(decoded) == 'table' and decoded or {}
    end
    return rel.stats
end

function RelXP.Stat(rel, k, delta)
    local s = RelXP.Stats(rel)
    s[k] = (tonumber(s[k]) or 0) + (delta or 1)
    SC.Rel.MarkDirty(rel)
    return s[k]
end

function RelXP.SetStat(rel, k, v)
    RelXP.Stats(rel)[k] = v
    SC.Rel.MarkDirty(rel)
end

-- Beraber gidilen yer; ilk kez ya da uzun aradan sonra gidildiyse true
function RelXP.AddPlace(rel, locId)
    if not locId then return false end
    local s = RelXP.Stats(rel)
    s.places = type(s.places) == 'table' and s.places or {}
    local cnt = 0
    for _ in pairs(s.places) do cnt = cnt + 1 end
    if not s.places[locId] and cnt >= ((Config.Memory and Config.Memory.TrackPlacesMax) or 20) then
        -- en az gidilen yeri at
        local minK, minV
        for k, v in pairs(s.places) do
            if not minV or v < minV then minK, minV = k, v end
        end
        if minK then s.places[minK] = nil end
    end
    s.places[locId] = (tonumber(s.places[locId]) or 0) + 1
    s.lastPlace = locId
    local lastAt = tonumber(s.lastPlaceAt) or 0
    s.lastPlaceAt = os.time()
    SC.Rel.MarkDirty(rel)
    local cdh = (Config.Memory and Config.Memory.PlaceMemoryCooldownHours) or 12
    return s.places[locId] == 1 or (os.time() - lastAt) > cdh * 3600
end

-- ---------------------------------------------------------------------
-- XP
-- ---------------------------------------------------------------------
function RelXP.LevelId(xp)
    local best = 'stranger'
    for _, lv in ipairs(XPC().Levels or {}) do
        if (xp or 0) >= (lv.min or 0) then best = lv.id end
    end
    return best
end

function RelXP.Label(stage)
    local lbl = Config.Relationship.Labels and Config.Relationship.Labels[stage]
    if lbl and lbl ~= '' then return lbl end
    return L('stage_' .. tostring(stage))
end

-- Oyuncuya gösterilen aşama: flört/sevgili ise o, değilse arkadaşlık aşaması
function RelXP.DisplayStage(rel)
    if rel.romance == 'dating' or rel.romance == 'partner' then return rel.romance end
    return rel.stage or 'stranger'
end

--[[
    XP ekle. source: Config.Relationship.XP.Sources anahtarı
    opts = { r = sakin (kişilik çarpanı için), mult, src (seviye değişince bildirim), force (bekleme süresini yok say) }
    dönüş: eklenen XP, aşama değişti mi
]]
function RelXP.Add(rel, source, opts)
    if not rel or not RelXP.Enabled() then return 0, false end
    opts = opts or {}
    local def = (XPC().Sources or {})[source]
    if not def then return 0, false end
    local now = os.time()
    local ck = rel.npc_id .. '|' .. rel.citizenid .. '|' .. source
    if not opts.force and (def.cooldown or 0) > 0 and cooldowns[ck] and now - cooldowns[ck] < def.cooldown then
        return 0, false
    end
    cooldowns[ck] = now
    local amount = (def.xp or 0) * (opts.mult or 1)
    if opts.r and SC.Persona then amount = amount * SC.Persona.GainMultiplier(opts.r, amount > 0) end
    amount = math.floor(amount + (amount >= 0 and 0.5 or -0.5))
    if amount == 0 then return 0, false end
    SC.Rel.EnsureDaily(rel)
    if amount > 0 then
        local room = math.max(0, (XPC().DailyCap or 220) - (rel.daily_xp or 0))
        amount = math.min(amount, room)
        if amount <= 0 then return 0, false end
        rel.daily_xp = (rel.daily_xp or 0) + amount
    end
    local oldDisplay = RelXP.DisplayStage(rel)
    rel.xp = Utils.Clamp((tonumber(rel.xp) or 0) + amount, 0, XPC().MaxXP or 5000)
    SC.Rel.MarkDirty(rel)
    local changed = SC.Rel.RefreshStage(rel)
    if changed and opts.src and GetPlayerName(opts.src) then
        TriggerClientEvent('samy-citizens:client:notify', opts.src,
            L('notify_stage_changed', opts.r and opts.r.firstname or '?', RelXP.Label(RelXP.DisplayStage(rel))), 'success')
    end
    return amount, changed or oldDisplay ~= RelXP.DisplayStage(rel)
end

-- Rel.ApplyDelta sonrası: sevgi çok düştüyse romantik ilişki biter
function RelXP.OnDelta(rel)
    if rel.romance and rel.romance ~= 'none' and (rel.affinity or 0) <= (RC().BreakupAffinity or -30) then
        local r = Sim.Residents[rel.npc_id]
        RelXP.SetRomance(r, rel, 'none')
        if r then
            SC.Memory.AddAsync(r.id, rel.citizenid, L('mem_breakup', rel.char_name or L('ctx_this_person')), 7, 'event',
                { valence = -1, data = { code = 'breakup' } })
        end
    end
end

-- ---------------------------------------------------------------------
-- Romantizm
-- ---------------------------------------------------------------------
function RelXP.SetRomance(r, rel, value)
    value = (value == 'dating' or value == 'partner') and value or 'none'
    if rel.romance == value then return end
    rel.romance = value
    SC.Rel.MarkDirty(rel)
    local e = romanceIndex[rel.citizenid]
    if e then e.map[rel.npc_id] = value ~= 'none' and value or nil end
    if r and value ~= 'none' then
        SC.Memory.AddAsync(r.id, rel.citizenid, L(value == 'partner' and 'mem_partner' or 'mem_dating', rel.char_name or L('ctx_this_person')),
            8, 'event', { valence = 1, data = { code = value } })
    end
end

--[[
    Flört / partner teklifi değerlendirmesi. wantPartner: 'ciddi ilişki' istendi.
    dönüş: ok, satır anahtarı (data/dialogue_life.lua: date_accept, partner_accept, date_refuse_* ...), yeni romance
]]
function RelXP.EvaluateDate(r, rel, playerGender, wantPartner)
    if not Config.Relationship.Romance or RC().Enabled == false then return false, 'date_refuse_closed' end
    if (r.age or 0) < (RC().MinAge or 21) then return false, 'date_refuse_age' end
    if rel.stage == 'enemy' or rel.stage == 'cold' then return false, 'date_refuse_closed' end
    local p = type(r.profile) == 'table' and r.profile or {}
    local rom = type(p.romance) == 'table' and p.romance or {}
    if RC().RequireOpen ~= false and rom.open == false then return false, 'date_refuse_closed' end
    local prefers = rom.prefers or 'any'
    if prefers ~= 'any' and playerGender and prefers ~= playerGender then return false, 'date_refuse_pref' end
    local xp = tonumber(rel.xp) or 0
    local stats = RelXP.Stats(rel)
    if rel.romance == 'partner' then return false, 'date_already' end
    if rel.romance == 'dating' then
        if not wantPartner then return false, 'date_already' end
        local dates = (tonumber(stats.dates) or 0) + (tonumber(stats.visits) or 0)
        if xp < (XPC().PartnerXP or 2000) or dates < (XPC().PartnerMinDates or 3) then return false, 'partner_refuse' end
        local ok = SC.Persona.Decide(r, rel, 'date', { sub = 'partner', bonus = 15 })
        if not ok then return false, 'partner_refuse' end
        return true, 'partner_accept', 'partner'
    end
    local need = XPC().DatingXP or 1200
    local rules = SC.Persona.Rules(r, 'date')
    -- özel kategorilerde (ör. eğlence çalışanı) kural bonusu eşiği biraz düşürür
    need = math.max(0, need - (rules.bonus or 0) * 10)
    if xp < need then return false, 'date_refuse_stage' end
    local ok, reason = SC.Persona.Decide(r, rel, 'date')
    if not ok then return false, (reason == 'mood' or reason == 'tired') and 'date_refuse_mood' or 'date_refuse_stage' end
    return true, 'date_accept', 'dating'
end

-- Bir karakterin romantik ilişkileri (thread içinden; 5 dk önbellek)
function RelXP.RomancesOf(cid)
    local e = romanceIndex[cid]
    if e and os.time() - e.at < 300 then return e.map end
    local rows = MySQL.query.await([[SELECT npc_id, romance FROM samy_citizens_relationships
        WHERE citizenid = ? AND romance <> 'none']], { cid }) or {}
    local map = {}
    for _, row in ipairs(rows) do map[row.npc_id] = row.romance end
    -- henüz yazılmamış (önbellekteki) değişiklikler
    if e then
        for npcId, v in pairs(e.map) do
            local rel = SC.Rel.Peek(npcId, cid)
            if rel and rel.romance and rel.romance ~= 'none' then map[npcId] = rel.romance end
        end
    end
    romanceIndex[cid] = { at = os.time(), map = map }
    return map
end

--[[
    Kıskançlık: oyuncu targetR ile (takip, gezinti, romantik etkileşim) vakit geçirirken, flörtü olan başka bir NPC
    onu yakında görürse hemen tepki verir; görmezse kıskançlık puanıyla orantılı bir olasılıkla dedikodudan duyar.
]]
function RelXP.JealousyCheck(src, cid, targetR, kind)
    if not cid or not targetR or RC().Enabled == false then return end
    local tk = cid .. '|' .. targetR.id
    local now = os.time()
    if jealousyThrottle[tk] and now - jealousyThrottle[tk] < 600 then return end
    jealousyThrottle[tk] = now
    CreateThread(function()
        local map = RelXP.RomancesOf(cid)
        local ppos = SC.NPC.PlayerCoords(src)
        for npcId in pairs(map) do
            local a = Sim.Residents[npcId]
            if a and a.id ~= targetR.id and a.enabled and a.status == 'alive' then
                local jealous = SC.Persona.Stats(a).jealousy
                local rel = SC.Rel.Get(a.id, cid)
                local who = (rel.name_known and rel.char_name) or L('ctx_someone')
                local apos = SC.Spawner.GetPedCoords(a)
                if apos and ppos and Utils.Dist(apos, ppos) <= (RC().JealousyRadius or 50.0) and jealous >= 25 then
                    SC.Convo.Bubble(a, SC.Dialogue.Line('jealous', a, rel), 'npc', 5000)
                    SC.Spawner.SetEmotion(a, 'angry')
                    SC.Rel.ApplyDelta(rel, -math.floor(jealous / 10), -math.floor(jealous / 15), { bypassCap = true })
                    RelXP.Add(rel, 'rude', { r = a, mult = jealous / 40, force = true })
                    SC.Context.AddMoodTowards(a.id, cid, -math.floor(jealous / 2), 30)
                    SC.Memory.Add(a.id, cid, L('mem_jealous_seen', who, targetR.firstname), 5, 'event',
                        { valence = -1, data = { code = 'jealous' } })
                elseif math.random() < jealous * (RC().JealousyGossipChance or 0.004) then
                    SC.Memory.Add(a.id, cid, L('mem_jealous_heard', targetR.firstname, who), 4, 'gossip',
                        { valence = -1, sourceNpc = targetR.id, data = { code = 'jealous', from = targetR.id } })
                    SC.Rel.ApplyDelta(rel, -math.floor(jealous / 15), -2, { bypassCap = true })
                end
            end
        end
    end)
end

-- Bellek temizliği
function RelXP.Cleanup()
    local now = os.time()
    for k, t in pairs(cooldowns) do
        if now - t > 7200 then cooldowns[k] = nil end
    end
    for k, t in pairs(jealousyThrottle) do
        if now - t > 1800 then jealousyThrottle[k] = nil end
    end
    for cid, e in pairs(romanceIndex) do
        if now - e.at > 1800 then romanceIndex[cid] = nil end
    end
end
