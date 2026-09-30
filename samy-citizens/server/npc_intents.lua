--[[
    v3 NİYET İŞLEYİCİLERİ
    Diyalog motoruna (server/dialogue.lua) Dialogue.Register ile eklenir. Desenler data/dialogue_life.lua'da.
    İşleyiciler yan etki üretmez: cevap + aksiyon listesi döndürür; aksiyonları server/actions.lua sunucu
    kurallarına göre yeniden doğrulayıp uygular (takip, araç daveti, bir yere gitme, etkileşim, flört).
]]
local Utils = SC.Utils
local Clock = SC.Clock
local Sim = SC.Sim
local Dialogue = SC.Dialogue
local H = Dialogue.H
local D = SCDialogue

local function group(ctx) return Dialogue.StageGroup(ctx.rel.stage) end

local function playerGender(ctx)
    local ci = ctx.c.charInfo
    if not ci and ctx.c.src then ci = SC.Bridge.GetCharInfo(ctx.c.src) end
    return ci and ci.gender or nil
end

local function isCompanionOf(ctx)
    local comp = SC.NPC.Companion(ctx.r)
    return comp and ctx.c.src and comp.target == ctx.c.src and comp or nil
end

-- ---------------------------------------------------------------------
-- GET_LOCATION: "Burası neresi?" / SMS: "Neredesin?"
-- ---------------------------------------------------------------------
Dialogue.Register('ask_where', function(ctx, a, out, vars)
    if group(ctx) == 'cold' then return out.say('where_me', 'cold') end
    if ctx.channel ~= 'talk' then
        local st = ctx.r.state or {}
        if st.activity == 'commute' then return out.say('where_me', 'commute') end
        if st.locationId == ctx.r.homeId then return out.say('where_me', 'home') end
        return out.say('where_me', 'default')
    end
    if vars.place then return out.say('where_here', 'default') end
    return out.say('where_here', 'unknown')
end, { composable = true, topic = 'city', filler = true })

-- ---------------------------------------------------------------------
-- Bağlama bağlı "kaçta?" — son konu iş ise mesai saatini söyler
-- ---------------------------------------------------------------------
local WORK_TOKENS = { 'is', 'ise', 'isten', 'isin', 'mesai', 'mesaiye', 'calisma', 'vardiya', 'vardiyan' }

Dialogue.Register('ask_when', function(ctx, a, out, vars)
    local topic = ctx.c.lastTopic
    local workAsked = H.hasToken(a.tokens, table.unpack(WORK_TOKENS)) or a.norm:find('calis', 1, true) ~= nil
    if workAsked or topic == 'job' then
        if group(ctx) == 'cold' then return out.say('when_work', 'cold') end
        out.topic = 'job'
        if vars.shift_start and vars.shift_end then return out.say('when_work', 'default') end
        return out.say('when_work', 'none')
    end
    if topic == 'plans' and ctx.c.lastPlan then
        vars.when = ctx.c.lastPlan.when
        vars.plan = ctx.c.lastPlan.plan
        vars.plan_cap = Dialogue.Capitalize(ctx.c.lastPlan.plan or '')
        out.topic = 'plans'
        return out.say('when_plan')
    end
    if ctx.cid and SC.Appt.GetWith(ctx.r.id, ctx.cid) and (topic == nil or topic == 'propose_meet') then
        return Dialogue.Handlers.ask_appointment(ctx, a, out, vars)
    end
    if a.norm:find('saat', 1, true) and not topic then return Dialogue.Handlers.ask_time(ctx, a, out, vars) end
    return out.say('when_unknown')
end, { composable = true, filler = true, overlap = { ask_time = true } })

-- "bu akşam ne yapıyorsun" cevabı hatırlanır; ardından "kaçta?" sorusu buna göre cevaplanır
do
    local orig = Dialogue.Handlers.ask_plans
    Dialogue.Register('ask_plans', function(ctx, a, out, vars)
        orig(ctx, a, out, vars)
        if vars.plan and vars.when then ctx.c.lastPlan = { when = vars.when, plan = vars.plan } end
    end)
end

-- ---------------------------------------------------------------------
-- GET_RELATIONSHIP: "Sevgilin var mı?"
-- ---------------------------------------------------------------------
Dialogue.Register('ask_relationship_status', function(ctx, a, out, vars)
    local r, rel = ctx.r, ctx.rel
    if group(ctx) == 'cold' then return out.say('rel_status', 'cold') end
    if rel.romance and rel.romance ~= 'none' then
        out.emotion = 'happy'
        return out.say('rel_status', 'you')
    end
    local p = type(r.profile) == 'table' and r.profile or {}
    local rom = type(p.romance) == 'table' and p.romance or {}
    local minAge = (Config.Relationship.Romance and Config.Relationship.Romance.MinAge) or 21
    if rom.open == false or (r.age or 0) < minAge then return out.say('rel_status', 'closed') end
    if SC.Persona.Stats(r).romantic >= 55 and SC.StageAtLeast(rel.stage, 'acquaintance') then
        out.emotion = 'embarrassed'
        return out.say('rel_status', 'single_flirty')
    end
    return out.say('rel_status', 'single')
end, { composable = true, topic = 'family' })

-- ---------------------------------------------------------------------
-- ASK_DATE: flört / ciddi ilişki teklifi
-- ---------------------------------------------------------------------
Dialogue.Register('ask_date', function(ctx, a, out, vars)
    local r, rel = ctx.r, ctx.rel
    out.topics.flirt = true
    local wantPartner = rel.romance == 'dating' or a.norm:find('ciddi', 1, true) ~= nil or a.norm:find('birlikte yasa', 1, true) ~= nil
    local ok, key, newRomance = SC.RelXP.EvaluateDate(r, rel, playerGender(ctx), wantPartner)
    if ok and not ctx.dry then
        out.actions[#out.actions + 1] = { type = 'set_romance', value = newRomance }
    end
    out.emotion = ok and 'happy' or 'embarrassed'
    return out.say(key)
end, { noAsk = true })

-- ---------------------------------------------------------------------
-- ASK_STOP: "Burada bekle" / "Gidebilirsin"
-- ---------------------------------------------------------------------
local WAIT_TOKENS = { 'bekle', 'kal', 'dur', 'bekler', 'durun' }

Dialogue.Register('ask_stop', function(ctx, a, out, vars)
    local comp = isCompanionOf(ctx)
    if not comp then return out.say('stop_none') end
    local leave = a.norm:find('gidebilir', 1, true) or a.norm:find('eve git', 1, true) or a.norm:find('isine don', 1, true)
        or a.norm:find('yeter', 1, true) or a.norm:find('ayril', 1, true) or a.norm:find('sen git', 1, true)
    local wait = not leave and H.hasToken(a.tokens, table.unpack(WAIT_TOKENS))
    if wait then
        out.actions[#out.actions + 1] = { type = 'companion_stop', wait = true }
        return out.say('stop_wait')
    end
    out.actions[#out.actions + 1] = { type = 'companion_stop', wait = false }
    return out.say('stop_leave')
end, { noAsk = true })

-- ---------------------------------------------------------------------
-- ASK_FOLLOW: "Benimle gel" (eski işleyicinin yerine; Config.Follow + kişilik kararı)
-- ---------------------------------------------------------------------
Dialogue.Register('ask_follow', function(ctx, a, out, vars)
    if ctx.channel ~= 'talk' then return out.say('ask_follow', 'default') end
    local r, rel = ctx.r, ctx.rel
    if Config.Follow.Enabled == false then return out.say('ask_follow', 'default') end
    local comp = isCompanionOf(ctx)
    if comp then
        if comp.phase == 'wait' or comp.phase == 'wait_car' then
            out.actions[#out.actions + 1] = { type = 'companion_resume' }
            return out.say('follow_accept')
        end
        return out.say('follow_already')
    end
    if group(ctx) == 'cold' then return out.say('follow_refuse', 'cold') end
    if ctx.dry then return out.say('follow_accept') end
    local ok, reason, repeated = SC.Persona.Decide(r, rel, 'follow', { cid = ctx.cid })
    if ok then
        out.actions[#out.actions + 1] = { type = 'companion_start', mode = 'follow' }
        out.emotion = 'happy'
        return out.say('follow_accept')
    end
    if repeated then return out.say('follow_refuse', 'repeat_no') end
    return out.say('follow_refuse', reason)
end, { noAsk = true })

-- ---------------------------------------------------------------------
-- ASK_VEHICLE: "Arabama bin"
-- ---------------------------------------------------------------------
local function playerVehicle(src)
    local ped = SC.NPC.PlayerPed(src)
    if not ped then return nil end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh and veh ~= 0 then return veh end
    local ok, v = pcall(function()
        return lib.getClosestVehicle(GetEntityCoords(ped), (Config.Vehicle.InviteDistance or 12.0), false)
    end)
    if ok and v and v ~= 0 and DoesEntityExist(v) and not Entity(v).state.scVeh then return v end
    return nil
end

Dialogue.Register('ask_ride', function(ctx, a, out, vars)
    if ctx.channel ~= 'talk' then return out.say('ride_sms') end
    local r, rel = ctx.r, ctx.rel
    if ctx.dry then return out.say('ride_accept') end
    local veh = playerVehicle(ctx.c.src)
    if not veh then return out.say('ride_no_vehicle') end
    local ok, reason = SC.Persona.Decide(r, rel, 'ride', { cid = ctx.cid })
    if not ok then return out.say('ride_refuse', reason == 'busy' and 'busy' or nil) end
    out.actions[#out.actions + 1] = { type = 'invite_vehicle', veh = NetworkGetNetworkIdFromEntity(veh) }
    out.emotion = 'happy'
    return out.say('ride_accept')
end, { noAsk = true })

-- ---------------------------------------------------------------------
-- ASK_GO_LOCATION: "Vespucci'ye gidelim" (zaman verilirse randevuya dönüşür)
-- ---------------------------------------------------------------------
Dialogue.Register('ask_go', function(ctx, a, out, vars)
    local loc = a.slots.place
    if not loc then return Dialogue.Handlers.fallback(ctx, a, out, vars) end
    if a.slots.day or a.slots.time or ctx.channel ~= 'talk' then
        return Dialogue.Handlers.propose_meet(ctx, a, out, vars)
    end
    local r, rel = ctx.r, ctx.rel
    vars.dest = loc.label
    local fav = Utils.Contains(r.favorite_places or {}, loc.id)
    local opinion = SC.Persona.Opinion(r, loc.label .. ' ' .. tostring(loc.type))
    if ctx.dry then return out.say(fav and 'go_like' or 'go_accept') end
    local bonus = (fav and 15 or 0) + opinion * 20
    local ok, reason = SC.Persona.Decide(r, rel, 'go', { cid = ctx.cid, sub = loc.id, bonus = bonus })
    if not ok then
        if opinion < 0 then return out.say('go_refuse', 'dislike') end
        return out.say('go_refuse', reason == 'busy' and 'busy' or nil)
    end
    out.actions[#out.actions + 1] = { type = 'go_to', location = loc.id }
    out.emotion = 'happy'
    return out.say((fav or opinion > 0) and 'go_like' or 'go_accept')
end, { noAsk = true })

-- ---------------------------------------------------------------------
-- ASK_DISLIKE
-- ---------------------------------------------------------------------
Dialogue.Register('ask_dislike', function(ctx, a, out, vars)
    if group(ctx) == 'cold' then return out.say('dislike', 'cold') end
    if not vars.dislike1 then return out.say('dislike', 'empty') end
    return out.say('dislike', 'default')
end, { composable = true, info = true, filler = true, topic = 'hobby' })

-- ---------------------------------------------------------------------
-- ASK_ACTIVITY: "Ne yapalım?" — NPC kişiliğine, saate, havaya göre bir şey önerir
-- ---------------------------------------------------------------------
Dialogue.Register('ask_activity', function(ctx, a, out, vars)
    if group(ctx) == 'cold' then return out.say('follow_refuse', 'cold') end
    local p = SC.Events and SC.Events.PickProposal(ctx.r, ctx.rel, ctx.c.src)
    if not p then return out.push('Bilmem, sen bir şey öner.') end
    out.push(p.text)
    ctx.c.expect = { kind = 'npc_proposal', proposal = p }
    if not ctx.dry and ctx.cid then SC.Context.SetProposal(ctx.r.id, ctx.cid, p) end
end, { noAsk = true })

-- ---------------------------------------------------------------------
-- Dokunma / sosyal etkileşim isteği: "Sarılalım mı?", "Dans edelim"
-- ---------------------------------------------------------------------
local function touchId(norm)
    for _, e in ipairs(D.TouchWords or {}) do
        if norm:find(e[1], 1, true) then return e[2] end
    end
    return nil
end

Dialogue.Register('ask_touch', function(ctx, a, out, vars)
    if ctx.channel ~= 'talk' then return out.say('ride_sms') end
    local id = touchId(a.norm)
    if not id or not Config.Animation.Social[id] then return Dialogue.Handlers.fallback(ctx, a, out, vars) end
    if ctx.dry then return out.say('touch_accept') end
    local ok, why = SC.Interact.Evaluate(ctx.r, ctx.rel, ctx.c.src, id)
    if ok then
        out.actions[#out.actions + 1] = { type = 'interact', id = id }
        out.emotion = 'happy'
        return out.say('touch_accept')
    end
    return out.say('touch_refuse', (why == 'romance' or why == 'vehicle' or why == 'busy') and why or nil)
end, { noAsk = true })

-- ---------------------------------------------------------------------
-- GET_PLAYER_RELATIONSHIP: "Biz neyiz?"
-- ---------------------------------------------------------------------
Dialogue.Register('ask_us', function(ctx, a, out, vars)
    if group(ctx) == 'cold' then return out.say('us', 'cold') end
    if ctx.rel.romance and ctx.rel.romance ~= 'none' then return out.say('us', 'romance') end
    return out.say('us', 'default')
end, { composable = true })

-- ---------------------------------------------------------------------
-- Beklenen cevap: NPC'nin teklifi ("Sahile inelim mi?" -> "olur")
-- ---------------------------------------------------------------------
local YES_TOKENS = { 'olur', 'tamam', 'evet', 'hadi', 'gidelim', 'tabii', 'tabi', 'kesinlikle', 'harika', 'super' }

Dialogue.ExpectHooks.npc_proposal = function(ctx, a, out, vars, e)
    local p = e.proposal
    if not p then return false end
    local yes = a.best == 'yes' or (a.best ~= 'no' and H.hasToken(a.tokens, table.unpack(YES_TOKENS)))
    if a.best == 'no' then
        if not ctx.dry and ctx.cid then SC.Context.TakeProposal(ctx.r.id, ctx.cid) end
        out.push('Peki, başka zaman.')
        return true
    end
    if not yes then return false end
    if not ctx.dry and ctx.cid then SC.Context.TakeProposal(ctx.r.id, ctx.cid) end
    vars.dest = p.label
    if ctx.channel == 'talk' then
        out.actions[#out.actions + 1] = { type = 'go_to', location = p.dest, fromProposal = true }
        out.emotion = 'happy'
        out.say('go_accept')
        return true
    end
    -- SMS: randevu akışına dönüşür (yer belli, saat sorulur)
    ctx.c.meet = { purpose = p.kind, types = p.types, locId = p.dest }
    H.meetFlow(ctx, a, out, vars, false)
    return true
end
