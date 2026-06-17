-- AdoptHub part3: frosted glass UI
local S = (...)

local TweenService = S.TweenService
local UIS          = S.UIS
local lp           = S.lp
local Config       = S.Config
local setStatus    = S.setStatus
local claimDailyLogin = S.claimDailyLogin

-- ============================================================
-- COLORS
-- ============================================================
local C = {
    BG        = Color3.fromRGB(14, 14, 18),
    BG2       = Color3.fromRGB(20, 20, 26),
    Card      = Color3.fromRGB(24, 24, 32),
    Border    = Color3.fromRGB(60, 60, 80),
    BorderDim = Color3.fromRGB(35, 35, 48),
    Text      = Color3.fromRGB(230, 230, 235),
    TextDim   = Color3.fromRGB(140, 140, 160),
    TextMuted = Color3.fromRGB(80, 80, 100),
    Green     = Color3.fromRGB(80, 220, 120),
    GreenDim  = Color3.fromRGB(30, 80, 50),
    Red       = Color3.fromRGB(220, 70, 70),
    RedDim    = Color3.fromRGB(80, 25, 25),
    Accent    = Color3.fromRGB(160, 160, 200),
    TabActive = Color3.fromRGB(40, 40, 55),
    TabInact  = Color3.fromRGB(20, 20, 28),
}

-- ============================================================
-- HELPERS
-- ============================================================
local function corner(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 10)
    c.Parent = inst
    return c
end

local function stroke(inst, color, thick, trans)
    local s = Instance.new("UIStroke")
    s.Color = color or C.Border
    s.Thickness = thick or 1
    s.Transparency = trans or 0.5
    s.Parent = inst
    return s
end

local function label(parent, text, size, color, font)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextSize = size or 13
    l.TextColor3 = color or C.Text
    l.Font = font or Enum.Font.Code
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Size = UDim2.new(1, 0, 0, size and size + 4 or 18)
    l.Parent = parent
    return l
end

local function frame(parent, size, pos, color, trans)
    local f = Instance.new("Frame")
    f.Size = size
    f.Position = pos or UDim2.new(0,0,0,0)
    f.BackgroundColor3 = color or C.Card
    f.BackgroundTransparency = trans or 0
    f.BorderSizePixel = 0
    f.Parent = parent
    return f
end

-- Toggle pill button
local function makeToggle(parent, labelText, yPos, configKey)
    local row = frame(parent,
        UDim2.new(1,-16,0,36),
        UDim2.new(0,8,0,yPos),
        C.BG2, 0)
    corner(row, 8)
    stroke(row, C.BorderDim, 1, 0.3)

    local lbl = label(row, labelText, 13, C.Text)
    lbl.Position = UDim2.new(0,10,0,0)
    lbl.Size = UDim2.new(1,-70,1,0)
    lbl.TextYAlignment = Enum.TextYAlignment.Center

    -- pill
    local pill = frame(row, UDim2.new(0,48,0,24), UDim2.new(1,-58,0.5,-12), C.RedDim, 0)
    corner(pill, 12)
    stroke(pill, C.Border, 1, 0.4)

    local knob = frame(pill, UDim2.new(0,18,0,18), UDim2.new(0,3,0.5,-9), C.Red, 0)
    corner(knob, 9)

    local active = Config[configKey] or false

    local function updateVisual()
        local on = Config[configKey]
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = on and UDim2.new(1,-21,0.5,-9) or UDim2.new(0,3,0.5,-9),
            BackgroundColor3 = on and C.Green or C.Red,
        }):Play()
        TweenService:Create(pill, TweenInfo.new(0.15), {
            BackgroundColor3 = on and C.GreenDim or C.RedDim,
        }):Play()
        lbl.TextColor3 = on and C.Text or C.TextDim
    end

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = row
    btn.MouseButton1Click:Connect(function()
        Config[configKey] = not Config[configKey]
        updateVisual()
    end)

    updateVisual()
    return row
end

-- Action button
local function makeBtn(parent, text, yPos, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,-16,0,32)
    btn.Position = UDim2.new(0,8,0,yPos)
    btn.BackgroundColor3 = C.Card
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextSize = 13
    btn.Font = Enum.Font.Code
    btn.TextColor3 = C.Accent
    btn.Parent = parent
    corner(btn, 8)
    stroke(btn, C.Border, 1, 0.4)

    btn.MouseButton1Click:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.08), {BackgroundColor3 = C.TabActive}):Play()
        task.delay(0.12, function()
            TweenService:Create(btn, TweenInfo.new(0.08), {BackgroundColor3 = C.Card}):Play()
        end)
        pcall(callback)
    end)
    return btn
end

-- ============================================================
-- BUILD GUI
-- ============================================================
local pg = lp:WaitForChild("PlayerGui")

local sg = Instance.new("ScreenGui")
sg.Name = "AdoptHubUI"
sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.IgnoreGuiInset = true
sg.Parent = pg

-- Blur
local blur = Instance.new("BlurEffect")
blur.Size = 0
blur.Parent = game:GetService("Lighting")

-- Main window
local win = frame(sg,
    UDim2.new(0,300,0,420),
    UDim2.new(0.5,-150,0.5,-210),
    C.BG, 0.06)
corner(win, 14)
stroke(win, C.Border, 1, 0.35)

-- Drop shadow illusion
local shadow = frame(sg,
    UDim2.new(0,310,0,430),
    UDim2.new(0,0,0,0),
    Color3.fromRGB(0,0,0), 0.6)
corner(shadow, 16)
shadow.ZIndex = win.ZIndex - 1
-- anchor shadow to win
local function updateShadow()
    shadow.Position = UDim2.new(
        win.Position.X.Scale,
        win.Position.X.Offset - 5,
        win.Position.Y.Scale,
        win.Position.Y.Offset - 5
    )
end
updateShadow()

-- ============================================================
-- TITLE BAR
-- ============================================================
local titleBar = frame(win, UDim2.new(1,0,0,40), UDim2.new(0,0,0,0), C.BG2, 0)
corner(titleBar, 14)
stroke(titleBar, C.BorderDim, 1, 0.5)

local titleLbl = label(titleBar, "AdoptHub  v1.0", 14, C.Text)
titleLbl.Position = UDim2.new(0,14,0,0)
titleLbl.Size = UDim2.new(1,-80,1,0)
titleLbl.TextYAlignment = Enum.TextYAlignment.Center
titleLbl.Font = Enum.Font.Code

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0,28,0,22)
minBtn.Position = UDim2.new(1,-62,0.5,-11)
minBtn.BackgroundColor3 = C.Card
minBtn.BorderSizePixel = 0
minBtn.Text = "—"
minBtn.TextSize = 13
minBtn.TextColor3 = C.TextDim
minBtn.Font = Enum.Font.Code
minBtn.Parent = titleBar
corner(minBtn, 6)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0,28,0,22)
closeBtn.Position = UDim2.new(1,-30,0.5,-11)
closeBtn.BackgroundColor3 = C.RedDim
closeBtn.BorderSizePixel = 0
closeBtn.Text = "×"
closeBtn.TextSize = 16
closeBtn.TextColor3 = C.Red
closeBtn.Font = Enum.Font.Code
closeBtn.Parent = titleBar
corner(closeBtn, 6)

-- ============================================================
-- STATUS BAR
-- ============================================================
local statusBar = frame(win, UDim2.new(1,-16,0,26), UDim2.new(0,8,0,44), C.BG2, 0)
corner(statusBar, 6)
stroke(statusBar, C.BorderDim, 1, 0.6)

local statusLbl = label(statusBar, "● idle", 12, C.TextDim)
statusLbl.Position = UDim2.new(0,8,0,0)
statusLbl.Size = UDim2.new(1,-10,1,0)
statusLbl.TextYAlignment = Enum.TextYAlignment.Center

-- Hook status
S._statusLblRef(statusLbl)
S.setStatus = function(text)
    S.statusText = text
    pcall(function() statusLbl.Text = "● " .. text end)
end
setStatus = S.setStatus

-- ============================================================
-- TABS
-- ============================================================
local tabBar = frame(win, UDim2.new(1,-16,0,30), UDim2.new(0,8,0,74), C.BG2, 0)
corner(tabBar, 8)
stroke(tabBar, C.BorderDim, 1, 0.6)

local tabNames = {"Farm", "Daily", "Settings"}
local tabBtns = {}
local tabPages = {}
local activeTab = 1

for i, name in ipairs(tabNames) do
    local tb = Instance.new("TextButton")
    tb.Size = UDim2.new(1/#tabNames, 0, 1, -4)
    tb.Position = UDim2.new((i-1)/#tabNames, 2, 0, 2)
    tb.BackgroundColor3 = i==1 and C.TabActive or C.TabInact
    tb.BorderSizePixel = 0
    tb.Text = name
    tb.TextSize = 12
    tb.TextColor3 = i==1 and C.Text or C.TextDim
    tb.Font = Enum.Font.Code
    tb.Parent = tabBar
    corner(tb, 6)
    tabBtns[i] = tb
end

-- Page scroll frames
local pageArea = frame(win, UDim2.new(1,0,1,-114), UDim2.new(0,0,0,114), C.BG, 0)

for i = 1, #tabNames do
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1,0,1,0)
    page.Position = UDim2.new(0,0,0,0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = C.Border
    page.CanvasSize = UDim2.new(0,0,0,0)
    page.Visible = i == 1
    page.Parent = pageArea
    tabPages[i] = page
end

local function switchTab(idx)
    activeTab = idx
    for i, tb in ipairs(tabBtns) do
        TweenService:Create(tb, TweenInfo.new(0.12), {
            BackgroundColor3 = i==idx and C.TabActive or C.TabInact,
            TextColor3 = i==idx and C.Text or C.TextDim,
        }):Play()
        tabPages[i].Visible = i == idx
    end
end

for i, tb in ipairs(tabBtns) do
    tb.MouseButton1Click:Connect(function() switchTab(i) end)
end

-- ============================================================
-- TAB 1: FARM
-- ============================================================
local farmPage = tabPages[1]
local fy = 8

local farmTitle = label(farmPage, "Auto Farm", 11, C.TextMuted)
farmTitle.Position = UDim2.new(0,12,0,fy)
farmTitle.Font = Enum.Font.Code
fy = fy + 20

makeToggle(farmPage, "Auto Pet Care", fy, "AutoFarm"); fy = fy + 44
makeToggle(farmPage, "Auto Pizza Job", fy, "AutoPizza"); fy = fy + 44
makeToggle(farmPage, "Auto Collect Bucks", fy, "AutoCollect"); fy = fy + 44

local sep1 = frame(farmPage, UDim2.new(1,-16,0,1), UDim2.new(0,8,0,fy), C.BorderDim, 0)
fy = fy + 9

makeBtn(farmPage, "Stop All Farms", fy, function()
    S.stopAll()
    setStatus("all stopped")
end)
fy = fy + 40

farmPage.CanvasSize = UDim2.new(0,0,0,fy+8)

-- ============================================================
-- TAB 2: DAILY
-- ============================================================
local dailyPage = tabPages[2]
local dy = 8

local dailyTitle = label(dailyPage, "Daily Tasks", 11, C.TextMuted)
dailyTitle.Position = UDim2.new(0,12,0,dy)
dy = dy + 20

makeToggle(dailyPage, "Auto Daily Tasks", dy, "AutoDaily"); dy = dy + 44

local sep2 = frame(dailyPage, UDim2.new(1,-16,0,1), UDim2.new(0,8,0,dy), C.BorderDim, 0)
dy = dy + 9

makeBtn(dailyPage, "Claim Daily Login Now", dy, function()
    task.spawn(claimDailyLogin)
end)
dy = dy + 40

makeBtn(dailyPage, "Run Daily Tasks Now", dy, function()
    if not Config.AutoDaily then
        Config.AutoDaily = true
        task.delay(0.5, function() Config.AutoDaily = false end)
    end
    setStatus("running daily tasks...")
end)
dy = dy + 40

-- Info box
local infoBox = frame(dailyPage, UDim2.new(1,-16,0,50), UDim2.new(0,8,0,dy), C.BG2, 0)
corner(infoBox, 8)
stroke(infoBox, C.BorderDim, 1, 0.5)
dy = dy + 58

local infoLbl = label(infoBox, "Tasks auto-detected via\nDailiesNetService hook", 11, C.TextMuted)
infoLbl.Position = UDim2.new(0,8,0,4)
infoLbl.Size = UDim2.new(1,-10,1,-4)
infoLbl.TextWrapped = true

dailyPage.CanvasSize = UDim2.new(0,0,0,dy+8)

-- ============================================================
-- TAB 3: SETTINGS
-- ============================================================
local settingsPage = tabPages[3]
local sy = 8

local settTitle = label(settingsPage, "Settings", 11, C.TextMuted)
settTitle.Position = UDim2.new(0,12,0,sy)
sy = sy + 20

makeBtn(settingsPage, "Destroy GUI", sy, function()
    _G.AdoptHub = false
    task.wait(0.2)
    sg:Destroy()
    blur:Destroy()
    setStatus = function() end
end)
sy = sy + 40

-- Version info
local verBox = frame(settingsPage, UDim2.new(1,-16,0,40), UDim2.new(0,8,0,sy), C.BG2, 0)
corner(verBox, 8)
stroke(verBox, C.BorderDim, 1, 0.5)
local verLbl = label(verBox, "AdoptHub v1.0\nRemotes: API.* confirmed", 11, C.TextMuted)
verLbl.Position = UDim2.new(0,8,0,4)
verLbl.Size = UDim2.new(1,-10,1,-4)
verLbl.TextWrapped = true
sy = sy + 48

settingsPage.CanvasSize = UDim2.new(0,0,0,sy+8)

-- ============================================================
-- DRAG
-- ============================================================
local dragging, dragStart, startPos = false, nil, nil

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = win.Position
    end
end)

UIS.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - dragStart
        win.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
        updateShadow()
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- ============================================================
-- MINIMIZE
-- ============================================================
local minimized = false
local fullH = 420

minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    TweenService:Create(win, TweenInfo.new(0.2), {
        Size = minimized and UDim2.new(0,300,0,44) or UDim2.new(0,300,0,fullH)
    }):Play()
    pageArea.Visible = not minimized
    tabBar.Visible = not minimized
    statusBar.Visible = not minimized
    minBtn.Text = minimized and "□" or "—"
end)

-- ============================================================
-- CLOSE
-- ============================================================
closeBtn.MouseButton1Click:Connect(function()
    TweenService:Create(win, TweenInfo.new(0.15), {
        Size = UDim2.new(0,0,0,0),
        Position = UDim2.new(
            win.Position.X.Scale,
            win.Position.X.Offset + 150,
            win.Position.Y.Scale,
            win.Position.Y.Offset + 210
        )
    }):Play()
    task.delay(0.2, function()
        _G.AdoptHub = false
        sg:Destroy()
        blur:Destroy()
    end)
end)

-- ============================================================
-- OPEN ANIM
-- ============================================================
win.Size = UDim2.new(0,0,0,0)
win.Position = UDim2.new(0.5,0,0.5,0)
win.Size = UDim2.new(0, 300, 0, fullH)
win.Position = UDim2.new(0.5, -150, 0.5, -210)
updateShadow()

setStatus("idle — ready")

return S
