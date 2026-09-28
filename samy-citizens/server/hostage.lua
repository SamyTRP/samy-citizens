--[[
    REHİNE ALMA
    Silahlı oyuncu bir sakine nişan alıp [E] (ya da ox_target "Rehin al") ile rehin alır.
    Modlar:
      hold    : kalkan — oyuncunun önünde tutulur (silah başında), kaçamaz
      escort  : eller yukarı, oyuncunun önünden yürür
      kneel   : diz çöküp elleri başının arkasında bekler
      vehicle : yakındaki bir araca bindirilir
    Sunucu yetkilidir: doğrulama, mod geçişleri, kaçma denemeleri, polis ihbarı ve anı/ilişki etkileri burada.
    Rehinenin hareketlerini (bağlama, animasyon, araca binme) ped'in network sahibi istemci uygular (client/tasks.lua).
]]
local Utils = SC.Utils
local Clock = SC.Clock
local Sim = SC.Sim
local Spawner = SC.Spawner

local Hostage = {}
SC.Hostage = Hostage

Hostage.byTaker = {}   -- oyuncu src -> residentId

local UNARMED = GetHashKey('WEAPON_UNARMED')
local HARMLESS, MELEE = {}, {}
for _, w in ipairs({ 'WEAPON_FIREEXTINGUISHER', 'WEAPON_PETROLCAN', 'WEAPON_HAZARDCAN', 'WEAPON_FERTILIZERCAN', 'WEAPON_BALL',
    'WEAPON_SNOWBALL', 'WEAPON_FLARE', 'GADGET_PARACHUTE' }) do
    HARMLESS[GetHashKey(w)] = true
end
for _, w in ipairs({ 'WEAPON_DAGGER', 'WEAPON_BAT', 'WEAPON_BOTTLE', 'WEAPON_CROWBAR', 'WEAPON_FLASHLIGHT', 'WEAPON_GOLFCLUB',
    'WEAPON_HAMMER', 'WEAPON_HATCHET', 'WEAPON_KNUCKLE', 'WEAPON_KNIFE', 'WEAPON_MACHETE', 'WEAPON_SWITCHBLADE',
    'WEAPON_NIGHTSTICK', 'WEAPON_WRENCH', 'WEAPON_BATTLEAXE', 'WEAPON_POOLCUE', 'WEAPON_STONE_HATCHET' }) do
    MELEE[GetHashKey(w)] = true
end

local MODES = { hold = true, escort = true, kneel = true, vehicle = true }
local QUIET_END = { dead = true, despawn = true, shutdown = true }
local lastAttempt = {}

local function cfg()
    return Config.Hostage or {}
end

local function randMs(range, def)
    range = type(range) == 'table' and range or def
    local a, b = range[1] or 10, range[2] or range[1] or 10
    return math.floor((a + math.random() * math.max(0, b - a)) * 1000)
end

local function notify(src, key, ...)
    TriggerClientEvent('samy-citizens:client:notify', src, L(key, ...), 'error')
end

-- Sakinin gözünden söylenen tek cümle (rehine anında ilişki yerine yabancı tonu kullanılır)
local function line(r, key, sub)
    return SC.Dialogue.Line(key, r, { stage = 'stranger' }, sub)
end

local function weaponOk(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local w = GetSelectedPedWeapon(ped)
    if not w or w == 0 or w == UNARMED or HARMLESS[w] then return false end
    if MELEE[w] and not cfg().AllowMelee then return false end
    return true
end
Hostage.WeaponOk = weaponOk

function Hostage.Is(r)
    return r ~= nil and r.override ~= nil and r.override.type == 'hostage'
end

function Hostage.Get(src)
    local rid = Hostage.byTaker[src]
    local r = rid and Sim.Residents[rid]
    if r and Hostage.Is(r) and r.override.taker == src then return r end
    return nil
end

local function sendState(src, r, reason)
    if not src or not GetPlayerName(src) then return end
    if r then
        local phys = Spawner.peds[r.id]
        TriggerClientEvent('samy-citizens:client:hostageState', src, { net = phys and phys.netId, mode = r.override.mode })
    else
        TriggerClientEvent('samy-citizens:client:hostageState', src, false, reason)
    end
end

-- ---------------------------------------------------------------------
-- Rehin alma
-- ---------------------------------------------------------------------
function Hostage.Take(src, r)
    local C = cfg()
    if not C.Enabled then return false, 'err_hostage_disabled' end
    local now = GetGameTimer()
    if lastAttempt[src] and now - lastAttempt[src] < 1500 then return false end
    lastAttempt[src] = now
    if Hostage.byTaker[src] then return false, 'err_hostage_already' end
    if not r or not r.enabled or r.status ~= 'alive' then return false, 'err_unavailable' end
    if Hostage.Is(r) then return false, 'err_hostage_taken' end
    local ped = Spawner.GetPed(r)
    if not ped or GetEntityHealth(ped) <= 0 then return false, 'err_unavailable' end
    if GetVehiclePedIsIn(ped, false) ~= 0 then return false, 'err_hostage_vehicle' end
    local pped = GetPlayerPed(src)
    if not pped or pped == 0 or GetVehiclePedIsIn(pped, false) ~= 0 then return false, 'err_hostage_in_vehicle' end
    if not weaponOk(src) then return false, 'err_hostage_weapon' end
    if not Spawner.PlayerNear(src, r, (C.TakeDistance or 2.0) + 1.0) then return false, 'err_too_far' end
    local cid = SC.Bridge.GetCitizenId(src)
    if not cid then return false, 'err_no_char' end

    if r.convo then SC.Convo.End(r, 'threat') end
    -- nişan alınınca başlayan "eller yukarı / kaç" durumunu, sonrasını tetiklemeden bırak
    r.override = nil
    local h = {
        type = 'hostage', taker = src, cid = cid, mode = MODES[C.StartMode or ''] and C.StartMode or 'hold',
        since = now, nextEscapeAt = now + (C.EscapeCheckSec or 10) * 1000, nextPleadAt = now + randMs(C.PleadIntervalSec, { 10, 22 }),
    }
    Sim.SetOverride(r, h)
    Hostage.byTaker[src] = r.id
    Entity(ped).state:set('scHostage', src, true)
    Spawner.SetEmotion(r, 'scared')
    SC.Convo.Bubble(r, line(r, 'hostage_taken'), 'npc', 4000)
    sendState(src, r)

    local ppos = GetEntityCoords(pped)
    CreateThread(function()
        local rel = SC.Rel.Get(r.id, cid)
        rel.facts = rel.facts or {}
        rel.facts.kidnapped_at = os.time()
        SC.Rel.MarkDirty(rel)
        SC.World.ApplyEvent(r, cid, 'kidnapped', L('mem_kidnapped', SC.World.PlayerRef(r, cid, src)))
    end)
    local witnesses = SC.World.Witness(r.id, ppos, src, cid, 'mem_saw_hostage', C.WitnessRadius or 30.0)
    if witnesses and #witnesses > 0 then
        h.witness = witnesses[1]
        h.policeAt = now + (C.WitnessPoliceDelaySec or 20) * 1000
    end
    SC.Log.Event(L('log_hostage_title'), ('%s (%s) -> %s %s (%s)'):format(GetPlayerName(src) or '?', cid, r.firstname, r.lastname, r.id))
    Sim.AddLog(r, Clock.Now(), 'event', { text = L('log_hostage') })
    return true
end

-- ---------------------------------------------------------------------
-- Mod değiştirme
-- ---------------------------------------------------------------------
function Hostage.SetMode(src, mode, vehNet, seat)
    local r = Hostage.Get(src)
    if not r or not MODES[mode] then return end
    local h = r.override
    local ped = Spawner.GetPed(r)
    local pped = GetPlayerPed(src)
    if not ped or not pped or pped == 0 then return end
    if mode ~= 'vehicle' then
        if GetVehiclePedIsIn(pped, false) ~= 0 then return notify(src, 'hostage_exit_first') end
        if not Spawner.PlayerNear(src, r, mode == 'hold' and 4.0 or 12.0) then return notify(src, 'err_too_far') end
        h.veh, h.seat = nil, nil
    else
        local veh = NetworkGetEntityFromNetworkId(math.floor(tonumber(vehNet) or 0))
        if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return notify(src, 'hostage_no_vehicle') end
        if Utils.Dist(GetEntityCoords(veh), GetEntityCoords(ped)) > 12.0 then return notify(src, 'hostage_no_vehicle') end
        seat = math.floor(tonumber(seat) or 1)
        if seat < 0 or seat > 6 then seat = 1 end
        local occ = GetPedInVehicleSeat(veh, seat)
        if occ and occ ~= 0 and occ ~= ped then return notify(src, 'hostage_seat_taken') end
        h.veh, h.seat = NetworkGetNetworkIdFromEntity(veh), seat
    end
    h.mode = mode
    h.nextEscapeAt = GetGameTimer() + (cfg().EscapeCheckSec or 10) * 1000
    Spawner.UpdateTask(r)
    sendState(src, r)
    if math.random() < 0.6 then SC.Convo.Bubble(r, line(r, 'hostage_plead', mode), 'npc', 4000) end
end

-- ---------------------------------------------------------------------
-- Bitirme (serbest bırakma, kaçma, ölüm...)
-- ---------------------------------------------------------------------
function Hostage.End(r, reason)
    if not Hostage.Is(r) then return end
    local h = r.override
    local src = h.taker
    if Hostage.byTaker[src] == r.id then Hostage.byTaker[src] = nil end
    local ped = Spawner.GetPed(r)
    if ped then Entity(ped).state:set('scHostage', nil, true) end
    sendState(src, nil, reason)
    local pped = GetPlayerName(src) and GetPlayerPed(src) or nil
    local from = (pped and pped ~= 0 and DoesEntityExist(pped)) and GetEntityCoords(pped) or (ped and GetEntityCoords(ped))
    if r.convo then SC.Convo.End(r, 'threat') end
    Sim.ClearOverride(r, 'hostage_end')
    if QUIET_END[reason] or not ped or r.status ~= 'alive' then return end

    local C = cfg()
    SC.World.Flee(r, from or GetEntityCoords(ped), src, C.FleeSeconds or 35, C.ShakenMinutes or 300)
    SC.Convo.Bubble(r, line(r, reason == 'released' and 'hostage_freed' or 'hostage_escape'), 'npc', 4500)
    SetTimeout((C.ReleasePoliceDelaySec or 8) * 1000, function()
        if r.status == 'alive' then SC.World.CallPolice(r, L('police_reason_kidnapped'), src, nil, true) end
    end)
end

function Hostage.OnDied(r)
    if Hostage.Is(r) then Hostage.End(r, 'dead') end
end

-- ---------------------------------------------------------------------
-- Tick (1 sn): kaçma, polis ihbarı, yalvarma, bağlantı/ölüm kontrolü
-- ---------------------------------------------------------------------
local function tickOne(src, r, h, now)
    local C = cfg()
    local ped = Spawner.GetPed(r)
    if not ped then return Hostage.End(r, 'despawn') end
    if not GetPlayerName(src) then return Hostage.End(r, 'dropped') end
    local pped = GetPlayerPed(src)
    if not pped or pped == 0 then return Hostage.End(r, 'dropped') end
    if GetEntityHealth(pped) <= 0 then return Hostage.End(r, 'taker_down') end
    if (C.MaxMinutes or 0) > 0 and now - h.since > C.MaxMinutes * 60000 then return Hostage.End(r, 'timeout') end

    local npos = GetEntityCoords(ped)
    local d = Utils.Dist(npos, GetEntityCoords(pped))
    local takerVeh = GetVehiclePedIsIn(pped, false)
    local npcVeh = GetVehiclePedIsIn(ped, false)
    local sameCar = npcVeh ~= 0 and takerVeh == npcVeh
    local leash = C.LeashDistance or 25.0
    if not sameCar and d > leash then return Hostage.End(r, 'escape') end

    -- kaçma denemesi (kalkan modunda ve aynı araçtayken kaçamaz)
    if h.mode ~= 'hold' and not sameCar and now >= (h.nextEscapeAt or 0) then
        h.nextEscapeAt = now + (C.EscapeCheckSec or 10) * 1000
        local chance = weaponOk(src) and (C.EscapeChance or 0.04) or (C.EscapeChanceUnarmed or 0.35)
        if takerVeh ~= 0 and npcVeh == 0 then chance = math.max(chance, 0.5) end
        if d > leash * 0.5 then chance = chance + 0.15 end
        if math.random() < chance then return Hostage.End(r, 'escape') end
    end

    -- olayı gören bir sakin polisi arar (rehinenin bulunduğu yeri bildirir)
    if h.policeAt and not h.policeDone and now >= h.policeAt then
        h.policeDone = true
        local w = Sim.Residents[h.witness or '']
        if w and w.status == 'alive' then SC.World.CallPolice(w, L('police_reason_hostage'), src, npos, true) end
    end

    if now >= (h.nextPleadAt or 0) then
        h.nextPleadAt = now + randMs(C.PleadIntervalSec, { 10, 22 })
        if not r.convo then SC.Convo.Bubble(r, line(r, 'hostage_plead', h.mode), 'npc', 4500) end
    end
end

function Hostage.Tick()
    local now = GetGameTimer()
    for src, rid in pairs(Hostage.byTaker) do
        local r = Sim.Residents[rid]
        if not r or not Hostage.Is(r) or r.override.taker ~= src then
            Hostage.byTaker[src] = nil
            sendState(src, nil, 'despawn')
        else
            local ok, err = pcall(tickOne, src, r, r.override, now)
            if not ok then print(('^1[samy-citizens] rehine hatası: %s^7'):format(tostring(err))) end
        end
    end
end

-- ---------------------------------------------------------------------
-- İstemci olayları
-- ---------------------------------------------------------------------
RegisterNetEvent('samy-citizens:server:hostageTake', function(netId)
    local src = source
    if not SC.Ready then return end
    local r = Spawner.GetResidentByNet(netId)
    local ok, err = Hostage.Take(src, r)
    if not ok and err then notify(src, err) end
end)

RegisterNetEvent('samy-citizens:server:hostageMode', function(mode, vehNet, seat)
    if type(mode) ~= 'string' then return end
    Hostage.SetMode(source, mode, vehNet, seat)
end)

RegisterNetEvent('samy-citizens:server:hostageRelease', function()
    local r = Hostage.Get(source)
    if r then Hostage.End(r, 'released') end
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastAttempt[src] = nil
    local r = Hostage.Get(src)
    if r then Hostage.End(r, 'dropped') end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(Hostage.byTaker) do sendState(src, nil, 'shutdown') end
end)
