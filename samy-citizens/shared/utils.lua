SC = SC or {}
Locales = Locales or {}

local Utils = {}
SC.Utils = Utils

-- ---------------------------------------------------------------------
-- Yerelleştirme
-- ---------------------------------------------------------------------
function L(key, ...)
    local lang = Locales[Config.Locale] or Locales.tr or {}
    local str = lang[key]
    if str == nil and Locales.en then str = Locales.en[key] end
    if str == nil then return key end
    if select('#', ...) > 0 then
        local ok, res = pcall(string.format, str, ...)
        if ok then return res end
    end
    return str
end

-- Yerelleştirilmiş tablo (liste vb.) döndürür
function LT(key)
    local lang = Locales[Config.Locale] or Locales.tr or {}
    local v = lang[key]
    if v == nil and Locales.en then v = Locales.en[key] end
    return v
end

-- ---------------------------------------------------------------------
-- Sayı yardımcıları
-- ---------------------------------------------------------------------
function Utils.Clamp(v, a, b)
    if v < a then return a end
    if v > b then return b end
    return v
end

function Utils.Round(v, dec)
    local m = 10 ^ (dec or 0)
    return math.floor(v * m + 0.5) / m
end

function Utils.Lerp(a, b, t)
    return a + (b - a) * t
end

function Utils.ToInt(v, def)
    local n = tonumber(v)
    if not n then return def end
    return math.floor(n)
end

-- ---------------------------------------------------------------------
-- Zaman yardımcıları
-- ---------------------------------------------------------------------
-- "HH:MM" -> dakika (24:00 üstü de desteklenir, örn "26:30")
function Utils.ParseTime(str)
    if type(str) == 'number' then return math.floor(str) end
    if type(str) ~= 'string' then return nil end
    local h, m = str:match('^%s*(%d+):(%d%d)%s*$')
    if not h then return nil end
    return tonumber(h) * 60 + tonumber(m)
end

function Utils.FormatTime(minutes)
    minutes = math.floor(minutes or 0) % 1440
    return ('%02d:%02d'):format(minutes // 60, minutes % 60)
end

-- ---------------------------------------------------------------------
-- Metin yardımcıları (UTF-8 / Türkçe)
-- ---------------------------------------------------------------------
local foldMap = {
    ['ç'] = 'c', ['Ç'] = 'c', ['ğ'] = 'g', ['Ğ'] = 'g', ['ı'] = 'i', ['İ'] = 'i',
    ['ö'] = 'o', ['Ö'] = 'o', ['ş'] = 's', ['Ş'] = 's', ['ü'] = 'u', ['Ü'] = 'u',
    ['â'] = 'a', ['Â'] = 'a', ['î'] = 'i', ['Î'] = 'i', ['û'] = 'u', ['Û'] = 'u',
    ['é'] = 'e', ['É'] = 'e', ['è'] = 'e', ['á'] = 'a', ['à'] = 'a', ['ñ'] = 'n',
}
local upperSet = {
    ['Ç'] = true, ['Ğ'] = true, ['İ'] = true, ['Ö'] = true, ['Ş'] = true, ['Ü'] = true,
    ['Â'] = true, ['Î'] = true, ['Û'] = true, ['É'] = true,
}

-- Küçük harfe çevirip Türkçe karakterleri ASCII'ye katlar (eşleştirme amaçlı)
function Utils.Fold(str)
    if type(str) ~= 'string' then return '' end
    str = str:gsub('[\xC3\xC4\xC5][\x80-\xBF]', function(c) return foldMap[c] end)
    return str:lower()
end

-- Görüntüleme amaçlı ASCII (GTA yerel fontları Türkçe karakterleri çizemez)
function Utils.Ascii(str)
    if type(str) ~= 'string' then return '' end
    local out = str:gsub('[\xC3\xC4\xC5][\x80-\xBF]', function(c)
        local f = foldMap[c]
        if not f then return '?' end
        if upperSet[c] then return f:upper() end
        return f
    end)
    return out
end

function Utils.Trim(s)
    if type(s) ~= 'string' then return '' end
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

function Utils.Utf8Len(s)
    local n = utf8.len(s)
    return n or #s
end

-- UTF-8 güvenli kısaltma
function Utils.Truncate(s, maxChars)
    if type(s) ~= 'string' then return '' end
    local len = utf8.len(s)
    if not len then
        return s:sub(1, maxChars)
    end
    if len <= maxChars then return s end
    local pos = utf8.offset(s, maxChars + 1)
    return s:sub(1, pos - 1)
end

-- Geçersiz UTF-8 baytlarını atar
local function stripInvalidUtf8(s)
    if utf8.len(s) then return s end
    local out, i, n = {}, 1, #s
    while i <= n do
        local c = s:byte(i)
        local len = c < 0x80 and 1 or (c >= 0xF0 and 4) or (c >= 0xE0 and 3) or (c >= 0xC2 and 2) or 0
        if len == 0 then
            i = i + 1
        else
            local chunk = s:sub(i, i + len - 1)
            if #chunk == len and utf8.len(chunk) then out[#out + 1] = chunk end
            i = i + len
        end
    end
    return table.concat(out)
end

-- Oyuncudan gelen metni temizler: kontrol karakterleri, fazla boşluk, geçersiz UTF-8
function Utils.SanitizeText(s, maxChars)
    if type(s) ~= 'string' then return '' end
    s = stripInvalidUtf8(s)
    s = s:gsub('%c', ' ')
    s = s:gsub('[<>]', '')
    s = s:gsub('%s+', ' ')
    s = Utils.Trim(s)
    return Utils.Truncate(s, maxChars or 300)
end

local stopwords = {}
for w in ([[ve veya ile bir bu su o ne mi mu da de ki ben sen biz siz onlar icin gibi ama cok daha en her hic ya yani
sey seyi beni seni bana sana onu ona var yok olarak olan ise diye nasil neden niye nerede hangi kim evet hayir tamam peki
simdi sonra once merhaba selam naber iyi abi abla kanka hocam lan hmm mi misin misiniz midir musun sey birsey bi
the a an is are was were you i me my to of and in it that what do does did be have has for on with your this at by not
but so just]]):gmatch('%S+') do stopwords[w] = true end

-- Türkçe için "F5" kök bulma: katlanmış kelimenin ilk 5 harfi
function Utils.Tokenize(text)
    local tokens = {}
    local folded = Utils.Fold(text or '')
    for word in folded:gmatch('[%a%d]+') do
        if #word >= 3 and not stopwords[word] then
            tokens[#tokens + 1] = word:sub(1, 5)
        end
    end
    return tokens
end

-- Kelime sınırlı arama (moderasyon vb.)
function Utils.ContainsPhrase(text, phrase)
    local t = ' ' .. Utils.Fold(text):gsub('[^%w]+', ' ') .. ' '
    local p = ' ' .. Utils.Fold(phrase):gsub('[^%w]+', ' ') .. ' '
    p = p:gsub('%s+', ' ')
    return t:find(p, 1, true) ~= nil
end

-- ---------------------------------------------------------------------
-- Hash & deterministik rastgele
-- ---------------------------------------------------------------------
function Utils.Hash(str)
    local h = 5381
    str = tostring(str)
    for i = 1, #str do
        h = ((h * 33) + str:byte(i)) & 0x7fffffff
    end
    return h
end

-- Tohumlu PRNG: rng() -> [0,1), rng(n) -> 1..n, rng(a,b) -> a..b
function Utils.Rng(seed)
    local s = (math.floor(seed or 1) & 0x7fffffff)
    if s == 0 then s = 1 end
    return function(a, b)
        s = (s * 1103515245 + 12345) & 0x7fffffff
        local r = s / 2147483648.0
        if a and b then
            return a + math.floor(r * (b - a + 1))
        elseif a then
            return 1 + math.floor(r * a)
        end
        return r
    end
end

function Utils.WeightedPick(list, rng)
    local total = 0.0
    for i = 1, #list do total = total + math.max(0, list[i].weight or 0) end
    if total <= 0 then return nil end
    local roll = (rng and rng() or math.random()) * total
    for i = 1, #list do
        roll = roll - math.max(0, list[i].weight or 0)
        if roll <= 0 then return list[i] end
    end
    return list[#list]
end

-- ---------------------------------------------------------------------
-- Tablo & vektör yardımcıları
-- ---------------------------------------------------------------------
function Utils.DeepCopy(t, seen)
    if type(t) ~= 'table' then return t end
    seen = seen or {}
    if seen[t] then return seen[t] end
    local out = {}
    seen[t] = out
    for k, v in pairs(t) do out[Utils.DeepCopy(k, seen)] = Utils.DeepCopy(v, seen) end
    return out
end

function Utils.Count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

function Utils.Contains(list, value)
    if type(list) ~= 'table' then return false end
    for i = 1, #list do if list[i] == value then return true end end
    return false
end

-- vector3/vector4/tablo -> {x,y,z,w} düz tablo (JSON için)
function Utils.VecToTable(v)
    if not v then return nil end
    local t = { x = Utils.Round(v.x + 0.0, 3), y = Utils.Round(v.y + 0.0, 3), z = Utils.Round(v.z + 0.0, 3) }
    local ok, w = pcall(function() return v.w end)
    if ok and w then t.w = Utils.Round(w + 0.0, 2) end
    return t
end

-- tablo/vektör -> vector4 (w yoksa 0)
function Utils.ToVec4(t)
    if not t then return nil end
    local ok, w = pcall(function() return t.w end)
    return vector4((t.x or t[1] or 0) + 0.0, (t.y or t[2] or 0) + 0.0, (t.z or t[3] or 0) + 0.0, ((ok and w) or t[4] or 0) + 0.0)
end

function Utils.ToVec3(t)
    if not t then return nil end
    return vector3((t.x or t[1] or 0) + 0.0, (t.y or t[2] or 0) + 0.0, (t.z or t[3] or 0) + 0.0)
end

function Utils.Dist(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function Utils.Dist2D(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

function Utils.HeadingTo(from, to)
    local h = math.deg(math.atan(to.y - from.y, to.x - from.x)) - 90.0
    if h < 0 then h = h + 360.0 end
    return h
end

-- ---------------------------------------------------------------------
-- JSON
-- ---------------------------------------------------------------------
function Utils.JsonDecode(str)
    if type(str) ~= 'string' or str == '' then return nil end
    local ok, res = pcall(json.decode, str)
    if ok then return res end
    return nil
end

function Utils.JsonEncode(v)
    local ok, res = pcall(json.encode, v)
    if ok then return res end
    return 'null'
end

-- ---------------------------------------------------------------------
-- Göreli zaman ("dün", "3 gün önce")
-- ---------------------------------------------------------------------
function Utils.RelativeAge(seconds)
    seconds = math.max(0, seconds or 0)
    if seconds < 90 then return L('age_now') end
    if seconds < 3600 then return L('age_minutes', math.floor(seconds / 60)) end
    if seconds < 86400 then return L('age_hours', math.floor(seconds / 3600)) end
    local days = math.floor(seconds / 86400)
    if days == 1 then return L('age_yesterday') end
    if days < 14 then return L('age_days', days) end
    if days < 60 then return L('age_weeks', math.floor(days / 7)) end
    return L('age_months', math.floor(days / 30))
end

-- ---------------------------------------------------------------------
-- İlişki aşamaları (paylaşılan)
-- ---------------------------------------------------------------------
SC.StageOrder = { enemy = -2, cold = -1, stranger = 0, acquaintance = 1, friend = 2, close_friend = 3 }

function SC.StageAtLeast(stage, minStage)
    return (SC.StageOrder[stage] or 0) >= (SC.StageOrder[minStage] or 0)
end

function SC.DebugPrint(...)
    if Config.Debug then
        print(('^5[samy-citizens]^7 %s'):format(table.concat({ ... }, ' ')))
    end
end
