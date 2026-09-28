--[[
    RANDEVULAR
    Oyuncuyla ayarlanan buluşma, o zaman dilimindeki rutin bloğunun yerine geçer (soyut katmanda da).
    Oyuncu gelmezse Config.Actions.AppointmentWaitMinutes bekler, sonra küsme anısı oluşur.
    İkisi de gelirse "buluşma modu": NPC oyuncunun yanına gelir, konuşma açılabilir.
]]
local Utils = SC.Utils
local Clock = SC.Clock
local Sim = SC.Sim

local Appt = {}
SC.Appt = Appt

Appt.byNpc = {}

local A = Config.Actions

local function add(a)
    local list = Appt.byNpc[a.npc_id]
    if not list then
        list = {}
        Appt.byNpc[a.npc_id] = list
    end
    list[#list + 1] = a
    table.sort(list, function(x, y) return x.start_min < y.start_min end)
end

local function remove(a)
    local list = Appt.byNpc[a.npc_id]
    if not list then return end
    for i, x in ipairs(list) do
        if x.id == a.id then
            table.remove(list, i)
            break
        end
    end
end

local function dbStatus(a)
    MySQL.update('UPDATE samy_citizens_appointments SET status = ?, met_at = ? WHERE id = ?', { a.status, a.met_at or 0, a.id })
end

function Appt.Load()
    Appt.byNpc = {}
    local rows = MySQL.query.await([[SELECT * FROM samy_citizens_appointments WHERE status IN ('pending', 'active', 'met')]]) or {}
    local now = Clock.Now()
    for _, row in ipairs(rows) do
        row.start_min = tonumber(row.start_min) or 0
        row.met_at = tonumber(row.met_at)
        if row.met_at == 0 then row.met_at = nil end
        if row.start_min + A.AppointmentWaitMinutes + A.AppointmentMeetMinutes < now or not Sim.Locations[row.location_id] then
            row.status = 'expired'
            dbStatus(row)
        else
            if row.status == 'met' then row.status = 'active' end
            add(row)
        end
    end
end

-- "yarın 20:00" gibi göreli ifade
function Appt.WhenText(start)
    local now = Clock.Now()
    local diff = Clock.Day(start) - Clock.Day(now)
    local dayWord
    if diff == 0 then
        dayWord = L('word_today')
    elseif diff == 1 then
        dayWord = L('word_tomorrow')
    else
        dayWord = Clock.DayName(start)
    end
    return ('%s %s'):format(dayWord, Utils.FormatTime(start % 1440))
end

local function windowEnd(a)
    if a.status == 'met' then return (a.met_at or a.start_min) + A.AppointmentMeetMinutes end
    return math.max(a.start_min, a.arrived_at or a.start_min) + A.AppointmentWaitMinutes
end

-- Sim için: t anında randevu segmenti
function Appt.SegmentFor(r, t)
    local list = Appt.byNpc[r.id]
    if not list then return nil end
    for _, a in ipairs(list) do
        if t >= a.start_min and t < windowEnd(a) then
            return {
                from = a.start_min, to = windowEnd(a), activity = 'appointment', location = a.location_id,
                key = 'appt:' .. a.id, firm = true, appt = a,
                resolved = { activity = 'appointment', loc = a.location_id },
            }
        end
    end
    return nil
end

function Appt.BoundariesFor(r)
    local out = {}
    for _, a in ipairs(Appt.byNpc[r.id] or {}) do
        out[#out + 1] = a.start_min
        out[#out + 1] = windowEnd(a)
    end
    return out
end

function Appt.HasActiveWith(npcId, cid)
    if not cid then return false end
    for _, a in ipairs(Appt.byNpc[npcId] or {}) do
        if a.citizenid == cid then return true end
    end
    return false
end

-- Bu oyuncuyla aktif randevu
function Appt.GetWith(npcId, cid)
    if not cid then return nil end
    for _, a in ipairs(Appt.byNpc[npcId] or {}) do
        if a.citizenid == cid and (a.status == 'pending' or a.status == 'active' or a.status == 'met') then return a end
    end
    return nil
end

-- ---------------------------------------------------------------------
-- Doğrulama
-- ---------------------------------------------------------------------
-- start'tan sonraki ilk uygun zaman (uyku/iş dışında, 08:00–23:00, başka randevuya çakışmayan)
local function suggestTime(r, start)
    for step = 1, 30 do
        local t = math.floor((start + step * 30) / 30 + 0.5) * 30
        local res, seg = Sim.PredictAt(r, t)
        if res then
            local def = SC.Activities[res.activity]
            local firm = (seg and seg.firm) or (def and def.firm)
            local mod = t % 1440
            local clash = false
            for _, other in ipairs(Appt.byNpc[r.id] or {}) do
                if math.abs(other.start_min - t) < (A.AppointmentMinGap or 90) then clash = true end
            end
            if res.activity ~= 'sleep' and not firm and not clash and mod >= 8 * 60 and mod <= 23 * 60 then
                return t
            end
        end
    end
    return nil
end
Appt.SuggestTime = suggestTime

--[[
    action = { place, time = 'HH:MM', day = 0|1|2|'today'|'tomorrow', purpose }
    dönüş: true, info  |  false, reason ('place'|'time'|'far'|'soon'|'sleep'|'work'|'busy'), önerilen mutlak dakika|nil
]]
function Appt.Validate(r, cid, action, rel)
    local placeText = tostring(action.place or action.location or action.locationId or '')
    local loc = Sim.FindLocation(placeText, true)
    if not loc and rel and SC.StageAtLeast(rel.stage, 'close_friend') then
        local f = Utils.Fold(placeText)
        if placeText == r.homeId or f:find('ev', 1, true) == 1 then loc = Sim.Locations[r.homeId] end
    end
    if not loc then return false, 'place' end
    local minutes = Utils.ParseTime(tostring(action.time or ''))
    if not minutes or minutes >= 1440 then return false, 'time' end
    local now = Clock.Now()
    local today = Clock.Day(now)
    local off
    local day = action.day
    if type(day) == 'number' then
        off = math.floor(day)
    elseif type(day) == 'string' then
        local f = Utils.Fold(day)
        if tonumber(day) then
            off = math.floor(tonumber(day))
        elseif f == 'today' or f:find('bugun', 1, true) then
            off = 0
        elseif f == 'tomorrow' or f:find('yarin', 1, true) then
            off = 1
        end
    end
    if not off then off = ((today * 1440 + minutes) > now + 20) and 0 or 1 end
    if off < 0 or off > (A.AppointmentMaxDaysAhead or 3) then
        return false, 'far', suggestTime(r, now + 30)
    end
    local start = (today + off) * 1440 + minutes
    if start < now + 20 then return false, 'soon', suggestTime(r, now + 30) end
    for _, t in ipairs({ start, start + 30 }) do
        local res, seg = Sim.PredictAt(r, t)
        if res then
            local def = SC.Activities[res.activity]
            if res.activity == 'sleep' then
                return false, 'sleep', suggestTime(r, start)
            end
            if (seg and seg.firm) or (def and def.firm) then
                return false, 'work', suggestTime(r, start)
            end
        end
    end
    for _, other in ipairs(Appt.byNpc[r.id] or {}) do
        if math.abs(other.start_min - start) < (A.AppointmentMinGap or 90) then
            return false, 'busy', suggestTime(r, start)
        end
    end
    return true, { loc = loc, start = start, purpose = Utils.Truncate(Utils.Trim(tostring(action.purpose or '')), 150) }
end

-- ---------------------------------------------------------------------
-- Oluşturma / iptal
-- ---------------------------------------------------------------------
function Appt.Create(r, cid, info, charName)
    local id = MySQL.insert.await([[INSERT INTO samy_citizens_appointments (npc_id, citizenid, location_id, start_min, purpose, status, created_at)
        VALUES (?, ?, ?, ?, ?, 'pending', ?)]], { r.id, cid, info.loc.id, info.start, info.purpose or '', os.time() })
    if not id then return nil end
    local a = {
        id = id, npc_id = r.id, citizenid = cid, location_id = info.loc.id, start_min = info.start,
        purpose = info.purpose or '', status = 'pending', created_at = os.time(), char_name = charName,
    }
    add(a)
    local when = Appt.WhenText(info.start)
    SC.Memory.AddAsync(r.id, cid, L('mem_appt_created', charName or L('ctx_this_person'), when, info.loc.label), 6, 'event', { valence = 1 })
    Sim.AddLog(r, Clock.Now(), 'event', { text = L('log_appt_created', charName or '?', when, info.loc.label) })
    local src = SC.Bridge.GetSourceByCitizenId(cid)
    if src then
        TriggerClientEvent('samy-citizens:client:notify', src, L('notify_appt_created', r.firstname, when, info.loc.label), 'success')
    end
    return a
end

function Appt.Cancel(r, cid, reason)
    for _, a in ipairs(Appt.byNpc[r.id] or {}) do
        if a.citizenid == cid and (a.status == 'pending' or a.status == 'active') then
            Appt.Finish(a, 'cancelled')
            SC.Memory.AddAsync(r.id, cid, L('mem_appt_cancelled', a.char_name or L('ctx_this_person'), Sim.LocationLabel(a.location_id)), 3, 'event')
            return true, a
        end
    end
    return false
end

function Appt.CancelAllFor(npcId, cid)
    for _, a in ipairs(Utils.DeepCopy(Appt.byNpc[npcId] or {})) do
        if not cid or a.citizenid == cid then
            for _, real in ipairs(Appt.byNpc[npcId] or {}) do
                if real.id == a.id then Appt.Finish(real, 'cancelled') break end
            end
        end
    end
end

function Appt.Finish(a, status)
    a.status = status
    dbStatus(a)
    remove(a)
    local r = Sim.Residents[a.npc_id]
    if r and r.override and r.override.apptId == a.id then
        Sim.ClearOverride(r, 'appt_' .. status)
    end
end

local function charNameFor(a)
    if a.char_name then return a.char_name end
    local rel = SC.Rel.Get(a.npc_id, a.citizenid)
    a.char_name = rel and rel.char_name or L('ctx_this_person')
    return a.char_name
end

function Appt.Met(a, r, src)
    a.status = 'met'
    a.met_at = Clock.Now()
    dbStatus(a)
    local name = charNameFor(a)
    SC.World.ApplyEvent(r, a.citizenid, 'met_appointment', L('mem_appt_met', name, Sim.LocationLabel(a.location_id)))
    Sim.SetOverride(r, { type = 'meet', target = src, apptId = a.id })
    TriggerClientEvent('samy-citizens:client:notify', src, L('notify_appt_met', r.firstname), 'inform')
    local greets = LT('appt_greet') or {}
    if #greets > 0 and SC.Convo then
        SC.Convo.Bubble(r, greets[math.random(#greets)]:format(name:match('^(%S+)') or name))
    end
end

function Appt.Missed(a, r)
    Appt.Finish(a, 'missed')
    local name = charNameFor(a)
    SC.World.ApplyEvent(r, a.citizenid, 'missed_appointment', L('mem_appt_missed', name, Sim.LocationLabel(a.location_id)))
    local rel = SC.Rel.Get(r.id, a.citizenid)
    if rel and rel.phone_known and rel.player_phone and SC.Phone.Enabled() then
        local lines = LT('sms_missed') or {}
        if #lines > 0 then SC.Phone.SendToPlayer(r, a.citizenid, rel.player_phone, lines[math.random(#lines)]) end
    end
end

-- ---------------------------------------------------------------------
-- Tick (thread içinden)
-- ---------------------------------------------------------------------
function Appt.Tick()
    local now = Clock.Now()
    for npcId, list in pairs(Appt.byNpc) do
        local r = Sim.Residents[npcId]
        for i = #list, 1, -1 do
            local a = list[i]
            if not r or not r.enabled then
                Appt.Finish(a, 'cancelled')
            elseif r.status ~= 'alive' then
                local name = charNameFor(a)
                Appt.Finish(a, 'cancelled')
                local rel = SC.Rel.Get(r.id, a.citizenid)
                if rel and rel.phone_known and rel.player_phone and SC.Phone.Enabled() and r.status == 'hospital' then
                    SC.Phone.SendToPlayer(r, a.citizenid, rel.player_phone, L('sms_hospital_cancel', name))
                end
            else
                local src = SC.Bridge.GetSourceByCitizenId(a.citizenid)
                if a.status == 'pending' and not a.reminded and now >= a.start_min - (A.AppointmentReminderMinutes or 30) and now < a.start_min then
                    a.reminded = true
                    if src then
                        local loc = Sim.Locations[a.location_id]
                        TriggerClientEvent('samy-citizens:client:notify', src, L('notify_appt_reminder', r.firstname, Appt.WhenText(a.start_min), loc and loc.label or '?'), 'inform')
                    end
                end
                if a.status == 'pending' and now >= a.start_min then
                    a.status = 'active'
                    dbStatus(a)
                end
                if a.status == 'active' then
                    local atPlace = r.state.locationId == a.location_id and r.state.activity == 'appointment'
                    if atPlace and not a.arrived_at then a.arrived_at = now end
                    if atPlace and src and not r.convo then
                        local npcPos = SC.Spawner.GetPedCoords(r) or Sim.GetPosition(r)
                        local pped = GetPlayerPed(src)
                        if npcPos and pped and pped ~= 0 and Utils.Dist(GetEntityCoords(pped), npcPos) <= (A.AppointmentArriveDistance or 25.0) then
                            Appt.Met(a, r, src)
                        end
                    end
                    if a.status == 'active' and now > windowEnd(a) then
                        if a.arrived_at then
                            Appt.Missed(a, r)
                        else
                            Appt.Finish(a, 'expired')
                        end
                    end
                elseif a.status == 'met' then
                    local done = false
                    if not src then
                        done = true
                    else
                        local npcPos = SC.Spawner.GetPedCoords(r) or Sim.GetPosition(r)
                        local pped = GetPlayerPed(src)
                        local d = (npcPos and pped and pped ~= 0) and Utils.Dist(GetEntityCoords(pped), npcPos) or 999.0
                        if d > 60.0 then
                            a.farSince = a.farSince or os.time()
                            if os.time() - a.farSince > 90 then done = true end
                        else
                            a.farSince = nil
                        end
                    end
                    if done or now > windowEnd(a) then Appt.Finish(a, 'done') end
                end
            end
        end
    end
end

function Appt.ListAll()
    local out = {}
    for _, list in pairs(Appt.byNpc) do
        for _, a in ipairs(list) do out[#out + 1] = a end
    end
    return out
end
