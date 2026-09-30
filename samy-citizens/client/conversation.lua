--[[
    Konuşma paneli (NUI) + 3D konuşma baloncukları
    Baloncuk konum güncellemesi sadece aktif baloncuk varken her karede yapılır.
]]
local ConvoUI = { active = false }
SC.ConvoUI = ConvoUI

-- NUI ilk yüklendiğinde metinleri ve ayarları ister
RegisterNUICallback('ui:ready', function(_, cb)
    cb({
        strings = LT('ui') or {},
        locale = Config.Locale,
        maxChars = Config.RateLimit.MaxChars,
        focusKey = 'Y',
    })
end)

function ConvoUI.Close()
    if not ConvoUI.active then return end
    ConvoUI.active = false
    ConvoUI.entity = nil
    SendNUIMessage({ action = 'convo:close' })
    SC.Client.SetFocus('convo', false)
end

function ConvoUI.Stop(notifyServer)
    if notifyServer then TriggerServerEvent('samy-citizens:server:endConversation') end
    ConvoUI.Close()
end

function ConvoUI.Start(entity)
    if ConvoUI.active or ConvoUI.starting then return end
    ConvoUI.starting = true
    local netId = NetworkGetNetworkIdFromEntity(entity)
    local res, err = lib.callback.await('samy-citizens:startConversation', false, netId)
    ConvoUI.starting = false
    if not res then
        lib.notify({ title = L('notify_title'), description = err or L('err_generic'), type = 'error' })
        return
    end
    ConvoUI.active = true
    ConvoUI.netId = netId
    ConvoUI.npcId = res.npcId
    ConvoUI.entity = entity
    TaskTurnPedToFaceEntity(cache.ped, entity, 1200)
    SendNUIMessage({ action = 'convo:open', data = res })
    SC.Client.SetFocus('convo', true)

    CreateThread(function()
        while ConvoUI.active do
            Wait(500)
            if not ConvoUI.active then break end
            if IsEntityDead(cache.ped) then
                ConvoUI.Stop(true)
                break
            end
            local ent = ConvoUI.entity
            if not ent or not DoesEntityExist(ent) then
                ConvoUI.Close()
                break
            end
            local d = #(GetEntityCoords(cache.ped) - GetEntityCoords(ent))
            if d > (Config.Conversation.MaxDistance or 5.0) + 1.0 then
                ConvoUI.Stop(true)
                break
            end
        end
    end)
end

-- Paneli açık tutup oyuna dön (yürüyerek uzaklaşmak için) / tekrar yazmaya dön
lib.addKeybind({
    name = 'samy_citizens_focus',
    description = L('keybind_focus'),
    defaultKey = 'Y',
    onPressed = function()
        if ConvoUI.active and SC.Client.nuiOwner ~= 'convo' then
            SC.Client.SetFocus('convo', true)
            SendNUIMessage({ action = 'convo:focus', value = true })
        end
    end,
})

RegisterNUICallback('convo:send', function(data, cb)
    if ConvoUI.active and type(data) == 'table' and type(data.text) == 'string' then
        TriggerServerEvent('samy-citizens:server:say', data.text)
    end
    cb({ ok = true })
end)

-- v3: kategori menüsü aksiyonları (Beraber Yürü / Araca Davet / Bir Yere Git / Etkileşimler)
-- Metin seçenekleri doğrudan NPC'ye söylenir; diğerleri sunucuda yeniden doğrulanır.
local function myVehicleNear()
    local veh = GetVehiclePedIsIn(cache.ped, false)
    if veh == 0 then veh = GetVehiclePedIsIn(cache.ped, true) end
    if veh == 0 or not DoesEntityExist(veh) then return nil end
    if #(GetEntityCoords(veh) - GetEntityCoords(cache.ped)) > (Config.Vehicle.InviteDistance or 12.0) then return nil end
    return NetworkGetNetworkIdFromEntity(veh)
end

local function waypointCoords()
    local blip = GetFirstBlipInfoId(8)
    if not blip or blip == 0 or not DoesBlipExist(blip) then return nil end
    local c = GetBlipInfoIdCoord(blip)
    local ok, gz = GetGroundZFor_3dCoord(c.x, c.y, 1000.0, false)
    return { x = c.x, y = c.y, z = ok and gz or c.z }
end

RegisterNUICallback('convo:action', function(data, cb)
    cb({ ok = true })
    if not ConvoUI.active or type(data) ~= 'table' then return end
    if type(data.text) == 'string' and data.text ~= '' then
        TriggerServerEvent('samy-citizens:server:say', data.text)
        return
    end
    local action = data.action
    local extra = { npc = ConvoUI.netId }
    if action == 'invite' then
        extra.veh = myVehicleNear()
        if not extra.veh then
            lib.notify({ title = L('notify_title'), description = (LT('ui') or {}).no_vehicle_near or '', type = 'error' })
            return
        end
        TriggerServerEvent('samy-citizens:server:menuAction', 'invite', nil, extra)
    elseif action == 'goto' and type(data.id) == 'string' then
        if data.id == 'waypoint' then
            extra.wp = waypointCoords()
            if not extra.wp then
                lib.notify({ title = L('notify_title'), description = (LT('ui') or {}).no_waypoint or '', type = 'error' })
                return
            end
        end
        TriggerServerEvent('samy-citizens:server:menuAction', 'goto', data.id, extra)
    elseif action == 'interact' and type(data.id) == 'string' then
        TriggerServerEvent('samy-citizens:server:menuAction', 'interact', data.id, extra)
    end
end)

-- v3: yanındaki (araçtaki dahil) eşlikçi NPC ile konuşma panelini aç
local function openCompanionMenu()
    if ConvoUI.active then return end
    local best, bestD
    local me = GetEntityCoords(cache.ped)
    SC.Client.ForEachResidentPed(function(ped)
        local t = Entity(ped).state.scTask
        if type(t) == 'table' and t.kind == 'companion' and t.target == cache.serverId then
            local d = #(GetEntityCoords(ped) - me)
            if d < 6.0 and (not bestD or d < bestD) then best, bestD = ped, d end
        end
    end)
    if not best then
        lib.notify({ title = L('notify_title'), description = L('companion_none'), type = 'inform' })
        return
    end
    ConvoUI.Start(best)
end

RegisterCommand((Config.Follow and Config.Follow.MenuCommand) or 'sakinmenu', openCompanionMenu, false)
lib.addKeybind({
    name = 'samy_citizens_companion_menu',
    description = L('keybind_companion_menu'),
    defaultKey = (Config.Follow and Config.Follow.MenuKey) or 'F9',
    onPressed = openCompanionMenu,
})

RegisterNUICallback('convo:close', function(_, cb)
    ConvoUI.Stop(true)
    cb({ ok = true })
end)

RegisterNUICallback('convo:release', function(_, cb)
    if ConvoUI.active then
        SC.Client.SetFocus('convo', false)
        SendNUIMessage({ action = 'convo:focus', value = false })
    end
    cb({ ok = true })
end)

RegisterNetEvent('samy-citizens:client:convoMessage', function(data)
    if ConvoUI.active then SendNUIMessage({ action = 'convo:message', data = data }) end
end)

RegisterNetEvent('samy-citizens:client:convoThinking', function(value)
    if ConvoUI.active then SendNUIMessage({ action = 'convo:thinking', value = value }) end
end)

RegisterNetEvent('samy-citizens:client:convoError', function(msg)
    if ConvoUI.active then SendNUIMessage({ action = 'convo:error', text = msg }) end
end)

RegisterNetEvent('samy-citizens:client:convoEnd', function(reason)
    if not ConvoUI.active then return end
    SendNUIMessage({ action = 'convo:ended', text = L('convo_end_' .. tostring(reason)) })
    SetTimeout(1400, function() ConvoUI.Close() end)
end)

-- ---------------------------------------------------------------------
-- 3D konuşma baloncukları
-- ---------------------------------------------------------------------
local bubbles = {}
local rendering = false

local function bubbleEntity(b)
    if b.net then
        if NetworkDoesEntityExistWithNetworkId(b.net) then return NetworkGetEntityFromNetworkId(b.net) end
        return 0
    end
    local pl = GetPlayerFromServerId(b.player or -1)
    if pl and pl ~= -1 then return GetPlayerPed(pl) end
    return 0
end

local function startRender()
    if rendering then return end
    rendering = true
    CreateThread(function()
        while true do
            local now = GetGameTimer()
            local cam = GetFinalRenderedCamCoord()
            local list, any = {}, false
            for key, b in pairs(bubbles) do
                if now > b.expires then
                    bubbles[key] = nil
                    SendNUIMessage({ action = 'bubble:remove', id = key })
                else
                    any = true
                    local ent = bubbleEntity(b)
                    local vis, sx, sy, scale = false, 0.0, 0.0, 1.0
                    if ent ~= 0 and DoesEntityExist(ent) then
                        local hp = GetWorldPositionOfEntityBone(ent, GetPedBoneIndex(ent, 31086)) + vector3(0.0, 0.0, 0.42)
                        local dist = #(cam - hp)
                        if dist < 28.0 then
                            local on, x, y = GetScreenCoordFromWorldCoord(hp.x, hp.y, hp.z)
                            if on then
                                vis, sx, sy = true, x, y
                                scale = math.max(0.55, math.min(1.0, 1.35 - dist / 22.0))
                            end
                        end
                    end
                    list[#list + 1] = { id = key, x = sx, y = sy, s = scale, v = vis }
                end
            end
            SendNUIMessage({ action = 'bubble:pos', list = list })
            if not any then
                rendering = false
                return
            end
            Wait(0)
        end
    end)
end

RegisterNetEvent('samy-citizens:client:bubble', function(data)
    if type(data) ~= 'table' or type(data.text) ~= 'string' then return end
    local key = data.net and ('n' .. tostring(data.net)) or ('p' .. tostring(data.player))
    bubbles[key] = {
        net = data.net, player = data.player, text = data.text, kind = data.kind,
        expires = GetGameTimer() + (tonumber(data.duration) or 7000),
    }
    SendNUIMessage({ action = 'bubble:set', id = key, text = data.text, kind = data.kind })
    startRender()
end)
