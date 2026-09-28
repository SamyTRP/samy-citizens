--[[
    REHİNE ALMA — rehin alan oyuncu tarafı
    - Silahlıyken bir sakine yakından nişan alıp [E] ya da ox_target "Rehin al"
    - Rehin tutarken: [G] bırak · [H] kalkan / yürüt · [J] diz çöktür · [K] yakındaki araca bindir / indir
    Rehinenin kendi hareketlerini ped'in network sahibi istemci uygular (client/tasks.lua); sunucu her şeyi doğrular.
    Kare bazlı döngü sadece "kalkan" modunda çalışır (animasyon + koşma/zıplama/ateş engeli).
]]
local C = Config.Hostage or {}
local H = { active = nil }
SC.HostageClient = H
if not C.Enabled then return end

local KEYS = C.Keys or {}
local PERP_DICT, PERP_ANIM = 'anim@gangops@hostage@', 'perp_idle'
-- kalkan modunda engellenen tuşlar: koşma, zıplama, araca binme, ateş/nişan, siper, yakın dövüş, silah çarkı
local BLOCK = { 21, 22, 23, 24, 25, 37, 44, 47, 58, 140, 141, 142, 143, 257, 263, 264 }

local function armed()
    return IsPedArmed(cache.ped, C.AllowMelee and 5 or 4)
end

local function helpText()
    return table.concat({
        ('[%s] %s'):format(KEYS.release or 'G', L('hostage_key_release')),
        ('[%s] %s'):format(KEYS.mode or 'H', L('hostage_key_mode')),
        ('[%s] %s'):format(KEYS.kneel or 'J', L('hostage_key_kneel')),
        ('[%s] %s'):format(KEYS.vehicle or 'K', L('hostage_key_vehicle')),
    }, '  \n')
end

local function npcEntity()
    local a = H.active
    if not a or not a.net or not NetworkDoesEntityExistWithNetworkId(a.net) then return 0 end
    return NetworkGetEntityFromNetworkId(a.net)
end

local function holdLoop()
    CreateThread(function()
        lib.requestAnimDict(PERP_DICT)
        local npc = npcEntity()
        if npc ~= 0 then
            -- rehineyi yakın tutan istemci biz olalım ki bağlama akıcı olsun
            local untilT = GetGameTimer() + 1500
            while not NetworkHasControlOfEntity(npc) and GetGameTimer() < untilT do
                NetworkRequestControlOfEntity(npc)
                Wait(50)
            end
        end
        while H.active and H.active.mode == 'hold' do
            local ped = cache.ped
            if not IsEntityPlayingAnim(ped, PERP_DICT, PERP_ANIM, 3) then
                TaskPlayAnim(ped, PERP_DICT, PERP_ANIM, 8.0, -8.0, -1, 49, 0.0, false, false, false)
            end
            for i = 1, #BLOCK do DisableControlAction(0, BLOCK[i], true) end
            Wait(0)
        end
        StopAnimTask(cache.ped, PERP_DICT, PERP_ANIM, 1.0)
        RemoveAnimDict(PERP_DICT)
    end)
end

local function shove()
    CreateThread(function()
        local dict = lib.requestAnimDict('reaction@shove')
        if dict then
            TaskPlayAnim(cache.ped, dict, 'shove_var_a', 8.0, -8.0, 1200, 48, 0.0, false, false, false)
            RemoveAnimDict(dict)
        end
    end)
end

RegisterNetEvent('samy-citizens:client:hostageState', function(data, reason)
    local prev = H.active
    if type(data) == 'table' and data.net then
        H.active = { net = data.net, mode = data.mode }
        lib.showTextUI(helpText(), { position = 'left-center', icon = 'user-lock' })
        if data.mode == 'hold' and not (prev and prev.mode == 'hold') then holdLoop() end
    else
        H.active = nil
        lib.hideTextUI()
        if prev and prev.mode == 'hold' and reason == 'released' then shove() end
        if reason and reason ~= 'released' and reason ~= 'shutdown' then
            local key = 'hostage_end_' .. tostring(reason)
            local msg = L(key)
            if msg ~= key then lib.notify({ title = L('notify_title'), description = msg, type = 'error' }) end
        end
    end
end)

-- ---------------------------------------------------------------------
-- Tuşlar (oyuncu GTA ayarlarından değiştirebilir)
-- ---------------------------------------------------------------------
local function aimedResident()
    if not IsPlayerFreeAiming(cache.playerId) then return nil end
    local ok, ent = GetEntityPlayerIsFreeAimingAt(cache.playerId)
    if not ok or not ent or ent == 0 or not SC.Client.IsResidentPed(ent) or IsPedDeadOrDying(ent, true) then return nil end
    if IsPedInAnyVehicle(ent, false) or Entity(ent).state.scHostage then return nil end
    if #(GetEntityCoords(ent) - GetEntityCoords(cache.ped)) > (C.TakeDistance or 2.0) + 0.5 then return nil end
    return ent
end

function H.Take(ent)
    if H.active or not ent or IsPedInAnyVehicle(cache.ped, false) or not armed() then return end
    TriggerServerEvent('samy-citizens:server:hostageTake', NetworkGetNetworkIdFromEntity(ent))
end

lib.addKeybind({
    name = 'samy_hostage_take',
    description = L('keybind_hostage_take'),
    defaultKey = KEYS.take or 'E',
    onPressed = function()
        if H.active then return end
        local ent = aimedResident()
        if ent then H.Take(ent) end
    end,
})

lib.addKeybind({
    name = 'samy_hostage_release',
    description = L('keybind_hostage_release'),
    defaultKey = KEYS.release or 'G',
    onPressed = function()
        if H.active then TriggerServerEvent('samy-citizens:server:hostageRelease') end
    end,
})

lib.addKeybind({
    name = 'samy_hostage_mode',
    description = L('keybind_hostage_mode'),
    defaultKey = KEYS.mode or 'H',
    onPressed = function()
        if not H.active then return end
        TriggerServerEvent('samy-citizens:server:hostageMode', H.active.mode == 'hold' and 'escort' or 'hold')
    end,
})

lib.addKeybind({
    name = 'samy_hostage_kneel',
    description = L('keybind_hostage_kneel'),
    defaultKey = KEYS.kneel or 'J',
    onPressed = function()
        if not H.active then return end
        TriggerServerEvent('samy-citizens:server:hostageMode', H.active.mode == 'kneel' and 'escort' or 'kneel')
    end,
})

-- en yakın araçta boş bir yolcu koltuğu (önce arka koltuklar)
local function freeSeat(veh)
    local seats = GetVehicleModelNumberOfSeats(GetEntityModel(veh))
    for _, seat in ipairs({ 1, 2, 0 }) do
        if seat <= seats - 2 and IsVehicleSeatFree(veh, seat) then return seat end
    end
    return nil
end

lib.addKeybind({
    name = 'samy_hostage_vehicle',
    description = L('keybind_hostage_vehicle'),
    defaultKey = KEYS.vehicle or 'K',
    onPressed = function()
        if not H.active then return end
        if H.active.mode == 'vehicle' then
            if IsPedInAnyVehicle(cache.ped, false) then
                return lib.notify({ title = L('notify_title'), description = L('hostage_exit_first'), type = 'error' })
            end
            return TriggerServerEvent('samy-citizens:server:hostageMode', 'escort')
        end
        local veh = lib.getClosestVehicle(GetEntityCoords(cache.ped), 8.0, true)
        if not veh or not NetworkGetEntityIsNetworked(veh) then
            return lib.notify({ title = L('notify_title'), description = L('hostage_no_vehicle'), type = 'error' })
        end
        local seat = freeSeat(veh)
        if not seat then
            return lib.notify({ title = L('notify_title'), description = L('hostage_seat_taken'), type = 'error' })
        end
        TriggerServerEvent('samy-citizens:server:hostageMode', 'vehicle', NetworkGetNetworkIdFromEntity(veh), seat)
    end,
})

-- Nişan alırken ipucu: "[E] Rehin al" (sadece silahlıyken; aksi hâlde 1 sn uyku)
CreateThread(function()
    local shown = false
    while true do
        local wait = 1000
        if not H.active and armed() and not IsPedInAnyVehicle(cache.ped, false) then
            wait = 250
            local ent = aimedResident()
            if ent and not shown then
                lib.showTextUI(L('hostage_take_hint', KEYS.take or 'E'), { position = 'left-center', icon = 'user-lock' })
                shown = true
            elseif not ent and shown then
                lib.hideTextUI()
                shown = false
            end
        elseif shown and not H.active then
            lib.hideTextUI()
            shown = false
        elseif H.active then
            shown = false
        end
        Wait(wait)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if H.active then
        StopAnimTask(cache.ped, PERP_DICT, PERP_ANIM, 1.0)
        lib.hideTextUI()
        H.active = nil
    end
end)
