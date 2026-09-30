--[[
    KONUŞMA PANELİ MENÜSÜ (kategoriler)
      Konuş · Soru Sor · Beraber Yürü · Araca Davet Et · Bir Yere Git · Telefon · Aktiviteler ·
      Sosyal Etkileşimler · Yetişkin Etkileşimleri (sadece yetişkin NPC + Config.AdultNPC)
    Menü içeriği sunucuda kişiye/NPC'ye göre üretilir (görünürlük sunucu kararı). Metin seçenekleri NPC'ye
    doğrudan "söylenir" (aynı diyalog motoru, hız sınırı ve log). Metinle ifade edilemeyenler (araç, hedef,
    animasyon) 'samy-citizens:server:menuAction' ile gelir ve burada tekrar doğrulanır.
]]
local Utils = SC.Utils
local Sim = SC.Sim
local NPC = SC.NPC

local Menu = {}
SC.Menu = Menu

local lastAction = {}

local function textItems(list)
    local out = {}
    for _, t in ipairs(list or {}) do
        if type(t) == 'string' then
            out[#out + 1] = { label = t, text = t }
        elseif type(t) == 'table' and t.text then
            out[#out + 1] = { label = t.label or t.text, text = t.text }
        end
    end
    return out
end

local function animItems(reg, r, rel, src, adult)
    local out = {}
    local ids = {}
    for id in pairs(reg or {}) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local def = reg[id]
        local visible = true
        if def.npcFemale and r.gender ~= 'female' then visible = false end
        if def.minStage and not SC.StageAtLeast(rel.stage, def.minStage) and (rel.romance or 'none') == 'none' then visible = false end
        if visible then out[#out + 1] = { label = def.label or id, action = 'interact', id = id, adult = adult or nil } end
    end
    return out
end

function Menu.Build(r, c)
    local src, rel = c.src, c.rel
    if c.hostage then return nil end
    local comp = NPC.Companion(r)
    local mine = comp and comp.target == src
    local D = SCDialogue
    local cats = {}
    cats[#cats + 1] = { id = 'talk', label = L('menu_talk'), icon = 'comments' }
    cats[#cats + 1] = { id = 'ask', label = L('menu_ask'), icon = 'circle-question', items = textItems(D.MenuQuestions) }
    if Config.Follow.Enabled ~= false then
        if mine then
            local items = {
                { label = L('menu_walk_wait'), text = 'Burada bekle' },
                { label = L('menu_walk_leave'), text = 'Gidebilirsin' },
            }
            if comp.phase == 'wait' or comp.phase == 'wait_car' then table.insert(items, 1, { label = L('menu_walk_resume'), text = 'Hadi gel' }) end
            cats[#cats + 1] = { id = 'walk', label = L('menu_walk'), icon = 'person-walking', items = items }
        else
            cats[#cats + 1] = { id = 'walk', label = L('menu_walk'), icon = 'person-walking', text = 'Benimle gel' }
        end
        cats[#cats + 1] = { id = 'invite', label = L('menu_invite'), icon = 'car', action = 'invite' }
    end
    local dests = {}
    for _, d in ipairs(Config.Destinations.List or {}) do dests[#dests + 1] = { label = d.label, action = 'goto', id = d.id } end
    if Config.Destinations.AllowWaypoint then dests[#dests + 1] = { label = L('menu_goto_waypoint'), action = 'goto', id = 'waypoint' } end
    cats[#cats + 1] = { id = 'goto', label = L('menu_goto'), icon = 'location-dot', items = dests }
    if SC.Phone.Enabled() and not rel.phone_known then
        cats[#cats + 1] = { id = 'phone', label = L('menu_phone'), icon = 'mobile-screen', items = textItems(D.MenuPhone) }
    end
    local acts = textItems(D.MenuActivities)
    local minAge = (Config.Relationship.Romance and Config.Relationship.Romance.MinAge) or 21
    if (r.age or 0) >= minAge and SC.StageAtLeast(rel.stage, 'acquaintance') then
        for _, it in ipairs(textItems(D.MenuRomance)) do acts[#acts + 1] = it end
    end
    cats[#cats + 1] = { id = 'activities', label = L('menu_activities'), icon = 'mug-hot', items = acts }
    cats[#cats + 1] = { id = 'social', label = L('menu_social'), icon = 'hand', items = animItems(Config.Animation.Social, r, rel, src, false) }
    if SC.Adult.CanSeeCategory(r, src) then
        cats[#cats + 1] = { id = 'adult', label = L('menu_adult'), icon = 'heart', adult = true, items = animItems(Config.AdultAnimations, r, rel, src, true) }
    end
    return cats
end

-- NPC'nin sözlü tepkisi: konuşma açıksa panelde, değilse baloncukta
local function react(r, src, key, sub, emotion)
    local c = r.convo
    local rel = (c and c.rel) or { stage = 'stranger' }
    local line = SC.Dialogue.Line(key, r, rel, sub)
    if c and c.src == src then
        SC.Convo.NpcSay(r, c, line, emotion or 'neutral')
    else
        SC.Convo.Bubble(r, line, 'npc', 4500)
    end
end

-- Oyuncunun etkileşim hakkı olan NPC: aktif konuşma ya da yakındaki eşlikçi
local function targetNpc(src, netId)
    local rid = SC.Convo.bySrc[src]
    local r = rid and Sim.Residents[rid]
    if r and r.convo and r.convo.src == src then return r end
    r = netId and NPC.ByNet(netId) or nil
    if r and SC.Spawner.PlayerNear(src, r, 10.0) then
        local comp = NPC.Companion(r)
        if comp and comp.target == src then return r end
    end
    return nil
end

RegisterNetEvent('samy-citizens:server:menuAction', function(action, arg, extra)
    local src = source
    if type(action) ~= 'string' or not SC.Ready then return end
    local now = GetGameTimer()
    if lastAction[src] and now - lastAction[src] < 1200 then return end
    lastAction[src] = now
    local netId = type(extra) == 'table' and tonumber(extra.npc) or nil
    local r = targetNpc(src, netId)
    if not r then return end
    CreateThread(function()
        local cid = SC.Bridge.GetCitizenId(src)
        if not cid then return end
        local rel = SC.Rel.Get(r.id, cid)
        if action == 'interact' then
            if type(arg) ~= 'string' then return end
            local ok, why = SC.Interact.Evaluate(r, rel, src, arg)
            if not ok then
                local _, adult = SC.Interact.Def(arg)
                local key = adult and 'intimate_refuse' or 'touch_refuse'
                local sub = (why == 'romance' or why == 'vehicle' or why == 'busy' or why == 'privacy') and why or nil
                react(r, src, key, sub, 'neutral')
                TriggerClientEvent('samy-citizens:client:notify', src, L('interact_refused_' .. tostring(why)), 'error')
                return
            end
            local _, adult = SC.Interact.Def(arg)
            if not adult then react(r, src, 'touch_accept', nil, 'happy') end
            SC.Interact.Start(r, src, arg, { decided = true })
        elseif action == 'invite' then
            local vnet = type(extra) == 'table' and tonumber(extra.veh) or nil
            local veh = vnet and SC.Companion.VehFromNet(vnet)
            local pped = NPC.PlayerPed(src)
            if not veh or not pped or Entity(veh).state.scVeh
                or Utils.Dist(GetEntityCoords(veh), GetEntityCoords(pped)) > (Config.Vehicle.InviteDistance or 12.0) + 2.0 then
                return react(r, src, 'ride_no_vehicle')
            end
            local ok, reason = SC.Persona.Decide(r, rel, 'ride', { cid = cid })
            if not ok then return react(r, src, 'ride_refuse', reason == 'busy' and 'busy' or nil) end
            react(r, src, 'ride_accept', nil, 'happy')
            SetTimeout(1500, function()
                if r.convo and r.convo.src == src then SC.Convo.End(r, 'follow') end
                SC.Companion.Start(r, src, 'follow', { decided = true, vehNet = vnet })
            end)
        elseif action == 'goto' then
            if type(arg) ~= 'string' then return end
            local spec
            if arg == 'waypoint' then
                local wp = type(extra) == 'table' and extra.wp or nil
                if type(wp) ~= 'table' then return react(r, src, 'go_unknown') end
                spec = { waypoint = { x = tonumber(wp.x), y = tonumber(wp.y), z = tonumber(wp.z) or 0.0 } }
            else
                spec = { location = arg }
            end
            local dest = SC.Companion.ResolveDest(r, rel, spec, src)
            if not dest then return react(r, src, 'go_unknown') end
            local fav = dest.id and Utils.Contains(r.favorite_places or {}, dest.id)
            local opinion = SC.Persona.Opinion(r, dest.label .. ' ' .. tostring(dest.type))
            local ok, reason = SC.Persona.Decide(r, rel, 'go', { cid = cid, sub = dest.id or 'wp', bonus = (fav and 15 or 0) + opinion * 20 })
            local c = r.convo
            local function sayLine(key, sub, emo)
                local line = SC.Dialogue.Line(key, r, rel, sub, { dest = dest.label })
                if c and c.src == src then SC.Convo.NpcSay(r, c, line, emo or 'neutral') else SC.Convo.Bubble(r, line, 'npc', 4500) end
            end
            if not ok then
                if opinion < 0 then return sayLine('go_refuse', 'dislike') end
                return sayLine('go_refuse', reason == 'busy' and 'busy' or nil)
            end
            sayLine((fav or opinion > 0) and 'go_like' or 'go_accept', nil, 'happy')
            SetTimeout(1500, function()
                if r.convo and r.convo.src == src then SC.Convo.End(r, 'follow') end
                SC.Companion.GoTo(r, src, spec, { decided = true })
            end)
        end
    end)
end)

AddEventHandler('playerDropped', function()
    lastAction[source] = nil
end)
