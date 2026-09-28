--[[
    MESLEK YARDIMCILARI
    Sakinin meslek kategorisi (data/jobs.lua), iş yerine göre menü, sağlık tavsiyesi ve meslek soru-cevapları.
]]
local Utils = SC.Utils
local Sim = SC.Sim

local Jobs = {}
SC.Jobs = Jobs

local J = SCJobs or { Menus = {}, Health = {}, Categories = {} }
local byId = {}
for _, c in ipairs(J.Categories or {}) do byId[c.id] = c end

-- Meslek adından kategori (sakin başına önbellekli; meslek değişince admin kaydı r._jobCat'ı sıfırlar)
function Jobs.Category(r)
    if not r or not r.job then return nil end
    local title = Utils.Fold(r.job.title or '')
    if r._jobCatTitle == title then return r._jobCat end
    r._jobCatTitle = title
    r._jobCat = nil
    if title == '' then return nil end
    for _, c in ipairs(J.Categories or {}) do
        for _, k in ipairs(c.keywords or {}) do
            if title:find(k, 1, true) then
                r._jobCat = c
                return c
            end
        end
    end
    return nil
end

function Jobs.Get(id) return byId[id] end

function Jobs.HasService(r, service)
    local c = Jobs.Category(r)
    return c and Utils.Contains(c.services or {}, service) or false
end

-- Şu an işbaşında mı (iş yerinde çalışıyor)
function Jobs.OnDuty(r)
    local st = r and r.state or {}
    if st.activity == 'work' or st.activity == 'guard' then return true end
    return false
end

-- Menü: iş yerinin tipine göre; iş yeri yoksa meslek kategorisinden tahmin
local CAT_MENU = { bar = 'bar', waiter = 'restaurant', barista = 'cafe', cook = 'restaurant', cashier = 'shop' }

function Jobs.Menu(r)
    local c = Jobs.Category(r)
    if not c or not Utils.Contains(c.services or {}, 'order') then return nil end
    local wp = Sim.Locations[(r.job and r.job.workplaceId) or '']
    local menu = wp and J.Menus[wp.type]
    if not menu and wp and wp.type == 'office' then menu = J.Menus.cafe end
    return menu or J.Menus[CAT_MENU[c.id] or ''] or nil
end

function Jobs.MenuText(menu)
    if not menu then return '' end
    local names = {}
    for i, m in ipairs(menu) do
        if i <= 6 then names[#names + 1] = SC.Dialogue.Lowerfirst(m.label) end
    end
    return SC.Dialogue.JoinList(names)
end

-- Cümledeki kelimelerden menü kalemi
function Jobs.FindItem(menu, tokens)
    if not menu then return nil end
    for _, m in ipairs(menu) do
        for _, w in ipairs(m.words or {}) do
            for _, t in ipairs(tokens) do
                if t == w or (#w >= 4 and t:sub(1, #w) == w) then return m end
            end
        end
    end
    return nil
end

function Jobs.Price(r, item, rel)
    local S = Config.JobServices or {}
    if not S.Charge then return 0 end
    local price = math.floor(tonumber(item and item.price) or 0)
    if rel and rel.stage == 'lover' then return 0 end
    if rel and SC.StageAtLeast(rel.stage, 'friend') then price = math.floor(price * (S.FriendDiscount or 1.0)) end
    return math.max(0, price)
end

-- Belirti -> tavsiye cümleleri (sağlıkçı mı değil mi)
function Jobs.HealthAdvice(norm, isMedic)
    for _, h in ipairs(J.Health or {}) do
        for _, w in ipairs(h.words or {}) do
            if norm:find(w, 1, true) then return isMedic and h.medic or h.folk, h.key end
        end
    end
    return nil
end

-- Meslek sorusu: tüm kategorilerde en iyi eşleşme { cat, entry, score }
function Jobs.MatchQA(a, r)
    local best
    local match = SC.Dialogue.MatchPattern
    local mine = r and Jobs.Category(r)
    for _, c in ipairs(J.Categories or {}) do
        for _, q in ipairs(c.qa or {}) do
            local s = 0
            for _, pat in ipairs(q.patterns or {}) do
                local m = match(a.norm, a.tokens, pat, false)
                if m then s = s + (1 + math.min(#pat, 18) / 6) * m end
            end
            -- kendi mesleğindeki sorulara küçük öncelik
            if s > 0 and mine == c then s = s + 0.5 end
            if s > 0 and (not best or s > best.score) then best = { cat = c, entry = q, score = s } end
        end
    end
    return best
end

function Jobs.Tip(r)
    local c = Jobs.Category(r)
    if not c or not c.tips or #c.tips == 0 then return nil end
    return c.tips[math.random(#c.tips)]
end

function Jobs.Story(r)
    local c = Jobs.Category(r)
    if c and c.stories and #c.stories > 0 and math.random() < 0.6 then return c.stories[math.random(#c.stories)] end
    local list = SCDialogue.Stories or {}
    if #list == 0 then return nil end
    return list[math.random(#list)]
end

-- Konuşma paneli öneri düğmeleri için hizmet türü
function Jobs.SuggestKey(r)
    local c = Jobs.Category(r)
    if not c then return nil end
    if c.suggest then return c.suggest end
    return 'default'
end
