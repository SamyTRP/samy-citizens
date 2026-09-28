-- QBX (qbx_core) köprüsü
if SC.Bridge then return end
if Config.Framework ~= 'qbx' and not (Config.Framework == 'auto' and GetResourceState('qbx_core') ~= 'missing') then return end

local Bridge = { name = 'qbx' }
SC.Bridge = Bridge

local function getPlayer(src)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    if ok then return p end
    return nil
end

function Bridge.GetPlayer(src)
    return getPlayer(src)
end

function Bridge.GetCitizenId(src)
    local p = getPlayer(src)
    return p and p.PlayerData and p.PlayerData.citizenid or nil
end

-- Karakter adı (asla gerçek/Steam adı değil)
function Bridge.GetCharInfo(src)
    local p = getPlayer(src)
    if not p or not p.PlayerData then return nil end
    local ci = p.PlayerData.charinfo or {}
    return {
        firstname = ci.firstname or '?',
        lastname = ci.lastname or '',
        gender = (tonumber(ci.gender) == 1) and 'female' or 'male',
        phone = ci.phone,
    }
end

function Bridge.GetJob(src)
    local p = getPlayer(src)
    if not p or not p.PlayerData or not p.PlayerData.job then return nil end
    local j = p.PlayerData.job
    return { name = j.name, label = j.label, onduty = j.onduty == true, grade = j.grade and (j.grade.level or j.grade) or 0 }
end

function Bridge.GetMoney(src, account)
    local p = getPlayer(src)
    if not p or not p.PlayerData or not p.PlayerData.money then return 0 end
    return p.PlayerData.money[account or 'cash'] or 0
end

function Bridge.GetSourceByCitizenId(cid)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayerByCitizenId(cid) end)
    if ok and p and p.PlayerData then return p.PlayerData.source end
    return nil
end

function Bridge.OnPlayerUnload(cb)
    AddEventHandler('QBCore:Server:OnPlayerUnload', function(src) cb(src or source) end)
    AddEventHandler('qbx_core:server:playerLoggedOut', function(src) cb(src or source) end)
end
