--[[
    KONUŞMA SİSTEMİ (yüz yüze, yapay zekâsız)
    ox_target "Konuş" -> sunucu doğrular (mesafe, durum) -> NPC durur, oyuncuya döner -> NUI paneli
    Her oyuncu mesajı: hız sınırı + küfür filtresi -> diyalog motoru (niyet + şablon) -> ilişki/anı/aksiyon
]]
local Utils = SC.Utils
local Clock = SC.Clock
local Sim = SC.Sim
local Spawner = SC.Spawner

local Convo = {}
SC.Convo = Convo

Convo.bySrc = {}
local rate = {}

-- ---------------------------------------------------------------------
-- Baloncuklar
-- ---------------------------------------------------------------------
function Convo.Bubble(r, text, kind, duration)
    local phys = Spawner.peds[r.id]
    if not phys or not DoesEntityExist(phys.ped) then return end
    local pc = GetEntityCoords(phys.ped)
    local maxD = Config.Conversation.BubbleDistance or 20.0
    for _, p in ipairs(Spawner.Players()) do
        if Utils.Dist(p.coords, pc) <= maxD then
            TriggerClientEvent('samy-citizens:client:bubble', p.src, {
                net = phys.netId, text = text, kind = kind or 'npc', duration = duration or Config.Conversation.BubbleDurationMs,
            })
        end
    end
end

function Convo.PlayerBubble(src, text)
    local pped = GetPlayerPed(src)
    if not pped or pped == 0 then return end
    local pc = GetEntityCoords(pped)
    local maxD = Config.Conversation.BubbleDistance or 20.0
    for _, p in ipairs(Spawner.Players()) do
        if Utils.Dist(p.coords, pc) <= maxD then
            TriggerClientEvent('samy-citizens:client:bubble', p.src, {
                player = src, text = text, kind = 'player', duration = Config.Conversation.BubbleDurationMs,
            })
        end
    end
end

-- ---------------------------------------------------------------------
-- Yardımcılar
-- ---------------------------------------------------------------------
local function checkRate(cid)
    local now = os.time()
    local e = rate[cid]
    if not e then
        e = { stamps = {}, date = '', count = 0 }
        rate[cid] = e
    end
    local today = Clock.RealDateKey()
    if e.date ~= today then
        e.date = today
        e.count = 0
    end
    for i = #e.stamps, 1, -1 do
        if now - e.stamps[i] >= 60 then table.remove(e.stamps, i) end
    end
    if #e.stamps >= (Config.RateLimit.PerMinute or 12) then return false, 'minute' end
    if e.count >= (Config.RateLimit.PerDay or 400) then return false, 'day' end
    e.stamps[#e.stamps + 1] = now
    e.count = e.count + 1
    return true
end
Convo.CheckRate = checkRate

function Convo.IsSevere(text)
    if not Config.Moderation.Enabled then return false end
    for _, w in ipairs(Config.Moderation.SevereWords or {}) do
        if Utils.ContainsPhrase(text, w) then return true end
    end
    return false
end

function Convo.DisplayName(r, rel)
    if rel and (rel.npc_name_shown or SC.StageAtLeast(rel.stage, 'acquaintance')) then
        return r.firstname .. ' ' .. r.lastname
    end
    return L('npc_unknown_name')
end

local function subtitle(r, rel)
    local st = r.state
    if st.activity == 'work' or st.activity == 'deliver' or st.activity == 'study' then
        return r.job.title or ''
    end
    if rel and SC.StageAtLeast(rel.stage, 'acquaintance') then return r.job.title or '' end
    return ''
end

-- Diyalog motoru bağlamı (konuşma tablosunun kendisi motorun durum tablosudur: expect, meet, topics...)
local function dialogueCtx(r, c)
    return {
        r = r, rel = c.rel, c = c, cid = c.citizenid, channel = 'talk',
        playerFirst = c.charInfo and c.charInfo.firstname or nil,
    }
end

local function clientPayload(r, c, text, emotion, extra)
    local rel = c.rel
    local p = {
        text = text,
        emotion = emotion or 'neutral',
        name = Convo.DisplayName(r, rel),
        nameKnown = (rel.npc_name_shown or SC.StageAtLeast(rel.stage, 'acquaintance')) and true or false,
        subtitle = subtitle(r, rel),
        stage = rel.stage,
        stageLabel = SC.Rel.StageLabel(rel.stage),
        rel = SC.Rel.PublicView(rel),
        mood = Sim.MoodKey(r),
        suggestions = SC.Dialogue.Suggestions(dialogueCtx(r, c)),
        ui = {},
    }
    for k, v in pairs(extra or {}) do p[k] = v end
    return p
end

-- Motorsuz, doğrudan şablon cevap (hediye teşekkürü, taciz vb.)
function Convo.NpcSay(r, c, line, emotion)
    c.history[#c.history + 1] = { role = 'npc', text = line }
    Convo.Bubble(r, line)
    Spawner.SetEmotion(r, emotion or 'neutral')
    SC.Log.Conversation(r.id, c.citizenid, c.charName, 'talk', 'npc', line, { template = true })
    TriggerClientEvent('samy-citizens:client:convoMessage', c.src, clientPayload(r, c, line, emotion))
end

-- ---------------------------------------------------------------------
-- Başlatma / bitirme
-- ---------------------------------------------------------------------
lib.callback.register('samy-citizens:startConversation', function(src, netId)
    if not SC.Ready then return false, L('err_not_ready') end
    local r = Spawner.GetResidentByNet(netId)
    if not r then return false, L('err_not_resident') end
    if r.status ~= 'alive' then return false, L('err_unavailable') end
    local near = Spawner.PlayerNear(src, r, (Config.Conversation.StartDistance or 3.0) + 1.5)
    if not near then return false, L('err_too_far') end
    if r.convo then
        if r.convo.src == src then return false, L('err_already') end
        return false, L('err_npc_busy_talking')
    end
    local hostage = SC.Hostage.Is(r)
    if hostage and r.override.taker ~= src then return false, L('err_npc_hostage') end
    if not hostage and r.override and (r.override.type == 'flee' or r.override.type == 'handsup' or r.override.type == 'cower') then
        return false, L('err_npc_scared')
    end
    local ped = Spawner.GetPed(r)
    if not hostage and not Config.Conversation.AllowWhileDriving and ped and GetVehiclePedIsIn(ped, false) ~= 0 then
        return false, L('err_driving')
    end
    local cid = SC.Bridge.GetCitizenId(src)
    if not cid then return false, L('err_no_char') end

    local prev = Convo.bySrc[src]
    if prev and Sim.Residents[prev] then Convo.End(Sim.Residents[prev], 'switch') end

    local rel = SC.Rel.Get(r.id, cid)
    local charInfo = SC.Bridge.GetCharInfo(src) or { firstname = '?', lastname = '', gender = 'male' }
    local charName = Utils.Trim(('%s %s'):format(charInfo.firstname or '?', charInfo.lastname or ''))

    if rel.stage == 'enemy' and not hostage then
        Convo.Bubble(r, SC.Actions.PickLine('refuse_enemy'))
        Spawner.SetEmotion(r, 'angry')
        Spawner.PlayGesture(r, 'no')
        return false, L('err_npc_refuses')
    end

    -- rehineyle konuşmak bir "görüşme" sayılmaz
    local meetInfo = not hostage and SC.Rel.OnMeet(rel, charName) or nil
    Sim.MarkInteracted(r)
    local c = {
        src = src, citizenid = cid, charName = charName, charInfo = charInfo,
        rel = rel, history = {}, startedAt = GetGameTimer(), startedAbs = Clock.Now(), lastActivity = GetGameTimer(),
        busy = false, meetInfo = meetInfo, playerMsgs = 0, negative = hostage, hostage = hostage,
        place = r.state.locationId or r.state.toLocationId,
    }
    r.convo = c
    Convo.bySrc[src] = r.id
    Spawner.UpdateTask(r)
    Sim.AddLog(r, Clock.Now(), 'event', { text = L('log_talked', rel.name_known and charName or L('ctx_stranger')) })

    local greeting, emotion = SC.Dialogue.Greeting(dialogueCtx(r, c), meetInfo)
    c.history[#c.history + 1] = { role = 'npc', text = greeting }
    Convo.Bubble(r, greeting)
    Spawner.SetEmotion(r, emotion)
    if not hostage then
        Spawner.PlayGesture(r, emotion == 'angry' and 'no' or (SC.StageAtLeast(rel.stage, 'acquaintance') and 'wave' or 'nod'))
    end
    SC.Log.Conversation(r.id, cid, charName, 'talk', 'npc', greeting, { greeting = true })

    return clientPayload(r, c, greeting, emotion, {
        npcId = r.id,
        maxChars = Config.RateLimit.MaxChars,
    })
end)

function Convo.End(r, reason)
    local c = r.convo
    if not c then return end
    r.convo = nil
    if Convo.bySrc[c.src] == r.id then Convo.bySrc[c.src] = nil end
    TriggerClientEvent('samy-citizens:client:convoEnd', c.src, reason)
    local paused = Clock.Now() - (c.startedAbs or Clock.Now())
    if r.state.activity == 'commute' and paused > 0 then
        r.state.startedAt = r.state.startedAt + paused
        r.state.eta = r.state.eta + paused
    end
    SC.Rel.Touch(c.rel)
    -- olumsuzluk olmadan en az 3 mesajlık sohbet ilişkiyi biraz güçlendirir
    if c.playerMsgs >= 3 and not c.negative and not c.hostage then
        local b = Config.Dialogue.GoodConversationBonus or { 2, 1 }
        SC.Rel.ApplyDelta(c.rel, b[1] or 0, b[2] or 0)
    end
    -- konuşma özeti (sonraki "ne konuşmuştuk?" sorusu için)
    if c.playerMsgs >= 1 and not c.hostage then
        local who = c.rel.name_known and c.charName or (c.rel.nickname or L('ctx_someone'))
        local text, data = SC.Dialogue.Summary(r, c, who, c.place)
        SC.Memory.AddAsync(r.id, c.citizenid, text, 3, 'conversation', { data = data })
    end
    SetTimeout(10000, function()
        if not r.convo then Spawner.SetEmotion(r, 'neutral') end
    end)
    Sim.Changed(r, 'convo_end')
end

RegisterNetEvent('samy-citizens:server:endConversation', function()
    local src = source
    local rid = Convo.bySrc[src]
    local r = rid and Sim.Residents[rid]
    if r and r.convo and r.convo.src == src then Convo.End(r, 'player') end
end)

-- ---------------------------------------------------------------------
-- Taciz (ağır küfür)
-- ---------------------------------------------------------------------
function Convo.Harassment(r, c, text)
    SC.Log.Event(L('log_harassment_title'), ('%s (%s) -> %s: %s'):format(c.charName, c.citizenid, r.id, text))
    SC.Log.Conversation(r.id, c.citizenid, c.charName, 'talk', 'player', text, { flagged = true })
    Convo.NpcSay(r, c, SC.Actions.PickLine('harassment_reply'), 'angry')
    Spawner.PlayGesture(r, 'no')
    c.negative = true
    SC.World.ApplyEvent(r, c.citizenid, 'harassment', L('mem_harassment', c.rel.name_known and c.charName or L('ctx_someone')))
    SetTimeout(2500, function()
        if r.convo == c then Convo.End(r, 'harassment') end
    end)
end

-- ---------------------------------------------------------------------
-- Mesaj akışı
-- ---------------------------------------------------------------------
function Convo.HandlePlayerText(src, text)
    local rid = Convo.bySrc[src]
    if not rid then return end
    local r = Sim.Residents[rid]
    local c = r and r.convo
    if not c or c.src ~= src then return end
    if c.busy then
        TriggerClientEvent('samy-citizens:client:convoError', src, L('err_wait_reply'))
        return
    end
    if not Spawner.PlayerNear(src, r, (Config.Conversation.MaxDistance or 5.0) + 1.0) then
        Convo.End(r, 'distance')
        return
    end
    text = Utils.SanitizeText(text, Config.RateLimit.MaxChars or 300)
    if text == '' then return end
    local ok, why = checkRate(c.citizenid)
    if not ok then
        if why == 'minute' then
            TriggerClientEvent('samy-citizens:client:convoError', src, L('err_rate_minute'))
            return
        end
        Convo.NpcSay(r, c, SC.Actions.PickLine('fallback_daily_limit'), 'neutral')
        SetTimeout(3000, function() if r.convo == c then Convo.End(r, 'limit') end end)
        return
    end
    c.lastActivity = GetGameTimer()
    c.playerMsgs = c.playerMsgs + 1
    if Convo.IsSevere(text) then
        Convo.Harassment(r, c, text)
        return
    end
    -- oyuncu kendi karakter adını söylediyse NPC adını öğrenir
    local rel = c.rel
    if not rel.name_known and c.charInfo.firstname and c.charInfo.firstname ~= '?' and Utils.ContainsPhrase(text, c.charInfo.firstname) then
        rel.name_known = true
        SC.Rel.MarkDirty(rel)
    end
    c.busy = true
    c.history[#c.history + 1] = { role = 'player', text = text }
    while #c.history > 30 do table.remove(c.history, 1) end
    SC.Log.Conversation(r.id, c.citizenid, c.charName, 'talk', 'player', text)
    if Config.Conversation.ShowPlayerBubble then Convo.PlayerBubble(src, text) end

    local res = SC.Dialogue.Respond(dialogueCtx(r, c), text)
    local tmin = Config.Dialogue.TypingDelayMs and Config.Dialogue.TypingDelayMs[1] or 600
    local tmax = Config.Dialogue.TypingDelayMs and Config.Dialogue.TypingDelayMs[2] or 2200
    local delay = Utils.Clamp(tmin + Utils.Utf8Len(res.reply) * 22 + math.random(0, 300), tmin, tmax)
    Convo.Bubble(r, '...', 'thinking', delay + 300)
    TriggerClientEvent('samy-citizens:client:convoThinking', src, true)
    SetTimeout(delay, function()
        if r.convo ~= c then return end
        local okA, err = pcall(Convo.ApplyTurn, r, c, res)
        if not okA then
            print(('^1[samy-citizens] konuşma hatası: %s^7'):format(tostring(err)))
            c.busy = false
        end
    end)
end

RegisterNetEvent('samy-citizens:server:say', function(text)
    if type(text) ~= 'string' then return end
    Convo.HandlePlayerText(source, text)
end)

function Convo.ApplyTurn(r, c, res)
    local rel = c.rel
    SC.Dialogue.ApplyRelUpdates(rel, res.rel)
    local oldStage = rel.stage
    SC.Rel.ApplyDelta(rel, res.dAff, res.dTrust)
    SC.Rel.AddFamiliarity(rel, Config.Relationship.FamiliarityPerMessage or 1)
    if (res.dAff or 0) < 0 then c.negative = true end
    local stageChanged = rel.stage ~= oldStage

    for _, m in ipairs(res.memories or {}) do
        SC.Memory.AddAsync(r.id, c.citizenid, m.text, m.importance or 3, m.type or 'conversation', {
            valence = m.valence or 0, shareable = m.shareable == true, data = m.data,
        })
    end
    if res.event then
        local who = SC.Dialogue.PlayerAddress(rel)
        SC.World.ApplyEvent(r, c.citizenid, res.event, L('mem_' .. res.event, who ~= '' and who or L('ctx_someone')))
    end

    local results = SC.Actions.Execute({
        r = r, src = c.src, citizenid = c.citizenid, rel = rel, channel = 'talk', charName = c.charName,
    }, res)

    c.history[#c.history + 1] = { role = 'npc', text = res.reply }
    local actionTypes = {}
    for _, a in ipairs(res.actions or {}) do actionTypes[#actionTypes + 1] = a.type end
    SC.Log.Conversation(r.id, c.citizenid, c.charName, 'talk', 'npc', res.reply, {
        intent = res.intent, emotion = res.emotion, actions = actionTypes, dAff = res.dAff, dTrust = res.dTrust,
    })

    Convo.Bubble(r, res.reply)
    Spawner.SetEmotion(r, res.emotion)
    if not c.hostage then Spawner.PlayGesture(r, res.animation ~= 'none' and res.animation or 'talk') end
    c.busy = false
    c.lastActivity = GetGameTimer()
    TriggerClientEvent('samy-citizens:client:convoMessage', c.src, clientPayload(r, c, res.reply, res.emotion, {
        stageChanged = stageChanged and SC.Rel.StageLabel(rel.stage) or nil,
        ui = results.ui,
    }))

    if results.flee then
        local pped = GetPlayerPed(c.src)
        local from = (pped and pped ~= 0) and GetEntityCoords(pped) or (Spawner.GetPedCoords(r) or vector3(0.0, 0.0, 0.0))
        local src = c.src
        Convo.End(r, 'flee')
        SC.World.Flee(r, from, src)
    elseif results.follow then
        local src, minutes = c.src, results.follow
        Convo.End(r, 'follow')
        Sim.SetOverride(r, { type = 'follow', target = src, untilMs = GetGameTimer() + minutes * 60000 })
    elseif results.endConversation then
        SetTimeout(3500, function()
            if r.convo == c then Convo.End(r, 'npc') end
        end)
    end
end

-- ---------------------------------------------------------------------
-- Tick: mesafe / bekleme süresi
-- ---------------------------------------------------------------------
function Convo.Tick()
    local timer = GetGameTimer()
    for src, rid in pairs(Convo.bySrc) do
        local r = Sim.Residents[rid]
        local c = r and r.convo
        if not c or c.src ~= src then
            Convo.bySrc[src] = nil
        elseif not GetPlayerName(src) then
            Convo.End(r, 'dropped')
        elseif not Spawner.GetPed(r) then
            Convo.End(r, 'despawn')
        elseif not Spawner.PlayerNear(src, r, Config.Conversation.MaxDistance or 5.0) then
            Convo.End(r, 'distance')
        elseif not c.busy and timer - c.lastActivity > (Config.Conversation.IdleTimeoutSec or 150) * 1000 then
            Convo.End(r, 'idle')
        end
    end
end

function Convo.OnPlayerLeft(src)
    local rid = Convo.bySrc[src]
    local r = rid and Sim.Residents[rid]
    if r and r.convo then Convo.End(r, 'dropped') end
    Convo.bySrc[src] = nil
end

-- ---------------------------------------------------------------------
-- Yoldan geçerken selam (tanıdık/arkadaş sakinler)
-- ---------------------------------------------------------------------
local ambientLast = {}
local cidCache = {}
local preloadAt = {}

local function cidFor(src)
    local e = cidCache[src]
    local now = os.time()
    if e and now - e.at < 120 then return e.cid end
    local cid = SC.Bridge.GetCitizenId(src)
    cidCache[src] = { cid = cid, at = now }
    if cid and (not preloadAt[cid] or now - preloadAt[cid] > 600) then
        preloadAt[cid] = now
        CreateThread(function() SC.Rel.Preload(cid) end)
    end
    return cid
end

function Convo.AmbientTick()
    if not Config.Conversation.AmbientGreetings then return end
    local players = Spawner.Players()
    if #players == 0 then return end
    local now = os.time()
    local maxD = Config.Conversation.AmbientDistance or 6.0
    local cooldown = Config.Conversation.AmbientCooldownSec or 300
    for rid, phys in pairs(Spawner.peds) do
        local r = Sim.Residents[rid]
        if r and not r.convo and not r.override and r.status == 'alive' and phys.coords and not phys.deadAt
            and r.state.activity ~= 'commute' then
            for _, p in ipairs(players) do
                if Utils.Dist(p.coords, phys.coords) <= maxD and not Convo.bySrc[p.src] then
                    local cid = cidFor(p.src)
                    local rel = cid and SC.Rel.Peek(r.id, cid)
                    local kidnappedAt = rel and rel.facts and tonumber(rel.facts.kidnapped_at)
                    local recognizeSec = ((Config.Hostage and Config.Hostage.RecognizeDays) or 7) * 86400
                    if kidnappedAt and os.time() - kidnappedAt < recognizeSec then
                        -- kendisini rehin alan kişiyi tanıdı: bağırır, kaçar, polisi arar
                        local k = 'kid|' .. r.id .. '|' .. cid
                        if not ambientLast[k] or now - ambientLast[k] > 120 then
                            ambientLast[k] = now
                            Convo.Bubble(r, SC.Dialogue.Line('hostage_recognize', r, rel), 'npc', 4500)
                            SC.World.Flee(r, p.coords, p.src)
                            SC.World.CallPolice(r, L('police_reason_kidnapper'), p.src)
                        end
                    elseif rel and (SC.StageAtLeast(rel.stage, 'acquaintance') or (SC.StageOrder[rel.stage] or 0) < 0) then
                        local k = r.id .. '|' .. cid
                        if not ambientLast[k] or now - ambientLast[k] > cooldown then
                            ambientLast[k] = now
                            local line = SC.Dialogue.Ambient(r, rel)
                            if line then Convo.Bubble(r, line, 'npc', 4000) end
                            local cold = (SC.StageOrder[rel.stage] or 0) < 0
                            Spawner.SetEmotion(r, cold and 'angry' or 'happy')
                            Spawner.PlayGesture(r, cold and 'no' or 'wave')
                        end
                    end
                end
            end
        end
    end
end

AddEventHandler('playerDropped', function()
    cidCache[source] = nil
end)

-- ---------------------------------------------------------------------
-- Hediye (ox_inventory)
-- ---------------------------------------------------------------------
local function giftingAvailable()
    return Config.Gifts.Enabled and GetResourceState('ox_inventory') == 'started'
end

lib.callback.register('samy-citizens:getGiftItems', function(src, netId)
    if not giftingAvailable() then return false end
    local r = Spawner.GetResidentByNet(netId)
    if not r or r.status ~= 'alive' then return false end
    if not Spawner.PlayerNear(src, r, 4.0) then return false end
    local items = exports.ox_inventory:GetInventoryItems(src) or {}
    local out, seen = {}, {}
    for _, it in pairs(items) do
        if type(it) == 'table' and it.name and (it.count or 0) > 0 and not seen[it.name]
            and (Config.Gifts.AllowAnyItem or Config.Gifts.Items[it.name]) then
            seen[it.name] = true
            out[#out + 1] = { name = it.name, label = it.label or it.name, count = it.count }
        end
    end
    return out
end)

lib.callback.register('samy-citizens:giveGift', function(src, netId, itemName)
    if not giftingAvailable() or type(itemName) ~= 'string' then return false end
    if not Config.Gifts.AllowAnyItem and not Config.Gifts.Items[itemName] then return false end
    local r = Spawner.GetResidentByNet(netId)
    if not r or r.status ~= 'alive' then return false end
    if not Spawner.PlayerNear(src, r, 4.0) then return false end
    local cid = SC.Bridge.GetCitizenId(src)
    if not cid then return false end
    local rel = SC.Rel.Get(r.id, cid)
    if rel.stage == 'enemy' then return false end
    if not exports.ox_inventory:RemoveItem(src, itemName, 1) then return false end
    local itemData = exports.ox_inventory:Items(itemName)
    local label = itemData and itemData.label or itemName
    local ci = SC.Bridge.GetCharInfo(src) or { firstname = '?', lastname = '' }
    local charName = Utils.Trim(('%s %s'):format(ci.firstname or '?', ci.lastname or ''))

    local value = Config.Gifts.Items[itemName] or Config.Gifts.DefaultValue
    if rel.daily_gifts < (Config.Gifts.DailyBonusPerResident or 1) then
        rel.daily_gifts = rel.daily_gifts + 1
        SC.Rel.ApplyDelta(rel, value.affinity or 0, value.trust or 0, { bypassCap = true })
    end
    SC.Rel.Touch(rel)
    SC.World.ApplyEvent(r, cid, 'gift', L('mem_gift', rel.name_known and charName or L('ctx_someone'), label), { item = label })
    Spawner.PlayGesture(r, 'thanks')
    Spawner.SetEmotion(r, 'happy')
    local line = SC.Actions.PickLine('gift_thanks'):gsub('%%item%%', label)
    if r.convo and r.convo.src == src then
        local c = r.convo
        c.history[#c.history + 1] = { role = 'player', text = L('history_gift', label) }
        Convo.NpcSay(r, c, line, 'happy')
    else
        Convo.Bubble(r, line)
    end
    return true
end)
