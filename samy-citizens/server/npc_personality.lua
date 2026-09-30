--[[
    KİŞİLİK, RUH HÂLİ VE KARAR MOTORU
    - Stats: profile.stats (0-100) ya da kişilik özelliklerinden (traits) deterministik türetme
    - Tone : konuşma tonu (warm/formal/grumpy/shy/neutral) = trait tonu + puanlar + ilişki aşaması
             (ör. confidence düşük NPC yeni tanıştığı kişiye mesafeli/çekingen konuşur)
    - MoodLabel: happy / normal / sad / angry / tired / excited / romantic
             (saat, ihtiyaçlar, son olaylar, ilişki ve oyuncunun son davranışından)
    - Decide: takip, araç, buluşma, etkileşim gibi tekliflere kabul/ret kararı. Karar bir süre değişmez
             (Config.Intelligence.DecisionCooldownSec) — ısrar ederek "evet" koparılamaz.
]]
local Utils = SC.Utils
local Clock = SC.Clock
local Sim = SC.Sim

local Persona = {}
SC.Persona = Persona

local STAT_KEYS = { 'friendliness', 'humor', 'confidence', 'jealousy', 'patience', 'romantic', 'social', 'aggression' }
Persona.StatKeys = STAT_KEYS

-- trait kelimesi (katlanmış, kök) -> puan değişimleri
local TRAIT_EFFECTS = {
    { 'disa donuk', { social = 25, friendliness = 10, confidence = 10 } },
    { 'ice donuk', { social = -25, confidence = -10 } },
    { 'esprili', { humor = 35 } },
    { 'neseli', { humor = 20, friendliness = 15 } },
    { 'alayci', { humor = 20, friendliness = -10 } },
    { 'huysuz', { friendliness = -25, aggression = 15, patience = -20 } },
    { 'sert', { friendliness = -15, aggression = 20 } },
    { 'sessiz', { social = -20, confidence = -5 } },
    { 'supheci', { friendliness = -12, confidence = 5 } },
    { 'kibar', { friendliness = 12, aggression = -10 } },
    { 'nazik', { friendliness = 15, aggression = -10 } },
    { 'sabirsiz', { patience = -30 } },
    { 'sabirli', { patience = 30 } },
    { 'iyimser', { friendliness = 10, humor = 10 } },
    { 'cekingen', { confidence = -30, social = -15 } },
    { 'utangac', { confidence = -30, social = -10 } },
    { 'enerjik', { social = 15 } },
    { 'konuskan', { social = 25 } },
    { 'duygusal', { romantic = 20, jealousy = 15 } },
    { 'hayalperest', { romantic = 15 } },
    { 'flortoz', { romantic = 30, confidence = 15 } },
    { 'sakin', { patience = 20, aggression = -10 } },
    { 'inatci', { patience = -10 } },
    { 'hirsli', { confidence = 20 } },
    { 'ozguvenli', { confidence = 30 } },
    { 'mesafeli', { friendliness = -15, confidence = -5 } },
    { 'sicakkanli', { friendliness = 20, social = 10 } },
    { 'sefkatli', { friendliness = 20 } },
    { 'koruyucu', { jealousy = 15 } },
    { 'kiskanc', { jealousy = 35 } },
    { 'tartismaci', { aggression = 15 } },
    { 'asabi', { aggression = 25, patience = -20 } },
    { 'merakli', { social = 10 } },
    { 'yalniz', { social = -15 } },
    { 'guvenilir', { friendliness = 5 } },
}

-- ---------------------------------------------------------------------
-- Puanlar
-- ---------------------------------------------------------------------
function Persona.Stats(r)
    if r._stats then return r._stats end
    local def = (Config.Intelligence and Config.Intelligence.DefaultStats) or {}
    local out = {}
    for _, k in ipairs(STAT_KEYS) do out[k] = def[k] or 50 end
    local given = type(r.profile) == 'table' and type(r.profile.stats) == 'table' and r.profile.stats or nil
    if not given and (not Config.Intelligence or Config.Intelligence.DeriveFromTraits ~= false) then
        local traits = Utils.Fold(table.concat((r.personality and r.personality.traits) or {}, ' '))
        for _, e in ipairs(TRAIT_EFFECTS) do
            if traits:find(Utils.Fold(e[1]), 1, true) then
                for k, v in pairs(e[2]) do out[k] = (out[k] or 50) + v end
            end
        end
        local jitter = (Config.Intelligence and Config.Intelligence.StatJitter) or 8
        if jitter > 0 then
            for _, k in ipairs(STAT_KEYS) do
                out[k] = out[k] + (Utils.Hash(r.id .. ':stat:' .. k) % (jitter * 2 + 1)) - jitter
            end
        end
        -- yaş: gençler biraz daha romantik/sosyal, yaşlılar sabırlı
        local age = r.age or 30
        if age >= 55 then
            out.patience = out.patience + 10
            out.romantic = out.romantic - 15
        elseif age <= 25 then
            out.social = out.social + 5
            out.patience = out.patience - 5
        end
    elseif given then
        for _, k in ipairs(STAT_KEYS) do
            if tonumber(given[k]) then out[k] = tonumber(given[k]) end
        end
    end
    for _, k in ipairs(STAT_KEYS) do out[k] = Utils.Clamp(math.floor(out[k] + 0.5), 0, 100) end
    r._stats = out
    return out
end

function Persona.Invalidate(r)
    r._stats = nil
    r._tone = nil
    r._quirks = nil
end

-- ---------------------------------------------------------------------
-- Ton
-- ---------------------------------------------------------------------
function Persona.Tone(r, stage)
    local base = SC.Dialogue and SC.Dialogue.BaseTone and SC.Dialogue.BaseTone(r) or 'neutral'
    local s = Persona.Stats(r)
    local tone = base
    if base == 'neutral' then
        if s.aggression >= 60 or s.patience <= 22 and s.friendliness < 50 then
            tone = 'grumpy'
        elseif s.friendliness >= 68 and s.social >= 55 then
            tone = 'warm'
        elseif s.confidence <= 35 then
            tone = 'shy'
        end
    end
    -- yeni tanıştığı birine karşı: özgüveni düşükse mesafeli, çok soğuk kişilikse ters
    if stage == 'stranger' then
        if s.confidence <= 30 and tone ~= 'formal' then tone = 'shy' end
        if s.friendliness <= 25 and tone == 'warm' then tone = 'neutral' end
    end
    return tone
end

-- ---------------------------------------------------------------------
-- Ruh hâli etiketi
-- ---------------------------------------------------------------------
local ANGRY_CODES = { harassment = true, aim_weapon = true, assaulted = true, threatened = true, kidnapped = true, car = true }

function Persona.MoodLabel(r, rel, cid)
    local n = r.needs or {}
    local m = r.mood or 0
    if cid and SC.Context then
        local mt = SC.Context.MoodTowards(r.id, cid)
        if mt <= -20 then return 'angry' end
    end
    local now = Clock.Now()
    for _, ev in ipairs(r.moodEvents or {}) do
        if ev.code and ANGRY_CODES[ev.code] and (now - (ev.at or 0)) < 90 and (ev.value or 0) < -15 then return 'angry' end
    end
    if (n.energy or 50) < 22 then return 'tired' end
    local mod = Clock.MinuteOfDay()
    local evening = mod >= 19 * 60 or mod < 2 * 60
    if rel and rel.romance and rel.romance ~= 'none' and m > -10 and evening then return 'romantic' end
    if m >= 55 and (n.fun or 50) >= 55 then return 'excited' end
    if m >= 18 then return 'happy' end
    if m <= -35 then return 'sad' end
    return 'normal'
end

-- ---------------------------------------------------------------------
-- İlişki kazanımı çarpanı (friendliness yüksekse daha kolay arkadaş olur)
-- ---------------------------------------------------------------------
function Persona.GainMultiplier(r, positive)
    if Config.Intelligence and Config.Intelligence.FriendlinessGain == false then return 1.0 end
    local s = Persona.Stats(r)
    if positive then return 0.7 + s.friendliness / 100 * 0.6 end
    -- olumsuz etkiyi sabırsız / agresif NPC daha çok hisseder
    return 0.8 + (100 - s.patience) / 100 * 0.3 + s.aggression / 100 * 0.2
end

-- ---------------------------------------------------------------------
-- Karar motoru
-- ---------------------------------------------------------------------
local decisions = {}

local STAGE_BONUS = { stranger = -15, acquaintance = 0, friend = 15, close_friend = 25 }
local ROMANCE_BONUS = { dating = 25, partner = 35 }
local MOVE_KINDS = { follow = true, ride = true, go = true }
local ROMANTIC_KINDS = { romantic = true, date = true, intimate = true }
local WORK_FRIENDLY = { touch = true, intimate = true, phone = true, romantic = true }

function Persona.Rules(r, kind)
    local def = SC.NPC and SC.NPC.TypeDef(r) or Config.NPCTypes.citizen
    return (def.rules and def.rules[kind]) or (Config.NPCTypes.citizen.rules[kind]) or {}
end

--[[
    Persona.Decide(r, rel, kind, opts) -> ok, reason, repeated
    kind: follow | ride | go | touch | romantic | phone | date | intimate
    opts: { cid, sub (alt anahtar: ör. etkileşim adı), bonus (ek puan), nocache }
    reason (ret): cold | stranger | stage | busy | tired | mood | default
]]
function Persona.Decide(r, rel, kind, opts)
    opts = opts or {}
    local cid = opts.cid or (rel and rel.citizenid) or '?'
    local key = r.id .. '|' .. cid .. '|' .. kind .. '|' .. tostring(opts.sub or '')
    local cd = (Config.Intelligence and Config.Intelligence.DecisionCooldownSec) or 90
    local now = os.time()
    local cached = decisions[key]
    if cached and not opts.nocache and now - cached.at < cd then return cached.ok, cached.reason, true end

    local function remember(ok, reason)
        if not opts.nocache then decisions[key] = { ok = ok, reason = reason, at = now } end
        return ok, reason, false
    end

    if not rel then return remember(false, 'default') end
    if rel.stage == 'enemy' or rel.stage == 'cold' then return remember(false, 'cold') end
    local romance = rel.romance and rel.romance ~= 'none' and rel.romance or nil
    local rules = Persona.Rules(r, kind)
    if rules.minStage and not SC.StageAtLeast(rel.stage, rules.minStage) and not romance then
        return remember(false, rel.stage == 'stranger' and 'stranger' or 'stage')
    end

    local s = Persona.Stats(r)
    local score = 50 + (rules.bonus or 0) + (opts.bonus or 0)
    score = score + (STAGE_BONUS[rel.stage] or 0) + (romance and ROMANCE_BONUS[romance] or 0)
    score = score + (s.friendliness - 50) * 0.4 + (s.social - 50) * 0.25
    if rel.stage == 'stranger' then score = score + (s.confidence - 50) * 0.3 end
    if ROMANTIC_KINDS[kind] then
        score = score + (s.romantic - 50) * 0.6
        if kind == 'intimate' then score = score + (s.confidence - 50) * 0.2 end
    elseif kind == 'touch' then
        score = score + (s.friendliness - 50) * 0.2
    end
    score = score + (rel.affinity or 0) * 0.2 + ((rel.trust or 0) - 30) * 0.15
    score = score + math.min(20, (tonumber(rel.xp) or 0) / 60)

    local mood = Persona.MoodLabel(r, rel, cid)
    if mood == 'happy' or mood == 'excited' then score = score + 10 end
    if mood == 'romantic' and ROMANTIC_KINDS[kind] then score = score + 15 end
    if mood == 'sad' then score = score - 10 end
    if mood == 'angry' then score = score - 30 end
    if mood == 'tired' and MOVE_KINDS[kind] then score = score - 22 end

    local act = r.state and r.state.activity
    local def = SC.Activities[act or '']
    local busy = def and def.busy
    if busy and not (SC.NPC.Type(r) ~= 'citizen' and WORK_FRIENDLY[kind]) then
        if MOVE_KINDS[kind] or kind == 'date' then score = score - 40 else score = score - 10 end
    end
    if act == 'sleep' then score = score - 50 end
    local mod = Clock.MinuteOfDay()
    if MOVE_KINDS[kind] and (mod >= 60 and mod < 6 * 60) and not romance then score = score - 15 end

    -- deterministik küçük sapma (aynı pencere içinde aynı sonuç)
    local window = math.floor(now / math.max(30, cd))
    score = score + (Utils.Hash(key .. ':' .. window) % 21) - 10

    local ok = score >= ((Config.Intelligence and Config.Intelligence.AcceptThreshold) or 50)
    if ok then return remember(true, nil) end
    local reason = 'default'
    if busy and (MOVE_KINDS[kind] or kind == 'date') then
        reason = 'busy'
    elseif mood == 'tired' and MOVE_KINDS[kind] then
        reason = 'tired'
    elseif mood == 'angry' or mood == 'sad' then
        reason = 'mood'
    elseif rel.stage == 'stranger' then
        reason = 'stranger'
    end
    return remember(false, reason)
end

-- Kararı unut (ör. başarılı bir etkileşimden sonra tekrar sorulabilsin)
function Persona.Forget(r, cid, kind, sub)
    decisions[r.id .. '|' .. tostring(cid) .. '|' .. kind .. '|' .. tostring(sub or '')] = nil
end

-- Bellek temizliği (Context tick'inden çağrılır)
function Persona.Cleanup()
    local now = os.time()
    local cd = (Config.Intelligence and Config.Intelligence.DecisionCooldownSec) or 90
    for k, d in pairs(decisions) do
        if now - d.at > cd then decisions[k] = nil end
    end
end

-- Sevdikleri / sevmedikleri (profil, yoksa hobiler)
function Persona.Likes(r)
    local p = r.profile or {}
    if type(p.likes) == 'table' and #p.likes > 0 then return p.likes end
    return (r.personality and r.personality.hobbies) or {}
end

function Persona.Dislikes(r)
    local p = r.profile or {}
    return type(p.dislikes) == 'table' and p.dislikes or {}
end

-- Metin bir sevdiği / sevmediği şeyle eşleşiyor mu (+1 sever, -1 sevmez, 0 nötr)
function Persona.Opinion(r, text)
    local f = Utils.Fold(text or '')
    if f == '' then return 0 end
    for _, d in ipairs(Persona.Dislikes(r)) do
        local stem = Utils.Fold(d):match('^(%a%a%a%a%a?)')
        if stem and f:find(stem, 1, true) then return -1 end
    end
    for _, l in ipairs(Persona.Likes(r)) do
        local stem = Utils.Fold(l):match('^(%a%a%a%a%a?)')
        if stem and f:find(stem, 1, true) then return 1 end
    end
    return 0
end
