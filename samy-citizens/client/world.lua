--[[
    Dünya olaylarını algılama (sadece yerel oyuncunun kendi eylemleri raporlanır; sunucu doğrular)
    - Silahlıyken ve yakında sakin varken: nişan alma / ateş etme kontrolü
      (kare bazlı kontrol sadece bu durumda çalışır; normalde 1 sn uyku)
    - CEventNetworkEntityDamage: sakine çarpma / saldırı
]]
local lastAim = {}
local lastShot = 0
local lastHit = {}

local function residentNear(radius)
    local myPos = GetEntityCoords(cache.ped)
    local found = false
    SC.Client.ForEachResidentPed(function(ped)
        if not found and #(GetEntityCoords(ped) - myPos) <= radius then found = true end
    end)
    return found
end

CreateThread(function()
    while true do
        local ped = cache.ped
        if IsPedArmed(ped, 6) and residentNear(Config.World.GunshotRadius or 70.0) then
            local untilT = GetGameTimer() + 1000
            while GetGameTimer() < untilT do
                local now = GetGameTimer()
                if IsPlayerFreeAiming(cache.playerId) then
                    local ok, ent = GetEntityPlayerIsFreeAimingAt(cache.playerId)
                    if ok and ent and ent ~= 0 and SC.Client.IsResidentPed(ent) and not IsPedDeadOrDying(ent, true) then
                        if now > (lastAim[ent] or 0) then
                            lastAim[ent] = now + (Config.World.AimReportCooldownSec or 6) * 1000
                            TriggerServerEvent('samy-citizens:server:worldEvent', 'aim', { net = NetworkGetNetworkIdFromEntity(ent) })
                        end
                    end
                end
                if IsPedShooting(ped) and now > lastShot then
                    lastShot = now + 3000
                    TriggerServerEvent('samy-citizens:server:worldEvent', 'shot', {})
                end
                Wait(0)
            end
        else
            Wait(1000)
        end
    end
end)

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' or type(args) ~= 'table' then return end
    local victim, attacker = args[1], args[2]
    if not victim or victim == 0 or not DoesEntityExist(victim) then return end
    if not SC.Client.IsResidentPed(victim) then return end
    local myPed = cache.ped
    local myVeh = GetVehiclePedIsIn(myPed, false)
    local byVehicle
    if myVeh ~= 0 and attacker == myVeh then
        byVehicle = true
    elseif attacker == myPed then
        byVehicle = myVeh ~= 0 and GetPedInVehicleSeat(myVeh, -1) == myPed
    else
        return
    end
    local now = GetGameTimer()
    if now < (lastHit[victim] or 0) then return end
    lastHit[victim] = now + 5000
    TriggerServerEvent('samy-citizens:server:worldEvent', 'hit', { net = NetworkGetNetworkIdFromEntity(victim), vehicle = byVehicle })
end)

-- ps-dispatch uyarısı (sunucu bu istemciyi seçtiğinde)
RegisterNetEvent('samy-citizens:client:dispatch', function(data)
    if type(data) ~= 'table' or type(data.coords) ~= 'vector3' and type(data.coords) ~= 'table' then return end
    if GetResourceState('ps-dispatch') ~= 'started' then return end
    local c = data.coords
    local blip = data.blip or {}
    local ok, err = pcall(function()
        exports['ps-dispatch']:CustomAlert({
            coords = vector3(c.x + 0.0, c.y + 0.0, c.z + 0.0),
            message = data.title,
            dispatchCode = data.code,
            code = data.code,
            description = data.message,
            information = data.message,
            icon = 'fas fa-user-shield',
            priority = 2,
            sprite = blip.sprite or 280,
            color = blip.color or 1,
            scale = blip.scale or 1.0,
            length = blip.length or 2,
            radius = 0,
            jobs = data.jobs,
        })
    end)
    if not ok then print(('[samy-citizens] ps-dispatch hatası: %s'):format(tostring(err))) end
end)
