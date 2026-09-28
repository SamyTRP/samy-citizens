--[[
    NPC'LER ARASI SOSYAL HAYAT (hafif)
    - Aynı işyeri = iş arkadaşı, aynı 'area' etiketli ev = komşu, data'daki acquaintances = tanıdık
    - Soyut katmanda aynı konumdaki sakinler düşük olasılıkla "sohbet eder" (şablon cümlelerle)
    - Dedikodu: önemi >= GossipMinImportance ve shareable anılar sohbetlerde ve gün sonunda ağa yayılır
      (alıcıda 'gossip' tipinde, düşük önemle ve tek adımlık). Özel sırlar (shareable=false) yayılmaz.
]]
local Utils = SC.Utils
local Clock = SC.Clock
local Sim = SC.Sim

local Social = {}
SC.Social = Social

Social.links = {}   -- npcId -> { otherId = 'coworker'|'neighbor'|'friend' }
Social.pool = {}    -- npcId -> { {id, citizenid, text, importance, valence, created_at, shared} }
local lastChatTick = nil

function Social.Rebuild()
    Social.links = {}
    local function link(a, b, kind)
        if a == b then return end
        Social.links[a] = Social.links[a] or {}
        Social.links[b] = Social.links[b] or {}
        -- en güçlü ilişki türü kalır: friend > coworker > neighbor
        local order = { neighbor = 1, coworker = 2, friend = 3 }
        if (order[kind] or 0) > (order[Social.links[a][b]] or 0) then Social.links[a][b] = kind end
        if (order[kind] or 0) > (order[Social.links[b][a]] or 0) then Social.links[b][a] = kind end
    end
    for i, a in ipairs(Sim.List) do
        for j = i + 1, #Sim.List do
            local b = Sim.List[j]
            if a.job and b.job and a.job.workplaceId and a.job.workplaceId == b.job.workplaceId then link(a.id, b.id, 'coworker') end
            local ha, hb = Sim.Locations[a.homeId], Sim.Locations[b.homeId]
            if ha and hb and (a.homeId == b.homeId or (Config.Social.NeighborAreaMatch and ha.area and ha.area ~= '' and ha.area == hb.area)) then
                link(a.id, b.id, 'neighbor')
            end
        end
        for _, other in ipairs(a.acquaintances or {}) do
            if Sim.Residents[other] then link(a.id, other, 'friend') end
        end
    end
end

function Social.Relation(a, b)
    return Social.links[a] and Social.links[a][b] or nil
end

-- NPC'nin tanıdıkları (bağlam/admin için)
function Social.Describe(r)
    local out = {}
    for other, kind in pairs(Social.links[r.id] or {}) do
        local o = Sim.Residents[other]
        if o then out[#out + 1] = ('%s %s (%s)'):format(o.firstname, o.lastname, L('social_' .. kind)) end
    end
    table.sort(out)
    return out
end

-- ---------------------------------------------------------------------
-- Dedikodu havuzu
-- ---------------------------------------------------------------------
function Social.LoadPool()
    Social.pool = {}
    local since = os.time() - 7 * 86400
    local rows = MySQL.query.await([[SELECT id, npc_id, citizenid, text, importance, valence, created_at, shared, data FROM samy_citizens_memories
        WHERE shareable = 1 AND archived = 0 AND citizenid IS NOT NULL AND type <> 'gossip' AND importance >= ? AND created_at >= ?]],
        { Config.Social.GossipMinImportance or 7, since }) or {}
    for _, row in ipairs(rows) do
        Social.pool[row.npc_id] = Social.pool[row.npc_id] or {}
        table.insert(Social.pool[row.npc_id], {
            id = row.id, citizenid = row.citizenid, text = row.text, importance = row.importance,
            valence = row.valence or 0, created_at = tonumber(row.created_at) or 0, shared = row.shared == 1,
            code = (Utils.JsonDecode(row.data) or {}).code,
        })
    end
end

function Social.OnShareableMemory(npcId, mem)
    Social.pool[npcId] = Social.pool[npcId] or {}
    mem.created_at = os.time()
    mem.shared = false
    table.insert(Social.pool[npcId], mem)
    while #Social.pool[npcId] > 20 do table.remove(Social.pool[npcId], 1) end
    -- çok önemli olaylar (silah doğrultma, saldırı...) birkaç dakika içinde telefonla yakın çevreye anlatılır
    if (mem.importance or 0) >= 8 then
        SetTimeout(math.random(60, 180) * 1000, function()
            local from = Sim.Residents[npcId]
            if not from then return end
            CreateThread(function()
                for other in pairs(Social.links[npcId] or {}) do
                    local to = Sim.Residents[other]
                    if to then Social.ShareGossip(from, to, mem) end
                end
            end)
        end)
    end
end

-- thread içinden
function Social.ShareGossip(from, to, mem)
    if from.id == to.id or not to.enabled then return false end
    if SC.Memory.HasFromSource(to.id, mem.id) then return false end
    local text = L('gossip_text', from.firstname, mem.text)
    local imp = math.min(Config.Social.GossipMaxImportance or 4, math.max(2, (mem.importance or 7) - 3))
    SC.Memory.Add(to.id, mem.citizenid, text, imp, 'gossip', {
        valence = mem.valence or 0, sourceId = mem.id, sourceNpc = from.id, shareable = false,
        data = { code = mem.code, from = from.id },
    })
    if (mem.valence or 0) ~= 0 then
        local rel = SC.Rel.Get(to.id, mem.citizenid)
        local d = (mem.valence or 0) * (Config.Social.GossipAffinity or 6)
        SC.Rel.ApplyDelta(rel, d, math.floor(d / 2), { bypassCap = true })
    end
    Sim.AddLog(from, Clock.Now(), 'event', { text = L('log_gossip_told', to.firstname) })
    return true
end

-- ---------------------------------------------------------------------
-- Sohbet
-- ---------------------------------------------------------------------
function Social.Chat(a, b)
    local now = Clock.Now()
    a.needs.social = Utils.Clamp(a.needs.social + 8, 0, 100)
    b.needs.social = Utils.Clamp(b.needs.social + 8, 0, 100)
    Sim.AddLog(a, now, 'event', { text = L('log_chat', b.firstname) })
    Sim.AddLog(b, now, 'event', { text = L('log_chat', a.firstname) })
    -- fiziksel olarak ikisi de görünür ve yakınsa karşılıklı sohbet animasyonu
    local pa, pb = SC.Spawner.GetPedCoords(a), SC.Spawner.GetPedCoords(b)
    if pa and pb and Utils.Dist(pa, pb) < 12.0 and not a.convo and not b.convo and not a.override and not b.override then
        local untilMs = GetGameTimer() + (Config.Social.PhysicalChatSeconds or 20) * 1000
        Sim.SetOverride(a, { type = 'chat', partner = b.id, untilMs = untilMs })
        Sim.SetOverride(b, { type = 'chat', partner = a.id, untilMs = untilMs })
    end
    -- dedikodu
    CreateThread(function()
        for _, pair in ipairs({ { a, b }, { b, a } }) do
            local from, to = pair[1], pair[2]
            for _, mem in ipairs(Social.pool[from.id] or {}) do
                if Social.ShareGossip(from, to, mem) then break end
            end
        end
    end)
end

-- Her ~10 oyun dakikasında bir çağrılır
function Social.Tick()
    local now = Clock.Now()
    if lastChatTick and now - lastChatTick < 10 then return end
    lastChatTick = now
    local byLoc = {}
    for _, r in ipairs(Sim.List) do
        local st = r.state
        if r.enabled and r.status == 'alive' and st and st.locationId and not r.convo
            and Config.Social.SocialActivities[st.activity] then
            byLoc[st.locationId] = byLoc[st.locationId] or {}
            table.insert(byLoc[st.locationId], r)
        end
    end
    local base = Config.Social.ChatChancePer10Min or 0.12
    for _, list in pairs(byLoc) do
        if #list >= 2 then
            for i = 1, #list do
                for j = i + 1, #list do
                    local a, b = list[i], list[j]
                    local chance = base * (Social.Relation(a.id, b.id) and 2.0 or 0.5)
                    if math.random() < chance then Social.Chat(a, b) end
                end
            end
        end
    end
end

-- Gün sonu: o gün oluşan önemli ve paylaşılabilir anılar tüm ağa yayılır
function Social.Nightly()
    CreateThread(function()
        for npcId, list in pairs(Social.pool) do
            local from = Sim.Residents[npcId]
            if from then
                for _, mem in ipairs(list) do
                    if not mem.shared then
                        for other in pairs(Social.links[npcId] or {}) do
                            local to = Sim.Residents[other]
                            if to then Social.ShareGossip(from, to, mem) end
                        end
                        mem.shared = true
                        MySQL.update('UPDATE samy_citizens_memories SET shared = 1 WHERE id = ?', { mem.id })
                    end
                end
            end
        end
        -- 7 günden eski havuz girdilerini at
        local cutoff = os.time() - 7 * 86400
        for npcId, list in pairs(Social.pool) do
            for i = #list, 1, -1 do
                if (list[i].created_at or 0) < cutoff then table.remove(list, i) end
            end
        end
    end)
end
