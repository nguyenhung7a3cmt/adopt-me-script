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
    AutoDaily  = false,
    AutoFarm   = false,
    AutoPizza  = false,
    AutoCollect= false,
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

local function getNet(path)
    -- path like "adoptme_new.modules.Dailies.DailiesNetService:9"
    if not NET then return nil end
    local node = NET
    for part in path:gmatch("[^%.]+") do
        if not node then return nil end
        -- handle :N suffix (numbered children)
        local name, idx = part:match("^(.+):(%d+)$")
        if name and idx then
            local parent = node:FindFirstChild(name)
            if not parent then return nil end
            -- numbered remote: GetChildren sorted
            local children = parent:GetChildren()
            table.sort(children, function(a,b) return a.Name < b.Name end)
            -- DailiesNetService:9 means 9th line in file → just find by index in children
            node = children[tonumber(idx)]
        else
            node = node:FindFirstChild(part)
        end
    end
    return node
end

-- Cache all remotes
pcall(function()
    if API then
        Remotes.DataChanged        = API:WaitForChild("DataAPI/DataChanged", 10)
        Remotes.PayCollect         = API:WaitForChild("PayAPI/Collect", 10)
        Remotes.ClaimDailyReward   = API:WaitForChild("DailyLoginAPI/ClaimDailyReward", 10)
        Remotes.ClaimStarReward    = API:WaitForChild("DailyLoginAPI/ClaimStarReward", 10)
        Remotes.ProgressPetAilment = API:WaitForChild("AilmentsAPI/ProgressPetMeAilment", 10)
        Remotes.PizzaClaim         = API:WaitForChild("RoleplayAPI/PizzaShopClaimDough", 10)
        Remotes.PizzaNav           = API:WaitForChild("RoleplayAPI/NavigateToPizzaShopConveyor", 10)
        Remotes.MinigameJoin       = API:WaitForChild("MinigameAPI/AttemptJoin", 10)
        Remotes.MicrogameStart     = API:WaitForChild("MicrogameAPI/AttemptStart", 10)
        Remotes.TeleToLocation     = API:WaitForChild("LocationAPI/TeleToLocation", 10)
    end
end)

-- Dailies net remotes (numbered children)
pcall(function()
    if NET then
        Remotes.DailiesEvent1 = NET:FindFirstChild("adoptme_new.modules.Dailies.DailiesNetService:9")
        Remotes.DailiesEvent2 = NET:FindFirstChild("adoptme_new.modules.Dailies.DailiesNetService:15")
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
        pcall(function() statusLbl.Text = "● " .. text end)
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
    for i = 1, maxTry do
        local ok, res = tryCall(remote, ...)
        if ok then return true, res end
        task.wait(1)
    end
    return false
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
S._statusLblRef = function(lbl) statusLbl = lbl end

return S
