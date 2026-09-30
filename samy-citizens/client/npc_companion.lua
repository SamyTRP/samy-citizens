--[[
    BERABER GEZME — ped'in network SAHİBİ istemci tarafı
    Görev tanımı Entity(ped).state.scTask = { kind = 'companion', phase, target, slot, veh, seat, dest, pos, ... }
    client/tasks.lua'daki 1 sn'lik sahiplik döngüsünden çağrılır (her karede çalışan döngü yok).
    Sahiplik başka oyuncuya geçerse yeni sahip aynı fazı statebag'den okuyup devam ettirir.

    Takip: TaskFollowToOffsetOfEntity ile oyuncunun yan/arka tarafında (Config.Follow.Offsets) mesafe korunur;
    oyuncu hızlanınca NPC hızlanır, koşunca koşar, durunca yakında bekler ve bir süre sonra bekleme animasyonuna geçer.
    Araç: atanmış koltuğa yürüyüp kapıyı açarak biner (TaskEnterVehicle). Kilitliyse haber verir, başarısız olursa
    birkaç kez dener, sonra sunucudan başka koltuk ister. SON ÇARE ışınlama sadece kapının dibindeyken.
]]
local C = {}
SC.CompanionC = C

local F = Config.Follow
local V = Config.Vehicle

local function vehicle(net)
    if not net or not NetworkDoesEntityExistWithNetworkId(net) then return 0 end
    local v = NetworkGetEntityFromNetworkId(net)
    if v ~= 0 and DoesEntityExist(v) then return v end
    return 0
end

local function offsetFor(slot)
    local list = F.Offsets or { { 1.1, -0.9 } }
    local o = list[((slot or 1) - 1) % #list + 1]
    return o[1] + 0.0, o[2] + 0.0
end

local function speedFor(tspeed, d)
    if tspeed >= (F.RunPlayerSpeed or 4.8) or d > (F.CatchUpDistance or 14.0) then return 'run', F.RunSpeed or 3.0 end
    if tspeed >= (F.JogPlayerSpeed or 2.4) or d > (F.CatchUpDistance or 14.0) * 0.5 then return 'jog', F.JogSpeed or 2.0 end
    return 'walk', F.WalkSpeed or 1.0
end

local function report(netId, spec, event, data)
    SC.Tasks.Report(netId, spec.seq, event, data)
end

local function groundZ(x, y, z)
    local ok, gz = GetGroundZFor_3dCoord(x, y, z + 2.0, false)
    if ok and math.abs(gz - z) < 4.0 then return gz end
    return z
end

-- ---------------------------------------------------------------------
-- Takip
-- ---------------------------------------------------------------------
local function follow(ped, netId, spec, a, now, target)
    local pc = GetEntityCoords(ped)
    local tpos = GetEntityCoords(target)
    local d = #(tpos - pc)
    if IsPedInAnyVehicle(ped, false) then
        if a.mode ~= 'exitveh' then
            TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 0)
            a.mode = 'exitveh'
        end
        return
    end
    -- SON ÇARE: oyuncu çok uzakta ve NPC de, varış noktası da ekranda değilse yakına alınır
    if d > (F.WarpFailsafeDistance or 110.0) and not IsPedInAnyVehicle(target, false)
        and not IsSphereVisible(pc.x, pc.y, pc.z, 1.5) and now - (a.warpAt or 0) > 15000 then
        local back = GetOffsetFromEntityInWorldCoords(target, 0.0, -7.0, 0.0)
        if not IsSphereVisible(back.x, back.y, back.z, 1.2) then
            SetEntityCoords(ped, back.x, back.y, groundZ(back.x, back.y, back.z), false, false, false, false)
            a.warpAt = now
            a.mode = nil
            report(netId, spec, 'comp_warped')
            return
        end
    end
    local tspeed = GetEntitySpeed(target)
    if tspeed < 0.4 and d < 3.6 then
        if a.mode ~= 'idle' and a.mode ~= 'idlescen' then
            ClearPedTasks(ped)
            TaskTurnPedToFaceEntity(ped, target, 1500)
            TaskLookAtEntity(ped, target, 8000, 2048, 3)
            a.mode = 'idle'
            a.idleAt = now
        elseif a.mode == 'idle' and spec.idleScenario and now - (a.idleAt or now) > (F.IdleScenarioAfterSec or 20) * 1000 then
            TaskStartScenarioInPlace(ped, spec.idleScenario, 0, true)
            a.mode = 'idlescen'
        end
        return
    end
    local cls, spd = speedFor(tspeed, d)
    local stalled = now - (a.issuedAt or 0) > 8000 and d > 6.0 and GetEntitySpeed(ped) < 0.5
    if a.mode ~= cls or stalled then
        if a.mode == 'idlescen' or a.mode == 'idle' then ClearPedTasks(ped) end
        local ox, oy = offsetFor(spec.slot)
        TaskFollowToOffsetOfEntity(ped, target, ox, oy, 0.0, spd + 0.0, -1, (F.StoppingRange or 1.4) + 0.0, true)
        a.mode = cls
        a.issuedAt = now
    end
end

-- ---------------------------------------------------------------------
-- Bir noktada bekleme / buluşma
-- ---------------------------------------------------------------------
local function stay(ped, netId, spec, a, now, target)
    if IsPedInAnyVehicle(ped, false) then
        if a.mode ~= 'exitveh' then
            TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 0)
            a.mode = 'exitveh'
        end
        return
    end
    local p = spec.pos
    local pc = GetEntityCoords(ped)
    if p and p.x then
        local dest = vector3(p.x + 0.0, p.y + 0.0, p.z + 0.0)
        local d = #(vector2(pc.x, pc.y) - vector2(dest.x, dest.y))
        if d > 1.6 and a.mode ~= 'going' and a.mode ~= 'doing' then
            ClearPedTasks(ped)
            TaskFollowNavMeshToCoord(ped, dest.x, dest.y, dest.z, 1.0, -1, 1.0, 0, (p.h or 0.0) + 0.0)
            a.mode = 'going'
            a.goAt = now
            return
        end
        if a.mode == 'going' and (d <= 1.6 or now - (a.goAt or now) > 20000) then
            if spec.scenario then
                TaskStartScenarioAtPosition(ped, spec.scenario, dest.x, dest.y, groundZ(dest.x, dest.y, dest.z) + 1.0, (p.h or 0.0) + 0.0, 0, spec.scenario:find('SEAT', 1, true) ~= nil, false)
            else
                TaskStandStill(ped, -1)
            end
            a.mode = 'doing'
            return
        end
        if a.mode == nil then
            a.mode = 'going'
            a.goAt = now - 20001
        end
        return
    end
    if a.mode ~= 'doing' then
        ClearPedTasks(ped)
        if spec.scenario then TaskStartScenarioInPlace(ped, spec.scenario, 0, true) else TaskStandStill(ped, -1) end
        a.mode = 'doing'
    end
    if target ~= 0 and now - (a.lookAt or 0) > 6000 and #(GetEntityCoords(target) - pc) < 8.0 then
        a.lookAt = now
        TaskLookAtEntity(ped, target, 5000, 2048, 3)
    end
end

-- ---------------------------------------------------------------------
-- Oyuncunun aracına binme / inme
-- ---------------------------------------------------------------------
local function enter(ped, netId, spec, a, now)
    local v = vehicle(spec.veh)
    if v == 0 then return end
    local seat = spec.seat or 0
    if IsPedInVehicle(ped, v, false) then
        if not a.reportedIn then
            a.reportedIn = true
            report(netId, spec, 'comp_entered')
        end
        return
    end
    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 0)
        return
    end
    local lock = GetVehicleDoorLockStatus(v)
    if lock == 2 or lock == 3 or lock == 4 or lock == 10 then
        if now - (a.lockAt or 0) > 10000 then
            a.lockAt = now
            report(netId, spec, 'comp_locked')
            TaskGoToEntity(ped, v, -1, 2.5, 1.0, 1073741824, 0)
        end
        a.entering = false
        return
    end
    if a.entering and now - (a.enterAt or now) <= (V.EnterTimeoutMs or 16000) then return end
    a.tries = (a.tries or 0) + 1
    local dist = #(GetEntityCoords(ped) - GetEntityCoords(v))
    if a.tries > (V.EnterRetries or 3) then
        if V.WarpFailsafe ~= false and dist < 4.5 and IsVehicleSeatFree(v, seat) then
            TaskWarpPedIntoVehicle(ped, v, seat)
            a.reportedIn = true
            report(netId, spec, 'comp_entered')
        else
            a.tries = 0
            report(netId, spec, 'comp_seatfail')
        end
        return
    end
    if not IsVehicleSeatFree(v, seat) then
        report(netId, spec, 'comp_seatfail')
        a.tries = 0
        return
    end
    ClearPedTasks(ped)
    TaskEnterVehicle(ped, v, V.EnterTimeoutMs or 16000, seat, dist > 8.0 and 2.0 or 1.0, 1, 0)
    a.entering = true
    a.enterAt = now
end

local function ride(ped, netId, spec, a, now)
    local v = vehicle(spec.veh)
    if v == 0 then return end
    if IsPedInVehicle(ped, v, false) then return end
    -- araçtan düştü / indirildi: yakınsa tekrar biner (birkaç kez)
    if #(GetEntityCoords(ped) - GetEntityCoords(v)) < 10.0 and (a.reboard or 0) < 3 and now - (a.reboardAt or 0) > 6000 then
        a.reboard = (a.reboard or 0) + 1
        a.reboardAt = now
        TaskEnterVehicle(ped, v, 10000, spec.seat or 0, 2.0, 1, 0)
    end
end

local function leave(ped, netId, spec, a, now)
    local cur = GetVehiclePedIsIn(ped, false)
    if cur == 0 then
        if not a.reportedOut then
            a.reportedOut = true
            report(netId, spec, 'comp_exited')
        end
        return
    end
    if not a.leaveAt then
        TaskLeaveVehicle(ped, cur, 0)
        a.leaveAt = now
    elseif now - a.leaveAt > (V.ExitTimeoutMs or 9000) and not a.forced then
        -- SON ÇARE: kapı açılamıyor (duvara yanaşık vb.) -> koltuktan dışarı
        a.forced = true
        TaskLeaveVehicle(ped, cur, 16)
    end
end

-- ---------------------------------------------------------------------
-- NPC şoför (kendi arabası)
-- ---------------------------------------------------------------------
local function toCar(ped, netId, spec, a, now)
    local v = vehicle(spec.veh)
    if v == 0 then return end
    if IsPedInVehicle(ped, v, false) and GetPedInVehicleSeat(v, -1) == ped then
        if not a.reportedReady then
            a.reportedReady = true
            report(netId, spec, 'comp_driver_ready')
        end
        return
    end
    if a.entering and now - (a.enterAt or now) <= 18000 then return end
    a.tries = (a.tries or 0) + 1
    local dist = #(GetEntityCoords(ped) - GetEntityCoords(v))
    if a.tries > 3 then
        if V.WarpFailsafe ~= false and dist < 4.5 and IsVehicleSeatFree(v, -1) then
            TaskWarpPedIntoVehicle(ped, v, -1)
        else
            report(netId, spec, 'comp_stuck')
        end
        return
    end
    ClearPedTasks(ped)
    TaskEnterVehicle(ped, v, 18000, -1, dist > 10.0 and 2.0 or 1.0, 1, 0)
    a.entering = true
    a.enterAt = now
end

local function drive(ped, netId, spec, a, now)
    local v = vehicle(spec.veh)
    if v == 0 or not IsPedInVehicle(ped, v, false) then return end
    local d = spec.dest
    if not d then return end
    local target = vector3(d.x + 0.0, d.y + 0.0, d.z + 0.0)
    local vc = GetEntityCoords(v)
    if not a.driving then
        SetDriverAbility(ped, 1.0)
        SetDriverAggressiveness(ped, 0.0)
        SetVehicleEngineOn(v, true, true, false)
        TaskVehicleDriveToCoordLongrange(ped, v, target.x, target.y, target.z, (spec.speed or 15.0) + 0.0, spec.style or 786603, 20.0)
        a.driving = true
        a.lastPos = vc
        a.lastMoveAt = now
        return
    end
    if #(vc - a.lastPos) > 2.0 then
        a.lastPos = vc
        a.lastMoveAt = now
    end
    local dist = #(vector2(vc.x, vc.y) - vector2(target.x, target.y))
    if dist < (spec.park or 24.0) then
        if not a.parking then
            a.parking = now
            TaskVehicleTempAction(ped, v, 1, 4000)
        elseif GetEntitySpeed(v) < 0.6 or now - a.parking > 5000 then
            if not a.reportedPark then
                a.reportedPark = true
                report(netId, spec, 'comp_parked')
            end
        end
        return
    end
    if GetEntitySpeed(v) < 1.0 and now - (a.lastMoveAt or now) > 25000 then
        a.retries = (a.retries or 0) + 1
        a.lastMoveAt = now
        if a.retries >= 3 then
            report(netId, spec, 'comp_stuck')
        else
            TaskVehicleDriveToCoordLongrange(ped, v, target.x, target.y, target.z, (spec.speed or 15.0) + 0.0, spec.style or 786603, 20.0)
        end
    end
end

local function hold(ped, netId, spec, a, now)
    local v = vehicle(spec.veh)
    if v == 0 or not IsPedInVehicle(ped, v, false) then return end
    if not a.holding or now - a.holding > 20000 then
        a.holding = now
        TaskVehicleTempAction(ped, v, 6, 30000)
    end
end

local function waitPassenger(ped, netId, spec, a, now)
    local v = vehicle(spec.veh)
    if v == 0 then return end
    if not IsPedInVehicle(ped, v, false) then return end
    if not a.engine then
        a.engine = true
        SetVehicleEngineOn(v, true, true, false)
    end
end

-- ---------------------------------------------------------------------
-- Görev döngüsü girişleri
-- ---------------------------------------------------------------------
function C.Apply(ped, netId, spec, a)
    a.mode = nil
    TaskClearLookAt(ped)
    if IsEntityAttachedToAnyPed(ped) then DetachEntity(ped, true, false) end
    C.Monitor(ped, netId, spec, a, GetGameTimer())
end

function C.Monitor(ped, netId, spec, a, now)
    local target = SC.Tasks.PedFromServerId(spec.target)
    local ph = spec.phase
    if ph == 'follow' then
        if target ~= 0 then follow(ped, netId, spec, a, now, target) end
    elseif ph == 'wait_car' then
        if target ~= 0 then
            -- aracın yanında bekler
            local v = vehicle(spec.veh)
            if v ~= 0 and #(GetEntityCoords(ped) - GetEntityCoords(v)) > 5.0 and a.mode ~= 'tocar' then
                TaskGoToEntity(ped, v, -1, 3.5, 1.5, 1073741824, 0)
                a.mode = 'tocar'
            elseif v == 0 then
                follow(ped, netId, spec, a, now, target)
            end
        end
    elseif ph == 'enter' then
        enter(ped, netId, spec, a, now)
    elseif ph == 'ride' then
        ride(ped, netId, spec, a, now)
    elseif ph == 'exit' or ph == 'arrive' then
        leave(ped, netId, spec, a, now)
    elseif ph == 'wait' or ph == 'date' then
        stay(ped, netId, spec, a, now, target)
    elseif ph == 'to_car' then
        toCar(ped, netId, spec, a, now)
    elseif ph == 'wait_passenger' then
        waitPassenger(ped, netId, spec, a, now)
    elseif ph == 'driving' then
        drive(ped, netId, spec, a, now)
    elseif ph == 'hold' then
        hold(ped, netId, spec, a, now)
    end
end

-- Sunucunun koltuk sorgusu: oyuncunun (sürücünün) istemcisi aracın yolcu koltuğu sayısını söyler
lib.callback.register('samy-citizens:vehicleSeats', function(netId)
    if type(netId) ~= 'number' or not NetworkDoesEntityExistWithNetworkId(netId) then return nil end
    local v = NetworkGetEntityFromNetworkId(netId)
    if v == 0 or not DoesEntityExist(v) or not IsEntityAVehicle(v) then return nil end
    return GetVehicleMaxNumberOfPassengers(v)
end)
