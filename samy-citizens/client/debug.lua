--[[
    /citizensdebug — her sakinin üstünde id + ad + aktivite + görev + ağ sahibi
    Sadece açıkken kare bazlı çizim yapar.
]]
local Utils = SC.Utils
local enabled = false
local info = {}
local peds = {}

local function drawText3D(x, y, z, text)
    SetDrawOrigin(x, y, z, 0)
    SetTextScale(0.0, 0.28)
    SetTextFont(0)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 220)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

RegisterNetEvent('samy-citizens:client:toggleDebug', function()
    enabled = not enabled
    lib.notify({ title = L('notify_title'), description = enabled and L('debug_on') or L('debug_off'), type = 'inform' })
    if not enabled then return end

    -- veri: 2 sn'de bir sunucudan, ped listesi 1 sn'de bir kayıt defterinden
    CreateThread(function()
        while enabled do
            local res = lib.callback.await('samy-citizens:admin:debugInfo', false)
            if type(res) == 'table' then info = res end
            Wait(2000)
        end
    end)
    CreateThread(function()
        while enabled do
            local list = {}
            SC.Client.ForEachResidentPed(function(ped, netId, rid)
                list[#list + 1] = { ped = ped, netId = netId, rid = rid }
            end)
            peds = list
            Wait(1000)
        end
    end)
    CreateThread(function()
        while enabled do
            local myPos = GetEntityCoords(cache.ped)
            for _, e in ipairs(peds) do
                if DoesEntityExist(e.ped) then
                    local pc = GetEntityCoords(e.ped)
                    if #(pc - myPos) < 60.0 then
                        local d = info[tostring(e.netId)] or {}
                        local owner = NetworkGetEntityOwner(e.ped)
                        local ownerSid = (owner and owner ~= -1) and GetPlayerServerId(owner) or -1
                        local task = Entity(e.ped).state.scTask
                        local text = ('~y~%s~w~ %s~n~%s | %s%s~n~sahip: %d%s'):format(
                            e.rid, Utils.Ascii(d.name or ''), d.activity or '?', task and task.kind or '?',
                            d.convo and ' ~g~[konusma]~w~' or (d.override and (' [' .. d.override .. ']') or ''),
                            ownerSid, owner == PlayerId() and ' ~g~(sen)' or '')
                        drawText3D(pc.x, pc.y, pc.z + 1.15, text)
                    end
                end
            end
            Wait(0)
        end
    end)
end)
