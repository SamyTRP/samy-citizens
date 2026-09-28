--[[
    samy-citizens — sunucu giriş noktası
    Başlatma sırası: migrate -> tohumlama -> yükleme -> döngüler
]]
local Utils = SC.Utils
local Clock = SC.Clock
local Sim = SC.Sim

SC.Ready = false

local function loadYesterdaySummaries()
    local day = Clock.Day() - 1
    local rows = MySQL.query.await('SELECT npc_id, summary FROM samy_citizens_daily_log WHERE game_day = ?', { day }) or {}
    for _, row in ipairs(rows) do
        local r = Sim.Residents[row.npc_id]
        if r and row.summary and row.summary ~= '' then r.yesterdaySummary = row.summary end
    end
end

local function saveAll(all)
    local ok, err = pcall(function()
        SC.DB.SaveResidentStates(Sim.CollectSaves(all), false)
        SC.Rel.Flush(false)
        SC.Log.Flush()
    end)
    if not ok then print(('^1[samy-citizens] kayıt hatası: %s^7'):format(tostring(err))) end
end

local function loop(interval, fn, name)
    CreateThread(function()
        while true do
            local ok, err = pcall(fn)
            if not ok then print(('^1[samy-citizens] %s döngü hatası: %s^7'):format(name, tostring(err))) end
            Wait(interval)
        end
    end)
end

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do Wait(100) end
    local p = promise.new()
    MySQL.ready(function() p:resolve(true) end)
    Citizen.Await(p)

    if not SC.Bridge then
        print('^1[samy-citizens] Desteklenen framework bulunamadı (qbx_core / qb-core / es_extended). Config.Framework ayarını kontrol et.^7')
        return
    end
    if not SC.DB.Migrate() then return end
    SC.DB.EnsureColumns()
    SC.DB.Seed()

    Sim.Locations = SC.DB.LoadLocations()
    Sim.Routines = SC.DB.LoadRoutines()
    for _, data in ipairs(SC.DB.LoadResidents()) do Sim.AddResident(data) end
    Sim.currentDay = Clock.Day()
    Sim.lastTick = Clock.Now()
    loadYesterdaySummaries()
    SC.Appt.Load()
    SC.Social.Rebuild()
    SC.Social.LoadPool()
    SC.Phone.Rebuild()

    Sim.OnDayChange(function(prev)
        for _, r in ipairs(Sim.List) do
            if r.enabled then Sim.EndOfDay(r, prev) end
            -- gece: evdeki sakinin arabası başka yerde kaldıysa eve getirilmiş sayılır
            if r.car and not r.car.inUse and not r.car.missing and r.state and r.state.locationId == r.homeId
                and r.car.locationId ~= r.homeId and not SC.Spawner.vehicles[r.id] then
                r.car.locationId = r.homeId
            end
        end
        SC.Social.Nightly()
        SC.DebugPrint('yeni gün:', Clock.Describe())
    end)

    SC.Ready = true
    print(('^2[samy-citizens] hazır: %d sakin, %d konum, %d rutin | framework: %s | saat: %s (%s) | diyalog: kural tabanlı (%d niyet)^7'):format(
        #Sim.List, Utils.Count(Sim.Locations), Utils.Count(Sim.Routines), SC.Bridge.name, Clock.Describe(), Config.TimeMode,
        #SCDialogue.Intents + #(SCDialogue.Custom or {})))

    loop(Config.SimTickMs or 2000, function()
        Sim.Tick()
        SC.Social.Tick()
    end, 'sim')
    loop(Config.SpawnCheckMs or 1500, SC.Spawner.Tick, 'spawner')
    loop(1000, SC.Convo.Tick, 'konuşma')
    loop(1000, SC.Hostage.Tick, 'rehine')
    loop(1000, SC.Life.Tick, 'hayat')
    loop(2000, SC.Convo.AmbientTick, 'selam')
    loop(5000, SC.Appt.Tick, 'randevu')
    loop(Config.Phone.CheckIntervalMs or 8000, SC.Phone.Tick, 'telefon')
    CreateThread(function()
        while true do
            Wait(Config.SaveIntervalMs or 60000)
            saveAll(false)
            SC.Rel.PruneCache()
        end
    end)
    CreateThread(function()
        while true do
            Wait(3600000)
            local ok, err = pcall(SC.Memory.ForgetTick)
            if not ok then print(('^1[samy-citizens] unutma hatası: %s^7'):format(tostring(err))) end
        end
    end)
end)

-- ---------------------------------------------------------------------
-- Oyuncu ayrılma / çıkış
-- ---------------------------------------------------------------------
AddEventHandler('playerDropped', function()
    SC.Convo.OnPlayerLeft(source)
end)

CreateThread(function()
    while not SC.Bridge do Wait(500) end
    SC.Bridge.OnPlayerUnload(function(src)
        if src then SC.Convo.OnPlayerLeft(src) end
    end)
end)

-- ---------------------------------------------------------------------
-- Kapanış
-- ---------------------------------------------------------------------
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if SC.Ready then saveAll(true) end
    SC.Spawner.Shutdown()
end)

AddEventHandler('txAdmin:events:serverShuttingDown', function()
    if SC.Ready then saveAll(true) end
end)

-- ---------------------------------------------------------------------
-- Dışa aktarımlar (diğer kaynaklar için)
-- ---------------------------------------------------------------------
local function publicResident(r)
    local phys = SC.Spawner.peds[r.id]
    return {
        id = r.id, firstname = r.firstname, lastname = r.lastname, age = r.age, gender = r.gender,
        job = r.job, homeId = r.homeId, phone_number = r.phone_number, status = r.status,
        activity = r.state and r.state.activity, locationId = r.state and r.state.locationId,
        mood = math.floor(r.mood or 0), physical = phys ~= nil, netId = phys and phys.netId or nil,
    }
end

exports('GetResident', function(id)
    local r = Sim.Residents[id]
    return r and publicResident(r) or nil
end)

exports('GetResidents', function()
    local out = {}
    for _, r in ipairs(Sim.List) do out[#out + 1] = publicResident(r) end
    return out
end)

exports('GetResidentByEntity', function(entity)
    local r = SC.Spawner.GetResidentByEntity(entity)
    return r and publicResident(r) or nil
end)

exports('IsResidentEntity', function(entity)
    return SC.Spawner.GetResidentByEntity(entity) ~= nil
end)

-- Sakin şu an rehin mi? (rehin alan oyuncunun src'si ile)
exports('IsHostage', function(npcId)
    local r = Sim.Residents[npcId]
    if r and SC.Hostage.Is(r) then return true, r.override.taker end
    return false
end)

-- Oyun olayı bildir (örn. EMS sakini kurtardı: 'saved'). eventType Config.Events anahtarlarından biri
exports('ReportEvent', function(npcId, citizenid, eventType, text)
    local r = Sim.Residents[npcId]
    if not r or not Config.Events[eventType] then return false end
    SC.World.ApplyEvent(r, citizenid, eventType, text or L('mem_generic_event', eventType))
    return true
end)

exports('AddMemory', function(npcId, citizenid, text, importance, opts)
    if not Sim.Residents[npcId] or type(text) ~= 'string' then return false end
    opts = type(opts) == 'table' and opts or {}
    SC.Memory.AddAsync(npcId, citizenid, text, importance or 5, opts.type or 'event', opts)
    return true
end)

exports('ModifyRelationship', function(npcId, citizenid, dAffinity, dTrust)
    if not Sim.Residents[npcId] or type(citizenid) ~= 'string' then return false end
    CreateThread(function()
        local rel = SC.Rel.Get(npcId, citizenid)
        SC.Rel.ApplyDelta(rel, dAffinity or 0, dTrust or 0, { bypassCap = true })
    end)
    return true
end)

-- Önbellekteki ilişki (yoksa nil; tam veri için oyuncu en az bir kez etkileşmiş olmalı)
exports('GetRelationship', function(npcId, citizenid)
    local rel = SC.Rel.Peek(npcId, citizenid)
    return rel and SC.Rel.PublicView(rel) or nil
end)
