--[[
    TELEFON KÖPRÜSÜ (sunucu)
    Config.Phone.Provider = 'auto' ise Config.Phone.AutoDetect sırasıyla başlamış ilk telefon kaynağı seçilir,
    hiçbiri yoksa yerleşik mini mesajlaşma ('builtin') kullanılır. Telefon kaynağı sonradan başlarsa yeniden algılanır.

    Sağlayıcı          NPC -> oyuncu                         oyuncu -> NPC
    gksphone (v2)      exports.gksphone:SendMessage           'gksphone:messages:messageSent'
    lb-phone           exports['lb-phone']:SendMessage        'lb-phone:messages:messageSent'
    npwd               exports.npwd:emitMessage               exports.npwd:onMessage(numara, cb)
    qb-phone           e-posta ('qb-phone:server:sendNewMailToOffline')   (yok: yerleşik ekran ile cevap)
    custom             Config.Phone.Custom.Send / GetNumber   gelen: TriggerEvent('samy-citizens:phone:incoming', ...) ya da export PhoneIncoming
    builtin            NUI (/sakinmesaj)                      NUI

    NOT: gksphone entegrasyonu bu kaynağın önceki sürümünden beri kullanılan yoldur. lb-phone / npwd / qb-phone
    adaptörleri bu telefonların yayımlanmış API'lerine göre yazıldı ve pcall ile korunur; telefonunun sürümü farklı
    bir imza kullanıyorsa 'custom' sağlayıcı ile kendi fonksiyonlarını bağlayabilirsin.
]]
local PB = {}
SC.PhoneBridge = PB

local active = nil
local npwdRegistered = {}

local function started(res)
    return GetResourceState(res) == 'started'
end

local function numStr(v)
    if v == nil then return nil end
    local s = tostring(v)
    if s == '' then return nil end
    return s
end

-- ---------------------------------------------------------------------
-- Sağlayıcılar
-- ---------------------------------------------------------------------
local Providers = {}

Providers.gksphone = {
    resource = 'gksphone', twoWay = true,
    Send = function(npcNumber, playerNumber, text)
        if not npcNumber or not playerNumber then return false end
        local ok, res = pcall(function()
            return exports.gksphone:SendMessage(npcNumber, playerNumber, text, { skipSIMUsage = true, saveSenderCopy = false })
        end)
        if not ok or (type(res) == 'table' and res.status == false) then
            SC.DebugPrint('gksphone SendMessage hatası:', ok and tostring(res and res.error) or tostring(res))
            return false
        end
        return true
    end,
    SendLocation = function(npcNumber, playerNumber, x, y)
        if not npcNumber or not playerNumber then return false end
        return pcall(function()
            exports.gksphone:SendMessage(npcNumber, playerNumber, vector2(x + 0.0, y + 0.0), { skipSIMUsage = true, saveSenderCopy = false })
        end)
    end,
    GetNumber = function(src)
        local ok, num = pcall(function() return exports.gksphone:GetPhoneBySource(src) end)
        return ok and numStr(num) or nil
    end,
}

Providers['lb-phone'] = {
    resource = 'lb-phone', twoWay = true,
    Send = function(npcNumber, playerNumber, text)
        if not npcNumber or not playerNumber then return false end
        local ok, err = pcall(function() exports['lb-phone']:SendMessage(npcNumber, playerNumber, text) end)
        if not ok then SC.DebugPrint('lb-phone SendMessage hatası:', tostring(err)) end
        return ok
    end,
    GetNumber = function(src)
        local ok, num = pcall(function() return exports['lb-phone']:GetEquippedPhoneNumber(src) end)
        return ok and numStr(num) or nil
    end,
    SourceOf = function(number)
        local ok, src = pcall(function() return exports['lb-phone']:GetSourceFromNumber(number) end)
        return ok and tonumber(src) or nil
    end,
}

Providers.npwd = {
    resource = 'npwd', twoWay = true,
    Send = function(npcNumber, playerNumber, text)
        if not npcNumber or not playerNumber then return false end
        local ok, err = pcall(function()
            exports.npwd:emitMessage({ senderNumber = npcNumber, targetNumber = playerNumber, message = text })
        end)
        if not ok then SC.DebugPrint('npwd emitMessage hatası:', tostring(err)) end
        return ok
    end,
    GetNumber = function(src)
        local ok, data = pcall(function() return exports.npwd:getPlayerData({ source = src }) end)
        if ok and type(data) == 'table' then return numStr(data.phoneNumber or data.phone_number) end
        return nil
    end,
}

Providers['qb-phone'] = {
    resource = 'qb-phone', twoWay = false,
    Send = function(npcNumber, playerNumber, text, src, meta)
        if not meta or not meta.cid then return false end
        local ok, err = pcall(function()
            TriggerEvent('qb-phone:server:sendNewMailToOffline', meta.cid, {
                sender = meta.npcName or npcNumber or '?', subject = meta.npcName or npcNumber or '?', message = text, button = {},
            })
        end)
        if not ok then SC.DebugPrint('qb-phone mail hatası:', tostring(err)) end
        return ok
    end,
    GetNumber = function() return nil end,
}

Providers.custom = {
    resource = nil, twoWay = true,
    Send = function(npcNumber, playerNumber, text, src, meta)
        local fn = Config.Phone.Custom and Config.Phone.Custom.Send
        if type(fn) ~= 'function' then return false end
        local ok, res = pcall(fn, npcNumber, playerNumber, text, src, meta and meta.npcName)
        return ok and res ~= false
    end,
    GetNumber = function(src)
        local fn = Config.Phone.Custom and Config.Phone.Custom.GetNumber
        if type(fn) ~= 'function' then return nil end
        local ok, num = pcall(fn, src)
        return ok and numStr(num) or nil
    end,
}

Providers.builtin = {
    resource = nil, twoWay = true, builtin = true,
    Send = function(npcNumber, playerNumber, text, src, meta)
        local target = src or (meta and meta.cid and SC.Bridge.GetSourceByCitizenId(meta.cid))
        if not target then return true end   -- çevrimdışı: mesaj DB'de, telefonu açınca görür
        local payload = {
            npcId = meta and meta.npcId, name = meta and meta.npcName, number = npcNumber,
            text = text, at = os.time(), direction = 'in',
        }
        for k, v in pairs((meta and meta.extra) or {}) do payload[k] = v end
        TriggerClientEvent('samy-citizens:client:phoneMessage', target, payload)
        return true
    end,
    GetNumber = function() return 'builtin' end,
}

-- ---------------------------------------------------------------------
-- Seçim
-- ---------------------------------------------------------------------
function PB.Resolve()
    local want = Config.Phone.Provider or 'auto'
    local pick
    if want == 'none' then
        pick = nil
    elseif want == 'auto' then
        for _, name in ipairs(Config.Phone.AutoDetect or {}) do
            local p = Providers[name]
            if p and p.resource and started(p.resource) then
                pick = name
                break
            end
        end
        pick = pick or 'builtin'
    elseif Providers[want] then
        local p = Providers[want]
        if p.resource and not started(p.resource) then
            pick = Config.Phone.BuiltinFallback ~= false and 'builtin' or nil
        else
            pick = want
        end
    end
    if pick ~= active then
        active = pick
        print(('^2[samy-citizens] telefon sağlayıcısı: %s^7'):format(tostring(active or 'kapalı')))
    end
    GlobalState.scPhoneProvider = active or 'none'
    GlobalState.scPhoneBuiltin = PB.BuiltinUI()
    if active == 'npwd' then PB.RegisterNumbers() end
    return active
end

function PB.Name() return active end
function PB.Enabled() return active ~= nil end
function PB.TwoWay() return active ~= nil and Providers[active].twoWay == true end

-- Yerleşik mesaj ekranı açık mı (builtin sağlayıcı ya da tek yönlü sağlayıcıda cevap için)
function PB.BuiltinUI()
    if active == 'builtin' then return true end
    return active ~= nil and not Providers[active].twoWay and Config.Phone.BuiltinFallback ~= false
end

function PB.GetNumber(src)
    if not active or not src then return nil end
    return Providers[active].GetNumber(src)
end

-- meta = { cid, npcId, npcName, extra }
function PB.Send(npcNumber, playerNumber, text, src, meta)
    if not active then return false end
    local ok = Providers[active].Send(numStr(npcNumber), numStr(playerNumber), text, src, meta)
    -- tek yönlü sağlayıcıda yerleşik ekrana da düşsün (oyuncu oradan cevap verebilsin)
    if active ~= 'builtin' and PB.BuiltinUI() then Providers.builtin.Send(npcNumber, playerNumber, text, src, meta) end
    return ok
end

function PB.SendLocation(npcNumber, playerNumber, x, y, label, src, meta)
    local p = active and Providers[active]
    if p and p.SendLocation then return p.SendLocation(numStr(npcNumber), numStr(playerNumber), x, y) end
    meta = meta or {}
    meta.extra = { location = { x = x, y = y, label = label } }
    return PB.Send(npcNumber, playerNumber, L('sms_location', label or '?'), src, meta)
end

-- Gelen mesaj: alıcı numara bir sakine aitse sunucunun SMS akışına verilir
function PB.Incoming(receiverNumber, src, senderNumber, text)
    if not SC.Phone or not receiverNumber then return end
    local rid = SC.Phone.byNumber[SC.Phone.Normalize(receiverNumber)]
    if not rid then return end
    src = tonumber(src)
    if not src or src <= 0 or not GetPlayerName(src) then return end
    if type(text) ~= 'string' then text = L('sms_location_shared') end
    SC.Phone.OnIncoming(rid, src, tostring(senderNumber or ''), text)
end

-- NPWD numara başına dinleyici ister
function PB.RegisterNumbers()
    if active ~= 'npwd' or not SC.Phone then return end
    for num in pairs(SC.Phone.byNumber) do
        if not npwdRegistered[num] then
            local ok = pcall(function()
                exports.npwd:onMessage(num, function(ctx)
                    if active ~= 'npwd' or type(ctx) ~= 'table' then return end
                    local data = type(ctx.data) == 'table' and ctx.data or ctx
                    local src = ctx.source or data.source
                    local from = data.sourcePhoneNumber or data.senderNumber or data.phoneNumber
                    PB.Incoming(num, src, from, data.message)
                end)
            end)
            if ok then npwdRegistered[num] = true end
        end
    end
end

-- ---------------------------------------------------------------------
-- Gelen mesaj dinleyicileri (etkin sağlayıcıya göre)
-- ---------------------------------------------------------------------
AddEventHandler('gksphone:messages:messageSent', function(data)
    if active ~= 'gksphone' or type(data) ~= 'table' then return end
    if data.receiverSource then return end   -- alıcı gerçek bir oyuncu
    PB.Incoming(data.receiverNumber, data.senderSource, data.senderNumber, data.message)
end)

AddEventHandler('lb-phone:messages:messageSent', function(msg)
    if active ~= 'lb-phone' or type(msg) ~= 'table' then return end
    local to = msg.recipient
    if not to or not SC.Phone or not SC.Phone.byNumber[SC.Phone.Normalize(to)] then return end
    local src = msg.source or Providers['lb-phone'].SourceOf(msg.sender)
    PB.Incoming(to, src, msg.sender, msg.message)
end)

-- Özel telefon (Provider = 'custom') ya da başka bir kaynak için gelen mesaj girişi.
-- SADECE sunucu tarafı: RegisterNetEvent yapılmadığı için istemci tetikleyemez.
--   TriggerEvent('samy-citizens:phone:incoming', src, npcNumber, playerNumber, text)
--   exports['samy-citizens']:PhoneIncoming(src, npcNumber, playerNumber, text)
AddEventHandler('samy-citizens:phone:incoming', function(src, npcNumber, playerNumber, text)
    PB.Incoming(npcNumber, src, playerNumber, text)
end)
exports('PhoneIncoming', function(src, npcNumber, playerNumber, text)
    PB.Incoming(npcNumber, src, playerNumber, text)
end)

-- telefon kaynağı sonradan başlar / durursa yeniden seç
AddEventHandler('onResourceStart', function(res)
    for _, p in pairs(Providers) do
        if p.resource == res then
            SetTimeout(2000, PB.Resolve)
            return
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    for _, p in pairs(Providers) do
        if p.resource == res then
            SetTimeout(500, PB.Resolve)
            return
        end
    end
end)
