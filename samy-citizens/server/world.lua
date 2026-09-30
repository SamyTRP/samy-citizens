--[[
    DÜNYA OLAYLARINA TEPKİ
    - Silah doğrultma / ateş / patlama / çarpma / saldırı: fiziksel sakin kaçar, soyut sakin "witnessed" anısı alır
    - Ölüm: status = hospital (veya PermaDeath), faili biliyorsa hatırlar
    - Araç hırsızlığı, polis çağrısı (dispatch)
    İstemci raporları sunucuda doğrulanır (mesafe, silah durumu, hız sınırı) ve sadece raporlayanın
    kendisi hakkında anı üretir; başkası adına sahte olay yaratılamaz.
]]
local Utils = SC.Utils
local Clock = SC.Clock
local Sim = SC.Sim

local World = {}
SC.World = World

local lastPolice = {}
local lastReport = {}
local lastDamage = {}
local lastWitness = {}

local UNARMED = GetHashKey('WEAPON_UNARMED')

local function throttled(key, seconds)
    local now = os.time()
    if lastReport[key] and now - lastReport[key] < seconds then return true end
    lastReport[key] = now
    return false
end

function World.NearestLabel(pos)
    local best, bestD = nil, 300.0
    for _, loc in pairs(Sim.Locations) do
        if loc.public then
            local d = Utils.Dist(pos, loc.door)
            if d < bestD then best, bestD = loc, d end
        end
    end
    return best and best.label or L('loc_somewhere')
end

-- NPC'nin gözünden oyuncu: adını biliyorsa adı, bilmiyorsa "tanımadığım bir adam/kadın" (thread içinden)
function World.PlayerRef(r, cid, src)
    if cid then
        local rel = SC.Rel.Get(r.id, cid)
        if rel and rel.name_known and rel.char_name then return rel.char_name end
    end
    local ci = src and SC.Bridge.GetCharInfo(src)
    return L('someone_' .. ((ci and ci.gender) or 'male'))
end

-- Oyun olayı -> anı + ilişki + ruh hâli
function World.ApplyEvent(r, citizenid, eventType, text, opts)
    local ev = Config.Events[eventType]
    if not ev or not r then return end
    opts = opts or {}
    SC.Memory.AddAsync(r.id, citizenid, text, ev.importance, opts.memType or 'event', {
        valence = ev.valence or 0, shareable = ev.shareable and citizenid ~= nil,
        data = { code = eventType, item = opts.item },
    })
    if citizenid and ((ev.affinity or 0) ~= 0 or (ev.trust or 0) ~= 0) then
        CreateThread(function()
            local rel = SC.Rel.Get(r.id, citizenid)
            SC.Rel.ApplyDelta(rel, ev.affinity or 0, ev.trust or 0, { bypassCap = true })
        end)
    end
    if ev.mood then Sim.AddMoodEvent(r, ev.mood, Utils.Truncate(text, 90), eventType) end
end

function World.Flee(r, fromPos, targetSrc, seconds, shakenMinutes)
    if r.override and r.override.type == 'hostage' then return end
    if r.convo then SC.Convo.End(r, 'flee') end
    if r.interaction and SC.Interact then SC.Interact.Stop(r, 'threat') end
    if SC.NPC and SC.NPC.Companion(r) then SC.Companion.End(r, 'flee', { silent = true }) end
    Sim.SetOverride(r, {
        type = 'flee', from = Utils.VecToTable(fromPos), target = targetSrc,
        untilMs = GetGameTimer() + (seconds or Config.World.FleeSeconds or 25) * 1000,
        after = function(rr)
            Sim.SetTempSeg(rr, 'home_idle', 'home', shakenMinutes or Config.World.ShakenMinutes or 120)
        end,
    })
    SC.Spawner.SetEmotion(r, 'scared')
end

-- ---------------------------------------------------------------------
-- Polis
-- ---------------------------------------------------------------------
-- coords: ihbar edilen yer (varsayılan: arayanın konumu); force: bekleme süresini yok say
function World.CallPolice(r, reason, suspectSrc, coords, force)
    local sys = Config.Dispatch.System
    if not sys or sys == 'none' then return false end
    local now = os.time()
    if not force and lastPolice[r.id] and now - lastPolice[r.id] < (Config.Actions.PoliceCooldownSec or 90) then return false end
    lastPolice[r.id] = now
    coords = coords or SC.Spawner.GetPedCoords(r) or Sim.GetPosition(r)
    if not coords then return false end
    local name = r.firstname .. ' ' .. r.lastname
    local msg = L('police_msg', name, reason)
    if sys == 'cd_dispatch' then
        TriggerEvent('cd_dispatch:AddNotification', {
            job_table = Config.Dispatch.Jobs,
            coords = coords,
            title = Config.Dispatch.Code .. ' - ' .. L('police_title'),
            message = msg,
            flash = 0,
            unique_id = tostring(math.random(1000000, 9999999)),
            sound = 1,
            blip = {
                sprite = Config.Dispatch.Blip.sprite, scale = Config.Dispatch.Blip.scale, colour = Config.Dispatch.Blip.color,
                flashes = false, text = L('police_title'), time = 5, radius = 0,
            },
        })
    elseif sys == 'ps-dispatch' then
        -- ps-dispatch uyarısı istemci export'u ile oluşturulur (sokak adı istemcide hesaplanır)
        local target
        local ped = SC.Spawner.GetPed(r)
        if ped then
            local owner = NetworkGetEntityOwner(ped)
            if owner and owner > 0 then target = owner end
        end
        if not target then
            local best = 400.0
            for _, p in ipairs(SC.Spawner.Players()) do
                local d = Utils.Dist(p.coords, coords)
                if d < best then best, target = d, p.src end
            end
        end
        target = target or suspectSrc
        if target then
            TriggerClientEvent('samy-citizens:client:dispatch', target, {
                coords = coords, message = msg, code = Config.Dispatch.Code, title = L('police_title'),
                blip = Config.Dispatch.Blip, jobs = Config.Dispatch.Jobs,
            })
        end
    elseif sys == 'custom' and Config.Dispatch.Custom then
        local ok, err = pcall(Config.Dispatch.Custom, { coords = coords, message = msg, residentName = name, reason = reason })
        if not ok then print(('^1[samy-citizens] dispatch custom hatası: %s^7'):format(tostring(err))) end
    end
    Sim.AddLog(r, Clock.Now(), 'event', { text = L('log_called_police') })
    Sim.AddMoodEvent(r, -10, L('mood_reason_police'), 'police')
    return true
end

-- Yakındaki diğer fiziksel sakinler olaya tanık olur; tanık kimliklerini döndürür
function World.Witness(exceptId, pos, src, cid, memKey, radius)
    local seen = {}
    for _, r in ipairs(Sim.List) do
        if r.id ~= exceptId and r.enabled and r.status == 'alive' and not (r.override and r.override.type == 'hostage') then
            local rp = SC.Spawner.GetPedCoords(r)
            if rp and Utils.Dist(rp, pos) <= (radius or 25.0) then
                local wkey = 'wit|' .. r.id
                local now = os.time()
                if not lastWitness[wkey] or now - lastWitness[wkey] > 60 then
                    lastWitness[wkey] = now
                    CreateThread(function()
                        local who = World.PlayerRef(r, cid, src)
                        SC.Memory.Add(r.id, cid, L(memKey, who), 6, 'witnessed', {
                            valence = -1, shareable = true, data = { code = (memKey:gsub('^mem_', '')) },
                        })
                        if cid then
                            local rel = SC.Rel.Get(r.id, cid)
                            SC.Rel.ApplyDelta(rel, -10, -10, { bypassCap = true })
                        end
                    end)
                    Sim.AddMoodEvent(r, -20, L('mood_reason_witness'), 'witness')
                    World.Flee(r, pos, src)
                    seen[#seen + 1] = r.id
                end
            end
        end
    end
    return seen
end

-- ---------------------------------------------------------------------
-- Olay işleyiciler
-- ---------------------------------------------------------------------
function World.OnAimed(r, src)
    if r.override and r.override.type == 'hostage' then return end
    if throttled('aim|' .. src .. '|' .. r.id, Config.World.AimReportCooldownSec or 6) then return end
    local cid = SC.Bridge.GetCitizenId(src)
    if not cid then return end
    local ppos = GetEntityCoords(GetPlayerPed(src))
    if r.convo then SC.Convo.End(r, 'threat') end
    SC.Convo.Bubble(r, SC.Actions.PickLine('scream_aim'), 'npc', 4000)
    SC.Spawner.SetEmotion(r, 'scared')
    Sim.SetOverride(r, {
        type = 'handsup', target = src, untilMs = GetGameTimer() + 3500,
        after = function(rr) World.Flee(rr, ppos, src) end,
    })
    CreateThread(function()
        World.ApplyEvent(r, cid, 'aim_weapon', L('mem_aimed', World.PlayerRef(r, cid, src)))
        Wait(4000)
        World.CallPolice(r, L('police_reason_aim'), src)
    end)
    World.Witness(r.id, ppos, src, cid, 'mem_saw_aim', 25.0)
end

function World.OnGunshot(src, pos)
    if throttled('shot|' .. src, 3) then return end
    if SC.Aware then SC.Aware.RecordIncident('gunshot', pos) end
    local cid = SC.Bridge.GetCitizenId(src)
    CreateThread(function()
        local now = os.time()
        for _, r in ipairs(Sim.List) do
            if r.enabled and r.status == 'alive' then
                local rp = SC.Spawner.GetPedCoords(r)
                local physical = rp ~= nil
                if not rp and Sim.GetSpawnInfo(r) then rp = Sim.GetPosition(r) end
                if rp then
                    local d = Utils.Dist(rp, pos)
                    if d <= (Config.World.GunshotRadius or 70.0) then
                        if physical then World.Flee(r, pos, src) end
                        local wkey = 'shot|' .. r.id
                        if not lastWitness[wkey] or now - lastWitness[wkey] > 60 then
                            lastWitness[wkey] = now
                            if physical and cid and d <= (Config.World.WitnessIdentifyRadius or 30.0) then
                                World.ApplyEvent(r, cid, 'gunshot_near', L('mem_shot_near', World.PlayerRef(r, cid, src)), { memType = 'witnessed' })
                                if math.random() < 0.5 then World.CallPolice(r, L('police_reason_shots'), src) end
                            else
                                World.ApplyEvent(r, nil, 'gunshot_witness', L('mem_heard_shots', World.NearestLabel(rp)), { memType = 'witnessed' })
                            end
                        end
                    end
                end
            end
        end
    end)
end

function World.OnHit(r, src, byVehicle)
    if throttled('hit|' .. src .. '|' .. r.id, 5) then return end
    lastDamage[r.id] = { src = src, at = os.time(), vehicle = byVehicle }
    local cid = SC.Bridge.GetCitizenId(src)
    local ppos = GetEntityCoords(GetPlayerPed(src))
    if r.override and r.override.type == 'hostage' then
        -- rehineye vurmak: kaçamaz ama unutmaz
        if cid then
            CreateThread(function() World.ApplyEvent(r, cid, 'assaulted', L('mem_assaulted', World.PlayerRef(r, cid, src))) end)
        end
        SC.Convo.Bubble(r, SC.Dialogue.Line('hostage_hurt', r, { stage = 'stranger' }), 'npc', 3500)
        return
    end
    if r.convo then SC.Convo.End(r, 'threat') end
    if SC.Aware and not byVehicle then SC.Aware.RecordIncident('fight', ppos) end
    -- saldırı/çarpma: süren eşlik ve etkileşim biter
    if r.interaction and SC.Interact then SC.Interact.Stop(r, 'threat') end
    if SC.NPC and SC.NPC.Companion(r) then SC.Companion.End(r, 'flee', { silent = true }) end
    SC.Convo.Bubble(r, SC.Actions.PickLine(byVehicle and 'scream_hit_vehicle' or 'scream_assault'), 'npc', 4000)
    World.Flee(r, ppos, src)
    if cid then
        CreateThread(function()
            local who = World.PlayerRef(r, cid, src)
            if byVehicle then
                World.ApplyEvent(r, cid, 'hit_by_vehicle', L('mem_hit_vehicle', who))
            else
                World.ApplyEvent(r, cid, 'assaulted', L('mem_assaulted', who))
                Wait(3000)
                World.CallPolice(r, L('police_reason_assault'), src)
            end
        end)
    end
    if not byVehicle then World.Witness(r.id, ppos, src, cid, 'mem_saw_assault', 20.0) end
end

function World.OnResidentDied(r)
    if r.status ~= 'alive' then return end
    if SC.Hostage then SC.Hostage.OnDied(r) end
    local dmg = lastDamage[r.id]
    local killerSrc = (dmg and os.time() - dmg.at <= 15) and dmg.src or nil
    local killerCid = killerSrc and SC.Bridge.GetCitizenId(killerSrc) or nil
    local pos = SC.Spawner.GetPedCoords(r)
    if r.convo then SC.Convo.End(r, 'dead') end
    SC.Log.Event(L('log_death_title'), ('%s %s (%s) %s'):format(r.firstname, r.lastname, r.id, killerCid and ('<- ' .. killerCid) or ''))
    if killerCid then
        CreateThread(function()
            World.ApplyEvent(r, killerCid, 'killed', L('mem_killed', World.PlayerRef(r, killerCid, killerSrc)))
        end)
        if pos then World.Witness(r.id, pos, killerSrc, killerCid, 'mem_saw_kill', 40.0) end
    else
        SC.Memory.AddAsync(r.id, nil, L('mem_hurt_unknown'), 8, 'event', { valence = -1 })
    end
    Sim.Hospitalize(r, L('log_died'))
end

function World.OnCarStolen(r, thiefSrc)
    if not r.car or r.car.missing then return end
    r.car.missing = true
    r.car.missingSince = os.time()
    r.dirty = true
    local cid = thiefSrc and SC.Bridge.GetCitizenId(thiefSrc) or nil
    local pedPos = SC.Spawner.GetPedCoords(r)
    local rec = SC.Spawner.vehicles[r.id]
    local vpos = rec and DoesEntityExist(rec.entity) and GetEntityCoords(rec.entity) or nil
    local witnessed = pedPos and vpos and Utils.Dist(pedPos, vpos) < 40.0
    if r.state.activity == 'commute' and r.state.mode == 'car' then
        r.state.mode = 'transit'
        if r.car then r.car.inUse = false end
        Sim.Changed(r, 'car_stolen')
    end
    CreateThread(function()
        if witnessed and cid then
            World.ApplyEvent(r, cid, 'car_stolen', L('mem_car_stolen_seen', World.PlayerRef(r, cid, thiefSrc)))
            SC.Convo.Bubble(r, SC.Actions.PickLine('scream_car'), 'npc', 4000)
            World.CallPolice(r, L('police_reason_car'), thiefSrc)
        else
            SC.Memory.Add(r.id, nil, L('mem_car_stolen_unknown'), 6, 'event', { valence = -1 })
            Sim.AddMoodEvent(r, -30, L('mood_reason_car'), 'car')
        end
    end)
end

-- ---------------------------------------------------------------------
-- İstemci raporları
-- ---------------------------------------------------------------------
local function playerArmed(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local w = GetSelectedPedWeapon(ped)
    return w ~= 0 and w ~= UNARMED
end

RegisterNetEvent('samy-citizens:server:worldEvent', function(kind, data)
    local src = source
    if type(kind) ~= 'string' then return end
    data = type(data) == 'table' and data or {}
    local pped = GetPlayerPed(src)
    if not pped or pped == 0 then return end
    local ppos = GetEntityCoords(pped)
    if kind == 'aim' then
        local r = SC.Spawner.GetResidentByNet(data.net)
        if not r or r.status ~= 'alive' or not playerArmed(src) then return end
        local near = SC.Spawner.PlayerNear(src, r, 50.0)
        if not near then return end
        World.OnAimed(r, src)
    elseif kind == 'shot' then
        if not playerArmed(src) then return end
        World.OnGunshot(src, ppos)
    elseif kind == 'hit' then
        local r = SC.Spawner.GetResidentByNet(data.net)
        if not r or r.status ~= 'alive' then return end
        local near = SC.Spawner.PlayerNear(src, r, 25.0)
        if not near then return end
        World.OnHit(r, src, data.vehicle == true)
    end
end)

AddEventHandler('explosionEvent', function(sender, ev)
    if type(ev) ~= 'table' or not ev.posX then return end
    local pos = vector3(ev.posX + 0.0, ev.posY + 0.0, ev.posZ + 0.0)
    local radius = Config.World.ExplosionRadius or 90.0
    if SC.Aware then SC.Aware.RecordIncident('explosion', pos) end
    local now = os.time()
    for _, r in ipairs(Sim.List) do
        if r.enabled and r.status == 'alive' then
            local rp = SC.Spawner.GetPedCoords(r)
            local physical = rp ~= nil
            if not rp and Sim.GetSpawnInfo(r) then rp = Sim.GetPosition(r) end
            if rp and Utils.Dist(rp, pos) <= radius then
                if physical then World.Flee(r, pos, nil) end
                local wkey = 'exp|' .. r.id
                if not lastWitness[wkey] or now - lastWitness[wkey] > 120 then
                    lastWitness[wkey] = now
                    World.ApplyEvent(r, nil, 'explosion', L('mem_explosion', World.NearestLabel(rp)), { memType = 'witnessed' })
                end
            end
        end
    end
end)
