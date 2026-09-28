--[[
    FİZİKSEL KATMAN
    Oyuncu, sakinin hesaplanan konumuna SpawnRadius kadar yaklaşınca sunucu network ped'i oluşturur.
    Görevleri ped'in network sahibi istemci yürütür: görev tanımı Entity(ped).state.scTask statebag'inde
    { seq, kind, ... } olarak durur; sahiplik değişince yeni sahip aynı görevi devam ettirir.
]]
local Utils = SC.Utils
local Clock = SC.Clock
local Sim = SC.Sim

local Spawner = {}
SC.Spawner = Spawner

Spawner.peds = {}      -- residentId -> phys
Spawner.byNet = {}     -- netId -> residentId
Spawner.vehicles = {}  -- residentId -> { entity, netId }

local spawning = {}
local vehSpawning = {}
local registryDirty = true
local players = {}

-- ---------------------------------------------------------------------
-- Yardımcılar
-- ---------------------------------------------------------------------
local function collectPlayers()
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 and GetPlayerRoutingBucket(src) == 0 then
            out[#out + 1] = { src = src, ped = ped, coords = GetEntityCoords(ped) }
        end
    end
    return out
end

local function nearestPlayer(list, pos)
    local best, bestSrc = math.huge, nil
    for _, p in ipairs(list) do
        local d = Utils.Dist(p.coords, pos)
        if d < best then best, bestSrc = d, p.src end
    end
    return best, bestSrc
end

function Spawner.Players()
    return players
end

function Spawner.Count()
    local n = 0
    for _ in pairs(Spawner.peds) do n = n + 1 end
    return n
end

function Spawner.GetPed(r)
    local phys = r and Spawner.peds[r.id]
    if phys and DoesEntityExist(phys.ped) then return phys.ped end
    return nil
end

function Spawner.GetPedCoords(r)
    local ped = Spawner.GetPed(r)
    if ped then return GetEntityCoords(ped) end
    return nil
end

function Spawner.GetResidentByNet(netId)
    local rid = Spawner.byNet[tonumber(netId) or -1]
    return rid and Sim.Residents[rid] or nil
end

function Spawner.GetResidentByEntity(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    local rid = Entity(ent).state.scId
    return rid and Sim.Residents[rid] or nil
end

local function waitExists(ent, ms)
    local timeout = GetGameTimer() + (ms or 3000)
    while not DoesEntityExist(ent) and GetGameTimer() < timeout do Wait(0) end
    return DoesEntityExist(ent)
end

-- Yakındaki bir istemciden konumu zemine/yola/navmesh'e oturtmasını ister
local function snap(src, pos, mode, dest)
    if not src then return nil end
    local p = promise.new()
    local done = false
    lib.callback('samy-citizens:snap', src, function(res)
        if done then return end
        done = true
        p:resolve(res)
    end, { x = pos.x, y = pos.y, z = pos.z, mode = mode, dx = dest and dest.x or nil, dy = dest and dest.y or nil })
    SetTimeout(Config.SnapTimeoutMs or 2500, function()
        if done then return end
        done = true
        p:resolve(nil)
    end)
    local res = Citizen.Await(p)
    if type(res) == 'table' and tonumber(res.x) then
        return vector3(res.x + 0.0, res.y + 0.0, res.z + 0.0), tonumber(res.h)
    end
    return nil
end

local function publishRegistry()
    local reg = {}
    for rid, phys in pairs(Spawner.peds) do
        reg[tostring(phys.netId)] = rid
    end
    GlobalState.scPeds = reg
    registryDirty = false
end

-- ---------------------------------------------------------------------
-- Araçlar
-- ---------------------------------------------------------------------
local function createVehicle(r, pos, heading, locked)
    local v = r.vehicle
    if not v or not v.model then return nil end
    local veh = CreateVehicleServerSetter(GetHashKey(v.model), v.type or 'automobile', pos.x, pos.y, pos.z + 0.3, heading or 0.0)
    if not veh or veh == 0 or not waitExists(veh, 3000) then return nil end
    SetVehicleNumberPlateText(veh, v.plate or 'SAKIN')
    if type(v.color) == 'table' and v.color[1] then
        SetVehicleColours(veh, math.floor(v.color[1]), math.floor(v.color[2] or v.color[1]))
    end
    SetVehicleDoorsLocked(veh, locked and 2 or 1)
    if SetEntityOrphanMode then SetEntityOrphanMode(veh, 2) end
    Entity(veh).state:set('scVeh', r.id, true)
    local rec = { entity = veh, netId = NetworkGetNetworkIdFromEntity(veh), spawnedAt = GetGameTimer() }
    Spawner.vehicles[r.id] = rec
    return veh
end

local function vehicleHasPlayer(veh)
    for seat = -1, 6 do
        local occ = GetPedInVehicleSeat(veh, seat)
        if occ and occ ~= 0 and IsPedAPlayer(occ) then return true, occ, seat end
    end
    return false
end

function Spawner.DeleteVehicle(r)
    local rec = Spawner.vehicles[r.id]
    if not rec then return end
    if DoesEntityExist(rec.entity) and not vehicleHasPlayer(rec.entity) then
        DeleteEntity(rec.entity)
    end
    Spawner.vehicles[r.id] = nil
end

-- Sürüş için araç: mevcutsa ve yakınsa onu kullanır, değilse pos'ta oluşturur
function Spawner.EnsureVehicle(r, pos, heading)
    local rec = Spawner.vehicles[r.id]
    if rec and DoesEntityExist(rec.entity) then
        local vc = GetEntityCoords(rec.entity)
        if Utils.Dist(vc, pos) <= 80.0 then
            SetVehicleDoorsLocked(rec.entity, 1)
            return rec.entity
        end
        if vehicleHasPlayer(rec.entity) then return nil end
        DeleteEntity(rec.entity)
        Spawner.vehicles[r.id] = nil
    end
    return createVehicle(r, pos, heading, false)
end

function Spawner.TickVehicles()
    for _, r in ipairs(Sim.List) do
        if r.vehicle and r.car and r.enabled then
            local rec = Spawner.vehicles[r.id]
            local driving = r.phys and r.phys.taskKind == 'drive'
            if rec then
                if not DoesEntityExist(rec.entity) then
                    Spawner.vehicles[r.id] = nil
                    if r.car.missing and (os.time() - (r.car.missingSince or 0)) > 60 then
                        -- çalınan araç ortadan kalktı: bir süre sonra "sigortadan" geri gelir
                        r.car.recoverAt = os.time() + 600
                    end
                else
                    local hasPlayer, occ, seat = vehicleHasPlayer(rec.entity)
                    if hasPlayer and seat == -1 and not r.car.missing and Config.World.CarTheftDetection then
                        local thief = NetworkGetEntityOwner(occ)
                        if SC.World then SC.World.OnCarStolen(r, thief) end
                    end
                    if not hasPlayer and not driving then
                        local vc = GetEntityCoords(rec.entity)
                        local d = nearestPlayer(players, vc)
                        local limit = (Config.VehicleSpawnRadius or 130.0) + (Config.DespawnBuffer or 40.0)
                        -- sakin arabayla yola çıktı ama ped fiziksel değil: araç da "gitti"
                        if (r.car.inUse and not r.phys and d > 50.0) or d > limit then
                            DeleteEntity(rec.entity)
                            Spawner.vehicles[r.id] = nil
                        end
                    end
                end
            elseif not r.car.inUse and not r.car.missing and not vehSpawning[r.id] then
                local loc = Sim.Locations[r.car.locationId]
                if loc and loc.parking then
                    local d, src = nearestPlayer(players, loc.parking)
                    if d <= (Config.VehicleSpawnRadius or 130.0) then
                        vehSpawning[r.id] = true
                        CreateThread(function()
                            local pos = snap(src, loc.parking, 'ground') or vector3(loc.parking.x, loc.parking.y, loc.parking.z)
                            if not Spawner.vehicles[r.id] and not r.car.inUse then
                                createVehicle(r, pos, loc.parking.w, true)
                            end
                            vehSpawning[r.id] = nil
                        end)
                    end
                end
            end
            if r.car.missing and r.car.recoverAt and os.time() >= r.car.recoverAt then
                r.car.missing = nil
                r.car.recoverAt = nil
                r.car.missingSince = nil
                r.car.locationId = r.homeId
                r.dirty = true
            end
        end
    end
end

-- ---------------------------------------------------------------------
-- Görev tanımı
-- ---------------------------------------------------------------------
local function defaultScenario(activity)
    local def = SC.Activities[activity]
    return def and def.scenario or 'WORLD_HUMAN_STAND_IMPATIENT'
end

function Spawner.BuildTask(r)
    local st = r.state
    local ov = r.override
    local phys = Spawner.peds[r.id]
    -- rehine: konuşma sırasında bile rehine görevi sürer
    if ov and ov.type == 'hostage' then
        return { kind = 'hostage', mode = ov.mode, target = ov.taker, veh = ov.veh, seat = ov.seat }
    end
    if r.convo then
        return { kind = 'converse', target = r.convo.src }
    end
    if ov then
        if ov.type == 'follow' then return { kind = 'follow', target = ov.target } end
        if ov.type == 'flee' then
            return { kind = 'flee', x = ov.from and ov.from.x or 0.0, y = ov.from and ov.from.y or 0.0, z = ov.from and ov.from.z or 0.0, target = ov.target }
        end
        if ov.type == 'handsup' then return { kind = 'handsup', target = ov.target } end
        if ov.type == 'cower' then return { kind = 'cower' } end
        if ov.type == 'meet' then return { kind = 'meet', target = ov.target } end
        if ov.type == 'summoned' and ov.pos then
            return { kind = 'idle', x = ov.pos.x, y = ov.pos.y, z = ov.pos.z, scenario = 'WORLD_HUMAN_STAND_IMPATIENT' }
        end
        if ov.type == 'chat' then
            local partner = ov.partner and Spawner.peds[ov.partner]
            if partner then return { kind = 'chat', partner = partner.netId } end
        end
        if SC.Life then
            local spec = SC.Life.BuildTask(r, ov)
            if spec then return spec end
        end
    end
    if st.activity == 'commute' then
        local to = st.toPos
        if st.mode == 'car' then
            local rec = Spawner.vehicles[r.id]
            if rec and DoesEntityExist(rec.entity) then
                return {
                    kind = 'drive', veh = rec.netId, x = to.x, y = to.y, z = to.z, h = to.w or 0.0,
                    speed = Config.Travel.DriveSpeed, style = Config.Travel.DrivingStyle,
                }
            end
            return { kind = 'walk', x = to.x, y = to.y, z = to.z, h = to.w or 0.0 }
        elseif st.mode == 'walk' then
            return { kind = 'walk', x = to.x, y = to.y, z = to.z, h = to.w or 0.0 }
        end
        -- toplu taşıma: hedef yönünde biraz yürüyüp gözden kaybolur
        local from = (phys and phys.coords) or Sim.GetPosition(r) or vector3(to.x, to.y, to.z)
        local dx, dy = to.x - from.x, to.y - from.y
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 1.0 then len = 1.0 end
        return { kind = 'leave', x = from.x + dx / len * 45.0, y = from.y + dy / len * 45.0, z = from.z }
    end
    if st.pos then
        return { kind = 'idle', x = st.pos.x, y = st.pos.y, z = st.pos.z, scenario = defaultScenario(st.activity) }
    end
    local loc = Sim.Locations[st.locationId]
    if not loc then return { kind = 'idle' } end
    if st.inside then
        return { kind = 'enter', x = loc.door.x, y = loc.door.y, z = loc.door.z, h = loc.door.w }
    end
    if st.pointIndex and loc.points[st.pointIndex] then
        local p = loc.points[st.pointIndex]
        return { kind = 'scenario', x = p.coords.x, y = p.coords.y, z = p.coords.z, h = p.coords.w, scenario = p.scenario or defaultScenario(st.activity) }
    end
    return { kind = 'scenario', x = loc.door.x, y = loc.door.y, z = loc.door.z, h = loc.door.w, scenario = defaultScenario(st.activity) }
end

function Spawner.UpdateTask(r)
    local phys = Spawner.peds[r.id]
    if not phys or not DoesEntityExist(phys.ped) then return end
    local spec = Spawner.BuildTask(r)
    phys.seq = (phys.seq or 0) + 1
    spec.seq = phys.seq
    spec.act = r.state.activity
    phys.taskKind = spec.kind
    phys.taskSetAt = GetGameTimer()
    phys.traveling = (spec.kind == 'drive' or spec.kind == 'walk') and r.state.activity == 'commute'
    Entity(phys.ped).state:set('scTask', spec, true)
end

-- Tek seferlik hareket (el sallama, omuz silkme...) ve yüz ifadesi
function Spawner.PlayGesture(r, name)
    local phys = Spawner.peds[r.id]
    if not phys or not SC.Gestures[name] then return end
    phys.animSeq = (phys.animSeq or 0) + 1
    Entity(phys.ped).state:set('scAnim', { name = name, seq = phys.animSeq }, true)
end

function Spawner.SetEmotion(r, emotion)
    local phys = Spawner.peds[r.id]
    if not phys or not SC.Emotions[emotion] then return end
    Entity(phys.ped).state:set('scEmo', emotion, true)
end

-- Sim durumu değişince (Sim.Changed) çağrılır
function Spawner.OnStateChanged(r, reason)
    local phys = Spawner.peds[r.id]
    if not phys then return end
    if r.state.activity == 'commute' and r.state.mode == 'car' and not r.convo and not r.override then
        local rec = Spawner.vehicles[r.id]
        if not rec or not DoesEntityExist(rec.entity) then
            -- araç henüz yok: park yerinde ya da ped'in yanındaki yolda oluştur
            if not vehSpawning[r.id] then
                vehSpawning[r.id] = true
                CreateThread(function()
                    local fromLoc = Sim.Locations[r.state.fromLocationId or '']
                    local pedPos = GetEntityCoords(phys.ped)
                    local _, src = nearestPlayer(players, pedPos)
                    local base = (fromLoc and fromLoc.parking) or pedPos
                    local pos, h = snap(src, base, fromLoc and fromLoc.parking and 'ground' or 'road', r.state.toPos)
                    pos = pos or vector3(base.x, base.y, base.z)
                    if Spawner.peds[r.id] and r.state.activity == 'commute' and r.state.mode == 'car' then
                        createVehicle(r, pos, h or (fromLoc and fromLoc.parking and fromLoc.parking.w) or 0.0, false)
                    end
                    vehSpawning[r.id] = nil
                    Spawner.UpdateTask(r)
                end)
            end
            return
        end
    end
    Spawner.UpdateTask(r)
end

-- ---------------------------------------------------------------------
-- Spawn / despawn
-- ---------------------------------------------------------------------
local function doSpawn(r, info, src)
    local pos, heading = info.pos, info.heading or 0.0
    local veh
    if info.kind == 'car' then
        local sp, sh = snap(src, pos, 'road', r.state.toPos)
        if not sp then return end
        pos, heading = sp, sh or heading
    elseif info.kind == 'walk' or info.kind == 'pos' then
        pos = snap(src, pos, 'ped') or pos
    else
        pos = snap(src, pos, 'ground') or pos
    end
    -- await sırasında durum değişmiş olabilir
    local again = Sim.GetSpawnInfo(r)
    if not again or Spawner.peds[r.id] or not r.enabled then return end
    if info.kind == 'car' then
        if again.kind ~= 'car' then return end
        veh = Spawner.EnsureVehicle(r, pos, heading)
        if not veh then return end
    end
    local ped = CreatePed(4, GetHashKey(r.model), pos.x, pos.y, pos.z, heading, true, true)
    if not ped or ped == 0 or not waitExists(ped, 3000) then return end
    if SetEntityOrphanMode then SetEntityOrphanMode(ped, 2) end
    if SetEntityDistanceCullingRadius then SetEntityDistanceCullingRadius(ped, Config.PedCullingRadius or 350.0) end
    if veh then SetPedIntoVehicle(ped, veh, -1) end
    local netId = NetworkGetNetworkIdFromEntity(ped)
    local es = Entity(ped).state
    es:set('scId', r.id, true)
    es:set('scLook', r.appearance or false, true)
    es:set('scEmo', 'neutral', true)
    local phys = { ped = ped, netId = netId, seq = 0, spawnedAt = GetGameTimer(), coords = pos, minDist = 0 }
    Spawner.peds[r.id] = phys
    Spawner.byNet[netId] = r.id
    r.phys = phys
    r.state.emerge = nil
    registryDirty = true
    Spawner.UpdateTask(r)
    SC.DebugPrint(('spawn %s (%s) net=%d'):format(r.id, info.kind, netId))
end

function Spawner.Spawn(r, info, src)
    if spawning[r.id] then return end
    spawning[r.id] = true
    CreateThread(function()
        local ok, err = pcall(doSpawn, r, info, src)
        if not ok then print(('^1[samy-citizens] spawn hatası (%s): %s^7'):format(r.id, tostring(err))) end
        spawning[r.id] = nil
    end)
end

-- Yolculuk sırasında ped silinirse soyut ilerleme gerçek konumdan devam eder
local function rebase(r, pc)
    local st = r.state
    local now = Clock.Now()
    if st.activity == 'commute' and st.toPos then
        local remaining = Utils.Dist(pc, st.toPos)
        st.fromPos = Utils.VecToTable(pc)
        st.startedAt = now
        st.eta = now + Sim.TravelMinutes(st.mode or 'walk', remaining)
        r.dirty = true
    elseif st.pos then
        st.pos = Utils.VecToTable(pc)
        r.dirty = true
    end
end

function Spawner.Despawn(r, reason, keepVehicle)
    local phys = Spawner.peds[r.id]
    if not phys then return end
    if r.convo and SC.Convo then SC.Convo.End(r, 'despawn') end
    if SC.Hostage and SC.Hostage.Is(r) then SC.Hostage.End(r, 'despawn') end
    if SC.Life then SC.Life.OnDespawn(r) end
    -- takip / buluşma ped'e bağlıdır: ped silinirken sakin bulunduğu yerde serbest kalır
    if r.override and (r.override.type == 'follow' or r.override.type == 'meet' or r.override.type == 'chat') then
        Sim.ClearOverride(r, 'despawn')
    end
    if DoesEntityExist(phys.ped) then
        local pc = GetEntityCoords(phys.ped)
        rebase(r, pc)
        local veh = GetVehiclePedIsIn(phys.ped, false)
        DeleteEntity(phys.ped)
        local rec = Spawner.vehicles[r.id]
        if not keepVehicle and veh and veh ~= 0 and rec and rec.entity == veh and r.state.activity == 'commute' then
            if not vehicleHasPlayer(veh) then DeleteEntity(veh) end
            Spawner.vehicles[r.id] = nil
        end
    end
    Spawner.peds[r.id] = nil
    Spawner.byNet[phys.netId] = nil
    r.phys = nil
    registryDirty = true
    SC.DebugPrint(('despawn %s (%s)'):format(r.id, tostring(reason)))
end

local function farthestEvictable()
    local best, bestD = nil, -1
    for rid, phys in pairs(Spawner.peds) do
        local r = Sim.Residents[rid]
        local ot = r and r.override and r.override.type
        if r and not r.convo and not (ot == 'follow' or ot == 'meet' or ot == 'hostage' or ot == 'ride' or ot == 'goto') then
            if (phys.minDist or 0) > bestD then best, bestD = r, phys.minDist or 0 end
        end
    end
    return best, bestD
end

-- ---------------------------------------------------------------------
-- Tick
-- ---------------------------------------------------------------------
function Spawner.Tick()
    local now = Clock.Now()
    players = collectPlayers()
    local spawnR = Config.SpawnRadius or 150.0
    local despawnR = spawnR + (Config.DespawnBuffer or 40.0)
    local timer = GetGameTimer()

    -- 1) mevcut pedler
    for rid, phys in pairs(Spawner.peds) do
        local r = Sim.Residents[rid]
        if not r then
            if DoesEntityExist(phys.ped) then DeleteEntity(phys.ped) end
            Spawner.peds[rid] = nil
            Spawner.byNet[phys.netId] = nil
            registryDirty = true
        elseif not DoesEntityExist(phys.ped) then
            -- başka bir şey sildi (temizlik scripti vb.)
            if r.convo and SC.Convo then SC.Convo.End(r, 'despawn') end
            Spawner.peds[rid] = nil
            Spawner.byNet[phys.netId] = nil
            r.phys = nil
            registryDirty = true
        else
            local pc = GetEntityCoords(phys.ped)
            phys.coords = pc
            local minD = nearestPlayer(players, pc)
            phys.minDist = minD
            if not phys.deadAt and GetEntityHealth(phys.ped) <= 0 then
                phys.deadAt = timer
                if SC.World then SC.World.OnResidentDied(r, nil) end
            end
            local keep = true
            if phys.deadAt then
                keep = (timer - phys.deadAt) < 20000
            elseif r.status ~= 'alive' then
                keep = false
            elseif minD > despawnR and not r.convo then
                keep = false
            elseif r.state.inside and phys.taskKind == 'enter' and (timer - (phys.taskSetAt or timer)) > 90000 then
                keep = false
            elseif phys.taskKind == 'leave' and (timer - (phys.taskSetAt or timer)) > 45000 then
                keep = false
            elseif (phys.stuck or 0) >= 3 and minD > 60.0 then
                keep = false
            end
            if not keep then Spawner.Despawn(r, 'tick') end
        end
    end

    -- 2) spawn adayları
    local candidates = {}
    for _, r in ipairs(Sim.List) do
        if r.enabled and not Spawner.peds[r.id] and not spawning[r.id] and not r.convo then
            local info = Sim.GetSpawnInfo(r, now)
            if info then
                local d, src = nearestPlayer(players, info.pos)
                if d <= spawnR then candidates[#candidates + 1] = { r = r, info = info, dist = d, src = src } end
            end
        end
    end
    table.sort(candidates, function(a, b) return a.dist < b.dist end)
    for _, c in ipairs(candidates) do
        if Spawner.Count() >= (Config.MaxSpawnedResidents or 20) then
            local far, farD = farthestEvictable()
            if far and farD > c.dist + 25.0 then
                Spawner.Despawn(far, 'evict')
            else
                break
            end
        end
        Spawner.Spawn(c.r, c.info, c.src)
    end

    -- 3) araçlar
    Spawner.TickVehicles()

    if registryDirty then publishRegistry() end
end

-- ---------------------------------------------------------------------
-- İstemci görev olayları (sadece ped'in network sahibi gönderebilir)
-- ---------------------------------------------------------------------
local function sanitizeAppearance(data)
    if type(data) ~= 'table' then return nil end
    local out = { components = {}, props = {} }
    for i = 0, 11 do
        local c = data.components and (data.components[i] or data.components[tostring(i)])
        if type(c) == 'table' and tonumber(c[1]) and tonumber(c[2]) then
            out.components[tostring(i)] = { Utils.Clamp(math.floor(c[1]), 0, 255), Utils.Clamp(math.floor(c[2]), 0, 63) }
        end
    end
    for i = 0, 7 do
        local p = data.props and (data.props[i] or data.props[tostring(i)])
        if type(p) == 'table' and tonumber(p[1]) and tonumber(p[2]) then
            out.props[tostring(i)] = { Utils.Clamp(math.floor(p[1]), -1, 255), Utils.Clamp(math.floor(p[2]), 0, 63) }
        end
    end
    return out
end

RegisterNetEvent('samy-citizens:server:taskEvent', function(netId, seq, event, data)
    local src = source
    local r = Spawner.GetResidentByNet(netId)
    if not r then return end
    local phys = Spawner.peds[r.id]
    if not phys or not DoesEntityExist(phys.ped) then return end
    if NetworkGetEntityOwner(phys.ped) ~= src then return end

    if event == 'look' then
        if not r.appearance then
            local look = sanitizeAppearance(data)
            if look then
                r.appearance = look
                r.dirty = true
                Entity(phys.ped).state:set('scLook', look, true)
            end
        end
        return
    end
    if event == 'dead' then
        if not phys.deadAt then
            phys.deadAt = GetGameTimer()
            if SC.World then SC.World.OnResidentDied(r, nil) end
        end
        return
    end
    if seq ~= phys.seq then return end

    local now = Clock.Now()
    if r.override and SC.Life and SC.Life.OnTaskEvent(r, event) then return end
    if event == 'arrived' or event == 'parked' then
        if r.state.activity == 'commute' and r.state.mode ~= 'transit' and not r.convo and not r.override then
            phys.traveling = false
            if event == 'parked' then
                local rec = Spawner.vehicles[r.id]
                if rec and DoesEntityExist(rec.entity) then SetVehicleDoorsLocked(rec.entity, 2) end
            end
            Sim.Arrive(r, now)
        end
    elseif event == 'entered' or event == 'left' then
        Spawner.Despawn(r, event, true)
    elseif event == 'noveh' then
        if r.state.activity == 'commute' and r.state.mode == 'car' then
            if r.car then r.car.inUse = false end
            r.state.mode = 'transit'
            rebase(r, GetEntityCoords(phys.ped))
            Sim.Changed(r, 'noveh')
        end
    elseif event == 'stuck' then
        phys.stuck = (phys.stuck or 0) + 1
    end
end)

-- ---------------------------------------------------------------------
-- Temizlik
-- ---------------------------------------------------------------------
function Spawner.Shutdown()
    for _, phys in pairs(Spawner.peds) do
        if DoesEntityExist(phys.ped) then DeleteEntity(phys.ped) end
    end
    for _, rec in pairs(Spawner.vehicles) do
        if DoesEntityExist(rec.entity) and not vehicleHasPlayer(rec.entity) then DeleteEntity(rec.entity) end
    end
    Spawner.peds, Spawner.byNet, Spawner.vehicles = {}, {}, {}
    GlobalState.scPeds = {}
end

-- Oyuncunun belirli bir sakin ped'ine gerçekten yakın olduğunu sunucuda doğrular
function Spawner.PlayerNear(src, r, maxDist)
    local ped = Spawner.GetPed(r)
    if not ped then return false, math.huge end
    local pped = GetPlayerPed(src)
    if not pped or pped == 0 then return false, math.huge end
    local d = Utils.Dist(GetEntityCoords(pped), GetEntityCoords(ped))
    return d <= maxDist, d
end
