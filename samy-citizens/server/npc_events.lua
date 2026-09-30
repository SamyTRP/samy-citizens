--[[
    NPC OLAYLARI ve KENDİLİĞİNDEN İLETİŞİM (spam korumalı)
    1) Kendiliğinden konuşma: beraber gezen NPC arada bir kendisi konuşur (Config.AutoConversation aralığında;
       sosyal NPC daha sık, içe dönük daha seyrek). Konu: ortam (yağmur, gece, çatışma, polis, oyuncunun hızlı
       sürmesi), ilişki (flört), kişilik (espri), sessizlik ("Bir şey mi oldu, bugün sessizsin?").
    2) Teklif: beraber gezerken kahve/sahil/yürüyüş/bar/yemek önerir; "olur" denirse ya da ox_target
       "Teklifi kabul et" seçilirse birlikte gidilir (SC.Companion.GoTo).
    3) Yaklaşma: arkadaş NPC oyuncuyu yakında görünce yanına gelip selam verir.
    4) Eve dönme: gece geç saatte ve yorgunsa eşlik etmeyi bırakıp eve gitmek ister.
    5) Akıllı telefon mesajları: son görüşme, ilişki, kişilik, NPC'nin programı (uyku/iş), oyun saati, gerçek saat
       ve ruh hâline göre; uyuyan NPC yazmaz, gece 04:00'te sebepsiz mesaj gelmez.
    Her olayın NPC–oyuncu çifti başına bekleme süresi vardır (Config.NPCEvents.Cooldowns).
]]
local Utils = SC.Utils
local Clock = SC.Clock
local Sim = SC.Sim
local NPC = SC.NPC

local Events = {}
SC.Events = Events

local cooldowns = {}   -- 'tür|npc|cid' -> os.time()

local function E() return Config.NPCEvents or {} end
local function AC() return Config.AutoConversation or {} end

local function onCooldown(kind, npcId, cid, sec)
    local k = kind .. '|' .. npcId .. '|' .. tostring(cid)
    local t = cooldowns[k]
    return t and os.time() - t < (sec or 600)
end

local function markCooldown(kind, npcId, cid)
    cooldowns[kind .. '|' .. npcId .. '|' .. tostring(cid)] = os.time()
end

local function nextAutoDelay(r)
    local minI, maxI = AC().minInterval or 120, AC().maxInterval or 420
    local social = SC.Persona.Stats(r).social
    -- sosyal NPC aralığın başına, içe dönük sonuna yakın
    local t = (100 - social) / 100
    local base = minI + (maxI - minI) * t
    return math.floor(base * (0.75 + math.random() * 0.5))
end

-- ---------------------------------------------------------------------
-- Teklif seçimi (kişilik, saat, hava, favoriler)
-- ---------------------------------------------------------------------
function Events.PickProposal(r, rel, src)
    local mod = Clock.MinuteOfDay()
    local raining = Clock.IsRaining()
    local evening = mod >= 18 * 60 or mod < 2 * 60
    local day = mod >= 8 * 60 and mod < 19 * 60
    local opts = {}
    local origin = NPC.Coords(r) or (src and NPC.PlayerCoords(src))
    for kind, t in pairs(E().Types or {}) do
        local ok = true
        if t.noRain and raining then ok = false end
        if t.evening and not evening then ok = false end
        if t.day and not day then ok = false end
        if ok then
            local loc = Sim.PickPlace(r, t.types, origin, 2500.0, mod, nil)
            if loc then
                local w = (t.weight or 1)
                local op = SC.Persona.Opinion(r, table.concat(t.types, ' ') .. ' ' .. loc.label)
                if op < 0 then w = w * 0.2 elseif op > 0 then w = w * 2 end
                if Utils.Contains(r.favorite_places or {}, loc.id) then w = w * 1.8 end
                if kind == 'bar' and (r.age or 30) > 60 then w = w * 0.3 end
                opts[#opts + 1] = { weight = w, kind = kind, loc = loc, types = t.types }
            end
        end
    end
    local pick = Utils.WeightedPick(opts)
    if not pick then return nil end
    local offers = SCDialogue.Offers and SCDialogue.Offers[pick.kind] or { '%dest% tarafına gidelim mi' }
    local vars = SC.Dialogue.Vars(r, rel)
    vars.dest = pick.loc.label
    vars.offer = SC.Dialogue.Fill(offers[math.random(#offers)], vars)
    local text = SC.DGen.Compose('propose', r, rel, { vars = vars, src = src }) or SC.Dialogue.Capitalize(vars.offer .. '?')
    return { kind = pick.kind, dest = pick.loc.id, label = pick.loc.label, types = pick.types, text = text }
end

local function offerProposal(r, ov)
    local rel = SC.Rel.Peek(r.id, ov.cid)
    if not rel then return false end
    if onCooldown('propose', r.id, ov.cid, (E().Cooldowns or {}).propose or 900) then return false end
    local p = Events.PickProposal(r, rel, ov.target)
    if not p then return false end
    markCooldown('propose', r.id, ov.cid)
    SC.Context.SetProposal(r.id, ov.cid, p)
    local ped = NPC.Ped(r)
    if ped then Entity(ped).state:set('scProposal', { to = ov.target, kind = p.kind }, true) end
    SC.Convo.Bubble(r, p.text, 'npc', 6000)
    TriggerClientEvent('samy-citizens:client:notify', ov.target, L('notify_proposal', r.firstname, p.label), 'inform')
    local ttl = (E().ProposalTTL or 120) * 1000
    SetTimeout(ttl, function()
        local ped2 = NPC.Ped(r)
        if ped2 then
            local cur = Entity(ped2).state.scProposal
            if type(cur) == 'table' and cur.to == ov.target then Entity(ped2).state:set('scProposal', nil, true) end
        end
    end)
    return true
end

-- ---------------------------------------------------------------------
-- Eşlikçi NPC'nin kendiliğinden konuşması
-- ---------------------------------------------------------------------
local function autoTalk(r, ov)
    local now = os.time()
    if not ov.nextAuto then ov.nextAuto = now + nextAutoDelay(r) return end
    if now < ov.nextAuto or r.convo or r.interaction then return end
    ov.nextAuto = now + nextAutoDelay(r)
    local rel = SC.Rel.Peek(r.id, ov.cid)
    if not rel then return end
    -- geç saat ve yorgunluk: eve dönmek ister
    local mod = Clock.MinuteOfDay()
    local late = mod >= (E().GoHomeHour or 23) * 60 or mod < 4 * 60
    local mood = SC.Persona.MoodLabel(r, rel, ov.cid)
    if late and mood == 'tired' and ov.phase ~= 'ride' and not onCooldown('go_home', r.id, ov.cid, (E().Cooldowns or {}).go_home or 600) then
        markCooldown('go_home', r.id, ov.cid)
        local line = SC.DGen.Compose('go_home', r, rel, { src = ov.target })
        if line then SC.Convo.Bubble(r, line, 'npc', 5000) end
        SetTimeout(4000, function()
            if NPC.Companion(r) == ov then SC.Companion.End(r, 'go_home') end
        end)
        return
    end
    -- teklif
    if E().Enabled ~= false and (ov.phase == 'follow' or ov.phase == 'date') and math.random() < (E().ProposeChance or 0.3) then
        if offerProposal(r, ov) then return end
    end
    local key = 'auto_walk'
    if ov.phase == 'ride' or ov.phase == 'driving' then key = 'auto_ride'
    elseif ov.phase == 'date' then key = 'auto_date'
    elseif ov.phase == 'wait' or ov.phase == 'wait_car' then return end
    -- oyuncu uzun süredir hiç konuşmadıysa
    local cm = SC.Context.Peek(r.id, ov.cid)
    local silentFor = now - ((cm and cm.lastInteraction) or ov.startedAtOs or now)
    if silentFor > math.max(240, (AC().maxInterval or 420)) and math.random() < 0.5 then key = 'auto_silence' end
    local line = SC.DGen.Compose(key, r, rel, { src = ov.target })
    if line then SC.Convo.Bubble(r, line, 'npc', 5500) end
end

-- ---------------------------------------------------------------------
-- Arkadaş NPC oyuncuyu görünce yanına gelir
-- ---------------------------------------------------------------------
local cidCache = {}

local function cidOf(src)
    local e = cidCache[src]
    if e and os.time() - e.at < 120 then return e.cid end
    local cid = SC.Bridge.GetCitizenId(src)
    cidCache[src] = { cid = cid, at = os.time() }
    return cid
end

local function approachTick()
    if E().Enabled == false then return end
    local minStage = E().ApproachMinStage or 'friend'
    local radius = E().ApproachRadius or 18.0
    local players = SC.Spawner.Players()
    for rid, phys in pairs(SC.Spawner.peds) do
        local r = Sim.Residents[rid]
        if r and not r.convo and not r.override and not r.interaction and r.status == 'alive' and phys.coords then
            local def = SC.Activities[r.state.activity or '']
            if r.state.activity ~= 'commute' and not (def and def.busy) and r.state.activity ~= 'sleep' then
                for _, p in ipairs(players) do
                    local d = Utils.Dist(p.coords, phys.coords)
                    if d <= radius and d > 4.0 and not SC.Convo.bySrc[p.src] then
                        local cid = cidOf(p.src)
                        local rel = cid and SC.Rel.Peek(r.id, cid)
                        if rel and (SC.StageAtLeast(rel.stage, minStage) or (rel.romance or 'none') ~= 'none')
                            and not onCooldown('approach', r.id, cid, (E().Cooldowns or {}).approach or 1800)
                            and math.random() < (E().ApproachChance or 0.08) * (0.5 + SC.Persona.Stats(r).social / 100) then
                            markCooldown('approach', r.id, cid)
                            local line = SC.DGen.Compose('approach', r, rel, { src = p.src })
                            if line then SC.Convo.Bubble(r, line, 'npc', 4000) end
                            SC.Spawner.PlayGesture(r, 'wave')
                            -- mevcut 'meet' görevi: oyuncuya yürür, yanında kısa süre bekler
                            Sim.SetOverride(r, { type = 'meet', target = p.src, untilMs = GetGameTimer() + 25000 })
                            break
                        end
                    end
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------
-- Akıllı kendiliğinden telefon mesajı
-- ---------------------------------------------------------------------
local phoneRelCache = {}   -- npcId -> { at, list }
local lastPhoneCheck = 0

local function inHours(h, range)
    local a, b = range[1], range[2]
    if a <= b then return h >= a and h < b end
    return h >= a or h < b
end

local function realHour()
    return tonumber(os.date('!%H', os.time() + (Config.RealTimeUtcOffset or 0) * 3600)) or 12
end

local function recentFun(rel)
    local s = SC.RelXP.Stats(rel)
    local last = math.max(tonumber(s.lastRide) or 0, tonumber(s.lastPlaceAt) or 0)
    return last > 0 and os.time() - last < ((Config.Phone.Proactive.RecentFunHours or 20) * 3600)
end

local function phoneCandidate(r, rel, P, now)
    if not rel.phone_known or not rel.player_phone or rel.player_phone == '' then return nil end
    if rel.stage == 'cold' or rel.stage == 'enemy' then return nil end
    local display = SC.RelXP.DisplayStage(rel)
    if not SC.StageAtLeast(rel.stage, P.MinStage or 'acquaintance') and display == rel.stage then return nil end
    if now - (tonumber(rel.last_contact) or 0) < (P.MinIntervalHours or 3) * 3600 then return nil end
    local today = Clock.RealDateKey()
    if rel.proactive_date ~= today then
        rel.proactive_date = today
        rel.proactive_count = 0
    end
    local cap = (P.PerDay or {})[display] or (P.PerDay or {})[rel.stage] or 1
    if (rel.proactive_count or 0) >= cap then return nil end
    return display
end

local function smartPhoneTick()
    local P = Config.Phone.Proactive or {}
    if not P.Smart or not Config.Phone.ProactiveEnabled or not SC.Phone.Enabled() then return end
    local now = os.time()
    if now - lastPhoneCheck < (P.CheckEverySec or 20) then return end
    lastPhoneCheck = now
    if inHours(realHour(), P.RealQuietHours or { 2, 9 }) then return end
    local gh = math.floor(Clock.MinuteOfDay() / 60)
    local hours = P.GameHours or { 9, 23 }
    if not inHours(gh, hours) then return end
    -- rastgele birkaç NPC değerlendir (hepsini her seferinde değil)
    local list = Sim.List
    if #list == 0 then return end
    for _ = 1, math.min(3, #list) do
        local r = list[math.random(#list)]
        if r.enabled and r.status == 'alive' and SC.Phone.Availability(r) == 'free' then
            local mood = SC.Persona.MoodLabel(r)
            if mood ~= 'angry' and mood ~= 'sad' then
                local cache = phoneRelCache[r.id]
                if not cache or now - cache.at > 300 then
                    CreateThread(function()
                        local ok, rows = pcall(SC.Rel.WithPhone, r.id)
                        phoneRelCache[r.id] = { at = os.time(), list = ok and rows or {} }
                    end)
                else
                    for _, rel in ipairs(cache.list) do
                        local display = phoneCandidate(r, rel, P, now)
                        local src = display and SC.Bridge.GetSourceByCitizenId(rel.citizenid)
                        if src then
                            local st = SC.Persona.Stats(r)
                            local chance = (P.BaseChance or 0.02) * (0.5 + st.social / 100)
                            local hoursAway = (now - (tonumber(rel.last_seen) or now)) / 3600
                            if display == 'dating' or display == 'partner' then chance = chance * (1.5 + st.romantic / 100) end
                            if hoursAway > (P.MissAfterHours or 30) then chance = chance * 2 end
                            if math.random() < chance then
                                Events.SendSmart(r, rel, src, display, hoursAway)
                                return
                            end
                        end
                    end
                end
            end
        end
    end
end

function Events.SendSmart(r, rel, src, display, hoursAway)
    local P = Config.Phone.Proactive or {}
    local key = 'sms_generic'
    local invite
    local romance = display == 'dating' or display == 'partner'
    local mod = Clock.MinuteOfDay()
    if hoursAway > (P.MissAfterHours or 30) then
        key = 'sms_miss'
    elseif recentFun(rel) and math.random() < 0.6 then
        key = 'sms_yesterday'
    elseif mod >= 16 * 60 and mod < 21 * 60 and math.random() < (P.InviteChance or 0.35) then
        invite = Events.PickProposal(r, rel, nil)
        if invite then key = 'sms_invite' end
    elseif romance and math.random() < 0.6 then
        key = 'sms_romance'
    elseif hoursAway > (P.AbsentAfterHours or 8) then
        key = 'sms_absent'
    end
    local vars = SC.Dialogue.Vars(r, rel)
    if invite then vars.dest = invite.label end
    local text = SC.DGen.Compose(key, r, rel, { vars = vars }) or SC.DGen.Compose('sms_generic', r, rel, { vars = vars })
    if not text then return end
    text = SC.Dialogue.SmsStyle(text, r, rel)
    rel.last_contact = os.time()
    rel.proactive_count = (rel.proactive_count or 0) + 1
    SC.Rel.MarkDirty(rel)
    SC.Phone.SendToPlayer(r, rel.citizenid, rel.player_phone, text, src)
    -- davet: oyuncunun cevabı SMS akışında "olur" -> saat sorulur -> randevu
    if invite then
        local t = SC.Phone.Thread(r.id, rel.citizenid)
        t.expect = { kind = 'npc_proposal', proposal = invite }
    end
    Sim.AddLog(r, Clock.Now(), 'event', { text = L('log_sms', SC.Dialogue.PlayerAddress(rel) ~= '' and SC.Dialogue.PlayerAddress(rel) or L('ctx_unknown_number')) })
end

-- ---------------------------------------------------------------------
-- Tick (Config.Performance.EventsTickMs, varsayılan 5 sn)
-- ---------------------------------------------------------------------
local approachAt = 0

function Events.Tick()
    if AC().enabled ~= false then
        for src, set in pairs(NPC.companionsBySrc) do
            for rid in pairs(set) do
                local r = Sim.Residents[rid]
                local ov = r and NPC.Companion(r)
                if ov and ov.target == src then
                    local ok, err = pcall(autoTalk, r, ov)
                    if not ok then SC.DebugPrint('otomatik konuşma hatası', tostring(err)) end
                end
            end
        end
    end
    local now = os.time()
    if now - approachAt >= 15 then
        approachAt = now
        local ok, err = pcall(approachTick)
        if not ok then SC.DebugPrint('yaklaşma hatası', tostring(err)) end
    end
    local ok, err = pcall(smartPhoneTick)
    if not ok then SC.DebugPrint('akıllı mesaj hatası', tostring(err)) end
end

function Events.Cleanup()
    local now = os.time()
    for k, t in pairs(cooldowns) do
        if now - t > 7200 then cooldowns[k] = nil end
    end
    for id, c in pairs(phoneRelCache) do
        if now - c.at > 900 then phoneRelCache[id] = nil end
    end
    for src, e in pairs(cidCache) do
        if now - e.at > 600 then cidCache[src] = nil end
    end
end

AddEventHandler('playerDropped', function()
    cidCache[source] = nil
end)
