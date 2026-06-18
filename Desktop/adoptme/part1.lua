-- AdoptHub part1: services, remotes, state
local S = (...) or {}

local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
local lp           = Players.LocalPlayer

-- ============================================================
-- CONFIG
-- ============================================================
local Config = {
    AutoDaily   = false,
    AutoFarm    = false,
    AutoPizza   = false,
    AutoCollect = false,
}

-- ============================================================
-- REMOTES CACHE
-- ============================================================
local API = RS:FindFirstChild("API")
local NET = RS:FindFirstChild("adoptme_new_net")
local Remotes = {}

local function getRemote(parent, path)
    if not parent then return nil end
    local node = parent
    for part in path:gmatch("[^/]+") do
        if not node then return nil end
        node = node:FindFirstChild(part)
    end
    return node
end

-- Resolve paths like:
-- adoptme_new.modules.Dailies.DailiesNetService:9
local function tryFindNetRemote(path)
    if not NET then return nil end
    local node = NET
    for part in path:gmatch("[^%.]+") do
        if not node then return nil end

        local name, idx = part:match("^(.+):(%d+)$")
        if name and idx then
            local folder = node:FindFirstChild(name)
            if not folder then return nil end
            local children = folder:GetChildren()
            table.sort(children, function(a, b) return a.Name < b.Name end)
            node = children[tonumber(idx)]
        else
            node = node:FindFirstChild(part)
        end
    end
    return node
end

pcall(function()
    if API then
        Remotes.DataChanged         = getRemote(API, "DataAPI/DataChanged")
        Remotes.DataInit            = getRemote(API, "DataAPI/ReplicateInitData")
        Remotes.DataPartial         = getRemote(API, "DataAPI/DataPartiallyChanged")
        Remotes.PayCollect          = getRemote(API, "PayAPI/Collect")
        Remotes.ClaimDailyReward    = getRemote(API, "DailyLoginAPI/ClaimDailyReward")
        Remotes.ClaimStarReward     = getRemote(API, "DailyLoginAPI/ClaimStarReward")
        -- Ailment remotes (mỗi loại có remote riêng)
        Remotes.ProgressPetMeAilment    = getRemote(API, "AilmentsAPI/ProgressPetMeAilment")
        Remotes.ProgressDirtyAilment    = getRemote(API, "AilmentsAPI/ProgressDirtyAilment")
        Remotes.ChooseMysteryAilment    = getRemote(API, "AilmentsAPI/ChooseMysteryAilment")
        Remotes.PetAilmentCompleted     = getRemote(API, "AilmentsAPI/PetAilmentCompleted")
        Remotes.BabyAilmentCompleted    = getRemote(API, "AilmentsAPI/BabyAilmentCompleted")
        Remotes.ShowHealingEffect       = getRemote(API, "AilmentsAPI/ShowHealingEffect")
        -- Map ailment name -> remote (dùng trong part2)
        Remotes.AilmentMap = {
            hungry   = Remotes.ProgressPetMeAilment,
            thirsty  = Remotes.ProgressPetMeAilment,
            sleepy   = Remotes.ProgressPetMeAilment,
            bored    = Remotes.ProgressPetMeAilment,
            sick     = Remotes.ProgressPetMeAilment,
            walk     = Remotes.ProgressPetMeAilment,
            toilet   = Remotes.ProgressPetMeAilment,
            dirty    = Remotes.ProgressDirtyAilment,
            mystery  = Remotes.ChooseMysteryAilment,
        }
        -- Backward compat
        Remotes.ProgressPetAilment = Remotes.ProgressPetMeAilment
        Remotes.PizzaClaim          = getRemote(API, "RoleplayAPI/PizzaShopClaimDough")
        Remotes.PizzaNav            = getRemote(API, "RoleplayAPI/NavigateToPizzaShopConveyor")
        Remotes.MinigameJoin        = getRemote(API, "MinigameAPI/AttemptJoin")
        Remotes.MicrogameStart      = getRemote(API, "MicrogameAPI/AttemptStart")
        Remotes.TeleToLocation      = getRemote(API, "LocationAPI/TeleToLocation")
        Remotes.PetProgressed       = getRemote(API, "PetAPI/PetProgressed")
        Remotes.PetHatched          = getRemote(API, "PetAPI/PetHatched")
        Remotes.FocusPet            = getRemote(API, "AdoptAPI/FocusPet")
        Remotes.UnfocusPet          = getRemote(API, "AdoptAPI/UnfocusPet")
        Remotes.ReplicateReactions  = getRemote(API, "PetAPI/ReplicateActiveReactions")
        Remotes.ResetPetNetwork     = getRemote(API, "PetAPI/ResetNetworkOwnership")
        Remotes.ClaimPetProgression = getRemote(API, "PetAPI/ClaimProgressionReward")
    end
end)

-- Tim remote theo dung ten (vd "DailiesNetService:9") trong toan bo descendants cua NET.
-- An toan hon sort index vi khong phu thuoc cau truc folder.
local function findNetRemoteByName(targetName)
    if not NET then return nil end
    if NET:FindFirstChild(targetName) then
        return NET:FindFirstChild(targetName)
    end
    for _, inst in ipairs(NET:GetDescendants()) do
        if inst.Name == targetName and (inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction")) then
            return inst
        end
    end
    return nil
end

pcall(function()
    if NET then
        Remotes.DailiesEvent1 = findNetRemoteByName("DailiesNetService:9")
            or tryFindNetRemote("adoptme_new.modules.Dailies.DailiesNetService:9")
        Remotes.DailiesEvent2 = findNetRemoteByName("DailiesNetService:15")
            or tryFindNetRemote("adoptme_new.modules.Dailies.DailiesNetService:15")
        print("[DEBUG] Found DailiesEvent1:", Remotes.DailiesEvent1 and Remotes.DailiesEvent1.Name)
        print("[DEBUG] Found DailiesEvent2:", Remotes.DailiesEvent2 and Remotes.DailiesEvent2.Name)
    end
end)

for name, remote in pairs(Remotes) do
    print("[DEBUG] Remote", name, "=", remote)
end

-- ============================================================
-- STATUS
-- ============================================================
local statusLbl = nil
local statusText = "idle"
local function setStatus(text)
    statusText = text
    if statusLbl then
        pcall(function()
            statusLbl.Text = "[*] " .. text
        end)
    end
end

-- ============================================================
-- HELPERS
-- ============================================================
local function safewait(t)
    local elapsed = 0
    local step = 0.1
    while _G.AdoptHub and elapsed < t do
        task.wait(step)
        elapsed = elapsed + step
    end
end

local function jitter(base)
    return base + (math.random() - 0.5)
end

local function tryCall(remote, ...)
    if not remote then return false, "no remote" end
    local ok, res = pcall(function(...)
        if remote:IsA("RemoteFunction") then
            return remote:InvokeServer(...)
        else
            remote:FireServer(...)
            return true
        end
    end, ...)
    return ok, res
end

local function retryCall(remote, maxTry, ...)
    for _ = 1, maxTry do
        local ok, res = tryCall(remote, ...)
        if ok then return true, res end
        task.wait(1)
    end
    return false
end

-- ============================================================
-- AUTO QUEST QUEUE + DE-DUP
-- ============================================================
local activeTasks = {}
local activeTaskMap = {}
local completedTaskCache = {}


local debugState = {
    step = "idle",
    detail = "",
    lastError = "",
    updatedAt = 0,
}

local function setDebugStep(step, detail)
    debugState.step = tostring(step or "idle")
    debugState.detail = tostring(detail or "")
    debugState.updatedAt = tick()
end

local function setDebugError(err)
    debugState.lastError = tostring(err or "")
    debugState.updatedAt = tick()
end

local function getDebugState()
    return debugState
end

local function simpleEncode(value, depth, seen)
    depth = depth or 0
    seen = seen or {}
    local valueType = typeof(value)

    if valueType == "string" then
        return value:lower()
    elseif valueType == "number" or valueType == "boolean" then
        return tostring(value)
    elseif valueType ~= "table" then
        return tostring(value)
    end

    if seen[value] then
        return "<cycle>"
    end
    if depth >= 3 then
        return "<max-depth>"
    end

    seen[value] = true
    local parts = {}
    for k, v in pairs(value) do
        parts[#parts + 1] = tostring(k):lower() .. "=" .. simpleEncode(v, depth + 1, seen)
    end
    table.sort(parts)
    seen[value] = nil
    return table.concat(parts, "|")
end

local function normalizeTaskData(taskData)
    if type(taskData) ~= "table" then return nil end

    local task = {}
    task.raw = taskData
    task.id = taskData.id or taskData.quest_id or taskData.daily_id or taskData.key
    task.name = taskData.name or taskData.quest_name or taskData.title or taskData.slug
    task.rawType = taskData.kind or taskData.type or taskData.quest_type or taskData.questType or taskData.category or taskData.task_type or taskData[1]
    task.progress = tonumber(taskData.progress or taskData.current_progress or taskData.current or taskData.value or 0) or 0
    task.goal = tonumber(taskData.goal or taskData.required or taskData.target or taskData.total or 1) or 1
    task.completed = taskData.completed == true or taskData.claimed == true
    task.location = taskData.location or taskData.destination or taskData.place or taskData.zone
    task.description = taskData.description or taskData.desc
    if type(taskData.kind) == "string" then
        task.kind = taskData.kind
    end
    return task
end

local function classifyQuest(task)
    if not task then return "unknown" end
    if task.kind then return task.kind end

    local blob = table.concat({
        tostring(task.rawType or ""),
        tostring(task.name or ""),
        tostring(task.id or ""),
        tostring(task.description or ""),
        simpleEncode(task.raw),
    }, " "):lower()

    local kind = "unknown"
    if blob:find("pizza") or blob:find("dough") or blob:find("delivery") or blob:find("pizza shop") then
        kind = "pizza"
    elseif blob:find("mini") or blob:find("microgame") or blob:find("obby") or blob:find("join game") then
        kind = "minigame"
    elseif blob:find("tele") or blob:find("location") or blob:find("school") or blob:find("hospital") or blob:find("neighborhood") then
        kind = "teleport"
    elseif blob:find("bucks") or blob:find("collect") or blob:find("reward") then
        kind = "collect"
    elseif blob:find("pet") or blob:find("ailment") or blob:find("sleep") or blob:find("dirty") or blob:find("hungry") or blob:find("sick") or blob:find("care") or blob:find("grow") or blob:find("level") then
        kind = "pet"
    end

    task.kind = kind
    return kind
end

local function getTaskKey(task)
    if type(task) ~= "table" then return nil end
    local t = task.raw and task or normalizeTaskData(task)
    if not t then return nil end
    return table.concat({
        tostring(t.id or ""),
        tostring(t.name or ""),
        tostring(t.rawType or ""),
        tostring(classifyQuest(t) or "unknown"),
    }, "|"):lower()
end

local function pushTask(taskData)
    if type(taskData) ~= "table" then return false end
    local task = taskData.raw and taskData or normalizeTaskData(taskData)
    if not task or task.completed then return false end

    local key = getTaskKey(task)
    if not key or activeTaskMap[key] then
        return false
    end

    activeTaskMap[key] = true
    table.insert(activeTasks, task)
    return true
end

local function popTask()
    while #activeTasks > 0 do
        local task = table.remove(activeTasks, 1)
        local key = getTaskKey(task)
        if key then
            activeTaskMap[key] = nil
        end
        if task and not task.completed then
            return task
        end
    end
    return nil
end

local function markTaskDone(task)
    local key = type(task) == "string" and task or getTaskKey(task)
    if key then
        completedTaskCache[key] = tick()
    end
end

local function dedupeTask(task, window)
    local key = type(task) == "string" and task or getTaskKey(task)
    if not key then return false end
    local ts = completedTaskCache[key]
    return ts and tick() - ts <= (window or 60) or false
end

-- ============================================================
-- FARM / STOP
-- ============================================================
local function stopAll()
    Config.AutoDaily   = false
    Config.AutoFarm    = false
    Config.AutoPizza   = false
    Config.AutoCollect = false
    setStatus("stopped")
end

local function startFarm()
    Config.AutoFarm = true
    setStatus("farming...")
end

-- ============================================================
-- EXPORT
-- ============================================================
S.Players      = Players
S.RS           = RS
S.RunService   = RunService
S.TweenService = TweenService
S.UIS          = UIS
S.lp           = lp
S.API          = API
S.NET          = NET
S.Config       = Config
S.Remotes      = Remotes
S.setStatus    = setStatus
S.safewait     = safewait
S.jitter       = jitter
S.tryCall      = tryCall
S.retryCall    = retryCall
S.stopAll      = stopAll
S.startFarm    = startFarm
S.statusText   = "idle"
S.activeTasks  = activeTasks
S.debugState   = debugState
S.setDebugStep = setDebugStep
S.setDebugError = setDebugError
S.getDebugState = getDebugState
S.normalizeTaskData = normalizeTaskData
S.classifyQuest = classifyQuest
S.getTaskKey   = getTaskKey
S.pushTask     = pushTask
S.popTask      = popTask
S.markTaskDone = markTaskDone
S.dedupeTask   = dedupeTask
S._statusLblRef = function(lbl) statusLbl = lbl end

return S