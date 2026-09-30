--[[
    ÇEVRE FARKINDALIĞI (sunucu tarafı, OneSync)
    NPC'nin konuşurken / beraber gezerken fark ettikleri:
      yağmur, gece/gündüz, oyuncu araçta mı, yaralı mı, silahlı mı, hızlı mı sürüyor, yakında çatışma/kavga oldu mu,
      yakında polis var mı, neredeyiz (en yakın konum / mahalle), NPC çalışıyor mu, eve mi gidiyor.
    İstemciye güvenmez: tüm bilgiler sunucu native'lerinden (GetEntityHealth, GetSelectedPedWeapon,
    GetVehiclePedIsIn, GetEntityVelocity) ve sunucunun kendi olay kayıtlarından okunur. Sonuçlar kısa süre önbelleklenir.
]]
local Utils = SC.Utils
local Clock = SC.Clock
local Sim = SC.Sim

local Aware = {}
SC.Aware = Aware

local UNARMED = GetHashKey('WEAPON_UNARMED')
local incidents = {}      -- { pos, at, kind }
local playerCache = {}    -- src -> { at, data }
local policeCache = { at = 0, list = {} }
local jobCache = {}       -- src -> { at, job }

-- world.lua çağırır: silah sesi, kavga, patlama
function Aware.RecordIncident(kind, pos)
    if not pos then return end
    incidents[#incidents + 1] = { kind = kind, pos = vector3(pos.x + 0.0, pos.y + 0.0, pos.z + 0.0), at = os.time() }
    while #incidents > 40 do table.remove(incidents, 1) end
end

function Aware.RecentIncident(pos, radius, seconds)
    if not pos then return nil end
    local now = os.time()
    for i = #incidents, 1, -1 do
        local e = incidents[i]
        if now - e.at > (seconds or 180) then break end
        if Utils.Dist(e.pos, pos) <= (radius or 150.0) then return e end
    end
    return nil
end

local function isPoliceJob(src)
    local e = jobCache[src]
    local now = os.time()
    if not e or now - e.at > 60 then
        local ok, job = pcall(SC.Bridge.GetJob, src)
        e = { at = now, job = ok and job or nil }
        jobCache[src] = e
    end
    local job = e.job
    if not job or not job.name then return false end
    for _, j in ipairs(Config.Dispatch.Jobs or { 'police' }) do
        if job.name == j and job.onduty ~= false then return true end
    end
    return false
end

-- Yakındaki görevli polisler (10 sn önbellek)
function Aware.PoliceNear(pos, radius)
    if not pos then return false end
    local now = os.time()
    if now - policeCache.at > 10 then
        local list = {}
        for _, p in ipairs(SC.Spawner.Players()) do
            if isPoliceJob(p.src) then list[#list + 1] = p.coords end
        end
        policeCache = { at = now, list = list }
    end
    for _, c in ipairs(policeCache.list) do
        if Utils.Dist(c, pos) <= (radius or 60.0) then return true end
    end
    return false
end

-- Oyuncu durumu (2 sn önbellek)
function Aware.Player(src)
    local now = GetGameTimer()
    local e = playerCache[src]
    if e and now - e.at < 2000 then return e.data end
    local ped = SC.NPC.PlayerPed(src)
    if not ped then return nil end
    local health = GetEntityHealth(ped)
    local okM, maxHealth = pcall(function() return GetEntityMaxHealth(ped) end)
    if not okM or not maxHealth or maxHealth <= 100 then maxHealth = 200 end
    local veh = GetVehiclePedIsIn(ped, false)
    local w = GetSelectedPedWeapon(ped)
    local speed = 0.0
    local ent = (veh and veh ~= 0) and veh or ped
    local okV, v = pcall(function() return GetEntityVelocity(ent) end)
    if okV and v then speed = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z) end
    local data = {
        pos = GetEntityCoords(ped),
        health = health,
        -- 100 = GTA'da "ölü" eşiği; can yarının altındaysa yaralı sayılır
        injured = health > 0 and (health - 100) < (maxHealth - 100) * 0.5,
        armed = w ~= nil and w ~= 0 and w ~= UNARMED,
        inVehicle = veh ~= nil and veh ~= 0,
        veh = (veh and veh ~= 0) and veh or nil,
        driver = veh and veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped or false,
        speed = speed,
        speeding = veh and veh ~= 0 and speed > 33.0 or false,   -- ~120 km/s
    }
    playerCache[src] = { at = now, data = data }
    return data
end

function Aware.TimeOfDay(mod)
    mod = mod or Clock.MinuteOfDay()
    if mod >= 5 * 60 and mod < 11 * 60 then return 'morning' end
    if mod >= 11 * 60 and mod < 18 * 60 then return 'day' end
    if mod >= 18 * 60 and mod < 23 * 60 then return 'evening' end
    return 'night'
end

-- En yakın konum (etiket + id) ve mahalle
function Aware.Place(pos, maxDist)
    if not pos then return nil end
    local best, bestD = nil, maxDist or 120.0
    for _, loc in pairs(Sim.Locations) do
        local d = Utils.Dist(pos, loc.door)
        if d < bestD then best, bestD = loc, d end
    end
    if not best then return nil end
    local area = best.area and SCDialogue.AreaLabels and SCDialogue.AreaLabels[best.area] or nil
    return { id = best.id, label = best.public and best.label or (area or best.label), area = area, public = best.public, dist = bestD }
end

-- Ortam anlık görüntüsü (diyalog/üretici koşulları için)
function Aware.Snapshot(r, src)
    local pos = SC.NPC.Coords(r) or (src and SC.NPC.PlayerCoords(src))
    local pl = src and Aware.Player(src) or nil
    local st = r and r.state or {}
    local place = Aware.Place(pos, 150.0)
    local def = SC.Activities[st.activity or '']
    return {
        rain = Clock.IsRaining(),
        time = Aware.TimeOfDay(),
        night = Aware.TimeOfDay() == 'night',
        injured = pl and pl.injured or false,
        armed = pl and pl.armed or false,
        inVehicle = pl and pl.inVehicle or false,
        speeding = pl and pl.speeding or false,
        fight = pos and Aware.RecentIncident(pos, 150.0, 180) ~= nil or false,
        police = pos and Aware.PoliceNear(pos, 60.0) or false,
        place = place and place.label or nil,
        placeId = place and place.id or nil,
        area = place and place.area or nil,
        working = def and def.busy or false,
        goingHome = st.activity == 'commute' and st.toLocationId == (r and r.homeId),
    }
end

AddEventHandler('playerDropped', function()
    playerCache[source] = nil
    jobCache[source] = nil
end)
