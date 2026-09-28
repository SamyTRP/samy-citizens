--[[
    samy-citizens — istemci giriş noktası
    Boşta resmon hedefi < 0.05 ms: her karede çalışan döngü yok; sahiplik döngüsü 1 sn,
    ox_target canInteract sadece nişan alınca değerlendirilir.
]]
local Utils = SC.Utils
local Client = {}
SC.Client = Client

Client.nuiOwner = nil

-- Tek NUI sayfası birden çok arayüz barındırır (konuşma / admin / telefon)
function Client.SetFocus(owner, state)
    if state then
        Client.nuiOwner = owner
        SetNuiFocus(true, true)
    elseif Client.nuiOwner == owner or owner == nil then
        Client.nuiOwner = nil
        SetNuiFocus(false, false)
    end
end

function Client.IsResidentPed(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) or not IsEntityAPed(ent) then return false end
    if not NetworkGetEntityIsNetworked(ent) then return false end
    return Entity(ent).state.scId ~= nil
end

-- Kayıt defteri: GlobalState.scPeds = { [netId] = residentId }
function Client.ForEachResidentPed(fn)
    local reg = GlobalState.scPeds
    if type(reg) ~= 'table' then return end
    for netStr, rid in pairs(reg) do
        local netId = tonumber(netStr)
        if netId and NetworkDoesEntityExistWithNetworkId(netId) then
            local ped = NetworkGetEntityFromNetworkId(netId)
            if ped ~= 0 and DoesEntityExist(ped) then fn(ped, netId, rid) end
        end
    end
end

-- ---------------------------------------------------------------------
-- Sunucu -> istemci yardımcı olaylar
-- ---------------------------------------------------------------------
RegisterNetEvent('samy-citizens:client:notify', function(msg, ntype)
    lib.notify({ title = L('notify_title'), description = msg, type = ntype or 'inform', duration = 7000 })
end)

RegisterNetEvent('samy-citizens:client:waypoint', function(x, y, label)
    if type(x) ~= 'number' or type(y) ~= 'number' then return end
    SetNewWaypoint(x + 0.0, y + 0.0)
    lib.notify({ title = L('notify_title'), description = L('notify_waypoint', label or ''), type = 'inform' })
end)

-- ---------------------------------------------------------------------
-- Sunucunun konum düzeltme istekleri (spawn öncesi zemine/yola/navmesh'e oturtma)
-- ---------------------------------------------------------------------
lib.callback.register('samy-citizens:snap', function(req)
    if type(req) ~= 'table' or type(req.x) ~= 'number' then return nil end
    local x, y, z = req.x + 0.0, req.y + 0.0, req.z + 0.0
    if req.mode == 'road' then
        local ok, pos, heading = GetClosestVehicleNodeWithHeading(x, y, z, 1, 3.0, 0)
        if ok and pos then
            if type(req.dx) == 'number' and type(req.dy) == 'number' then
                local rad = math.rad(heading)
                local fx, fy = -math.sin(rad), math.cos(rad)
                if fx * (req.dx - pos.x) + fy * (req.dy - pos.y) < 0 then heading = (heading + 180.0) % 360.0 end
            end
            return { x = pos.x, y = pos.y, z = pos.z, h = heading }
        end
        return nil
    elseif req.mode == 'ped' then
        local ok, safe = GetSafeCoordForPed(x, y, z, true, 16)
        if ok and safe then return { x = safe.x, y = safe.y, z = safe.z } end
    end
    local found, gz = GetGroundZFor_3dCoord(x, y, z + 2.0, false)
    if found and math.abs(gz - z) < 6.0 then return { x = x, y = y, z = gz } end
    return { x = x, y = y, z = z }
end)

-- Sunucunun saat/hava örneklemesi
local weatherByHash = {}
for _, n in ipairs({ 'CLEAR', 'EXTRASUNNY', 'CLOUDS', 'OVERCAST', 'RAIN', 'CLEARING', 'THUNDER', 'SMOG', 'FOGGY', 'XMAS', 'SNOW', 'SNOWLIGHT', 'BLIZZARD', 'HALLOWEEN', 'NEUTRAL' }) do
    local h = GetHashKey(n)
    weatherByHash[h] = n
    weatherByHash[h & 0xFFFFFFFF] = n
    if (h & 0xFFFFFFFF) >= 0x80000000 then weatherByHash[(h & 0xFFFFFFFF) - 0x100000000] = n end
end

lib.callback.register('samy-citizens:sampleWorld', function()
    local wh = GetPrevWeatherTypeHashName()
    return { h = GetClockHours(), m = GetClockMinutes(), w = weatherByHash[wh] or 'CLEAR' }
end)

-- ---------------------------------------------------------------------
-- Yüz ifadesi (tüm istemciler; yerel efekt)
-- ---------------------------------------------------------------------
AddStateBagChangeHandler('scEmo', nil, function(bagName, _, value)
    local ent = GetEntityFromStateBagName(bagName)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    local mood = SC.Emotions[value]
    if mood then SetFacialIdleAnimOverride(ent, mood, 0) end
end)

-- ---------------------------------------------------------------------
-- ox_target
-- ---------------------------------------------------------------------
CreateThread(function()
    while GetResourceState('ox_target') ~= 'started' do Wait(500) end
    exports.ox_target:addGlobalPed({
        {
            name = 'samy_citizens_talk',
            icon = 'fa-solid fa-comments',
            label = L('target_talk'),
            distance = Config.Conversation.StartDistance or 3.0,
            canInteract = function(entity)
                if not Client.IsResidentPed(entity) or IsPedDeadOrDying(entity, true) then return false end
                -- rehineyle sadece onu tutan konuşabilir
                local holder = Entity(entity).state.scHostage
                if holder then return holder == cache.serverId and not (SC.ConvoUI and SC.ConvoUI.active) end
                return not (SC.ConvoUI and SC.ConvoUI.active)
                    and (Config.Conversation.AllowWhileDriving or not IsPedInAnyVehicle(entity, false))
            end,
            onSelect = function(data)
                SC.ConvoUI.Start(data.entity)
            end,
        },
        {
            name = 'samy_citizens_hostage',
            icon = 'fa-solid fa-user-lock',
            label = L('target_hostage'),
            distance = (Config.Hostage and Config.Hostage.TakeDistance) or 2.0,
            canInteract = function(entity)
                local H = SC.HostageClient
                return Config.Hostage and Config.Hostage.Enabled and H and not H.active
                    and Client.IsResidentPed(entity) and not IsPedDeadOrDying(entity, true)
                    and not IsPedInAnyVehicle(entity, false) and not IsPedInAnyVehicle(cache.ped, false)
                    and not Entity(entity).state.scHostage
                    and IsPedArmed(cache.ped, Config.Hostage.AllowMelee and 5 or 4)
            end,
            onSelect = function(data)
                SC.HostageClient.Take(data.entity)
            end,
        },
        {
            name = 'samy_citizens_gift',
            icon = 'fa-solid fa-gift',
            label = L('target_gift'),
            distance = 2.5,
            canInteract = function(entity)
                return Config.Gifts.Enabled and GetResourceState('ox_inventory') == 'started'
                    and Client.IsResidentPed(entity) and not IsPedDeadOrDying(entity, true)
            end,
            onSelect = function(data)
                Client.OpenGiftMenu(data.entity)
            end,
        },
    })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if GetResourceState('ox_target') == 'started' then
        exports.ox_target:removeGlobalPed({ 'samy_citizens_talk', 'samy_citizens_hostage', 'samy_citizens_gift' })
    end
    SetNuiFocus(false, false)
end)

-- ---------------------------------------------------------------------
-- Hediye menüsü
-- ---------------------------------------------------------------------
function Client.OpenGiftMenu(entity)
    local netId = NetworkGetNetworkIdFromEntity(entity)
    local items = lib.callback.await('samy-citizens:getGiftItems', false, netId)
    if not items or #items == 0 then
        lib.notify({ title = L('notify_title'), description = L('gift_none'), type = 'error' })
        return
    end
    local options = {}
    for _, it in ipairs(items) do
        options[#options + 1] = {
            title = it.label,
            description = ('x%d'):format(it.count or 1),
            icon = 'gift',
            onSelect = function()
                local ok = lib.callback.await('samy-citizens:giveGift', false, netId, it.name)
                if ok then
                    lib.requestAnimDict('mp_common')
                    TaskPlayAnim(cache.ped, 'mp_common', 'givetake1_a', 8.0, -8.0, 1500, 48, 0.0, false, false, false)
                    RemoveAnimDict('mp_common')
                end
                lib.notify({ title = L('notify_title'), description = ok and L('gift_given', it.label) or L('gift_failed'), type = ok and 'success' or 'error' })
            end,
        }
    end
    lib.registerContext({ id = 'samy_citizens_gift', title = L('gift_title'), options = options })
    lib.showContext('samy_citizens_gift')
end
