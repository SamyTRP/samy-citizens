--[[
    BERABER GEZME (companion) — sunucu yetkilidir
    NPC'nin oyuncuyla yürümesi, oyuncunun aracına binmesi, beraber bir yere gitmesi, kendi arabasıyla şoförlük
    yapması, beklemesi ve buluşma yerinde vakit geçirmesi burada yönetilir.

    Durum: r.override = { type = 'companion', target = src, cid, mode, phase, slot, veh, seat, npcVeh, dest, ... }
      (override olduğu için rutin motoru bu sürede NPC'yi götürmez; bitince NPC bulunduğu yerden rutinine döner)
    Fazlar:
      follow         : oyuncuyu doğal mesafeyle takip (hız eşleme, durunca yakında bekleme)
      wait_car       : oyuncu araçta ama boş koltuk yok / koltuk sayısı bekleniyor
      enter          : atanan koltuğa yürüyüp kapıyı açıp biner (TaskEnterVehicle)
      ride           : yolcu
      exit           : oyuncu indi, NPC de iner
      wait           : "burada bekle"
      date           : varılan yerde birlikte vakit (uygun aktivite noktasında)
      to_car / wait_passenger / driving / hold / arrive : NPC kendi arabasıyla şoför
    Koltuk ataması sunucudadır: birden fazla NPC aynı araca binerken koltuklar paylaşılır, çakışma olmaz.
    Görevleri ped'in network sahibi istemci uygular (client/npc_companion.lua); istemci olayları sadece sahipten kabul edilir.
    Işınlama yalnızca son çare (istemcide, NPC ekranda değilken / kapının dibinde defalarca binemediğinde).
]]
local Utils = SC.Utils
local Clock = SC.Clock
local Sim = SC.Sim
local Spawner = SC.Spawner
local NPC = SC.NPC

local Companion = {}
SC.Companion = Companion

local seatCache = {}     -- model -> { n, at }
local seatPending = {}   -- model -> true
local bubbleThrottle = {}

local F = Config.Follow
local V = Config.Vehicle

-- ---------------------------------------------------------------------
-- Yardımcılar
-- ---------------------------------------------------------------------
local function vehFromNet(net)
    net = tonumber(net)
    if not net or net <= 0 then return nil end
    local e = NetworkGetEntityFromNetworkId(net)
    if e and e ~= 0 and DoesEntityExist(e) and GetEntityType(e) == 2 then return e end
    return nil
end
Companion.VehFromNet = vehFromNet

local function relOf(r, ov)
    return (ov and ov.cid and SC.Rel.Peek(r.id, ov.cid)) or { stage = 'stranger', romance = 'none' }
end

local function say(r, ov, key, throttleKey, throttleSec)
    if throttleKey then
        local k = r.id .. '|' .. throttleKey
        local now = os.time()
        if bubbleThrottle[k] and now - bubbleThrottle[k] < (throttleSec or 10) then return end
        bubbleThrottle[k] = now
    end
    SC.Convo.Bubble(r, SC.Dialogue.Line(key, r, relOf(r, ov)), 'npc', 4500)
end

local function notify(src, key, ntype, ...)
    if src and GetPlayerName(src) then
        TriggerClientEvent('samy-citizens:client:notify', src, L(key, ...), ntype or 'inform')
    end
end

local function update(r)
    Spawner.UpdateTask(r)
    SC.State.Refresh(r, 'companion')
end

local function setPhase(r, ov, phase)
    if ov.phase == phase then return end
    ov.phase = phase
    ov.phaseAt = GetGameTimer()
    update(r)
end

local function nextSlot(src)
    local used = {}
    for _, other in ipairs(NPC.CompanionsOf(src)) do used[NPC.Companion(other).slot or 1] = true end
    for i = 1, 8 do if not used[i] then return i end end
    return 1
end

-- bekleme / kişilik senaryosu
local function idleScenario(r)
    local h = Utils.Hash(r.id .. ':idle') % 4
    if h == 0 then return 'WORLD_HUMAN_SMOKING' end
    if h == 1 then return 'WORLD_HUMAN_STAND_MOBILE' end
    if h == 2 then return 'WORLD_HUMAN_HANG_OUT_STREET' end
    return 'WORLD_HUMAN_STAND_IMPATIENT'
end

-- NPC'nin yakında zorunlu bir işi (iş, ders, randevu) var mı? (şu an içinde olduğu blok hariç)
local function dutySoon(r)
    local now = Clock.Now()
    local ok, seg = pcall(Sim.EffectiveSegmentAt, r, now + (F.LeaveForDutyMinutes or 30))
    if not ok or not seg or (seg.from or 0) <= now then return false end
    local okR, res = pcall(Sim.Resolve, r, seg, now, true)
    if not okR or not res then return false end
    local def = SC.Activities[res.activity]
    return (seg.firm or (def and def.firm) or seg.appt ~= nil) == true
end

-- ---------------------------------------------------------------------
-- Hedef çözümleme (Config.Destinations / konum id / harita işareti)
-- ---------------------------------------------------------------------
local function destFromLocation(loc)
    if not loc then return nil end
    return {
        id = loc.id, label = loc.label, type = loc.type, loc = loc,
        pos = vector3(loc.door.x, loc.door.y, loc.door.z),
        drive = loc.parking and vector4(loc.parking.x, loc.parking.y, loc.parking.z, loc.parking.w) or vector4(loc.door.x, loc.door.y, loc.door.z, loc.door.w),
    }
end

function Companion.ResolveDest(r, rel, spec, src)
    if type(spec) ~= 'table' then return nil end
    if type(spec.waypoint) == 'table' and Config.Destinations.AllowWaypoint then
        local x, y, z = tonumber(spec.waypoint.x), tonumber(spec.waypoint.y), tonumber(spec.waypoint.z) or 0.0
        if not x or not y or math.abs(x) > 9000 or math.abs(y) > 9000 then return nil end
        local pp = NPC.PlayerCoords(src)
        if pp and Utils.Dist2D(pp, vector3(x, y, 0.0)) > (Config.Destinations.MaxDistance or 9000.0) then return nil end
        local p = vector3(x + 0.0, y + 0.0, z + 0.0)
        local near = SC.Aware.Place(p, 60.0)
        return { id = near and near.id or nil, label = near and near.label or L('dest_waypoint'), type = 'other',
            loc = near and Sim.Locations[near.id] or nil, pos = p, drive = vector4(p.x, p.y, p.z, 0.0), waypoint = true }
    end
    local key = spec.location
    if type(key) ~= 'string' then return nil end
    for _, d in ipairs(Config.Destinations.List or {}) do
        if d.id == key then
            if d.location and Sim.Locations[d.location] then
                local out = destFromLocation(Sim.Locations[d.location])
                out.label = d.label or out.label
                return out
            end
            if d.types then
                local home = Sim.Locations[r.homeId]
                local origin = NPC.Coords(r) or (home and home.door)
                local loc = Sim.PickPlace(r, d.types, origin, 6000.0, Clock.MinuteOfDay(), nil)
                return destFromLocation(loc)
            end
        end
    end
    local loc = Sim.Locations[key]
    if loc and (loc.public or (key == r.homeId and rel and (rel.romance ~= 'none' or SC.StageAtLeast(rel.stage, 'close_friend')))) then
        return destFromLocation(loc)
    end
    return nil
end

-- ---------------------------------------------------------------------
-- Koltuklar (sunucuda atanır; birden fazla NPC paylaşır)
-- ---------------------------------------------------------------------
local function requestSeatCount(veh, src)
    local model = GetEntityModel(veh)
    if seatPending[model] or not src then return end
    seatPending[model] = true
    local done = false
    lib.callback('samy-citizens:vehicleSeats', src, function(n)
        if done then return end
        done = true
        n = tonumber(n)
        if n then seatCache[model] = { n = Utils.Clamp(math.floor(n), 0, 15), at = os.time() } end
        seatPending[model] = nil
    end, NetworkGetNetworkIdFromEntity(veh))
    SetTimeout(5000, function()
        if not done then
            done = true
            seatPending[model] = nil
        end
    end)
end

-- dönüş: yolcu koltuğu sayısı ya da nil (henüz öğrenilmedi)
function Companion.SeatCount(veh, src)
    local model = GetEntityModel(veh)
    local e = seatCache[model]
    if e and os.time() - e.at < (V.SeatCacheSec or 3600) then return e.n end
    requestSeatCount(veh, src)
    return nil
end

local function seatReserved(net, seat, exceptId)
    for _, set in pairs(NPC.companionsBySrc) do
        for rid in pairs(set) do
            if rid ~= exceptId then
                local r = Sim.Residents[rid]
                local ov = r and NPC.Companion(r)
                if ov and ov.veh == net and ov.seat == seat and (ov.phase == 'enter' or ov.phase == 'ride') then return true end
            end
        end
    end
    return false
end

function Companion.FindSeat(r, veh, count, exclude)
    local ped = NPC.Ped(r)
    local net = NetworkGetNetworkIdFromEntity(veh)
    for seat = 0, math.max(0, count - 1) do
        if seat ~= exclude then
            local occ = GetPedInVehicleSeat(veh, seat)
            if (not occ or occ == 0 or occ == ped) and not seatReserved(net, seat, r.id) then return seat end
        end
    end
    return nil
end

function Companion.BoardVehicle(r, ov, veh, exclude)
    local count = Companion.SeatCount(veh, ov.target)
    if count == nil then
        if ov.phase ~= 'wait_car' then setPhase(r, ov, 'wait_car') end
        ov.retryAt = GetGameTimer() + 1500
        return false
    end
    local seat = Companion.FindSeat(r, veh, count, exclude)
    if not seat then
        if ov.phase ~= 'wait_car' then setPhase(r, ov, 'wait_car') end
        if not ov.noSeatSaid then
            ov.noSeatSaid = true
            say(r, ov, 'no_seat')
        end
        ov.waitVeh = NetworkGetNetworkIdFromEntity(veh)
        ov.retryAt = GetGameTimer() + 3000
        return false
    end
    ov.veh = NetworkGetNetworkIdFromEntity(veh)
    ov.seat = seat
    ov.enterStarted = GetGameTimer()
    ov.noSeatSaid = nil
    ov.phase = nil
    setPhase(r, ov, 'enter')
    return true
end

-- ---------------------------------------------------------------------
-- Başlat / durdur
-- ---------------------------------------------------------------------
--[[
    mode: 'follow' (goto için Companion.GoTo)
    opts = { decided = true (karar diyalogda verildi), vehNet = oyuncu aracı (arabama davet), force = NPC başlattı }
]]
function Companion.Start(r, src, mode, opts)
    opts = opts or {}
    if F.Enabled == false then return false, 'err_follow_disabled' end
    if not r or not r.enabled or r.status ~= 'alive' then return false, 'err_unavailable' end
    local ped = NPC.Ped(r)
    local pped = NPC.PlayerPed(src)
    if not ped or not pped then return false, 'err_unavailable' end
    local cid = SC.Bridge.GetCitizenId(src)
    if not cid then return false, 'err_no_char' end
    if SC.Hostage.Is(r) then return false, 'err_npc_hostage' end
    local existing = NPC.Companion(r)
    if existing and existing.target ~= src then return false, 'err_companion_busy' end
    local maxD = (opts.vehNet and ((V.InviteDistance or 12.0) + 10.0)) or ((F.StartDistance or 6.0) + 3.0)
    if Utils.Dist(GetEntityCoords(ped), GetEntityCoords(pped)) > maxD then return false, 'err_too_far' end
    if not existing then
        local okState = SC.State.CanEnter(r, 'FOLLOWING')
        if not okState then return false, 'err_npc_busy_state' end
        if #NPC.CompanionsOf(src) >= (F.MaxCompanionsPerPlayer or 3) then return false, 'err_companion_limit' end
    end
    local rel = SC.Rel.Get(r.id, cid)
    if not opts.decided and not opts.force then
        local ok, reason = SC.Persona.Decide(r, rel, opts.vehNet and 'ride' or 'follow', { cid = cid })
        if not ok then
            say(r, { cid = cid }, opts.vehNet and 'ride_refuse' or 'follow_refuse')
            return false, 'err_npc_refuses_' .. tostring(reason)
        end
    end
    local inviteVeh = opts.vehNet and vehFromNet(opts.vehNet) or nil
    if opts.vehNet then
        if not inviteVeh or Entity(inviteVeh).state.scVeh then return false, 'err_no_vehicle' end
        if Utils.Dist(GetEntityCoords(inviteVeh), GetEntityCoords(pped)) > (V.InviteDistance or 12.0) + 2.0 then return false, 'err_no_vehicle' end
    end
    if r.convo then SC.Convo.End(r, 'follow') end
    local now = GetGameTimer()
    local ov = existing or {
        type = 'companion', target = src, cid = cid, mode = mode or 'follow', slot = nextSlot(src), startedAt = now,
        startedAtOs = os.time(), idleScenario = idleScenario(r), walkMs = 0,
    }
    ov.untilMs = now + (F.MaxMinutes or 30) * 60000
    ov.lastTick = now
    ov.fails = 0
    if not existing then
        ov.phase = 'follow'
        ov.phaseAt = now
        -- NPC başlattığında da ara sıra kendiliğinden konuşsun
        ov.nextAuto = os.time() + math.random(30, 90)
        Sim.SetOverride(r, ov)
        NPC.IndexCompanion(r, src, true)
        SC.RelXP.JealousyCheck(src, cid, r, 'follow')
        notify(src, 'notify_companion_start', 'success', r.firstname)
    end
    if inviteVeh then
        -- arabama davet: kapı kilitliyse açmaya gerek yok, oyuncu aracın sahibi; koltuk sunucuda atanır
        Companion.BoardVehicle(r, ov, inviteVeh)
    elseif existing then
        setPhase(r, ov, 'follow')
    end
    return true
end

function Companion.Resume(r, src)
    local ov = NPC.Companion(r)
    if not ov or ov.target ~= src then return false end
    if ov.phase == 'wait' and ov.waitSince and os.time() - ov.waitSince > (F.WaitPenaltyAfterMinutes or 5) * 60 then
        local rel = SC.Rel.Peek(r.id, ov.cid)
        if rel then
            SC.RelXP.Add(rel, 'made_wait', { r = r, src = src })
            SC.RelXP.Stat(rel, 'waits', 1)
        end
    end
    ov.waitSince, ov.waitPos = nil, nil
    ov.untilMs = math.max(ov.untilMs or 0, GetGameTimer() + 10 * 60000)
    setPhase(r, ov, 'follow')
    return true
end

-- how: 'wait' | 'dismissed'
function Companion.Stop(r, how, src)
    local ov = NPC.Companion(r)
    if not ov or (src and ov.target ~= src) then return false end
    if how == 'wait' then
        local pos = SC.Spawner.GetPedCoords(r)
        ov.waitPos = pos and Utils.VecToTable(pos) or nil
        ov.waitSince = os.time()
        setPhase(r, ov, 'wait')
        return true
    end
    Companion.End(r, 'dismissed')
    return true
end

local QUIET = { dropped = true, despawn = true, shutdown = true, dead = true, hostage = true, flee = true, admin = true, dismissed = true }
local END_LINES = { duty = 'duty_leave', timeout = 'timeout_leave', waited = 'waited_leave', left_behind = 'left_behind',
    lost = 'lost_leave', date_over = 'timeout_leave', stuck = 'lost_leave', player_down = 'lost_leave' }

-- NPC'nin kendi arabası: kullanım bitince bulunduğu yere en yakın konumda "park edilmiş" sayılır
local function releaseNpcCar(r, ov)
    if not ov.npcVeh or not r.car then return end
    r.car.inUse = false
    local veh = vehFromNet(ov.npcVeh)
    if veh then
        local near = SC.Aware.Place(GetEntityCoords(veh), 500.0)
        if near then r.car.locationId = near.id end
        SetVehicleDoorsLocked(veh, 2)
    end
    r.dirty = true
end

local function releaseDatePoint(ov)
    if ov.dateLoc and ov.datePoint then
        local occ = Sim.Occupancy[ov.dateLoc]
        if occ and occ[ov.datePoint] == ov.rid then occ[ov.datePoint] = nil end
    end
    ov.dateLoc, ov.datePoint = nil, nil
end

function Companion.End(r, reason, opts)
    local ov = NPC.Companion(r)
    if not ov then return end
    local src = ov.target
    NPC.IndexCompanion(r, src, false)
    releaseDatePoint(ov)
    releaseNpcCar(r, ov)
    local rel = SC.Rel.Peek(r.id, ov.cid)
    if rel then
        if reason == 'left_behind' then
            SC.RelXP.Add(rel, 'abandon', { r = r, src = src })
            SC.RelXP.Stat(rel, 'abandons', 1)
            SC.Memory.AddAsync(r.id, ov.cid, L('mem_abandoned', rel.char_name or L('ctx_someone')), 5, 'event',
                { valence = -1, data = { code = 'abandoned' } })
        elseif reason == 'waited' then
            SC.RelXP.Add(rel, 'made_wait', { r = r, src = src })
            SC.RelXP.Stat(rel, 'waits', 1)
            SC.Memory.AddAsync(r.id, ov.cid, L('mem_made_wait', rel.char_name or L('ctx_someone')), 4, 'event',
                { valence = -1, data = { code = 'made_wait' } })
        end
        SC.Rel.Touch(rel)
    end
    if not QUIET[reason] and END_LINES[reason] and SC.Spawner.GetPed(r) then say(r, ov, END_LINES[reason]) end
    Sim.ClearOverride(r, 'companion_' .. tostring(reason))
    if not (opts and opts.silent) and reason ~= 'dropped' then
        notify(src, 'notify_companion_end_' .. tostring(reason), 'inform', r.firstname)
    end
end

-- ---------------------------------------------------------------------
-- Beraber bir yere gitmek
-- ---------------------------------------------------------------------
function Companion.GoTo(r, src, spec, opts)
    opts = opts or {}
    local cid = SC.Bridge.GetCitizenId(src)
    if not cid then return false end
    local rel = SC.Rel.Get(r.id, cid)
    local dest = Companion.ResolveDest(r, rel, spec, src)
    if not dest then
        say(r, { cid = cid }, 'go_unknown')
        return false, 'err_dest'
    end
    if not NPC.Companion(r) then
        local ok, err = Companion.Start(r, src, 'goto', { decided = opts.decided })
        if not ok then return false, err end
    end
    local ov = NPC.Companion(r)
    if not ov then return false end
    ov.mode = 'goto'
    ov.dest = dest
    ov.arrived = nil
    ov.untilMs = math.max(ov.untilMs or 0, GetGameTimer() + (F.MaxMinutes or 30) * 60000)
    local ped = NPC.Ped(r)
    local pped = NPC.PlayerPed(src)
    if not ped or not pped then return false end
    local npos = GetEntityCoords(ped)
    local pveh = GetVehiclePedIsIn(pped, false)
    -- 1) oyuncu araçta -> oyuncu sürer
    -- 2) NPC'nin kendi arabası yakında -> NPC sürer
    -- 3) yakınsa yürürler, uzaksa NPC oyuncunun bir araca binmesini bekler (takip ederek)
    local driver = 'player'
    local npcCar
    if (not pveh or pveh == 0) and V.AllowNpcDriver ~= false and r.vehicle and r.car and not r.car.missing and r.vehicle.type ~= 'bike' then
        local rec = Spawner.vehicles[r.id]
        if rec and DoesEntityExist(rec.entity) and Utils.Dist(GetEntityCoords(rec.entity), npos) <= (V.NpcCarMaxDistance or 70.0) then
            npcCar = rec.entity
        end
    end
    if npcCar then
        driver = 'npc'
    elseif (not pveh or pveh == 0) and Utils.Dist(npos, dest.pos) <= 350.0 then
        driver = 'walk'
    end
    ov.driver = driver
    TriggerClientEvent('samy-citizens:client:waypoint', src, dest.pos.x, dest.pos.y, dest.label)
    if driver == 'npc' then
        ov.npcVeh = NetworkGetNetworkIdFromEntity(npcCar)
        r.car.inUse = true
        SetVehicleDoorsLocked(npcCar, 1)
        say(r, ov, 'go_npc_drive')
        ov.phase = nil
        setPhase(r, ov, 'to_car')
    else
        say(r, ov, driver == 'walk' and 'go_walk' or 'go_player_drive')
        if pveh and pveh ~= 0 then
            Companion.BoardVehicle(r, ov, pveh)
        else
            ov.phase = nil
            setPhase(r, ov, 'follow')
        end
    end
    SC.RelXP.JealousyCheck(src, cid, r, 'go')
    return true
end

-- Varış: birlikte vakit geçirme (date) fazı
function Companion.Arrive(r, ov)
    if ov.arrived then return end
    ov.arrived = true
    local dest = ov.dest
    say(r, ov, 'go_arrive')
    local rel = SC.Rel.Peek(r.id, ov.cid)
    if rel and dest then
        local key = dest.id or ('wp_' .. math.floor(dest.pos.x / 50) .. '_' .. math.floor(dest.pos.y / 50))
        local firstTime = SC.RelXP.AddPlace(rel, key)
        local dating = rel.romance and rel.romance ~= 'none'
        SC.RelXP.Add(rel, dating and 'date' or 'visit_place', { r = r, src = ov.target })
        SC.RelXP.Stat(rel, 'visits', 1)
        if dating then SC.RelXP.Stat(rel, 'dates', 1) end
        if firstTime then
            SC.Memory.AddAsync(r.id, ov.cid, L('mem_visited_together', rel.char_name or L('ctx_someone'), dest.label), 5, 'event',
                { valence = 1, data = { code = 'visit_place', place = dest.id } })
        end
    end
    -- varılan konumda uygun bir aktivite noktası
    ov.datePos, ov.dateScenario, ov.dateLoc, ov.datePoint = nil, nil, nil, nil
    local loc = dest and dest.loc
    if loc then
        local act = (Config.Destinations.ActivityByType or {})[loc.type] or 'leisure'
        local def = SC.Activities[act]
        local occ = Sim.Occupancy[loc.id] or {}
        Sim.Occupancy[loc.id] = occ
        for i, p in ipairs(loc.points or {}) do
            local tagOk = false
            for _, t in ipairs(p.tags or {}) do
                for _, at in ipairs((def and def.tags) or {}) do if t == at then tagOk = true end end
            end
            if tagOk and not occ[i] then
                occ[i] = r.id
                ov.rid = r.id
                ov.dateLoc, ov.datePoint = loc.id, i
                ov.datePos = { x = p.coords.x, y = p.coords.y, z = p.coords.z, h = p.coords.w }
                ov.dateScenario = p.scenario or (def and def.scenario)
                break
            end
        end
    end
    ov.dest = nil
    ov.untilMs = math.max(ov.untilMs or 0, GetGameTimer() + 12 * 60000)
    setPhase(r, ov, 'date')
end

-- ---------------------------------------------------------------------
-- Görev tanımı (Spawner.BuildTask çağırır)
-- ---------------------------------------------------------------------
function Companion.BuildTask(r, ov)
    local spec = { kind = 'companion', target = ov.target, phase = ov.phase or 'follow', slot = ov.slot or 1, idleScenario = ov.idleScenario }
    local ph = spec.phase
    if ph == 'enter' or ph == 'ride' or ph == 'exit' then
        spec.veh, spec.seat = ov.veh, ov.seat
    elseif ph == 'wait_car' then
        spec.veh = ov.waitVeh
    elseif ph == 'to_car' or ph == 'wait_passenger' or ph == 'driving' or ph == 'hold' or ph == 'arrive' then
        spec.veh, spec.seat = ov.npcVeh, -1
        local d = ov.dest and ov.dest.drive
        if d then spec.dest = { x = d.x, y = d.y, z = d.z, h = d.w or 0.0 } end
        spec.speed = V.DriveSpeed or 15.0
        spec.style = V.DrivingStyle or 786603
        spec.park = V.ParkDistance or 24.0
    elseif ph == 'wait' then
        spec.pos = ov.waitPos
        spec.scenario = ov.idleScenario or 'WORLD_HUMAN_STAND_IMPATIENT'
    elseif ph == 'date' then
        spec.pos = ov.datePos
        spec.scenario = ov.dateScenario or ov.idleScenario
    end
    return spec
end

-- ---------------------------------------------------------------------
-- İstemci olayları (sadece ped'in network sahibinden; spawner doğrular)
-- ---------------------------------------------------------------------
function Companion.OnTaskEvent(r, event, data)
    local ov = NPC.Companion(r)
    if not ov then return end
    if event == 'comp_entered' then
        if ov.phase == 'enter' then
            ov.rideStart = os.time()
            if math.random() < 0.5 then say(r, ov, 'boarded') end
            setPhase(r, ov, 'ride')
        end
    elseif event == 'comp_seatfail' then
        ov.seatFails = (ov.seatFails or 0) + 1
        local veh = vehFromNet(ov.veh)
        if not veh or ov.seatFails > 3 then
            ov.seatFails = 0
            setPhase(r, ov, 'follow')
            return
        end
        Companion.BoardVehicle(r, ov, veh, ov.seat)
    elseif event == 'comp_locked' then
        say(r, ov, 'door_locked', 'locked', 12)
    elseif event == 'comp_driver_ready' then
        if ov.phase == 'to_car' then
            say(r, ov, 'npc_drive_wait', 'drivewait', 15)
            setPhase(r, ov, 'wait_passenger')
        end
    elseif event == 'comp_parked' then
        if ov.phase == 'driving' then setPhase(r, ov, 'arrive') end
    elseif event == 'comp_stuck' then
        if ov.phase == 'driving' then
            setPhase(r, ov, 'arrive')
        elseif ov.phase == 'to_car' then
            ov.npcVeh = nil
            releaseNpcCar(r, ov)
            say(r, ov, 'go_player_drive')
            setPhase(r, ov, 'follow')
        end
    elseif event == 'comp_warped' then
        SC.DebugPrint(('companion failsafe: %s oyuncunun yakınına alındı'):format(r.id))
    end
end

-- ---------------------------------------------------------------------
-- Tick (1 sn)
-- ---------------------------------------------------------------------
local function rideXp(r, ov)
    if not ov.rideStart then return end
    local dur = os.time() - ov.rideStart
    ov.rideStart = nil
    if dur < (V.RideMinSeconds or 60) then return end
    local rel = SC.Rel.Peek(r.id, ov.cid)
    if not rel then return end
    SC.RelXP.Add(rel, 'ride', { r = r, src = ov.target })
    SC.RelXP.Stat(rel, 'rides', 1)
    local last = tonumber(SC.RelXP.Stats(rel).lastRideMem) or 0
    SC.RelXP.SetStat(rel, 'lastRide', os.time())
    if os.time() - last > ((Config.Memory and Config.Memory.PlaceMemoryCooldownHours) or 12) * 3600 then
        SC.RelXP.SetStat(rel, 'lastRideMem', os.time())
        SC.Memory.AddAsync(r.id, ov.cid, L('mem_ride_together', rel.char_name or L('ctx_someone')), 4, 'event',
            { valence = 1, data = { code = 'ride' } })
    end
end

local function tickOne(r, ov, nowMs)
    local src = ov.target
    if not GetPlayerName(src) then return Companion.End(r, 'dropped') end
    local ped = NPC.Ped(r)
    if not ped then return Companion.End(r, 'despawn') end
    if GetEntityHealth(ped) <= 0 then return Companion.End(r, 'dead') end
    local pped = NPC.PlayerPed(src)
    if not pped then return end
    if GetEntityHealth(pped) <= 0 then return Companion.End(r, 'player_down') end
    local dt = nowMs - (ov.lastTick or nowMs)
    ov.lastTick = nowMs
    local npos, ppos = GetEntityCoords(ped), GetEntityCoords(pped)
    local d = Utils.Dist(npos, ppos)
    local pveh = GetVehiclePedIsIn(pped, false)
    if pveh == 0 then pveh = nil end
    local nveh = GetVehiclePedIsIn(ped, false)
    if nveh == 0 then nveh = nil end
    local ph = ov.phase

    if nowMs > (ov.untilMs or 0) and not nveh and ph ~= 'driving' then return Companion.End(r, 'timeout') end
    -- zorunlu iş/ders/randevu yaklaşıyorsa izin ister (araçtaysa indirilmeyi bekler)
    if not ov.dutyAt or nowMs - ov.dutyAt > 15000 then
        ov.dutyAt = nowMs
        if dutySoon(r) then
            if not nveh then return Companion.End(r, 'duty') end
            if not ov.dutyAsked then
                ov.dutyAsked = true
                say(r, ov, 'duty_drop')
            end
        end
    end

    if ph == 'follow' then
        if pveh then return Companion.BoardVehicle(r, ov, pveh) end
        if d > (F.LostDistance or 160.0) then return Companion.End(r, 'lost') end
        if d < 25.0 then
            ov.walkMs = (ov.walkMs or 0) + dt
            if ov.walkMs >= 60000 then
                ov.walkMs = ov.walkMs - 60000
                local rel = SC.Rel.Peek(r.id, ov.cid)
                if rel then
                    SC.RelXP.Add(rel, 'walk_minute', { r = r, src = src })
                    SC.RelXP.Stat(rel, 'walks', 1)
                end
            end
        end
        if ov.dest then
            local ar = Config.Destinations.ArriveRadius or 32.0
            if Utils.Dist(ppos, ov.dest.pos) <= ar and Utils.Dist(npos, ov.dest.pos) <= ar + 12.0 then Companion.Arrive(r, ov) end
        end
    elseif ph == 'wait_car' then
        if not pveh then
            setPhase(r, ov, 'follow')
        elseif nowMs >= (ov.retryAt or 0) then
            Companion.BoardVehicle(r, ov, pveh)
        end
        if d > (F.LeftBehindDistance or 90.0) then return Companion.End(r, 'left_behind') end
    elseif ph == 'enter' then
        local veh = vehFromNet(ov.veh)
        if not veh then return setPhase(r, ov, 'follow') end
        if nveh == veh then
            ov.rideStart = ov.rideStart or os.time()
            return Companion.OnTaskEvent(r, 'comp_entered')
        end
        if pveh ~= veh then
            if pveh then return Companion.BoardVehicle(r, ov, pveh) end
            return setPhase(r, ov, 'follow')
        end
        if Utils.Dist(GetEntityCoords(veh), npos) > (F.LeftBehindDistance or 90.0) then return Companion.End(r, 'left_behind') end
        -- toplam süre aşıldıysa başka koltuk dene (istemci de dener)
        local limit = (V.EnterTimeoutMs or 16000) * ((V.EnterRetries or 3) + 1) + 5000
        if nowMs - (ov.enterStarted or nowMs) > limit then
            ov.enterStarted = nowMs
            Companion.OnTaskEvent(r, 'comp_seatfail')
        end
    elseif ph == 'ride' then
        local veh = vehFromNet(ov.veh)
        if not nveh then
            if pveh then return Companion.BoardVehicle(r, ov, pveh) end
            rideXp(r, ov)
            return setPhase(r, ov, 'follow')
        end
        if not pveh or pveh ~= nveh then
            rideXp(r, ov)
            return setPhase(r, ov, 'exit')
        end
        if ov.dest and veh and not ov.arriveSaid then
            local ar = Config.Destinations.ArriveRadius or 32.0
            if Utils.Dist(GetEntityCoords(veh), ov.dest.pos) <= ar then
                ov.arriveSaid = true
                say(r, ov, 'go_arrive')
            end
        end
    elseif ph == 'exit' then
        if not nveh then
            if ov.dest and Utils.Dist(npos, ov.dest.pos) <= (Config.Destinations.ArriveRadius or 32.0) + 15.0 then
                return Companion.Arrive(r, ov)
            end
            return setPhase(r, ov, 'follow')
        elseif pveh and pveh == nveh then
            ov.rideStart = ov.rideStart or os.time()
            return setPhase(r, ov, 'ride')
        end
    elseif ph == 'wait' then
        if os.time() - (ov.waitSince or os.time()) > (F.WaitMaxMinutes or 10) * 60 then return Companion.End(r, 'waited') end
    elseif ph == 'date' then
        if pveh and d < 25.0 then return setPhase(r, ov, 'follow') end
        if d > 45.0 then
            ov.farSince = ov.farSince or os.time()
            if os.time() - ov.farSince > 60 then return Companion.End(r, 'date_over') end
        else
            ov.farSince = nil
        end
    elseif ph == 'to_car' then
        local veh = vehFromNet(ov.npcVeh)
        if not veh then
            releaseNpcCar(r, ov)
            ov.npcVeh = nil
            say(r, ov, 'go_player_drive')
            return setPhase(r, ov, 'follow')
        end
        if nveh == veh and GetPedInVehicleSeat(veh, -1) == ped then return Companion.OnTaskEvent(r, 'comp_driver_ready') end
        if nowMs - (ov.phaseAt or nowMs) > 45000 then return Companion.OnTaskEvent(r, 'comp_stuck') end
    elseif ph == 'wait_passenger' then
        local veh = vehFromNet(ov.npcVeh)
        if not veh or nveh ~= veh then return setPhase(r, ov, 'to_car') end
        if pveh == veh then
            ov.rideStart = os.time()
            return setPhase(r, ov, 'driving')
        end
        if d > (F.LeftBehindDistance or 90.0) then return Companion.End(r, 'left_behind') end
        if nowMs - (ov.phaseAt or nowMs) > 120000 then return Companion.End(r, 'waited') end
        if nowMs - (ov.phaseAt or nowMs) > 20000 then say(r, ov, 'npc_drive_wait', 'drivewait', 25) end
    elseif ph == 'driving' then
        local veh = vehFromNet(ov.npcVeh)
        if not veh or nveh ~= veh then return setPhase(r, ov, 'arrive') end
        if pveh ~= veh then return setPhase(r, ov, 'hold') end
        if ov.dest and ov.dest.drive then
            local vpos = GetEntityCoords(veh)
            if Utils.Dist2D(vpos, ov.dest.drive) <= (V.ParkDistance or 24.0) * 0.6 then
                local okV, vel = pcall(function() return GetEntityVelocity(veh) end)
                local sp = okV and vel and math.sqrt(vel.x * vel.x + vel.y * vel.y) or 0.0
                if sp < 1.0 then setPhase(r, ov, 'arrive') end
            end
        end
    elseif ph == 'hold' then
        local veh = vehFromNet(ov.npcVeh)
        if veh and pveh == veh then return setPhase(r, ov, 'driving') end
        if d > (F.LeftBehindDistance or 90.0) then return Companion.End(r, 'left_behind') end
        if nowMs - (ov.phaseAt or nowMs) > 90000 then return setPhase(r, ov, 'arrive') end
    elseif ph == 'arrive' then
        if not nveh then
            rideXp(r, ov)
            releaseNpcCar(r, ov)
            ov.npcVeh = nil
            if ov.dest then return Companion.Arrive(r, ov) end
            return setPhase(r, ov, 'follow')
        end
    end
end

function Companion.Tick()
    local nowMs = GetGameTimer()
    for src, set in pairs(NPC.companionsBySrc) do
        for rid in pairs(set) do
            local r = Sim.Residents[rid]
            local ov = r and NPC.Companion(r)
            if not ov or ov.target ~= src then
                set[rid] = nil
            else
                local ok, err = pcall(tickOne, r, ov, nowMs)
                if not ok then print(('^1[samy-citizens] eşlik hatası (%s): %s^7'):format(rid, tostring(err))) end
            end
        end
        if next(set) == nil then NPC.companionsBySrc[src] = nil end
    end
    -- eski konuşma balonu kısıtlamaları
    local now = os.time()
    for k, t in pairs(bubbleThrottle) do
        if now - t > 120 then bubbleThrottle[k] = nil end
    end
end

function Companion.OnPlayerLeft(src)
    for _, r in ipairs(NPC.CompanionsOf(src)) do Companion.End(r, 'dropped') end
    NPC.companionsBySrc[src] = nil
end

-- ---------------------------------------------------------------------
-- Oyuncu olayları
-- ---------------------------------------------------------------------
-- NPC'nin teklifini ox_target "Teklifi kabul et" ile kabul etmek
RegisterNetEvent('samy-citizens:server:acceptProposal', function(netId)
    local src = source
    local r = NPC.ByNet(netId)
    if not r then return end
    local cid = SC.Bridge.GetCitizenId(src)
    if not cid or not SC.Spawner.PlayerNear(src, r, 6.0) then return end
    local p = SC.Context.TakeProposal(r.id, cid)
    if not p then return end
    local ped = NPC.Ped(r)
    if ped then Entity(ped).state:set('scProposal', nil, true) end
    CreateThread(function()
        SC.Companion.GoTo(r, src, { location = p.dest }, { decided = true })
    end)
end)
