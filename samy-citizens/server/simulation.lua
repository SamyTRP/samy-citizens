--[[
    SOYUT KATMAN — rutin motoru
    Her sakinin durumu sunucuda tutulur; ped yoktur, sadece veri.
    state = { activity, locationId, fromLocationId, toLocationId, fromPos, toPos, startedAt, eta, mode, pointIndex, inside, pos }
    Zamanlar "mutlak oyun dakikası" (SC.Clock.Now()).
]]
local Utils = SC.Utils
local Clock = SC.Clock
local Activities = SC.Activities

local Sim = {}
SC.Sim = Sim

Sim.Residents = {}
Sim.List = {}
Sim.Locations = {}
Sim.Routines = {}
Sim.Occupancy = {}
Sim.dayListeners = {}
Sim.lastTick = nil
Sim.currentDay = nil

-- =====================================================================
-- KONUMLAR
-- =====================================================================
function Sim.GetLocation(id)
    return id and Sim.Locations[id] or nil
end

function Sim.LocationLabel(id)
    local loc = id and Sim.Locations[id]
    return loc and loc.label or L('loc_unknown')
end

function Sim.IsOpen(loc, mod)
    if not loc or type(loc.hours) ~= 'table' then return true end
    local o, c = Utils.ParseTime(loc.hours.open), Utils.ParseTime(loc.hours.close)
    if not o or not c then return true end
    mod = math.floor(mod) % 1440
    if c > o then return mod >= o and mod < c end
    return mod >= o or mod < c
end

-- Serbest metinden konum bulur (oyuncu cümlesi, SMS): id, etiket ve takma adlarla bulanık eşleşme
function Sim.FindLocation(text, onlyPublic)
    if type(text) ~= 'string' or text == '' then return nil end
    local exact = Sim.Locations[text]
    if exact and (not onlyPublic or exact.public) then return exact end
    local q = Utils.Fold(text)
    local best, bestScore = nil, 0
    for id, loc in pairs(Sim.Locations) do
        if not onlyPublic or loc.public then
            local cands = { Utils.Fold(id), Utils.Fold(loc.label) }
            for _, a in ipairs(loc.aliases or {}) do cands[#cands + 1] = Utils.Fold(a) end
            local score = 0
            for _, c in ipairs(cands) do
                if c == q then
                    score = math.max(score, 100)
                elseif #c >= 3 and q:find(c, 1, true) then
                    score = math.max(score, 50 + #c)
                elseif #q >= 3 and c:find(q, 1, true) then
                    score = math.max(score, 40 + #q)
                end
            end
            if score > bestScore then best, bestScore = loc, score end
        end
    end
    return best
end

function Sim.FindLocationsByType(types, onlyPublic)
    local set = {}
    for _, t in ipairs(types or {}) do set[t] = true end
    local out = {}
    for _, loc in pairs(Sim.Locations) do
        if set[loc.type] and (not onlyPublic or loc.public) then out[#out + 1] = loc end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function Sim.FindHospital()
    for _, loc in pairs(Sim.Locations) do
        if loc.type == 'hospital' then return loc end
    end
    return nil
end

-- =====================================================================
-- AKTİVİTE NOKTALARI
-- =====================================================================
local function tagsMatch(pointTags, actTags)
    for _, t in ipairs(pointTags or {}) do
        for _, a in ipairs(actTags or {}) do
            if t == a then return true end
        end
    end
    return false
end

function Sim.ReleasePoint(r)
    local st = r.state
    if st and st.locationId and st.pointIndex then
        local occ = Sim.Occupancy[st.locationId]
        if occ and occ[st.pointIndex] == r.id then occ[st.pointIndex] = nil end
    end
    if st then st.pointIndex = nil end
end

function Sim.AssignPoint(r, loc, activity, rng)
    local def = Activities[activity]
    if not def or def.inside or not def.tags then return nil end
    local chance = Config.Routine.OutsideChance and Config.Routine.OutsideChance[activity]
    if chance and chance < 1.0 then
        local roll = rng and rng() or math.random()
        if roll > chance then return nil end
    end
    local occ = Sim.Occupancy[loc.id]
    if not occ then
        occ = {}
        Sim.Occupancy[loc.id] = occ
    end
    local free = {}
    for i, p in ipairs(loc.points or {}) do
        if tagsMatch(p.tags, def.tags) and (not occ[i] or occ[i] == r.id) then free[#free + 1] = i end
    end
    if #free == 0 then return nil end
    local idx = free[rng and rng(#free) or math.random(#free)]
    occ[idx] = r.id
    return idx
end

function Sim.PlaceAtLocation(r, activity)
    local st = r.state
    local wasInside = st.inside
    st.inside = true
    st.atDoor = nil
    st.pointIndex = nil
    local loc = Sim.Locations[st.locationId]
    if not loc then return end
    local rng = Utils.Rng(Utils.Hash(r.id .. ':' .. activity .. ':' .. tostring(st.startedAt)))
    local idx = Sim.AssignPoint(r, loc, activity, rng)
    if idx then
        st.pointIndex = idx
        st.inside = false
    elseif Activities[activity] and Activities[activity].neverInside then
        st.inside = false
        st.atDoor = true
    end
    -- binadan çıkıyorsa fiziksel ped kapıda belirsin
    if wasInside and not st.inside then st.emerge = true end
end

function Sim.PointCoords(r)
    local st = r.state
    local loc = st and Sim.Locations[st.locationId]
    if not loc then return nil, nil end
    if st.pointIndex and loc.points[st.pointIndex] then
        return loc.points[st.pointIndex].coords, loc.points[st.pointIndex]
    end
    return loc.door, nil
end

-- =====================================================================
-- KONUM / SPAWN BİLGİSİ
-- =====================================================================
function Sim.CommuteProgress(st, now)
    local total = (st.eta or 0) - (st.startedAt or 0)
    if total <= 0 then return 1.0 end
    return Utils.Clamp((now - st.startedAt) / total, 0.0, 1.0)
end

function Sim.GetPosition(r, now)
    now = now or Clock.Now()
    local st = r.state
    if not st then return nil end
    if st.activity == 'commute' and st.fromPos and st.toPos then
        local p = Sim.CommuteProgress(st, now)
        local a, b = st.fromPos, st.toPos
        return vector3(Utils.Lerp(a.x, b.x, p), Utils.Lerp(a.y, b.y, p), Utils.Lerp(a.z, b.z, p))
    end
    if st.pos then return Utils.ToVec3(st.pos) end
    local c = Sim.PointCoords(r)
    if c then return vector3(c.x, c.y, c.z) end
    return nil
end

--[[
    Fiziksel katmana: bu sakin şu an görünür bir yerde mi, nerede?
    dönüş: { kind = 'point'|'door'|'walk'|'car'|'pos', pos = vector3, heading } | nil
]]
function Sim.GetSpawnInfo(r, now)
    if not r.enabled or r.status ~= 'alive' then return nil end
    local st = r.state
    if not st then return nil end
    now = now or Clock.Now()
    if st.activity == 'commute' then
        if st.mode == 'transit' then return nil end
        local pos = Sim.GetPosition(r, now)
        if not pos then return nil end
        return { kind = st.mode == 'car' and 'car' or 'walk', pos = pos, heading = Utils.HeadingTo(pos, st.toPos) }
    end
    if st.pos then
        return { kind = 'pos', pos = Utils.ToVec3(st.pos), heading = st.pos.w or 0.0 }
    end
    if st.inside then return nil end
    local c, point = Sim.PointCoords(r)
    if not c then return nil end
    if point and st.emerge then
        local loc = Sim.Locations[st.locationId]
        return { kind = 'point', pos = vector3(loc.door.x, loc.door.y, loc.door.z), heading = loc.door.w, emerge = true }
    end
    return { kind = point and 'point' or 'door', pos = vector3(c.x, c.y, c.z), heading = c.w or 0.0 }
end

-- =====================================================================
-- ULAŞIM
-- =====================================================================
function Sim.ChooseMode(r, fromLocId, dist)
    if dist <= (Config.Travel.WalkMaxDistance or 200.0) then return 'walk' end
    if r.vehicle and r.car and not r.car.missing and fromLocId and r.car.locationId == fromLocId then return 'car' end
    return 'transit'
end

function Sim.TravelMinutes(mode, dist)
    local T = Config.Travel
    local speed = (mode == 'car' and T.CarSpeed) or (mode == 'walk' and T.WalkSpeed) or T.TransitSpeed
    local factor = mode == 'walk' and 1.1 or (T.DetourFactor or 1.35)
    local secs = dist * factor / math.max(0.5, speed or 10.0)
    return math.max(T.MinTravelMinutes or 5, math.ceil(Clock.RealSecondsToGameMinutes(secs)))
end

function Sim.EstimateTravel(r, fromLocId, fromPos, toLocId)
    local to = Sim.Locations[toLocId]
    if not to then return 0, 'walk' end
    local fp = fromPos
    if not fp then
        local from = fromLocId and Sim.Locations[fromLocId]
        fp = from and from.door or Sim.GetPosition(r)
    end
    if not fp then return 0, 'walk' end
    local dist = Utils.Dist(fp, to.door)
    local mode = Sim.ChooseMode(r, fromLocId, dist)
    return Sim.TravelMinutes(mode, dist), mode
end

local function currentPos(r, now)
    if SC.Spawner then
        local p = SC.Spawner.GetPedCoords(r)
        if p then return p end
    end
    local pos = Sim.GetPosition(r, now)
    if pos then return pos end
    local home = Sim.Locations[r.homeId]
    return home and home.door or vector3(0.0, 0.0, 0.0)
end

-- =====================================================================
-- RUTİN PLANLAMA
-- =====================================================================
local function resolveTime(tok, shift)
    if type(tok) == 'number' then return math.floor(tok) end
    if type(tok) ~= 'string' then return nil end
    local t = Utils.ParseTime(tok)
    if t then return t end
    local name, sign, num = tok:match('^%s*(shift_%a+)%s*([%+%-]?)%s*(%d*)%s*$')
    if not name or type(shift) ~= 'table' then return nil end
    local s, e = Utils.ParseTime(shift.start), Utils.ParseTime(shift['end'])
    if not s or not e then return nil end
    if e <= s then e = e + 1440 end
    local base
    if name == 'shift_start' then
        base = s
    elseif name == 'shift_end' then
        base = e
    elseif name == 'shift_mid' then
        base = math.floor(((s + e) / 2) / 30 + 0.5) * 30
    else
        return nil
    end
    local off = tonumber(num) or 0
    if sign == '-' then off = -off end
    local v = base + off
    if v < 0 then v = v + 1440 end
    return v
end
Sim.ResolveTime = resolveTime

function Sim.GetRoutineBlocks(r, day)
    local routine = Sim.Routines[r.routine_id or ''] or Sim.Routines['day_worker']
    if not routine then
        for _, rt in pairs(Sim.Routines) do routine = rt break end
    end
    if not routine then return {}, false end
    local wd = Clock.WeekdayForDay(day)
    if type(routine.days) == 'table' then
        local d = routine.days[wd] or routine.days[tostring(wd)]
        if type(d) == 'table' and #d > 0 then return d, true end
    end
    local isWork = Utils.Contains(r.job and r.job.workdays or {}, wd)
    return (isWork and routine.workday or routine.offday) or {}, isWork
end

local function pickRoamLocation(r, types, origin, rng, excludeId)
    local set = {}
    for _, t in ipairs(types or {}) do set[t] = true end
    local cands = {}
    local workId = r.job and r.job.workplaceId
    for _, loc in pairs(Sim.Locations) do
        if loc.public and set[loc.type] and loc.id ~= excludeId and loc.id ~= workId then
            if not origin or Utils.Dist2D(origin, loc.door) <= 3000.0 then cands[#cands + 1] = loc end
        end
    end
    if #cands == 0 then return nil end
    table.sort(cands, function(a, b) return a.id < b.id end)
    return cands[rng(#cands)]
end

local function expandRoam(r, seg, rng, out)
    local roam = seg.roam
    local slot = math.max(60, tonumber(roam.slot) or 150)
    local away = Utils.Clamp(tonumber(roam.away) or 90, 20, slot - 10)
    local work = Sim.Locations[r.job and r.job.workplaceId or '']
    local t, lastId = seg.from, nil
    while t < seg.to - 15 do
        local slotEnd = math.min(t + slot, seg.to)
        local awayStart = math.max(t, slotEnd - away)
        if awayStart > t then
            out[#out + 1] = { from = t, to = awayStart, activity = seg.activity, location = seg.location, firm = seg.firm }
        end
        local placed = false
        if slotEnd - awayStart >= 25 then
            local loc = pickRoamLocation(r, roam.types, work and work.door, rng, lastId)
            if loc then
                out[#out + 1] = { from = awayStart, to = slotEnd, activity = roam.activity or 'deliver', location = loc.id, firm = true, roaming = true }
                lastId = loc.id
                placed = true
            end
        end
        if not placed and out[#out] then out[#out].to = slotEnd end
        t = slotEnd
    end
end

-- Bir günün ham (gece yarısını aşan kuyruk hariç) segmentleri, mutlak dakikalarla
local function buildRaw(r, day)
    local blocks = Sim.GetRoutineBlocks(r, day)
    local shift = r.job and r.job.shift
    local rng = Utils.Rng(Utils.Hash(r.id .. ':' .. day))
    local segs = {}
    local prevFrom = -1
    for _, b in ipairs(blocks) do
        local f = resolveTime(b.from, shift)
        local t = resolveTime(b.to, shift)
        if f and t and b.activity then
            while f < prevFrom do f = f + 1440 end
            while t <= f do t = t + 1440 end
            local def = Activities[b.activity]
            segs[#segs + 1] = {
                from = f, to = t, activity = b.activity, location = b.location or 'home',
                firm = b.firm or (def and def.firm) or false, roam = b.roam,
            }
            prevFrom = f
        end
    end
    for i = 1, #segs - 1 do segs[i].contiguous = math.abs(segs[i].to - segs[i + 1].from) <= 1 end
    -- günlük sapma (±10–20 dk)
    for _, seg in ipairs(segs) do
        local overrides = Config.Routine.JitterOverrides or {}
        local jmax = overrides[seg.activity] or Config.Routine.JitterMax or 20
        local jmin = math.min(Config.Routine.JitterMin or 10, jmax)
        local j = rng(jmin, jmax)
        if rng() < 0.5 then j = -j end
        seg.from = seg.from + j
    end
    for i, seg in ipairs(segs) do
        local nxt = segs[i + 1]
        if nxt and nxt.from < seg.from + 10 then nxt.from = seg.from + 10 end
        if nxt and (seg.contiguous or seg.to > nxt.from) then seg.to = nxt.from end
        if seg.to <= seg.from then seg.to = seg.from + 10 end
    end
    local out = {}
    for _, seg in ipairs(segs) do
        if type(seg.roam) == 'table' then
            expandRoam(r, seg, rng, out)
        else
            out[#out + 1] = seg
        end
    end
    local base = day * 1440
    for _, seg in ipairs(out) do
        seg.from = seg.from + base
        seg.to = seg.to + base
        seg.roam = nil
        seg.contiguous = nil
    end
    return out
end

--[[
    Günün planı: önceki günden sarkan segment (ilk bloğa kadar) + günün blokları + boşluk doldurma.
    Deterministiktir (sakin id + gün tohumlu); önbelleğe alınır.
]]
function Sim.GetPlan(r, day)
    r.plans = r.plans or {}
    local cached = r.plans[day]
    if cached then return cached end
    local dayStart = day * 1440
    local cur = buildRaw(r, day)
    local prev = r.plans[day - 1] or buildRaw(r, day - 1)
    local firstFrom = cur[1] and cur[1].from or (dayStart + 1440)
    local plan = {}
    for _, seg in ipairs(prev) do
        if seg.to > dayStart and seg.from < firstFrom then
            local c = {
                from = math.max(seg.from, dayStart), to = math.min(seg.to, firstFrom),
                activity = seg.activity, location = seg.location, firm = seg.firm,
                carry = true, origin = seg.origin or seg,
            }
            if c.to > c.from then plan[#plan + 1] = c end
        end
    end
    for _, seg in ipairs(cur) do plan[#plan + 1] = seg end
    table.sort(plan, function(a, b) return a.from < b.from end)

    local filled = {}
    for _, seg in ipairs(plan) do
        local last = filled[#filled]
        if last then
            if seg.from > last.to then
                local gap = seg.from - last.to
                if last.activity == 'sleep' or gap <= (Config.Routine.GapFillMinutes or 60) then
                    last.to = seg.from
                else
                    filled[#filled + 1] = { from = last.to, to = seg.from, activity = 'home_idle', location = 'home', gap = true }
                end
            elseif seg.from < last.to then
                last.to = seg.from
            end
        end
        filled[#filled + 1] = seg
    end
    if filled[1] and filled[1].from > dayStart then
        table.insert(filled, 1, { from = dayStart, to = filled[1].from, activity = 'sleep', location = 'home', gap = true })
    end
    if #filled == 0 then
        filled[1] = { from = dayStart, to = dayStart + 1440, activity = 'home_idle', location = 'home', gap = true }
    end
    for i, seg in ipairs(filled) do seg.key = day .. ':' .. i end
    r.plans[day] = filled
    for d in pairs(r.plans) do
        if d < day - 2 or d > day + 2 then r.plans[d] = nil end
    end
    return filled
end

function Sim.SegmentAt(r, t)
    local plan = Sim.GetPlan(r, math.floor(t / 1440))
    local found
    for _, seg in ipairs(plan) do
        if seg.from <= t then found = seg else break end
    end
    return found or plan[1]
end

function Sim.NextSegment(r, t)
    local day = math.floor(t / 1440)
    for _, seg in ipairs(Sim.GetPlan(r, day)) do
        if seg.from > t then return seg end
    end
    for _, seg in ipairs(Sim.GetPlan(r, day + 1)) do
        if seg.from > t and not seg.carry then return seg end
    end
    return nil
end

-- Geçici segment (örn. korkunca eve kapanma, admin çağırması) ve randevular rutini ezer
function Sim.EffectiveSegmentAt(r, t)
    local ts = r.tempSeg
    if ts and t >= ts.from and t < ts.to then return ts end
    if SC.Appt then
        local a = SC.Appt.SegmentFor(r, t)
        if a then return a end
    end
    return Sim.SegmentAt(r, t)
end

function Sim.NextBoundary(r, t)
    local best
    local function consider(x)
        if x and x > t and (not best or x < best) then best = x end
    end
    local nxt = Sim.NextSegment(r, t)
    if nxt then consider(nxt.from) end
    if r.tempSeg then
        consider(r.tempSeg.from)
        consider(r.tempSeg.to)
    end
    if SC.Appt then
        for _, b in ipairs(SC.Appt.BoundariesFor(r)) do consider(b) end
    end
    return best
end

function Sim.SetTempSeg(r, activity, location, minutes, now)
    now = now or Clock.Now()
    r.tempSeg = { from = now, to = now + minutes, activity = activity, location = location, key = 'temp:' .. now, firm = false, temp = true }
    r.dirty = true
end

-- =====================================================================
-- ESNEK AKTİVİTE ÇÖZÜMÜ
-- =====================================================================
-- Tercih: favori mekanlar (açık, menzilde) > en yakın 3 mekandan biri
function Sim.PickPlace(r, types, origin, maxDist, mod, rng)
    local set = {}
    for _, t in ipairs(types or {}) do set[t] = true end
    local favs, others = {}, {}
    local favSet = {}
    for _, id in ipairs(r.favorite_places or {}) do favSet[id] = true end
    for id, loc in pairs(Sim.Locations) do
        if set[loc.type] and loc.type ~= 'home' and Sim.IsOpen(loc, mod) then
            local d = origin and Utils.Dist2D(origin, loc.door) or 0
            if d <= (maxDist or 3500.0) then
                if favSet[id] then
                    favs[#favs + 1] = loc
                elseif loc.public then
                    others[#others + 1] = { loc = loc, d = d }
                end
            end
        end
    end
    if #favs > 0 then
        table.sort(favs, function(a, b) return a.id < b.id end)
        return favs[rng and rng(#favs) or math.random(#favs)]
    end
    if #others == 0 then return nil end
    table.sort(others, function(a, b) return a.d < b.d end)
    local n = math.min(3, #others)
    return others[rng and rng(n) or math.random(n)].loc
end

function Sim.PickFavorite(r, locType)
    local home = Sim.Locations[r.homeId]
    local loc = Sim.PickPlace(r, { locType }, home and home.door, 99999.0, 720, Utils.Rng(Utils.Hash(r.id .. locType)))
    return loc and loc.id or nil
end

function Sim.ResolveFlex(r, seg, kind, now)
    local rng = Utils.Rng(Utils.Hash(r.id .. ':' .. tostring(seg.origin and seg.origin.from or seg.from)))
    local mod = math.floor(seg.from or now) % 1440
    local n = r.needs
    if kind == 'lunch' then
        local st = r.state or {}
        local base = st.locationId or st.toLocationId or r.homeId
        local baseLoc = Sim.Locations[base] or Sim.Locations[r.homeId]
        if n.hunger >= (Config.Needs.LunchOutHunger or 50) and baseLoc then
            local loc = Sim.PickPlace(r, SC.LeisureTypes.eat, baseLoc.door, Config.Routine.MaxLunchDistance or 1200.0, mod, rng)
            if loc then return 'eat', loc.id end
        end
        if base == r.homeId then return 'eat', r.homeId end
        return 'lunch_break', base
    end

    -- 'free': ihtiyaçlara, havaya, saate ve kişiliğe göre ağırlıklı seçim
    local raining = Clock.IsRaining()
    local late = mod >= 21 * 60 or mod < 5 * 60
    local traits = Utils.Fold(table.concat(r.personality.traits or {}, ' '))
    local hobbies = Utils.Fold(table.concat(r.personality.hobbies or {}, ' '))
    local sociable = traits:find('disa donuk', 1, true) or traits:find('konuskan', 1, true) or traits:find('sosyal', 1, true)
    local home = Sim.Locations[r.homeId]
    local origin = home and home.door
    local options = {}
    local function add(activity, weight, types)
        if not weight or weight <= 0 then return end
        if types then
            local loc = Sim.PickPlace(r, types, origin, 3500.0, mod, rng)
            if not loc then return end
            options[#options + 1] = { weight = weight, act = activity, loc = loc.id }
        else
            options[#options + 1] = { weight = weight, act = activity, loc = r.homeId }
        end
    end
    add('home_idle', 1.0 + (n.energy < 40 and 1.5 or 0) + (late and 1.0 or 0))
    add('sleep', n.energy < (Config.Needs.EarlySleepEnergy or 25) and 6.0 or 0)
    local drinkW = 0.6 + (n.social < (Config.Needs.LonelySocial or 40) and 2.0 or 0) + (sociable and 0.8 or 0) + (late and 1.0 or 0)
    if (r.age or 30) > 60 then drinkW = drinkW * 0.3 end
    add('drink', drinkW, SC.LeisureTypes.drink)
    if not raining then
        add('leisure', (late and 0.1 or 0.8) + (n.fun < (Config.Needs.BoredFun or 40) and 1.5 or 0), SC.LeisureTypes.leisure)
    end
    if not late then
        add('coffee', 0.6 + (raining and 2.0 or 0), SC.LeisureTypes.coffee)
        local sporty = hobbies:find('fitness', 1, true) or hobbies:find('spor', 1, true) or hobbies:find('yoga', 1, true)
            or hobbies:find('basketbol', 1, true) or hobbies:find('kosu', 1, true)
        add('exercise', (sporty and 1.8 or 0.1) * (raining and 0.3 or 1.0), SC.LeisureTypes.exercise)
        if hobbies:find('balik', 1, true) and not raining then add('fish', 1.5, SC.LeisureTypes.fish) end
    end
    add('shopping', late and 0.1 or 0.4, SC.LeisureTypes.shopping)
    local pick = Utils.WeightedPick(options, rng)
    if not pick then return 'home_idle', r.homeId end
    return pick.act, pick.loc
end

--[[
    Segmenti somut { activity, loc }'a çevirir. Esnek segmentler bir kez çözülüp saklanır;
    uzak gelecekteki segmentler için tentative = true ile saklamadan tahmin edilir.
]]
function Sim.Resolve(r, seg, now, tentative)
    local target = seg.origin or seg
    if target.resolved then return target.resolved end
    if seg.resolved then return seg.resolved end
    local act, spec = seg.activity, seg.location or 'home'
    local locId
    if spec == 'home' then
        locId = r.homeId
    elseif spec == 'work' then
        locId = (r.job and r.job.workplaceId) or r.homeId
    elseif spec:sub(1, 5) == 'flex:' then
        act, locId = Sim.ResolveFlex(r, seg, spec:sub(6), now)
    elseif spec:sub(1, 4) == 'fav:' then
        locId = Sim.PickFavorite(r, spec:sub(5))
    else
        locId = spec
    end
    if not locId or not Sim.Locations[locId] then locId = r.homeId end
    if act == 'lunch' then act = (locId == r.homeId) and 'eat' or 'lunch_break' end
    if act == 'free' then act = 'home_idle' end
    if not Activities[act] then act = 'idle' end
    local res = { activity = act, loc = locId }
    if not tentative then target.resolved = res end
    return res
end

function Sim.NextLocationChange(r, now, here)
    local t = now
    for _ = 1, 6 do
        local B = Sim.NextBoundary(r, t)
        if not B or B - now > 300 then return nil end
        local seg = Sim.EffectiveSegmentAt(r, B)
        if not seg then return nil end
        local res = Sim.Resolve(r, seg, now, (B - now) > 120)
        if res and res.loc ~= here then return seg, res, B end
        t = B
    end
    return nil
end

-- =====================================================================
-- DURUM GEÇİŞLERİ
-- =====================================================================
function Sim.Changed(r, reason)
    r.dirty = true
    if SC.Spawner then SC.Spawner.OnStateChanged(r, reason) end
end

function Sim.Depart(r, seg, res, now)
    local toLoc = Sim.Locations[res.loc]
    if not toLoc then return end
    local st = r.state or {}
    local fromLocId = st.locationId
    local fromLoc = fromLocId and Sim.Locations[fromLocId]
    local pos = currentPos(r, now)
    local dist = Utils.Dist(pos, toLoc.door)
    local mode = Sim.ChooseMode(r, fromLocId, dist)
    local fromP, toP = pos, toLoc.door
    if mode == 'car' then
        if fromLoc and fromLoc.parking and not r.phys then fromP = fromLoc.parking end
        toP = toLoc.parking or toLoc.door
    end
    local travel = Sim.TravelMinutes(mode, Utils.Dist(fromP, toP))
    Sim.ReleasePoint(r)
    r.state = {
        activity = 'commute', mode = mode,
        fromLocationId = fromLocId, toLocationId = res.loc,
        fromPos = Utils.VecToTable(fromP), toPos = Utils.VecToTable(toP),
        startedAt = now, eta = now + travel, nextActivity = res.activity, segKey = seg.key,
        -- gidilen segmentin penceresi: erken varılırsa önceki segmente geri dönülmez
        targetFrom = seg.from, targetTo = seg.to,
    }
    if mode == 'car' and r.car then r.car.inUse = true end
    Sim.AddLog(r, now, 'depart', { from = fromLocId, to = res.loc, mode = mode })
    Sim.Changed(r, 'depart')
end

function Sim.Arrive(r, now)
    local st = r.state
    local locId = st.toLocationId
    if not Sim.Locations[locId] then locId = r.homeId end
    if st.mode == 'car' and r.car then
        r.car.locationId = locId
        r.car.inUse = false
    end
    local act = st.nextActivity or 'idle'
    local cur = Sim.EffectiveSegmentAt(r, now)
    if cur then
        local res = Sim.Resolve(r, cur, now)
        if res.loc == locId then act = res.activity end
    end
    local transit = st.mode == 'transit'
    r.state = { activity = act, locationId = locId, startedAt = now, inside = true, targetFrom = st.targetFrom, targetTo = st.targetTo }
    Sim.PlaceAtLocation(r, act)
    if transit and not r.state.inside then r.state.emerge = true end
    Sim.AddLog(r, now, 'arrive', { loc = locId, act = act })
    Sim.Changed(r, 'arrive')
end

function Sim.SetActivity(r, act, now)
    Sim.ReleasePoint(r)
    r.state.activity = act
    r.state.startedAt = now
    Sim.PlaceAtLocation(r, act)
    Sim.AddLog(r, now, 'activity', { loc = r.state.locationId, act = act })
    Sim.Changed(r, 'activity')
end

-- Belirli bir noktada serbest duruma geç (takip/kaçma/çağırma sonrası)
function Sim.SetFreePos(r, pos, activity)
    Sim.ReleasePoint(r)
    r.state = { activity = activity or 'idle', pos = Utils.VecToTable(pos), startedAt = Clock.Now() }
    Sim.Changed(r, 'freepos')
end

-- Geçici davranış (takip, kaçma, sohbet, buluşma...) rutini askıya alır
function Sim.SetOverride(r, ov)
    r.override = ov
    Sim.Changed(r, 'override')
end

function Sim.ClearOverride(r, reason)
    local ov = r.override
    if not ov then return end
    r.override = nil
    if ov.type == 'follow' or ov.type == 'flee' or ov.type == 'meet' or ov.type == 'handsup' or ov.type == 'cower' or ov.type == 'hostage' then
        local pos = SC.Spawner and SC.Spawner.GetPedCoords(r)
        if pos then
            Sim.ReleasePoint(r)
            r.state = { activity = 'idle', pos = Utils.VecToTable(pos), startedAt = Clock.Now() }
        end
    end
    if ov.after then
        local ok, err = pcall(ov.after, r, reason)
        if not ok then SC.DebugPrint('override after hatası', tostring(err)) end
    end
    Sim.Changed(r, 'override_clear')
end

function Sim.CheckOverride(r)
    local ov = r.override
    if ov and ov.untilMs and GetGameTimer() >= ov.untilMs then
        Sim.ClearOverride(r, 'expired')
    end
end

function Sim.Hospitalize(r, reason)
    local now = Clock.Now()
    Sim.ReleasePoint(r)
    r.override = nil
    r.tempSeg = nil
    if Config.World.PermaDeath then
        r.status = 'dead'
        r.status_until = 0
    else
        r.status = 'hospital'
        r.status_until = now + math.floor((Config.World.HospitalDays or 1) * 1440)
    end
    local hosp = Sim.FindHospital()
    r.state = { activity = 'hospital', locationId = hosp and hosp.id or r.homeId, startedAt = now, inside = true }
    Sim.AddLog(r, now, 'event', { text = reason or L('log_hospital') })
    Sim.Changed(r, 'hospital')
end

function Sim.Discharge(r, now)
    r.status = 'alive'
    r.status_until = 0
    r.plans = {}
    r.state = { activity = 'home_idle', locationId = r.homeId, startedAt = now, inside = true }
    Sim.PlaceAtLocation(r, 'home_idle')
    Sim.AddLog(r, now, 'event', { text = L('log_discharged') })
    Sim.AddMoodEvent(r, -20, L('mood_reason_recovering'), 'recovering')
    Sim.Changed(r, 'discharge')
end

-- =====================================================================
-- İHTİYAÇLAR & RUH HÂLİ
-- =====================================================================
-- code: olay kodu (diyalogda birinci şahıs sebep cümlesi için, örn. 'police', 'car', 'aim_weapon')
function Sim.AddMoodEvent(r, value, reason, code)
    r.moodEvents = r.moodEvents or {}
    r.moodEvents[#r.moodEvents + 1] = { value = value, reason = reason, at = Clock.Now(), code = code }
    while #r.moodEvents > 6 do table.remove(r.moodEvents, 1) end
    r.mood = Utils.Clamp((r.mood or 0) + value * 0.5, -100, 100)
    r.mood_reason = reason
    r.dirty = true
end

function Sim.NeedReason(r)
    local n = r.needs
    local best, bestV = nil, 0
    local function check(cond, v, key)
        if cond and v > bestV then best, bestV = key, v end
    end
    check(n.energy < 25, 25 - n.energy, 'mood_reason_tired')
    check(n.hunger > 70, n.hunger - 70, 'mood_reason_hungry')
    check(n.social < 25, 25 - n.social, 'mood_reason_lonely')
    check(n.fun < 25, 25 - n.fun, 'mood_reason_bored')
    if best then return L(best) end
    if (r.mood or 0) > 30 then return L('mood_reason_good') end
    return L('mood_reason_ok')
end

function Sim.UpdateNeeds(r, dt, now)
    if dt <= 0 then return end
    local act = r.state and r.state.activity or 'idle'
    if r.status == 'hospital' then act = 'hospital' end
    if r.override and r.override.type == 'follow' then act = 'follow' end
    local def = Activities[act] or Activities.idle
    local h = dt / 60
    local n = r.needs
    for k, rate in pairs(def.needs or {}) do
        n[k] = Utils.Clamp((n[k] or 50) + rate * h, 0, 100)
    end
    if r.convo then n.social = Utils.Clamp(n.social + 6 * h, 0, 100) end

    local target = (n.energy - 50) * 0.35 + (50 - n.hunger) * 0.3 + (n.social - 50) * 0.25 + (n.fun - 50) * 0.3
    local strongest
    if r.moodEvents then
        for i = #r.moodEvents, 1, -1 do
            local ev = r.moodEvents[i]
            local eff = ev.value * (0.5 ^ ((now - ev.at) / 120))
            if math.abs(eff) < 3 then
                table.remove(r.moodEvents, i)
            else
                target = target + eff
                if not strongest or math.abs(eff) > math.abs(strongest.eff) then strongest = { eff = eff, reason = ev.reason } end
            end
        end
    end
    target = Utils.Clamp(target, -100, 100)
    local k = math.min(1.0, (Config.Needs.MoodDriftPerHour or 6) / 10 * h)
    r.mood = Utils.Clamp((r.mood or 0) + (target - (r.mood or 0)) * k, -100, 100)
    r.mood_reason = strongest and strongest.reason or Sim.NeedReason(r)
end

function Sim.MoodKey(r)
    local m = r.mood or 0
    if m >= 50 then return 'great' end
    if m >= 15 then return 'good' end
    if m > -15 then return 'neutral' end
    if m > -50 then return 'bad' end
    return 'awful'
end

-- =====================================================================
-- GÜNLÜK KAYIT
-- =====================================================================
function Sim.AddLog(r, now, kind, data)
    local day = Clock.Day(now)
    if not r.dayLog or r.dayLog.day ~= day then
        if r.dayLog and r.dayLog.day < day then r.prevDayLog = r.dayLog end
        r.dayLog = { day = day, entries = {} }
    end
    local e = { t = now, k = kind }
    for k, v in pairs(data or {}) do e[k] = v end
    local entries = r.dayLog.entries
    entries[#entries + 1] = e
    while #entries > 40 do table.remove(entries, 1) end
    r.dirty = true
end

-- you = true: 2. tekil şahıs; false: 3. şahıs (panel, gün özeti)
function Sim.LogEntryText(e, you)
    local time = Utils.FormatTime(math.floor(e.t) % 1440)
    local p = you and 'logy_' or 'log_'
    local ap = you and 'actn.' or 'act.'
    if e.k == 'depart' then
        return L(p .. 'depart', time, Sim.LocationLabel(e.from), Sim.LocationLabel(e.to), L('mode_' .. tostring(e.mode)))
    elseif e.k == 'arrive' then
        return L(p .. 'arrive', time, Sim.LocationLabel(e.loc), L(ap .. tostring(e.act)))
    elseif e.k == 'activity' then
        return L(p .. 'activity', time, L(ap .. tostring(e.act)), Sim.LocationLabel(e.loc))
    elseif e.k == 'event' then
        return time .. ' — ' .. tostring(e.text or '')
    end
    return time
end

function Sim.RenderLog(log, you, maxEntries)
    if not log or not log.entries then return {} end
    local out = {}
    local start = math.max(1, #log.entries - (maxEntries or 40) + 1)
    for i = start, #log.entries do out[#out + 1] = Sim.LogEntryText(log.entries[i], you) end
    return out
end

function Sim.MarkInteracted(r)
    r.interactedDays = r.interactedDays or {}
    r.interactedDays[tostring(Clock.Day())] = true
    for k in pairs(r.interactedDays) do
        if tonumber(k) and tonumber(k) < Clock.Day() - 3 then r.interactedDays[k] = nil end
    end
    r.dirty = true
end

-- Gün sonu: özet + veritabanı
function Sim.EndOfDay(r, day)
    local log = (r.dayLog and r.dayLog.day == day and r.dayLog) or (r.prevDayLog and r.prevDayLog.day == day and r.prevDayLog)
    if not log or #log.entries == 0 then return end
    local lines = Sim.RenderLog(log, false, 40)
    local summary = L('daysum_template', r.firstname, table.concat(lines, '; '))
    r.yesterdaySummary = summary
    MySQL.prepare([[INSERT INTO samy_citizens_daily_log (npc_id, game_day, entries, summary) VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE entries = VALUES(entries), summary = VALUES(summary)]], { r.id, day, json.encode(log.entries), summary })
end

-- =====================================================================
-- YAŞAM DÖNGÜSÜ
-- =====================================================================
function Sim.PlaceFresh(r, now)
    r.state = { activity = 'home_idle', locationId = r.homeId, startedAt = now, inside = true }
    local seg = Sim.EffectiveSegmentAt(r, now)
    local res = seg and Sim.Resolve(r, seg, now) or { activity = 'home_idle', loc = r.homeId }
    r.state = { activity = res.activity, locationId = res.loc, startedAt = now, inside = true }
    if r.car then
        local home = Sim.Locations[r.homeId]
        local target = Sim.Locations[res.loc]
        if home and target and res.loc ~= r.homeId and Utils.Dist(home.door, target.door) > (Config.Travel.WalkMaxDistance or 200.0) then
            r.car.locationId = res.loc
        else
            r.car.locationId = r.homeId
        end
    end
    Sim.PlaceAtLocation(r, res.activity)
    r.state.emerge = nil
end

function Sim.RestoreState(r, st, savedAt)
    local now = Clock.Now()
    if type(st) == 'table' and st.activity and savedAt and (now - savedAt) >= 0 and (now - savedAt) < 90 then
        local valid = true
        if st.activity == 'commute' then
            valid = Sim.Locations[st.toLocationId] ~= nil and st.fromPos ~= nil and st.toPos ~= nil
        elseif st.locationId then
            valid = Sim.Locations[st.locationId] ~= nil
        elseif not st.pos then
            valid = false
        end
        if valid then
            r.state = st
            if st.locationId and st.pointIndex then
                local occ = Sim.Occupancy[st.locationId] or {}
                Sim.Occupancy[st.locationId] = occ
                if occ[st.pointIndex] and occ[st.pointIndex] ~= r.id then
                    Sim.PlaceAtLocation(r, st.activity)
                else
                    occ[st.pointIndex] = r.id
                end
            end
            if st.activity == 'hospital' and r.status == 'alive' then Sim.PlaceFresh(r, now) end
            return
        end
    end
    if r.status == 'hospital' or r.status == 'dead' then
        local hosp = Sim.FindHospital()
        r.state = { activity = 'hospital', locationId = hosp and hosp.id or r.homeId, startedAt = now, inside = true }
        return
    end
    Sim.PlaceFresh(r, now)
end

local function firstHomeId()
    local ids = {}
    for id, loc in pairs(Sim.Locations) do if loc.type == 'home' then ids[#ids + 1] = id end end
    table.sort(ids)
    return ids[1]
end

function Sim.AddResident(data)
    local r = data
    r.needs = type(r.needs) == 'table' and r.needs or { energy = 75, hunger = 35, social = 60, fun = 60 }
    for _, k in ipairs({ 'energy', 'hunger', 'social', 'fun' }) do r.needs[k] = tonumber(r.needs[k]) or 50 end
    r.mood = tonumber(r.mood) or 0
    r.personality = r.personality or {}
    r.job = r.job or {}
    r.plans = {}
    r.moodEvents = {}
    r.status = r.status or 'alive'
    r.status_until = tonumber(r.status_until) or 0
    if r.enabled == nil then r.enabled = true end
    if not r.homeId or not Sim.Locations[r.homeId] then
        r.homeId = firstHomeId()
        print(('^3[samy-citizens] %s için geçerli ev yok, %s atandı^7'):format(r.id, tostring(r.homeId)))
    end
    if r.job.workplaceId and not Sim.Locations[r.job.workplaceId] then
        print(('^3[samy-citizens] %s iş yeri bulunamadı: %s^7'):format(r.id, tostring(r.job.workplaceId)))
        r.job.workplaceId = nil
    end
    local saved = r.savedState
    r.savedState = nil
    if type(saved) == 'table' then
        r.car = saved.car
        r.tempSeg = saved.tempSeg
        r.moodEvents = saved.moodEvents or {}
        r.dayLog = saved.dayLog
        r.prevDayLog = saved.prevDayLog
        r.interactedDays = saved.interactedDays
    end
    if r.vehicle then
        r.car = type(r.car) == 'table' and r.car or { locationId = r.homeId }
        r.car.inUse = false
        r.car.missing = nil
        if not Sim.Locations[r.car.locationId or ''] then r.car.locationId = r.homeId end
    else
        r.car = nil
    end
    local existing = Sim.Residents[r.id]
    if existing then Sim.RemoveResident(r.id) end
    Sim.Residents[r.id] = r
    Sim.List[#Sim.List + 1] = r
    Sim.RestoreState(r, saved and saved.state, saved and saved.savedAt)
    return r
end

function Sim.RemoveResident(id)
    local r = Sim.Residents[id]
    if not r then return end
    if SC.Spawner then SC.Spawner.Despawn(r, 'removed', true) end
    Sim.ReleasePoint(r)
    Sim.Residents[id] = nil
    for i, x in ipairs(Sim.List) do
        if x.id == id then
            table.remove(Sim.List, i)
            break
        end
    end
end

function Sim.Serialize(r)
    return json.encode({
        state = r.state,
        car = r.car,
        tempSeg = r.tempSeg,
        moodEvents = r.moodEvents,
        dayLog = r.dayLog,
        prevDayLog = r.prevDayLog,
        interactedDays = r.interactedDays,
        savedAt = Clock.Now(),
    })
end

function Sim.CollectSaves(all)
    local list = {}
    for _, r in ipairs(Sim.List) do
        if all or r.dirty then
            list[#list + 1] = {
                id = r.id,
                needs = json.encode({
                    energy = Utils.Round(r.needs.energy, 1), hunger = Utils.Round(r.needs.hunger, 1),
                    social = Utils.Round(r.needs.social, 1), fun = Utils.Round(r.needs.fun, 1),
                }),
                mood = math.floor(r.mood or 0),
                mood_reason = r.mood_reason or '',
                status = r.status or 'alive',
                status_until = math.floor(r.status_until or 0),
                state = Sim.Serialize(r),
                appearance = r.appearance and json.encode(r.appearance) or 'null',
            }
            r.dirty = false
        end
    end
    return list
end

function Sim.OnDayChange(fn)
    Sim.dayListeners[#Sim.dayListeners + 1] = fn
end

-- =====================================================================
-- TICK
-- =====================================================================
function Sim.TickResident(r, now, dt)
    Sim.UpdateNeeds(r, dt, now)
    if r.status ~= 'alive' then
        if (r.status == 'hospital' or r.status == 'jailed') and now >= (r.status_until or 0) then
            Sim.Discharge(r, now)
        end
        return
    end
    if r.tempSeg and now >= r.tempSeg.to then r.tempSeg = nil end
    if r.override then Sim.CheckOverride(r) end
    if r.convo or r.override then return end

    local st = r.state
    if st.activity == 'commute' then
        if now >= st.eta then
            if r.phys and r.phys.traveling and now < st.eta + (Config.Travel.ArrivalGraceMinutes or 120) then return end
            Sim.Arrive(r, now)
        end
        return
    end

    local here = st.locationId
    local cur = Sim.EffectiveSegmentAt(r, now)
    if not cur then return end
    local res = Sim.Resolve(r, cur, now)
    if res.loc ~= here then
        -- gelinen segment henüz başlamadıysa (erken varış) burada bekle; geçici segment/randevu hariç
        if here and st.targetFrom and now < st.targetFrom and not cur.temp and not cur.appt then
            return
        end
        Sim.Depart(r, cur, res, now)
        return
    end
    local nxt, nres, startAt = Sim.NextLocationChange(r, now, here)
    if nxt then
        local tt = Sim.EstimateTravel(r, here, nil, nres.loc)
        local departAt = startAt - tt
        local def = Activities[res.activity]
        if cur.firm or (def and def.firm) then departAt = math.max(departAt, startAt) end
        if now >= departAt then
            Sim.Depart(r, nxt, nres, now)
            return
        end
    end
    if res.activity ~= st.activity then Sim.SetActivity(r, res.activity, now) end
end

function Sim.Tick()
    local now = Clock.Now()
    local dt = Sim.lastTick and (now - Sim.lastTick) or 0
    if dt < 0 then dt = 0 elseif dt > 120 then dt = 120 end
    Sim.lastTick = now
    local day = Clock.Day(now)
    if not Sim.currentDay then
        Sim.currentDay = day
    elseif day > Sim.currentDay then
        local prev = Sim.currentDay
        Sim.currentDay = day
        for _, fn in ipairs(Sim.dayListeners) do
            local ok, err = pcall(fn, prev, day)
            if not ok then print(('^1[samy-citizens] gün değişimi hatası: %s^7'):format(tostring(err))) end
        end
    end
    for _, r in ipairs(Sim.List) do
        if r.enabled then
            local ok, err = pcall(Sim.TickResident, r, now, dt)
            if not ok then print(('^1[samy-citizens] tick hatası (%s): %s^7'):format(r.id, tostring(err))) end
        end
    end
end

-- =====================================================================
-- GÖRÜNÜM YARDIMCILARI
-- =====================================================================
function Sim.GetPlanView(r, day, you)
    local now = Clock.Now()
    local out = {}
    for _, seg in ipairs(Sim.GetPlan(r, day)) do
        local res = Sim.Resolve(r, seg, now, seg.from > now + 120 and not (seg.origin or seg).resolved)
        out[#out + 1] = {
            from = Utils.FormatTime(seg.from % 1440),
            to = Utils.FormatTime(seg.to % 1440),
            fromAbs = seg.from, toAbs = seg.to,
            activity = res.activity,
            activityLabel = L((you and 'actyou.' or 'act.') .. res.activity),
            location = res.loc,
            locationLabel = Sim.LocationLabel(res.loc),
            flex = (seg.location or ''):sub(1, 5) == 'flex:',
            firm = seg.firm and true or false,
        }
    end
    return out
end

-- Belirli bir mutlak zamanda sakinin nerede/ne yapıyor olacağı (randevu doğrulama)
function Sim.PredictAt(r, t)
    local seg = Sim.SegmentAt(r, t)
    if not seg then return nil end
    return Sim.Resolve(r, seg, Clock.Now(), true), seg
end
