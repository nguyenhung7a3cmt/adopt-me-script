-- AdoptHub Loader
_G.AdoptHub = false
task.wait(1.5)
_G.AdoptHub = true

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
_G.CachedRemotes = {}

pcall(function()
    for _, obj in ipairs(RS:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            _G.CachedRemotes[obj.Name] = _G.CachedRemotes[obj.Name] or obj
            local full = obj:GetFullName():gsub("^ReplicatedStorage%.", "")
            _G.CachedRemotes[full] = obj
        end
    end
    local n = 0
    for _ in pairs(_G.CachedRemotes) do
        n = n + 1
    end
    print("[AdoptHub] Pre-cached " .. n .. " remotes")
end)

pcall(function()
    local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
    local old = pg:FindFirstChild("AdoptHubUI")
    if old then old:Destroy() end
end)

local LOCAL_BASE = "C:/Users/Admin/Desktop/adoptme/"
local REMOTE_BASE = "https://raw.githubusercontent.com/nguyenhung7a3cmt/adopt-me-script/main/Desktop/adoptme/"

local function buildRemoteCache()
    pcall(function()
        for _, obj in ipairs(RS:GetDescendants()) do
            if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                _G.CachedRemotes[obj.Name] = _G.CachedRemotes[obj.Name] or obj
                local full = obj:GetFullName():gsub("^ReplicatedStorage%.", "")
                _G.CachedRemotes[full] = obj
            end
        end
        local n = 0
        for _ in pairs(_G.CachedRemotes) do n = n + 1 end
        print("[AdoptHub] Cache pass done:", n, "entries")
    end)
end

buildRemoteCache()
task.delay(0.5, buildRemoteCache)
task.delay(2.0, buildRemoteCache)

local function readSource(file)
    local localPath = LOCAL_BASE .. file
    if readfile and isfile and isfile(localPath) then
        local ok, src = pcall(readfile, localPath)
        if ok and type(src) == "string" and #src > 0 then
            return src, "local"
        end
    end
    local ok, src = pcall(function()
        return game:HttpGet(REMOTE_BASE .. file)
    end)
    if ok and type(src) == "string" and #src > 0 then
        return src, "remote"
    end
    return nil, "missing"
end

local function loadPart(file, arg)
    local src, mode = readSource(file)
    if not src then
        error("[AdoptHub] cannot load " .. tostring(file) .. " (local/remote missing)")
    end
    if type(loadstring) ~= "function" then
        error("[AdoptHub] loadstring is not available in this executor")
    end
    local fn, err = loadstring(src)
    if not fn then
        error("[AdoptHub] loadstring failed for " .. tostring(file) .. ": " .. tostring(err))
    end
    local ok, result = pcall(fn, arg)
    if not ok then
        error("[AdoptHub] run failed for " .. tostring(file) .. " [" .. tostring(mode) .. "]: " .. tostring(result))
    end
    return result
end

local ok1, S = pcall(loadPart, "part1.lua")
if not ok1 then error(S) end
print("[DEBUG] Part1 loaded")

local ok2
ok2, S = pcall(loadPart, "part2.lua", S)
if not ok2 then error(S) end
print("[DEBUG] Part2 loaded")

local ok3
ok3, S = pcall(loadPart, "part3.lua", S)
if not ok3 then error(S) end
print("[DEBUG] Part3 loaded")

print("[AdoptHub] Script loaded successfully")
