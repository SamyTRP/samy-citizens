--[[
    ETKİLEŞİM ANİMASYONLARI (sosyal + yetişkin) — sunucu yetkilidir
    Akış:
      1) Oyuncu menüden ya da sözle ("Sarılalım mı?") ister -> Interact.Evaluate: mesafe, araç, durum önceliği,
         ilişki/romantizm şartı, kişilik kararı; yetişkin etkileşimlerde ayrıca SC.Adult kuralları (rıza, bölge, gizlilik)
      2) Start: r.interaction = { id, src, phase = 'align' } -> NPC'nin sahibi istemci NPC'yi oyuncuya göre
         hizalar (Config offset: ileri/yan/açı; iç içe girmesinler), hazır olunca 'int_ready' bildirir
      3) Play: iki tarafa aynı anda "oynat" gider (NPC: statebag, oyuncu: istemci olayı)
      4) Süre dolunca / oyuncu iptal edince / uzaklaşınca Stop; XP, anı (yetişkinde özel, paylaşılmaz), tepki cümlesi
    Etkileşim sürerken NPC'nin durumu INTERACTING / INTIMATE_INTERACTION'dır; rutin ve eşlik bekler.
]]
local Utils = SC.Utils
local Sim = SC.Sim
local NPC = SC.NPC

local Interact = {}
SC.Interact = Interact

Interact.active = {}   -- residentId -> true (tek merkezi durum r.interaction'da; bu sadece tick dizini)
local lastStart = {}

local function AN() return Config.Animation or {} end

function Interact.Def(id)
    if type(id) ~= 'string' then return nil end
    local d = AN().Social and AN().Social[id]
    if d then return d, false end
    if Config.AdultNPC and Config.AdultNPC.Enabled then
        d = Config.AdultAnimations and Config.AdultAnimations[id]
        if d then return d, true end
    end
    return nil
end

local function romanceOk(r, rel)
    if rel.romance and rel.romance ~= 'none' then return true end
    -- romantik kişilikli yakın arkadaş da kabul edebilir
    return SC.StageAtLeast(rel.stage, 'close_friend') and SC.Persona.Stats(r).romantic >= 60
end

--[[
    dönüş: ok, sebep
    sebep: unknown | far | vehicle | busy | stage | romance | state | cold | mood | tired | adult | zone | privacy | female | cooldown | default
]]
function Interact.Evaluate(r, rel, src, id, skipDecision)
    local def, adult = Interact.Def(id)
    if not def then return false, 'unknown' end
    if not r or r.status ~= 'alive' or not r.enabled then return false, 'default' end
    local ped = NPC.Ped(r)
    local pped = NPC.PlayerPed(src)
    if not ped or not pped then return false, 'default' end
    if SC.Hostage.Is(r) then return false, 'state' end
    if rel.stage == 'enemy' or rel.stage == 'cold' then return false, 'cold' end
    local d = Utils.Dist(GetEntityCoords(ped), GetEntityCoords(pped))
    local nveh = GetVehiclePedIsIn(ped, false)
    local pveh = GetVehiclePedIsIn(pped, false)
    if def.vehicle then
        if nveh == 0 or pveh == 0 or nveh ~= pveh then return false, 'vehicle' end
        local okV, vel = pcall(function() return GetEntityVelocity(pveh) end)
        if okV and vel and math.sqrt(vel.x * vel.x + vel.y * vel.y) > 1.0 then return false, 'vehicle' end
    else
        if nveh ~= 0 or pveh ~= 0 then return false, 'vehicle' end
        if d > (AN().MaxDistance or 3.5) and not def.pole then return false, 'far' end
        if def.pole and d > 20.0 then return false, 'far' end
    end
    if r.interaction and r.interaction.src ~= src then return false, 'state' end
    local okState = SC.State.CanEnter(r, adult and 'INTIMATE_INTERACTION' or 'INTERACTING', true)
    if not okState and not r.interaction then return false, 'state' end
    if def.minStage and not SC.StageAtLeast(rel.stage, def.minStage) and (rel.romance or 'none') == 'none' then return false, 'stage' end
    if def.romance and not romanceOk(r, rel) then return false, 'romance' end
    if adult then return SC.Adult.CanUse(r, src, id, def, rel, skipDecision) end
    if skipDecision then return true end
    local ok, reason = SC.Persona.Decide(r, rel, def.rule or 'touch', { cid = rel.citizenid, sub = id })
    if not ok then return false, reason end
    return true
end

local REFUSE_KEYS = { romance = 'romance', vehicle = 'vehicle', busy = 'busy' }

function Interact.Start(r, src, id, opts)
    opts = opts or {}
    local cid = SC.Bridge.GetCitizenId(src)
    if not cid or not r then return false end
    local now = GetGameTimer()
    local lk = src .. '|' .. r.id
    if lastStart[lk] and now - lastStart[lk] < 1500 then return false end
    lastStart[lk] = now
    local rel = SC.Rel.Get(r.id, cid)
    local def, adult = Interact.Def(id)
    local ok, why = Interact.Evaluate(r, rel, src, id, opts.decided)
    if not ok then
        if def then
            local key = adult and 'intimate_refuse' or 'touch_refuse'
            local sub = adult and ((why == 'privacy' or why == 'vehicle') and why or nil) or REFUSE_KEYS[why]
            SC.Convo.Bubble(r, SC.Dialogue.Line(key, r, rel, sub), 'npc', 4000)
        end
        TriggerClientEvent('samy-citizens:client:notify', src, L('interact_refused_' .. tostring(why)), 'error')
        return false, why
    end
    if r.interaction then Interact.Stop(r, 'replaced') end
    local spec = {
        id = id, src = src, cid = cid, adult = adult, phase = 'align', startedAt = now,
        untilMs = now + (AN().AlignTimeoutMs or 6000) + 1500,
    }
    if def.pole then
        local p = SC.Adult.PolePos(r)
        if p then spec.pos = { x = p.x, y = p.y, z = p.z, h = p.w or 0.0 } end
    end
    r.interaction = spec
    Interact.active[r.id] = true
    SC.Spawner.UpdateTask(r)
    if adult then
        SC.Convo.Bubble(r, SC.Dialogue.Line('intimate_accept', r, rel), 'npc', 3500)
    end
    TriggerClientEvent('samy-citizens:client:interactionStart', src, { id = id, net = NPC.NetId(r), adult = adult })
    if def.romance or adult then SC.RelXP.JealousyCheck(src, cid, r, 'interaction') end
    return true
end

function Interact.Play(r)
    local it = r.interaction
    if not it or it.phase == 'play' then return end
    local def = Interact.Def(it.id)
    if not def then return Interact.Stop(r, 'invalid') end
    it.phase = 'play'
    local dur = tonumber(def.duration) or 4000
    if def.loop then dur = math.min(dur, (AN().MaxLoopSeconds or 30) * 1000) end
    if it.adult then dur = math.min(dur, ((Config.AdultNPC and Config.AdultNPC.MaxDurationSec) or 45) * 1000) end
    it.untilMs = GetGameTimer() + dur
    SC.Spawner.UpdateTask(r)
    TriggerClientEvent('samy-citizens:client:interactionPlay', it.src, { id = it.id, net = NPC.NetId(r), adult = it.adult })
end

function Interact.Stop(r, reason)
    local it = r.interaction
    if not it then return end
    r.interaction = nil
    Interact.active[r.id] = nil
    if SC.Spawner.GetPed(r) then SC.Spawner.UpdateTask(r) end
    SC.State.Refresh(r, 'interaction_end')
    if GetPlayerName(it.src) then
        TriggerClientEvent('samy-citizens:client:interactionStop', it.src, { reason = reason, id = it.id })
    end
    if reason ~= 'done' then return end
    -- ödül: XP, ruh hâli, tepki; yetişkin etkileşimde özel (paylaşılmayan) anı
    local def = Interact.Def(it.id) or {}
    local rel = SC.Rel.Peek(r.id, it.cid)
    if rel then
        SC.RelXP.Add(rel, def.xp or (it.adult and 'intimate' or 'interaction'), { r = r, src = it.src })
        SC.Context.AddMoodTowards(r.id, it.cid, 8, 20)
        if def.memory and it.adult then
            SC.Memory.AddAsync(r.id, it.cid, L('mem_intimate', rel.char_name or L('ctx_someone')), 6, 'event',
                { valence = 1, shareable = false, data = { code = 'intimate' } })
        end
    end
    local lines = SCDialogue.InteractLines and SCDialogue.InteractLines[it.id]
    if lines and #lines > 0 then
        local line = lines[math.random(#lines)]
        if line ~= '...' then SC.Convo.Bubble(r, line, 'npc', 3500) end
    end
    SC.Spawner.SetEmotion(r, 'happy')
end

function Interact.OnTaskEvent(r, event, data)
    if event == 'int_ready' and r.interaction and r.interaction.phase == 'align' then Interact.Play(r) end
end

-- 1 sn
function Interact.Tick()
    local now = GetGameTimer()
    for rid in pairs(Interact.active) do
        local r = Sim.Residents[rid]
        local it = r and r.interaction
        if not it then
            Interact.active[rid] = nil
        else
            local ok, err = pcall(function()
                if not GetPlayerName(it.src) then return Interact.Stop(r, 'dropped') end
                if not SC.Spawner.GetPed(r) or r.status ~= 'alive' then return Interact.Stop(r, 'despawn') end
                if SC.Hostage.Is(r) or (r.override and r.override.type == 'flee') then return Interact.Stop(r, 'threat') end
                local def = Interact.Def(it.id)
                local d = NPC.DistanceToPlayer(r, it.src)
                local maxD = (def and def.pole) and 25.0 or 8.0
                if d > maxD then return Interact.Stop(r, 'distance') end
                if it.phase == 'align' and now >= it.untilMs then return Interact.Play(r) end
                if it.phase == 'play' and now >= it.untilMs then return Interact.Stop(r, 'done') end
            end)
            if not ok then
                print(('^1[samy-citizens] etkileşim hatası (%s): %s^7'):format(rid, tostring(err)))
                r.interaction = nil
                Interact.active[rid] = nil
            end
        end
    end
end

function Interact.BuildTask(r, it)
    return { kind = 'interact', id = it.id, target = it.src, phase = it.phase, adult = it.adult or nil, pos = it.pos }
end

function Interact.OnPlayerLeft(src)
    for rid in pairs(Interact.active) do
        local r = Sim.Residents[rid]
        if r and r.interaction and r.interaction.src == src then Interact.Stop(r, 'dropped') end
    end
    for k in pairs(lastStart) do
        if k:find('^' .. src .. '|') then lastStart[k] = nil end
    end
end

-- Oyuncu iptal etti (X tuşu / menü)
RegisterNetEvent('samy-citizens:server:interactionCancel', function()
    local src = source
    for rid in pairs(Interact.active) do
        local r = Sim.Residents[rid]
        if r and r.interaction and r.interaction.src == src then
            -- en az oynatma aşamasına geldiyse "tamamlandı" sayılır
            Interact.Stop(r, r.interaction.phase == 'play' and 'done' or 'cancel')
        end
    end
end)
