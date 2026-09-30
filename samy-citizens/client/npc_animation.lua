--[[
    ETKİLEŞİM ANİMASYONLARI — istemci
    NPC tarafı : ped'in network SAHİBİ istemci (client/tasks.lua döngüsünden, 1 sn) NPC'yi oyuncuya göre hizalar
                 (Config offset: ileri / yan / açı -> karakterler iç içe girmez), 'int_ready' bildirir, sonra oynatır.
    Oyuncu tarafı: etkileşimi başlatan oyuncunun istemcisi kendi animasyonunu oynatır. Sadece etkileşim sürerken
                 hareket/ateş tuşlarını kilitleyen kısa ömürlü bir kare döngüsü çalışır ([X] ile bitirilir).
    Animasyon registry'si: Config.Animation.Social ve Config.AdultAnimations (paylaşılan config).
]]
local AnimC = { active = nil }
SC.AnimC = AnimC

local AN = Config.Animation or {}

local BENCH_MODELS = {
    'prop_bench_01a', 'prop_bench_01b', 'prop_bench_01c', 'prop_bench_02', 'prop_bench_03', 'prop_bench_04', 'prop_bench_05',
    'prop_bench_06', 'prop_bench_07', 'prop_bench_08', 'prop_bench_09', 'prop_bench_10', 'prop_bench_11', 'prop_fib_3b_bench',
    'prop_ld_bench01', 'prop_wait_bench_01', 'prop_busstop_02', 'prop_busstop_04', 'prop_busstop_05',
}
local BENCH_HASHES = {}
for i, m in ipairs(BENCH_MODELS) do BENCH_HASHES[i] = GetHashKey(m) end

-- kilitlenen kontroller: hareket, koşu, zıplama, ateş/nişan, siper, araca binme, yakın dövüş
local LOCKED = { 21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 36, 44, 140, 141, 142, 143, 257, 263 }

local function defOf(id, adult)
    if adult then return Config.AdultAnimations and Config.AdultAnimations[id] end
    return (AN.Social and AN.Social[id]) or (Config.AdultAnimations and Config.AdultAnimations[id])
end

local function loadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(dict)
end

local function netPed(net)
    if not net or not NetworkDoesEntityExistWithNetworkId(net) then return 0 end
    local e = NetworkGetEntityFromNetworkId(net)
    if e ~= 0 and DoesEntityExist(e) then return e end
    return 0
end

-- En yakın bank ve üzerindeki iki oturma yeri (A: oyuncu, B: NPC)
local function findBench(pos)
    local best, bestD
    for _, h in ipairs(BENCH_HASHES) do
        local obj = GetClosestObjectOfType(pos.x, pos.y, pos.z, 5.0, h, false, false, false)
        if obj ~= 0 and DoesEntityExist(obj) then
            local d = #(GetEntityCoords(obj) - pos)
            if not bestD or d < bestD then best, bestD = obj, d end
        end
    end
    if not best then return nil end
    local heading = (GetEntityHeading(best) + 180.0) % 360.0
    return {
        a = GetOffsetFromEntityInWorldCoords(best, 0.5, 0.0, 0.5),
        b = GetOffsetFromEntityInWorldCoords(best, -0.5, 0.0, 0.5),
        h = heading,
    }
end

-- Rolün animasyon parçası (cinsiyete göre yer değiştirme, kadın varyantı, alçak araç varyantı)
local function partFor(def, role, ped, playerPed, npcPed)
    local r = role
    if def.swapByGender and playerPed ~= 0 and npcPed ~= 0 and not IsPedMale(playerPed) and IsPedMale(npcPed) then
        r = role == 'player' and 'npc' or 'player'
    end
    local part = def[r]
    if def.lowVariant then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 then
            local cls = GetVehicleClass(veh)
            if cls == 6 or cls == 7 then part = def.lowVariant[r] or part end
        end
    end
    if type(part) == 'table' and part.female and not IsPedMale(ped) then part = part.female end
    return part
end

local function playPart(ped, def, role, other, seat)
    local playerPed = role == 'player' and ped or other
    local npcPed = role == 'npc' and ped or other
    local part = partFor(def, role, ped, playerPed, npcPed)
    if not part then return false end
    -- harici animasyon kaynağı (Config.AdultNPC.ExternalPlayer)
    if Config.AdultNPC and type(Config.AdultNPC.ExternalPlayer) == 'function' and Config.AdultAnimations and def == Config.AdultAnimations[def._id or ''] then
        local ok, handled = pcall(Config.AdultNPC.ExternalPlayer, role, def, ped, other)
        if ok and handled then return true end
    end
    if part.scenario then
        if seat then
            TaskStartScenarioAtPosition(ped, part.scenario, seat.x, seat.y, seat.z, seat.h, 0, true, true)
        else
            TaskStartScenarioInPlace(ped, part.scenario, 0, true)
        end
        return true
    end
    if not part.dict or not loadDict(part.dict) then return false end
    local dur = def.loop and -1 or (def.duration or 3000)
    TaskPlayAnim(ped, part.dict, part.anim, 8.0, -8.0, dur, part.flag or 0, 0.0, false, false, false)
    return true
end

local function stopPart(ped, def, role, other)
    if not def then return end
    local part = partFor(def, role, ped, role == 'player' and ped or other, role == 'npc' and ped or other)
    if type(part) == 'table' and part.dict then
        StopAnimTask(ped, part.dict, part.anim, 2.0)
        RemoveAnimDict(part.dict)
    elseif type(part) == 'table' and part.scenario then
        if IsPedInAnyVehicle(ped, false) then
            ClearPedSecondaryTask(ped)
        else
            ClearPedTasks(ped)
        end
    end
end

-- Bu etkileşim için tüm registry'lerde id'yi def'e işle (harici oynatıcıya kimliği iletmek için)
for id, d in pairs(Config.AdultAnimations or {}) do d._id = id end
for id, d in pairs(AN.Social or {}) do d._id = id end

-- =====================================================================
-- NPC tarafı (network sahibi)
-- =====================================================================
function AnimC.ApplyNpc(ped, netId, spec, a)
    local def = defOf(spec.id, spec.adult)
    if not def then return end
    a.def = def
    local target = SC.Tasks.PedFromServerId(spec.target)
    a.target = target
    if spec.phase == 'align' then
        a.ready = false
        if def.vehicle or IsPedInAnyVehicle(ped, false) then
            a.ready = true
            SC.Tasks.Report(netId, spec.seq, 'int_ready')
            return
        end
        local pos, heading
        if spec.pos then
            pos = vector3(spec.pos.x + 0.0, spec.pos.y + 0.0, spec.pos.z + 0.0)
            heading = (spec.pos.h or 0.0) + 0.0
        elseif target ~= 0 then
            local off = def.offset or { front = 1.0, side = 0.0, heading = 180.0 }
            if def.special == 'sit' then
                local bench = findBench(GetEntityCoords(target))
                if bench then
                    a.seat = { x = bench.b.x, y = bench.b.y, z = bench.b.z, h = bench.h }
                    pos, heading = bench.b, bench.h
                end
            end
            if not pos then
                pos = GetOffsetFromEntityInWorldCoords(target, (off.side or 0.0) + 0.0, (off.front or 1.0) + 0.0, 0.0)
                heading = (GetEntityHeading(target) + (off.heading or 180.0)) % 360.0
            end
        end
        if not pos then return end
        a.alignPos, a.alignH = pos, heading
        ClearPedTasks(ped)
        TaskGoStraightToCoord(ped, pos.x, pos.y, pos.z, 1.0, AN.AlignTimeoutMs or 6000, heading, 0.05)
    elseif spec.phase == 'play' then
        local seat
        if def.special == 'sit' and target ~= 0 then
            local bench = findBench(GetEntityCoords(target))
            if bench then seat = { x = bench.b.x, y = bench.b.y, z = bench.b.z, h = bench.h } end
        end
        if def.special == 'sit' and not seat and def.ground then
            TaskStartScenarioInPlace(ped, def.ground.scenario, 0, true)
        else
            playPart(ped, def, 'npc', target, seat)
        end
        a.playing = true
        a.replays = 0
    end
end

function AnimC.MonitorNpc(ped, netId, spec, a, now)
    local def = a.def
    if not def then return end
    if spec.phase == 'align' and not a.ready and a.alignPos then
        local pc = GetEntityCoords(ped)
        local d = #(vector2(pc.x, pc.y) - vector2(a.alignPos.x, a.alignPos.y))
        if d < 0.45 or now - (a.startedAt or now) > (AN.AlignTimeoutMs or 6000) then
            -- son küçük düzeltme (en fazla ~0.8 m; ışınlama değil hizalama)
            if d < 0.8 then SetEntityCoordsNoOffset(ped, a.alignPos.x, a.alignPos.y, pc.z, false, false, false) end
            SetEntityHeading(ped, a.alignH or GetEntityHeading(ped))
            a.ready = true
            SC.Tasks.Report(netId, spec.seq, 'int_ready')
        end
    elseif spec.phase == 'play' and def.loop and a.playing then
        local part = partFor(def, 'npc', ped, a.target or 0, ped)
        if type(part) == 'table' and part.dict and not IsEntityPlayingAnim(ped, part.dict, part.anim, 3) and (a.replays or 0) < 3 then
            a.replays = (a.replays or 0) + 1
            playPart(ped, def, 'npc', a.target or 0)
        end
    end
end

function AnimC.CleanupNpc(ped, a)
    if a and a.def then stopPart(ped, a.def, 'npc', a.target or 0) end
end

-- =====================================================================
-- Oyuncu tarafı
-- =====================================================================
local function lockLoop()
    CreateThread(function()
        while AnimC.active do
            for i = 1, #LOCKED do DisableControlAction(0, LOCKED[i], true) end
            Wait(0)
        end
    end)
end

local function finish()
    local act = AnimC.active
    if not act then return end
    AnimC.active = nil
    lib.hideTextUI()
    local def = defOf(act.id, act.adult)
    if def then stopPart(cache.ped, def, 'player', netPed(act.net)) end
    if act.faded then DoScreenFadeIn(600) end
end

RegisterNetEvent('samy-citizens:client:interactionStart', function(data)
    if type(data) ~= 'table' or type(data.id) ~= 'string' then return end
    if AnimC.active then finish() end
    local def = defOf(data.id, data.adult)
    if not def then return end
    AnimC.active = { id = data.id, net = data.net, adult = data.adult == true, since = GetGameTimer() }
    lib.showTextUI(L('interact_cancel_hint', AN.CancelKey or 'X'), { position = 'left-center', icon = 'hand' })
    -- yan yana oturma: oyuncu bankın A yerine yürür
    if def.special == 'sit' then
        local bench = findBench(GetEntityCoords(cache.ped))
        if bench then
            AnimC.active.seat = { x = bench.a.x, y = bench.a.y, z = bench.a.z, h = bench.h }
            TaskGoStraightToCoord(cache.ped, bench.a.x, bench.a.y, bench.a.z, 1.0, 4000, bench.h, 0.05)
        end
    end
    lockLoop()
end)

RegisterNetEvent('samy-citizens:client:interactionPlay', function(data)
    local act = AnimC.active
    if not act or type(data) ~= 'table' or data.id ~= act.id then return end
    local def = defOf(act.id, act.adult)
    if not def then return end
    local npc = netPed(act.net)
    if act.adult and Config.AdultNPC and Config.AdultNPC.FadeScreen and def.private then
        act.faded = true
        DoScreenFadeOut(800)
    end
    if def.special == 'sit' and not act.seat and def.ground then
        TaskStartScenarioInPlace(cache.ped, def.ground.scenario, 0, true)
    else
        playPart(cache.ped, def, 'player', npc, act.seat)
    end
end)

RegisterNetEvent('samy-citizens:client:interactionStop', function(data)
    finish()
    local reason = type(data) == 'table' and data.reason or nil
    if reason and reason ~= 'done' and reason ~= 'cancel' and reason ~= 'replaced' then
        local key = 'interact_end_' .. tostring(reason)
        local msg = L(key)
        if msg ~= key then lib.notify({ title = L('notify_title'), description = msg, type = 'inform' }) end
    end
end)

lib.addKeybind({
    name = 'samy_citizens_interact_cancel',
    description = L('keybind_interact_cancel'),
    defaultKey = AN.CancelKey or 'X',
    onPressed = function()
        if AnimC.active then TriggerServerEvent('samy-citizens:server:interactionCancel') end
    end,
})

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if AnimC.active then
        local act = AnimC.active
        AnimC.active = nil
        ClearPedTasks(cache.ped)
        if act.faded then DoScreenFadeIn(0) end
        lib.hideTextUI()
    end
end)
