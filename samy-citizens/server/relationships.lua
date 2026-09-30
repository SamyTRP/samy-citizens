--[[
    NPC – karakter (citizenid) ilişkileri
    familiarity 0..100, affinity -100..100, trust 0..100, stage, görüşme günleri, telefon bilgisi...
    Önbellekte tutulur, değişiklikler toplu yazılır.
]]
local Utils = SC.Utils
local Rel = {}
SC.Rel = Rel

local cache = {}   -- key -> row
local dirty = {}   -- key -> true

local function key(npcId, cid) return npcId .. '|' .. cid end

local function defaultRow(npcId, cid)
    return {
        npc_id = npcId, citizenid = cid, char_name = nil,
        familiarity = 0, affinity = 0, trust = 10, stage = 'stranger',
        last_seen = 0, times_met = 0, meet_days = 0, last_meet_day = nil,
        phone_known = false, player_phone = nil, name_known = false, npc_name_shown = false, nickname = nil, facts = {},
        daily_date = nil, daily_affinity = 0, daily_trust = 0, daily_familiarity = 0, daily_gifts = 0,
        proactive_date = nil, proactive_count = 0, last_decay_day = nil,
        xp = 0, romance = 'none', first_met = 0, last_contact = 0, daily_xp = 0, stats = {},
        isNew = true,
    }
end

local function normalize(row)
    row.familiarity = tonumber(row.familiarity) or 0
    row.affinity = tonumber(row.affinity) or 0
    row.trust = tonumber(row.trust) or 0
    row.last_seen = tonumber(row.last_seen) or 0
    row.times_met = tonumber(row.times_met) or 0
    row.meet_days = tonumber(row.meet_days) or 0
    row.phone_known = row.phone_known == 1 or row.phone_known == true
    row.name_known = row.name_known == 1 or row.name_known == true
    row.npc_name_shown = row.npc_name_shown == 1 or row.npc_name_shown == true
    if type(row.facts) ~= 'table' then
        local f = Utils.JsonDecode(row.facts)
        row.facts = type(f) == 'table' and f or {}
    end
    row.daily_affinity = tonumber(row.daily_affinity) or 0
    row.daily_trust = tonumber(row.daily_trust) or 0
    row.daily_familiarity = tonumber(row.daily_familiarity) or 0
    row.daily_gifts = tonumber(row.daily_gifts) or 0
    row.proactive_count = tonumber(row.proactive_count) or 0
    row.xp = tonumber(row.xp) or 0
    row.daily_xp = tonumber(row.daily_xp) or 0
    row.first_met = tonumber(row.first_met) or 0
    row.last_contact = tonumber(row.last_contact) or 0
    if row.romance ~= 'dating' and row.romance ~= 'partner' then row.romance = 'none' end
    if type(row.stats) ~= 'table' then
        local st = Utils.JsonDecode(row.stats)
        row.stats = type(st) == 'table' and st or {}
    end
    for _, f in ipairs({ 'char_name', 'last_meet_day', 'player_phone', 'nickname', 'daily_date', 'proactive_date', 'last_decay_day' }) do
        if row[f] == '' then row[f] = nil end
    end
    return row
end

-- ---------------------------------------------------------------------
-- Aşama hesabı
-- ---------------------------------------------------------------------
function Rel.ComputeStage(r)
    local S = Config.Relationship.Stages
    if r.affinity <= S.enemy.maxAffinity then return 'enemy' end
    if r.affinity <= S.cold.maxAffinity then return 'cold' end
    local st = 'stranger'
    if r.familiarity >= S.acquaintance.familiarity and r.times_met >= S.acquaintance.timesMet then
        st = 'acquaintance'
        if r.familiarity >= S.friend.familiarity and r.affinity >= S.friend.affinity and r.trust >= S.friend.trust and r.meet_days >= S.friend.meetDays then
            st = 'friend'
            local C = S.close_friend
            if r.familiarity >= C.familiarity and r.affinity >= C.affinity and r.trust >= C.trust and r.meet_days >= C.meetDays then
                st = 'close_friend'
            end
        end
    end
    -- v3: ilişki XP'si ('hybrid' = ikisinden yüksek olan, 'xp' = sadece XP)
    local mode = Config.Relationship.Mode or 'classic'
    if mode ~= 'classic' and SC.RelXP and SC.RelXP.Enabled() then
        local xs = SC.RelXP.LevelId(tonumber(r.xp) or 0)
        if mode == 'xp' or (SC.StageOrder[xs] or 0) > (SC.StageOrder[st] or 0) then st = xs end
    end
    return st
end

function Rel.StageLabel(stage)
    local lbl = Config.Relationship.Labels and Config.Relationship.Labels[stage or 'stranger']
    if lbl and lbl ~= '' then return lbl end
    return L('stage_' .. (stage or 'stranger'))
end

local function refreshStage(row)
    local old = row.stage
    row.stage = Rel.ComputeStage(row)
    if SC.StageAtLeast(row.stage, 'acquaintance') then row.name_known = true end
    return old ~= row.stage, old
end

-- Günlük sayaçları sıfırla
local function ensureDaily(row)
    local today = SC.Clock.RealDateKey()
    if row.daily_date ~= today then
        row.daily_date = today
        row.daily_affinity = 0
        row.daily_trust = 0
        row.daily_familiarity = 0
        row.daily_gifts = 0
        row.daily_xp = 0
    end
end
Rel.EnsureDaily = ensureDaily
Rel.RefreshStage = function(row) return refreshStage(row) end

-- Uzun süre görüşülmeyince familiarity azalır (tembel hesap)
-- last_decay_day: son azaltmanın uygulandığı unix zamanı (metin olarak saklanır)
local function applyDecay(row)
    if row.last_seen <= 0 then return end
    local now = os.time()
    local base = row.last_seen + (Config.Relationship.DecayAfterDays or 5) * 86400
    local lastTs = tonumber(row.last_decay_day)
    if lastTs and lastTs > base then base = lastTs end
    if now <= base then return end
    local days = math.floor((now - base) / 86400)
    if days < 1 then return end
    row.familiarity = math.max(0, row.familiarity - days * (Config.Relationship.DecayPerDay or 2))
    row.last_decay_day = tostring(base + days * 86400)
    refreshStage(row)
    dirty[key(row.npc_id, row.citizenid)] = true
end

-- ---------------------------------------------------------------------
-- Okuma
-- ---------------------------------------------------------------------
-- Thread içinden çağrılmalı (DB'den yükleyebilir)
function Rel.Get(npcId, cid)
    if not npcId or not cid then return nil end
    local k = key(npcId, cid)
    local row = cache[k]
    if not row then
        local dbRow = MySQL.single.await('SELECT * FROM samy_citizens_relationships WHERE npc_id = ? AND citizenid = ?', { npcId, cid })
        if dbRow then
            row = normalize(dbRow)
        else
            row = defaultRow(npcId, cid)
        end
        cache[k] = row
    end
    row.cachedAt = os.time()
    applyDecay(row)
    ensureDaily(row)
    return row
end

-- Sadece önbellek (await etmez)
function Rel.Peek(npcId, cid)
    return cache[key(npcId, cid)]
end

-- Bir karakterin tüm ilişkilerini önbelleğe al (yoldan geçerken selam için; thread içinden)
function Rel.Preload(cid)
    local rows = MySQL.query.await('SELECT * FROM samy_citizens_relationships WHERE citizenid = ?', { cid }) or {}
    local now = os.time()
    for _, row in ipairs(rows) do
        local k = key(row.npc_id, row.citizenid)
        if cache[k] then
            cache[k].cachedAt = now
        else
            local r = normalize(row)
            r.cachedAt = now
            cache[k] = r
        end
    end
end

function Rel.MarkDirty(row)
    dirty[key(row.npc_id, row.citizenid)] = true
end

-- ---------------------------------------------------------------------
-- Değişiklikler
-- ---------------------------------------------------------------------
--[[
    Puan değişimi. opts.bypassCap = true ise mesaj başı ±5 ve günlük sınır uygulanmaz
    (oyun olayları için: silah doğrultma, hediye vb.)
    dönüş: stageChanged, oldStage
]]
function Rel.ApplyDelta(row, dAff, dTrust, opts)
    opts = opts or {}
    ensureDaily(row)
    dAff = math.floor(tonumber(dAff) or 0)
    dTrust = math.floor(tonumber(dTrust) or 0)
    if not opts.bypassCap then
        local m = Config.Relationship.MaxDeltaPerMessage or 5
        dAff = Utils.Clamp(dAff, -m, m)
        dTrust = Utils.Clamp(dTrust, -m, m)
        if dAff > 0 then
            local room = math.max(0, (Config.Relationship.DailyAffinityCap or 15) - row.daily_affinity)
            dAff = math.min(dAff, room)
            row.daily_affinity = row.daily_affinity + dAff
        end
        if dTrust > 0 then
            local room = math.max(0, (Config.Relationship.DailyTrustCap or 12) - row.daily_trust)
            dTrust = math.min(dTrust, room)
            row.daily_trust = row.daily_trust + dTrust
        end
    end
    row.affinity = Utils.Clamp(row.affinity + dAff, -100, 100)
    row.trust = Utils.Clamp(row.trust + dTrust, 0, 100)
    Rel.MarkDirty(row)
    local changed, old = refreshStage(row)
    if SC.RelXP and dAff < 0 then SC.RelXP.OnDelta(row) end
    return changed, old, dAff, dTrust
end

function Rel.AddFamiliarity(row, amount, bypassCap)
    ensureDaily(row)
    amount = math.floor(amount or 0)
    if amount > 0 and not bypassCap then
        local room = math.max(0, (Config.Relationship.DailyFamiliarityCap or 12) - row.daily_familiarity)
        amount = math.min(amount, room)
        row.daily_familiarity = row.daily_familiarity + amount
    end
    row.familiarity = Utils.Clamp(row.familiarity + amount, 0, 100)
    Rel.MarkDirty(row)
    return refreshStage(row)
end

--[[
    Konuşma/buluşma başında çağrılır.
    dönüş: { firstMeeting = bool, daysAway = number, newDay = bool }
]]
function Rel.OnMeet(row, charName)
    ensureDaily(row)
    local info = { firstMeeting = row.times_met == 0, daysAway = 0, newDay = false }
    if row.last_seen > 0 then
        info.daysAway = math.floor((os.time() - row.last_seen) / 86400)
    end
    row.char_name = charName or row.char_name
    row.times_met = row.times_met + 1
    if (row.first_met or 0) <= 0 then row.first_met = os.time() end
    local dayKey = SC.Clock.RelationshipDayKey()
    if row.last_meet_day ~= dayKey then
        row.last_meet_day = dayKey
        row.meet_days = row.meet_days + 1
        info.newDay = true
        Rel.AddFamiliarity(row, Config.Relationship.FamiliarityPerNewDay or 5)
    end
    row.last_seen = os.time()
    row.isNew = false
    Rel.MarkDirty(row)
    refreshStage(row)
    return info
end

function Rel.Touch(row)
    row.last_seen = os.time()
    Rel.MarkDirty(row)
end

-- ---------------------------------------------------------------------
-- Kalıcılık
-- ---------------------------------------------------------------------
local function s(v) if v == nil then return '' end return v end

function Rel.Flush(sync)
    local queries = {}
    for k in pairs(dirty) do
        local row = cache[k]
        if row then
            queries[#queries + 1] = {
                query = [[INSERT INTO samy_citizens_relationships
                    (npc_id, citizenid, char_name, familiarity, affinity, trust, stage, last_seen, times_met, meet_days, last_meet_day,
                     phone_known, player_phone, name_known, npc_name_shown, nickname, daily_date, daily_affinity, daily_trust, daily_familiarity, daily_gifts,
                     proactive_date, proactive_count, last_decay_day, facts, xp, romance, first_met, last_contact, daily_xp, stats)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON DUPLICATE KEY UPDATE char_name = VALUES(char_name), familiarity = VALUES(familiarity), affinity = VALUES(affinity),
                    trust = VALUES(trust), stage = VALUES(stage), last_seen = VALUES(last_seen), times_met = VALUES(times_met),
                    meet_days = VALUES(meet_days), last_meet_day = VALUES(last_meet_day), phone_known = VALUES(phone_known),
                    player_phone = VALUES(player_phone), name_known = VALUES(name_known), npc_name_shown = VALUES(npc_name_shown), nickname = VALUES(nickname),
                    daily_date = VALUES(daily_date), daily_affinity = VALUES(daily_affinity), daily_trust = VALUES(daily_trust),
                    daily_familiarity = VALUES(daily_familiarity), daily_gifts = VALUES(daily_gifts), proactive_date = VALUES(proactive_date),
                    proactive_count = VALUES(proactive_count), last_decay_day = VALUES(last_decay_day), facts = VALUES(facts),
                    xp = VALUES(xp), romance = VALUES(romance), first_met = VALUES(first_met), last_contact = VALUES(last_contact),
                    daily_xp = VALUES(daily_xp), stats = VALUES(stats)]],
                values = {
                    row.npc_id, row.citizenid, s(row.char_name), row.familiarity, row.affinity, row.trust, row.stage,
                    row.last_seen, row.times_met, row.meet_days, s(row.last_meet_day),
                    row.phone_known and 1 or 0, s(row.player_phone), row.name_known and 1 or 0, row.npc_name_shown and 1 or 0, s(row.nickname),
                    s(row.daily_date), row.daily_affinity, row.daily_trust, row.daily_familiarity, row.daily_gifts,
                    s(row.proactive_date), row.proactive_count, s(row.last_decay_day), json.encode(row.facts or {}),
                    math.floor(tonumber(row.xp) or 0), row.romance or 'none', math.floor(tonumber(row.first_met) or 0),
                    math.floor(tonumber(row.last_contact) or 0), math.floor(tonumber(row.daily_xp) or 0), json.encode(row.stats or {}),
                },
            }
        end
    end
    dirty = {}
    if #queries == 0 then return end
    if sync then MySQL.transaction.await(queries) else MySQL.transaction(queries) end
end

-- Uzun süredir kullanılmayan önbellek girdilerini at
function Rel.PruneCache()
    local cutoff = os.time() - 1800
    for k, row in pairs(cache) do
        if not dirty[k] and (row.cachedAt or 0) < cutoff then cache[k] = nil end
    end
end

-- ---------------------------------------------------------------------
-- Sorgular / yönetim
-- ---------------------------------------------------------------------
function Rel.ListForNpc(npcId)
    Rel.Flush(true)
    local rows = MySQL.query.await('SELECT * FROM samy_citizens_relationships WHERE npc_id = ? ORDER BY last_seen DESC LIMIT 200', { npcId }) or {}
    for i, row in ipairs(rows) do rows[i] = normalize(row) end
    return rows
end

function Rel.ListForCitizen(cid)
    Rel.Flush(true)
    local rows = MySQL.query.await('SELECT * FROM samy_citizens_relationships WHERE citizenid = ?', { cid }) or {}
    for i, row in ipairs(rows) do rows[i] = normalize(row) end
    return rows
end

-- Numarası bilinen ve en az belirli aşamadaki ilişkiler (akıllı proaktif mesaj için; thread içinden)
function Rel.WithPhone(npcId)
    local rows = MySQL.query.await([[SELECT * FROM samy_citizens_relationships WHERE npc_id = ? AND phone_known = 1]], { npcId }) or {}
    local out = {}
    for _, row in ipairs(rows) do
        local k = key(row.npc_id, row.citizenid)
        if not cache[k] then
            local r = normalize(row)
            r.cachedAt = os.time()
            cache[k] = r
        end
        out[#out + 1] = cache[k]
    end
    return out
end

-- Yakın arkadaşlar (proaktif SMS için)
function Rel.CloseFriendsWithPhone(npcId)
    Rel.Flush(true)
    local rows = MySQL.query.await([[SELECT * FROM samy_citizens_relationships
        WHERE npc_id = ? AND stage = 'close_friend' AND phone_known = 1]], { npcId }) or {}
    local out = {}
    for _, row in ipairs(rows) do
        local k = key(row.npc_id, row.citizenid)
        out[#out + 1] = cache[k] or normalize(row)
        if not cache[k] then cache[k] = out[#out] end
    end
    return out
end

function Rel.Reset(npcId, cid)
    local k = key(npcId, cid)
    cache[k] = nil
    dirty[k] = nil
    MySQL.update.await('DELETE FROM samy_citizens_relationships WHERE npc_id = ? AND citizenid = ?', { npcId, cid })
end

function Rel.Set(npcId, cid, fields)
    local row = Rel.Get(npcId, cid)
    for _, f in ipairs({ 'familiarity', 'affinity', 'trust', 'times_met', 'meet_days' }) do
        if fields[f] ~= nil then row[f] = math.floor(tonumber(fields[f]) or row[f]) end
    end
    if fields.phone_known ~= nil then row.phone_known = fields.phone_known == true end
    if fields.nickname ~= nil then row.nickname = fields.nickname ~= '' and fields.nickname or nil end
    if fields.xp ~= nil then row.xp = Utils.Clamp(math.floor(tonumber(fields.xp) or row.xp or 0), 0, (Config.Relationship.XP and Config.Relationship.XP.MaxXP) or 5000) end
    if fields.romance ~= nil then row.romance = (fields.romance == 'dating' or fields.romance == 'partner') and fields.romance or 'none' end
    row.familiarity = Utils.Clamp(row.familiarity, 0, 100)
    row.affinity = Utils.Clamp(row.affinity, -100, 100)
    row.trust = Utils.Clamp(row.trust, 0, 100)
    refreshStage(row)
    Rel.MarkDirty(row)
    return row
end

-- Oyuncu için hafif özet (NUI)
function Rel.PublicView(row)
    local display = SC.RelXP and SC.RelXP.DisplayStage(row) or row.stage
    local xp = tonumber(row.xp) or 0
    local nextMin
    for _, lv in ipairs((Config.Relationship.XP and Config.Relationship.XP.Levels) or {}) do
        if (lv.min or 0) > xp then nextMin = lv.min break end
    end
    if not nextMin and row.romance == 'none' and Config.Relationship.XP then nextMin = Config.Relationship.XP.DatingXP end
    return {
        stage = row.stage,
        stageLabel = Rel.StageLabel(row.stage),
        display = display,
        displayLabel = Rel.StageLabel(display),
        romance = row.romance or 'none',
        xp = xp,
        nextXp = nextMin,
        familiarity = row.familiarity,
        affinity = row.affinity,
        trust = row.trust,
        phoneKnown = row.phone_known,
        nameKnown = row.name_known,
    }
end
