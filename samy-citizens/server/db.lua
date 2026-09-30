local Utils = SC.Utils
local DB = {}
SC.DB = DB

local RESOURCE = GetCurrentResourceName()

-- ---------------------------------------------------------------------
-- Şema: sql/install.sql dosyasını ifade ifade çalıştırır
-- ---------------------------------------------------------------------
function DB.Migrate()
    local sql = LoadResourceFile(RESOURCE, 'sql/install.sql')
    if not sql then
        print('^1[samy-citizens] sql/install.sql okunamadı!^7')
        return false
    end
    -- satır yorumlarını temizle
    local lines = {}
    for line in (sql .. '\n'):gmatch('(.-)\r?\n') do
        if not line:match('^%s*%-%-') then lines[#lines + 1] = line end
    end
    sql = table.concat(lines, '\n')
    local count = 0
    for stmt in sql:gmatch('([^;]+);') do
        stmt = Utils.Trim(stmt)
        if stmt ~= '' then
            local ok, err = pcall(MySQL.query.await, stmt)
            if not ok then
                print(('^1[samy-citizens] migrate hatası: %s^7'):format(tostring(err)))
                return false
            end
            count = count + 1
        end
    end
    SC.DebugPrint('migrate tamam, ifade sayısı:', count)
    return true
end

-- Sonraki sürümlerde eklenen sütunlar (eski kurulumları yükseltir; MySQL 8 ve MariaDB uyumlu)
local UPGRADE_COLUMNS = {
    { 'samy_citizens_relationships', 'npc_name_shown', 'TINYINT(1) NOT NULL DEFAULT 0' },
    { 'samy_citizens_relationships', 'facts', 'LONGTEXT NULL' },
    { 'samy_citizens_residents', 'acquaintances', 'LONGTEXT NULL' },
    { 'samy_citizens_residents', 'topics', 'LONGTEXT NULL' },
    { 'samy_citizens_memories', 'data', 'TEXT NULL' },
    -- v3: yaşayan NPC katmanı
    { 'samy_citizens_residents', 'profile', 'LONGTEXT NULL' },
    { 'samy_citizens_relationships', 'xp', 'INT NOT NULL DEFAULT 0' },
    { 'samy_citizens_relationships', 'romance', "VARCHAR(16) NOT NULL DEFAULT 'none'" },
    { 'samy_citizens_relationships', 'first_met', 'BIGINT NOT NULL DEFAULT 0' },
    { 'samy_citizens_relationships', 'last_contact', 'BIGINT NOT NULL DEFAULT 0' },
    { 'samy_citizens_relationships', 'daily_xp', 'INT NOT NULL DEFAULT 0' },
    { 'samy_citizens_relationships', 'stats', 'LONGTEXT NULL' },
}

local UPGRADE_INDEXES = {
    { 'samy_citizens_relationships', 'idx_npc_phone', '(`npc_id`, `phone_known`)' },
    { 'samy_citizens_relationships', 'idx_citizen_romance', '(`citizenid`, `romance`)' },
}

-- Sütun yeni eklendiyse çalışan tek seferlik veri dönüşümleri (eski kurulumlar aşama kaybetmesin)
local function backfill(tbl, col)
    if tbl ~= 'samy_citizens_relationships' then return end
    if col == 'xp' then
        local levels = {}
        for _, lv in ipairs((Config.Relationship.XP and Config.Relationship.XP.Levels) or {}) do levels[lv.id] = math.floor(lv.min or 0) end
        MySQL.query.await([[UPDATE samy_citizens_relationships SET xp = CASE stage
            WHEN 'acquaintance' THEN ? WHEN 'friend' THEN ? WHEN 'close_friend' THEN ? ELSE 0 END WHERE xp = 0]],
            { levels.acquaintance or 100, levels.friend or 300, levels.close_friend or 700 })
        print('^3[samy-citizens] mevcut ilişkilere aşamalarına göre XP verildi^7')
    elseif col == 'first_met' then
        MySQL.query.await('UPDATE samy_citizens_relationships SET first_met = UNIX_TIMESTAMP(created_at) WHERE first_met = 0')
    end
end

function DB.EnsureColumns()
    for _, c in ipairs(UPGRADE_COLUMNS) do
        local exists = MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.COLUMNS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?]], { c[1], c[2] })
        if (tonumber(exists) or 0) == 0 then
            MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `%s` %s'):format(c[1], c[2], c[3]))
            print(('^3[samy-citizens] sütun eklendi: %s.%s^7'):format(c[1], c[2]))
            local ok, err = pcall(backfill, c[1], c[2])
            if not ok then print(('^1[samy-citizens] veri dönüşümü hatası (%s): %s^7'):format(c[2], tostring(err))) end
        end
    end
    for _, ix in ipairs(UPGRADE_INDEXES) do
        local exists = MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.STATISTICS
            WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND INDEX_NAME = ?]], { ix[1], ix[2] })
        if (tonumber(exists) or 0) == 0 then
            local ok, err = pcall(MySQL.query.await, ('ALTER TABLE `%s` ADD INDEX `%s` %s'):format(ix[1], ix[2], ix[3]))
            if ok then
                print(('^3[samy-citizens] indeks eklendi: %s.%s^7'):format(ix[1], ix[2]))
            else
                print(('^1[samy-citizens] indeks eklenemedi (%s): %s^7'):format(ix[2], tostring(err)))
            end
        end
    end
end

-- ---------------------------------------------------------------------
-- Dönüştürücüler
-- ---------------------------------------------------------------------
local function encodeLocationData(loc)
    local points = {}
    for i, p in ipairs(loc.points or {}) do
        points[i] = { coords = Utils.VecToTable(p.coords), scenario = p.scenario, tags = p.tags or {} }
    end
    return json.encode({
        door = Utils.VecToTable(loc.door),
        parking = loc.parking and Utils.VecToTable(loc.parking) or nil,
        points = points,
        hours = loc.hours,
        aliases = loc.aliases or {},
    })
end
DB.EncodeLocationData = encodeLocationData

local function decodeLocation(row)
    local data = Utils.JsonDecode(row.data) or {}
    local loc = {
        id = row.id,
        label = row.label,
        type = row.type,
        area = row.area,
        public = row.public == 1 or row.public == true,
        door = Utils.ToVec4(data.door or { x = 0, y = 0, z = 0 }),
        parking = data.parking and Utils.ToVec4(data.parking) or nil,
        hours = data.hours,
        aliases = data.aliases or {},
        points = {},
    }
    for i, p in ipairs(data.points or {}) do
        loc.points[i] = { coords = Utils.ToVec4(p.coords), scenario = p.scenario, tags = p.tags or {} }
    end
    return loc
end
DB.DecodeLocation = decodeLocation

local function genPhone(id, taken)
    local pattern = Config.Phone.NumberPattern or '555#####'
    local rng = Utils.Rng(Utils.Hash(id))
    for _ = 1, 50 do
        local num = pattern:gsub('#', function() return tostring(rng(0, 9)) end)
        if not taken[num] then
            taken[num] = true
            return num
        end
    end
    return pattern:gsub('#', '0') .. tostring(math.random(10, 99))
end
DB.GeneratePhone = genPhone

-- NOT: oxmysql konumsal parametre dizilerinde nil "delik" oluşturur; bu yüzden NULL yerine '' / 'null' yazılır
local function s(v) if v == nil then return '' end return v end
DB.S = s

local function nilIfEmpty(v)
    if v == nil or v == '' then return nil end
    return v
end
DB.NilIfEmpty = nilIfEmpty

local function residentParams(r, phone)
    return {
        r.id, r.firstname, r.lastname, r.age or 30, r.gender or 'male', r.model,
        r.appearance and json.encode(r.appearance) or 'null',
        s(r.voice_id),
        json.encode(r.personality or {}),
        r.backstory or '',
        json.encode(r.job or {}),
        s(r.homeId),
        r.vehicle and json.encode(r.vehicle) or 'null',
        json.encode(r.favorite_places or {}),
        json.encode(r.acquaintances or {}),
        s(r.routine_id),
        s(phone),
        json.encode(r.topics or {}),
        json.encode(r.profile or {}),
    }
end

-- ---------------------------------------------------------------------
-- Tohumlama: veritabanında olmayan örnek kayıtları ekler (mevcut düzenlemeler korunur)
-- ---------------------------------------------------------------------
function DB.Seed()
    for _, loc in ipairs(SCData.Locations or {}) do
        MySQL.prepare.await('INSERT IGNORE INTO samy_citizens_locations (id, label, type, area, public, data) VALUES (?, ?, ?, ?, ?, ?)', {
            loc.id, loc.label, loc.type or 'other', s(loc.area), loc.public == false and 0 or 1, encodeLocationData(loc),
        })
    end
    for id, routine in pairs(SCData.Routines or {}) do
        MySQL.prepare.await('INSERT IGNORE INTO samy_citizens_routines (id, label, data) VALUES (?, ?, ?)', {
            id, routine.label or id, json.encode({ workday = routine.workday or {}, offday = routine.offday or {}, days = routine.days }),
        })
    end
    local taken = {}
    local rows = MySQL.query.await('SELECT phone_number FROM samy_citizens_residents WHERE phone_number IS NOT NULL') or {}
    for _, row in ipairs(rows) do taken[row.phone_number] = true end
    for _, r in ipairs(SCData.Residents or {}) do
        local exists = MySQL.scalar.await('SELECT 1 FROM samy_citizens_residents WHERE id = ?', { r.id })
        if not exists then
            local phone = r.phone_number or genPhone(r.id, taken)
            MySQL.prepare.await([[INSERT IGNORE INTO samy_citizens_residents
                (id, firstname, lastname, age, gender, model, appearance, voice_id, personality, backstory, job, home_id,
                 vehicle, favorite_places, acquaintances, routine_id, phone_number, topics, profile)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], residentParams(r, phone))
        else
            if r.topics then
                -- önceki sürümden kalan kayıtlara konuşma konularını ekle (elle düzenlenmişse dokunma)
                MySQL.prepare.await([[UPDATE samy_citizens_residents SET topics = ?
                    WHERE id = ? AND (topics IS NULL OR topics = '' OR topics = 'null' OR topics = '[]' OR topics = '{}')]],
                    { json.encode(r.topics), r.id })
            end
            if r.profile then
                -- v3 profili (kişilik puanları, sevdikleri, rutin alternatifleri...) boş kayıtlara eklenir
                MySQL.prepare.await([[UPDATE samy_citizens_residents SET profile = ?
                    WHERE id = ? AND (profile IS NULL OR profile = '' OR profile = 'null' OR profile = '[]' OR profile = '{}')]],
                    { json.encode(r.profile), r.id })
            end
        end
    end
end

-- ---------------------------------------------------------------------
-- Yükleme
-- ---------------------------------------------------------------------
function DB.LoadLocations()
    local out = {}
    for _, row in ipairs(MySQL.query.await('SELECT * FROM samy_citizens_locations') or {}) do
        local loc = decodeLocation(row)
        out[loc.id] = loc
    end
    return out
end

function DB.LoadRoutines()
    local out = {}
    for _, row in ipairs(MySQL.query.await('SELECT * FROM samy_citizens_routines') or {}) do
        local data = Utils.JsonDecode(row.data) or {}
        out[row.id] = { id = row.id, label = row.label, workday = data.workday or {}, offday = data.offday or {}, days = data.days }
    end
    return out
end

function DB.DecodeResident(row)
    return {
        id = row.id,
        firstname = row.firstname,
        lastname = row.lastname,
        age = row.age,
        gender = row.gender,
        model = row.model,
        appearance = Utils.JsonDecode(row.appearance),
        voice_id = nilIfEmpty(row.voice_id),
        personality = Utils.JsonDecode(row.personality) or {},
        backstory = row.backstory or '',
        job = Utils.JsonDecode(row.job) or {},
        homeId = nilIfEmpty(row.home_id),
        vehicle = Utils.JsonDecode(row.vehicle),
        favorite_places = Utils.JsonDecode(row.favorite_places) or {},
        acquaintances = Utils.JsonDecode(row.acquaintances) or {},
        topics = type(Utils.JsonDecode(row.topics)) == 'table' and Utils.JsonDecode(row.topics) or {},
        profile = type(Utils.JsonDecode(row.profile)) == 'table' and Utils.JsonDecode(row.profile) or {},
        routine_id = nilIfEmpty(row.routine_id),
        phone_number = nilIfEmpty(row.phone_number),
        needs = Utils.JsonDecode(row.needs),
        mood = row.mood or 0,
        mood_reason = nilIfEmpty(row.mood_reason),
        status = row.status or 'alive',
        status_until = tonumber(row.status_until) or 0,
        savedState = Utils.JsonDecode(row.state),
        enabled = row.enabled == 1 or row.enabled == true,
    }
end

function DB.LoadResidents()
    local out = {}
    for _, row in ipairs(MySQL.query.await('SELECT * FROM samy_citizens_residents') or {}) do
        out[#out + 1] = DB.DecodeResident(row)
    end
    return out
end

-- ---------------------------------------------------------------------
-- Yazma
-- ---------------------------------------------------------------------
-- Sakinlerin dinamik durumunu toplu yazar (async, kaynak kapanırken de güvenli)
function DB.SaveResidentStates(list, sync)
    if #list == 0 then return end
    local queries = {}
    for _, item in ipairs(list) do
        queries[#queries + 1] = {
            query = 'UPDATE samy_citizens_residents SET needs = ?, mood = ?, mood_reason = ?, status = ?, status_until = ?, state = ?, appearance = ? WHERE id = ?',
            values = { item.needs, item.mood, s(item.mood_reason), item.status, item.status_until, item.state, item.appearance or 'null', item.id },
        }
    end
    if sync then
        MySQL.transaction.await(queries)
    else
        MySQL.transaction(queries)
    end
end

function DB.UpsertResident(r)
    local params = residentParams(r, r.phone_number)
    params[#params + 1] = r.enabled == false and 0 or 1
    return MySQL.prepare.await([[INSERT INTO samy_citizens_residents
        (id, firstname, lastname, age, gender, model, appearance, voice_id, personality, backstory, job, home_id,
         vehicle, favorite_places, acquaintances, routine_id, phone_number, topics, profile, enabled)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE firstname = VALUES(firstname), lastname = VALUES(lastname), age = VALUES(age),
        gender = VALUES(gender), model = VALUES(model), appearance = VALUES(appearance), voice_id = VALUES(voice_id),
        personality = VALUES(personality), backstory = VALUES(backstory), job = VALUES(job), home_id = VALUES(home_id),
        vehicle = VALUES(vehicle), favorite_places = VALUES(favorite_places), acquaintances = VALUES(acquaintances),
        routine_id = VALUES(routine_id), phone_number = VALUES(phone_number), topics = VALUES(topics), profile = VALUES(profile),
        enabled = VALUES(enabled)]], params)
end

function DB.UpsertLocation(loc)
    return MySQL.prepare.await([[INSERT INTO samy_citizens_locations (id, label, type, area, public, data) VALUES (?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE label = VALUES(label), type = VALUES(type), area = VALUES(area), public = VALUES(public), data = VALUES(data)]], {
        loc.id, loc.label, loc.type or 'other', s(loc.area), loc.public == false and 0 or 1, encodeLocationData(loc),
    })
end

function DB.UpsertRoutine(routine)
    return MySQL.prepare.await([[INSERT INTO samy_citizens_routines (id, label, data) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE label = VALUES(label), data = VALUES(data)]], {
        routine.id, routine.label or routine.id, json.encode({ workday = routine.workday or {}, offday = routine.offday or {}, days = routine.days }),
    })
end

-- Çok satırlı INSERT üretir: rows = { {v1, v2, ...}, ... }
function DB.InsertMany(tableName, columns, rows, cb)
    if #rows == 0 then return end
    local placeholders = '(' .. string.rep('?', #columns, ', ') .. ')'
    local parts, params = {}, {}
    for _, row in ipairs(rows) do
        parts[#parts + 1] = placeholders
        for i = 1, #columns do params[#params + 1] = row[i] end
    end
    local sql = ('INSERT INTO %s (%s) VALUES %s'):format(tableName, table.concat(columns, ', '), table.concat(parts, ', '))
    MySQL.query(sql, params, cb)
end
