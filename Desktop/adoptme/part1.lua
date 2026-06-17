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
        Remotes.DataChanged        = API:WaitForChild("DataAPI",10)     and API.DataAPI:WaitForChild("DataChanged",5)
        Remotes.PayCollect         = API:WaitForChild("PayAPI",10)      and API.PayAPI:WaitForChild("Collect",5)
        Remotes.ClaimDailyReward   = API:WaitForChild("DailyLoginAPI",10) and API.DailyLoginAPI:WaitForChild("ClaimDailyReward",5)
        Remotes.ClaimStarReward    = API:WaitForChild("DailyLoginAPI",10) and API.DailyLoginAPI:WaitForChild("ClaimStarReward",5)
        Remotes.ProgressPetAilment = API:WaitForChild("AilmentsAPI",10) and API.AilmentsAPI:WaitForChild("ProgressPetMeAilment",5)
        Remotes.PizzaClaim         = API:WaitForChild("RoleplayAPI",10) and API.RoleplayAPI:WaitForChild("PizzaShopClaimDough",5)
        Remotes.PizzaNav           = API:WaitForChild("RoleplayAPI",10) and API.RoleplayAPI:WaitForChild("NavigateToPizzaShopConveyor",5)
        Remotes.MinigameJoin       = API:WaitForChild("MinigameAPI",10) and API.MinigameAPI:WaitForChild("AttemptJoin",5)
        Remotes.MicrogameStart     = API:WaitForChild("MicrogameAPI",10) and API.MicrogameAPI:WaitForChild("AttemptStart",5)
        Remotes.TeleToLocation     = API:WaitForChild("LocationAPI",10) and API.LocationAPI:WaitForChild("TeleToLocation",5)
    end
end)

-- Dailies net remotes (numbered children)
pcall(function()
    if NET then
        local dailiesFolder = NET
        for _, part in ipairs({"adoptme_new","modules","Dailies","DailiesNetService"}) do
            if dailiesFolder then dailiesFolder = dailiesFolder:FindFirstChild(part) end
        end
        if dailiesFolder then
            local ch = dailiesFolder:GetChildren()
            -- :9 and :15 are RemoteEvents inside DailiesNetService folder
            -- they show as child RemoteEvents
            for _, v in ipairs(ch) do
                if v:IsA("RemoteEvent") then
                    if not Remotes.DailiesEvent1 then
                        Remotes.DailiesEvent1 = v
                    elseif not Remotes.DailiesEvent2 then
                        Remotes.DailiesEvent2 = v
                    end
                end
            end
        end
    end
end)

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
