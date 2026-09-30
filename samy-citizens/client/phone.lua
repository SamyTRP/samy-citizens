--[[
    Yerleşik mini mesajlaşma
    Sunucu, seçilen telefon sağlayıcısını GlobalState.scPhoneProvider'a yazar (bridge/phone.lua).
    Yerleşik ekran sadece sağlayıcı 'builtin' ise ya da tek yönlü bir sağlayıcıda (qb-phone) cevap için açılır;
    gksphone / lb-phone / npwd kullanılıyorsa tüm SMS akışı o telefondan geçer.
]]
local open = false

local function openPhone()
    if open then return end
    if not GlobalState.scPhoneBuiltin then
        lib.notify({ title = L('notify_title'), description = L('phone_use_own', tostring(GlobalState.scPhoneProvider or '?')), type = 'inform' })
        return
    end
    local contacts = lib.callback.await('samy-citizens:phone:contacts', false)
    open = true
    SendNUIMessage({ action = 'phone:open', contacts = contacts or {} })
    SC.Client.SetFocus('phone', true)
end

RegisterCommand(Config.Phone.BuiltinCommand or 'sakinmesaj', openPhone, false)

RegisterNUICallback('phone:thread', function(data, cb)
    local rows = lib.callback.await('samy-citizens:phone:thread', false, data and data.npcId)
    cb(rows or {})
end)

RegisterNUICallback('phone:send', function(data, cb)
    if type(data) == 'table' and type(data.npcId) == 'string' and type(data.text) == 'string' then
        TriggerServerEvent('samy-citizens:server:phoneSend', data.npcId, data.text)
    end
    cb({ ok = true })
end)

RegisterNUICallback('phone:waypoint', function(data, cb)
    if type(data) == 'table' and tonumber(data.x) and tonumber(data.y) then
        SetNewWaypoint(tonumber(data.x) + 0.0, tonumber(data.y) + 0.0)
    end
    cb({ ok = true })
end)

RegisterNUICallback('phone:close', function(_, cb)
    open = false
    SC.Client.SetFocus('phone', false)
    cb({ ok = true })
end)

RegisterNetEvent('samy-citizens:client:phoneTyping', function(npcId, on)
    if type(npcId) ~= 'string' then return end
    SendNUIMessage({ action = 'phone:typing', npcId = npcId, value = on == true })
end)

RegisterNetEvent('samy-citizens:client:phoneMessage', function(msg)
    if type(msg) ~= 'table' then return end
    PlaySoundFrontend(-1, 'Text_Arrive_Tone', 'Phone_SoundSet_Default', true)
    lib.notify({
        title = ('📱 %s'):format(msg.name or '?'),
        description = msg.text,
        type = 'inform',
        duration = 9000,
    })
    SendNUIMessage({ action = 'phone:message', message = msg })
end)
