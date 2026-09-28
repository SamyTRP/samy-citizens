local Utils = SC.Utils
local Log = {}
SC.Log = Log

local convoQueue = {}
local discordQueue = {}
local webhook = GetConvar('samy_citizens_webhook', '')

local speakerIcons = { player = '🧑', npc = '🗣️', system = '⚙️' }

-- Konuşma/SMS satırı: DB'ye ve (varsa) Discord'a gruplanarak yazılır
function Log.Conversation(npcId, citizenid, charName, channel, speaker, message, meta)
    if Config.Logging.Conversations then
        convoQueue[#convoQueue + 1] = {
            npcId, citizenid or '', charName or '', channel or 'talk', speaker, Utils.Truncate(message or '', 1000),
            meta and json.encode(meta) or '',
        }
    end
    if Config.Logging.Discord and webhook ~= '' then
        discordQueue[#discordQueue + 1] = ('%s **%s** `%s` [%s] %s'):format(
            speakerIcons[speaker] or '•',
            speaker == 'npc' and npcId or (charName ~= '' and charName or citizenid or '?'),
            channel or 'talk',
            speaker == 'npc' and ('→ ' .. (charName or '?')) or ('→ ' .. npcId),
            Utils.Truncate(message or '', 300)
        )
    end
end

-- Moderasyon / yönetim olayları
function Log.Event(title, text)
    print(('^3[samy-citizens] %s: %s^7'):format(title, text))
    if Config.Logging.Discord and webhook ~= '' then
        discordQueue[#discordQueue + 1] = ('⚠️ **%s** %s'):format(title, Utils.Truncate(text, 500))
    end
end

local function postDiscord(lines)
    local desc = table.concat(lines, '\n')
    PerformHttpRequest(webhook, function(status)
        if status and status >= 400 then
            SC.DebugPrint('discord webhook hata kodu', status)
        end
    end, 'POST', json.encode({
        username = 'samy-citizens',
        embeds = { {
            title = 'Sakin konuşmaları',
            description = Utils.Truncate(desc, 3900),
            color = 3447003,
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        } },
    }), { ['Content-Type'] = 'application/json' })
end

function Log.Flush()
    if #convoQueue > 0 then
        local rows = convoQueue
        convoQueue = {}
        SC.DB.InsertMany('samy_citizens_conversations',
            { 'npc_id', 'citizenid', 'char_name', 'channel', 'speaker', 'message', 'meta' }, rows)
    end
    if #discordQueue > 0 and webhook ~= '' then
        local lines = discordQueue
        discordQueue = {}
        local chunk, size = {}, 0
        for _, line in ipairs(lines) do
            if size + #line > 3500 and #chunk > 0 then
                postDiscord(chunk)
                chunk, size = {}, 0
            end
            chunk[#chunk + 1] = line
            size = size + #line + 1
        end
        if #chunk > 0 then postDiscord(chunk) end
    end
end

CreateThread(function()
    while true do
        Wait(Config.Logging.DiscordFlushMs or 10000)
        Log.Flush()
    end
end)
