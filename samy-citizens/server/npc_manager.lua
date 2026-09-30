--[[
    NPC MANAGER — tek merkezi erişim noktası
    Sakin kayıtları (Sim.Residents), fiziksel ped'ler (Spawner.peds) ve eşlikçi (companion) dizini burada birleşir.
    Yeni modüller (companion, etkileşim, olaylar, yetişkin NPC...) kendi entity listesini TUTMAZ; her şeyi
    SC.NPC üzerinden sorgular. Böylece ped silinince / sahiplik değişince tek bir yerden doğru bilgi okunur.

    NPC.Data(id, cid) örnek görünümü:
      { id, name, ped, netId, physical, state, type, adult, personality = stats, relationship = {...}|nil,
        schedule = { activity, location, from, to }, destination, currentVehicle, currentPlayer, mood }
]]
local Utils = SC.Utils
local Sim = SC.Sim
local Spawner = SC.Spawner

local NPC = {}
SC.NPC = NPC

-- src -> { [residentId] = true }  (eşlikçi NPC'ler; companion override'ı ile senkron tutulur)
NPC.companionsBySrc = {}

local function resolve(x)
    if type(x) == 'table' then return x end
    if type(x) == 'string' then return Sim.Residents[x] end
    return nil
end

function NPC.Get(id) return Sim.Residents[id] end
function NPC.All() return Sim.List end

function NPC.Ped(x)
    local r = resolve(x)
    return r and Spawner.GetPed(r) or nil
end

function NPC.NetId(x)
    local r = resolve(x)
    local phys = r and Spawner.peds[r.id]
    return phys and phys.netId or nil
end

function NPC.IsPhysical(x)
    local r = resolve(x)
    return r ~= nil and Spawner.GetPed(r) ~= nil
end

function NPC.Coords(x)
    local r = resolve(x)
    if not r then return nil end
    return Spawner.GetPedCoords(r) or Sim.GetPosition(r)
end

function NPC.ByNet(netId) return Spawner.GetResidentByNet(netId) end
function NPC.ByEntity(ent) return Spawner.GetResidentByEntity(ent) end

function NPC.Profile(x)
    local r = resolve(x)
    return (r and type(r.profile) == 'table') and r.profile or {}
end

function NPC.Type(x)
    local p = NPC.Profile(x)
    local t = p.type
    if type(t) ~= 'string' or not Config.NPCTypes[t] then return 'citizen' end
    return t
end

function NPC.TypeDef(x)
    return Config.NPCTypes[NPC.Type(x)] or Config.NPCTypes.citizen
end

-- Sosyal ağ ayrımı: normal sakinler ile özel kategoriler (ör. yetişkin eğlence çalışanları) birbirine karışmaz
function NPC.Group(x)
    local t = NPC.Type(x)
    return t == 'citizen' and 'citizen' or t
end

function NPC.IsFemale(x)
    local r = resolve(x)
    return r ~= nil and r.gender == 'female'
end

function NPC.Vehicle(x)
    local ped = NPC.Ped(x)
    if not ped then return nil end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh and veh ~= 0 then return veh end
    return nil
end

-- ---------------------------------------------------------------------
-- Eşlikçi dizini
-- ---------------------------------------------------------------------
function NPC.Companion(x)
    local r = resolve(x)
    if r and r.override and r.override.type == 'companion' then return r.override end
    return nil
end

function NPC.IndexCompanion(r, src, on)
    if not src then return end
    local set = NPC.companionsBySrc[src]
    if on then
        if not set then
            set = {}
            NPC.companionsBySrc[src] = set
        end
        set[r.id] = true
    elseif set then
        set[r.id] = nil
        if next(set) == nil then NPC.companionsBySrc[src] = nil end
    end
end

-- Oyuncunun eşlikçileri (dizindeki bayat kayıtları temizleyerek)
function NPC.CompanionsOf(src)
    local out = {}
    local set = NPC.companionsBySrc[src]
    if not set then return out end
    for rid in pairs(set) do
        local r = Sim.Residents[rid]
        local c = r and NPC.Companion(r)
        if c and c.target == src then
            out[#out + 1] = r
        else
            set[rid] = nil
        end
    end
    if next(set) == nil then NPC.companionsBySrc[src] = nil end
    table.sort(out, function(a, b) return (NPC.Companion(a).slot or 1) < (NPC.Companion(b).slot or 1) end)
    return out
end

-- ---------------------------------------------------------------------
-- Oyuncu yardımcıları
-- ---------------------------------------------------------------------
function NPC.PlayerPed(src)
    if not src or not GetPlayerName(src) then return nil end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return ped
end

function NPC.PlayerCoords(src)
    local ped = NPC.PlayerPed(src)
    return ped and GetEntityCoords(ped) or nil
end

function NPC.DistanceToPlayer(x, src)
    local a = NPC.Coords(x)
    local b = NPC.PlayerCoords(src)
    if not a or not b then return math.huge end
    return Utils.Dist(a, b)
end

-- ---------------------------------------------------------------------
-- Birleşik görünüm (debug, export, diğer kaynaklar)
-- ---------------------------------------------------------------------
function NPC.Data(id, cid)
    local r = resolve(id)
    if not r then return nil end
    local phys = Spawner.peds[r.id]
    local st = r.state or {}
    local comp = NPC.Companion(r)
    local rel = cid and SC.Rel.Peek(r.id, cid) or nil
    local seg = nil
    local okSeg, cur = pcall(Sim.EffectiveSegmentAt, r, SC.Clock.Now())
    if okSeg and cur then
        local okRes, res = pcall(Sim.Resolve, r, cur, SC.Clock.Now(), true)
        seg = {
            activity = okRes and res and res.activity or cur.activity, location = okRes and res and res.loc or nil,
            from = Utils.FormatTime(cur.from % 1440), to = Utils.FormatTime(cur.to % 1440), temp = cur.temp == true, appt = cur.appt ~= nil,
        }
    end
    local veh = NPC.Vehicle(r)
    return {
        id = r.id,
        name = r.firstname .. ' ' .. r.lastname,
        ped = phys and phys.ped or nil,
        netId = phys and phys.netId or nil,
        physical = phys ~= nil,
        state = SC.State and SC.State.Get(r) or nil,
        type = NPC.Type(r),
        adult = SC.Adult and SC.Adult.IsAdultNPC(r) or false,
        personality = SC.Persona and SC.Persona.Stats(r) or nil,
        mood = SC.Persona and SC.Persona.MoodLabel(r, rel, cid) or nil,
        relationship = rel and SC.Rel.PublicView(rel) or nil,
        schedule = seg,
        activity = st.activity,
        destination = (comp and comp.dest and comp.dest.label) or (st.activity == 'commute' and Sim.LocationLabel(st.toLocationId)) or nil,
        currentVehicle = veh and NetworkGetNetworkIdFromEntity(veh) or nil,
        currentPlayer = (comp and comp.target) or (r.convo and r.convo.src) or (r.interaction and r.interaction.src) or nil,
        companion = comp and { mode = comp.mode, phase = comp.phase, target = comp.target } or nil,
    }
end
