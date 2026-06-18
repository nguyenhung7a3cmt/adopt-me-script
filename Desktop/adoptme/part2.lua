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
local setDebugStep     = S.setDebugStep or function() end
local setDebugError    = S.setDebugError or function() end

-- ============================================================
-- DAILY LOGIN CLAIM
-- ============================================================
local function claimDailyLogin()
    setDebugStep("daily_login", "claiming rewards")
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

local PET_AILMENTS = {"hungry", "sleepy", "dirty", "sick", "thirsty", "bored", "walk", "toilet"}

local function findActivePet()
    setDebugStep("find_pet", "searching Workspace.Pets")
    local pets = workspace:FindFirstChild("Pets")
    if not pets then return nil end

    local fallback = nil
    for _, pet in ipairs(pets:GetChildren()) do
        if pet:IsA("Model") then
            fallback = fallback or pet
            local owner = pet:FindFirstChild("Owner") or pet:FindFirstChild("owner")
            if owner and owner.Value == S.lp then
                return pet
            end
            local player = pet:GetAttribute("Owner") or pet:GetAttribute("owner") or pet:GetAttribute("Player")
            if player == S.lp.Name or player == S.lp.UserId then
                return pet
            end
        end
    end
    return fallback
end

local function sendPetReaction(pet, reactionName)
    if not Remotes.ReplicateReactions or not pet then
        setDebugStep("reaction", "missing remote or pet")
        return false
    end
    local payload = {}
    payload[reactionName] = true
    local ok, res = tryCall(Remotes.ReplicateReactions, S.lp, pet, payload)
    if not ok then
        setDebugError("ReplicateActiveReactions failed: " .. tostring(res))
        ok, res = tryCall(Remotes.ReplicateReactions, pet, payload)
        if not ok then
            setDebugError("ReplicateActiveReactions alt failed: " .. tostring(res))
        end
    end
    return ok
end

local function focusActivePet()
    setDebugStep("focus_pet", "trying focus active pet")
    local pet = findActivePet()
    if pet then
        setDebugStep("focus_pet", pet:GetFullName())
        local ok, res = tryCall(Remotes.FocusPet, S.lp, pet)
        if not ok then
            setDebugError("FocusPet failed: " .. tostring(res))
            ok, res = tryCall(Remotes.FocusPet, pet)
            if not ok then
                setDebugError("FocusPet alt failed: " .. tostring(res))
            end
        end
        task.wait(0.15)
    end
    return pet
end

-- ============================================================
-- QUEST ACTIONS
-- ============================================================
local function progressPetCare(taskInfo)
    setDebugStep("pet_care", "starting care loop")
    setStatus("pet care: working needs")
    local pet = focusActivePet()
    local tries = 4
    if taskInfo and taskInfo.progress and taskInfo.goal and taskInfo.goal > taskInfo.progress then
        tries = math.clamp(taskInfo.goal - taskInfo.progress, 1, 8)
    end

    local anySuccess = false
    if pet and sendPetReaction(pet, "NavigateReaction") then
        anySuccess = true
    end
    if pet then
        local okReset, resReset = tryCall(Remotes.ResetPetNetwork, S.lp, pet)
        if not okReset then
            okReset, resReset = tryCall(Remotes.ResetPetNetwork, pet)
        end
        if okReset then
            anySuccess = true
        else
            setDebugError("ResetNetworkOwnership failed: " .. tostring(resReset))
        end
    end

    for i = 1, tries do
        for _, ailment in ipairs(PET_AILMENTS) do
            if not _G.AdoptHub then break end
            setDebugStep("pet_ailment", ailment)
            setStatus("pet care: " .. ailment)
            if pet then
                local reaction = ailment:gsub("^%l", string.upper) .. "AilmentReaction"
                if sendPetReaction(pet, reaction) then
                    anySuccess = true
                end
            end
            local ok, res = tryCall(Remotes.ProgressPetAilment, S.lp, pet, ailment)
            if not ok then
                ok, res = tryCall(Remotes.ProgressPetAilment, ailment)
            end
            if ok then
                anySuccess = true
            else
                setDebugError("ProgressPetAilment failed: " .. tostring(res))
            end
            task.wait(jitter(0.35))
        end

        local ok2, res2 = tryCall(Remotes.ProgressPetAilment, S.lp, pet)
        if not ok2 then
            ok2, res2 = tryCall(Remotes.ProgressPetAilment, pet)
        end
        if ok2 then
            anySuccess = true
        else
            setDebugError("ProgressPetAilment(empty) failed: " .. tostring(res2))
        end
        task.wait(jitter(0.8))
    end

    if not anySuccess then
        setDebugStep("pet_care_fail", "no remote success")
        setStatus("pet care: failed")
        return false
    end
    return true
end

local function runPizzaQuest()
    setDebugStep("pizza", "starting pizza quest")
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
    setDebugStep("minigame", "starting minigame quest")
    setStatus("quest: minigame")
    tryCall(Remotes.MinigameJoin)
    task.wait(jitter(1))
    tryCall(Remotes.MicrogameStart)
    return true
end

local function runCollectQuest()
    setDebugStep("collect", "collecting bucks")
    setStatus("quest: collect bucks")
    tryCall(Remotes.PayCollect)
    return true
end

local function runTeleportQuest(task)
    setDebugStep("teleport", "teleporting")
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
    setDebugStep("handle_task", tostring(type(taskData)))
    local task = normalizeTaskData(taskData)
    if not task then
        setDebugError("normalizeTaskData returned nil")
        return false
    end

    local key = getTaskKey(task)
    if key and dedupeTask(key, 2.5) then return false end

    local kind = classifyQuest(task) or "unknown"
    if (kind == "unknown" or not questHandlers[kind]) and Config.AutoFarm then
        kind = "pet"
    end
    local handler = questHandlers[kind]
    if not handler then
        setDebugError("unknown quest: " .. tostring(task.rawType or task.name or task.id or kind))
        setStatus("quest unknown: " .. tostring(task.rawType or task.name or task.id or kind))
        return false
    end

    setDebugStep("run_handler", kind)
    local ok = handler(task)
    if ok and key then
        setDebugStep("task_done", key)
        markTaskDone(key)
    end
    return ok
end

local function queueTaskList(list)
    if type(list) ~= "table" then return end
    for _, value in ipairs(list) do
        setDebugStep("queue_task", tostring(type(value)))
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
                setDebugStep("queue_task", tostring(type(value)))
        local task = normalizeTaskData(value)
                if task then
                    setDebugStep("queue_push", tostring(task.rawType or task.name or task.id or "unknown"))
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
            setDebugStep("pet_complete", tostring(ailmentName))
            rememberQuestSignal(ailmentName)
            rememberQuestSignal("pet")
            rememberQuestSignal("ailment")
        end)
    end

    if Remotes.PetProgressed then
        Remotes.PetProgressed.OnClientEvent:Connect(function()
            setDebugStep("pet_progressed", "event")
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
            if Config.AutoDaily or Config.AutoFarm then
                setDebugStep("loop", "pump fallback")
                pumpFallbackQuests()
                local taskData = popTask()
                if taskData then
                    setDebugStep("loop_task", tostring(taskData.kind or taskData.rawType or taskData.name or "unknown"))
                    local okHandle, errHandle = pcall(handleTask, taskData)
                    if not okHandle then
                        setDebugError("handleTask crash: " .. tostring(errHandle))
                    end
                    task.wait(jitter(1))
                elseif Config.AutoFarm then
                    setDebugStep("loop_fallback", "auto_farm_pet_loop")
                    local okFallback, errFallback = pcall(handleTask, {id = "auto_farm_pet_loop", kind = "pet", rawType = "pet_care", progress = 0, goal = 1})
                    if not okFallback then
                        setDebugError("auto_farm handleTask crash: " .. tostring(errFallback))
                    end
                    safewait(4)
                else
                    setDebugStep("waiting", "no queued task")
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
                -- AutoFarm is handled by runDailyLoop so it can share quest queue/dedupe.
                safewait(5)
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
