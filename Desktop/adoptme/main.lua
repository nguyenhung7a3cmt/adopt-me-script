-- AdoptHub Loader
_G.AdoptHub = false

-- Cache remotes NGAY LẬP TỨC, không wait
local RS = game:GetService("ReplicatedStorage")
_G.CachedRemotes = {}

local function doCache()
    local n = 0
    for _, obj in ipairs(RS:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local full = obj:GetFullName():gsub("^ReplicatedStorage%.", "")
            _G.CachedRemotes[obj.Name] = _G.CachedRemotes[obj.Name] or obj
            _G.CachedRemotes[full] = obj
            n = n + 1
        end
    end
    return n
end

-- Cache lần 1 ngay lúc đầu
local n1 = doCache()
print("[AdoptHub] Cache lần 1:", n1, "remotes")

-- Cache lần 2 sau 0.5s
task.delay(0.5, function()
    local n2 = doCache()
    print("[AdoptHub] Cache lần 2:", n2, "remotes")
end)

-- Cache lần 3 sau 2s
task.delay(2, function()
    local n3 = doCache()
    print("[AdoptHub] Cache lần 3:", n3, "remotes")
    -- Check AilmentsAPI có không
    local r = _G.CachedRemotes["ProgressPetMeAilment"]
    print("[AdoptHub] ProgressPetMeAilment:", r and r:GetFullName() or "NIL")
end)

_G.AdoptHub = true

pcall(function()
    local pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    local old = pg:FindFirstChild("AdoptHubUI")
    if old then old:Destroy() end
end)

local BASE = "https://raw.githubusercontent.com/nguyenhung7a3cmt/adopt-me-script/main/Desktop/adoptme/"

local function load(file, arg)
    return loadstring(game:HttpGet(BASE .. file))(arg)
end

local S = load("part1.lua")
print("[DEBUG] Part1 loaded")
S = load("part2.lua", S)
print("[DEBUG] Part2 loaded")
S = load("part3.lua", S)
print("[DEBUG] Part3 loaded")
print("[AdoptHub] Script loaded successfully")