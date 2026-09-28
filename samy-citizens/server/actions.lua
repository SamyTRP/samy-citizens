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

handlers.follow_player = function(ctx, a, out)
    if ctx.channel ~= 'talk' then return end
    if not SC.StageAtLeast(ctx.rel.stage, Config.Actions.MinStage.follow_player) then return end
    local minutes = Utils.Clamp(math.floor(tonumber(a.minutes) or 3), 1, Config.Actions.FollowMaxMinutes or 5)
    out.follow = minutes
    out.endConversation = true
    out.ui[#out.ui + 1] = { type = 'follow', text = L('ui_follow', ctx.r.firstname, minutes) }
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
