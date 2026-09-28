--[[
    HAFIZA (yapay zekâsız)
    Anılar: konuşma özetleri, oyuncunun söylediği bilgiler (ad, meslek, sevdikleri), oyun olayları, dedikodular.
    Her anının isteğe bağlı 'data' alanı (JSON) vardır: { kind='convo', place, topics } veya { code='aim_weapon' } gibi.
    Diyalog motoru bu yapısal alanlardan ikinci şahısla cümle kurar ("Bana silah doğrultan sendin!").
    Sıkıştırma: bir NPC–oyuncu çiftinde anı sayısı eşiği aşınca eski ve önemsiz olanlar arşivlenir.
    Unutma: önemi düşük ve uzun süre erişilmeyen anılar silinir; önemi yüksek olanlar kalıcıdır.
]]
local Utils = SC.Utils
local Memory = {}
SC.Memory = Memory

local compacting = {}

-- ---------------------------------------------------------------------
-- Ekleme (thread içinden çağrılmalı)
-- opts = { valence, shareable, sourceId, sourceNpc, data = {...} }
-- ---------------------------------------------------------------------
function Memory.Add(npcId, citizenid, text, importance, mtype, opts)
    opts = opts or {}
    text = Utils.Truncate(Utils.Trim(tostring(text or '')), Config.Memory.MaxTextLength or 220)
    if text == '' then return nil end
    importance = Utils.Clamp(math.floor(tonumber(importance) or 3), 1, 10)
    local ts = opts.createdAt or os.time()
    local keywords = table.concat(Utils.Tokenize(text), ' ')
    local dataJson = type(opts.data) == 'table' and json.encode(opts.data) or ''
    local id = MySQL.insert.await([[INSERT INTO samy_citizens_memories
        (npc_id, citizenid, text, importance, type, valence, shareable, source_id, source_npc, keywords, data, created_at, last_accessed)
        VALUES (?, NULLIF(?, ''), ?, ?, ?, ?, ?, NULLIF(?, 0), NULLIF(?, ''), ?, NULLIF(?, ''), ?, ?)]], {
        npcId, citizenid or '', text, importance, mtype or 'conversation', math.floor(opts.valence or 0),
        opts.shareable and 1 or 0, opts.sourceId or 0, opts.sourceNpc or '', keywords, dataJson, ts, ts,
    })
    if not id then return nil end

    if citizenid then Memory.MaybeCompact(npcId, citizenid) end

    if opts.shareable and citizenid and importance >= (Config.Social.GossipMinImportance or 7) and SC.Social then
        SC.Social.OnShareableMemory(npcId, {
            id = id, citizenid = citizenid, text = text, importance = importance, valence = opts.valence or 0,
            code = type(opts.data) == 'table' and opts.data.code or nil,
        })
    end

    local r = SC.Sim and SC.Sim.Residents[npcId]
    if r and importance >= 6 then
        SC.Sim.AddLog(r, SC.Clock.Now(), 'event', { text = text })
    end
    return id
end

function Memory.AddAsync(...)
    local args = { ... }
    CreateThread(function() Memory.Add(table.unpack(args, 1, 6)) end)
end

function Memory.HasFromSource(npcId, sourceId)
    return MySQL.scalar.await('SELECT 1 FROM samy_citizens_memories WHERE npc_id = ? AND source_id = ? LIMIT 1', { npcId, sourceId }) ~= nil
end

-- ---------------------------------------------------------------------
-- Sıkıştırma (eski ve önemsiz anıları arşivle)
-- ---------------------------------------------------------------------
function Memory.MaybeCompact(npcId, citizenid)
    local k = npcId .. '|' .. citizenid
    if compacting[k] then return end
    compacting[k] = true
    CreateThread(function()
        local ok, err = pcall(function()
            local rows = MySQL.query.await([[SELECT id, importance FROM samy_citizens_memories
                WHERE npc_id = ? AND citizenid = ? AND archived = 0 ORDER BY id ASC]], { npcId, citizenid }) or {}
            if #rows <= (Config.Memory.CompactThreshold or 30) then return end
            local keepFrom = #rows - (Config.Memory.CompactKeepRecent or 12) + 1
            local archive = {}
            for i, row in ipairs(rows) do
                if i < keepFrom and (row.importance or 0) < (Config.Memory.PermanentImportance or 8) then
                    archive[#archive + 1] = row.id
                end
            end
            if #archive > 0 then
                MySQL.update(('UPDATE samy_citizens_memories SET archived = 1 WHERE id IN (%s)'):format(string.rep('?', #archive, ',')), archive)
                SC.DebugPrint(('anı sıkıştırma: %s <-> %s, arşivlenen %d'):format(npcId, citizenid, #archive))
            end
        end)
        if not ok then SC.DebugPrint('sıkıştırma hatası', tostring(err)) end
        compacting[k] = nil
    end)
end

-- Anıya erişildi (unutma sayacını sıfırlar)
function Memory.Touch(ids)
    if not ids or #ids == 0 then return end
    MySQL.update(('UPDATE samy_citizens_memories SET last_accessed = ? WHERE id IN (%s)'):format(string.rep('?', #ids, ',')),
        { os.time(), table.unpack(ids) })
end

-- ---------------------------------------------------------------------
-- Unutma
-- ---------------------------------------------------------------------
function Memory.ForgetTick()
    local now = os.time()
    local perm = Config.Memory.PermanentImportance or 8
    local maxImp = math.min(Config.Memory.ForgetMaxImportance or 4, perm - 1)
    MySQL.update([[DELETE FROM samy_citizens_memories WHERE importance <= ? AND last_accessed < ?]],
        { maxImp, now - (Config.Memory.ForgetAfterDays or 14) * 86400 })
    MySQL.update([[DELETE FROM samy_citizens_memories WHERE archived = 1 AND importance < ? AND last_accessed < ?]],
        { perm, now - (Config.Memory.ArchiveDeleteAfterDays or 60) * 86400 })
end

-- ---------------------------------------------------------------------
-- Yönetim
-- ---------------------------------------------------------------------
function Memory.ListForPair(npcId, citizenid, includeArchived)
    local sql = [[SELECT id, citizenid, text, importance, type, valence, shareable, archived, source_npc, created_at
        FROM samy_citizens_memories WHERE npc_id = ? AND ]]
    local params = { npcId }
    if citizenid and citizenid ~= '' then
        sql = sql .. 'citizenid = ?'
        params[2] = citizenid
    else
        sql = sql .. 'citizenid IS NULL'
    end
    if not includeArchived then sql = sql .. ' AND archived = 0' end
    sql = sql .. ' ORDER BY id DESC LIMIT 200'
    local rows = MySQL.query.await(sql, params) or {}
    local now = os.time()
    for _, row in ipairs(rows) do row.age = Utils.RelativeAge(now - (tonumber(row.created_at) or now)) end
    return rows
end

function Memory.Delete(id)
    return MySQL.update.await('DELETE FROM samy_citizens_memories WHERE id = ?', { id })
end

function Memory.DeletePair(npcId, citizenid)
    return MySQL.update.await('DELETE FROM samy_citizens_memories WHERE npc_id = ? AND citizenid = ?', { npcId, citizenid })
end
