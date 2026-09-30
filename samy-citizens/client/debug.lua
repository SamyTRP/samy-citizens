--[[
    /citizensdebug — her sakinin üstünde id + ad + aktivite + görev + ağ sahibi
    v3: + State (durum makinesi), Mood, LOD, Relationship/XP (seninle), LastIntent, Destination, Vehicle,
        CurrentActivity, Schedule. Aynı bilgiler Config.Debug = true iken sunucu konsoluna da yazılır.
    Sadece açıkken kare bazlı çizim yapar; kapalıyken hiçbir debug thread'i çalışmaz.
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
                        -- v3: durum makinesi, ruh hâli, ilişki, hedef, araç, son niyet, program
                        if d.state then
                            text = text .. ('~n~~b~State:~w~ %s  ~b~Mood:~w~ %s  ~b~LOD:~w~ %s~n~~b~Rel:~w~ %s (%s XP)  ~b~Intent:~w~ %s~n~~b~Dest:~w~ %s  ~b~Veh:~w~ %s~n~~b~Now:~w~ %s~n~~b~Sched:~w~ %s'):format(
                                d.state, d.mood or '-', d.lod or '-', Utils.Ascii(d.relationship or '-'), tostring(d.xp or 0),
                                d.lastIntent or '-', Utils.Ascii(d.destination or '-'), d.vehicle or '-',
                                Utils.Ascii(d.current or '-'), Utils.Ascii(d.schedule or '-'))
                        end
                        drawText3D(pc.x, pc.y, pc.z + 1.35, text)
                    end
                end
            end
            Wait(0)
        end
    end)
end)
