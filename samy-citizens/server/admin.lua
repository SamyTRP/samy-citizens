--[[
    YÖNETİM PANELİ (/citizensadmin, ace: Config.Admin.Ace)
    Her istek sunucuda ace ile yeniden doğrulanır; istemciden gelen tüm veriler şemaya göre temizlenir.
]]
local Utils = SC.Utils
local Clock = SC.Clock
local Sim = SC.Sim

local Admin = {}
SC.Admin = Admin

function Admin.IsAdmin(src)
    if not src or src == 0 then return true end
    return IsPlayerAceAllowed(src, Config.Admin.Ace) or IsPlayerAceAllowed(src, 'command.' .. Config.Admin.Command)
end

local function register(name, fn)
    lib.callback.register('samy-citizens:admin:' .. name, function(src, ...)
        if not Admin.IsAdmin(src) then return false, L('err_no_permission') end
        local ok, a, b = pcall(fn, src, ...)
        if not ok then
            print(('^1[samy-citizens] admin %s hatası: %s^7'):format(name, tostring(a)))
            return false, tostring(a)
        end
        return a, b
    end)
end

-- ---------------------------------------------------------------------
-- Doğrulama yardımcıları
-- ---------------------------------------------------------------------
local function str(v, max, pattern)
    if type(v) ~= 'string' then return nil end
    v = Utils.Trim(v)
    if v == '' then return nil end
    v = Utils.Truncate(v, max or 100)
    if pattern and not v:match(pattern) then return nil end
    return v
end

local function strList(v, maxItems, maxLen)
    local out = {}
    if type(v) == 'string' then
        local parts = {}
        for piece in v:gmatch('[^,]+') do parts[#parts + 1] = piece end
        v = parts
    end
    if type(v) ~= 'table' then return out end
    for _, s in ipairs(v) do
        local x = str(s, maxLen or 40)
        if x and #out < (maxItems or 8) then out[#out + 1] = x end
    end
    return out
end

local function vec4From(t)
    if type(t) ~= 'table' then return nil end
    local x, y, z, w = tonumber(t.x), tonumber(t.y), tonumber(t.z), tonumber(t.w or t.h or 0)
    if not x or not y or not z then return nil end
    if math.abs(x) > 10000 or math.abs(y) > 10000 or math.abs(z) > 3000 then return nil end
    return vector4(x + 0.0, y + 0.0, z + 0.0, (w or 0.0) % 360.0)
end

local function validTimeToken(tok)
    if type(tok) ~= 'string' then return false end
    if Utils.ParseTime(tok) then return Utils.ParseTime(tok) < 72 * 60 end
    return tok:match('^%s*shift_%a+%s*[%+%-]?%s*%d*%s*$') ~= nil
end

local ID_PATTERN = '^[a-z0-9_]+$'

local function slugify(s)
    local f = Utils.Fold(s or ''):gsub('[^a-z0-9]+', '_'):gsub('^_+', ''):gsub('_+$', '')
    return Utils.Truncate(f, 40)
end

-- ---------------------------------------------------------------------
-- Genel bakış
-- ---------------------------------------------------------------------
local function residentRow(r)
    local pos = SC.Spawner.GetPedCoords(r) or Sim.GetPosition(r)
    local st = r.state or {}
    return {
        id = r.id,
        name = r.firstname .. ' ' .. r.lastname,
        job = r.job.title or '',
        enabled = r.enabled,
        status = r.status,
        activity = st.activity,
        activityLabel = L('act.' .. tostring(st.activity)),
        location = st.activity == 'commute' and (Sim.LocationLabel(st.fromLocationId) .. ' → ' .. Sim.LocationLabel(st.toLocationId)) or (st.pos and L('loc_outside') or Sim.LocationLabel(st.locationId)),
        mode = st.mode,
        inside = st.inside == true,
        physical = SC.Spawner.peds[r.id] ~= nil,
        mood = math.floor(r.mood or 0),
        moodKey = Sim.MoodKey(r),
        moodReason = r.mood_reason or '',
        needs = {
            energy = math.floor(r.needs.energy), hunger = math.floor(r.needs.hunger),
            social = math.floor(r.needs.social), fun = math.floor(r.needs.fun),
        },
        convo = r.convo ~= nil,
        override = r.override and r.override.type or nil,
        pos = pos and { x = pos.x, y = pos.y, z = pos.z } or nil,
        phone = r.phone_number,
        state = SC.State and SC.State.Get(r) or nil,
        npcType = SC.NPC and SC.NPC.Type(r) or 'citizen',
    }
end

register('overview', function(src)
    local list = {}
    for _, r in ipairs(Sim.List) do list[#list + 1] = residentRow(r) end
    table.sort(list, function(a, b) return a.name < b.name end)
    return {
        residents = list,
        clock = Clock.Describe(),
        weather = Clock.WeatherLabel(),
        clockSource = Clock.source,
        spawned = SC.Spawner.Count(),
        maxSpawned = Config.MaxSpawnedResidents,
        appointments = #SC.Appt.ListAll(),
    }
end)

register('bootstrap', function(src)
    local locs, routines = {}, {}
    for id, loc in pairs(Sim.Locations) do locs[#locs + 1] = { id = id, label = loc.label, type = loc.type } end
    table.sort(locs, function(a, b) return a.label < b.label end)
    for id, rt in pairs(Sim.Routines) do routines[#routines + 1] = { id = id, label = rt.label } end
    table.sort(routines, function(a, b) return a.label < b.label end)
    local acts = {}
    for k in pairs(SC.Activities) do acts[#acts + 1] = { id = k, label = L('act.' .. k) } end
    acts[#acts + 1] = { id = 'lunch', label = L('act.lunch') }
    acts[#acts + 1] = { id = 'free', label = L('act.free') }
    table.sort(acts, function(a, b) return a.id < b.id end)
    local tags = {}
    local tagSet = {}
    for _, def in pairs(SC.Activities) do
        for _, t in ipairs(def.tags or {}) do
            if not tagSet[t] then tagSet[t] = true tags[#tags + 1] = t end
        end
    end
    table.sort(tags)
    return {
        locations = locs, routines = routines, activities = acts, scenarios = SC.Scenarios,
        locationTypes = SC.LocationTypes, tags = tags, weekdays = LT('weekdays_short'),
        stages = { 'enemy', 'cold', 'stranger', 'acquaintance', 'friend', 'close_friend' },
        stageLabels = {
            enemy = L('stage_enemy'), cold = L('stage_cold'), stranger = L('stage_stranger'),
            acquaintance = L('stage_acquaintance'), friend = L('stage_friend'), close_friend = L('stage_close_friend'),
        },
        generateEnabled = true,
        locale = Config.Locale,
        npcTypes = (function()
            local out = {}
            for k, v in pairs(Config.NPCTypes or {}) do out[k] = v.label or k end
            return out
        end)(),
    }
end)

register('resident', function(src, id)
    local r = Sim.Residents[id]
    if not r then return false, L('err_not_found') end
    local rels = SC.Rel.ListForNpc(id)
    local relList = {}
    for _, rel in ipairs(rels) do
        relList[#relList + 1] = {
            citizenid = rel.citizenid, name = rel.char_name or '?', stage = rel.stage, stageLabel = SC.Rel.StageLabel(rel.stage),
            familiarity = rel.familiarity, affinity = rel.affinity, trust = rel.trust, timesMet = rel.times_met,
            meetDays = rel.meet_days, lastSeen = rel.last_seen > 0 and Utils.RelativeAge(os.time() - rel.last_seen) or '-',
            phoneKnown = rel.phone_known, xp = rel.xp or 0, romance = rel.romance or 'none',
            romanceLabel = (rel.romance and rel.romance ~= 'none') and SC.Rel.StageLabel(rel.romance) or '-',
        }
    end
    local appts = {}
    for _, a in ipairs(SC.Appt.byNpc[id] or {}) do
        appts[#appts + 1] = { id = a.id, citizenid = a.citizenid, when = SC.Appt.WhenText(a.start_min), place = Sim.LocationLabel(a.location_id), status = a.status, purpose = a.purpose }
    end
    return {
        data = {
            id = r.id, firstname = r.firstname, lastname = r.lastname, age = r.age, gender = r.gender, model = r.model,
            voice_id = r.voice_id, personality = r.personality, backstory = r.backstory, job = r.job, homeId = r.homeId,
            vehicle = r.vehicle, favorite_places = r.favorite_places, acquaintances = r.acquaintances, routine_id = r.routine_id,
            phone_number = r.phone_number, enabled = r.enabled, hasAppearance = r.appearance ~= nil, topics = r.topics or {},
            profile = r.profile or {}, derivedStats = SC.Persona and SC.Persona.Stats(r) or nil,
        },
        row = residentRow(r),
        plan = Sim.GetPlanView(r, Clock.Day(), false),
        log = Sim.RenderLog(r.dayLog, false, 40),
        yesterday = r.yesterdaySummary,
        social = SC.Social.Describe(r),
        relationships = relList,
        appointments = appts,
    }
end)

-- ---------------------------------------------------------------------
-- Sakin kaydetme
-- ---------------------------------------------------------------------
local TOPIC_KEYS = { 'job', 'work_opinion', 'family', 'dream', 'secret', 'food', 'music', 'origin' }
local STAT_KEYS = { 'friendliness', 'humor', 'confidence', 'jealousy', 'patience', 'romantic', 'social', 'aggression' }
local VEH_PREFS = { car = true, walk = true, transit = true }

-- v3 profili: kişilik puanları, kategori, sevdikleri/sevmedikleri, ilişki tercihleri (rutin alternatifleri korunur)
local function validateProfile(p, age)
    if type(p) ~= 'table' then return nil end
    local out = {}
    out.type = (type(p.type) == 'string' and Config.NPCTypes[p.type]) and p.type or 'citizen'
    local minAge = (Config.AdultNPC and Config.AdultNPC.MinAge) or 21
    out.adult = p.adult == true and (tonumber(age) or 0) >= minAge
    out.zone = str(p.zone, 40, '^[%w_]+$')
    if type(p.stats) == 'table' then
        local st = {}
        local any = false
        for _, k in ipairs(STAT_KEYS) do
            local n = tonumber(p.stats[k])
            if n then
                st[k] = Utils.Clamp(math.floor(n), 0, 100)
                any = true
            end
        end
        if any then out.stats = st end
    end
    out.likes = strList(p.likes, 10, 40)
    out.dislikes = strList(p.dislikes, 10, 40)
    local rom = type(p.romance) == 'table' and p.romance or {}
    out.romance = { open = rom.open ~= false, prefers = (rom.prefers == 'male' or rom.prefers == 'female') and rom.prefers or 'any' }
    out.favorite_areas = strList(p.favorite_areas, 8, 40)
    out.vehicle_pref = VEH_PREFS[p.vehicle_pref] and p.vehicle_pref or nil
    return out
end

local function validateResident(d)
    if type(d) ~= 'table' then return nil, 'data' end
    local out = {}
    out.id = str(d.id, 50, ID_PATTERN)
    if not out.id then return nil, 'id' end
    out.firstname = str(d.firstname, 50)
    out.lastname = str(d.lastname, 50) or ''
    if not out.firstname then return nil, 'firstname' end
    out.age = Utils.Clamp(math.floor(tonumber(d.age) or 30), 16, 99)
    out.gender = d.gender == 'female' and 'female' or 'male'
    out.model = str(d.model, 64, '^[%w_]+$')
    if not out.model then return nil, 'model' end
    out.voice_id = str(d.voice_id, 30, '^[%w_%-]+$')
    local p = type(d.personality) == 'table' and d.personality or {}
    out.personality = {
        traits = strList(p.traits, 8, 40),
        speech_style = str(p.speech_style, 400) or '',
        values = str(p.values, 250) or '',
        fears = str(p.fears, 250) or '',
        hobbies = strList(p.hobbies, 8, 40),
    }
    out.backstory = str(d.backstory, 1500) or ''
    -- hazır cevap konuları (diyalog motoru "işin nasıl", "ailen var mı" gibi sorularda kullanır)
    local t = type(d.topics) == 'table' and d.topics or {}
    out.topics = {}
    for _, key in ipairs(TOPIC_KEYS) do
        local v = str(t[key], 400)
        if v then out.topics[key] = v end
    end
    local j = type(d.job) == 'table' and d.job or {}
    out.job = { title = str(j.title, 60) or '' }
    local wp = str(j.workplaceId, 64)
    if wp then
        if not Sim.Locations[wp] then return nil, 'workplace' end
        out.job.workplaceId = wp
    end
    local sh = type(j.shift) == 'table' and j.shift or nil
    if sh and Utils.ParseTime(sh.start or '') and Utils.ParseTime(sh['end'] or '') then
        out.job.shift = { start = Utils.FormatTime(Utils.ParseTime(sh.start)), ['end'] = Utils.FormatTime(Utils.ParseTime(sh['end'])) }
    end
    out.job.workdays = {}
    for _, wd in ipairs(type(j.workdays) == 'table' and j.workdays or {}) do
        local n = math.floor(tonumber(wd) or 0)
        if n >= 1 and n <= 7 and not Utils.Contains(out.job.workdays, n) then out.job.workdays[#out.job.workdays + 1] = n end
    end
    table.sort(out.job.workdays)
    out.homeId = str(d.homeId, 64)
    if not out.homeId or not Sim.Locations[out.homeId] then return nil, 'home' end
    if type(d.vehicle) == 'table' and str(d.vehicle.model, 40) then
        local v = d.vehicle
        local color = type(v.color) == 'table' and v.color or {}
        out.vehicle = {
            model = str(v.model, 40, '^[%w_]+$'),
            plate = str(v.plate, 8, '^[%w ]+$') or 'SAKIN',
            color = { Utils.Clamp(math.floor(tonumber(color[1]) or 0), 0, 160), Utils.Clamp(math.floor(tonumber(color[2]) or 0), 0, 160) },
            type = (v.type == 'bike') and 'bike' or 'automobile',
        }
        if not out.vehicle.model then out.vehicle = nil end
    end
    out.favorite_places = {}
    for _, id in ipairs(type(d.favorite_places) == 'table' and d.favorite_places or {}) do
        if type(id) == 'string' and Sim.Locations[id] and #out.favorite_places < 10 then out.favorite_places[#out.favorite_places + 1] = id end
    end
    out.acquaintances = {}
    for _, id in ipairs(type(d.acquaintances) == 'table' and d.acquaintances or {}) do
        if type(id) == 'string' and id ~= out.id and id:match(ID_PATTERN) and #out.acquaintances < 20 then out.acquaintances[#out.acquaintances + 1] = id end
    end
    out.routine_id = str(d.routine_id, 64)
    if not out.routine_id or not Sim.Routines[out.routine_id] then return nil, 'routine' end
    out.phone_number = str(d.phone_number, 15, '^%d+$')
    out.enabled = d.enabled ~= false
    out.profile = validateProfile(d.profile, out.age)
    return out
end

register('saveResident', function(src, d)
    local data, err = validateResident(d)
    if not data then return false, L('err_invalid_field', err) end
    -- telefon benzersiz olmalı
    for _, other in ipairs(Sim.List) do
        if other.id ~= data.id and data.phone_number and other.phone_number == data.phone_number then
            return false, L('err_phone_taken')
        end
    end
    if not data.phone_number then
        local taken = {}
        for _, other in ipairs(Sim.List) do if other.phone_number then taken[other.phone_number] = true end end
        data.phone_number = SC.DB.GeneratePhone(data.id, taken)
    end
    local r = Sim.Residents[data.id]
    if r and not d.resetAppearance and r.model == data.model then
        data.appearance = r.appearance
    end
    -- profil panelden gelmediyse mevcut korunur; güne özel rutin (schedule) panelde düzenlenmez, korunur
    local old = r and type(r.profile) == 'table' and r.profile or nil
    data.profile = data.profile or old or { type = 'citizen' }
    if old and old.schedule and not data.profile.schedule then data.profile.schedule = old.schedule end
    SC.DB.UpsertResident(data)
    if r then
        local respawn = r.model ~= data.model or Utils.JsonEncode(r.vehicle) ~= Utils.JsonEncode(data.vehicle) or d.resetAppearance
        for k, v in pairs(data) do r[k] = v end
        if not data.vehicle then r.vehicle = nil end
        if not data.voice_id then r.voice_id = nil end
        r.appearance = data.appearance
        r.plans = {}
        if SC.Persona then SC.Persona.Invalidate(r) end
        if r.vehicle then
            r.car = r.car or { locationId = r.homeId }
        else
            r.car = nil
        end
        if respawn then
            SC.Spawner.Despawn(r, 'admin_edit')
            SC.Spawner.DeleteVehicle(r)
        end
        if not r.enabled then
            SC.Spawner.Despawn(r, 'disabled')
            SC.Spawner.DeleteVehicle(r)
        end
        r.dirty = true
    else
        local row = MySQL.single.await('SELECT * FROM samy_citizens_residents WHERE id = ?', { data.id })
        if row then Sim.AddResident(SC.DB.DecodeResident(row)) end
    end
    SC.Social.Rebuild()
    SC.Phone.Rebuild()
    SC.Log.Event('Admin', ('%s sakini kaydetti: %s'):format(GetPlayerName(src) or 'console', data.id))
    return true
end)

register('deleteResident', function(src, id)
    if type(id) ~= 'string' or not Sim.Residents[id] then return false, L('err_not_found') end
    local r = Sim.Residents[id]
    SC.Spawner.DeleteVehicle(r)
    SC.Appt.CancelAllFor(id)
    Sim.RemoveResident(id)
    MySQL.update.await('DELETE FROM samy_citizens_residents WHERE id = ?', { id })
    MySQL.update.await('DELETE FROM samy_citizens_relationships WHERE npc_id = ?', { id })
    MySQL.update.await('DELETE FROM samy_citizens_memories WHERE npc_id = ?', { id })
    MySQL.update.await('DELETE FROM samy_citizens_daily_log WHERE npc_id = ?', { id })
    SC.Social.Rebuild()
    SC.Phone.Rebuild()
    SC.Log.Event('Admin', ('%s sakini sildi: %s'):format(GetPlayerName(src) or 'console', id))
    return true
end)

register('setStatus', function(src, payload)
    local r = type(payload) == 'table' and Sim.Residents[payload.id]
    if not r then return false, L('err_not_found') end
    local st = payload.status
    local now = Clock.Now()
    if st == 'alive' then
        Sim.Discharge(r, now)
    elseif st == 'hospital' then
        SC.Spawner.Despawn(r, 'admin')
        Sim.Hospitalize(r, L('log_admin_hospital'))
    elseif st == 'jailed' then
        SC.Spawner.Despawn(r, 'admin')
        Sim.ReleasePoint(r)
        r.status = 'jailed'
        r.status_until = now + 1440 * math.max(1, math.floor(tonumber(payload.days) or 1))
        r.state = { activity = 'hospital', locationId = r.homeId, startedAt = now, inside = true }
        Sim.Changed(r, 'jailed')
    elseif st == 'moved_away' then
        SC.Spawner.Despawn(r, 'admin')
        r.status = 'moved_away'
        r.status_until = 0
        Sim.Changed(r, 'moved_away')
    else
        return false, 'status'
    end
    r.dirty = true
    return true
end)

-- ---------------------------------------------------------------------
-- Konumlar
-- ---------------------------------------------------------------------
local function locationPayload(loc)
    local points = {}
    for i, p in ipairs(loc.points or {}) do
        points[i] = { coords = Utils.VecToTable(p.coords), scenario = p.scenario, tags = p.tags or {} }
    end
    return {
        id = loc.id, label = loc.label, type = loc.type, area = loc.area, public = loc.public,
        door = Utils.VecToTable(loc.door), parking = loc.parking and Utils.VecToTable(loc.parking) or nil,
        points = points, hours = loc.hours, aliases = loc.aliases or {},
    }
end

register('locations', function(src)
    local out = {}
    for _, loc in pairs(Sim.Locations) do out[#out + 1] = locationPayload(loc) end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end)

register('saveLocation', function(src, d)
    if type(d) ~= 'table' then return false, 'data' end
    local loc = {}
    loc.id = str(d.id, 64, ID_PATTERN)
    loc.label = str(d.label, 100)
    if not loc.id or not loc.label then return false, L('err_invalid_field', 'id/label') end
    loc.type = Utils.Contains(SC.LocationTypes, d.type) and d.type or 'other'
    loc.area = str(d.area, 50, ID_PATTERN) or ''
    loc.public = d.public ~= false
    loc.door = vec4From(d.door)
    if not loc.door then return false, L('err_invalid_field', 'door') end
    loc.parking = vec4From(d.parking)
    loc.points = {}
    for _, p in ipairs(type(d.points) == 'table' and d.points or {}) do
        local c = vec4From(p.coords)
        if c and #loc.points < 24 then
            loc.points[#loc.points + 1] = {
                coords = c,
                scenario = str(p.scenario, 64, '^[%u_]+$') or 'WORLD_HUMAN_STAND_IMPATIENT',
                tags = strList(p.tags, 8, 20),
            }
        end
    end
    if type(d.hours) == 'table' and Utils.ParseTime(d.hours.open or '') and Utils.ParseTime(d.hours.close or '') then
        loc.hours = { open = Utils.FormatTime(Utils.ParseTime(d.hours.open)), close = Utils.FormatTime(Utils.ParseTime(d.hours.close)) }
    end
    loc.aliases = strList(d.aliases, 10, 40)
    SC.DB.UpsertLocation(loc)
    Sim.Locations[loc.id] = loc
    Sim.Occupancy[loc.id] = {}
    for _, r in ipairs(Sim.List) do
        if r.state and r.state.locationId == loc.id and r.state.activity ~= 'commute' then
            r.state.pointIndex = nil
            Sim.PlaceAtLocation(r, r.state.activity)
            r.state.emerge = nil
            Sim.Changed(r, 'location_edit')
        end
        r.plans = {}
    end
    SC.Log.Event('Admin', ('%s konum kaydetti: %s'):format(GetPlayerName(src) or 'console', loc.id))
    return true
end)

register('deleteLocation', function(src, id)
    if type(id) ~= 'string' or not Sim.Locations[id] then return false, L('err_not_found') end
    for _, r in ipairs(Sim.List) do
        if r.homeId == id or (r.job and r.job.workplaceId == id) then
            return false, L('err_location_in_use', r.firstname .. ' ' .. r.lastname)
        end
    end
    MySQL.update.await('DELETE FROM samy_citizens_locations WHERE id = ?', { id })
    Sim.Locations[id] = nil
    Sim.Occupancy[id] = nil
    for _, r in ipairs(Sim.List) do
        r.plans = {}
        if r.state and (r.state.locationId == id or r.state.toLocationId == id) then Sim.PlaceFresh(r, Clock.Now()) Sim.Changed(r, 'location_deleted') end
        for i = #(r.favorite_places or {}), 1, -1 do
            if r.favorite_places[i] == id then table.remove(r.favorite_places, i) end
        end
    end
    return true
end)

-- ---------------------------------------------------------------------
-- Rutinler
-- ---------------------------------------------------------------------
local function validateBlocks(list)
    local out = {}
    if type(list) ~= 'table' then return out end
    for _, b in ipairs(list) do
        if type(b) == 'table' and validTimeToken(b.from) and validTimeToken(b.to) and #out < 30 then
            local act = b.activity
            if SC.Activities[act] or SC.FlexActivities[act] then
                local loc = type(b.location) == 'string' and b.location or 'home'
                local okLoc = loc == 'home' or loc == 'work' or loc == 'flex:lunch' or loc == 'flex:free'
                    or (loc:sub(1, 4) == 'fav:' and Utils.Contains(SC.LocationTypes, loc:sub(5))) or Sim.Locations[loc] ~= nil
                if okLoc then
                    local block = { from = Utils.Trim(b.from), to = Utils.Trim(b.to), activity = act, location = loc }
                    if b.firm == true then block.firm = true end
                    if type(b.roam) == 'table' then
                        block.roam = {
                            types = strList(b.roam.types, 12, 20),
                            slot = Utils.Clamp(math.floor(tonumber(b.roam.slot) or 150), 60, 600),
                            away = Utils.Clamp(math.floor(tonumber(b.roam.away) or 90), 20, 590),
                            activity = SC.Activities[b.roam.activity] and b.roam.activity or 'deliver',
                        }
                    end
                    out[#out + 1] = block
                end
            end
        end
    end
    return out
end

register('routines', function(src)
    local out = {}
    for id, rt in pairs(Sim.Routines) do
        local users = {}
        for _, r in ipairs(Sim.List) do if r.routine_id == id then users[#users + 1] = r.firstname end end
        out[#out + 1] = { id = id, label = rt.label, workday = rt.workday, offday = rt.offday, users = users }
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end)

register('saveRoutine', function(src, d)
    if type(d) ~= 'table' then return false, 'data' end
    local rt = { id = str(d.id, 64, ID_PATTERN), label = str(d.label, 100) }
    if not rt.id or not rt.label then return false, L('err_invalid_field', 'id/label') end
    rt.workday = validateBlocks(d.workday)
    rt.offday = validateBlocks(d.offday)
    if #rt.workday == 0 and #rt.offday == 0 then return false, L('err_invalid_field', 'blocks') end
    if #rt.workday == 0 then rt.workday = rt.offday end
    if #rt.offday == 0 then rt.offday = rt.workday end
    SC.DB.UpsertRoutine(rt)
    Sim.Routines[rt.id] = rt
    for _, r in ipairs(Sim.List) do
        if r.routine_id == rt.id then r.plans = {} end
    end
    return true
end)

register('deleteRoutine', function(src, id)
    if type(id) ~= 'string' or not Sim.Routines[id] then return false, L('err_not_found') end
    for _, r in ipairs(Sim.List) do
        if r.routine_id == id then return false, L('err_routine_in_use', r.firstname) end
    end
    MySQL.update.await('DELETE FROM samy_citizens_routines WHERE id = ?', { id })
    Sim.Routines[id] = nil
    return true
end)

-- Bir sakinin belirli bir gün için planını önizle
register('previewPlan', function(src, payload)
    local r = type(payload) == 'table' and Sim.Residents[payload.id]
    if not r then return false end
    local day = Clock.Day() + Utils.Clamp(math.floor(tonumber(payload.offset) or 0), -1, 6)
    return { day = Clock.DayName(day * 1440 + 720), plan = Sim.GetPlanView(r, day, false) }
end)

-- ---------------------------------------------------------------------
-- İlişkiler & anılar
-- ---------------------------------------------------------------------
register('memories', function(src, payload)
    if type(payload) ~= 'table' or type(payload.npcId) ~= 'string' then return false end
    return SC.Memory.ListForPair(payload.npcId, payload.citizenid, payload.archived == true)
end)

register('deleteMemory', function(src, id)
    id = tonumber(id)
    if not id then return false end
    SC.Memory.Delete(id)
    return true
end)

register('resetRelationship', function(src, payload)
    if type(payload) ~= 'table' or type(payload.npcId) ~= 'string' or type(payload.citizenid) ~= 'string' then return false end
    SC.Rel.Reset(payload.npcId, payload.citizenid)
    SC.Memory.DeletePair(payload.npcId, payload.citizenid)
    SC.Appt.CancelAllFor(payload.npcId, payload.citizenid)
    SC.Log.Event('Admin', ('%s ilişkiyi sıfırladı: %s <-> %s'):format(GetPlayerName(src) or 'console', payload.npcId, payload.citizenid))
    return true
end)

register('setRelationship', function(src, payload)
    if type(payload) ~= 'table' or type(payload.npcId) ~= 'string' or type(payload.citizenid) ~= 'string' then return false end
    if not Sim.Residents[payload.npcId] then return false end
    local row = SC.Rel.Set(payload.npcId, payload.citizenid, type(payload.fields) == 'table' and payload.fields or {})
    SC.Rel.Flush(true)
    return SC.Rel.PublicView(row)
end)

-- Diyalog testi: bir cümlenin hangi niyete düştüğünü ve sakinin ne cevap vereceğini gösterir (yan etkisiz)
-- Diyalog testi: aynı sakin + aşama için bağlam (son konu, bekleyen soru) denemeler arasında korunur
local testStates = {}
register('testDialogue', function(src, payload)
    if type(payload) ~= 'table' or type(payload.text) ~= 'string' then return false end
    local r = Sim.Residents[payload.id or '']
    if not r then return false, L('err_not_found') end
    local stage = SC.StageOrder[payload.stage] and payload.stage or 'stranger'
    local ci = src ~= 0 and SC.Bridge.GetCharInfo(src) or nil
    local name = ci and Utils.Trim(('%s %s'):format(ci.firstname or '', ci.lastname or '')) or 'Test Oyuncu'
    local key = r.id .. '|' .. stage
    local st = testStates[src]
    if payload.reset or not st or st.key ~= key then
        st = { key = key, state = {} }
        testStates[src] = st
    end
    local res = SC.Dialogue.Test(r, Utils.SanitizeText(payload.text, 300), stage, name, st.state)
    return res
end)

-- ---------------------------------------------------------------------
-- Işınlanma / çağırma / harita
-- ---------------------------------------------------------------------
register('teleport', function(src, id)
    local r = Sim.Residents[id or '']
    if not r then return false end
    local pos = SC.Spawner.GetPedCoords(r) or Sim.GetPosition(r)
    if not pos then
        local loc = Sim.Locations[r.state.locationId or r.homeId]
        pos = loc and loc.door
    end
    if not pos then return false end
    return { x = pos.x, y = pos.y, z = pos.z }
end)

register('summon', function(src, id)
    local r = Sim.Residents[id or '']
    if not r or r.status ~= 'alive' then return false end
    local ped = GetPlayerPed(src)
    local pc = GetEntityCoords(ped)
    local h = math.rad(GetEntityHeading(ped))
    local pos = vector3(pc.x - math.sin(h) * 1.8, pc.y + math.cos(h) * 1.8, pc.z)
    if r.convo then SC.Convo.End(r, 'admin') end
    SC.Spawner.Despawn(r, 'summon')
    Sim.SetFreePos(r, pos, 'idle')
    Sim.SetOverride(r, { type = 'summoned', pos = Utils.VecToTable(pos), untilMs = GetGameTimer() + 90000 })
    return true
end)

register('blips', function(src)
    local out = {}
    for _, r in ipairs(Sim.List) do
        if r.enabled and r.status == 'alive' then
            local pos = SC.Spawner.GetPedCoords(r) or Sim.GetPosition(r)
            if pos then
                out[#out + 1] = {
                    id = r.id, name = r.firstname .. ' ' .. r.lastname, x = pos.x, y = pos.y, z = pos.z,
                    physical = SC.Spawner.peds[r.id] ~= nil, activity = L('act.' .. tostring(r.state.activity)),
                    commute = r.state.activity == 'commute', inside = r.state.inside == true,
                }
            end
        end
    end
    return out
end)

register('debugInfo', function(src)
    local out = {}
    local cid = src ~= 0 and SC.Bridge.GetCitizenId(src) or nil
    local ppos = src ~= 0 and SC.NPC.PlayerCoords(src) or nil
    for rid, phys in pairs(SC.Spawner.peds) do
        local r = Sim.Residents[rid]
        -- sadece yakındaki NPC'ler için ayrıntı (ağ yükü)
        if r and (not ppos or not phys.coords or Utils.Dist(ppos, phys.coords) < 80.0) then
            local rel = cid and SC.Rel.Peek(r.id, cid) or nil
            local comp = SC.NPC.Companion(r)
            local data = SC.NPC.Data(r, cid) or {}
            local ctx = cid and SC.Context.Peek(r.id, cid) or nil
            local veh = data.currentVehicle
            out[tostring(phys.netId)] = {
                id = r.id, name = r.firstname .. ' ' .. r.lastname, activity = r.state.activity,
                task = phys.taskKind, convo = r.convo ~= nil, override = r.override and r.override.type or nil,
                state = data.state, mood = data.mood, lod = phys.lod,
                relationship = rel and SC.Rel.StageLabel(SC.RelXP.DisplayStage(rel)) or '-', xp = rel and rel.xp or 0,
                destination = data.destination or '-', vehicle = veh and ('#' .. tostring(veh)) or '-',
                current = comp and ('Companion:' .. tostring(comp.phase)) or (r.interaction and ('Anim:' .. r.interaction.id)) or L('act.' .. tostring(r.state.activity)),
                lastIntent = (ctx and ctx.lastIntent) or r.lastIntent or '-',
                schedule = data.schedule and (data.schedule.from .. '-' .. data.schedule.to .. ' ' .. L('actn.' .. tostring(data.schedule.activity))) or '-',
            }
        end
    end
    return out
end)

-- ---------------------------------------------------------------------
-- Rastgele sakin taslağı (yapay zekâsız: isim, kişilik ve geçmiş havuzlarından)
-- Taslak kaydedilmez; panelde düzenleyip "Kaydet" ile eklenir.
-- ---------------------------------------------------------------------
local JOB_CATEGORIES = {
    service = { titles = { 'Garson', 'Kasiyer', 'Barista', 'Aşçı yardımcısı' }, types = { 'fastfood', 'cafe', 'restaurant', 'bar' }, routine = 'day_worker', shift = { '10:00', '18:00' }, workdays = { 1, 2, 3, 5, 6 } },
    office = { titles = { 'Muhasebeci', 'Sekreter', 'Sigortacı', 'Emlakçı' }, types = { 'office' }, routine = 'day_worker', shift = { '09:00', '18:00' }, workdays = { 1, 2, 3, 4, 5 } },
    health = { titles = { 'Hemşire', 'Sağlık teknisyeni' }, types = { 'hospital' }, routine = 'night_nurse', shift = { '19:00', '07:00' }, workdays = { 1, 3, 5 } },
    mechanic = { titles = { 'Oto tamircisi', 'Kaportacı' }, types = { 'garage' }, routine = 'day_worker', shift = { '08:00', '17:00' }, workdays = { 1, 2, 3, 4, 5, 6 } },
    driver = { titles = { 'Taksi şoförü', 'Kurye' }, types = { 'depot' }, routine = 'day_worker_roam', shift = { '10:00', '19:00' }, workdays = { 1, 2, 3, 4, 5, 6 } },
    student = { titles = { 'Üniversite öğrencisi' }, types = { 'school' }, routine = 'student', shift = { '09:00', '15:00' }, workdays = { 1, 2, 3, 4, 5 } },
    retired = { titles = { 'Emekli memur', 'Emekli öğretmen' }, types = {}, routine = 'retiree', workdays = { 1, 2, 3, 4, 5 } },
    nightlife = { titles = { 'Barmen', 'Güvenlik görevlisi' }, types = { 'bar' }, routine = 'night_bar', shift = { '18:00', '02:00' }, workdays = { 3, 4, 5, 6, 7 } },
    outdoor = { titles = { 'Balıkçı' }, types = { 'pier', 'park', 'beach' }, routine = 'fisherman', shift = { '05:00', '12:00' }, workdays = { 1, 2, 3, 4, 5, 6 } },
}

local MODEL_POOLS = {
    male = {
        young = { 'a_m_y_hipster_01', 'a_m_y_business_01', 'a_m_y_business_03', 'a_m_y_beach_01', 'a_m_y_genstreet_01', 'a_m_y_stbla_02' },
        middle = { 'a_m_m_business_01', 'a_m_m_eastsa_01', 'a_m_m_bevhills_01', 'a_m_m_salton_02', 'a_m_m_socenlat_01' },
        old = { 'a_m_o_genstreet_01', 'a_m_o_soucent_01', 'a_m_o_ktown_01' },
    },
    female = {
        young = { 'a_f_y_hipster_01', 'a_f_y_hipster_02', 'a_f_y_business_01', 'a_f_y_vinewood_01', 'a_f_y_genhot_01', 'a_f_y_tourist_01' },
        middle = { 'a_f_m_business_02', 'a_f_m_bevhills_01', 'a_f_m_eastsa_01', 'a_f_m_soucent_01' },
        old = { 'a_f_o_genstreet_01', 'a_f_o_soucent_01', 'a_f_o_ktown_01' },
    },
}

local NAMES = {
    male = { 'Ahmet', 'Mehmet', 'Mustafa', 'Burak', 'Cem', 'Kerem', 'Oğuz', 'Serkan', 'Tolga', 'Volkan', 'Kaan', 'Arda', 'Onur', 'Barış', 'Hakan', 'Yusuf', 'Selim', 'Tarık', 'Umut', 'Levent' },
    female = { 'Ayşe', 'Fatma', 'Zehra', 'Merve', 'Esra', 'Buse', 'Ceren', 'Damla', 'Ece', 'Gizem', 'İrem', 'Nazlı', 'Pınar', 'Seda', 'Tuğba', 'Yasemin', 'Gül', 'Derya', 'Özge', 'Melis' },
}
local SURNAMES = { 'Yılmaz', 'Kaya', 'Demir', 'Şahin', 'Çelik', 'Yıldırım', 'Aydın', 'Özdemir', 'Doğan', 'Kılıç', 'Aslan', 'Çetin', 'Kara', 'Kurt', 'Özkan', 'Şimşek', 'Polat', 'Korkmaz', 'Erdem', 'Güler' }
local TRAITS = { 'neşeli', 'sessiz', 'meraklı', 'şüpheci', 'esprili', 'sabırsız', 'sakin', 'konuşkan', 'çekingen', 'iyimser', 'alaycı',
    'titiz', 'dağınık', 'cömert', 'inatçı', 'duygusal', 'pratik', 'hayalperest', 'dürüst', 'huysuz', 'nazik', 'enerjik' }
local HOBBIES = { 'futbol izlemek', 'kitap okumak', 'yemek yapmak', 'balık tutmak', 'fotoğraf çekmek', 'video oyunları', 'bahçecilik',
    'koşu', 'gitar çalmak', 'satranç', 'dans', 'film izlemek', 'araba modifiye', 'yürüyüş', 'yoga', 'resim yapmak' }
local SPEECH = {
    'Sakin ve kısa konuşur, fazla detaya girmez.',
    "Hızlı ve samimi konuşur; 'yaa', 'kanka' gibi sözler kullanır.",
    "Kibar ve resmî konuşur; 'efendim' der.",
    'Esprili konuşur, her şeye bir laf yetiştirir.',
    'Çekingen konuşur, cümlelerini yarım bırakır.',
    "Bol bol konuşur; 'bak şimdi' diye söze girer, 'dostum' diye hitap eder.",
}
local ORIGINS = { 'Paleto Bay', 'Sandy Shores', 'Harmony', 'Chumash', 'Grapeseed', 'Liberty City', 'San Fierro', 'Vice City', 'Los Santos' }
local BACKSTORIES = {
    "%origin% doğumlu. Birkaç yıl önce Los Santos'a taşındı ve %job% olarak çalışmaya başladı. Boş zamanlarında %hobby% ile uğraşıyor.",
    'Çocukluğu %origin% tarafında geçti. Şehre iş için geldi; şimdi %job% olarak geçimini sağlıyor. En büyük keyfi %hobby%.',
    'Kalabalık bir ailede büyüdü, aslen %origin% doğumlu. %job% olarak çalışıyor ve işini ciddiye alıyor. Hafta sonları %hobby% için zaman ayırıyor.',
}
local TOPICS = {
    family = { 'Ailem %origin% tarafında yaşıyor, sık sık arıyorum.', 'Bekârım, ailemle aram iyi.', 'Evliyim, küçük bir kızım var.', 'Geçen yıl ailemin yanından ayrılıp kendi evime çıktım.' },
    dream = { 'Bir gün kendi işimi kurmak istiyorum.', 'Deniz kenarında küçük bir ev almak hayalim.', 'Dünyayı gezmek istiyorum.', 'Biraz para biriktirip memlekete dönmek istiyorum.' },
    food = { 'Ev yemeği severim, özellikle kuru fasulye.', 'Hamburger derseniz hayır demem.', 'Deniz ürünlerine bayılırım.', 'Tatlıya zaafım var.' },
    music = { 'Arabesk dinlerim, dert ortağım.', 'Eski rock gruplarını severim.', 'Radyoda ne çıkarsa dinlerim.', 'Genelde rap dinliyorum.' },
    work_opinion = { 'İşim yorucu ama seviyorum.', 'Maaş az, iş çok... ama idare ediyoruz.', 'İş arkadaşlarım iyi, o yüzden katlanıyorum.' },
    secret = { 'Aslında şarkı söylemeyi çok seviyorum ama kimse bilmiyor.', 'Bir süredir iş değiştirmeyi düşünüyorum, kimseye söyleme.', 'Borçlarım var, biraz zor günler geçiriyorum.' },
}
local CARS = { 'asea', 'blista', 'primo', 'emperor', 'panto', 'glendale', 'ingot', 'premier' }

local function pickFrom(list)
    if not list or #list == 0 then return nil end
    return list[math.random(#list)]
end

local function pickMany(list, n)
    local pool = Utils.DeepCopy(list)
    local out = {}
    while #out < n and #pool > 0 do
        out[#out + 1] = table.remove(pool, math.random(#pool))
    end
    return out
end

register('generate', function(src)
    local cats = {}
    for k in pairs(JOB_CATEGORIES) do cats[#cats + 1] = k end
    table.sort(cats)
    local cat = pickFrom(cats)
    local spec = JOB_CATEGORIES[cat]
    local gender = math.random() < 0.5 and 'female' or 'male'
    local age = cat == 'student' and math.random(19, 25) or (cat == 'retired' and math.random(62, 78) or math.random(24, 58))
    local bracket = age < 32 and 'young' or (age < 58 and 'middle' or 'old')
    local model = pickFrom(MODEL_POOLS[gender][bracket])
    if cat == 'health' and gender == 'female' then model = 's_f_y_scrubs_01' end
    if cat == 'mechanic' and gender == 'male' then model = 's_m_y_xmech_02' end
    local firstname = pickFrom(NAMES[gender])
    local lastname = pickFrom(SURNAMES)
    local title = pickFrom(spec.titles)
    local origin = pickFrom(ORIGINS)
    local hobbies = pickMany(HOBBIES, 3)

    -- ev: en az sakini olan ev
    local homeCounts, homes = {}, {}
    for id, loc in pairs(Sim.Locations) do
        if loc.type == 'home' then
            homes[#homes + 1] = id
            homeCounts[id] = 0
        end
    end
    for _, r in ipairs(Sim.List) do if homeCounts[r.homeId] then homeCounts[r.homeId] = homeCounts[r.homeId] + 1 end end
    table.sort(homes, function(a, b)
        if homeCounts[a] == homeCounts[b] then return a < b end
        return homeCounts[a] < homeCounts[b]
    end)
    local work = pickFrom(Sim.FindLocationsByType(spec.types, false))
    local publics = {}
    for id, loc in pairs(Sim.Locations) do if loc.public and (not work or id ~= work.id) then publics[#publics + 1] = id end end
    local favs = pickMany(publics, 3)

    local baseId = slugify(firstname .. '_' .. lastname)
    local id, n = baseId ~= '' and baseId or 'sakin', 1
    while Sim.Residents[id] do
        n = n + 1
        id = baseId .. '_' .. n
    end
    local vehicle
    if age >= 25 and cat ~= 'student' and math.random() < 0.55 then
        vehicle = {
            model = pickFrom(CARS),
            plate = (Utils.Ascii(firstname):upper():gsub('[^%w]', ''):sub(1, 5)) .. tostring(math.random(100, 999)),
            color = { math.random(0, 150), 0 }, type = 'automobile',
        }
    end
    local jobLower = SC.Dialogue.Lowerfirst(title)
    local function fillBio(s)
        return (s:gsub('%%origin%%', origin):gsub('%%job%%', jobLower):gsub('%%hobby%%', hobbies[1] or 'yürüyüş'))
    end
    local bioTemplate = pickFrom(BACKSTORIES)
    if cat == 'retired' then
        bioTemplate = '%origin% doğumlu. Uzun yıllar çalıştıktan sonra emekli oldu; artık günleri %hobby% ve mahalle sohbetleriyle geçiyor.'
    elseif cat == 'student' then
        bioTemplate = "%origin% doğumlu. Üniversite için Los Santos'a geldi, küçük bir dairede kalıyor. Boş zamanlarında %hobby% ile uğraşıyor."
    end
    local backstory = SC.Dialogue.Capitalize(fillBio(bioTemplate))
    local topics = { origin = origin .. ' doğumluyum, sonra buraya taşındım.' }
    for key, list in pairs(TOPICS) do topics[key] = fillBio(pickFrom(list)) end
    if cat == 'retired' then
        topics.job = 'Emekliyim artık; yıllarca ' .. (jobLower:gsub('^emekli ', '')) .. ' olarak çalıştım.'
        topics.work_opinion = 'Çalıştığım yılları bazen özlüyorum ama emeklilik de güzelmiş.'
    elseif cat == 'student' then
        topics.work_opinion = 'Dersler yoğun ama idare ediyorum, vizeler yaklaşınca zorlanıyorum.'
    end
    return {
        id = id, firstname = firstname, lastname = lastname, age = age, gender = gender, model = model,
        personality = {
            traits = pickMany(TRAITS, 5), speech_style = pickFrom(SPEECH),
            values = pickFrom({ 'Aile, dürüstlük', 'Özgürlük, eğlence', 'Emek, sadakat', 'Başarı, düzen' }),
            fears = pickFrom({ 'Yalnız kalmak', 'İşini kaybetmek', 'Hastalık', 'Borç' }),
            hobbies = hobbies,
        },
        backstory = backstory,
        topics = topics,
        job = {
            title = title,
            workplaceId = work and work.id or nil,
            shift = spec.shift and { start = spec.shift[1], ['end'] = spec.shift[2] } or nil,
            workdays = spec.workdays or {},
        },
        homeId = homes[1],
        vehicle = vehicle,
        favorite_places = favs,
        acquaintances = {},
        routine_id = Sim.Routines[spec.routine] and spec.routine or 'day_worker',
        enabled = true,
    }
end)


-- ---------------------------------------------------------------------
-- Komutlar
-- ---------------------------------------------------------------------
RegisterCommand(Config.Admin.Command, function(src)
    if src == 0 then
        print('[samy-citizens] Bu komut oyun içinden kullanılır.')
        return
    end
    if not Admin.IsAdmin(src) then
        TriggerClientEvent('samy-citizens:client:notify', src, L('err_no_permission'), 'error')
        return
    end
    TriggerClientEvent('samy-citizens:client:openAdmin', src)
end, false)

RegisterCommand(Config.Admin.DebugCommand, function(src)
    if src == 0 then return end
    if not Admin.IsAdmin(src) then
        TriggerClientEvent('samy-citizens:client:notify', src, L('err_no_permission'), 'error')
        return
    end
    TriggerClientEvent('samy-citizens:client:toggleDebug', src)
end, false)
