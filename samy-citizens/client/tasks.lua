--[[
    AKTİVİTE -> GTA GÖREV EŞLEMESİ
    Bu istemci bir sakin ped'inin network sahibiyse, Entity(ped).state.scTask'taki görevi uygular ve
    ilerlemeyi (varış, park, binaya giriş) sunucuya bildirir. Sahiplik değişince yeni sahip aynı
    görevi statebag'den okuyup devam ettirir. Döngü 1 sn aralıklıdır (her karede çalışmaz).
]]
local Utils = SC.Utils
local Tasks = {}
SC.Tasks = Tasks

local applied = {}
local setupDone = {}
local myId = PlayerId()

local function report(netId, seq, event, data)
    TriggerServerEvent('samy-citizens:server:taskEvent', netId, seq, event, data)
end

local function pedFromServerId(sid)
    if not sid then return 0 end
    local player = GetPlayerFromServerId(sid)
    if not player or player == -1 then return 0 end
    return GetPlayerPed(player)
end

local function loadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(dict)
end

local function dist2d(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function groundZ(x, y, z)
    local found, gz = GetGroundZFor_3dCoord(x, y, z + 1.5, false)
    if found and math.abs(gz - z) < 3.0 then return gz + 1.0 end
    return z
end

-- ---------------------------------------------------------------------
-- Ped kurulumu & görünüm
-- ---------------------------------------------------------------------
local function setupPed(ped)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedKeepTask(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCanEvasiveDive(ped, false)
    SetPedDiesWhenInjured(ped, false)
    SetPedCanPlayAmbientAnims(ped, true)
    SetPedCanRagdollFromPlayerImpact(ped, true)
end

local function applyLook(ped, netId)
    local look = Entity(ped).state.scLook
    if type(look) == 'table' then
        for comp, v in pairs(look.components or {}) do
            local c = tonumber(comp)
            if c and type(v) == 'table' then
                local d, t = tonumber(v[1]) or 0, tonumber(v[2]) or 0
                if d < GetNumberOfPedDrawableVariations(ped, c) then SetPedComponentVariation(ped, c, d, t, 0) end
            end
        end
        for prop, v in pairs(look.props or {}) do
            local p = tonumber(prop)
            if p and type(v) == 'table' then
                local d, t = tonumber(v[1]) or -1, tonumber(v[2]) or 0
                if d < 0 then ClearPedProp(ped, p) else SetPedPropIndex(ped, p, d, t, true) end
            end
        end
        return
    end
    -- İlk kez: geçerli rastgele varyasyon seç ve kalıcı olması için sunucuya bildir
    SetPedRandomComponentVariation(ped, 0)
    SetPedRandomProps(ped)
    local out = { components = {}, props = {} }
    for c = 0, 11 do
        out.components[tostring(c)] = { GetPedDrawableVariation(ped, c), GetPedTextureVariation(ped, c) }
    end
    for p = 0, 7 do
        out.props[tostring(p)] = { GetPedPropIndex(ped, p), math.max(0, GetPedPropTextureIndex(ped, p)) }
    end
    report(netId, 0, 'look', out)
end

-- ---------------------------------------------------------------------
-- Görev uygulayıcıları
-- ---------------------------------------------------------------------
local function startScenario(ped, spec)
    local scen = spec.scenario or 'WORLD_HUMAN_STAND_IMPATIENT'
    local seated = scen:find('SEAT', 1, true) ~= nil or scen:find('BENCH', 1, true) ~= nil
    local z = groundZ(spec.x, spec.y, spec.z)
    ClearPedTasks(ped)
    TaskStartScenarioAtPosition(ped, scen, spec.x + 0.0, spec.y + 0.0, z, (spec.h or 0.0) + 0.0, 0, seated, false)
end

local function navTo(ped, x, y, z, speed, heading)
    TaskFollowNavMeshToCoord(ped, x + 0.0, y + 0.0, z + 0.0, speed or 1.0, -1, 1.0, 0, (heading or 0.0) + 0.0)
end

local function startDrive(ped, veh, spec)
    if not NetworkHasControlOfEntity(veh) then NetworkRequestControlOfEntity(veh) end
    SetDriverAbility(ped, 1.0)
    SetDriverAggressiveness(ped, 0.0)
    SetVehicleEngineOn(veh, true, true, false)
    TaskVehicleDriveToCoordLongrange(ped, veh, spec.x + 0.0, spec.y + 0.0, spec.z + 0.0, (spec.speed or 14.0) + 0.0, spec.style or 786603, 15.0)
end

-- ---------------------------------------------------------------------
-- Rehine (bağlama / eller yukarı / diz çökme / araca binme)
-- ---------------------------------------------------------------------
local HOSTAGE_ANIM = {
    hold = { 'anim@gangops@hostage@', 'victim_idle', 49 },
    escort = { 'random@mugging3', 'handsup_standing_base', 49 },
    kneel = { 'random@arrests@busted', 'idle_a', 1 },
}

local function hostageAnim(ped, mode)
    local an = HOSTAGE_ANIM[mode]
    if not an or IsEntityPlayingAnim(ped, an[1], an[2], 3) then return end
    if loadDict(an[1]) then
        TaskPlayAnim(ped, an[1], an[2], 8.0, -8.0, -1, an[3], 0.0, false, false, false)
    end
end

local function attachHostage(ped, target)
    AttachEntityToEntity(ped, target, 0, -0.24, 0.11, 0.0, 0.5, 0.5, 0.0, false, false, false, false, 2, false)
end

local function hostageVehicle(spec)
    if not spec.veh or not NetworkDoesEntityExistWithNetworkId(spec.veh) then return 0 end
    return NetworkGetEntityFromNetworkId(spec.veh)
end

function Tasks.ApplyHostage(ped, netId, spec, a)
    local target = pedFromServerId(spec.target)
    local mode = spec.mode
    if mode ~= 'hold' and IsEntityAttachedToAnyPed(ped) then DetachEntity(ped, true, false) end
    if mode ~= 'vehicle' and IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 0)
        a.phase = 'exitveh'
        return
    end
    ClearPedSecondaryTask(ped)
    if mode == 'hold' then
        ClearPedTasksImmediately(ped)
        if target ~= 0 then attachHostage(ped, target) end
        hostageAnim(ped, 'hold')
        a.phase = 'held'
    elseif mode == 'escort' then
        ClearPedTasks(ped)
        if target ~= 0 then TaskFollowToOffsetOfEntity(ped, target, 0.0, 1.3, 0.0, 1.0, -1, 0.8, true) end
        hostageAnim(ped, 'escort')
        a.phase = 'escort'
        a.followAt = GetGameTimer()
    elseif mode == 'kneel' then
        ClearPedTasks(ped)
        hostageAnim(ped, 'kneel')
        a.phase = 'kneel'
    elseif mode == 'vehicle' then
        local veh = hostageVehicle(spec)
        ClearPedTasks(ped)
        if veh ~= 0 then
            TaskEnterVehicle(ped, veh, 10000, spec.seat or 1, 1.0, 1, 0)
            a.phase = 'boarding'
            a.boardAt = GetGameTimer()
        else
            TaskCower(ped, -1)
            a.phase = 'cower'
        end
    end
end

function Tasks.MonitorHostage(ped, spec, a, now)
    local target = pedFromServerId(spec.target)
    if a.phase == 'held' then
        if target ~= 0 and not IsEntityAttachedToEntity(ped, target) then attachHostage(ped, target) end
        hostageAnim(ped, 'hold')
    elseif a.phase == 'escort' then
        if target ~= 0 then
            local d = #(GetEntityCoords(ped) - GetEntityCoords(target))
            if d > 3.5 and now - (a.followAt or 0) > 5000 then
                TaskFollowToOffsetOfEntity(ped, target, 0.0, 1.3, 0.0, 1.0, -1, 0.8, true)
                a.followAt = now
            end
        end
        hostageAnim(ped, 'escort')
    elseif a.phase == 'kneel' then
        hostageAnim(ped, 'kneel')
    elseif a.phase == 'boarding' then
        local veh = hostageVehicle(spec)
        if veh == 0 then return end
        if IsPedInVehicle(ped, veh, false) then
            a.phase = 'seated'
        elseif now - (a.boardAt or now) > 10000 then
            TaskWarpPedIntoVehicle(ped, veh, spec.seat or 1)
            a.phase = 'seated'
        end
    elseif a.phase == 'seated' then
        local veh = hostageVehicle(spec)
        if veh ~= 0 and not IsPedInVehicle(ped, veh, false) and #(GetEntityCoords(ped) - GetEntityCoords(veh)) < 8.0 then
            TaskEnterVehicle(ped, veh, 10000, spec.seat or 1, 1.0, 1, 0)
            a.phase = 'boarding'
            a.boardAt = now
        end
    end
end

function Tasks.Apply(ped, netId, spec, a)
    local kind = spec.kind
    local pc = GetEntityCoords(ped)
    if kind ~= 'converse' and kind ~= 'meet' and kind ~= 'chat' then
        TaskClearLookAt(ped)
    end
    if kind == 'hostage' then return Tasks.ApplyHostage(ped, netId, spec, a) end
    -- rehinelikten çıktı: bağı çöz, eller-yukarı animasyonunu bırak
    if IsEntityAttachedToAnyPed(ped) then DetachEntity(ped, true, false) end
    ClearPedSecondaryTask(ped)
    if kind == 'scenario' or (kind == 'idle' and spec.x) then
        local target = vector3(spec.x, spec.y, spec.z)
        if IsPedInAnyVehicle(ped, false) then
            TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 0)
            a.phase = 'exitveh'
        elseif dist2d(pc, target) > 2.0 then
            ClearPedTasks(ped)
            navTo(ped, spec.x, spec.y, spec.z, 1.0, spec.h)
            a.phase = 'moving'
        else
            startScenario(ped, spec)
            a.phase = 'doing'
        end
    elseif kind == 'idle' then
        ClearPedTasks(ped)
        TaskStandStill(ped, -1)
        a.phase = 'doing'
    elseif kind == 'walk' or kind == 'enter' or kind == 'leave' then
        if IsPedInAnyVehicle(ped, false) then
            TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 0)
            a.phase = 'exitveh'
        else
            ClearPedTasks(ped)
            navTo(ped, spec.x, spec.y, spec.z, 1.0, spec.h)
            a.phase = 'moving'
        end
    elseif kind == 'drive' then
        a.phase = 'waitveh'
        Tasks.Monitor(ped, netId, spec, a, GetGameTimer())
    elseif kind == 'converse' then
        local target = pedFromServerId(spec.target)
        ClearPedTasks(ped)
        if target ~= 0 then
            TaskLookAtEntity(ped, target, -1, 2048, 3)
            TaskTurnPedToFaceEntity(ped, target, -1)
        else
            TaskStandStill(ped, -1)
        end
        a.phase = 'talking'
    elseif kind == 'meet' then
        local target = pedFromServerId(spec.target)
        if target ~= 0 then
            ClearPedTasks(ped)
            TaskGoToEntity(ped, target, -1, 1.8, 1.0, 1073741824, 0)
            a.phase = 'approach'
        end
    elseif kind == 'follow' then
        a.phase = 'follow'
        a.followMode = nil
        Tasks.Monitor(ped, netId, spec, a, GetGameTimer())
    elseif kind == 'flee' then
        local fveh = GetVehiclePedIsIn(ped, false)
        if fveh ~= 0 and GetPedInVehicleSeat(fveh, -1) ~= ped then
            -- yolcu koltuğundan (ör. rehine) önce iner, sonra kaçar
            TaskLeaveVehicle(ped, fveh, 256)
            a.phase = 'exitveh'
            return
        end
        ClearPedTasks(ped)
        local target = pedFromServerId(spec.target)
        if target ~= 0 then
            TaskSmartFleePed(ped, target, 150.0, -1, false, false)
        else
            TaskSmartFleeCoord(ped, (spec.x or pc.x) + 0.0, (spec.y or pc.y) + 0.0, (spec.z or pc.z) + 0.0, 150.0, -1, false, false)
        end
        a.phase = 'fleeing'
    elseif kind == 'handsup' then
        local target = pedFromServerId(spec.target)
        ClearPedTasks(ped)
        TaskHandsUp(ped, 4000, target ~= 0 and target or 0, -1, false)
        a.phase = 'handsup'
    elseif kind == 'cower' then
        ClearPedTasks(ped)
        TaskCower(ped, -1)
        a.phase = 'cower'
    elseif kind == 'chat' then
        local partner = spec.partner and NetworkDoesEntityExistWithNetworkId(spec.partner) and NetworkGetEntityFromNetworkId(spec.partner) or 0
        ClearPedTasks(ped)
        if partner ~= 0 then
            TaskLookAtEntity(ped, partner, -1, 2048, 3)
            TaskTurnPedToFaceEntity(ped, partner, 1500)
        end
        a.phase = 'turning'
    end
end

function Tasks.Monitor(ped, netId, spec, a, now)
    local kind = spec.kind
    local pc = GetEntityCoords(ped)

    -- genel takılma takibi (hareket gerektiren aşamalarda)
    if a.phase == 'moving' or a.phase == 'driving' or a.phase == 'entering' or a.phase == 'approach' then
        if #(pc - a.lastPos) > 1.0 then
            a.lastPos = pc
            a.lastMoveAt = now
        end
    end

    if a.phase == 'exitveh' then
        if not IsPedInAnyVehicle(ped, false) then
            a.lastPos, a.lastMoveAt = pc, now
            Tasks.Apply(ped, netId, spec, a)
        end
        return
    end

    if kind == 'hostage' then
        Tasks.MonitorHostage(ped, spec, a, now)
    elseif kind == 'scenario' or (kind == 'idle' and spec.x) then
        local target = vector3(spec.x, spec.y, spec.z)
        if a.phase == 'moving' then
            if dist2d(pc, target) < 1.6 or now - a.lastMoveAt > 20000 then
                startScenario(ped, spec)
                a.phase = 'doing'
                a.checkAt = now + 4000
            end
        elseif a.phase == 'doing' and now >= (a.checkAt or 0) then
            a.checkAt = now + 5000
            -- birisi itip senaryodan çıkardıysa geri dön
            if not IsPedActiveInScenario(ped) and not IsPedRagdoll(ped) then
                if dist2d(pc, target) > 2.0 then
                    navTo(ped, spec.x, spec.y, spec.z, 1.0, spec.h)
                    a.phase = 'moving'
                    a.lastMoveAt = now
                elseif (a.retries or 0) < 3 then
                    a.retries = (a.retries or 0) + 1
                    startScenario(ped, spec)
                end
            end
        end
    elseif kind == 'walk' or kind == 'enter' or kind == 'leave' then
        local target = vector3(spec.x, spec.y, spec.z)
        local d = dist2d(pc, target)
        if a.phase == 'moving' then
            local arriveDist = kind == 'leave' and 4.0 or (kind == 'enter' and 1.8 or 2.5)
            if d < arriveDist then
                if kind == 'walk' then
                    report(netId, spec.seq, 'arrived')
                    a.phase = 'done'
                elseif kind == 'leave' then
                    report(netId, spec.seq, 'left')
                    a.phase = 'done'
                else
                    a.phase = 'door'
                    a.doorAt = now
                    TaskTurnPedToFaceCoord(ped, spec.x + 0.0, spec.y + 0.0, spec.z + 0.0, 800)
                    CreateThread(function()
                        if loadDict('anim@heists@keycard@') then
                            Wait(700)
                            TaskPlayAnim(ped, 'anim@heists@keycard@', 'exit', 5.0, 1.0, 1200, 16, 0.0, false, false, false)
                            RemoveAnimDict('anim@heists@keycard@')
                        end
                    end)
                end
            elseif now - a.lastMoveAt > 15000 then
                a.retries = (a.retries or 0) + 1
                a.lastMoveAt = now
                if kind == 'leave' or (kind == 'enter' and a.retries >= 2) then
                    report(netId, spec.seq, kind == 'leave' and 'left' or 'entered')
                    a.phase = 'done'
                elseif a.retries >= 4 then
                    report(netId, spec.seq, 'stuck')
                    a.phase = 'stuck'
                elseif a.retries >= 2 then
                    TaskGoStraightToCoord(ped, spec.x + 0.0, spec.y + 0.0, spec.z + 0.0, 1.0, -1, (spec.h or 0.0) + 0.0, 0.5)
                else
                    navTo(ped, spec.x, spec.y, spec.z, 1.0, spec.h)
                end
            end
            if kind == 'leave' and now - a.startedAt > 40000 and a.phase == 'moving' then
                report(netId, spec.seq, 'left')
                a.phase = 'done'
            end
        elseif a.phase == 'door' and now - (a.doorAt or now) > 1800 then
            report(netId, spec.seq, 'entered')
            a.phase = 'done'
        end
    elseif kind == 'drive' then
        local veh = (spec.veh and NetworkDoesEntityExistWithNetworkId(spec.veh)) and NetworkGetEntityFromNetworkId(spec.veh) or 0
        if veh == 0 or not DoesEntityExist(veh) then
            if a.phase ~= 'waitveh' then a.phase = 'waitveh' a.waitSince = now end
            a.waitSince = a.waitSince or now
            if now - a.waitSince > 10000 then
                report(netId, spec.seq, 'noveh')
                a.phase = 'done'
            end
            return
        end
        local target = vector3(spec.x, spec.y, spec.z)
        if a.phase == 'waitveh' then
            if IsPedInVehicle(ped, veh, false) then
                startDrive(ped, veh, spec)
                a.phase = 'driving'
                a.lastMoveAt = now
            elseif #(pc - GetEntityCoords(veh)) > 60.0 then
                report(netId, spec.seq, 'noveh')
                a.phase = 'done'
            else
                ClearPedTasks(ped)
                TaskEnterVehicle(ped, veh, 20000, -1, 1.0, 1, 0)
                a.phase = 'entering'
                a.enterAt = now
                a.lastMoveAt = now
            end
        elseif a.phase == 'entering' then
            if IsPedInVehicle(ped, veh, false) then
                startDrive(ped, veh, spec)
                a.phase = 'driving'
                a.lastMoveAt = now
            elseif now - (a.enterAt or now) > 25000 then
                TaskWarpPedIntoVehicle(ped, veh, -1)
                a.enterAt = now
            end
        elseif a.phase == 'driving' then
            if not IsPedInVehicle(ped, veh, false) then
                -- araçtan indirildi (araç çalınmış olabilir)
                report(netId, spec.seq, 'noveh')
                a.phase = 'done'
                return
            end
            local vc = GetEntityCoords(veh)
            if #(vc - target) < 25.0 then
                TaskVehicleTempAction(ped, veh, 1, 3000)
                a.phase = 'parking'
                a.parkAt = now
            elseif GetEntitySpeed(veh) < 1.0 and now - a.lastMoveAt > 25000 then
                a.retries = (a.retries or 0) + 1
                a.lastMoveAt = now
                if a.retries >= 3 then
                    report(netId, spec.seq, 'stuck')
                end
                startDrive(ped, veh, spec)
            end
        elseif a.phase == 'parking' then
            if GetEntitySpeed(veh) < 0.6 or now - a.parkAt > 4000 then
                TaskLeaveVehicle(ped, veh, 0)
                a.phase = 'leaving'
                a.leaveAt = now
            end
        elseif a.phase == 'leaving' then
            if not IsPedInAnyVehicle(ped, false) or now - a.leaveAt > 8000 then
                report(netId, spec.seq, 'parked')
                a.phase = 'done'
            end
        end
    elseif kind == 'converse' then
        if now >= (a.checkAt or 0) then
            a.checkAt = now + 4000
            local target = pedFromServerId(spec.target)
            if target ~= 0 and not IsPedFacingPed(ped, target, 40.0) then
                TaskTurnPedToFaceEntity(ped, target, -1)
            end
        end
    elseif kind == 'meet' then
        local target = pedFromServerId(spec.target)
        if target == 0 then return end
        local d = #(pc - GetEntityCoords(target))
        if a.phase == 'approach' and d < 2.6 then
            ClearPedTasks(ped)
            TaskLookAtEntity(ped, target, -1, 2048, 3)
            TaskTurnPedToFaceEntity(ped, target, -1)
            a.phase = 'with'
        elseif a.phase == 'with' and d > 6.0 then
            TaskGoToEntity(ped, target, -1, 1.8, 1.0, 1073741824, 0)
            a.phase = 'approach'
        end
    elseif kind == 'follow' then
        local target = pedFromServerId(spec.target)
        if target == 0 then return end
        local tveh = GetVehiclePedIsIn(target, false)
        local myVeh = GetVehiclePedIsIn(ped, false)
        if tveh ~= 0 then
            if myVeh ~= tveh and a.followMode ~= 'enter' then
                for seat = 0, 2 do
                    if IsVehicleSeatFree(tveh, seat) then
                        ClearPedTasks(ped)
                        TaskEnterVehicle(ped, tveh, 15000, seat, 2.0, 1, 0)
                        a.followMode = 'enter'
                        break
                    end
                end
            elseif myVeh == tveh then
                a.followMode = 'riding'
            end
        else
            if myVeh ~= 0 then
                if a.followMode ~= 'exit' then
                    TaskLeaveVehicle(ped, myVeh, 0)
                    a.followMode = 'exit'
                end
            elseif a.followMode ~= 'walk' then
                ClearPedTasks(ped)
                TaskFollowToOffsetOfEntity(ped, target, 0.8, -1.2, 0.0, 2.0, -1, 1.5, true)
                a.followMode = 'walk'
            end
        end
    elseif kind == 'chat' then
        if a.phase == 'turning' and now - a.startedAt > 1500 then
            TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_HANG_OUT_STREET', 0, true)
            a.phase = 'chatting'
        end
    end
end

-- Konuşma sırasındaki hareket (üst gövde, görevi bozmaz)
function Tasks.PlayGesture(ped, name)
    local g = SC.Gestures[name]
    if not g then return end
    CreateThread(function()
        if not loadDict(g.dict) then return end
        TaskPlayAnim(ped, g.dict, g.anim, 4.0, -4.0, g.dur or 2000, 48, 0.0, false, false, false)
        RemoveAnimDict(g.dict)
    end)
end

function Tasks.Process(ped, netId, now)
    if not setupDone[netId] then
        setupPed(ped)
        applyLook(ped, netId)
        setupDone[netId] = true
    end
    local a = applied[netId]
    if IsPedDeadOrDying(ped, true) then
        if not (a and a.deadReported) then
            a = a or { seq = -1 }
            a.deadReported = true
            applied[netId] = a
            report(netId, 0, 'dead')
        end
        return
    end
    local es = Entity(ped).state
    local spec = es.scTask
    if type(spec) ~= 'table' then return end
    if not a or a.seq ~= spec.seq then
        local pc = GetEntityCoords(ped)
        a = { seq = spec.seq, kind = spec.kind, phase = 'start', startedAt = now, lastPos = pc, lastMoveAt = now, retries = 0, animSeq = a and a.animSeq or 0 }
        applied[netId] = a
        Tasks.Apply(ped, netId, spec, a)
    else
        Tasks.Monitor(ped, netId, spec, a, now)
    end
    local anim = es.scAnim
    if type(anim) == 'table' and anim.seq ~= a.animSeq then
        a.animSeq = anim.seq
        Tasks.PlayGesture(ped, anim.name)
    end
end

-- Sahiplik döngüsü (1 sn)
CreateThread(function()
    while true do
        local reg = GlobalState.scPeds
        local now = GetGameTimer()
        local seen = {}
        if type(reg) == 'table' then
            for netStr in pairs(reg) do
                local netId = tonumber(netStr)
                if netId then
                    seen[netId] = true
                    if NetworkDoesEntityExistWithNetworkId(netId) then
                        local ped = NetworkGetEntityFromNetworkId(netId)
                        if ped ~= 0 and DoesEntityExist(ped) and NetworkGetEntityOwner(ped) == myId then
                            local ok, err = pcall(Tasks.Process, ped, netId, now)
                            if not ok then print(('[samy-citizens] görev hatası: %s'):format(tostring(err))) end
                        else
                            applied[netId] = nil
                            setupDone[netId] = nil
                        end
                    else
                        applied[netId] = nil
                        setupDone[netId] = nil
                    end
                end
            end
        end
        for netId in pairs(applied) do
            if not seen[netId] then
                applied[netId] = nil
                setupDone[netId] = nil
            end
        end
        Wait(1000)
    end
end)
