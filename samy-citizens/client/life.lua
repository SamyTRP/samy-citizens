--[[
    GÜNLÜK HAYAT — oyuncu tarafı
    - Karşılık hareketleri: sarılma, öpücük, çak bir beşlik; sipariş alınca içme / yeme / eşyayı alma
    - Hemşire / doktor tedavisi (can), tamircinin araç tamiri
    - Araba gezmesi: gezerken haritada yeni bir yer işaretlersen sakin oraya sürer
    Döngü sadece araba gezmesi sırasında (2 sn aralıkla) çalışır.
]]
local Life = { ride = nil }
SC.LifeClient = Life

local function loadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(dict)
end

local function attachProp(ped, model)
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local t = GetGameTimer() + 2000
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(10) end
    if not HasModelLoaded(hash) then return nil end
    local obj = CreateObject(hash, 0.0, 0.0, 0.0, true, true, false)
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, 18905), 0.12, 0.028, 0.001, 10.0, 175.0, 0.0, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(hash)
    return obj
end

-- Oyuncunun karşılık hareketi (npcNet: yüzünü döneceği sakin)
RegisterNetEvent('samy-citizens:client:playerAnim', function(name, npcNet)
    local an = SC.PlayerAnims and SC.PlayerAnims[name]
    if not an or IsPedInAnyVehicle(cache.ped, false) then return end
    CreateThread(function()
        if not loadDict(an.dict) then return end
        local ped = cache.ped
        if an.delay then Wait(an.delay) end
        if an.face and npcNet and NetworkDoesEntityExistWithNetworkId(npcNet) then
            TaskTurnPedToFaceEntity(ped, NetworkGetEntityFromNetworkId(npcNet), 600)
            Wait(600)
        end
        local prop = an.prop and attachProp(ped, an.prop) or nil
        TaskPlayAnim(ped, an.dict, an.anim, 4.0, -4.0, an.dur or 2500, an.flag or 0, 0.0, false, false, false)
        Wait(an.dur or 2500)
        if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
        RemoveAnimDict(an.dict)
    end)
end)

-- Tedavi: can yenilenir (isteğe bağlı sunucunun kendi ambulans script'inin event'i de tetiklenir)
RegisterNetEvent('samy-citizens:client:heal', function(amount, customEvent)
    local ped = cache.ped
    if IsEntityDead(ped) then return end
    local max = GetEntityMaxHealth(ped)
    local hp = math.min(max, GetEntityHealth(ped) + math.floor(tonumber(amount) or 40))
    SetEntityHealth(ped, hp)
    if hp >= max then ClearPedBloodDamage(ped) end
    if type(customEvent) == 'string' and customEvent ~= '' then TriggerEvent(customEvent) end
    lib.notify({ title = L('notify_title'), description = L('ui_healed'), type = 'success' })
end)

-- Tamir: aracın sahibi (genelde oyuncu) aracı onarır
RegisterNetEvent('samy-citizens:client:repairVehicle', function(net)
    if type(net) ~= 'number' or not NetworkDoesEntityExistWithNetworkId(net) then return end
    local veh = NetworkGetEntityFromNetworkId(net)
    if veh == 0 or not DoesEntityExist(veh) then return end
    local t = GetGameTimer() + 2000
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() < t do
        NetworkRequestControlOfEntity(veh)
        Wait(50)
    end
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleBodyHealth(veh, 1000.0)
    SetVehiclePetrolTankHealth(veh, 1000.0)
    SetVehicleUndriveable(veh, false)
end)

-- ---------------------------------------------------------------------
-- Araba gezmesi
-- ---------------------------------------------------------------------
local function waypoint()
    local blip = GetFirstBlipInfoId(8)
    if blip == 0 or not DoesBlipExist(blip) then return nil end
    return GetBlipInfoIdCoord(blip)
end

RegisterNetEvent('samy-citizens:client:rideState', function(data)
    if type(data) ~= 'table' then
        Life.ride = nil
        return
    end
    Life.ride = data
    local seq = (Life.rideSeq or 0) + 1
    Life.rideSeq = seq
    CreateThread(function()
        local last = waypoint()
        while Life.ride and Life.rideSeq == seq do
            Wait(2000)
            local wp = waypoint()
            if wp and (not last or #(vector2(wp.x, wp.y) - vector2(last.x, last.y)) > 5.0) then
                local found, gz = GetGroundZFor_3dCoord(wp.x, wp.y, 1000.0, false)
                TriggerServerEvent('samy-citizens:server:rideDest', wp.x + 0.0, wp.y + 0.0, found and gz or 0.0)
                lib.notify({ title = L('notify_title'), description = L('ui_ride_newdest', data.name or ''), type = 'inform' })
            end
            last = wp
        end
    end)
end)
