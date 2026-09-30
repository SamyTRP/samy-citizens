--[[
    MERKEZİ DURUM MAKİNESİ
    NPC'nin davranışı dağınık boolean'lar yerine tek bir duruma indirgenir:
      HOSTAGE > FLEEING > INTIMATE_INTERACTION > INTERACTING > TALKING > ENTERING_VEHICLE > IN_VEHICLE > DRIVING
      > DATE > FOLLOWING > WAITING > SOCIALIZING > GOING_TO_WORK / GOING_HOME > WALKING > WORKING > SLEEPING > IDLE
    Öncelikler Config.StateMachine.Priority'dedir. Yeni davranışlar (takip, araç, etkileşim) başlamadan önce
    State.CanEnter ile öncelik kontrolü yapar; yüksek öncelikli bir durum (ör. TALKING) sürerken rutin (WORKING,
    GOING_HOME...) NPC'yi götüremez (rutin motoru konuşma/override sırasında zaten beklemededir).
    Durum her değişiklikte (Sim.Changed / Spawner.UpdateTask) yeniden türetilir; değiştiyse ped statebag'ine yazılır.
]]
local Sim = SC.Sim

local State = {}
SC.State = State

local PRIO = Config.StateMachine and Config.StateMachine.Priority or {}

local SOCIAL_ACTS = { drink = true, coffee = true, eat = true, leisure = true, lunch_break = true, exercise = true,
    shopping = true, fish = true, entertain = true }
local WORK_ACTS = { work = true, study = true, deliver = true, entertain = true }

function State.Priority(state)
    return PRIO[state] or 0
end

-- Mevcut verilerden durumu türetir (yan etkisiz)
function State.Derive(r)
    if not r then return 'IDLE' end
    local ov = r.override
    if ov and ov.type == 'hostage' then return 'HOSTAGE' end
    if ov and (ov.type == 'flee' or ov.type == 'handsup' or ov.type == 'cower') then return 'FLEEING' end
    local it = r.interaction
    if it then return it.adult and 'INTIMATE_INTERACTION' or 'INTERACTING' end
    if ov and ov.type == 'companion' then
        local ph = ov.phase
        if r.convo and ph ~= 'ride' and ph ~= 'driving' then return 'TALKING' end
        if ph == 'enter' or ph == 'to_car' then return 'ENTERING_VEHICLE' end
        if ph == 'ride' then return 'IN_VEHICLE' end
        if ph == 'driving' or ph == 'wait_passenger' or ph == 'hold' then return 'DRIVING' end
        if ph == 'date' then return 'DATE' end
        if ph == 'wait' or ph == 'wait_car' then return 'WAITING' end
        return 'FOLLOWING'
    end
    if r.convo then return 'TALKING' end
    if ov then
        if ov.type == 'follow' then return 'FOLLOWING' end
        if ov.type == 'meet' then return 'DATE' end
        if ov.type == 'chat' then return 'SOCIALIZING' end
        if ov.type == 'summoned' then return 'WAITING' end
    end
    local st = r.state or {}
    local act = st.activity
    if act == 'commute' then
        if st.toLocationId and r.job and st.toLocationId == r.job.workplaceId then return 'GOING_TO_WORK' end
        if st.toLocationId and st.toLocationId == r.homeId then return 'GOING_HOME' end
        if st.mode == 'car' then return 'DRIVING' end
        return 'WALKING'
    end
    if act == 'sleep' then return 'SLEEPING' end
    if WORK_ACTS[act] then return 'WORKING' end
    if act == 'appointment' then return 'WAITING' end
    if SOCIAL_ACTS[act] then return 'SOCIALIZING' end
    return 'IDLE'
end

function State.Get(r)
    if not r then return 'IDLE' end
    if not r.fsm then State.Refresh(r) end
    return r.fsm and r.fsm.state or 'IDLE'
end

-- Yeni duruma geçilebilir mi? (mevcut durumdan daha düşük öncelikli bir istek reddedilir)
function State.CanEnter(r, target, allowEqual)
    local cur = State.Derive(r)
    if cur == target then return true, cur end
    local a, b = State.Priority(target), State.Priority(cur)
    if a > b or (allowEqual and a == b) then return true, cur end
    -- konuşma sırasında başlatılan takip/araç/etkileşim konuşmayı bitirerek başlar
    if cur == 'TALKING' and a >= State.Priority('WAITING') then return true, cur end
    return false, cur
end

function State.Refresh(r, reason)
    if not r then return end
    local new = State.Derive(r)
    local fsm = r.fsm
    if fsm and fsm.state == new then return new end
    local old = fsm and fsm.state or nil
    r.fsm = { state = new, since = os.time(), prev = old, reason = reason }
    if Config.StateMachine and Config.StateMachine.Publish ~= false and SC.Spawner then
        local ped = SC.Spawner.GetPed(r)
        if ped then Entity(ped).state:set('scState', new, true) end
    end
    if Config.Debug then
        SC.DebugPrint(('durum %s: %s -> %s (%s)'):format(r.id, tostring(old), new, tostring(reason)))
    end
    return new
end
