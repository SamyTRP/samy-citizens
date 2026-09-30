--[[
    YETİŞKİN NPC KATEGORİSİ (sunucu kuralları)
    - Sadece açıkça yetişkin olarak işaretlenmiş (profile.adult = true), yaşı Config.AdultNPC.MinAge üstü ve tipi
      Config.AdultNPC.AllowedTypes içinde olan NPC'ler bu kategoriye girer.
    - "Yetişkin Etkileşimleri" menüsü, yetişkin animasyonları ve ilgili kurallar sadece bu NPC'lerde ve
      Config.AdultNPC.Enabled = true iken çalışır. RequireAce ile oyuncu grubu da sınırlanabilir.
    - Her etkileşim oyuncu tarafından başlatılır; NPC kişiliğine, ilişkiye ve ruh hâline göre kabul/ret eder (rıza).
      Reddedilen teklif ConsentCooldownSec boyunca tekrar denenemez.
    - Bölgeler (Config.AdultNPCZones): aynı anda en fazla maxNPCs fiziksel yetişkin NPC; normal sakinlerle
      sosyal ağ (komşu/iş arkadaşı/dedikodu) karışmaz (server/social.lua, SC.NPC.Group).
]]
local Utils = SC.Utils
local Sim = SC.Sim
local NPC = SC.NPC

local Adult = {}
SC.Adult = Adult

local refused = {}   -- 'npc|cid|anim' -> os.time()

local function A() return Config.AdultNPC or {} end

function Adult.Enabled()
    return A().Enabled == true
end

function Adult.IsAdultNPC(r)
    if not r or not Adult.Enabled() then return false end
    local p = type(r.profile) == 'table' and r.profile or {}
    if p.adult ~= true then return false end
    if (tonumber(r.age) or 0) < (A().MinAge or 21) then return false end
    local allowed = A().AllowedTypes or {}
    return allowed[NPC.Type(r)] == true
end

function Adult.PlayerAllowed(src)
    if not A().RequireAce then return true end
    return IsPlayerAceAllowed(src, A().Ace or 'samycitizens.adult')
end

-- Menüde "Yetişkin Etkileşimleri" kategorisi görünsün mü
function Adult.CanSeeCategory(r, src)
    return Adult.IsAdultNPC(r) and Adult.PlayerAllowed(src)
end

function Adult.Zone(r)
    local p = type(r.profile) == 'table' and r.profile or {}
    local z = p.zone and Config.AdultNPCZones and Config.AdultNPCZones[p.zone]
    if z and z.enabled ~= false then return z, p.zone end
    return nil
end

function Adult.InZone(zone, pos)
    if not zone or not pos then return false end
    return Utils.Dist(zone.center, pos) <= (zone.radius or 80.0)
end

-- Bölge kapasitesi: aynı bölgedeki fiziksel yetişkin NPC sayısı maxNPCs'i aşmasın
function Adult.CanSpawn(r)
    local zone, zoneId = Adult.Zone(r)
    if not zone or NPC.Type(r) == 'citizen' then return true end
    local pos = Sim.GetPosition(r)
    if not pos or not Adult.InZone(zone, pos) then return true end
    local n = 0
    for rid in pairs(SC.Spawner.peds) do
        local o = Sim.Residents[rid]
        if o and o.id ~= r.id and o.profile and o.profile.zone == zoneId then
            local op = SC.Spawner.GetPedCoords(o)
            if op and Adult.InZone(zone, op) then n = n + 1 end
        end
    end
    return n < (zone.maxNPCs or 6)
end

-- NPC'ye en yakın direk noktası (bölge ayarı + konumdaki 'pole' etiketli noktalar)
function Adult.PolePos(r)
    local zone = Adult.Zone(r)
    local pos = NPC.Coords(r)
    if not pos then return nil end
    local best, bestD
    local function consider(v)
        local d = Utils.Dist(pos, v)
        if d <= 20.0 and (not bestD or d < bestD) then best, bestD = v, d end
    end
    for _, v in ipairs((zone and zone.poles) or {}) do consider(v) end
    local loc = zone and zone.location and Sim.Locations[zone.location]
    for _, p in ipairs((loc and loc.points) or {}) do
        for _, t in ipairs(p.tags or {}) do
            if t == 'pole' then consider(p.coords) end
        end
    end
    return best
end

local function otherPlayersNear(src, pos, radius)
    for _, p in ipairs(SC.Spawner.Players()) do
        if p.src ~= src and Utils.Dist(p.coords, pos) <= radius then return true end
    end
    return false
end

--[[
    Yetişkin etkileşim kuralları. dönüş: ok, sebep
    sebep: adult | zone | privacy | vehicle | female | cooldown | stage | mood | busy | default | cold
]]
function Adult.CanUse(r, src, id, def, rel, skipDecision)
    if not Adult.CanSeeCategory(r, src) then return false, 'adult' end
    local npos, ppos = NPC.Coords(r), NPC.PlayerCoords(src)
    if not npos or not ppos then return false, 'default' end
    if def.npcFemale and r.gender ~= 'female' then return false, 'female' end
    if def.zone then
        local zone = Adult.Zone(r)
        if not zone or not Adult.InZone(zone, npos) or not Adult.InZone(zone, ppos) then return false, 'zone' end
    end
    if def.pole and not Adult.PolePos(r) then return false, 'zone' end
    if def.private and otherPlayersNear(src, ppos, A().PrivacyRadius or 20.0) then return false, 'privacy' end
    if def.minStage and not SC.StageAtLeast(rel.stage, def.minStage) and (rel.romance or 'none') == 'none' then return false, 'stage' end
    if skipDecision then return true end
    local rk = r.id .. '|' .. tostring(rel.citizenid) .. '|' .. id
    if refused[rk] and os.time() - refused[rk] < (A().ConsentCooldownSec or 120) then return false, 'cooldown' end
    local ok, reason = SC.Persona.Decide(r, rel, def.rule or 'intimate', { cid = rel.citizenid, sub = id })
    if not ok then
        refused[rk] = os.time()
        return false, reason or 'default'
    end
    return true
end

function Adult.Cleanup()
    local now = os.time()
    local cd = A().ConsentCooldownSec or 120
    for k, t in pairs(refused) do
        if now - t > cd then refused[k] = nil end
    end
end
