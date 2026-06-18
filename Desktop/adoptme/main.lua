-- AdoptHub Loader
_G.AdoptHub = false
task.wait(1.5)
_G.AdoptHub = true

-- Pre-cache toan bo remotes NGAY LUC DAU truoc khi game filter
local RS = game:GetService("ReplicatedStorage")
_G.CachedRemotes = {}
pcall(function()
    for _, obj in ipairs(RS:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            _G.CachedRemotes[obj.Name] = obj
        end
    end
    local n = 0
    for _ in pairs(_G.CachedRemotes) do n = n + 1 end
    print("[AdoptHub] Pre-cached " .. n .. " remotes")
end)


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