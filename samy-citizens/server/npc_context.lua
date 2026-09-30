--[[
    KISA SÜRELİ KONUŞMA BAĞLAMI (RAM, veritabanına yazılmaz)
    Her NPC–karakter çifti için:
      { lastTopic, previousTopics, lastQuestion, lastAnswer, lastIntent, lastInteraction, mood = { value, untilAt },
        proposal = { kind, dest, label, at }, silencePrompted }
    Konuşma kapanıp kısa süre içinde yeniden açılırsa NPC son konuyu hatırlar:
      "Nerede çalışıyorsun?" -> "Benny's'de." ... (panel kapandı, açıldı) ... "Kaçta gidiyorsun?" -> iş saatini söyler.
    Config.Memory.ContextTTLMinutes kadar etkileşim olmayan bağlam silinir (RAM şişmez).
]]
local Utils = SC.Utils

local Context = {}
SC.Context = Context

local store = {}   -- key -> ctx

local function key(npcId, cid) return tostring(npcId) .. '|' .. tostring(cid) end

local function ttl()
    return ((Config.Memory and Config.Memory.ContextTTLMinutes) or 20) * 60
end

function Context.Get(npcId, cid, create)
    if not npcId or not cid then return nil end
    local k = key(npcId, cid)
    local c = store[k]
    local now = os.time()
    if c and now - (c.lastInteraction or 0) > ttl() then
        store[k] = nil
        c = nil
    end
    if not c and create ~= false then
        c = { previousTopics = {}, lastInteraction = now, createdAt = now }
        store[k] = c
    end
    return c
end

function Context.Peek(npcId, cid)
    return Context.Get(npcId, cid, false)
end

function Context.Touch(c)
    if c then c.lastInteraction = os.time() end
end

function Context.PushTopic(c, topic)
    if not c or not topic then return end
    if c.lastTopic and c.lastTopic ~= topic then
        table.insert(c.previousTopics, 1, c.lastTopic)
        local max = (Config.Memory and Config.Memory.ContextMaxTopics) or 5
        while #c.previousTopics > max do table.remove(c.previousTopics) end
    end
    c.lastTopic = topic
end

-- Konuşma turunu kaydet (yüz yüze ya da SMS)
function Context.RecordTurn(npcId, cid, playerText, reply, intent, topic)
    local c = Context.Get(npcId, cid)
    if not c then return end
    c.lastQuestion = Utils.Truncate(playerText or '', 160)
    c.lastAnswer = Utils.Truncate(reply or '', 200)
    c.lastIntent = intent
    if topic then Context.PushTopic(c, topic) end
    Context.Touch(c)
end

-- Oyuncunun davranışına göre NPC'nin ona karşı geçici ruh hâli (-100..100), minutes gerçek dk sürer
function Context.AddMoodTowards(npcId, cid, delta, minutes)
    local c = Context.Get(npcId, cid)
    if not c then return end
    local now = os.time()
    local cur = (c.mood and now < (c.mood.untilAt or 0)) and c.mood.value or 0
    c.mood = { value = Utils.Clamp(cur + (delta or 0), -100, 100), untilAt = now + (minutes or 20) * 60 }
    Context.Touch(c)
end

function Context.MoodTowards(npcId, cid)
    local c = Context.Peek(npcId, cid)
    if not c or not c.mood then return 0 end
    if os.time() >= (c.mood.untilAt or 0) then return 0 end
    return c.mood.value or 0
end

-- NPC teklifi (kahve/sahil/bar...) — Config.NPCEvents.ProposalTTL boyunca geçerli
function Context.SetProposal(npcId, cid, proposal)
    local c = Context.Get(npcId, cid)
    if not c then return end
    proposal.at = os.time()
    c.proposal = proposal
    Context.Touch(c)
end

function Context.TakeProposal(npcId, cid, peekOnly)
    local c = Context.Peek(npcId, cid)
    local p = c and c.proposal
    if not p then return nil end
    if os.time() - (p.at or 0) > ((Config.NPCEvents and Config.NPCEvents.ProposalTTL) or 120) then
        c.proposal = nil
        return nil
    end
    if not peekOnly then c.proposal = nil end
    return p
end

-- Periyodik temizlik (main.lua döngüsü)
function Context.Cleanup()
    local now = os.time()
    local limit = ttl()
    for k, c in pairs(store) do
        if now - (c.lastInteraction or 0) > limit then store[k] = nil end
    end
    if SC.Persona then SC.Persona.Cleanup() end
end

function Context.Count()
    local n = 0
    for _ in pairs(store) do n = n + 1 end
    return n
end
