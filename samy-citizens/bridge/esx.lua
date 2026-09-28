-- ESX köprüsü
if SC.Bridge then return end
if Config.Framework ~= 'esx' and not (Config.Framework == 'auto' and GetResourceState('es_extended') ~= 'missing') then return end

local ESX = exports.es_extended:getSharedObject()
local Bridge = { name = 'esx' }
SC.Bridge = Bridge

local function getPlayer(src)
    return ESX.GetPlayerFromId(src)
end

function Bridge.GetPlayer(src)
    return getPlayer(src)
end

function Bridge.GetCitizenId(src)
    local x = getPlayer(src)
    return x and x.identifier or nil
end

function Bridge.GetCharInfo(src)
    local x = getPlayer(src)
    if not x then return nil end
    local first = x.get and x.get('firstName') or nil
    local last = x.get and x.get('lastName') or nil
    if not first then
        local full = x.getName and x.getName() or '?'
        first, last = full:match('^(%S+)%s*(.*)$')
    end
    local sex = x.get and x.get('sex') or 'm'
    return {
        firstname = first or '?',
        lastname = last or '',
        gender = (sex == 'f' or sex == 'F' or sex == 1) and 'female' or 'male',
        phone = x.get and x.get('phoneNumber') or nil,
    }
end

function Bridge.GetJob(src)
    local x = getPlayer(src)
    if not x or not x.job then return nil end
    local onDuty = true
    if x.job.onDuty ~= nil then onDuty = x.job.onDuty == true end
    return { name = x.job.name, label = x.job.label, onduty = onDuty, grade = x.job.grade or 0 }
end

function Bridge.GetMoney(src, account)
    local x = getPlayer(src)
    if not x then return 0 end
    if account == 'bank' then
        local acc = x.getAccount and x.getAccount('bank')
        return acc and acc.money or 0
    end
    return x.getMoney and x.getMoney() or 0
end

function Bridge.RemoveMoney(src, account, amount)
    local x = getPlayer(src)
    if not x then return false end
    if account == 'bank' then
        local acc = x.getAccount and x.getAccount('bank')
        if not acc or acc.money < amount then return false end
        x.removeAccountMoney('bank', amount)
        return true
    end
    if (x.getMoney and x.getMoney() or 0) < amount then return false end
    x.removeMoney(amount)
    return true
end

-- açlık / susuzluk (esx_status: 0-1000000)
function Bridge.AddStatus(src, kind, amount)
    TriggerClientEvent('esx_status:add', src, kind == 'hunger' and 'hunger' or 'thirst', math.floor((amount or 25) * 10000))
end

function Bridge.GetSourceByCitizenId(cid)
    local x = ESX.GetPlayerFromIdentifier(cid)
    return x and x.source or nil
end

function Bridge.OnPlayerUnload(cb)
    AddEventHandler('esx:playerLogout', function(src) cb(src or source) end)
end
