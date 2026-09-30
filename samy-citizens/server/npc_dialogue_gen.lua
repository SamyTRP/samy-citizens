--[[
    DİNAMİK CÜMLE ÜRETİCİ (yapay zekâ yok)
    SCDialogue.Parts[anahtar] = { slot1, slot2, ... }  (data/dialogue_life.lua)
    Her slottan koşulları tutan girdiler arasından ağırlıklı seçim yapılır (daha çok koşul tutan daha olası),
    seçilen girdiden son kullanılmamış bir cümle alınır, parçalar birleştirilip yer tutucular doldurulur.
      friendly NPC     : "Selam Samy, bugün nasıl gidiyor?"
      mesafeli NPC     : "Selam. Bir şey mi vardı?"
      yakın arkadaş    : "Ooo, sonunda ortaya çıktın."
      flört/sevgili    : "Samy! Bugün seni göremeyeceğim sandım."
    Tekrar önleme: NPC başına RecentResponseHistory (Config.Dialogue.RecentHistorySize / RecentHistoryMinutes).
]]
local Utils = SC.Utils

local DGen = {}
SC.DGen = DGen

-- ---------------------------------------------------------------------
-- Son kullanılan cümleler (NPC başına, RAM)
-- ---------------------------------------------------------------------
local function historyCfg()
    local D = Config.Dialogue or {}
    return D.RecentHistorySize or 40, (D.RecentHistoryMinutes or 45) * 60
end

function DGen.Remember(r, line)
    if not r or type(line) ~= 'string' or line == '' then return end
    local size = historyCfg()
    r._recent = r._recent or {}
    local h = r._recent
    h[#h + 1] = { line = line, at = os.time() }
    while #h > size do table.remove(h, 1) end
end

-- { [cümle] = true } — süresi dolmamış son cümleler
function DGen.RecentSet(r)
    local out = {}
    if not r or not r._recent then return out end
    local _, ttl = historyCfg()
    local now = os.time()
    local h = r._recent
    for i = #h, 1, -1 do
        if now - h[i].at > ttl then
            table.remove(h, i)
        else
            out[h[i].line] = true
        end
    end
    return out
end

-- ---------------------------------------------------------------------
-- Koşullar
-- ---------------------------------------------------------------------
--[[ cond = { tone, group, romance (bool), mood (etiket), stats (tablo), time, rain, type, adult,
             injured, armed, fight, police, inVehicle, speeding } ]]
local function matches(when, cond)
    if not when then return true, 0 end
    local n = 0
    for k, v in pairs(when) do
        if k == 'stat' then
            for sk, min in pairs(v) do
                if ((cond.stats or {})[sk] or 50) < min then return false end
            end
            n = n + 1
        elseif k == 'statMax' then
            for sk, max in pairs(v) do
                if ((cond.stats or {})[sk] or 50) > max then return false end
            end
            n = n + 1
        elseif k == 'mood' then
            local ok = false
            for _, m in ipairs(type(v) == 'table' and v or { v }) do
                if m == cond.mood then ok = true end
            end
            if not ok then return false end
            n = n + 1
        elseif k == 'romance' then
            if (cond.romance == true) ~= (v == true) then return false end
            n = n + 1
        else
            local cv = cond[k]
            if type(v) == 'boolean' then
                if (cv == true) ~= v then return false end
            elseif cv ~= v then
                return false
            end
            n = n + 1
        end
    end
    return true, n
end

local function usable(line, vars)
    for k in line:gmatch('%%([%w_]+)%%') do
        if k ~= 'p' then
            local v = vars[k]
            if v == nil or v == '' then return false end
        end
    end
    return true
end

local function pickLine(lines, vars, recent, used)
    local fresh, any = {}, {}
    for _, l in ipairs(lines or {}) do
        if usable(l, vars) then
            any[#any + 1] = l
            if not recent[l] and not (used and used[l]) then fresh[#fresh + 1] = l end
        end
    end
    local list = #fresh > 0 and fresh or any
    if #list == 0 then return nil end
    return list[math.random(#list)]
end

-- ---------------------------------------------------------------------
-- Koşul tablosu oluşturma
-- ---------------------------------------------------------------------
function DGen.Cond(r, rel, src, extra)
    local stage = rel and rel.stage or 'stranger'
    local cond = {
        tone = SC.Persona.Tone(r, stage),
        group = SC.Dialogue.StageGroup(stage),
        romance = rel ~= nil and rel.romance ~= nil and rel.romance ~= 'none',
        mood = SC.Persona.MoodLabel(r, rel, rel and rel.citizenid),
        stats = SC.Persona.Stats(r),
        type = SC.NPC.Type(r),
        adult = SC.Adult and SC.Adult.IsAdultNPC(r) or false,
    }
    local snap = SC.Aware.Snapshot(r, src)
    for k, v in pairs(snap) do if cond[k] == nil then cond[k] = v end end
    for k, v in pairs(extra or {}) do cond[k] = v end
    return cond, snap
end

--[[
    Parçalardan cümle üret.
    dönüş: metin | nil (hiçbir slot tutmadıysa)
    opts = { vars, cond, used (konuşma içi kullanılanlar), noRemember }
]]
function DGen.Compose(key, r, rel, opts)
    local parts = SCDialogue.Parts and SCDialogue.Parts[key]
    if not parts then return nil end
    opts = opts or {}
    local vars = opts.vars or SC.Dialogue.Vars(r, rel)
    local cond = opts.cond or DGen.Cond(r, rel, opts.src)
    local recent = DGen.RecentSet(r)
    local pieces = {}
    for _, slot in ipairs(parts) do
        if not slot.chance or math.random() <= slot.chance then
            local cands, total = {}, 0
            for _, entry in ipairs(slot.list or {}) do
                local ok, n = matches(entry.when, cond)
                if ok then
                    local w = (entry.w or 1) * (1 + (n or 0) * 1.5)
                    cands[#cands + 1] = { entry = entry, w = w }
                    total = total + w
                end
            end
            -- ağırlıklı seçim; seçilen girdide kullanılabilir cümle yoksa diğerlerini dene
            local tries = 0
            while #cands > 0 and tries < 4 do
                tries = tries + 1
                local roll = math.random() * total
                local chosen, idx
                for i, c in ipairs(cands) do
                    roll = roll - c.w
                    if roll <= 0 then chosen, idx = c, i break end
                end
                chosen = chosen or cands[#cands]
                idx = idx or #cands
                local line = pickLine(chosen.entry.lines, vars, recent, opts.used)
                if line then
                    pieces[#pieces + 1] = line
                    break
                end
                total = total - chosen.w
                table.remove(cands, idx)
            end
        end
    end
    if #pieces == 0 then return nil end
    -- noktalama ile biten ön ekten sonra yeni cümle büyük harfle başlasın
    local text = pieces[1]
    for i = 2, #pieces do
        local p = pieces[i]
        if text:match('[%.!%?]$') then p = SC.Dialogue.Capitalize(p) end
        text = text .. ' ' .. p
    end
    text = SC.Dialogue.Capitalize(SC.Dialogue.Fill(text, vars))
    if text == '' then return nil end
    if not opts.noRemember then
        for _, p in ipairs(pieces) do DGen.Remember(r, p) end
    end
    return text
end

-- Konuşmada kullanılmamış, NPC'nin yakın zamanda söylemediği bir şablon satırı (bucket listesi için)
function DGen.PickFresh(r, list, vars, used)
    local line = pickLine(list, vars, DGen.RecentSet(r), used)
    if line then DGen.Remember(r, line) end
    return line
end
