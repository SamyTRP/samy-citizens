--[[
    Yönetim paneli istemci tarafı: NUI <-> sunucu callback köprüsü, ışınlanma, harita işaretleri
    Tüm yetki kontrolleri sunucuda yapılır.
]]
local Utils = SC.Utils
local Admin = { open = false, blips = {}, blipsOn = false }
SC.AdminC = Admin

local ALLOWED = {
    overview = true, resident = true, saveResident = true, deleteResident = true, setStatus = true,
    locations = true, saveLocation = true, deleteLocation = true, routines = true, saveRoutine = true,
    deleteRoutine = true, previewPlan = true, memories = true, deleteMemory = true, resetRelationship = true,
    setRelationship = true, testDialogue = true, summon = true, generate = true, bootstrap = true,
}

RegisterNetEvent('samy-citizens:client:openAdmin', function()
    local boot, err = lib.callback.await('samy-citizens:admin:bootstrap', false)
    if not boot then
        lib.notify({ title = L('notify_title'), description = err or L('err_no_permission'), type = 'error' })
        return
    end
    Admin.open = true
    SendNUIMessage({ action = 'admin:open', bootstrap = boot })
    SC.Client.SetFocus('admin', true)
end)

local function teleport(x, y, z)
    local ped = cache.ped
    DoScreenFadeOut(250)
    Wait(260)
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoords(ped, x + 1.5, y, z + 0.5, false, false, false, false)
    local t = GetGameTimer() + 2500
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < t do Wait(0) end
    local found, gz = GetGroundZFor_3dCoord(x + 1.5, y, z + 5.0, false)
    if found then SetEntityCoords(ped, x + 1.5, y, gz, false, false, false, false) end
    DoScreenFadeIn(250)
end

function Admin.ClearBlips()
    for id, blip in pairs(Admin.blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        Admin.blips[id] = nil
    end
end

function Admin.UpdateBlips(list)
    local seen = {}
    for _, b in ipairs(list) do
        seen[b.id] = true
        local blip = Admin.blips[b.id]
        if not blip or not DoesBlipExist(blip) then
            blip = AddBlipForCoord(b.x + 0.0, b.y + 0.0, b.z + 0.0)
            SetBlipSprite(blip, 280)
            SetBlipScale(blip, 0.75)
            SetBlipAsShortRange(blip, false)
            Admin.blips[b.id] = blip
        else
            SetBlipCoords(blip, b.x + 0.0, b.y + 0.0, b.z + 0.0)
        end
        SetBlipColour(blip, b.physical and 2 or (b.commute and 5 or (b.inside and 40 or 3)))
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(Utils.Ascii(('%s - %s'):format(b.name, b.activity or '')))
        EndTextCommandSetBlipName(blip)
    end
    for id, blip in pairs(Admin.blips) do
        if not seen[id] then
            if DoesBlipExist(blip) then RemoveBlip(blip) end
            Admin.blips[id] = nil
        end
    end
end

function Admin.ToggleBlips()
    Admin.blipsOn = not Admin.blipsOn
    if not Admin.blipsOn then return end
    CreateThread(function()
        while Admin.blipsOn do
            local list = lib.callback.await('samy-citizens:admin:blips', false)
            if type(list) == 'table' and Admin.blipsOn then Admin.UpdateBlips(list) end
            Wait(Config.Admin.BlipRefreshMs or 5000)
        end
        Admin.ClearBlips()
    end)
end

RegisterNUICallback('admin', function(data, cb)
    if type(data) ~= 'table' or type(data.action) ~= 'string' then
        cb({ ok = false })
        return
    end
    local action = data.action
    if action == 'close' then
        Admin.open = false
        SC.Client.SetFocus('admin', false)
        cb({ ok = true })
    elseif action == 'myPosition' then
        local ped = cache.ped
        local veh = GetVehiclePedIsIn(ped, false)
        local ent = (data.payload == 'vehicle' and veh ~= 0) and veh or ped
        local c = GetEntityCoords(ent)
        cb({ ok = true, data = { x = Utils.Round(c.x, 2), y = Utils.Round(c.y, 2), z = Utils.Round(c.z, 2), w = Utils.Round(GetEntityHeading(ent), 1) } })
    elseif action == 'teleport' then
        local pos = lib.callback.await('samy-citizens:admin:teleport', false, data.payload)
        if type(pos) == 'table' and pos.x then teleport(pos.x + 0.0, pos.y + 0.0, pos.z + 0.0) end
        cb({ ok = type(pos) == 'table' })
    elseif action == 'teleportCoords' then
        local p = data.payload
        if type(p) == 'table' and tonumber(p.x) then teleport(tonumber(p.x) + 0.0, tonumber(p.y) + 0.0, tonumber(p.z) + 0.0) end
        cb({ ok = true })
    elseif action == 'toggleBlips' then
        Admin.ToggleBlips()
        cb({ ok = true, data = Admin.blipsOn })
    elseif action == 'validateModel' then
        local hash = GetHashKey(tostring(data.payload or ''))
        cb({ ok = true, data = IsModelInCdimage(hash) and IsModelAPed(hash) })
    elseif action == 'validateVehicle' then
        local hash = GetHashKey(tostring(data.payload or ''))
        cb({ ok = true, data = IsModelInCdimage(hash) and IsModelAVehicle(hash) })
    elseif ALLOWED[action] then
        local res, err = lib.callback.await('samy-citizens:admin:' .. action, false, data.payload)
        cb({ ok = res ~= false and res ~= nil, data = res, error = err })
    else
        cb({ ok = false })
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then Admin.ClearBlips() end
end)
