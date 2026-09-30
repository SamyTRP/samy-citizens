--[[
    KURAL TABANLI DİYALOG MOTORU (yapay zekâ yok)
    1) Cümle katlanır (küçük harf, Türkçe karakter -> ASCII), uzatılmış harfler toparlanır ("selaaam"),
       kısaltmalar açılır ("nbr" -> "naber"), küçük yazım hataları tolere edilir ("tesekurler")
    2) Bilgi çıkarımı: yer, saat, gün, başka bir sakin, oyuncunun adı/mesleği/memleketi/sevdikleri
    3) Niyet puanlaması (data/dialogue.lua) + bağlam: bekleyen soru, son konu ("neden?", "gerçekten mi?", "sen?")
    4) Cevap: ilişki aşaması + kişilik tonu + ruh hâli + anılar + rutin durumuna göre şablondan seçilir.
       Aynı konuşmada aynı cümle tekrar edilmez; tek cümlede iki soru varsa ikisine de cevap verilir;
       sakin gerektiğinde sohbeti sürdürmek için kendisi de soru sorar.
    Motor yan etki üretmez; sonucu (cevap, ilişki değişimi, anılar, aksiyonlar) çağıran uygular.
]]
local Utils = SC.Utils
local Clock = SC.Clock
local Sim = SC.Sim
local D = SCDialogue

local Dialogue = {}
SC.Dialogue = Dialogue

-- =====================================================================
-- METİN YARDIMCILARI
-- =====================================================================
local upperFirst = { ['i'] = 'İ', ['ı'] = 'I', ['ç'] = 'Ç', ['ş'] = 'Ş', ['ğ'] = 'Ğ', ['ü'] = 'Ü', ['ö'] = 'Ö' }
local lowerFirst = { ['İ'] = 'i', ['I'] = 'ı', ['Ç'] = 'ç', ['Ş'] = 'ş', ['Ğ'] = 'ğ', ['Ü'] = 'ü', ['Ö'] = 'ö' }

local function firstChar(s)
    local c = s:match('^[%z\1-\127\194-\244][\128-\191]*')
    return c or s:sub(1, 1)
end

function Dialogue.Capitalize(s)
    if type(s) ~= 'string' or s == '' then return s or '' end
    local c = firstChar(s)
    local up = upperFirst[c] or c:upper()
    return up .. s:sub(#c + 1)
end

function Dialogue.Lowerfirst(s)
    if type(s) ~= 'string' or s == '' then return s or '' end
    local c = firstChar(s)
    local low = lowerFirst[c] or c:lower()
    return low .. s:sub(#c + 1)
end

local function isCapitalized(w)
    local c = firstChar(w)
    return c ~= '' and (upperFirst[Dialogue.Lowerfirst(c)] == c or (c:match('^%u$') ~= nil))
end

local function joinList(list)
    local items = {}
    for _, v in ipairs(list or {}) do if v and v ~= '' then items[#items + 1] = v end end
    if #items == 0 then return '' end
    if #items == 1 then return items[1] end
    return table.concat(items, ', ', 1, #items - 1) .. ' ve ' .. items[#items]
end
Dialogue.JoinList = joinList

local function normalize(folded)
    local n = folded:gsub('[^%w%s]', ' '):gsub('%s+', ' ')
    return Utils.Trim(n)
end

-- Oyuncu cümlesi: uzatılmış harfleri toparla ("selaaam" -> "selam"), kısaltmaları aç ("nbr" -> "naber")
local LETTERS = 'abcdefghijklmnopqrstuvwxyz'

local function normalizeInput(folded)
    local n = normalize(folded)
    -- 3+ aynı harf -> tek harf (Lua desenlerinde geri referansa niceleyici uygulanamadığı için harf harf)
    for ch in LETTERS:gmatch('.') do
        if n:find(ch .. ch .. ch, 1, true) then n = n:gsub(ch .. ch .. ch .. '+', ch) end
    end
    local out = {}
    for w in n:gmatch('%S+') do out[#out + 1] = (D.Slang and D.Slang[w]) or w end
    return table.concat(out, ' ')
end

local function tokenize(norm)
    local t = {}
    for w in norm:gmatch('%S+') do t[#t + 1] = w end
    return t
end

-- Orijinal kelimeler (büyük/küçük harf ve Türkçe karakter korunur) + katlanmış hâlleri
local function words(text)
    local out = {}
    for w in tostring(text or ''):gmatch('%S+') do
        local clean = w:gsub('[%p%d]', '')
        if clean ~= '' then out[#out + 1] = { orig = clean, fold = Utils.Fold(clean) } end
    end
    return out
end

-- a ile b arasında en fazla bir harf farkı (ekleme / silme / değiştirme) var mı
local function within1(a, b)
    if a == b then return true end
    local la, lb = #a, #b
    if la > lb then a, b, la, lb = b, a, lb, la end
    if lb - la > 1 then return false end
    local i = 1
    while i <= la and a:byte(i) == b:byte(i) do i = i + 1 end
    if la == lb then return a:sub(i + 1) == b:sub(i + 1) end
    return a:sub(i) == b:sub(i + 1)
end

-- Eşleşme katsayısı: 1 tam, 0.7 yazım hatasıyla, nil yok
-- pat tablo ise KELİME KOMBİNASYONU: her grup (herhangi bir sırada) eşleşmeli; grup içinde '|' ile alternatifler
local function matchPattern(norm, tokens, pat, fuzzy)
    if type(pat) == 'table' then
        local worst = 1
        for _, group in ipairs(pat) do
            local best
            for alt in tostring(group):gmatch('[^|]+') do
                local m = matchPattern(norm, tokens, alt, fuzzy)
                if m and (not best or m > best) then best = m end
            end
            if not best then return nil end
            if best < worst then worst = best end
        end
        return worst
    end
    if pat:sub(1, 1) == '=' then
        local w = pat:sub(2)
        for _, t in ipairs(tokens) do if t == w then return 1 end end
        if fuzzy and #w >= 6 then
            for _, t in ipairs(tokens) do
                if t:byte(1) == w:byte(1) and within1(t, w) then return 0.7 end
            end
        end
        return nil
    end
    if pat:find(' ', 1, true) then
        return (' ' .. norm .. ' '):find(' ' .. pat, 1, true) and 1 or nil
    end
    for _, t in ipairs(tokens) do
        if t:sub(1, #pat) == pat then return 1 end
    end
    if fuzzy and #pat >= 6 then
        local c1 = pat:byte(1)
        for _, t in ipairs(tokens) do
            if #t >= #pat - 1 and t:byte(1) == c1 then
                for len = #pat - 1, math.min(#t, #pat + 1) do
                    if within1(t:sub(1, len), pat) then return 0.7 end
                end
            end
        end
    end
    return nil
end

-- Desen uzunluğu (puanlamada uzun/özgül desenler daha ağır basar)
local function patLen(pat)
    if type(pat) ~= 'table' then return #pat end
    local n = 0
    for _, g in ipairs(pat) do n = n + #(tostring(g):match('^[^|]+') or '') + 1 end
    return n
end

local function hasToken(tokens, ...)
    for _, t in ipairs(tokens) do
        for _, w in ipairs({ ... }) do
            if t == w then return true end
        end
    end
    return false
end

local QUESTION_WORDS = { mi = true, mu = true, misin = true, musun = true, misiniz = true, musunuz = true, miyim = true, muyum = true,
    neden = true, niye = true, nasil = true, ne = true, kim = true, nerede = true, nereye = true, hangi = true, kac = true, nicin = true }

-- =====================================================================
-- BİLGİ ÇIKARIMI
-- =====================================================================
-- Saat: "20:00", "20.30", "saat 8", "8'de", "akşam 8", "sabah 9 buçuk" -> dakika (0..1439), belirsiz mi
function Dialogue.ParseTime(folded)
    local h, m
    local a, b = folded:match('(%d%d?)[:%.](%d%d)')
    if a then
        h, m = tonumber(a), tonumber(b)
    else
        local x = folded:match('saat%s*(%d%d?)') or folded:match("(%d%d?)%s*'?%s*[dt][ae]%f[%A]") or folded:match('(%d%d?)%s*gibi')
            or folded:match('aksam%s+(%d%d?)%f[%D]') or folded:match('sabah%s+(%d%d?)%f[%D]') or folded:match('gece%s+(%d%d?)%f[%D]')
            or folded:match('ogleden sonra%s+(%d%d?)%f[%D]')
        if x then h, m = tonumber(x), 0 end
    end
    local pm = folded:find('aksam', 1, true) or folded:find('gece', 1, true)
    local am = folded:find('sabah', 1, true)
    local noon = folded:find('ogle', 1, true)
    if h then
        if folded:find('bucuk', 1, true) and m == 0 then m = 30 end
        if h > 23 or m > 59 then return nil end
        if h < 12 then
            local isGece = folded:find('gece', 1, true)
            if pm and not (isGece and h <= 4) then
                h = h + 12
            elseif noon and h < 6 then
                h = h + 12
            elseif not am and h < 8 then
                h = h + 12
            end
        end
        return (h % 24) * 60 + m, false
    end
    if pm then return 20 * 60, true end
    if noon then return 12 * 60 + 30, true end
    if am then return 9 * 60 + 30, true end
    return nil
end

-- Gün: bugün 0, yarın 1, öbür gün 2, gün adları
function Dialogue.ParseDay(tokens)
    for i, t in ipairs(tokens) do
        if t:sub(1, 5) == 'yarin' then return 1 end
        if (t == 'obur' or t == 'ertesi') and tokens[i + 1] and tokens[i + 1]:sub(1, 3) == 'gun' then return 2 end
        if t:sub(1, 5) == 'bugun' or (t == 'bu' and tokens[i + 1] and tokens[i + 1]:sub(1, 5) == 'aksam') then return 0 end
    end
    local names = { { 'pazartesi', 1 }, { 'cumartesi', 6 }, { 'carsamba', 3 }, { 'persembe', 4 }, { 'pazar', 7 }, { 'cuma', 5 }, { 'sali', 2 } }
    for _, t in ipairs(tokens) do
        for _, n in ipairs(names) do
            if t:sub(1, #n[1]) == n[1] and #t <= #n[1] + 3 then
                return (n[2] - Clock.Weekday()) % 7
            end
        end
    end
    return nil
end

local function locCandidates(loc)
    if loc._cands then return loc._cands end
    local c = {}
    local function add(s)
        local n = normalize(Utils.Fold(s or ''))
        if #n >= 3 then c[#c + 1] = n end
    end
    add(loc.label)
    add(loc.id:gsub('_', ' '))
    for _, a in ipairs(loc.aliases or {}) do add(a) end
    loc._cands = c
    return c
end

function Dialogue.FindPlace(norm)
    local best, bestLen = nil, 0
    local padded = ' ' .. norm .. ' '
    for _, loc in pairs(Sim.Locations) do
        if loc.public then
            for _, cand in ipairs(locCandidates(loc)) do
                if #cand > bestLen and padded:find(' ' .. cand, 1, true) then
                    best, bestLen = loc, #cand
                end
            end
        end
    end
    return best
end

function Dialogue.FindPerson(tokens, self)
    for _, other in ipairs(Sim.List) do
        if other.id ~= self.id and other.enabled then
            local f = Utils.Fold(other.firstname)
            for _, t in ipairs(tokens) do
                if t == f or (#f >= 4 and t:sub(1, #f) == f and #t <= #f + 3) then return other end
            end
        end
    end
    return nil
end

local function cleanName(w)
    if not w or D.NotNames[w.fold] then return nil end
    local len = Utils.Utf8Len(w.orig)
    if len < 2 or len > 20 then return nil end
    return Dialogue.Capitalize(Dialogue.Lowerfirst(w.orig))
end

-- "benim adım X", "adım X", "ismim X", "bana X de", ("ben X" zayıf)
function Dialogue.ExtractName(text)
    local ws = words(text)
    for i, w in ipairs(ws) do
        if (w.fold == 'adim' or w.fold == 'ismim') and ws[i + 1] then
            local n = cleanName(ws[i + 1])
            if n then return n, false end
        end
        if w.fold == 'bana' and ws[i + 2] then
            local nx = ws[i + 2].fold
            if nx == 'de' or nx == 'derler' or nx:sub(1, 5) == 'diyeb' or nx == 'diye' then
                local n = cleanName(ws[i + 1])
                if n then return n, false end
            end
        end
    end
    if #ws >= 2 and #ws <= 3 and ws[1].fold == 'ben' then
        local n = cleanName(ws[2])
        if n then return n, true end
    end
    return nil
end

local COPULAS = { 'yım', 'yim', 'yum', 'yüm', 'ım', 'im', 'um', 'üm' }
local NOT_JOBS = { iyi = true, kotu = true, yorgun = true, hasta = true, mutlu = true, uzgun = true, burada = true, evde = true,
    hazir = true, ac = true, tok = true, yalniz = true, mesgul = true, bos = true, sen = true, ben = true, oyle = true,
    bilmiyor = true, bilm = true, yok = true, issiz = true }

local function stripCopula(word)
    for _, suf in ipairs(COPULAS) do
        if #word > #suf and word:sub(-#suf) == suf then
            local base = word:sub(1, #word - #suf)
            if Utils.Utf8Len(base) >= 3 then return base, true end
        end
    end
    return word, false
end

local JOB_FILLERS = { ben = true, bir = true, olarak = true, calisiyorum = true, yapiyorum = true, benim = true, meslegim = true,
    isim = true, is = true, iste = true, su = true, an = true, simdi = true, de = true, da = true, genelde = true, aslinda = true,
    sen = true, ya = true, peki = true }

-- "X olarak çalışıyorum", "mesleğim X", "ben polisim"; free = beklenen cevap ("Sen ne iş yapıyorsun?")
function Dialogue.ExtractJob(text, free)
    local ws = words(text)
    for i, w in ipairs(ws) do
        if w.fold == 'olarak' and i > 1 and ws[i + 1] and ws[i + 1].fold:sub(1, 5) == 'calis' then
            return Dialogue.Lowerfirst(ws[i - 1].orig)
        end
        if w.fold == 'meslegim' and ws[i + 1] then
            return (stripCopula(Dialogue.Lowerfirst(ws[i + 1].orig)))
        end
    end
    if #ws == 2 and ws[1].fold == 'ben' then
        local base, stripped = stripCopula(Dialogue.Lowerfirst(ws[2].orig))
        if stripped and not NOT_JOBS[Utils.Fold(base)] then return base end
    end
    if free then
        local rest = {}
        for _, w in ipairs(ws) do
            if not JOB_FILLERS[w.fold] then rest[#rest + 1] = w end
        end
        if #rest >= 1 and #rest <= 3 then
            local last = rest[#rest]
            local base = stripCopula(Dialogue.Lowerfirst(last.orig))
            if NOT_JOBS[Utils.Fold(base)] then return nil end
            local parts = {}
            for k = 1, #rest - 1 do parts[#parts + 1] = Dialogue.Lowerfirst(rest[k].orig) end
            parts[#parts + 1] = base
            return table.concat(parts, ' ')
        end
    end
    return nil
end

local LIKE_SKIP = { ben = true, cok = true, en = true, de = true, da = true, gercekten = true, asiri = true }

-- "balık tutmayı seviyorum", "en sevdiğim şey futbol"
function Dialogue.ExtractLike(text, free)
    local ws = words(text)
    for i, w in ipairs(ws) do
        local f = w.fold
        local nextF = ws[i + 1] and ws[i + 1].fold or ''
        local asked = nextF:sub(1, 2) == 'mu' or nextF:sub(1, 2) == 'mi' or f:find('sun$') or f:find('sin$')
        if not asked and (f:sub(1, 7) == 'seviyor' or f == 'severim' or f:sub(1, 7) == 'bayilir' or f:sub(1, 8) == 'bayiliyo' or f:sub(1, 8) == 'hoslanir' or f:sub(1, 9) == 'hoslaniyo') then
            local parts = {}
            for k = math.max(1, i - 3), i - 1 do
                if not LIKE_SKIP[ws[k].fold] then parts[#parts + 1] = ws[k].orig end
            end
            if #parts > 0 and not hasToken({ Utils.Fold(parts[1]) }, 'seni', 'sizi', 'onu') then
                return Dialogue.Lowerfirst(table.concat(parts, ' '))
            end
        end
        if f == 'sevdigim' and ws[i + 1] then
            local parts = {}
            for k = i + 1, math.min(#ws, i + 3) do
                if ws[k].fold ~= 'sey' and ws[k].fold ~= 'seyler' then parts[#parts + 1] = ws[k].orig end
            end
            if #parts > 0 then return Dialogue.Lowerfirst(table.concat(parts, ' ')) end
        end
    end
    if free and #ws >= 1 and #ws <= 5 then
        return Dialogue.Lowerfirst(Utils.Truncate(Utils.Trim(text):gsub('[%.!%?]+$', ''), 40))
    end
    return nil
end

-- "Paleto'luyum", "aslen Sandy Shores", "Liberty City'den geldim", "buralıyım" -> memleket, yerli mi
local ORIGIN_SUFFIX = { 'luyum', 'liyim', 'lıyım', 'lüyüm', 'luyuz', 'liyiz', 'lıyız', 'lüyüz', 'dayim', 'deyim', 'danim', 'denim',
    'tanim', 'tenim', 'dan', 'den', 'tan', 'ten', 'lu', 'li', 'lı', 'lü' }

function Dialogue.ExtractOrigin(text, free)
    local ws = words(text)
    for _, w in ipairs(ws) do
        if w.fold:sub(1, 6) == 'burali' or w.fold == 'buradanim' or w.fold:sub(1, 8) == 'losantos' then return 'Los Santos', true end
    end
    local idx
    for i, w in ipairs(ws) do
        local f = w.fold
        if (f == 'aslen' or f == 'memleketim') and ws[i + 1] then idx = i + 1 break end
        if (f:sub(1, 5) == 'dogum' or f == 'geldim' or f == 'tasindim' or f:sub(1, 6) == 'buyudu') and i > 1 then idx = i - 1 break end
    end
    if not idx then
        for i, w in ipairs(ws) do
            if isCapitalized(w.orig) and not D.NotNames[w.fold] then
                -- cümle başındaki büyük harf ancak memleket ekiyle (Paleto'luyum) ya da kısa cevapta sayılır
                local strong = w.fold:find('l[iu]y[iu]m$') or w.fold:find('d[ae]nim$')
                if i > 1 or #ws <= 2 or strong then
                    idx = i
                    break
                end
            end
        end
    end
    if not idx and free and #ws >= 1 and #ws <= 3 then idx = #ws end
    if not idx then return nil end
    local base = ws[idx].orig
    for _, suf in ipairs(ORIGIN_SUFFIX) do
        if #base > #suf + 2 and base:sub(-#suf) == suf then
            base = base:sub(1, #base - #suf)
            break
        end
    end
    -- iki kelimelik yer adı ("Sandy Shores", "Liberty City")
    if idx > 1 and isCapitalized(ws[idx - 1].orig) and not D.NotNames[ws[idx - 1].fold] and (idx - 1 > 1 or #ws <= 3) then
        base = ws[idx - 1].orig .. ' ' .. base
    end
    local f = Utils.Fold(base)
    if D.NotNames[f] or NOT_JOBS[f] or Utils.Utf8Len(base) < 2 or Utils.Utf8Len(base) > 30 then return nil end
    return Dialogue.Capitalize(base), false
end

-- Sorulmadan söylenen memleket: sadece belirgin ifadelerde ("Paleto'luyum", "aslen X", "X doğumluyum", "buralıyım")
function Dialogue.StrongOrigin(text)
    for _, w in ipairs(words(text)) do
        local f = w.fold
        if f:sub(1, 6) == 'burali' or f:find('dogumlu', 1, true) or f == 'aslen'
            or (#f >= 7 and f:find('l[iu]y[iu]m$') and isCapitalized(w.orig)) then
            return Dialogue.ExtractOrigin(text, false)
        end
    end
    return nil
end

-- =====================================================================
-- NİYET ANALİZİ
-- =====================================================================
local customIntents
local function allIntents()
    if customIntents then return customIntents end
    customIntents = {}
    for _, i in ipairs(D.Intents) do customIntents[#customIntents + 1] = i end
    for _, c in ipairs(D.Custom or {}) do
        customIntents[#customIntents + 1] = {
            id = 'custom:' .. tostring(c.id), patterns = c.patterns or {}, weight = c.weight or 1.3,
            custom = c,
        }
    end
    return customIntents
end

function Dialogue.Analyze(r, text)
    local folded = Utils.Fold(text or '')
    local norm = normalizeInput(folded)
    local tokens = tokenize(norm)
    local slots = {}
    slots.place = Dialogue.FindPlace(norm)
    slots.person = Dialogue.FindPerson(tokens, r)
    slots.name, slots.weakName = Dialogue.ExtractName(text)
    slots.time, slots.vagueTime = Dialogue.ParseTime(folded)
    slots.day = Dialogue.ParseDay(tokens)
    slots.job = Dialogue.ExtractJob(text, false)
    slots.like = Dialogue.ExtractLike(text, false)
    slots.origin, slots.originLocal = Dialogue.StrongOrigin(text)

    local fuzzyOn = Config.Dialogue.FuzzyMatch ~= false
    local scores = {}
    for _, intent in ipairs(allIntents()) do
        local ok = true
        for _, req in ipairs(intent.requires or {}) do
            if not slots[req] then ok = false end
        end
        if ok then
            local s = 0
            local fuzzy = fuzzyOn and not intent.exact
            for _, pat in ipairs(intent.patterns or {}) do
                local m = matchPattern(norm, tokens, pat, fuzzy)
                if m then s = s + (1 + math.min(patLen(pat), 18) / 6) * m end
            end
            if s > 0 then scores[intent.id] = s * (intent.weight or 1) end
        end
    end
    if slots.name and not slots.weakName then scores.introduce = math.max(scores.introduce or 0, 4.0) end
    if slots.name and slots.weakName then scores.introduce = math.max(scores.introduce or 0, 1.5) end
    if slots.person and not scores.ask_person then scores.ask_person = 1.2 end
    if slots.job then scores.player_job = math.max(scores.player_job or 0, 3.2) end
    if slots.like then scores.player_like = math.max(scores.player_like or 0, 2.8) end
    if slots.origin then scores.player_origin = math.max(scores.player_origin or 0, 3.0) end
    if (slots.time or slots.day) and scores.propose_meet then scores.propose_meet = scores.propose_meet + 1 end

    local ranked = {}
    for id, s in pairs(scores) do ranked[#ranked + 1] = { id = id, score = s } end
    table.sort(ranked, function(a, b)
        if a.score == b.score then return a.id < b.id end
        return a.score > b.score
    end)
    local best = ranked[1]
    local question = (text or ''):find('?', 1, true) ~= nil
    if not question then
        for _, t in ipairs(tokens) do if QUESTION_WORDS[t] then question = true break end end
    end
    return {
        folded = folded, norm = norm, tokens = tokens, slots = slots, scores = scores, ranked = ranked,
        best = best and best.score >= (Config.Dialogue.MinScore or 1.0) and best.id or nil,
        score = best and best.score or 0,
        question = question, short = #tokens <= 2, long = #tokens >= 8,
    }
end

-- =====================================================================
-- BAĞLAM DEĞİŞKENLERİ
-- =====================================================================
function Dialogue.StageGroup(stage)
    if stage == 'enemy' or stage == 'cold' then return 'cold' end
    if stage == 'acquaintance' then return 'known' end
    if stage == 'friend' or stage == 'close_friend' then return 'friend' end
    return 'stranger'
end

local TONE_WORDS = {
    { 'formal', { 'kibar', 'titiz', 'resmi', 'ciddi', 'nazik' } },
    { 'grumpy', { 'huysuz', 'alayci', 'supheci', 'sert', 'asabi', 'ters' } },
    { 'shy', { 'sessiz', 'ice donuk', 'cekingen', 'utangac', 'yalniz' } },
    { 'warm', { 'esprili', 'enerjik', 'disa donuk', 'konuskan', 'sicakkanli', 'iyimser', 'neseli' } },
}

function Dialogue.Tone(r)
    if r._tone then return r._tone end
    local traits = Utils.Fold(table.concat(r.personality.traits or {}, ' '))
    r._tone = 'neutral'
    for _, entry in ipairs(TONE_WORDS) do
        for _, w in ipairs(entry[2]) do
            if traits:find(w, 1, true) then
                r._tone = entry[1]
                return r._tone
            end
        end
    end
    return r._tone
end

-- Sadece kişilik özelliklerinden (traits) gelen ton; puanlar ve ilişki aşaması SC.Persona.Tone'da eklenir
Dialogue.BaseTone = Dialogue.Tone

function Dialogue.Talkative(r)
    local traits = Utils.Fold(table.concat(r.personality.traits or {}, ' '))
    return traits:find('konuskan', 1, true) or traits:find('disa donuk', 1, true) or traits:find('enerjik', 1, true)
end

-- Konuşma tarzındaki tırnaklı kelimeler: hitaplar (sona) ve ağız alışkanlıkları (başa)
function Dialogue.Quirks(r)
    if r._quirks then return r._quirks end
    local q = { vocative = {}, prefix = {} }
    for w in tostring(r.personality.speech_style or ''):gmatch("'([^']+)'") do
        local low = Dialogue.Lowerfirst(w)
        if D.Vocatives[low] then
            q.vocative[#q.vocative + 1] = low
        elseif not D.PrefixOK or D.PrefixOK[Utils.Fold(low)] then
            q.prefix[#q.prefix + 1] = Dialogue.Capitalize(low)
        end
    end
    r._quirks = q
    return q
end

function Dialogue.ReasonMe(r)
    local now = Clock.Now()
    local strongest
    for _, ev in ipairs(r.moodEvents or {}) do
        local eff = ev.value * (0.5 ^ ((now - (ev.at or now)) / 120))
        if math.abs(eff) >= 10 and (not strongest or math.abs(eff) > math.abs(strongest.eff)) then
            strongest = { eff = eff, ev = ev }
        end
    end
    if strongest then
        local ev = strongest.ev
        if ev.code and D.ReasonMe[ev.code] then return D.ReasonMe[ev.code] end
        if ev.reason and ev.reason ~= '' then return ev.reason end
    end
    local n = r.needs
    if n.energy < 25 then return D.ReasonMe.tired end
    if n.hunger > 70 then return D.ReasonMe.hungry end
    if n.social < 25 then return D.ReasonMe.lonely end
    if n.fun < 25 then return D.ReasonMe.bored end
    if (r.mood or 0) > 30 then return D.ReasonMe.good end
    return D.ReasonMe.ok
end

local function helloWord()
    local mod = Clock.MinuteOfDay()
    if mod >= 5 * 60 and mod < 11 * 60 then return L('hello_morning') end
    if mod >= 18 * 60 or mod < 5 * 60 then return L('hello_evening') end
    return L('hello_day')
end

local function firstName(full)
    if not full then return nil end
    return full:match('^(%S+)') or full
end

function Dialogue.PlayerAddress(rel)
    if not rel then return '' end
    if rel.nickname and rel.nickname ~= '' then return rel.nickname end
    if rel.name_known and rel.char_name then return firstName(rel.char_name) or '' end
    return ''
end

-- Listeden cümle seç: bu konuşmada kullanılmamış olanları tercih et
local function pick(list, avoid, used)
    if not list or #list == 0 then return nil end
    if #list == 1 then return list[1] end
    local fresh = {}
    for _, l in ipairs(list) do
        if l ~= avoid and not (used and used[l]) then fresh[#fresh + 1] = l end
    end
    if #fresh > 0 then return fresh[math.random(#fresh)] end
    for _ = 1, 4 do
        local l = list[math.random(#list)]
        if l ~= avoid then return l end
    end
    return list[1]
end

-- Sakinin kimliğinden türetilen sabit kişisel cevap (her sorulduğunda aynı: kedisi hep Pamuk)
local function personalPick(r, key)
    local list = D.Personal and D.Personal[key]
    if type(list) ~= 'table' or #list == 0 then return nil end
    return list[(Utils.Hash(r.id .. ':' .. key) % #list) + 1]
end

local NUMBER_WORDS = { bir = 1, iki = 2, uc = 3, dort = 4, bes = 5, alti = 6, yedi = 7, sekiz = 8, dokuz = 9, on = 10,
    yirmi = 20, otuz = 30, kirk = 40, elli = 50 }

-- "Üç yıldır", "15 yıldır", "On beş yıl" -> sayı (önce hazır cevaplardan, sonra geçmiş hikâyesinden)
function Dialogue.YearsInJob(r)
    if r._years then return r._years end
    local sources = { (r.topics or {}).job, r.backstory }
    for _, src in ipairs(sources) do
        local f = Utils.Fold(src or '')
        local n = f:match('(%d+)%s*yil')
        if n then r._years = tonumber(n) return r._years end
        local w1, w2 = f:match('(%a+)%s+(%a+)%s+yil')
        local total = 0
        if w1 and NUMBER_WORDS[w1] and NUMBER_WORDS[w2] then
            total = NUMBER_WORDS[w1] + NUMBER_WORDS[w2]
        else
            local w = f:match('(%a+)%s+yil')
            if w and NUMBER_WORDS[w] then total = NUMBER_WORDS[w] end
        end
        if total > 0 then r._years = total return total end
    end
    r._years = math.max(1, math.min((r.age or 30) - 17, (Utils.Hash(r.id .. ':years') % 14) + 1))
    return r._years
end

function Dialogue.Vars(r, rel)
    local st = r.state or {}
    local home = Sim.Locations[r.homeId]
    local areaLabel = home and home.area and D.AreaLabels[home.area] or (home and home.label) or ''
    local facts = rel and rel.facts or {}
    local doingList = D.Doing[st.activity] or D.Doing.idle
    local topics = r.topics or {}
    local hereId = st.activity ~= 'commute' and st.locationId or nil
    local years = Dialogue.YearsInJob(r)
    local vars = {
        p = Dialogue.PlayerAddress(rel),
        hello = helloWord(),
        me = r.firstname,
        job = r.job.title or '',
        work = r.job.workplaceId and Sim.LocationLabel(r.job.workplaceId) or '',
        hobbies = joinList(r.personality.hobbies),
        hobby1 = (r.personality.hobbies or {})[1],
        hobbies_rest = joinList({ table.unpack(r.personality.hobbies or {}, 2) }),
        age = tostring(r.age or ''),
        area = areaLabel,
        home = home and home.label or '',
        here = hereId and Sim.Locations[hereId] and Sim.LocationLabel(hereId) or nil,
        time = Utils.FormatTime(Clock.MinuteOfDay()),
        weather = Clock.WeatherLabel(),
        phone = r.phone_number or '',
        reason = Dialogue.ReasonMe(r),
        dest = st.toLocationId and Sim.LocationLabel(st.toLocationId) or nil,
        fact_job = facts.job,
        fact_like = facts.likes and facts.likes[#facts.likes] or nil,
        fact_origin = facts.origin,
        fact_fav = facts.fav_place and Sim.Locations[facts.fav_place] and Sim.LocationLabel(facts.fav_place) or nil,
        t_work = topics.work_opinion, t_family = topics.family, t_dream = topics.dream,
        t_origin = topics.origin, t_food = topics.food, t_music = topics.music,
        years = tostring(years),
        car = r.vehicle and r.vehicle.model and Dialogue.Capitalize(r.vehicle.model) or nil,
    }
    -- v3 yer tutucuları
    local shift = r.job and r.job.shift
    vars.shift_start = shift and shift.start or nil
    vars.shift_end = shift and shift['end'] or nil
    if SC.Persona then
        local likes, dislikes = SC.Persona.Likes(r), SC.Persona.Dislikes(r)
        vars.likes1 = likes[1]
        vars.dislike1 = dislikes[1]
        vars.dislike2 = dislikes[2]
        vars.mood = L('moodlbl_' .. SC.Persona.MoodLabel(r, rel, rel and rel.citizenid))
    end
    if SC.RelXP and rel and rel.stage then
        vars.xp_level = Dialogue.Lowerfirst(SC.RelXP.Label(SC.RelXP.DisplayStage(rel)))
    end
    local here = SC.Aware and SC.Aware.Place(SC.NPC.Coords(r), 150.0)
    vars.place = here and here.label or vars.here
    vars.doing_short = L('actn.' .. tostring(st.activity))
    -- "şu an ne yapıyorsun" cümlesi: boş kalacak yer tutucusu olmayanlardan, önceden doldurulmuş
    local function okLines(list)
        local ok = {}
        for _, l in ipairs(list or {}) do
            local fine = true
            for k in l:gmatch('%%([%w_]+)%%') do if k ~= 'p' and (vars[k] == nil or vars[k] == '') then fine = false end end
            if fine then ok[#ok + 1] = l end
        end
        return ok
    end
    local okDoing = okLines(doingList)
    if #okDoing == 0 then okDoing = okLines(D.Doing.idle) end
    vars.doing = Dialogue.Fill(pick(okDoing) or '...', vars)
    return vars
end

-- Şablonu doldur: %p% boşsa önündeki virgül/boşlukla birlikte silinir
function Dialogue.Fill(line, vars)
    if not line then return '' end
    if not vars.p or vars.p == '' then
        line = line:gsub(',?%s*%%p%%', '')
    end
    line = line:gsub('%%([%w_]+)%%', function(k)
        local v = vars[k]
        if v == nil then return '' end
        return tostring(v)
    end)
    line = line:gsub('%s+([,%.!%?])', '%1'):gsub('^[,%s]+', ''):gsub('%s%s+', ' ')
    return Utils.Trim(line)
end

-- Yer tutucularının hepsi dolu olan cümleler (%p% hariç: o boşsa silinir)
local function usable(line, vars)
    for k in line:gmatch('%%([%w_]+)%%') do
        if k ~= 'p' then
            local v = vars[k]
            if v == nil or v == '' then return false end
        end
    end
    return true
end

local function filterUsable(list, vars)
    if not list then return nil end
    local out = {}
    for _, l in ipairs(list) do
        if usable(l, vars) then out[#out + 1] = l end
    end
    return out
end

-- Kova seçimi: <ton>_<aşama> -> <aşama> -> <ton> -> default
function Dialogue.Bucket(key, r, stage, sub)
    local t = D.Lines[key]
    if not t then return nil end
    if sub then return t[sub] end
    local tone = SC.Persona and SC.Persona.Tone(r, stage) or Dialogue.Tone(r)
    local g = Dialogue.StageGroup(stage)
    for _, k in ipairs({ tone .. '_' .. g, g, tone, 'default' }) do
        if t[k] and #t[k] > 0 then return t[k] end
    end
    for _, v in pairs(t) do return v end
    return nil
end

-- =====================================================================
-- ANILARDAN YARARLANMA (DB; thread içinden)
-- =====================================================================
function Dialogue.FindCoded(npcId, cid, valence)
    if not cid or cid == '' then return nil end
    local rows = MySQL.query.await([[SELECT id, type, data, source_npc, created_at FROM samy_citizens_memories
        WHERE npc_id = ? AND citizenid = ? AND valence = ? AND archived = 0 AND data IS NOT NULL
        ORDER BY importance DESC, id DESC LIMIT 8]], { npcId, cid, valence }) or {}
    for _, row in ipairs(rows) do
        local data = Utils.JsonDecode(row.data)
        if data and data.code then
            row.code = data.code
            row.from = data.from
            return row
        end
    end
    return nil
end

function Dialogue.GrudgeLine(r, grudge)
    if not grudge then return nil end
    if grudge.type == 'gossip' then
        local lines = D.GossipAccuse[grudge.code]
        if not lines then return nil end
        local teller = Sim.Residents[grudge.from or grudge.source_npc or '']
        return (pick(lines):gsub('%%other%%', teller and teller.firstname or L('ctx_someone')))
    end
    local lines = D.Accuse[grudge.code]
    return lines and pick(lines) or nil
end

-- =====================================================================
-- CEVAP ÜRETİMİ — sabitler
-- =====================================================================
local INFO_INTENTS = { ask_name = true, ask_job = true, ask_hobby = true, ask_age = true, ask_home = true, ask_origin = true,
    ask_family = true, ask_dream = true, ask_food = true, ask_music = true, ask_pet = true, ask_sport = true, ask_movie = true,
    ask_car = true, ask_favorite_place = true, ask_city = true }

-- tek cümlede ikinci soru olarak cevaplanabilenler
local COMPOSABLE = { how_are_you = true, ask_name = true, ask_job = true, ask_doing = true, ask_hobby = true, ask_age = true,
    ask_home = true, ask_origin = true, ask_family = true, ask_dream = true, ask_food = true, ask_music = true, ask_today = true,
    ask_feeling = true, ask_plans = true, ask_pet = true, ask_sport = true, ask_movie = true, ask_car = true,
    ask_favorite_place = true, ask_city = true, ask_weather = true, ask_time = true }

-- bunlardan sonra ikinci bir soru eklenebilir
local LEAD_OK = { greet = true, player_mood_good = true, player_mood_bad = true, player_job = true, player_like = true,
    introduce = true, thanks = true, compliment = true, laugh = true, impressed = true, agree = true, ack = true, sympathy = true,
    me_too = true, expectation = true, player_hungry = true, player_tired = true, player_origin = true }

-- niyet -> "son konu" (tepkiler bu konuya göre cevaplanır)
local TOPIC_OF = {
    ask_job = 'job', player_job = 'pjob', ask_family = 'family', ask_hobby = 'hobby', player_like = 'plike', ask_dream = 'dream',
    ask_origin = 'origin', player_origin = 'porigin', ask_food = 'food', ask_music = 'music', ask_weather = 'weather',
    ask_news = 'news', ask_secret = 'secret', ask_today = 'today', ask_yesterday = 'today', ask_joke = 'joke', ask_city = 'city',
    ask_plans = 'plans', ask_pet = 'pet', ask_sport = 'sport', ask_movie = 'movie', ask_car = 'car', ask_feeling = 'feeling',
    how_are_you = 'mood', player_mood_bad = 'pmood_bad', player_mood_good = 'pmood_good', ask_doing = 'doing',
    ask_home = 'home', ask_age = 'age', ask_favorite_place = 'fav',
}

-- sakinin sorduğu soru türü -> oyuncu "sen?" derse sakinin cevaplayacağı niyet
local BACK_OF = { player_mood = 'how_are_you', name = 'ask_name', job = 'ask_job', likes = 'ask_hobby', origin = 'ask_origin',
    plans = 'ask_plans', player_day = 'ask_today', fav_place = 'ask_favorite_place' }

local FOLLOWUP_KINDS = { 'why', 'really', 'agree', 'ack', 'impressed', 'sympathy', 'me_too', 'tell_more', 'dont_know', 'how_long' }
local FOLLOWUPS = {}
for _, k in ipairs(FOLLOWUP_KINDS) do FOLLOWUPS[k] = true end

-- rehine konuşması: niyet -> cevap kovası (diğer her şey yalvarma)
local HOSTAGE_KEYS = { threat = 'hostage_threat', calm = 'hostage_calm', ask_money = 'hostage_money', keep_secret = 'hostage_silence',
    ask_name = 'hostage_name', ask_phone = 'hostage_phone', release_promise = 'hostage_hope', insult = 'hostage_insult',
    how_are_you = 'hostage_how', ask_feeling = 'hostage_how', ask_family = 'hostage_family', goodbye = 'hostage_hope',
    apology = 'hostage_calm', ask_job = 'hostage_job' }

-- aynı ifadeden çıkan iç içe niyetler (ör. "bu akşam ne yapıyorsun" = plan, "ne yapıyorsun" değil)
local OVERLAP = {
    ask_plans = { ask_doing = true, ask_today = true }, ask_today = { ask_doing = true, ask_yesterday = true },
    ask_yesterday = { ask_today = true, ask_doing = true }, ask_feeling = { how_are_you = true },
    how_are_you = { ask_feeling = true }, ask_job = { ask_doing = true }, ask_favorite_place = { ask_advice = true, ask_hobby = true },
    ask_advice = { ask_favorite_place = true }, ask_doing = { ask_plans = true, ask_today = true },
}

-- dolgu sözcüğü ("Hmm.", "Valla.") eklenebilecek cevaplar
local FILLER_OK = { ask_job = true, ask_hobby = true, ask_age = true, ask_home = true, ask_origin = true, ask_family = true,
    ask_dream = true, ask_food = true, ask_music = true, ask_today = true, ask_yesterday = true, ask_plans = true, ask_city = true,
    ask_pet = true, ask_sport = true, ask_movie = true, ask_car = true, ask_favorite_place = true, ask_advice = true, ask_news = true,
    ask_opinion_me = true, ask_doing = true, why = true, tell_more = true, how_long = true, really = true, dont_know = true }

-- bu niyetlerden sonra sakin kendiliğinden soru sormaz
local NO_ASK = { goodbye = true, insult = true, threat = true, busy_end = true, fallback = true, meet_continue = true,
    propose_meet = true, cancel_meet = true, offer_drink = true, hostage = true, ask_directions = true, flirt = true, meta = true,
    sensitive = true, ask_money = true, player_story = true, ask_secret = true, keep_secret = true, share = true }

local EMO = {
    greet = { 'happy', 'wave' }, compliment = { 'embarrassed', 'none' }, insult = { 'angry', 'none' }, threat = { 'scared', 'none' },
    laugh = { 'happy', 'laugh' }, thanks = { 'happy', 'none' }, goodbye = { 'neutral', 'wave' }, fallback = { 'neutral', 'shrug' },
    flirt = { 'embarrassed', 'facepalm' }, apology = { 'neutral', 'none' }, ask_directions = { 'neutral', 'point' },
    player_mood_bad = { 'sad', 'none' }, player_mood_good = { 'happy', 'none' },
    ask_joke = { 'happy', 'laugh' }, sympathy = { 'sad', 'none' }, impressed = { 'happy', 'nod' }, agree = { 'happy', 'nod' },
    really = { 'neutral', 'nod' }, meta = { 'surprised', 'shrug' }, sensitive = { 'neutral', 'shrug' }, miss_you = { 'happy', 'none' },
    dont_know = { 'neutral', 'shrug' }, player_bored = { 'neutral', 'shrug' }, ask_advice = { 'neutral', 'point' },
    ask_money = { 'neutral', 'shrug' }, offer_help = { 'happy', 'none' }, keep_secret = { 'neutral', 'nod' }, ack = { 'neutral', 'nod' },
    me_too = { 'happy', 'none' }, player_story = { 'surprised', 'none' }, ask_smoke = { 'neutral', 'none' },
}

local function purposeFromText(norm)
    if norm:find('kahve', 1, true) or norm:find('kafe', 1, true) then return 'kahve', { 'cafe' } end
    if norm:find('yemek', 1, true) or norm:find('yemeg', 1, true) or norm:find('yenir', 1, true) or norm:find('yesem', 1, true) then
        return 'yemek', { 'restaurant', 'fastfood', 'cafe' }
    end
    if norm:find('icki', 1, true) or norm:find('bira', 1, true) or norm:find('icel', 1, true) or norm:find('bar', 1, true) then
        return 'bir şeyler içmek', { 'bar' }
    end
    if norm:find('spor', 1, true) then return 'spor', { 'gym' } end
    if norm:find('yuru', 1, true) or norm:find('gezel', 1, true) or norm:find('deniz', 1, true) then return 'yürüyüş', { 'park', 'beach' } end
    return 'takılmak', { 'cafe', 'park', 'beach', 'bar' }
end

-- Önerilecek yer: önce sakinin favorilerinden, yoksa herkese açık mekanlardan
local function recommendPlace(r, types)
    local set = {}
    for _, t in ipairs(types or {}) do set[t] = true end
    local favs = {}
    for _, id in ipairs(r.favorite_places or {}) do
        local loc = Sim.Locations[id]
        if loc and loc.public and set[loc.type] then favs[#favs + 1] = loc end
    end
    if #favs > 0 then return favs[math.random(#favs)] end
    local all = Sim.FindLocationsByType(types, true)
    if #all > 0 then return all[math.random(#all)] end
    return nil
end

-- Belirli bir mutlak dakikada ne yapıyor olacağı (birinci şahıs)
local function planPhrase(r, absMin)
    local ok, res = pcall(Sim.PredictAt, r, absMin)
    if not ok or type(res) ~= 'table' then return nil end
    local ph = D.PlanPhrase[res.activity]
    if not ph then return nil end
    local loc = res.loc and res.loc ~= r.homeId and Sim.Locations[res.loc]
    if loc and ph.loc then return (ph.loc:gsub('%%loc%%', loc.label)) end
    return ph.plain
end

local function suggestStart(r, dayOff)
    local now = Clock.Now()
    local today = Clock.Day(now)
    local t = now + 60
    if dayOff and dayOff > 0 then t = math.max(t, (today + dayOff) * 1440 + 10 * 60) end
    t = math.ceil(t / 30) * 30
    for _ = 1, 48 do
        local res, seg = Sim.PredictAt(r, t)
        local mod = t % 1440
        if res and mod >= 10 * 60 and mod <= 22 * 60 then
            local def = SC.Activities[res.activity]
            local firm = (seg and seg.firm) or (def and def.firm)
            if res.activity ~= 'sleep' and not firm then
                local clash = false
                for _, a in ipairs(SC.Appt.byNpc[r.id] or {}) do
                    if math.abs(a.start_min - t) < (Config.Actions.AppointmentMinGap or 90) then clash = true end
                end
                if not clash then return t end
            end
        end
        t = t + 30
    end
    return math.ceil((now + 180) / 30) * 30
end

-- Buluşma akışı (konuşma ve SMS). ctx.c.meet slotları birden çok mesaja yayılabilir
local function meetFlow(ctx, a, out, vars, initiating)
    local r, rel, c = ctx.r, ctx.rel, ctx.c
    local g = Dialogue.StageGroup(rel.stage)
    if initiating then
        if not SC.StageAtLeast(rel.stage, Config.Actions.MinStage.create_appointment) then
            c.meet = nil
            local key = g == 'cold' and 'meet_refuse_cold' or (rel.stage == 'stranger' and 'meet_refuse_stranger' or 'meet_refuse_known')
            return out.say(key)
        end
        local existing = ctx.cid and SC.Appt.GetWith(r.id, ctx.cid)
        if existing and not c.meet then
            vars.when = SC.Appt.WhenText(existing.start_min)
            vars.loc = Sim.LocationLabel(existing.location_id)
            return out.say('meet_already')
        end
        c.meet = c.meet or {}
        c.meet.purpose, c.meet.types = purposeFromText(a.norm)
    end
    local m = c.meet
    if not m then return nil end
    m.turns = 0
    if a.slots.place then m.locId = a.slots.place.id end
    if a.slots.time then m.minutes = a.slots.time end
    if a.slots.day then m.day = a.slots.day end
    if not m.locId then
        local home = Sim.Locations[r.homeId]
        local loc = Sim.PickPlace(r, m.types or { 'cafe', 'park', 'bar' }, home and home.door, 99999.0, m.minutes or 720, Utils.Rng(Utils.Hash(r.id .. os.time())))
        if not loc then
            c.meet = nil
            return out.say('meet_unknown_place')
        end
        vars.loc = loc.label
        c.expect = { kind = 'meet_place', loc = loc.id }
        return out.say('meet_ask_place')
    end
    if not m.minutes then
        local start = suggestStart(r, m.day)
        vars.when = SC.Appt.WhenText(start)
        vars.loc = Sim.LocationLabel(m.locId)
        c.expect = { kind = 'meet_time', start = start }
        return out.say('meet_ask_time')
    end
    local action = { place = m.locId, time = Utils.FormatTime(m.minutes), day = m.day, purpose = m.purpose }
    local ok, info, sug = SC.Appt.Validate(r, ctx.cid, action, rel)
    if ok then
        action.type = 'create_appointment'
        out.actions[#out.actions + 1] = action
        vars.when = SC.Appt.WhenText(info.start)
        vars.loc = info.loc.label
        c.meet = nil
        out.topics.propose_meet = true
        return out.say('meet_accept')
    end
    local reason = info
    if reason == 'place' then
        m.locId = nil
        return out.say('meet_unknown_place')
    end
    m.minutes, m.day = nil, nil
    if sug and (reason == 'work' or reason == 'sleep' or reason == 'busy') then
        vars.when = SC.Appt.WhenText(sug)
        c.expect = { kind = 'meet_time', start = sug }
        return out.say(reason == 'work' and 'meet_conflict_work' or (reason == 'sleep' and 'meet_conflict_sleep' or 'meet_conflict_busy'))
    end
    return out.say('meet_bad_time')
end

-- =====================================================================
-- NİYET İŞLEYİCİLERİ
-- =====================================================================
local handlers = {}

-- sakin oyuncuya karşı soru sorar (ctx.noAskBack ile ikinci cevapta bastırılır)
local function askBack(ctx, out, key, kind, chance)
    if ctx.noAskBack or ctx.c.expect then return end
    if math.random() >= (chance or 0.5) then return end
    ctx.c.askedKinds = ctx.c.askedKinds or {}
    if ctx.c.askedKinds[kind] and kind ~= 'share' then return end
    if out.sayTail(key) then
        ctx.c.expect = { kind = kind }
        ctx.c.askedKinds[kind] = true
    end
end

-- ---------------------------------------------------------------------
-- Eklenti API'si (server/npc_intents.lua yeni niyetleri buradan kaydeder)
-- ---------------------------------------------------------------------
Dialogue.Handlers = handlers
Dialogue.ExpectHooks = {}

function Dialogue.Register(id, fn, o)
    handlers[id] = fn
    o = o or {}
    if o.composable then COMPOSABLE[id] = true end
    if o.lead then LEAD_OK[id] = true end
    if o.topic then TOPIC_OF[id] = o.topic end
    if o.info then INFO_INTENTS[id] = true end
    if o.noAsk then NO_ASK[id] = true end
    if o.filler then FILLER_OK[id] = true end
    if o.emo then EMO[id] = o.emo end
    if o.overlap then OVERLAP[id] = o.overlap end
end

Dialogue.H = {
    askBack = askBack, pick = pick, filterUsable = filterUsable, recommendPlace = recommendPlace,
    purposeFromText = purposeFromText, planPhrase = planPhrase, meetFlow = meetFlow, hasToken = hasToken,
    suggestStart = suggestStart,
}

handlers.greet = function(ctx, a, out, vars)
    if ctx.c.greeted then
        if (ctx.c.playerMsgs or 0) <= 1 and not ctx.c.greetedBack then
            ctx.c.greetedBack = true
            return out.say('greet_back')
        end
        return out.say('greet_again')
    end
    ctx.c.greeted = true
    return out.say('greet')
end

handlers.how_are_you = function(ctx, a, out, vars)
    local g = Dialogue.StageGroup(ctx.rel.stage)
    local moodKey = Sim.MoodKey(ctx.r)
    out.emotion = (moodKey == 'great' or moodKey == 'good') and 'happy' or ((moodKey == 'bad' or moodKey == 'awful') and 'sad' or 'neutral')
    if g == 'cold' then return out.say('how_are_you', 'cold') end
    out.say('how_are_you', moodKey)
    askBack(ctx, out, 'askback_mood', 'player_mood', Config.Dialogue.AskBackChance or 0.6)
end

local function rememberMood(out, v)
    out.rel.facts = out.rel.facts or {}
    out.rel.facts.last_mood = { v = v, at = os.time() }
end

handlers.player_mood_good = function(ctx, a, out)
    rememberMood(out, 'good')
    out.topic = 'pmood_good'
    ctx.c.backIntent = 'how_are_you'
    return out.say('player_mood_good')
end

handlers.player_mood_bad = function(ctx, a, out)
    rememberMood(out, 'bad')
    out.topic = 'pmood_bad'
    ctx.c.backIntent = 'how_are_you'
    out.say('player_mood_bad')
    if not ctx.c.expect and math.random() < 0.5 then
        out.sayTail('askwhy_bad')
        ctx.c.expect = { kind = 'share', bad = true }
    end
end

handlers.player_hungry = function(ctx, a, out, vars)
    local loc = recommendPlace(ctx.r, { 'fastfood', 'restaurant', 'cafe' })
    if loc then
        vars.loc = loc.label
        return out.say('player_hungry', 'place')
    end
    return out.say('player_hungry', 'default')
end

handlers.player_tired = function(ctx, a, out)
    rememberMood(out, 'bad')
    return out.say('player_tired')
end

handlers.player_bored = function(ctx, a, out, vars)
    local loc = recommendPlace(ctx.r, { 'park', 'beach', 'bar', 'cafe' })
    if loc then
        vars.loc = loc.label
        return out.say('player_bored', 'place')
    end
    return out.say('player_bored', 'default')
end

handlers.ask_name = function(ctx, a, out, vars)
    local rel = ctx.rel
    local g = Dialogue.StageGroup(rel.stage)
    out.say('ask_name')
    if g ~= 'cold' then
        out.rel.npc_name_shown = true
        if not rel.name_known and not rel.nickname then askBack(ctx, out, 'askback_name', 'name', 1.0) end
    end
end

handlers.introduce = function(ctx, a, out, vars, name)
    local rel = ctx.rel
    name = name or a.slots.name
    if not name then return handlers.fallback(ctx, a, out, vars) end
    local real = ctx.playerFirst
    out.topics.introduce = true
    ctx.c.backIntent = 'ask_name'
    if real and Utils.Fold(name) == Utils.Fold(real) then
        vars.p = name
        if rel.name_known then return out.say('introduce_known') end
        out.rel.name_known = true
        out.dTrust = out.dTrust + 1
        out.memories[#out.memories + 1] = { text = L('mem_met', name), importance = 4, type = 'conversation', data = { fact = 'name' } }
        return out.say('introduce_ok')
    end
    out.rel.nickname = name
    vars.p = name
    out.memories[#out.memories + 1] = { text = L('mem_met', name), importance = 3, type = 'conversation', data = { fact = 'nickname' } }
    return out.say('introduce_nick')
end

handlers.ask_job = function(ctx, a, out, vars)
    local r = ctx.r
    local topics = r.topics or {}
    if Dialogue.StageGroup(ctx.rel.stage) == 'cold' then return out.say('ask_job', 'cold') end
    if topics.job and topics.job ~= '' then
        out.push(topics.job)
    elseif r.job.workplaceId then
        out.push('%job% olarak çalışıyorum. İş yerim %work%.')
    else
        out.push(r.job.title and (r.job.title .. '.') or '...')
    end
    if topics.work_opinion and topics.work_opinion ~= '' and math.random() < 0.45 then out.push(topics.work_opinion) end
    local facts = ctx.rel.facts or {}
    if not facts.job then askBack(ctx, out, 'askback_job', 'job', 0.5) end
end

handlers.player_job = function(ctx, a, out, vars, job)
    job = job or a.slots.job
    if not job then return handlers.fallback(ctx, a, out, vars) end
    out.rel.facts = out.rel.facts or {}
    out.rel.facts.job = job
    vars.fact_job = job
    out.topics.player_job = true
    out.topic = 'pjob'
    ctx.c.backIntent = 'ask_job'
    out.dTrust = out.dTrust + 1
    out.memories[#out.memories + 1] = { text = L('mem_player_job', ctx.addr ~= '' and ctx.addr or L('ctx_this_person'), job), importance = 4, type = 'conversation', data = { fact = 'job', value = job } }
    return out.say('player_job')
end

handlers.ask_doing = function(ctx, a, out) return out.say('ask_doing') end

local function logSequence(log, maxN)
    if not log or not log.entries then return nil end
    local items, last = {}, nil
    for _, e in ipairs(log.entries) do
        if (e.k == 'arrive' or e.k == 'activity') and e.loc and e.act then
            local item = ('%s (%s)'):format(Sim.LocationLabel(e.loc), L('actn.' .. tostring(e.act)))
            if item ~= last then
                items[#items + 1] = item
                last = item
            end
        end
    end
    if #items == 0 then return nil end
    local start = math.max(1, #items - (maxN or 4) + 1)
    local seq = {}
    for i = start, #items do seq[#seq + 1] = items[i] end
    return table.concat(seq, ', sonra ')
end

handlers.ask_today = function(ctx, a, out, vars)
    if Dialogue.StageGroup(ctx.rel.stage) == 'cold' then return out.say('ask_today', 'cold') end
    local r = ctx.r
    local seq = logSequence(r.dayLog and r.dayLog.day == Clock.Day() and r.dayLog or nil, 4)
    if not seq then
        out.say('ask_today', 'empty')
    else
        vars.text = seq
        out.say('ask_today', 'default')
    end
    askBack(ctx, out, 'askback_day', 'player_day', 0.3)
end

handlers.ask_yesterday = function(ctx, a, out, vars)
    if Dialogue.StageGroup(ctx.rel.stage) == 'cold' then return out.say('ask_yesterday', 'cold') end
    local r = ctx.r
    local log = r.prevDayLog and r.prevDayLog.day == Clock.Day() - 1 and r.prevDayLog or nil
    local seq = logSequence(log, 4)
    if not seq then return out.say('ask_yesterday', 'empty') end
    vars.text = seq
    return out.say('ask_yesterday', 'default')
end

handlers.ask_remember = function(ctx, a, out, vars)
    local rel, r = ctx.rel, ctx.r
    if not ctx.dry then
        local grudge = Dialogue.FindCoded(r.id, ctx.cid, -1)
        local line = Dialogue.GrudgeLine(r, grudge)
        if line then
            out.emotion = 'angry'
            return out.push(line)
        end
        local last = MySQL.single.await([[SELECT data, created_at FROM samy_citizens_memories
            WHERE npc_id = ? AND citizenid = ? AND archived = 0 AND data LIKE '%"kind":"convo"%' ORDER BY id DESC LIMIT 1]], { r.id, ctx.cid or '' })
        if last then
            local data = Utils.JsonDecode(last.data) or {}
            vars.ago = Utils.RelativeAge(os.time() - (tonumber(last.created_at) or os.time()))
            vars.loc = Sim.LocationLabel(data.place)
            local phrases = {}
            for _, k in ipairs(data.topics or {}) do if D.Topics[k] then phrases[#phrases + 1] = D.Topics[k] end end
            if #phrases > 0 then
                vars.topics = joinList(phrases)
                out.say('ask_remember', 'convo')
            else
                out.say('ask_remember', 'convo_nosum')
            end
            if vars.fact_job then out.say('ask_remember', 'fact_job') end
            if vars.fact_like and math.random() < 0.5 then out.say('ask_remember', 'fact_like') end
            out.emotion = 'happy'
            return
        end
    end
    if rel.times_met > 1 then return out.say('ask_remember', 'vague') end
    return out.say('ask_remember', 'stranger')
end

handlers.ask_hobby = function(ctx, a, out, vars)
    if Dialogue.StageGroup(ctx.rel.stage) == 'cold' then return out.say('ask_hobby', 'cold') end
    if vars.hobbies == '' then vars.hobbies = 'yürüyüş yapmayı' end
    out.say('ask_hobby', 'default')
    askBack(ctx, out, 'askback_likes', 'likes', 0.4)
end

handlers.player_like = function(ctx, a, out, vars, like)
    like = like or a.slots.like
    if not like then return handlers.fallback(ctx, a, out, vars) end
    out.rel.facts = out.rel.facts or {}
    out.rel.facts.likes = out.rel.facts.likes or Utils.DeepCopy((ctx.rel.facts or {}).likes or {})
    table.insert(out.rel.facts.likes, like)
    vars.fact_like = like
    out.topics.player_like = true
    out.topic = 'plike'
    ctx.c.backIntent = 'ask_hobby'
    out.memories[#out.memories + 1] = { text = L('mem_player_like', ctx.addr ~= '' and ctx.addr or L('ctx_this_person'), like), importance = 3, type = 'conversation', data = { fact = 'like', value = like } }
    -- ortak hobi: sakinin de sevdiği bir şeyse daha çok sevinir
    local f = Utils.Fold(like)
    for _, h in ipairs(ctx.r.personality.hobbies or {}) do
        local hf = Utils.Fold(h):sub(1, 5)
        if #hf >= 4 and f:find(hf, 1, true) then
            out.dAff = out.dAff + 2
            out.emotion = 'happy'
            out.push('Oo, ben de bayılırım! Ortak noktamız varmış.')
            return
        end
    end
    return out.say('player_like')
end

handlers.player_origin = function(ctx, a, out, vars, origin, isLocal)
    if not origin then origin, isLocal = a.slots.origin, a.slots.originLocal end
    if not origin then return handlers.fallback(ctx, a, out, vars) end
    out.rel.facts = out.rel.facts or {}
    out.rel.facts.origin = origin
    vars.fact_origin = origin
    out.topics.player_origin = true
    out.topic = 'porigin'
    ctx.c.backIntent = 'ask_origin'
    out.memories[#out.memories + 1] = { text = L('mem_player_origin', ctx.addr ~= '' and ctx.addr or L('ctx_this_person'), origin), importance = 3, type = 'conversation', data = { fact = 'origin', value = origin } }
    if isLocal then return out.say('player_origin', 'local') end
    local mine = ctx.r.topics and ctx.r.topics.origin
    if mine and Utils.Fold(mine):find(Utils.Fold(origin), 1, true) then
        out.dAff = out.dAff + 2
        out.emotion = 'happy'
        ctx.noBack = true
        return out.say('player_origin', 'same')
    end
    return out.say('player_origin', 'default')
end

handlers.ask_age = function(ctx, a, out) return out.say('ask_age') end

handlers.ask_home = function(ctx, a, out)
    out.say('ask_home')
    if ctx.rel.stage == 'close_friend' and ctx.channel == 'talk' then
        out.actions[#out.actions + 1] = { type = 'give_directions', locationId = ctx.r.homeId }
    end
end

local TOPIC_ASKBACK = {
    ask_origin = { 'askback_origin', 'origin', 0.45 }, ask_food = { 'askback_food', 'likes', 0.35 },
    ask_music = { 'askback_music', 'likes', 0.35 }, ask_dream = { 'askback_dream', 'share', 0.35 },
}

local function topicAnswer(key)
    return function(ctx, a, out, vars)
        local g = Dialogue.StageGroup(ctx.rel.stage)
        if g == 'cold' then return out.say(key, 'cold') end
        local text = ctx.r.topics and ctx.r.topics[(key:gsub('^ask_', ''))]
        if not text or text == '' then
            out.say(key, 'empty')
        else
            vars.text = text
            if key == 'ask_family' and g == 'stranger' then out.say(key, 'stranger') else out.say(key, 'default') end
        end
        local ab = TOPIC_ASKBACK[key]
        if ab and not (ab[2] == 'origin' and (ctx.rel.facts or {}).origin) then
            askBack(ctx, out, ab[1], ab[2], ab[3])
            if ctx.c.expect and ctx.c.expect.kind == 'share' then ctx.c.expect.back = key end
        end
    end
end
handlers.ask_origin = topicAnswer('ask_origin')
handlers.ask_family = topicAnswer('ask_family')
handlers.ask_dream = topicAnswer('ask_dream')
handlers.ask_food = topicAnswer('ask_food')
handlers.ask_music = topicAnswer('ask_music')

handlers.ask_secret = function(ctx, a, out, vars)
    local rel = ctx.rel
    local g = Dialogue.StageGroup(rel.stage)
    if g == 'cold' then return out.say('ask_secret', 'cold') end
    if rel.stage ~= 'close_friend' then return out.say('ask_secret', 'default') end
    local text = ctx.r.topics and ctx.r.topics.secret
    if not text or text == '' then return out.say('ask_secret', 'empty') end
    vars.text = text
    out.dTrust = out.dTrust + 1
    return out.say('ask_secret', 'friend')
end

handlers.ask_opinion_me = function(ctx, a, out, vars)
    local rel = ctx.rel
    if not ctx.dry then
        local line = Dialogue.GrudgeLine(ctx.r, Dialogue.FindCoded(ctx.r.id, ctx.cid, -1))
        if line and Dialogue.StageGroup(rel.stage) ~= 'friend' then
            out.emotion = 'angry'
            out.say('ask_opinion_me', 'cold')
            return out.push(line)
        end
    end
    if rel.stage == 'close_friend' then return out.say('ask_opinion_me', 'close') end
    return out.say('ask_opinion_me')
end

handlers.ask_phone = function(ctx, a, out, vars)
    local rel = ctx.rel
    local g = Dialogue.StageGroup(rel.stage)
    if not SC.Phone.Enabled() then return out.say('ask_phone', 'disabled') end
    if rel.phone_known then return out.say('ask_phone', 'already') end
    if g == 'cold' then return out.say('ask_phone', 'cold') end
    local need = Config.Dialogue.PhoneTrust or 15
    if Dialogue.Tone(ctx.r) == 'grumpy' then need = need + 15 end
    local stageOk = SC.StageAtLeast(rel.stage, Config.Actions.MinStage.give_phone_number)
    if stageOk and (rel.trust >= need or SC.StageAtLeast(rel.stage, 'friend')) then
        out.actions[#out.actions + 1] = { type = 'give_phone_number' }
        out.emotion = 'happy'
        return out.say('ask_phone', 'give')
    end
    return out.say('ask_phone', g == 'stranger' and 'stranger' or 'known')
end

handlers.ask_appointment = function(ctx, a, out, vars)
    local appt = ctx.cid and SC.Appt.GetWith(ctx.r.id, ctx.cid)
    if not appt then return out.say('ask_appointment', 'none') end
    vars.when = SC.Appt.WhenText(appt.start_min)
    vars.loc = Sim.LocationLabel(appt.location_id)
    return out.say('ask_appointment', 'has')
end

handlers.propose_meet = function(ctx, a, out, vars)
    out.topics.propose_meet = true
    return meetFlow(ctx, a, out, vars, true)
end

handlers.offer_drink = function(ctx, a, out, vars)
    if SC.StageAtLeast(ctx.rel.stage, Config.Actions.MinStage.create_appointment) then
        out.topics.propose_meet = true
        return meetFlow(ctx, a, out, vars, true)
    end
    return out.say('offer_drink')
end

handlers.cancel_meet = function(ctx, a, out, vars)
    ctx.c.meet = nil
    if ctx.cid and SC.Appt.HasActiveWith(ctx.r.id, ctx.cid) then
        out.actions[#out.actions + 1] = { type = 'cancel_appointment' }
        return out.say('cancel_meet', 'default')
    end
    return out.say('cancel_meet', 'none')
end

handlers.ask_directions = function(ctx, a, out, vars)
    local loc = a.slots.place
    vars.loc = loc.label
    out.actions[#out.actions + 1] = { type = 'give_directions', locationId = loc.id }
    return out.say('ask_directions', Dialogue.StageGroup(ctx.rel.stage) == 'stranger' and 'stranger' or 'found')
end

handlers.ask_advice = function(ctx, a, out, vars)
    local _, types = purposeFromText(a.norm)
    local loc = recommendPlace(ctx.r, types)
    out.topic = 'fav'
    if not loc then return out.say('ask_advice', 'none') end
    vars.loc = loc.label
    out.actions[#out.actions + 1] = { type = 'give_directions', locationId = loc.id }
    return out.say('ask_advice', 'found')
end

handlers.ask_person = function(ctx, a, out, vars)
    local other = a.slots.person
    vars.other = other.firstname
    local kind = SC.Social.Relation(ctx.r.id, other.id)
    out.topics.ask_person = true
    if not kind then return out.say('ask_person', 'none') end
    out.say('ask_person', kind)
    local asksWhere = hasToken(a.tokens, 'nerede', 'nerde', 'neredeydi', 'nereye')
    if asksWhere and SC.StageAtLeast(ctx.rel.stage, 'acquaintance') and other.state then
        local ost = other.state
        if ost.activity == 'commute' then
            vars.other_where = ('%s tarafına gidiyordur'):format(Sim.LocationLabel(ost.toLocationId))
        else
            vars.other_where = ('%s civarında, %s'):format(Sim.LocationLabel(ost.locationId), L('act.' .. tostring(ost.activity)))
        end
        out.say('ask_person', 'where')
    end
end

handlers.ask_news = function(ctx, a, out, vars)
    local g = Dialogue.StageGroup(ctx.rel.stage)
    if g == 'cold' then return out.say('ask_news', 'cold') end
    if g == 'stranger' then return out.say('ask_news', 'stranger') end
    if ctx.dry then return out.say('ask_news', 'empty') end
    local rows = MySQL.query.await([[SELECT citizenid, text, type, data, source_npc FROM samy_citizens_memories
        WHERE npc_id = ? AND archived = 0 AND type IN ('gossip', 'witnessed') ORDER BY id DESC LIMIT 10]], { ctx.r.id }) or {}
    for _, row in ipairs(rows) do
        if row.citizenid and row.citizenid == ctx.cid then
            local data = Utils.JsonDecode(row.data) or {}
            local line = Dialogue.GrudgeLine(ctx.r, { type = row.type, code = data.code, from = data.from, source_npc = row.source_npc })
            if line then
                out.emotion = 'angry'
                return out.push(line)
            end
        else
            vars.news = row.type == 'witnessed' and Dialogue.Lowerfirst(row.text) or row.text
            out.topics.ask_news = true
            if row.type == 'witnessed' then return out.push('Geçenlerde %news%') end
            return out.push('Duydun mu? %news%')
        end
    end
    return out.say('ask_news', 'empty')
end

handlers.ask_weather = function(ctx, a, out)
    out.topics.ask_weather = true
    return out.say('ask_weather', Clock.IsRaining() and 'rain' or 'default')
end

handlers.ask_time = function(ctx, a, out) return out.say('ask_time') end

handlers.ask_feeling = function(ctx, a, out)
    if Dialogue.StageGroup(ctx.rel.stage) == 'cold' then return out.say('ask_feeling', 'cold') end
    local mk = Sim.MoodKey(ctx.r)
    out.emotion = (mk == 'great' or mk == 'good') and 'happy' or ((mk == 'bad' or mk == 'awful') and 'sad' or 'neutral')
    return out.say('ask_feeling', mk)
end

handlers.ask_joke = function(ctx, a, out)
    if Dialogue.StageGroup(ctx.rel.stage) == 'cold' then return out.say('ask_joke', 'cold') end
    if Dialogue.Tone(ctx.r) == 'grumpy' and math.random() < 0.5 then out.say('ask_joke', 'grumpy') end
    out.sayList(D.Jokes)
    out.emotion = 'happy'
    out.animation = 'laugh'
end

handlers.ask_plans = function(ctx, a, out, vars)
    if Dialogue.StageGroup(ctx.rel.stage) == 'cold' then return out.say('ask_plans', 'cold') end
    local r = ctx.r
    local now = Clock.Now()
    local day = Clock.Day(now)
    local mod = Clock.MinuteOfDay(now)
    local weekend = hasToken(a.tokens, 'hafta')
    local tomorrow = not weekend and (a.slots.day == 1 or hasToken(a.tokens, 'yarin'))
    local t
    if weekend then
        local add = (6 - Clock.Weekday(now)) % 7
        t = (day + add) * 1440 + 15 * 60
        vars.when = 'hafta sonu'
    elseif tomorrow then
        t = (day + 1) * 1440 + 19 * 60
        vars.when = 'yarın akşam'
    else
        t = mod < 19 * 60 and (day * 1440 + 20 * 60) or (now + 90)
        vars.when = mod < 19 * 60 and 'bu akşam' or 'birazdan'
    end
    local phrase = planPhrase(r, t)
    if not phrase then
        out.say('ask_plans', 'nothing')
    else
        vars.plan = phrase
        out.say('ask_plans', 'default')
    end
    askBack(ctx, out, 'askback_plans', 'plans', 0.4)
end

handlers.ask_city = function(ctx, a, out)
    if Dialogue.StageGroup(ctx.rel.stage) == 'cold' then return out.say('ask_city', 'cold') end
    local tone = Dialogue.Tone(ctx.r)
    return out.say('ask_city', D.Lines.ask_city[tone] and tone or 'default')
end

local function personalHandler(key)
    return function(ctx, a, out)
        if Dialogue.StageGroup(ctx.rel.stage) == 'cold' then return out.say('ask_doing', 'cold') end
        out.push(personalPick(ctx.r, key) or '...')
    end
end
handlers.ask_pet = personalHandler('pet')
handlers.ask_sport = personalHandler('sport')
handlers.ask_movie = personalHandler('movie')

handlers.ask_car = function(ctx, a, out)
    local r = ctx.r
    if Dialogue.StageGroup(ctx.rel.stage) == 'cold' then return out.say('ask_car', 'cold') end
    if not r.vehicle then return out.say('ask_car', 'none') end
    if r.car and r.car.missing then return out.say('ask_car', 'stolen') end
    return out.say('ask_car', 'has')
end

handlers.ask_smoke = function(ctx, a, out)
    local smoker = Utils.Hash(ctx.r.id .. ':smoke') % 3 == 0
    return out.say('ask_smoke', smoker and 'yes' or 'no')
end

handlers.ask_money = function(ctx, a, out) return out.say('ask_money') end
handlers.ask_help = function(ctx, a, out) return out.say('ask_help') end

handlers.offer_help = function(ctx, a, out)
    local def = SC.Activities[ctx.r.state.activity]
    return out.say('offer_help', def and def.busy and 'busy' or 'default')
end

handlers.ask_favorite_place = function(ctx, a, out, vars)
    local favs = {}
    for _, id in ipairs(ctx.r.favorite_places or {}) do if Sim.Locations[id] then favs[#favs + 1] = id end end
    if #favs == 0 then return out.say('ask_favorite_place', 'none') end
    vars.loc = Sim.LocationLabel(favs[math.random(#favs)])
    out.say('ask_favorite_place', 'default')
    if not (ctx.rel.facts or {}).fav_place then askBack(ctx, out, 'askback_fav', 'fav_place', 0.45) end
end

handlers.meta = function(ctx, a, out) return out.say('meta') end
handlers.sensitive = function(ctx, a, out) return out.say('sensitive') end
handlers.miss_you = function(ctx, a, out) return out.say('miss_you') end
handlers.keep_secret = function(ctx, a, out) return out.say('keep_secret') end
handlers.calm = function(ctx, a, out) return out.say('calm_normal') end

handlers.player_story = function(ctx, a, out)
    out.say('listen')
    if not ctx.c.expect then ctx.c.expect = { kind = 'share' } end
end

handlers.compliment = function(ctx, a, out)
    out.topics.compliment = true
    return out.say('compliment')
end

handlers.insult = function(ctx, a, out, vars)
    ctx.c.insults = (ctx.c.insults or 0) + 1
    out.say('insult')
    out.memories[#out.memories + 1] = {
        text = L('mem_harassment', ctx.addr ~= '' and ctx.addr or L('ctx_this_person')), importance = 5, type = 'event', valence = -1,
        data = { code = 'harassment' },
    }
    if ctx.c.insults >= 2 and ctx.channel == 'talk' then
        out.actions[#out.actions + 1] = { type = 'end_conversation' }
    end
end

handlers.threat = function(ctx, a, out)
    out.event = 'threatened'
    out.say('threat')
    if ctx.channel == 'talk' then
        out.actions[#out.actions + 1] = { type = 'flee' }
    end
    out.actions[#out.actions + 1] = { type = 'call_police' }
end

handlers.thanks = function(ctx, a, out) return out.say('thanks') end

handlers.apology = function(ctx, a, out)
    if ctx.rel.affinity < 0 or ctx.rel.stage == 'cold' then
        out.dTrust = out.dTrust + 2
        out.dAff = out.dAff + 1
        return out.say('apology', 'forgive')
    end
    return out.say('apology', 'default')
end

handlers.flirt = function(ctx, a, out)
    out.topics.flirt = true
    local g = Dialogue.StageGroup(ctx.rel.stage)
    if g == 'stranger' then out.dAff = out.dAff - 1 elseif g == 'friend' then out.dAff = out.dAff + 1 end
    return out.say('flirt')
end

handlers.ask_follow = function(ctx, a, out)
    if ctx.channel ~= 'talk' then return out.say('ask_follow', 'default') end
    local def = SC.Activities[ctx.r.state.activity]
    if ctx.rel.stage == 'close_friend' then
        if def and def.busy then return out.say('ask_follow', 'busy') end
        out.actions[#out.actions + 1] = { type = 'follow_player', minutes = 3 }
        return out.say('ask_follow', 'yes')
    end
    if ctx.rel.stage == 'stranger' then return out.say('ask_follow', 'stranger') end
    return out.say('ask_follow', 'default')
end

handlers.laugh = function(ctx, a, out) return out.say('laugh') end

handlers.yes = function(ctx, a, out)
    if ctx.c.lastWasQuestion then return out.say('yes_q') end
    return out.say('yes')
end

handlers.no = function(ctx, a, out)
    if ctx.c.lastWasQuestion then return out.say('no_q') end
    return out.say('no')
end

handlers.goodbye = function(ctx, a, out)
    out.say('goodbye')
    if ctx.channel == 'talk' then out.actions[#out.actions + 1] = { type = 'end_conversation' } end
end

-- "sen?" / "ya sen?": sakinin sorduğu (ya da oyuncunun az önce anlattığı) konuyu sakin kendisi için cevaplar
handlers.ask_back = function(ctx, a, out, vars)
    local target = ctx.c.backIntent
    if ctx.noBack then return end
    if target and target ~= 'how_are_you' and (ctx.c.asked[target] or 0) >= 1 then
        out.say('ask_back_already')
        return
    end
    if target and target ~= 'ask_back' and handlers[target] then
        ctx.noAskBack = true
        handlers[target](ctx, a, out, vars)
        out.topic = TOPIC_OF[target] or out.topic
        return
    end
    if ctx.c.lastTopic then return handlers.tell_more(ctx, a, out, vars) end
    return out.say('ask_back_none')
end

-- Sohbet tepkileri: önce son konuya özel cevap, yoksa genel tepki
local function inferTopic(r, a)
    local stem = function(s) return Utils.Fold(s or ''):match('^(%a%a%a%a%a?)') end
    -- meslek adının en uzun kelimesi ("Oto tamircisi" -> "tamir")
    local longest = ''
    for w in Utils.Fold((r.job and r.job.title) or ''):gmatch('%a+') do if #w > #longest then longest = w end end
    local job = stem(longest)
    for _, t in ipairs(a.tokens) do
        if t == 'is' or t == 'isin' or t:sub(1, 5) == 'calis' or t:sub(1, 5) == 'mesle' or (job and #job >= 4 and t:sub(1, #job) == job) then return 'job' end
        if t:sub(1, 5) == 'sehir' or t:sub(1, 5) == 'sehri' or t == 'burasi' or t == 'buralar' then return 'city' end
        if t:sub(1, 3) == 'ail' or t:sub(1, 4) == 'anne' or t:sub(1, 4) == 'baba' then return 'family' end
    end
    for _, h in ipairs(r.personality.hobbies or {}) do
        local hs = stem(h)
        if hs and #hs >= 4 and a.norm:find(hs, 1, true) then return 'hobby' end
    end
    return nil
end

local function followupHandler(kind)
    return function(ctx, a, out)
        local topic = inferTopic(ctx.r, a) or ctx.c.lastTopic
        local ft = topic and D.Followups[topic]
        if ft and ft[kind] and out.sayList(ft[kind]) then
            out.topic = topic
            return
        end
        out.say('fu_' .. kind)
        out.topic = topic
    end
end
for _, k in ipairs(FOLLOWUP_KINDS) do handlers[k] = followupHandler(k) end

handlers.release_promise = function(ctx, a, out, vars) return handlers.fallback(ctx, a, out, vars) end

handlers.fallback = function(ctx, a, out)
    local c = ctx.c
    c.fallbacks = (c.fallbacks or 0) + 1
    -- anlamadığı ama soru olan cümleye "bilmiyorum" der; kısa/uzun cümleye doğal tepki verir
    if a.question and not a.short then
        out.say('fallback_question')
    elseif a.short then
        out.say('fallback_short')
    elseif a.long then
        out.say('fallback_long')
    else
        out.say('fallback')
    end
    if c.fallbacks >= 3 then
        c.fallbacks = 0
        out.say('fallback_hint')
    end
end

local BAD_WORDS = { 'kotu', 'berbat', 'yorgun', 'uzgun', 'sikildi', 'sinir', 'stres', 'hasta', 'moral', 'zor', 'yorucu', 'felaket' }

local function soundsBad(norm)
    for _, w in ipairs(BAD_WORDS) do
        if norm:find(w, 1, true) then return true end
    end
    return false
end

local GOOD_WORDS = { 'iyi', 'super', 'harika', 'duzel', 'fena degil', 'idare', 'guzel', 'mukemmel', 'bomba', 'keyfim yerinde', 'mutlu', 'evet' }

local function soundsGood(norm)
    for _, w in ipairs(GOOD_WORDS) do
        if norm:find(w, 1, true) then return true end
    end
    return false
end

-- sadece "neden?" / "niye sordun?" gibi cümleler (konu kelimesi yok)
local WHY_ONLY = { neden = true, niye = true, nicin = true, ki = true, sordun = true, soruyorsun = true, peki = true, ya = true, bunu = true, merak = true, ettin = true }

-- Niyet bulunamadı: son konuya göre anlam çıkarmayı dene, olmazsa insan gibi tepki ver
function Dialogue.Contextual(ctx, a, out, vars)
    local c = ctx.c
    local topic = c.lastTopic
    -- iş konusu açıkken "polisim", "tamirciyim"
    if (topic == 'job' or topic == 'pjob') and not a.question and #a.tokens <= 3 then
        local job = Dialogue.ExtractJob(ctx.text, true)
        if job then
            handlers.player_job(ctx, a, out, vars, job)
            return 'player_job'
        end
    end
    -- oyuncu derdini anlatıyor
    if (topic == 'pmood_bad' or topic == 'feeling') and not a.question and #a.tokens >= 2 then
        out.say('share_bad')
        out.dAff = out.dAff + 1
        out.topics.player_story = true
        out.topic = 'pmood_bad'
        return 'share'
    end
    -- soru olmayan, anlaşılmayan bir cümle: çoğu zaman dinliyormuş gibi karşılık verir
    if not a.question and #a.tokens >= 3 and math.random() < 0.65 then
        if soundsBad(a.norm) then out.say('share_bad') else out.say('share_ack') end
        out.topic = topic
        return 'share'
    end
    handlers.fallback(ctx, a, out, vars)
    return 'fallback'
end

local function customHandler(intent)
    return function(ctx, a, out)
        local c = intent.custom
        if c.stage and not SC.StageAtLeast(ctx.rel.stage, c.stage) then return handlers.fallback(ctx, a, out) end
        if c.residents and not Utils.Contains(c.residents, ctx.r.id) then return handlers.fallback(ctx, a, out) end
        return out.push(pick(c.lines or {}, nil, ctx.c.used) or '...')
    end
end

-- =====================================================================
-- BEKLENEN CEVAPLAR (sakin bir şey sorduysa)
-- =====================================================================

-- Bekleyen soruya verilen cevabı işle. true dönerse cevap üretilmiştir
local function handleExpectation(ctx, a, out, vars)
    local e = ctx.c.expect
    if not e then return false end
    ctx.c.expect = nil
    local c = ctx.c
    local hook = Dialogue.ExpectHooks[e.kind]
    if hook then
        return hook(ctx, a, out, vars, e) == true
    end
    if BACK_OF[e.kind] then c.backIntent = BACK_OF[e.kind] end
    if e.back then c.backIntent = e.back end
    local strongOther = a.best and a.score >= 2.5 and not FOLLOWUPS[a.best] and a.best ~= 'ask_back'
    -- serbest cevap beklenen sorularda: soru, "hmm", kahkaha ya da "gerçekten mi" cevap sayılmaz
    local notAnswer = (a.question and not a.scores.ask_back) or a.best == 'laugh' or (a.best and FOLLOWUPS[a.best] and a.best ~= 'dont_know')
    -- sadece "neden?" / "niye sordun?" -> merak ettim
    if a.best == 'why' and e.kind ~= 'share' and e.kind ~= 'meet_place' and e.kind ~= 'meet_time' then
        local onlyWhy = true
        for _, t in ipairs(a.tokens) do if not WHY_ONLY[t] then onlyWhy = false end end
        if onlyWhy then
            out.say('why_asked')
            c.expect = e
            return true
        end
        return false
    end
    -- "söylemem", "bilmiyorum"
    if (a.best == 'dont_know' or (a.best == 'no' and e.kind ~= 'meet_place' and e.kind ~= 'meet_time')) and e.kind ~= 'player_mood' then
        out.say('share_declined')
        return true
    end
    -- sorulmadan söylenen memleket ("Paleto'luyum") her beklentide işlenir
    if a.slots.origin and e.kind ~= 'origin' then
        handlers.player_origin(ctx, a, out, vars, a.slots.origin, a.slots.originLocal)
        return true
    end
    if e.kind == 'player_mood' then
        if a.best == 'player_mood_good' or a.best == 'player_mood_bad' then
            handlers[a.best](ctx, a, out)
            if a.best == 'player_mood_bad' then out.dAff = out.dAff + 1 end
            return true
        end
        -- ruh hâli belirtisi yoksa (ör. sadece "selam") cevap sayma
        if not strongOther and (soundsBad(a.norm) or soundsGood(a.norm)) then
            local bad = soundsBad(a.norm)
            handlers[bad and 'player_mood_bad' or 'player_mood_good'](ctx, a, out)
            return true
        end
    elseif e.kind == 'name' then
        if a.slots.name then
            handlers.introduce(ctx, a, out, vars, a.slots.name)
            return true
        end
        if not strongOther and #a.tokens <= 2 then
            local ws = words(ctx.text or '')
            local n = ws[1] and cleanName(ws[1])
            if n then
                handlers.introduce(ctx, a, out, vars, n)
                return true
            end
        end
    elseif e.kind == 'job' then
        local job = a.slots.job or (not strongOther and not notAnswer and Dialogue.ExtractJob(ctx.text, true))
        if job then
            handlers.player_job(ctx, a, out, vars, job)
            return true
        end
    elseif e.kind == 'likes' then
        local like = a.slots.like or (not strongOther and not notAnswer and Dialogue.ExtractLike(ctx.text, true))
        if like then
            handlers.player_like(ctx, a, out, vars, like)
            return true
        end
    elseif e.kind == 'origin' then
        local origin, isLocal = a.slots.origin, a.slots.originLocal
        if not origin and not notAnswer then origin, isLocal = Dialogue.ExtractOrigin(ctx.text, not strongOther) end
        if origin then
            handlers.player_origin(ctx, a, out, vars, origin, isLocal)
            return true
        end
    elseif e.kind == 'player_day' then
        if not strongOther and not notAnswer then
            if soundsBad(a.norm) or a.best == 'player_mood_bad' then
                handlers.player_mood_bad(ctx, a, out)
            else
                out.say('player_day_good')
            end
            return true
        end
    elseif e.kind == 'plans' then
        if not strongOther and not notAnswer then
            local sub = 'default'
            if a.norm:find('calis', 1, true) or hasToken(a.tokens, 'is', 'iste', 'mesai', 'nobet') then
                sub = 'work'
            elseif hasToken(a.tokens, 'hic', 'yok', 'bos', 'bilmiyorum', 'evde') then
                sub = 'none'
            end
            out.say('player_plans', sub)
            return true
        end
    elseif e.kind == 'fav_place' then
        if a.slots.place then
            local loc = a.slots.place
            out.rel.facts = out.rel.facts or {}
            out.rel.facts.fav_place = loc.id
            vars.loc = loc.label
            vars.fact_fav = loc.label
            out.topic = 'pfav'
            out.say('player_fav', Utils.Contains(ctx.r.favorite_places or {}, loc.id) and 'same' or 'default')
            return true
        end
        if not strongOther and not notAnswer and #a.tokens >= 2 then
            out.say('share_ack')
            return true
        end
    elseif e.kind == 'share' then
        if not strongOther and not notAnswer then
            if e.bad or soundsBad(a.norm) then
                out.say('share_bad')
                out.dAff = out.dAff + 1
            else
                out.say('share_ack')
            end
            out.topics.player_story = true
            return true
        end
    elseif e.kind == 'meet_place' and c.meet then
        if a.slots.place then
            meetFlow(ctx, a, out, vars, false)
            return true
        end
        if a.best == 'yes' or (not strongOther and hasToken(a.tokens, 'olur', 'tamam', 'evet', 'uyar', 'tabii', 'tabi')) then
            c.meet.locId = e.loc
            meetFlow(ctx, a, out, vars, false)
            return true
        end
        if a.best == 'no' then
            c.expect = { kind = 'meet_place_free' }
            out.say('meet_declined')
            return true
        end
    elseif e.kind == 'meet_time' and c.meet then
        if a.slots.time or a.slots.day then
            meetFlow(ctx, a, out, vars, false)
            return true
        end
        if a.best == 'yes' or (not strongOther and hasToken(a.tokens, 'olur', 'tamam', 'evet', 'uyar', 'tabii', 'tabi')) then
            c.meet.minutes = e.start % 1440
            c.meet.day = Clock.Day(e.start) - Clock.Day()
            meetFlow(ctx, a, out, vars, false)
            return true
        end
        if a.best == 'no' then
            out.say('meet_declined')
            return true
        end
    elseif e.kind == 'meet_place_free' and c.meet then
        if a.slots.place or a.slots.time then
            meetFlow(ctx, a, out, vars, false)
            return true
        end
    end
    return false
end

-- Sakin sohbeti sürdürmek için kendisi soru sorar (kısa cevaplardan sonra, konuşkanlarda daha sık)
local function maybeAsk(ctx, out, intent, parts)
    local c, rel, r = ctx.c, ctx.rel, ctx.r
    if c.expect or out.tail or NO_ASK[intent] or #parts == 0 or #parts > 2 or #out.actions > 0 or c.lastWasQuestion then return end
    if tostring(parts[#parts]):find('%?%s*$') then return end
    if Dialogue.StageGroup(rel.stage) == 'cold' then return end
    if (c.playerMsgs or 0) < 2 or (c.npcQs or 0) >= 3 then return end
    local chance = Config.Dialogue.NpcQuestionChance or 0.22
    if Dialogue.Talkative(r) then chance = chance * 1.7 end
    local tone = Dialogue.Tone(r)
    if tone == 'shy' or tone == 'grumpy' then chance = chance * 0.5 end
    if intent == 'ack' or intent == 'agree' or intent == 'laugh' or intent == 'fallback_short' then chance = chance * 2 end
    if math.random() >= chance then return end
    local facts = rel.facts or {}
    c.askedKinds = c.askedKinds or {}
    local options = {}
    for _, q in ipairs(D.NpcQuestions or {}) do
        local f = q.fact and facts[q.fact]
        local known = f ~= nil and (type(f) ~= 'table' or #f > 0)
        if not known and not c.askedKinds[q.kind] and (not q.minStage or SC.StageAtLeast(rel.stage, q.minStage)) then
            options[#options + 1] = q
        end
    end
    if #options == 0 then return end
    local q = options[math.random(#options)]
    c.askedKinds[q.kind] = true
    c.npcQs = (c.npcQs or 0) + 1
    if out.sayList(q.lines) then c.expect = { kind = q.kind } end
end

--[[
    ctx = { r, rel, c (konuşma/SMS durumu), cid, channel = 'talk'|'sms', playerFirst, dry }
    dönüş: { reply, emotion, animation, dAff, dTrust, actions, memories, rel (güncellemeler), event, topics, intent, suggestions }
]]
function Dialogue.Respond(ctx, text)
    local r, rel, c = ctx.r, ctx.rel, ctx.c
    ctx.text = text
    ctx.addr = Dialogue.PlayerAddress(rel)
    ctx.noAskBack = nil
    ctx.noBack = nil
    c.asked = c.asked or {}
    c.topics = c.topics or {}
    c.used = c.used or {}
    c.usedN = c.usedN or 0
    if c.usedN > 120 then
        c.used, c.usedN = {}, 0
    end
    local a = Dialogue.Analyze(r, text)
    local vars = Dialogue.Vars(r, rel)
    local parts = {}
    local lastLine = c.lastLine
    -- konuşma içinde kullanılanlar + NPC'nin (başka oyuncularla da) yakın zamanda söyledikleri tekrar seçilmez
    local recent = SC.DGen and SC.DGen.RecentSet(r) or {}
    local usedLookup = setmetatable({}, { __index = function(_, k) return c.used[k] or recent[k] end })
    local out = {
        dAff = 0, dTrust = 0, actions = {}, memories = {}, rel = {}, topics = c.topics,
        emotion = 'neutral', animation = 'none',
    }
    local function remember(line)
        if line and not c.used[line] then
            c.used[line] = true
            c.usedN = c.usedN + 1
        end
    end
    function out.push(line)
        if line and line ~= '' then parts[#parts + 1] = line end
    end
    function out.say(key, sub)
        local list = filterUsable(Dialogue.Bucket(key, r, rel.stage, sub), vars)
        if (not list or #list == 0) and sub then list = filterUsable(Dialogue.Bucket(key, r, rel.stage), vars) end
        local line = pick(list, lastLine, usedLookup)
        remember(line)
        out.push(line)
        return line
    end
    -- karşı soru: cevabın en sonuna (tek bir tane)
    function out.sayTail(key, sub)
        if out.tail then return nil end
        local list = filterUsable(Dialogue.Bucket(key, r, rel.stage, sub), vars)
        local line = pick(list, lastLine, usedLookup)
        remember(line)
        out.tail = line
        return line
    end
    function out.sayList(list)
        local line = pick(filterUsable(list, vars), lastLine, usedLookup)
        remember(line)
        out.push(line)
        return line
    end

    local intent = a.best
    local g = Dialogue.StageGroup(rel.stage)

    if c.hostage then
        -- rehine: korku içinde, sadece birkaç şeye anlamlı cevap verir
        local key = HOSTAGE_KEYS[intent or '']
        if key then out.say(key) end
        if #parts == 0 then out.say('hostage_plead', r.override and r.override.mode or 'hold') end
        out.emotion = 'scared'
        intent = 'hostage'
    else
        -- aynı cümleyi tekrarlarsa fark eder
        if c.lastPlayerNorm and a.norm == c.lastPlayerNorm and #a.tokens >= 2 then out.say('repeat_same') end
        c.lastPlayerNorm = a.norm

        -- meşgul (iş/yol) ve arkadaş değilse: birkaç cevaptan sonra işine döner
        local busyDef = SC.Activities[r.state.activity]
        if ctx.channel == 'talk' and busyDef and busyDef.busy and g ~= 'friend' and intent ~= 'goodbye' then
            c.busyTurns = (c.busyTurns or 0) + 1
            if c.busyTurns > (Config.Dialogue.BusyMaxTurns or 3) then
                out.say('busy_end')
                out.actions[#out.actions + 1] = { type = 'end_conversation' }
                intent = 'busy_end'
            end
        end

        local done = {}
        if intent ~= 'busy_end' then
            local handled = handleExpectation(ctx, a, out, vars)
            if handled then
                intent = 'expectation'
                -- "iyiyim, sen?": cevaptan sonra aynı soruyu sakin kendisi için cevaplar
                if a.scores.ask_back and c.backIntent and not ctx.noBack then
                    done[c.backIntent] = true
                    handlers.ask_back(ctx, a, out, vars)
                end
            else
                if intent == 'ask_back' and c.backIntent then done[c.backIntent] = true end
                if intent then done[intent] = true end
                if c.meet and not intent and (a.slots.place or a.slots.time or a.slots.day) then intent = 'meet_continue' end
                if intent == 'meet_continue' then
                    meetFlow(ctx, a, out, vars, false)
                elseif intent and intent:sub(1, 7) == 'custom:' then
                    for _, i in ipairs(allIntents()) do
                        if i.id == intent then customHandler(i)(ctx, a, out, vars) break end
                    end
                elseif intent and handlers[intent] then
                    -- aynı bilgiyi tekrar tekrar sorarsa
                    c.asked[intent] = (c.asked[intent] or 0) + 1
                    if INFO_INTENTS[intent] and c.asked[intent] >= 2 then
                        out.say('repeat_answer')
                        if c.asked[intent] >= 3 then out.dAff = out.dAff - 1 end
                    end
                    handlers[intent](ctx, a, out, vars)
                    if D.Topics[intent] then c.topics[intent] = true end
                else
                    intent = Dialogue.Contextual(ctx, a, out, vars)
                end
                if c.meet then
                    c.meet.turns = (c.meet.turns or 0) + 1
                    if c.meet.turns > 3 then c.meet = nil end
                end
                -- "iyiyim, sen?" / "polisim, ya sen?": kendi hakkında söyleyip soruyu sakine yöneltti
                if a.scores.ask_back and intent ~= 'ask_back' and LEAD_OK[intent] and c.backIntent and not ctx.noBack and not done[c.backIntent] then
                    done[c.backIntent] = true
                    handlers.ask_back(ctx, a, out, vars)
                end
            end
            -- tek cümlede ikinci soru: "Selam, adın ne? Ne iş yapıyorsun?"
            if Config.Dialogue.SecondIntent ~= false and intent and (LEAD_OK[intent] or COMPOSABLE[intent]) then
                for _, cand in ipairs(a.ranked) do
                    if not done[cand.id] and (cand.id ~= a.best or intent == 'expectation') and COMPOSABLE[cand.id] and cand.score >= 1.8
                        and handlers[cand.id] and not (OVERLAP[intent] and OVERLAP[intent][cand.id]) then
                        local keepExpect = c.expect
                        ctx.noAskBack = keepExpect ~= nil
                        c.asked[cand.id] = (c.asked[cand.id] or 0) + 1
                        handlers[cand.id](ctx, a, out, vars)
                        if keepExpect then c.expect = keepExpect end
                        if D.Topics[cand.id] then c.topics[cand.id] = true end
                        out.topic = TOPIC_OF[cand.id] or out.topic
                        break
                    end
                end
            end
        end

        -- ilk mesajda selam + başka bir soru varsa kısa selam ekle
        if a.scores.greet and intent ~= 'greet' and not c.greeted and (c.playerMsgs or 0) <= 1 then
            c.greeted = true
            local greetLine = pick(filterUsable(Dialogue.Bucket('greet', r, rel.stage), vars))
            if greetLine then table.insert(parts, 1, greetLine) end
        end

        -- ilişki etkisi (niyet başına)
        local delta = (Config.Dialogue.Deltas or {})[intent == 'expectation' and 'answer' or intent]
        if delta then
            out.dAff = out.dAff + (delta[1] or 0)
            out.dTrust = out.dTrust + (delta[2] or 0)
        end

        -- duygu & hareket
        local emo = EMO[intent]
        if emo and out.emotion == 'neutral' then out.emotion = emo[1] end
        if emo and out.animation == 'none' then out.animation = emo[2] end
        if intent == 'greet' and g == 'cold' then out.emotion, out.animation = 'angry', 'none' end

        -- sohbeti sürdürme
        if intent ~= 'busy_end' then maybeAsk(ctx, out, intent, parts) end

        -- kişilik süsü: ağız alışkanlığı / dolgu sözcüğü (başa) / hitap (sona) / konuşkanlık
        if g ~= 'cold' and #parts > 0 and intent ~= 'threat' and intent ~= 'insult' then
            local q = Dialogue.Quirks(r)
            local decorated = false
            if #q.prefix > 0 and FILLER_OK[intent] and math.random() < 0.15 then
                parts[1] = pick(q.prefix) .. ', ' .. Dialogue.Lowerfirst(parts[1])
                decorated = true
            end
            local startsSoft = Utils.Fold(parts[1]):match('^(hm)') or Utils.Fold(parts[1]):match('^(valla)') or Utils.Fold(parts[1]):match('^(ya[%.%s,])')
            if not decorated and FILLER_OK[intent] and not startsSoft and math.random() < (Config.Dialogue.FillerChance or 0.15) then
                local f = pick((D.Fillers or {})[Dialogue.Tone(r)] or (D.Fillers or {}).neutral)
                if f then table.insert(parts, 1, f) end
            end
            if #q.vocative > 0 and math.random() < 0.3 then
                local voc = pick(q.vocative)
                local casual = voc == 'kanka' or voc == 'dostum' or voc == 'kardo'
                if not casual or g == 'friend' or g == 'known' then
                    parts[#parts] = parts[#parts]:gsub('([%.!%?]?)$', ', ' .. voc .. '%1', 1)
                end
            end
            if Dialogue.Talkative(r) and (intent == 'how_are_you' or intent == 'ask_doing' or intent == 'greet') and math.random() < 0.35 and #parts < 3 then
                local ch = pick(filterUsable(D.Lines.chatter.default, vars), nil, usedLookup)
                if ch then
                    remember(ch)
                    parts[#parts + 1] = ch
                end
            end
        end
    end

    -- v3: kişilik ve ruh hâli süsleri
    if not c.hostage and #parts > 0 and SC.Persona then
        local mood = SC.Persona.MoodLabel(r, rel, ctx.cid)
        local st = SC.Persona.Stats(r)
        if mood == 'tired' and FILLER_OK[intent] and out.tail and math.random() < 0.6 then
            out.tail = nil   -- yorgunken karşı soru sormaz, kısa keser
            if math.random() < 0.35 then parts[#parts + 1] = 'Biraz yorgunum da, kusura bakma.' end
        end
        if g ~= 'cold' and FILLER_OK[intent] and not out.tail and #parts < 3 and st.humor >= 60
            and math.random() < ((Config.Intelligence and Config.Intelligence.HumorQuipChance) or 0.35) * st.humor / 100 then
            local q = SC.DGen and SC.DGen.Compose('quip', r, rel, { vars = vars, used = usedLookup })
            if q then parts[#parts + 1] = q end
        end
    end

    if out.tail then parts[#parts + 1] = out.tail end
    if SC.DGen then
        for _, p in ipairs(parts) do SC.DGen.Remember(r, p) end
    end
    local filled = {}
    for _, p in ipairs(parts) do
        local f = Dialogue.Fill(p, vars)
        if f ~= '' then filled[#filled + 1] = Dialogue.Capitalize(f) end
    end
    out.reply = table.concat(filled, ' ')
    if out.reply == '' then out.reply = '...' end
    c.lastLine = parts[#parts]
    c.lastWasQuestion = out.reply:find('%?%s*$') ~= nil
    -- son konu: tepkiler ("neden?", "gerçekten mi?") buna göre cevaplanır
    if out.topic then
        c.lastTopic = out.topic
    elseif TOPIC_OF[intent] then
        c.lastTopic = TOPIC_OF[intent]
    elseif not FOLLOWUPS[intent] and intent ~= 'ask_back' and intent ~= 'expectation' then
        c.lastTopic = nil
    end
    out.intent = intent
    out.canonical = (D.Canonical and D.Canonical[intent or '']) or (intent and intent:upper()) or 'UNKNOWN'
    out.analysis = a
    out.suggestions = Dialogue.Suggestions(ctx)
    return out
end

-- Tanıdığı oyuncuyu karşılarken onun hakkında bildiklerinden bahset
local function factRecall(ctx, vars)
    local rel, c = ctx.rel, ctx.c
    local f = rel.facts or {}
    local lm = type(f.last_mood) == 'table' and f.last_mood or nil
    if lm and lm.v == 'bad' and not lm.recalled and os.time() - (tonumber(lm.at) or 0) < 3 * 86400 then
        if not ctx.dry then
            lm.recalled = true
            SC.Rel.MarkDirty(rel)
        end
        c.expect = { kind = 'player_mood' }
        return pick(D.FactRecall.mood_bad)
    end
    local opts = {}
    if vars.fact_job then opts[#opts + 1] = { 'job', 'pjob' } end
    if vars.fact_like then opts[#opts + 1] = { 'like', 'plike' } end
    if vars.fact_origin then opts[#opts + 1] = { 'origin', 'porigin' } end
    if vars.fact_fav then opts[#opts + 1] = { 'fav', 'pfav' } end
    if #opts == 0 then return nil end
    local o = opts[math.random(#opts)]
    c.lastTopic = o[2]
    return pick(filterUsable(D.FactRecall[o[1]], vars))
end

-- Konuşma başında sakinin ilk sözü
function Dialogue.Greeting(ctx, info)
    local r, rel, c = ctx.r, ctx.rel, ctx.c
    local vars = Dialogue.Vars(r, rel)
    c.used = c.used or {}
    if c.hostage then
        c.greeted = true
        return Dialogue.Capitalize(Dialogue.Fill(pick(D.Lines.hostage_greet.default), vars)), 'scared'
    end
    local g = Dialogue.StageGroup(rel.stage)
    local def = SC.Activities[r.state.activity]
    local line, emotion = nil, (g == 'friend' and 'happy' or 'neutral')
    if not ctx.dry then
        local grudge = Dialogue.FindCoded(r.id, ctx.cid, -1)
        local recent = grudge and (os.time() - (tonumber(grudge.created_at) or 0)) < 3 * 86400
        if grudge and (g == 'cold' or recent) then
            line = Dialogue.GrudgeLine(r, grudge)
            if line then emotion = 'angry' end
        end
    end
    if not line then
        local key
        if g == 'cold' then
            key = 'greet'
        elseif info and info.daysAway and info.daysAway >= (Config.Relationship.LongAbsenceDays or 4) and g ~= 'stranger' then
            key = 'greet_absence'
        elseif def and def.busy and g ~= 'friend' then
            key = 'greet_busy'
        else
            key = 'greet'
        end
        -- v3: kategoriye özel selam kovası (ör. greet_entertainer)
        local typed = SC.NPC and ('greet_' .. SC.NPC.Type(r):gsub('^adult_', ''))
        if key == 'greet' and typed and D.Lines[typed] then key = typed end
        local recentSet = SC.DGen and SC.DGen.RecentSet(r) or nil
        -- v3: parçalardan dinamik selam (kişilik + ilişki + ruh hâli)
        local G = Config.Dialogue.Generator or {}
        if key == 'greet' and SC.DGen and G.Enabled ~= false and math.random() < (G.GreetingChance or 0.5) then
            line = SC.DGen.Compose('greet', r, rel, { vars = vars, src = c.src })
        end
        if not line then
            line = pick(filterUsable(Dialogue.Bucket(key, r, rel.stage), vars), nil, recentSet) or '...'
            if SC.DGen then SC.DGen.Remember(r, line) end
        end
        local extra
        -- v3: ortam gözlemi — oyuncu yaralı/silahlıysa her zaman, yağmur/gece/çatışma/polis bazen
        if not ctx.dry and g ~= 'cold' and SC.DGen and SC.Aware and c.src then
            local cond = SC.DGen.Cond(r, rel, c.src)
            local strong = cond.injured or cond.armed
            local weak = cond.rain or cond.fight or cond.police or cond.night
            if strong or (weak and math.random() < (G.AwarenessChance or 0.6)) then
                extra = SC.DGen.Compose('aware', r, rel, { vars = vars, cond = cond })
                if extra and cond.injured then emotion = 'surprised' end
            end
        end
        -- v3: NPC'nin bekleyen teklifi (beraber gezerken önerdiği yer)
        if not extra and not ctx.dry and SC.Context and ctx.cid then
            local p = SC.Context.TakeProposal(r.id, ctx.cid, true)
            if p and p.text then
                extra = p.text
                c.expect = { kind = 'npc_proposal', proposal = p }
            end
        end
        if not extra and not ctx.dry and g ~= 'cold' and g ~= 'stranger' and math.random() < 0.35 then
            local good = Dialogue.FindCoded(r.id, ctx.cid, 1)
            if good and D.Recall[good.code] and (os.time() - (tonumber(good.created_at) or 0)) < 4 * 86400 then
                extra = pick(D.Recall[good.code])
                emotion = 'happy'
            end
        end
        if not extra and g ~= 'cold' and g ~= 'stranger' and math.random() < (Config.Dialogue.FactRecallChance or 0.4) then
            extra = factRecall(ctx, vars)
        end
        if not extra and g ~= 'cold' and not (def and def.busy) and math.random() < 0.2 then
            extra = vars.doing
        end
        if extra then line = line .. ' ' .. extra end
    end
    c.greeted = true
    c.lastWasQuestion = line:find('%?%s*$') ~= nil
    return Dialogue.Capitalize(Dialogue.Fill(line, vars)), emotion
end

-- Tek bir şablon kovasından doldurulmuş cümle (sub: alt kova, ör. rehine modu)
function Dialogue.Line(key, r, rel, sub, extra)
    local vars = Dialogue.Vars(r, rel)
    if type(extra) == 'table' then for k, v in pairs(extra) do vars[k] = v end end
    local list = filterUsable(Dialogue.Bucket(key, r, rel.stage, sub), vars)
    if (not list or #list == 0) and sub then list = filterUsable(Dialogue.Bucket(key, r, rel.stage), vars) end
    local line = pick(list, nil, SC.DGen and SC.DGen.RecentSet(r) or nil)
    if not line then return '...' end
    if SC.DGen then SC.DGen.Remember(r, line) end
    return Dialogue.Capitalize(Dialogue.Fill(line, vars))
end

-- SMS'te günlük yazım: genç/samimi karakterler küçük harfle, noktasız yazar; resmî ve yaşlılar olduğu gibi
local function startsWithName(text, rel)
    local first = Utils.Fold(text:match('^([^%s%p]+)') or '')
    if first == '' then return false end
    local names = {}
    for _, o in ipairs(Sim.List or {}) do names[#names + 1] = o.firstname end
    if rel then
        names[#names + 1] = rel.nickname
        if rel.char_name then for w in rel.char_name:gmatch('%S+') do names[#names + 1] = w end end
    end
    for _, n in ipairs(names) do
        if n and Utils.Fold(n) == first then return true end
    end
    for _, loc in pairs(Sim.Locations or {}) do
        if Utils.Fold((loc.label or ''):match('^(%S+)') or '') == first then return true end
    end
    return false
end

function Dialogue.SmsStyle(text, r, rel)
    if type(text) ~= 'string' or text == '' then return text end
    local tone = Dialogue.Tone(r)
    local age = r.age or 30
    if tone == 'formal' or age >= 45 then return text end
    if not (tone == 'warm' or age < 30) and math.random() < 0.5 then return text end
    local s = text
    if math.random() < 0.6 and not startsWithName(s, rel) then s = Dialogue.Lowerfirst(s) end
    if math.random() < 0.7 then s = s:gsub('([^%.])%.$', '%1') end
    if math.random() < 0.35 then
        s = s:gsub('%f[%a]Tamam%f[%A]', 'Tmm'):gsub('%f[%a]tamam%f[%A]', 'tmm')
    end
    return s
end

-- Motorun döndürdüğü ilişki güncellemelerini uygula (ad, takma ad, oyuncu hakkında öğrenilenler)
function Dialogue.ApplyRelUpdates(rel, updates)
    if type(updates) ~= 'table' then return end
    for k, v in pairs(updates) do
        if k == 'facts' then
            rel.facts = rel.facts or {}
            for fk, fv in pairs(v) do rel.facts[fk] = fv end
            if type(rel.facts.likes) == 'table' then
                while #rel.facts.likes > 5 do table.remove(rel.facts.likes, 1) end
            end
        else
            rel[k] = v
        end
    end
    SC.Rel.MarkDirty(rel)
end

-- Yakından geçerken selam baloncuğu
function Dialogue.Ambient(r, rel)
    local g = Dialogue.StageGroup(rel.stage)
    local key = g == 'friend' and 'ambient_friend' or (g == 'cold' and 'ambient_cold' or 'ambient_known')
    local vars = Dialogue.Vars(r, rel)
    local line = pick(filterUsable(D.Lines[key] and D.Lines[key].default, vars), nil, SC.DGen and SC.DGen.RecentSet(r) or nil)
    if not line then return nil end
    if SC.DGen then SC.DGen.Remember(r, line) end
    return Dialogue.Capitalize(Dialogue.Fill(line, vars))
end

-- Hızlı cevap düğmeleri: bekleyen soruya uygun cevaplar + son konuya göre devam + genel öneriler
function Dialogue.Suggestions(ctx)
    local rel, c = ctx.rel, ctx.c
    local S = D.Suggestions
    local out, seen = {}, {}
    local function add(list, max)
        local n = 0
        for _, s in ipairs(list or {}) do
            if #out < 7 and (not max or n < max) then
                local txt = s:gsub('%%name%%', ctx.playerFirst or '')
                if not txt:find('%%') and not seen[txt] then
                    out[#out + 1] = txt
                    seen[txt] = true
                    n = n + 1
                end
            end
        end
    end
    if c.hostage then
        add(S.hostage)
        return out
    end
    local e = c.expect
    if e and (e.kind == 'meet_place' or e.kind == 'meet_time') then
        add(S.yesno)
        return out
    end
    if e and e.kind == 'npc_proposal' then add(S.proposal or S.yesno) end
    if ctx.r and ctx.r.override and ctx.r.override.type == 'companion' and ctx.r.override.target == ctx.c.src then
        add(S.companion, 2)
    end
    if rel.romance and rel.romance ~= 'none' then add(S.romance, 1) end
    if e and S.answer and S.answer[e.kind] then add(S.answer[e.kind], 3) end
    if c.lastTopic and S.followup and S.followup[c.lastTopic] then add(S.followup[c.lastTopic], 2) end
    local g = Dialogue.StageGroup(rel.stage)
    if not rel.npc_name_shown and g ~= 'cold' then add({ S.stranger[1] }) end
    if not rel.name_known and not rel.nickname and ctx.playerFirst then add({ S.stranger[2] }) end
    -- genel önerilerden rastgele birkaçı (her seferinde farklı)
    local base = {}
    for _, s in ipairs(S.base or {}) do base[#base + 1] = s end
    for i = #base, 2, -1 do
        local j = math.random(i)
        base[i], base[j] = base[j], base[i]
    end
    add(base, 3)
    if SC.StageAtLeast(rel.stage, 'acquaintance') then
        for _, s in ipairs(S.known) do
            if not (rel.phone_known and s:find('Numara', 1, true)) then add({ s }, 1) end
        end
    end
    if SC.StageAtLeast(rel.stage, 'friend') then add(S.friend, 1) end
    add(S.bye)
    return out
end

-- Konuşma sonu özeti (anı)
function Dialogue.Summary(r, c, charName, placeId)
    local keys, phrases = {}, {}
    for k in pairs(c.topics or {}) do
        if D.Topics[k] then keys[#keys + 1] = k end
    end
    table.sort(keys)
    for _, k in ipairs(keys) do phrases[#phrases + 1] = D.Topics[k] end
    local who = charName or L('ctx_someone')
    local text
    if #phrases > 0 then
        text = L('mem_convo_summary', who, Sim.LocationLabel(placeId), joinList(phrases))
    else
        text = L('mem_convo_short', who, Sim.LocationLabel(placeId))
    end
    return text, { kind = 'convo', place = placeId, topics = keys }
end

-- Yönetim paneli: yan etkisiz test (history: aynı konuşmanın önceki cümleleri — bağlam testi için)
function Dialogue.Test(r, text, stage, playerName, state)
    local rel = {
        stage = stage or 'stranger', familiarity = 30, affinity = 10, trust = 20, times_met = 2, meet_days = 1,
        name_known = SC.StageAtLeast(stage or 'stranger', 'acquaintance'), char_name = playerName or 'Test Oyuncu',
        phone_known = false, facts = {},
    }
    local c = type(state) == 'table' and state or {}
    c.playerMsgs = (c.playerMsgs or 0) + 1
    local ctx = { r = r, rel = rel, c = c, cid = nil, channel = 'talk', playerFirst = firstName(playerName or 'Test'), dry = true }
    local res = Dialogue.Respond(ctx, text)
    local a = res.analysis
    local top = {}
    for i = 1, math.min(5, #a.ranked) do top[#top + 1] = { id = a.ranked[i].id, score = Utils.Round(a.ranked[i].score, 2) } end
    return {
        intent = res.intent, reply = res.reply, emotion = res.emotion, top = top,
        slots = {
            place = a.slots.place and a.slots.place.label or nil,
            person = a.slots.person and a.slots.person.firstname or nil,
            time = a.slots.time and Utils.FormatTime(a.slots.time) or nil,
            day = a.slots.day, name = a.slots.name, job = a.slots.job, like = a.slots.like,
            topic = c.lastTopic, expect = c.expect and c.expect.kind or nil,
        },
        actions = res.actions, dAff = res.dAff, dTrust = res.dTrust,
    }, c
end
