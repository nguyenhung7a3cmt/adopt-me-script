-- AdoptHub part2: farm logic
local S = (...)

local Config    = S.Config
local Remotes   = S.Remotes
local setStatus = S.setStatus
local safewait  = S.safewait
local jitter    = S.jitter
local tryCall   = S.tryCall
local retryCall = S.retryCall

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
-- DAILY TASKS
-- ============================================================
local activeTasks = {}

local function handleTask(taskData)
    if not taskData then return end
    local taskType = type(taskData) == "table" and (taskData.type or taskData.kind or taskData[1]) or tostring(taskData)
    taskType = tostring(taskType):lower()

    if taskType:find("pet") or taskType:find("ailment") or taskType:find("care") then
        setStatus("daily task: pet care")
        for i = 1, 3 do
            tryCall(Remotes.ProgressPetAilment)
            task.wait(jitter(1))
        end

    elseif taskType:find("pizza") or taskType:find("dough") or taskType:find("delivery") then
        setStatus("daily task: pizza job")
        tryCall(Remotes.PizzaNav)
        task.wait(jitter(2))
        for i = 1, 5 do
            tryCall(Remotes.PizzaClaim)
            task.wait(jitter(1.5))
        end

    elseif taskType:find("mini") or taskType:find("game") or taskType:find("micro") then
        setStatus("daily task: minigame")
        tryCall(Remotes.MinigameJoin)
        task.wait(jitter(1))
        tryCall(Remotes.MicrogameStart)

    else
        setStatus("daily task: unknown type - " .. taskType)
    end
end

local function hookDailies()
    if Remotes.DailiesEvent2 then
        Remotes.DailiesEvent2.OnClientEvent:Connect(function(...)
            local args = {...}
            if not Config.AutoDaily then return end
            for _, taskData in ipairs(args) do
                if type(taskData) == "table" then
                    handleTask(taskData)
                    task.wait(0.5)
                end
            end
        end)
    end
    if Remotes.DailiesEvent1 then
        Remotes.DailiesEvent1.OnClientEvent:Connect(function(...)
            if not Config.AutoDaily then return end
            local args = {...}
            for _, v in ipairs(args) do
                if type(v) == "table" then
                    table.insert(activeTasks, v)
                end
            end
        end)
    end
end

local function runDailyLoop()
    task.spawn(function()
        while _G.AdoptHub do
            if Config.AutoDaily then
                setStatus("checking daily tasks...")
                -- try to fire daily check
-- Dailies check đã auto-hook qua OnClientEvent, không cần fire
                -- process any buffered tasks
                for _, taskData in ipairs(activeTasks) do
                    if Config.AutoDaily then
                        handleTask(taskData)
                        task.wait(jitter(1))
                    end
                end
                activeTasks = {}
                safewait(30)
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
                    for i = 1, 8 do
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
-- PET CARE LOOP (AilmentsAPI passive)
-- ============================================================
local function runPetCareLoop()
    task.spawn(function()
        while _G.AdoptHub do
            if Config.AutoFarm then
                setStatus("pet care: progressing ailments...")
                for i = 1, 3 do
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

-- ============================================================
-- EXPORT
-- ============================================================
S.claimDailyLogin = claimDailyLogin
S.activeTasks     = activeTasks
S.handleTask      = handleTask

return S
