--[[
    AKSİYONLAR
    Diyalog motorunun ürettiği aksiyonlar (numara verme, randevu, yol tarifi, eşlik etme, kaçma, polis)
    burada sunucu kurallarına göre bir kez daha doğrulanıp uygulanır.
    Hiçbir aksiyon oyuncuya eşya/para vermez.
]]
local Utils = SC.Utils
local Sim = SC.Sim

local Actions = {}
SC.Actions = Actions

-- Yerelleştirilmiş cümle listesinden rastgele bir tane
local function pickLine(key)
    local list = LT(key) or {}
    if #list == 0 then return '...' end
    return list[math.random(#list)]
end
Actions.PickLine = pickLine

local handlers = {}

handlers.end_conversation = function(ctx, a, out)
    if ctx.channel == 'talk' then out.endConversation = true end
end

handlers.give_phone_number = function(ctx, a, out)
    local rel = ctx.rel
    if not SC.StageAtLeast(rel.stage, Config.Actions.MinStage.give_phone_number) then return end
    if rel.phone_known or not SC.Phone.Enabled() then return end
    rel.phone_known = true
    rel.player_phone = SC.Phone.GetPlayerNumber(ctx.src) or rel.player_phone
    SC.Rel.MarkDirty(rel)
    out.ui[#out.ui + 1] = { type = 'phone', text = L('ui_phone_given', ctx.r.firstname, ctx.r.phone_number or '?') }
    SC.Phone.SendIntro(ctx.r, ctx.citizenid, ctx.src, rel)
    SC.Memory.AddAsync(ctx.r.id, ctx.citizenid, L('mem_gave_phone', ctx.charName or L('ctx_this_person')), 4, 'event', { valence = 1 })
end

handlers.create_appointment = function(ctx, a, out)
    local rel = ctx.rel
    if not SC.StageAtLeast(rel.stage, Config.Actions.MinStage.create_appointment) then return end
    local ok, info = SC.Appt.Validate(ctx.r, ctx.citizenid, a, rel)
    if not ok then return end
    local appt = SC.Appt.Create(ctx.r, ctx.citizenid, info, ctx.charName)
    if appt then
        out.ui[#out.ui + 1] = { type = 'appointment', text = L('ui_appt_created', SC.Appt.WhenText(info.start), info.loc.label) }
        out.appointment = appt
    end
end

handlers.cancel_appointment = function(ctx, a, out)
    local ok = SC.Appt.Cancel(ctx.r, ctx.citizenid, 'npc')
    if ok then out.ui[#out.ui + 1] = { type = 'appointment', text = L('ui_appt_cancelled') } end
end

-- Eski "eşlik et" aksiyonu artık beraber gezme (companion) sistemine yönlenir
handlers.follow_player = function(ctx, a, out)
    if ctx.channel ~= 'talk' then return end
    out.companion = { mode = 'follow' }
    out.endConversation = true
end

-- ---------------------------------------------------------------------
-- v3: beraber gezme / araç / bir yere gitme / etkileşim / flört
-- Karar diyalog işleyicisinde verildi; burada sadece kanala göre sonuç işaretlenir,
-- asıl doğrulama SC.Companion / SC.Interact içinde (mesafe, durum önceliği, koltuk...) yapılır.
-- ---------------------------------------------------------------------
handlers.companion_start = function(ctx, a, out)
    if ctx.channel ~= 'talk' then return end
    out.companion = { mode = 'follow' }
    out.endConversation = true
end

handlers.companion_resume = function(ctx, a, out)
    if ctx.channel ~= 'talk' then return end
    out.companionResume = true
    out.endConversation = true
end

handlers.companion_stop = function(ctx, a, out)
    if ctx.channel ~= 'talk' then return end
    out.companionStop = a.wait and 'wait' or 'leave'
    out.endConversation = true
end

handlers.invite_vehicle = function(ctx, a, out)
    if ctx.channel ~= 'talk' then return end
    local net = math.floor(tonumber(a.veh) or 0)
    if net <= 0 then return end
    out.invite = { veh = net }
    out.endConversation = true
end

handlers.go_to = function(ctx, a, out)
    if ctx.channel ~= 'talk' then return end
    if type(a.location) ~= 'string' and type(a.waypoint) ~= 'table' then return end
    out.goTo = { location = a.location, waypoint = a.waypoint }
    out.endConversation = true
end

handlers.interact = function(ctx, a, out)
    if ctx.channel ~= 'talk' or type(a.id) ~= 'string' then return end
    out.interact = a.id
end

handlers.set_romance = function(ctx, a, out)
    if a.value ~= 'dating' and a.value ~= 'partner' then return end
    -- son bir kontrol: karar aynı turda sunucuda verildi, yine de temel şartlar
    local minAge = (Config.Relationship.Romance and Config.Relationship.Romance.MinAge) or 21
    if (ctx.r.age or 0) < minAge or ctx.rel.stage == 'enemy' or ctx.rel.stage == 'cold' then return end
    SC.RelXP.SetRomance(ctx.r, ctx.rel, a.value)
    out.ui[#out.ui + 1] = { type = 'romance', text = L('ui_romance_' .. a.value, ctx.r.firstname) }
end

handlers.give_directions = function(ctx, a, out)
    local target = tostring(a.locationId or a.location or a.place or '')
    local loc = Sim.FindLocation(target, true)
    if not loc and target == ctx.r.homeId and SC.StageAtLeast(ctx.rel.stage, 'close_friend') then
        loc = Sim.Locations[ctx.r.homeId]
    end
    if not loc then return end
    if ctx.channel == 'sms' then
        out.smsLocation = loc
    else
        TriggerClientEvent('samy-citizens:client:waypoint', ctx.src, loc.door.x, loc.door.y, loc.label)
    end
    out.ui[#out.ui + 1] = { type = 'directions', text = L('ui_directions', loc.label) }
end

handlers.flee = function(ctx, a, out)
    if ctx.channel ~= 'talk' then return end
    out.flee = true
    out.endConversation = true
end

handlers.call_police = function(ctx, a, out)
    out.police = true
end

-- ctx = { r, src, citizenid, rel, channel, charName }; res.actions = { {type=...}, ... }
function Actions.Execute(ctx, res)
    local out = { ui = {} }
    for _, a in ipairs(res.actions or {}) do
        local h = handlers[a.type]
        if h then
            local ok, err = pcall(h, ctx, a, out)
            if not ok then print(('^1[samy-citizens] aksiyon hatası %s: %s^7'):format(a.type, tostring(err))) end
        end
    end
    if out.police then
        SC.World.CallPolice(ctx.r, L('police_reason_threat'), ctx.src)
    end
    return out
end
