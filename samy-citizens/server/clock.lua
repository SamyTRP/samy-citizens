--[[
    Saat & hava sağlayıcısı
    Tüm simülasyon "mutlak dakika" ile çalışır: gün * 1440 + günün dakikası.
    - game modu: 1 oyun dakikası = Config.GameMinuteMs gerçek ms; saat senkronu (weathersync) ile
      uyumlu olması için periyodik olarak export'lardan veya bir oyuncunun istemcisinden örneklenir.
    - real modu: Config.RealTimeUtcOffset saat dilimindeki gerçek saat.
]]
local Utils = SC.Utils
local Clock = {}
SC.Clock = Clock

local KVP_OFFSET = 'samy_citizens:clock_offset'
Clock.offset = GetResourceKvpInt(KVP_OFFSET) or 0
Clock.weather = 'CLEAR'
Clock.source = 'internal'
Clock.lastSampleAt = 0

local baseOs = os.time()
local baseTimer = GetGameTimer()

local function nowMs()
    return baseOs * 1000 + (GetGameTimer() - baseTimer)
end

local function rawAbs()
    if Config.TimeMode == 'real' then
        return math.floor((os.time() + (Config.RealTimeUtcOffset or 0) * 3600) / 60)
    end
    return math.floor(nowMs() / (Config.GameMinuteMs or 2000))
end

function Clock.Now()
    if Config.TimeMode == 'real' then return rawAbs() end
    return rawAbs() + Clock.offset
end

function Clock.Day(abs)
    return math.floor((abs or Clock.Now()) / 1440)
end

function Clock.MinuteOfDay(abs)
    return math.floor(abs or Clock.Now()) % 1440
end

-- 1 = Pazartesi ... 7 = Pazar
function Clock.Weekday(abs)
    abs = abs or Clock.Now()
    if Config.TimeMode == 'real' then
        local unix = math.floor(abs * 60) - (Config.RealTimeUtcOffset or 0) * 3600
        local t = os.date('!*t', unix + (Config.RealTimeUtcOffset or 0) * 3600)
        return ((t.wday + 5) % 7) + 1
    end
    return ((Clock.Day(abs) + (Config.WeekStartOffset or 0)) % 7) + 1
end

function Clock.WeekdayForDay(day)
    return Clock.Weekday(day * 1440 + 720)
end

function Clock.IsRaining()
    return Config.RainWeathers[Clock.weather] == true
end

function Clock.WeatherLabel()
    return L('weather_' .. string.lower(Clock.weather or 'clear'))
end

function Clock.DayName(abs)
    local names = LT('weekdays') or {}
    return names[Clock.Weekday(abs)] or '?'
end

function Clock.Describe(abs)
    abs = abs or Clock.Now()
    return ('%s %s'):format(Clock.DayName(abs), Utils.FormatTime(Clock.MinuteOfDay(abs)))
end

-- Oyun dakikası -> gerçek saniye
function Clock.GameMinutesToRealSeconds(minutes)
    if Config.TimeMode == 'real' then return minutes * 60 end
    return minutes * (Config.GameMinuteMs or 2000) / 1000
end

function Clock.RealSecondsToGameMinutes(seconds)
    if Config.TimeMode == 'real' then return seconds / 60 end
    return seconds * 1000 / (Config.GameMinuteMs or 2000)
end

-- Gerçek tarih anahtarı (günlük limitler için)
function Clock.RealDateKey()
    return os.date('!%Y-%m-%d', os.time() + (Config.RealTimeUtcOffset or 0) * 3600)
end

-- İlişki gün birimi ('real' veya 'game')
function Clock.RelationshipDayKey()
    if (Config.Relationship.DayUnit or 'real') == 'game' then
        return 'g' .. tostring(Clock.Day())
    end
    return Clock.RealDateKey()
end

-- ---------------------------------------------------------------------
-- Örnekleme
-- ---------------------------------------------------------------------
function Clock.ApplySample(hour, minute, weather)
    if weather and type(weather) == 'string' and weather ~= '' then
        Clock.weather = weather:upper()
    end
    if Config.TimeMode == 'real' then return end
    if not hour or not minute then return end
    local target = (math.floor(hour) % 24) * 60 + (math.floor(minute) % 60)
    local cur = (rawAbs() + Clock.offset) % 1440
    local diff = target - cur
    if diff > 720 then diff = diff - 1440 elseif diff < -720 then diff = diff + 1440 end
    if diff ~= 0 then
        Clock.offset = Clock.offset + diff
        if math.abs(diff) > 2 then
            SetResourceKvpInt(KVP_OFFSET, Clock.offset)
            SC.DebugPrint(('saat düzeltildi %+d dk -> %s'):format(diff, Clock.Describe()))
        end
    end
    Clock.lastSampleAt = os.time()
end

local function tryExports()
    -- qb-weathersync
    if GetResourceState('qb-weathersync') == 'started' then
        local ok, h, m = pcall(function() return exports['qb-weathersync']:getTime() end)
        local okW, w = pcall(function() return exports['qb-weathersync']:getWeatherState() end)
        if ok and type(h) == 'number' then
            Clock.source = 'qb-weathersync'
            Clock.ApplySample(h, m, okW and w or nil)
            return true
        end
    end
    -- Renewed-Weathersync ve GlobalState yayınlayan benzerleri
    local gt = GlobalState.currentTime
    if type(gt) == 'table' and tonumber(gt.hour) then
        local weather = GlobalState.weather
        if type(weather) == 'table' then weather = weather.weather end
        Clock.source = 'globalstate'
        Clock.ApplySample(tonumber(gt.hour), tonumber(gt.minute) or 0, type(weather) == 'string' and weather or nil)
        return true
    end
    return false
end

local function sampleFromClient()
    local players = GetPlayers()
    if #players == 0 then return false end
    local src = tonumber(players[math.random(1, #players)])
    local p = promise.new()
    local done = false
    lib.callback('samy-citizens:sampleWorld', src, function(data)
        if done then return end
        done = true
        p:resolve(data)
    end)
    SetTimeout(4000, function()
        if not done then
            done = true
            p:resolve(nil)
        end
    end)
    local data = Citizen.Await(p)
    if type(data) ~= 'table' then return false end
    Clock.source = 'client'
    Clock.ApplySample(tonumber(data.h), tonumber(data.m), type(data.w) == 'string' and data.w or nil)
    return true
end

function Clock.Sample()
    local src = Config.TimeSource or 'auto'
    if src == 'internal' and Config.TimeMode ~= 'real' then
        -- sadece hava için örnekle
        if GetPlayers()[1] then
            local players = GetPlayers()
            local target = tonumber(players[math.random(1, #players)])
            lib.callback('samy-citizens:sampleWorld', target, function(data)
                if type(data) == 'table' and type(data.w) == 'string' then Clock.weather = data.w:upper() end
            end)
        end
        return
    end
    if src == 'auto' and tryExports() then return end
    sampleFromClient()
end

CreateThread(function()
    Wait(3000)
    while true do
        local ok, err = pcall(Clock.Sample)
        if not ok then SC.DebugPrint('saat örnekleme hatası', tostring(err)) end
        Wait(Config.ClockSampleIntervalMs or 30000)
    end
end)
