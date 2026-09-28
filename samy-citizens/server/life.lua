--[[
    GÜNLÜK HAYAT: KOMUTLAR, HİZMETLER, AŞK
    Diyalog motorunun ürettiği { type = 'command' } ve { type = 'service' } aksiyonlarını fiziksel dünyada uygular.
      follow   : oyuncuyu takip eder (arabaya da biner)
      wait     : olduğu yerde bekler
      goto     : haritada işaretli yere gider (yakınsa yürüyerek, uzaksa arabasıyla ya da görünmez taksiyle), orada bekler
      ride     : arabasına binip oyuncuyu gezdirir / işaretli yere götürür
      perform  : dans, oturma, sigara, şınav... (senaryo ya da animasyon)
      outing   : "hadi şimdi kahve içelim" -> o mekâna gider, bir süre kalır
      go_home  : evine döner; release: yaptığı işi bırakıp rutinine döner
      report   : polisi arar (dispatch)
      repair   : tamirci arabaya yürür, tamir eder
    Hizmetler (konuşma sürerken): sipariş (eşya/açlık-susuzluk), tedavi (can), ücret.
    Sunucu yetkilidir: mesafe, sahiplik ve aşama tekrar kontrol edilir.
]]
local Utils = SC.Utils
local Clock = SC.Clock
local Sim = SC.Sim
local Spawner = SC.Spawner

local Life = {}
SC.Life = Life

local lastService = {}   -- 'svc|npc|cid' -> os.time()
local lastReport = {}    -- npcId -> os.time()

local function A() return Config.Actions or {} end
local function S() return Config.JobServices or {} end

local function notify(src, msg, kind)
    if src and GetPlayerName(src) then TriggerClientEvent('samy-citizens:client:notify', src, msg, kind or 'inform') end
end

local function say(r, key, sub, vars)
    local line = SC.Dialogue.Line(key, r, { stage = 'friend' }, sub)
    if vars then
        for k, v in pairs(vars) do line = line:gsub('%%' .. k .. '%%', tostring(v)) end
    end
    SC.Convo.Bubble(r, line, 'npc', 5000)
    return line
end

local function vecFrom(t, zFallback)
    if type(t) ~= 'table' or not tonumber(t.x) or not tonumber(t.y) then return nil end
    local z = tonumber(t.z)
    if not z or z == 0.0 then z = zFallback or 0.0 end
    return vector3(t.x + 0.0, t.y + 0.0, z + 0.0)
end

-- =====================================================================
-- ARABA
-- =====================================================================
-- Sakinin arabası yakında mı (ya da park yerinde, oluşturulabilir mi)? spawn = true ise gerekirse oluşturur (thread içinden)
function Life.GetCar(r, spawn)
    if not r.vehicle or not r.car or r.car.missing then return nil end
    local pc = Spawner.GetPedCoords(r)
    if not pc then return nil end
    local rec = Spawner.vehicles[r.id]
    if rec and DoesEntityExist(rec.entity) then
        if Utils.Dist(GetEntityCoords(rec.entity), pc) <= 90.0 then return rec end
        return nil
    end
    if r.car.inUse then return nil end
    local loc = Sim.Locations[r.car.locationId or '']
    if not loc or not loc.parking or Utils.Dist(loc.parking, pc) > 90.0 then return nil end
    if not spawn then return true end
    local veh = Spawner.EnsureVehicle(r, vector3(loc.parking.x, loc.parking.y, loc.parking.z), loc.parking.w)
    if not veh then return nil end
    return Spawner.vehicles[r.id]
end

function Life.CarNearby(r)
    return Life.GetCar(r, false) ~= nil
end

-- =====================================================================
-- EYLEMLER ("dans et", "otur"...)
-- =====================================================================
Life.Performs = {
    dance = { anim = { m = { 'anim@amb@nightclub@mini@dance@dance_solo@male@var_a@', 'high_center' }, f = { 'anim@amb@nightclub@mini@dance@dance_solo@female@var_a@', 'high_center' } } },
    sit = { scenario = 'WORLD_HUMAN_PICNIC' },
    smoke = { scenario = 'WORLD_HUMAN_SMOKING' },
    drink = { scenario = 'WORLD_HUMAN_DRINKING' },
    pushups = { scenario = 'WORLD_HUMAN_PUSH_UPS' },
    situps = { scenario = 'WORLD_HUMAN_SIT_UPS' },
    yoga = { scenario = 'WORLD_HUMAN_YOGA' },
    music = { scenario = 'WORLD_HUMAN_MUSICIAN' },
    cheer = { scenario = 'WORLD_HUMAN_CHEERING' },
    photo = { scenario = 'WORLD_HUMAN_PAPARAZZI' },
    flex = { scenario = 'WORLD_HUMAN_MUSCLE_FLEX' },
    jog = { scenario = 'WORLD_HUMAN_JOG_STANDING' },
    phone = { scenario = 'WORLD_HUMAN_STAND_MOBILE' },
    binoculars = { scenario = 'WORLD_HUMAN_BINOCULARS' },
    lean = { scenario = 'WORLD_HUMAN_LEANING' },
    sunbathe = { scenario = 'WORLD_HUMAN_SUNBATHE_BACK' },
    repair = { anim = { m = { 'mini@repair', 'fixing_a_ped' }, f = { 'mini@repair', 'fixing_a_ped' } } },
    medic = { anim = { m = { 'anim@amb@business@weed@weed_inspecting_high_dry@', 'weed_inspecting_high_base_inspector' }, f = { 'anim@amb@business@weed@weed_inspecting_high_dry@', 'weed_inspecting_high_base_inspector' } } },
}

-- Spawner.BuildTask'tan çağrılır: komut override'ı -> görev tanımı
function Life.BuildTask(r, ov)
    if ov.type == 'wait' and ov.pos then
        return { kind = 'idle', x = ov.pos.x, y = ov.pos.y, z = ov.pos.z, h = ov.pos.w or 0.0, scenario = ov.scenario or 'WORLD_HUMAN_STAND_IMPATIENT' }
    end
    if ov.type == 'goto' then
        local d = ov.dest
        if ov.mode == 'drive' and ov.veh then
            return { kind = 'drive', veh = ov.veh, x = d.x, y = d.y, z = d.z, h = 0.0, speed = Config.Travel.DriveSpeed, style = Config.Travel.DrivingStyle }
        elseif ov.mode == 'taxi' then
            local from = ov.from or d
            local dx, dy = d.x - from.x, d.y - from.y
            local len = math.max(1.0, math.sqrt(dx * dx + dy * dy))
            return { kind = 'leave', x = from.x + dx / len * 45.0, y = from.y + dy / len * 45.0, z = from.z }
        end
        return { kind = 'walk', x = d.x, y = d.y, z = d.z, h = 0.0 }
    end
    if ov.type == 'ride' then
        local d = ov.dest
        return {
            kind = 'ride', veh = ov.veh, passenger = ov.passenger, boarded = ov.boarded == true,
            x = d and d.x or nil, y = d and d.y or nil, z = d and d.z or nil,
            speed = (Config.Travel.DriveSpeed or 14.0) * 0.85, style = Config.Travel.DrivingStyle,
        }
    end
    if ov.type == 'perform' then
        local p = Life.Performs[ov.key or ''] or Life.Performs.dance
        local pos = ov.pos or { x = 0.0, y = 0.0, z = 0.0, w = 0.0 }
        if p.scenario then
            return { kind = 'scenario', x = pos.x, y = pos.y, z = pos.z, h = pos.w or 0.0, scenario = p.scenario }
        end
        return { kind = 'anim', dictM = p.anim.m[1], animM = p.anim.m[2], dictF = p.anim.f[1], animF = p.anim.f[2], face = ov.face }
    end
    return nil
end

-- =====================================================================
-- KOMUTLAR (konuşma bittikten sonra çalışır; thread içinden)
-- =====================================================================
local function pedPos(r)
    local ped = Spawner.GetPed(r)
    if not ped then return nil end
    local c = GetEntityCoords(ped)
    return vector4(c.x, c.y, c.z, GetEntityHeading(ped))
end

local function startWait(r, pos, minutes, scenario)
    Sim.SetFreePos(r, pos, 'idle')
    Sim.SetOverride(r, {
        type = 'wait', pos = Utils.VecToTable(pos), scenario = scenario,
        untilMs = GetGameTimer() + math.max(1, minutes or 5) * 60000,
    })
end

local function arrive(r, ov)
    local p = pedPos(r)
    local dest = (p and Utils.Dist(p, ov.dest) < 40.0) and p or vector4(ov.dest.x, ov.dest.y, ov.dest.z, 0.0)
    if ov.mode == 'drive' and r.car then r.car.inUse = false end
    if ov.onArrive then
        local ok, err = pcall(ov.onArrive, r, dest)
        if not ok then print(('^1[samy-citizens] komut varış hatası: %s^7'):format(tostring(err))) end
        return
    end
    startWait(r, dest, A().GotoWaitMinutes or 6)
    SC.Convo.Bubble(r, SC.Dialogue.Line('cmd_wait', r, { stage = 'friend' }, 'yes'), 'npc', 4000)
end

-- Bir hedefe git (yürü / arabayla / taksi) ve varınca onArrive (yoksa orada bekle)
function Life.Goto(r, dest, mode, onArrive)
    local p = pedPos(r)
    if not p then return false end
    local ov = { type = 'goto', dest = { x = dest.x, y = dest.y, z = dest.z }, mode = mode or 'walk', onArrive = onArrive, from = { x = p.x, y = p.y, z = p.z } }
    local now = GetGameTimer()
    ov.untilMs = now + (A().GotoTimeoutMinutes or 6) * 60000
    if ov.mode == 'drive' then
        local rec = Life.GetCar(r, true)
        if rec and type(rec) == 'table' and DoesEntityExist(rec.entity) then
            SetVehicleDoorsLocked(rec.entity, 1)
            ov.veh = rec.netId
            if r.car then r.car.inUse = true end
        else
            ov.mode = 'taxi'
        end
    end
    if ov.mode == 'taxi' then
        local dist = Utils.Dist(p, dest)
        -- görünmez yolculuk süresi (gerçek sn): taksi hızı + 20 sn bekleme
        ov.arriveAt = now + math.floor((dist * (Config.Travel.DetourFactor or 1.35) / (Config.Travel.TransitSpeed or 9.0) + 20) * 1000)
        ov.untilMs = ov.arriveAt + 120000
    end
    Sim.SetOverride(r, ov)
    return true
end

function Life.Run(r, src, cmd)
    if not r or r.status ~= 'alive' or (SC.Hostage and SC.Hostage.Is(r)) then return end
    local name = cmd.cmd
    local now = GetGameTimer()
    if name == 'follow' then
        Sim.SetOverride(r, { type = 'follow', target = src, untilMs = now + math.max(1, cmd.minutes or 10) * 60000 })
        notify(src, L('ui_follow', r.firstname, cmd.minutes or 10))
    elseif name == 'wait' then
        local p = pedPos(r)
        if p then
            startWait(r, p, cmd.minutes or A().WaitMinutes or 8)
            notify(src, L('ui_wait', r.firstname, cmd.minutes or A().WaitMinutes or 8))
        end
    elseif name == 'release' then
        if r.override and r.override.type ~= 'hostage' then Sim.ClearOverride(r, 'released') end
    elseif name == 'go_home' then
        if r.override and r.override.type ~= 'hostage' then Sim.ClearOverride(r, 'released') end
        Sim.SetTempSeg(r, 'home_idle', 'home', 90)
    elseif name == 'goto' then
        local p = pedPos(r)
        local dest = vecFrom(cmd.wp, p and p.z)
        if dest and Life.Goto(r, dest, cmd.mode) then notify(src, L('ui_goto', r.firstname)) end
    elseif name == 'ride' then
        Life.StartRide(r, src, cmd.wp)
    elseif name == 'perform' then
        local p = pedPos(r)
        if p then
            local pped = GetPlayerPed(src)
            Sim.SetOverride(r, {
                type = 'perform', key = cmd.key, pos = Utils.VecToTable(p),
                face = (pped and pped ~= 0) and NetworkGetNetworkIdFromEntity(pped) or nil,
                untilMs = now + (A().PerformMinutes or 3) * 60000,
            })
        end
    elseif name == 'outing' then
        local loc = Sim.Locations[cmd.locationId or '']
        if loc then
            local act = ({ bar = 'drink', cafe = 'coffee', restaurant = 'eat', fastfood = 'eat', park = 'leisure', beach = 'leisure', gym = 'exercise', pier = 'fish', shop = 'shopping' })[loc.type] or 'leisure'
            if r.override and r.override.type ~= 'hostage' then Sim.ClearOverride(r, 'outing') end
            Sim.SetTempSeg(r, act, loc.id, A().OutingMinutes or 25)
        end
    elseif name == 'report' then
        Life.Report(r, src, cmd.reason)
    elseif name == 'repair' then
        Life.StartRepair(r, src, cmd)
    end
end

-- Polis ihbarı: oyuncunun bulunduğu yer bildirilir
function Life.Report(r, src, reason)
    local nowS = os.time()
    if lastReport[r.id] and nowS - lastReport[r.id] < (A().ReportCooldownSec or 120) then return false end
    lastReport[r.id] = nowS
    local pped = GetPlayerPed(src)
    local coords = (pped and pped ~= 0) and GetEntityCoords(pped) or nil
    local text = Utils.Trim(tostring(reason or ''))
    local msg = text ~= '' and L('police_reason_request', text) or L('police_reason_request_plain')
    SC.World.CallPolice(r, msg, nil, coords, true)
    notify(src, L('ui_report', r.firstname), 'success')
    return true
end

function Life.ReportBlocked(r)
    return lastReport[r.id] and os.time() - lastReport[r.id] < (A().ReportCooldownSec or 120) or false
end

-- =====================================================================
-- ARABA GEZMESİ
-- =====================================================================
function Life.StartRide(r, src, wp)
    local rec = Life.GetCar(r, true)
    if not rec or type(rec) ~= 'table' or not DoesEntityExist(rec.entity) then
        say(r, 'cmd_ride', 'far')
        return false
    end
    SetVehicleDoorsLocked(rec.entity, 1)
    if r.car then r.car.inUse = true end
    local now = GetGameTimer()
    local p = pedPos(r)
    Sim.SetOverride(r, {
        type = 'ride', veh = rec.netId, passenger = src, dest = vecFrom(wp, p and p.z), boarded = false,
        boardBy = now + (A().RideBoardSeconds or 60) * 1000,
        untilMs = now + (A().RideMaxMinutes or 12) * 60000,
        chatAt = now + 25000,
    })
    TriggerClientEvent('samy-citizens:client:rideState', src, { veh = rec.netId, name = r.firstname })
    notify(src, L('ui_ride_board', r.firstname))
    return true
end

function Life.EndRide(r, lineKey)
    local ov = r.override
    if not ov or ov.type ~= 'ride' then return end
    local src = ov.passenger
    if lineKey then say(r, lineKey) end
    if r.car then r.car.inUse = false end
    Sim.ClearOverride(r, 'ride_end')
    TriggerClientEvent('samy-citizens:client:rideState', src, false)
end

RegisterNetEvent('samy-citizens:server:rideDest', function(x, y, z)
    local src = source
    if type(x) ~= 'number' or type(y) ~= 'number' then return end
    for _, r in ipairs(Sim.List) do
        local ov = r.override
        if ov and ov.type == 'ride' and ov.passenger == src then
            ov.dest = vector3(x + 0.0, y + 0.0, (tonumber(z) or 0.0) + 0.0)
            ov.arrived = nil
            Spawner.UpdateTask(r)
            return
        end
    end
end)

-- =====================================================================
-- TAMİR
-- =====================================================================
function Life.StartRepair(r, src, cmd)
    local veh = NetworkGetEntityFromNetworkId(math.floor(tonumber(cmd.veh) or 0))
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then
        say(r, 'repair', 'novehicle')
        return
    end
    local vc = GetEntityCoords(veh)
    local h = math.rad(GetEntityHeading(veh))
    -- kaputun önü
    local front = vector3(vc.x - math.sin(h) * 2.6, vc.y + math.cos(h) * 2.6, vc.z)
    local vehNet = NetworkGetNetworkIdFromEntity(veh)
    Life.Goto(r, front, 'walk', function(rr, pos)
        Sim.SetFreePos(rr, pos, 'idle')
        Sim.SetOverride(rr, {
            type = 'perform', key = 'repair', pos = Utils.VecToTable(vector4(pos.x, pos.y, pos.z, (GetEntityHeading(veh) + 180.0) % 360.0)),
            untilMs = GetGameTimer() + (S().RepairSeconds or 9) * 1000,
            after = function(r2, reason)
                if reason ~= 'expired' then return end
                if not DoesEntityExist(veh) then return end
                if (cmd.price or 0) > 0 and not Life.Charge(src, cmd.price) then
                    say(r2, 'repair', 'nomoney', { price = cmd.price .. '$' })
                    return
                end
                TriggerClientEvent('samy-citizens:client:repairVehicle', src, vehNet)
                say(r2, 'repair', 'done')
                notify(src, L('ui_repaired'), 'success')
            end,
        })
    end)
end

-- =====================================================================
-- HİZMETLER (konuşma sürerken)
-- =====================================================================
function Life.Charge(src, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    if not SC.Bridge.RemoveMoney then return true end
    local ok = SC.Bridge.RemoveMoney(src, S().Account or 'cash', amount)
    if ok then notify(src, L('ui_paid', amount)) end
    return ok
end

function Life.Blocked(kind, r, cid)
    local key = kind .. '|' .. r.id .. '|' .. tostring(cid)
    local cd = kind == 'heal' and (S().HealCooldownSec or 300) or (kind == 'repair' and (S().RepairCooldownSec or 300) or (S().ServiceCooldownSec or 20))
    return lastService[key] and os.time() - lastService[key] < cd or false
end

local function markService(kind, r, cid)
    lastService[kind .. '|' .. r.id .. '|' .. tostring(cid)] = os.time()
end

local function findMenuItem(r, key)
    local menu = SC.Jobs.Menu(r)
    for _, m in ipairs(menu or {}) do if m.key == key then return m end end
    return nil
end

local function oxStarted() return GetResourceState('ox_inventory') == 'started' end

-- dönüş: ui metni (ya da nil), hata anahtarı
function Life.Service(ctx, a)
    local r, src, cid = ctx.r, ctx.src, ctx.citizenid
    if ctx.channel ~= 'talk' or not Spawner.PlayerNear(src, r, 6.0) then return nil end
    if a.svc == 'order' then
        local item = findMenuItem(r, a.item)
        if not item or Life.Blocked('order', r, cid) then return nil end
        local price = math.floor(tonumber(a.price) or 0)
        if price > 0 and not Life.Charge(src, price) then return nil end
        markService('order', r, cid)
        local given = false
        if S().GiveItems ~= false and item.item and oxStarted() then
            local ok, res = pcall(function()
                if exports.ox_inventory:Items(item.item) and exports.ox_inventory:CanCarryItem(src, item.item, 1) then
                    return exports.ox_inventory:AddItem(src, item.item, 1)
                end
                return false
            end)
            given = ok and res and true or false
        end
        if not given and SC.Bridge.AddStatus then
            SC.Bridge.AddStatus(src, item.kind == 'food' and 'hunger' or 'thirst', item.kind == 'other' and 0 or 30)
        end
        SetTimeout(900, function()
            TriggerClientEvent('samy-citizens:client:playerAnim', src, given and 'take' or (item.kind == 'food' and 'eat' or 'drink'))
        end)
        SC.World.ApplyEvent(r, cid, 'served', L('mem_served', ctx.charName or L('ctx_someone'), SC.Dialogue.Lowerfirst(item.label)))
        return L('ui_served', item.label, price > 0 and (price .. '$') or L('price_free_short'))
    elseif a.svc == 'heal' then
        if Life.Blocked('heal', r, cid) then return nil end
        local price = math.floor(tonumber(a.price) or 0)
        if price > 0 and not Life.Charge(src, price) then return nil end
        markService('heal', r, cid)
        Spawner.PlayGesture(r, 'medic')
        local amount = S().HealAmount or 60
        if a.offduty then amount = math.floor(amount / 2) end
        local rid = r.id
        SetTimeout(5200, function()
            local rr = Sim.Residents[rid]
            if not rr or not Spawner.PlayerNear(src, rr, 6.0) then return end
            TriggerClientEvent('samy-citizens:client:heal', src, amount, S().HealClientEvent)
            local line = SC.Dialogue.Line('heal', rr, { stage = 'friend' }, 'done')
            if rr.convo and rr.convo.src == src then SC.Convo.NpcSay(rr, rr.convo, line, 'happy') else SC.Convo.Bubble(rr, line) end
            SC.World.ApplyEvent(rr, cid, 'helped_heal', L('mem_helped_heal', ctx.charName or L('ctx_someone')))
        end)
        return L('ui_healing', r.firstname)
    elseif a.svc == 'repair' then
        if Life.Blocked('repair', r, cid) then return nil end
        markService('repair', r, cid)
        return nil, { cmd = 'repair', veh = a.veh, price = a.price, endReason = 'repair' }
    end
    return nil
end

-- =====================================================================
-- GÖREV OLAYLARI / TICK
-- =====================================================================
-- Spawner taskEvent'ten: true dönerse olay işlenmiştir
function Life.OnTaskEvent(r, event)
    local ov = r.override
    if not ov then return false end
    if ov.type == 'goto' and (event == 'arrived' or event == 'parked') then
        arrive(r, ov)
        return true
    end
    if ov.type == 'goto' and event == 'noveh' then
        ov.mode = 'walk'
        ov.veh = nil
        if r.car then r.car.inUse = false end
        Spawner.UpdateTask(r)
        return true
    end
    if ov.type == 'ride' and event == 'arrived' then
        if not ov.arrived then
            ov.arrived = true
            say(r, 'ride_arrived')
            local rid = r.id
            SetTimeout(6000, function()
                local rr = Sim.Residents[rid]
                if rr and rr.override == ov then Life.EndRide(rr) end
            end)
        end
        return true
    end
    return false
end

-- Ped silinirken: yoldaki sakin soyut olarak yoluna devam eder
function Life.OnDespawn(r)
    local ov = r.override
    if not ov then return end
    if ov.type == 'goto' and ov.mode ~= 'taxi' then
        local p = pedPos(r)
        local dist = p and Utils.Dist(p, ov.dest) or 200.0
        ov.mode = 'taxi'
        if ov.veh and r.car then r.car.inUse = false end
        ov.veh = nil
        ov.arriveAt = GetGameTimer() + math.floor((dist / (Config.Travel.TransitSpeed or 9.0) + 10) * 1000)
        ov.untilMs = ov.arriveAt + 120000
    elseif ov.type == 'ride' or ov.type == 'perform' then
        if ov.type == 'ride' then TriggerClientEvent('samy-citizens:client:rideState', ov.passenger, false) end
        if r.car and ov.type == 'ride' then r.car.inUse = false end
        Sim.ClearOverride(r, 'despawn')
    end
end

local function tickOne(r, ov, now)
    if ov.type == 'goto' then
        if ov.mode == 'taxi' and ov.arriveAt and now >= ov.arriveAt and not Spawner.peds[r.id] then
            -- görünmez yolculuk bitti: hedefte belirir ve bekler
            Sim.SetFreePos(r, vector4(ov.dest.x, ov.dest.y, ov.dest.z, 0.0), 'idle')
            Sim.SetOverride(r, { type = 'wait', pos = { x = ov.dest.x, y = ov.dest.y, z = ov.dest.z, w = 0.0 }, untilMs = now + (A().GotoWaitMinutes or 6) * 60000 })
        elseif now > (ov.untilMs or 0) then
            local p = pedPos(r)
            if p and Utils.Dist(p, ov.dest) < 40.0 then arrive(r, ov) else
                if ov.veh and r.car then r.car.inUse = false end
                Sim.ClearOverride(r, 'timeout')
            end
        end
    elseif ov.type == 'ride' then
        local src = ov.passenger
        if not GetPlayerName(src) then return Life.EndRide(r) end
        local pped = GetPlayerPed(src)
        local veh = NetworkGetEntityFromNetworkId(ov.veh or 0)
        if not veh or veh == 0 or not DoesEntityExist(veh) then return Life.EndRide(r) end
        local inside = pped and pped ~= 0 and GetVehiclePedIsIn(pped, false) == veh
        if not ov.boarded then
            if inside then
                ov.boarded = true
                Spawner.UpdateTask(r)
                say(r, 'ride_chat')
                ov.chatAt = now + math.random(35, 60) * 1000
            elseif now > (ov.boardBy or 0) then
                return Life.EndRide(r, 'ride_end')
            elseif now > (ov.waitNagAt or 0) then
                ov.waitNagAt = now + 20000
                say(r, 'ride_wait')
            end
        elseif not inside then
            return Life.EndRide(r, 'ride_end')
        elseif now >= (ov.chatAt or 0) and not ov.arrived then
            ov.chatAt = now + math.random(40, 75) * 1000
            say(r, 'ride_chat')
        end
        if now > (ov.untilMs or 0) then return Life.EndRide(r, 'ride_end') end
    elseif ov.type == 'follow' then
        if not GetPlayerName(ov.target or -1) then Sim.ClearOverride(r, 'target_left') end
    end
end

function Life.Tick()
    local now = GetGameTimer()
    for _, r in ipairs(Sim.List) do
        local ov = r.override
        if ov and (ov.type == 'goto' or ov.type == 'ride' or ov.type == 'follow') then
            local ok, err = pcall(tickOne, r, ov, now)
            if not ok then print(('^1[samy-citizens] hayat tick hatası (%s): %s^7'):format(r.id, tostring(err))) end
        end
    end
end

-- =====================================================================
-- AŞK: aldatılma (dedikodu ile öğrenir)
-- =====================================================================
function Life.OnGossip(from, to, mem)
    local R = Config.Romance or {}
    if mem.code ~= 'became_lover' or R.AllowMultiple or not mem.citizenid then return end
    local rel = SC.Rel.Get(to.id, mem.citizenid)
    if rel.stage ~= 'lover' then return end
    rel.facts = rel.facts or {}
    rel.facts.lover = false
    rel.facts.ex = true
    rel.facts.broke_up_at = os.time()
    local pen = R.CheatPenalty or { -35, -40 }
    SC.Rel.ApplyDelta(rel, pen[1] or -35, pen[2] or -40, { bypassCap = true })
    local who = rel.name_known and rel.char_name or L('ctx_someone')
    SC.Memory.Add(to.id, mem.citizenid, L('mem_cheated', who, from.firstname), 9, 'event', {
        valence = -1, shareable = true, data = { code = 'cheated', from = from.id },
    })
    Sim.AddMoodEvent(to, -50, L('mood_reason_cheated'), 'cheated')
    -- telefon numarası varsa mesajla hesap sorar
    if rel.phone_known and rel.player_phone and SC.Phone and SC.Phone.Enabled() then
        local line = SC.Dialogue.Line('cheated', to, rel):gsub('%%other%%', from.firstname)
        SC.Phone.SendToPlayer(to, mem.citizenid, rel.player_phone, line, SC.Bridge.GetSourceByCitizenId(mem.citizenid))
    end
end

-- =====================================================================
-- İSTEMCİ: yakındaki araç / işaret (konuşma mesajıyla gelir, sunucuda doğrulanır)
-- =====================================================================
function Life.SanitizeMeta(src, r, meta)
    local out = {}
    if type(meta) ~= 'table' then return out end
    if type(meta.wp) == 'table' and tonumber(meta.wp.x) and tonumber(meta.wp.y) then
        local x, y, z = tonumber(meta.wp.x), tonumber(meta.wp.y), tonumber(meta.wp.z)
        if math.abs(x) < 10000 and math.abs(y) < 10000 then
            out.wp = { x = x + 0.0, y = y + 0.0, z = (z and math.abs(z) < 3000) and (z + 0.0) or nil }
        end
    end
    local vnet = math.floor(tonumber(meta.veh) or 0)
    if vnet > 0 then
        local veh = NetworkGetEntityFromNetworkId(vnet)
        local pped = GetPlayerPed(src)
        if veh and veh ~= 0 and DoesEntityExist(veh) and GetEntityType(veh) == 2 and pped and pped ~= 0
            and Utils.Dist(GetEntityCoords(veh), GetEntityCoords(pped)) <= 10.0 then
            out.veh = vnet
        end
    end
    return out
end
