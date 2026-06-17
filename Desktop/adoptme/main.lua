-- AdoptHub Loader
_G.AdoptHub = false
task.wait(1.5)
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