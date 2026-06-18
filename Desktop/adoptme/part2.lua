-- AdoptHub part2: farm logic
local S = (...)

local Config      = S.Config
local Remotes     = S.Remotes
local setStatus   = S.setStatus
local safewait    = S.safewait
local jitter      = S.jitter
local tryCall     = S.tryCall
local retryCall   = S.retryCall
local normalizeTaskData = S.normalizeTaskData
local classifyQuest    = S.classifyQuest
local pushTask         = S.pushTask
local popTask          = S.popTask
local markTaskDone     = S.markTaskDone
local getTaskKey       = S.getTaskKey
local dedupeTask       = S.dedupeTask

-- ============================================================
-- DAILY LOGIN CLAIM
-- ============================================================
local function claimDailyLogin()
    setStatus("claiming daily login...")
    local ok1 = retryCall(Remotes.ClaimDailyReward, 3)
    task.wait(0.5)
    local ok2 = retryCall(Remotes.ClaimStarReward, 3)
    if ok1 or ok2 then
        setStatus("daily login claimed!")
    else
        setStatus("daily login: nothing to claim")
    end
end

-- ============================================================
-- QUEST HELPERS
-- ============================================================
local recentQuestSignals = {}

local function rememberQuestSignal(name)
    if not name then return end
    recentQuestSignals[tostring(name):lower()] = tick()
end

local function hasRecentQuestSignal(name, window)
    local ts = recentQuestSignals[tostring(name):lower()]
    return ts and (tick() - ts <= (window or 120)) or false
end

-- ============================================================
-- QUEST ACTIONS
-- ============================================================
local function progressPetCare(taskInfo)
    setStatus("quest: pet care")
    local tries = 3
    if taskInfo and taskInfo.progress and taskInfo.goal and taskInfo.goal > taskInfo.progress then
        tries = math.clamp(taskInfo.goal - taskInfo.progress, 1, 6)
    end
    for _ = 1, tries do
        tryCall(Remotes.ProgressPetAilment)
        task.wait(jitter(0.9))
    end
    return true
end

local function runPizzaQuest()
    setStatus("quest: pizza")
    tryCall(Remotes.PizzaNav)
    task.wait(jitter(2))
    for _ = 1, 6 do
        tryCall(Remotes.PizzaClaim)
        task.wait(jitter(1.25))
    end
    return true
end

local function runMinigameQuest()
    setStatus("quest: minigame")
    tryCall(Remotes.MinigameJoin)
    task.wait(jitter(1))
    tryCall(Remotes.MicrogameStart)
    return true
end

local function runCollectQuest()
    setStatus("quest: collect bucks")
    tryCall(Remotes.PayCollect)
    return true
end

local function runTeleportQuest(task)
    setStatus("quest: teleport")
    local target = task and (task.location or task.destination or task.place or task.zone)
    if target then
        tryCall(Remotes.TeleToLocation, target)
    else
        tryCall(Remotes.TeleToLocation)
    end
    return true
end

local questHandlers = {
    pet = progressPetCare,
    ailment = progressPetCare,
    pizza = runPizzaQuest,
    minigame = runMinigameQuest,
    collect = runCollectQuest,
    teleport = runTeleportQuest,
}

local function handleTask(taskData)
    local task = normalizeTaskData(taskData)
    if not task then return false end

    local key = getTaskKey(task)
    if key and dedupeTask(key, 2.5) then return false end

    local kind = classifyQuest(task)
    local handler = questHandlers[kind]
    if not handler then
        setStatus("quest unknown: " .. tostring(task.rawType or task.name or task.id or kind))
        return false
    end

    local ok = handler(task)
    if ok and key then
        markTaskDone(key)
    end
    return ok
end

local function queueTaskList(list)
    if type(list) ~= "table" then return end
    for _, value in ipairs(list) do
        local task = normalizeTaskData(value)
        if task then
            pushTask(task)
        end
    end
end

-- Read any payload style coming from remote events and enqueue tasks
local function inspectDailyPayload(...)
    local args = {...}
    for _, value in ipairs(args) do
        if type(value) == "table" then
            if value.tasks then queueTaskList(value.tasks) end
            if value.quests then queueTaskList(value.quests) end
            if value.entries then queueTaskList(value.entries) end
            if value.active then queueTaskList(value.active) end
            if value.daily_quests then queueTaskList(value.daily_quests) end
            if value.kind or value.type or value.quest_type or value.questType or value.id or value.name then
                local task = normalizeTaskData(value)
                if task then
                    pushTask(task)
                end
            end
        end
    end
end

local function inspectDataContainer(container)
    if type(container) ~= "table" then return end
    for key, value in pairs(container) do
        local lowerKey = tostring(key):lower()
        if lowerKey:find("daily") or lowerKey:find("quest") then
            if type(value) == "table" then
                inspectDailyPayload(value)
                queueTaskList(value)
                if value.tasks then queueTaskList(value.tasks) end
                if value.quests then queueTaskList(value.quests) end
                if value.entries then queueTaskList(value.entries) end
                if value.active then queueTaskList(value.active) end
                if value.daily_quests then queueTaskList(value.daily_quests) end
            end
        end
    end
end

local function hookDailies()
    if Remotes.DailiesEvent2 then
        Remotes.DailiesEvent2.OnClientEvent:Connect(function(...)
            if not Config.AutoDaily then return end
            inspectDailyPayload(...)
        end)
    end

    if Remotes.DailiesEvent1 then
        Remotes.DailiesEvent1.OnClientEvent:Connect(function(...)
            if not Config.AutoDaily then return end
            inspectDailyPayload(...)
        end)
    end

    if Remotes.DataInit then
        Remotes.DataInit.OnClientEvent:Connect(function(data)
            if not Config.AutoDaily then return end
            inspectDataContainer(data)
        end)
    end

    if Remotes.DataChanged then
        Remotes.DataChanged.OnClientEvent:Connect(function(...)
            if not Config.AutoDaily then return end
            inspectDailyPayload(...)
            for _, value in ipairs({...}) do
                if type(value) == "table" then
                    inspectDataContainer(value)
                end
            end
        end)
    end

    if Remotes.DataPartial then
        Remotes.DataPartial.OnClientEvent:Connect(function(...)
            if not Config.AutoDaily then return end
            inspectDailyPayload(...)
            for _, value in ipairs({...}) do
                if type(value) == "table" then
                    inspectDataContainer(value)
                end
            end
        end)
    end

    if Remotes.PetAilmentCompleted then
        Remotes.PetAilmentCompleted.OnClientEvent:Connect(function(_, ailmentName)
            rememberQuestSignal(ailmentName)
            rememberQuestSignal("pet")
            rememberQuestSignal("ailment")
        end)
    end

    if Remotes.PetProgressed then
        Remotes.PetProgressed.OnClientEvent:Connect(function()
            rememberQuestSignal("pet_progressed")
            rememberQuestSignal("level_up")
        end)
    end
end

-- fallback trigger from real-time events when remote event shape for quests isn't verbose enough
local function pumpFallbackQuests()
    if hasRecentQuestSignal("pet", 120) or hasRecentQuestSignal("ailment", 120) then
        pushTask({
            id = "fallback_pet_care",
            name = "fallback_pet_care",
            kind = "pet",
            rawType = "pet_care",
            progress = 0,
            goal = 1,
        })
    end

    if hasRecentQuestSignal("level_up", 180) then
        pushTask({
            id = "fallback_level_up",
            name = "fallback_level_up",
            kind = "pet",
            rawType = "level_up",
            progress = 0,
            goal = 1,
        })
    end
end

local function runDailyLoop()
    task.spawn(function()
        while _G.AdoptHub do
            if Config.AutoDaily then
                pumpFallbackQuests()
                local taskData = popTask()
                if taskData then
                    handleTask(taskData)
                    task.wait(jitter(1))
                else
                    setStatus("auto quest: waiting")
                    safewait(5)
                end
            else
                task.wait(1)
            end
        end
    end)
end

-- ============================================================
-- AUTO COLLECT BUCKS
-- ============================================================
local function runCollectLoop()
    task.spawn(function()
        while _G.AdoptHub do
            if Config.AutoCollect then
                setStatus("collecting bucks...")
                tryCall(Remotes.PayCollect)
                safewait(jitter(60))
            else
                task.wait(1)
            end
        end
    end)
end

-- ============================================================
-- PIZZA JOB FARM
-- ============================================================
local function runPizzaLoop()
    task.spawn(function()
        while _G.AdoptHub do
            if Config.AutoPizza then
                setStatus("pizza job: navigating...")
                tryCall(Remotes.PizzaNav)
                safewait(jitter(2))
                if Config.AutoPizza then
                    setStatus("pizza job: claiming dough...")
                    for _ = 1, 8 do
                        if not Config.AutoPizza or not _G.AdoptHub then break end
                        tryCall(Remotes.PizzaClaim)
                        task.wait(jitter(1.2))
                    end
                end
                safewait(jitter(5))
            else
                task.wait(1)
            end
        end
    end)
end

-- ============================================================
-- PET CARE LOOP (Ailments API passive)
-- ============================================================
local function runPetCareLoop()
    task.spawn(function()
        while _G.AdoptHub do
            if Config.AutoFarm then
                for _ = 1, 3 do
                    tryCall(Remotes.ProgressPetAilment)
                    task.wait(jitter(0.8))
                end
                safewait(jitter(20))
            else
                task.wait(1)
            end
        end
    end)
end

-- ============================================================
-- INIT
-- ============================================================
print("[AdoptHub] Hooking dailies...")
print("[AdoptHub] DailiesEvent1:", Remotes.DailiesEvent1)
print("[AdoptHub] DailiesEvent2:", Remotes.DailiesEvent2)
hookDailies()
runDailyLoop()
runCollectLoop()
runPizzaLoop()
runPetCareLoop()

S.claimDailyLogin = claimDailyLogin
S.activeTasks = S.activeTasks or {}
S.handleTask = handleTask

return S
