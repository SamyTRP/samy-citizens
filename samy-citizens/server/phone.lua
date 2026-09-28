--[[
    TELEFON / SMS
    gksphone v2:
      - NPC -> oyuncu : exports["gksphone"]:SendMessage(npcNumara, oyuncuNumara, mesaj, { skipSIMUsage, saveSenderCopy })
      - oyuncu -> NPC : AddEventHandler("gksphone:messages:messageSent", data) (receiverNumber bir sakine aitse)
    Her gelen mesaja bir cevap zamanı atanır: müsaitse birkaç saniye, işteyse/konuşuyorsa biraz daha geç,
    uyuyorsa uykulu bir cevap (Config.Phone.SleepMode). Yerleşik telefonda cevap öncesi "yazıyor..." görünür.
    Yakın arkadaş NPC ara sıra kendiliğinden yazar (günde en fazla Config.Phone.ProactivePerDay).
    Provider = 'builtin' ise yerleşik mini mesajlaşma arayüzü kullanılır.
]]
local Utils = SC.Utils
local Clock = SC.Clock
local Sim = SC.Sim

local Phone = {}
SC.Phone = Phone

Phone.byNumber = {}
local pending = {}
local smsCount = {}
local closeFriendsCache = {}

local function norm(num)
    return (tostring(num or ''):gsub('%D', ''))
end
Phone.Normalize = norm

function Phone.Enabled()
    local p = Config.Phone.Provider
    if p == 'gksphone' then return GetResourceState('gksphone') == 'started' end
    return p == 'builtin'
end

function Phone.Rebuild()
    Phone.byNumber = {}
    for _, r in ipairs(Sim.List) do
        if r.phone_number and r.phone_number ~= '' then Phone.byNumber[norm(r.phone_number)] = r.id end
    end
end

function Phone.GetPlayerNumber(src)
    if Config.Phone.Provider == 'gksphone' and GetResourceState('gksphone') == 'started' then
        local ok, num = pcall(function() return exports.gksphone:GetPhoneBySource(src) end)
        if ok and num and tostring(num) ~= '' then return tostring(num) end
    end
    local ci = SC.Bridge.GetCharInfo(src)
    if ci and ci.phone then return tostring(ci.phone) end
    if Config.Phone.Provider == 'builtin' then return 'builtin' end
    return nil
end

local function storeMessage(npcId, cid, phone, direction, body, status)
    MySQL.insert([[INSERT INTO samy_citizens_messages (npc_id, citizenid, player_phone, direction, body, status, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)]], { npcId, cid, phone or '', direction, body, status or 'sent', os.time() })
end

-- ---------------------------------------------------------------------
-- Gönderim (NPC -> oyuncu)
-- ---------------------------------------------------------------------
function Phone.SendToPlayer(r, cid, playerPhone, text, src, extra)
    if not Phone.Enabled() or not text or text == '' then return false end
    storeMessage(r.id, cid, playerPhone, 'out', text, 'sent')
    SC.Log.Conversation(r.id, cid, nil, 'sms', 'npc', text)
    local provider = Config.Phone.Provider
    if provider == 'gksphone' then
        if not playerPhone or playerPhone == '' or not r.phone_number then return false end
        local ok, res = pcall(function()
            return exports.gksphone:SendMessage(r.phone_number, playerPhone, text, { skipSIMUsage = true, saveSenderCopy = false })
        end)
        if not ok or (type(res) == 'table' and res.status == false) then
            SC.DebugPrint('gksphone SendMessage hatası:', ok and tostring(res and res.error) or tostring(res))
            return false
        end
        return true
    elseif provider == 'builtin' then
        local target = src or SC.Bridge.GetSourceByCitizenId(cid)
        if target then
            local payload = {
                npcId = r.id, name = r.firstname .. ' ' .. r.lastname, number = r.phone_number,
                text = text, at = os.time(), direction = 'in',
            }
            for k, v in pairs(extra or {}) do payload[k] = v end
            TriggerClientEvent('samy-citizens:client:phoneMessage', target, payload)
        end
        return true
    end
    return false
end

function Phone.SendLocation(r, cid, playerPhone, loc, src)
    if Config.Phone.Provider == 'gksphone' then
        if not playerPhone or not r.phone_number then return end
        pcall(function()
            exports.gksphone:SendMessage(r.phone_number, playerPhone, vector2(loc.door.x, loc.door.y), { skipSIMUsage = true, saveSenderCopy = false })
        end)
        storeMessage(r.id, cid, playerPhone, 'out', L('sms_location', loc.label), 'sent')
    else
        Phone.SendToPlayer(r, cid, playerPhone, L('sms_location', loc.label), src, { location = { x = loc.door.x, y = loc.door.y, label = loc.label } })
    end
end

function Phone.SendIntro(r, cid, src, rel)
    local phone = rel.player_phone or Phone.GetPlayerNumber(src)
    if not phone then return end
    rel.player_phone = phone
    local line = SC.Actions.PickLine('sms_intro'):gsub('%%name%%', r.firstname)
    SetTimeout(4000, function() Phone.SendToPlayer(r, cid, phone, line, src) end)
end

-- ---------------------------------------------------------------------
-- Gelen mesaj (oyuncu -> NPC)
-- ---------------------------------------------------------------------
local function dailySmsOk(cid)
    local today = Clock.RealDateKey()
    local e = smsCount[cid]
    if not e or e.date ~= today then
        e = { date = today, n = 0 }
        smsCount[cid] = e
    end
    if e.n >= (Config.RateLimit.SmsPerDay or 40) then return false end
    e.n = e.n + 1
    return true
end

function Phone.OnIncoming(npcId, src, playerPhone, text)
    local r = Sim.Residents[npcId]
    if not r or not r.enabled then return end
    local cid = SC.Bridge.GetCitizenId(src)
    if not cid then return end
    text = Utils.SanitizeText(text, Config.RateLimit.MaxChars or 300)
    if text == '' then return end
    storeMessage(npcId, cid, playerPhone, 'in', text, 'pending')
    SC.Log.Conversation(npcId, cid, nil, 'sms', 'player', text)
    if not dailySmsOk(cid) then return end
    if SC.Convo.IsSevere(text) then
        SC.Log.Event(L('log_harassment_title'), ('SMS %s -> %s: %s'):format(cid, npcId, text))
        MySQL.update([[UPDATE samy_citizens_messages SET status = 'ignored' WHERE npc_id = ? AND citizenid = ? AND status = 'pending']], { npcId, cid })
        SC.World.ApplyEvent(r, cid, 'harassment', L('mem_harassment_sms'))
        return
    end
    if r.status == 'dead' then return end
    local key = npcId .. '|' .. cid
    local p = pending[key]
    local nowMs = GetGameTimer()
    if not p then
        p = { npcId = npcId, cid = cid, msgs = {}, firstAt = os.time(), firstMs = nowMs }
        pending[key] = p
        Phone.Schedule(r, p, text)
    elseif p.replyAt then
        -- art arda gelen mesajları da okur; toplam gecikme sınırlı kalır
        local cap = p.firstMs + (Config.Phone.MaxReplyDelaySec or 90) * 1000
        p.replyAt = math.min(math.max(p.replyAt, nowMs + 2500), math.max(cap, nowMs + 2500))
        p.typingSent = nil
    end
    p.src = src
    p.phone = playerPhone
    p.msgs[#p.msgs + 1] = text
    while #p.msgs > (Config.Phone.MaxPendingPerThread or 5) do table.remove(p.msgs, 1) end
end

AddEventHandler('gksphone:messages:messageSent', function(data)
    if Config.Phone.Provider ~= 'gksphone' or type(data) ~= 'table' then return end
    if data.receiverSource then return end
    local rid = Phone.byNumber[norm(data.receiverNumber)]
    if not rid then return end
    local src = tonumber(data.senderSource)
    if not src or src <= 0 then return end
    local msg = data.message
    if type(msg) ~= 'string' then msg = L('sms_location_shared') end
    Phone.OnIncoming(rid, src, tostring(data.senderNumber or ''), msg)
end)

-- ---------------------------------------------------------------------
-- Cevaplama
-- ---------------------------------------------------------------------
-- 'free' | 'busy' | 'talking' | 'sleep' | 'hostage' | 'never'
local function availability(r)
    if r.status == 'hospital' then return 'free' end
    if r.status ~= 'alive' then return 'never' end
    if r.override and r.override.type == 'hostage' then return 'hostage' end
    if r.convo then return 'talking' end
    local act = r.state.activity
    if act == 'sleep' then return 'sleep' end
    local def = SC.Activities[act]
    if def and def.busy then return 'busy' end
    return 'free'
end
Phone.Availability = availability

local function randRange(t, def)
    t = type(t) == 'table' and t or def
    local a, b = t[1] or 0, t[2] or t[1] or 0
    return a + math.random() * math.max(0, b - a)
end

-- Cevap gecikmesi (ms): müsaitlik + okuma süresi; arkadaşlara daha çabuk döner
local function replyDelayMs(r, cid, text, av)
    local P = Config.Phone
    local sec
    if av == 'sleep' then
        sec = randRange(P.SleepDelaySec, { 25, 70 })
    elseif av == 'talking' then
        sec = randRange(P.TalkingDelaySec, { 15, 45 })
    elseif av == 'busy' then
        sec = randRange(P.BusyDelaySec, { 12, 40 })
    else
        sec = randRange(P.ReplyDelaySec, { 3, 8 })
    end
    sec = sec + math.min(6, Utils.Utf8Len(text or '') / 30)
    local rel = SC.Rel.Peek(r.id, cid)
    if rel and SC.StageAtLeast(rel.stage, 'friend') then sec = sec * (P.FriendDelayFactor or 0.6) end
    return math.floor(sec * 1000)
end

local function mustWait(av)
    if av == 'hostage' then return true end
    return av == 'sleep' and (Config.Phone.SleepMode or 'wake') ~= 'wake'
end

-- Bekleyen konuşmaya cevap zamanı ata (ya da sakin uyanana / serbest kalana kadar beklet)
function Phone.Schedule(r, p, text)
    local av = availability(r)
    p.sleepy = av == 'sleep'
    p.typingSent = nil
    if mustWait(av) then
        p.waiting = true
        p.replyAt = nil
    else
        p.waiting = nil
        p.replyAt = GetGameTimer() + replyDelayMs(r, p.cid, text or table.concat(p.msgs or {}, ' '), av)
    end
end


-- SMS'te yarım kalan konuşma durumu (bekleyen soru, buluşma slotları) — Config.Phone.ThreadMemoryMinutes kadar
local threads = {}

local function threadState(key)
    local now = os.time()
    local ttl = (Config.Phone.ThreadMemoryMinutes or 30) * 60
    local t = threads[key]
    if not t or now - (t.at or 0) > ttl then
        t = { topics = {}, asked = {}, playerMsgs = 0, greeted = false }
        threads[key] = t
    end
    t.at = now
    return t
end

function Phone.Reply(r, p)
    local rel = SC.Rel.Get(r.id, p.cid)
    local src = SC.Bridge.GetSourceByCitizenId(p.cid) or p.src
    if p.phone and p.phone ~= '' then
        rel.player_phone = p.phone
        SC.Rel.MarkDirty(rel)
    end
    local ci = src and SC.Bridge.GetCharInfo(src) or nil
    local playerFirst = ci and ci.firstname or nil
    local text = table.concat(p.msgs, '. ')
    local phone = rel.player_phone or p.phone
    local reply, results

    if not rel.phone_known then
        -- NPC bu numarayı tanımıyor: yüz yüze tanıştığı biri (tanıdık+) kendini tanıtırsa numarayı kaydeder
        local name = SC.Dialogue.ExtractName(text)
        local mentionsSelf = playerFirst and ((name and Utils.Fold(name) == Utils.Fold(playerFirst)) or Utils.ContainsPhrase(text, playerFirst))
        if rel.name_known and SC.StageAtLeast(rel.stage, 'acquaintance') and mentionsSelf then
            rel.phone_known = true
            SC.Rel.MarkDirty(rel)
            reply = SC.Dialogue.Line('sms_recognized', r, rel)
        else
            reply = SC.Dialogue.Line('sms_unknown', r, rel)
        end
    else
        local c = threadState(r.id .. '|' .. p.cid)
        c.playerMsgs = c.playerMsgs + 1
        local res = SC.Dialogue.Respond({ r = r, rel = rel, c = c, cid = p.cid, channel = 'sms', playerFirst = playerFirst }, text)
        reply = res.reply
        SC.Dialogue.ApplyRelUpdates(rel, res.rel)
        SC.Rel.ApplyDelta(rel, res.dAff, res.dTrust)
        SC.Rel.AddFamiliarity(rel, 1)
        for _, m in ipairs(res.memories or {}) do
            SC.Memory.Add(r.id, p.cid, m.text, m.importance or 3, m.type or 'conversation', {
                valence = m.valence or 0, shareable = m.shareable == true, data = m.data,
            })
        end
        if res.event then
            local who = SC.Dialogue.PlayerAddress(rel)
            SC.World.ApplyEvent(r, p.cid, res.event, L('mem_' .. res.event, who ~= '' and who or L('ctx_someone')))
        end
        results = SC.Actions.Execute({
            r = r, src = src, citizenid = p.cid, rel = rel, channel = 'sms', charName = rel.char_name,
        }, res)
    end

    if p.sleepy and rel.phone_known then
        reply = SC.Dialogue.Line('sms_sleepy', r, rel) .. ' ' .. reply
    end
    reply = SC.Dialogue.SmsStyle(reply, r, rel)
    -- uzun cevaplar bazen iki ayrı mesaj olarak gelir (insanlar böyle yazar)
    local first, second = reply:match('^(.-[%.!%?]+)%s+(.+)$')
    if Config.Phone.SplitLongReplies ~= false and first and Utils.Utf8Len(reply) > 55 and math.random() < 0.45 then
        Phone.SendToPlayer(r, p.cid, phone, SC.Dialogue.SmsStyle(first, r, rel), src)
        if src and Config.Phone.Provider == 'builtin' then TriggerClientEvent('samy-citizens:client:phoneTyping', src, r.id, true) end
        SetTimeout(1500 + math.random(0, 2000), function()
            Phone.SendToPlayer(r, p.cid, phone, SC.Dialogue.SmsStyle(second, r, rel), src)
        end)
    else
        Phone.SendToPlayer(r, p.cid, phone, reply, src)
    end
    if results and results.smsLocation then Phone.SendLocation(r, p.cid, phone, results.smsLocation, src) end
    MySQL.update([[UPDATE samy_citizens_messages SET status = 'replied'
        WHERE npc_id = ? AND citizenid = ? AND direction = 'in' AND status = 'pending']], { r.id, p.cid })
    Sim.MarkInteracted(r)
    local who = SC.Dialogue.PlayerAddress(rel)
    Sim.AddLog(r, Clock.Now(), 'event', { text = L('log_sms', who ~= '' and who or L('ctx_unknown_number')) })
end

-- Yakın arkadaşın kendiliğinden mesajı (şablon)
function Phone.TryProactive(r)
    local cache = closeFriendsCache[r.id]
    if not cache or os.time() - cache.at > 300 then
        cache = { list = SC.Rel.CloseFriendsWithPhone(r.id), at = os.time() }
        closeFriendsCache[r.id] = cache
    end
    local today = Clock.RealDateKey()
    local candidates = {}
    for _, rel in ipairs(cache.list) do
        if rel.proactive_date ~= today then
            rel.proactive_date = today
            rel.proactive_count = 0
        end
        if rel.proactive_count < (Config.Phone.ProactivePerDay or 1) and rel.player_phone then
            local src = SC.Bridge.GetSourceByCitizenId(rel.citizenid)
            if src then candidates[#candidates + 1] = { rel = rel, src = src } end
        end
    end
    if #candidates == 0 then return end
    local pick = candidates[math.random(#candidates)]
    local rel = pick.rel
    local text = SC.Actions.PickLine(rel.stage == 'lover' and 'sms_proactive_lover' or 'sms_proactive'):gsub('%%place%%', Sim.LocationLabel(r.state.locationId or r.state.toLocationId))
    rel.proactive_count = rel.proactive_count + 1
    SC.Rel.MarkDirty(rel)
    Phone.SendToPlayer(r, rel.citizenid, rel.player_phone, text, pick.src)
end

local lastProactive = 0
local PROACTIVE_EVERY = 8

function Phone.Tick()
    if not Phone.Enabled() then return end
    local nowMs = GetGameTimer()
    for key, p in pairs(pending) do
        local r = Sim.Residents[p.npcId]
        if not r then
            pending[key] = nil
        else
            local av = availability(r)
            if av == 'never' then
                pending[key] = nil
            elseif p.waiting then
                -- uyandı / serbest kaldı: şimdi okuyup cevaplar
                if not mustWait(av) then Phone.Schedule(r, p) end
            elseif av == 'hostage' then
                p.waiting = true
                p.replyAt = nil
            elseif nowMs >= (p.replyAt or 0) then
                pending[key] = nil
                CreateThread(function()
                    local ok, err = pcall(Phone.Reply, r, p)
                    if not ok then print(('^1[samy-citizens] SMS cevap hatası: %s^7'):format(tostring(err))) end
                end)
            elseif not p.typingSent and p.replyAt - nowMs <= 3000 and Config.Phone.Provider == 'builtin' then
                p.typingSent = true
                local src = SC.Bridge.GetSourceByCitizenId(p.cid) or p.src
                if src then TriggerClientEvent('samy-citizens:client:phoneTyping', src, r.id, true) end
            end
        end
    end

    local now = os.time()
    if Config.Phone.ProactiveEnabled and now - lastProactive >= PROACTIVE_EVERY then
        lastProactive = now
        local tickSec = PROACTIVE_EVERY
        local hourSec = Clock.GameMinutesToRealSeconds(60)
        local chance = (Config.Phone.ProactiveChancePerHour or 0.1) * tickSec / math.max(1, hourSec)
        for _, r in ipairs(Sim.List) do
            if r.enabled and r.status == 'alive' and availability(r) == 'free' and math.random() < chance then
                CreateThread(function()
                    local ok, err = pcall(Phone.TryProactive, r)
                    if not ok then SC.DebugPrint('proaktif SMS hatası', tostring(err)) end
                end)
            end
        end
    end
end

-- ---------------------------------------------------------------------
-- Yerleşik (builtin) mini mesajlaşma
-- ---------------------------------------------------------------------
lib.callback.register('samy-citizens:phone:contacts', function(src)
    if Config.Phone.Provider ~= 'builtin' then return false end
    local cid = SC.Bridge.GetCitizenId(src)
    if not cid then return {} end
    local rels = SC.Rel.ListForCitizen(cid)
    local out = {}
    for _, rel in ipairs(rels) do
        local r = Sim.Residents[rel.npc_id]
        if r and rel.phone_known then
            local last = MySQL.single.await([[SELECT body, created_at FROM samy_citizens_messages WHERE npc_id = ? AND citizenid = ?
                ORDER BY id DESC LIMIT 1]], { r.id, cid })
            out[#out + 1] = {
                npcId = r.id, name = r.firstname .. ' ' .. r.lastname, number = r.phone_number,
                lastText = last and last.body or '', lastAt = last and tonumber(last.created_at) or 0,
            }
        end
    end
    table.sort(out, function(a, b) return a.lastAt > b.lastAt end)
    return out
end)

lib.callback.register('samy-citizens:phone:thread', function(src, npcId)
    if Config.Phone.Provider ~= 'builtin' or type(npcId) ~= 'string' then return false end
    local cid = SC.Bridge.GetCitizenId(src)
    if not cid then return {} end
    local rows = MySQL.query.await([[SELECT direction, body, created_at FROM samy_citizens_messages
        WHERE npc_id = ? AND citizenid = ? ORDER BY id DESC LIMIT 40]], { npcId, cid }) or {}
    local out = {}
    for i = #rows, 1, -1 do
        out[#out + 1] = { direction = rows[i].direction, text = rows[i].body, at = tonumber(rows[i].created_at) }
    end
    return out
end)

RegisterNetEvent('samy-citizens:server:phoneSend', function(npcId, text)
    local src = source
    if Config.Phone.Provider ~= 'builtin' or type(npcId) ~= 'string' or type(text) ~= 'string' then return end
    local r = Sim.Residents[npcId]
    local cid = SC.Bridge.GetCitizenId(src)
    if not r or not cid then return end
    CreateThread(function()
        local rel = SC.Rel.Get(r.id, cid)
        if not rel.phone_known then return end
        Phone.OnIncoming(npcId, src, rel.player_phone or Phone.GetPlayerNumber(src), text)
    end)
end)
