-- =============================================
-- TURKEY HUNT AUTO COLLECTOR + GUI
-- Draggable GUI with toggle, timer, logs
-- =============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")
local playerGui = player:WaitForChild("PlayerGui")

-- =============================================
-- STATE
-- =============================================
local isRunning = false
local huntActive = false
local huntEnded = false
local roundNumber = 0
local collected = 0
local cooldownRemaining = 0
local cooldownTicking = false

-- =============================================
-- REMOTES
-- =============================================
local ThanksgivingEvent = ReplicatedStorage
    :WaitForChild("GameEvents")
    :WaitForChild("Events")
    :WaitForChild("ThanksgivingEvent")

local StartTurkeyHunt = ThanksgivingEvent:WaitForChild("StartTurkeyHunt")
local TurkeyHuntEnded = ThanksgivingEvent:WaitForChild("TurkeyHuntEnded")

-- =============================================
-- GUI SETUP
-- =============================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TurkeyHuntGUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- =============================================
-- COLORS & STYLE
-- =============================================
local C = {
    bg        = Color3.fromRGB(18, 14, 10),
    panel     = Color3.fromRGB(28, 22, 15),
    border    = Color3.fromRGB(180, 110, 30),
    accent    = Color3.fromRGB(220, 140, 40),
    accentDim = Color3.fromRGB(120, 75, 15),
    green     = Color3.fromRGB(80, 200, 100),
    red       = Color3.fromRGB(220, 70, 60),
    textMain  = Color3.fromRGB(240, 220, 180),
    textDim   = Color3.fromRGB(140, 120, 90),
    logBg     = Color3.fromRGB(14, 10, 6),
    toggleOn  = Color3.fromRGB(80, 200, 100),
    toggleOff = Color3.fromRGB(80, 55, 30),
}

-- =============================================
-- HELPER: Make draggable
-- =============================================
local function makeDraggable(frame, handle)
    local dragging, dragInput, dragStart, startPos
    handle = handle or frame

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- =============================================
-- HELPER: Add log entry
-- =============================================
local logFrame -- forward declare
local function addLog(msg, color)
    color = color or C.textMain
    if not logFrame then return end

    local entry = Instance.new("TextLabel")
    entry.Size = UDim2.new(1, -8, 0, 16)
    entry.BackgroundTransparency = 1
    entry.Text = "› " .. msg
    entry.TextColor3 = color
    entry.TextSize = 11
    entry.Font = Enum.Font.Code
    entry.TextXAlignment = Enum.TextXAlignment.Left
    entry.TextWrapped = true
    entry.AutomaticSize = Enum.AutomaticSize.Y
    entry.Parent = logFrame

    -- Auto scroll to bottom
    task.defer(function()
        local scroll = logFrame.Parent
        if scroll:IsA("ScrollingFrame") then
            scroll.CanvasPosition = Vector2.new(0, scroll.AbsoluteCanvasSize.Y)
        end
    end)
end

-- =============================================
-- BUILD MAIN GUI
-- =============================================

-- Main frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 250, 0, 345)
mainFrame.Position = UDim2.new(0.5, -125, 0.5, -172)
mainFrame.BackgroundColor3 = C.bg
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

-- Border glow effect
local borderFrame = Instance.new("UIStroke", mainFrame)
borderFrame.Color = C.border
borderFrame.Thickness = 1.5
borderFrame.Transparency = 0.2

-- =============================================
-- TITLE BAR (draggable handle)
-- =============================================
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.Position = UDim2.new(0, 0, 0, 0)
titleBar.BackgroundColor3 = C.panel
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

-- Bottom of title bar fills corners
local titleBarFill = Instance.new("Frame")
titleBarFill.Size = UDim2.new(1, 0, 0, 10)
titleBarFill.Position = UDim2.new(0, 0, 1, -10)
titleBarFill.BackgroundColor3 = C.panel
titleBarFill.BorderSizePixel = 0
titleBarFill.Parent = titleBar

-- Turkey emoji + title
local titleEmoji = Instance.new("TextLabel")
titleEmoji.Size = UDim2.new(0, 30, 1, 0)
titleEmoji.Position = UDim2.new(0, 10, 0, 0)
titleEmoji.BackgroundTransparency = 1
titleEmoji.Text = "🦃"
titleEmoji.TextSize = 18
titleEmoji.Font = Enum.Font.GothamBold
titleEmoji.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -80, 1, 0)
titleLabel.Position = UDim2.new(0, 44, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Turkey Hunt"
titleLabel.TextColor3 = C.accent
titleLabel.TextSize = 14
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

-- Separator line under title
local sep = Instance.new("Frame")
sep.Size = UDim2.new(1, -20, 0, 1)
sep.Position = UDim2.new(0, 10, 0, 36)
sep.BackgroundColor3 = C.border
sep.BackgroundTransparency = 0.6
sep.BorderSizePixel = 0
sep.Parent = mainFrame

makeDraggable(mainFrame, titleBar)

-- =============================================
-- CONTENT AREA
-- =============================================
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 0, 296)
content.Position = UDim2.new(0, 10, 0, 44)
content.BackgroundTransparency = 1
content.Parent = mainFrame

local contentLayout = Instance.new("UIListLayout", content)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Padding = UDim.new(0, 5)

-- =============================================
-- STATUS ROW
-- =============================================
local statusRow = Instance.new("Frame")
statusRow.Size = UDim2.new(1, 0, 0, 30)
statusRow.BackgroundColor3 = C.panel
statusRow.BorderSizePixel = 0
statusRow.LayoutOrder = 1
statusRow.Parent = content
Instance.new("UICorner", statusRow).CornerRadius = UDim.new(0, 6)

local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0, 8, 0, 8)
statusDot.Position = UDim2.new(0, 12, 0.5, -4)
statusDot.BackgroundColor3 = C.red
statusDot.BorderSizePixel = 0
statusDot.Parent = statusRow
Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -30, 1, 0)
statusLabel.Position = UDim2.new(0, 28, 0, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Idle — press Start to begin"
statusLabel.TextColor3 = C.textDim
statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = statusRow

-- =============================================
-- TOGGLE BUTTON
-- =============================================
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(1, 0, 0, 36)
toggleBtn.BackgroundColor3 = C.toggleOff
toggleBtn.Text = ""
toggleBtn.BorderSizePixel = 0
toggleBtn.LayoutOrder = 2
toggleBtn.Parent = content
Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)

local toggleInner = Instance.new("Frame")
toggleInner.Size = UDim2.new(1, -4, 1, -4)
toggleInner.Position = UDim2.new(0, 2, 0, 2)
toggleInner.BackgroundTransparency = 1
toggleInner.Parent = toggleBtn

local toggleIcon = Instance.new("TextLabel")
toggleIcon.Size = UDim2.new(0, 30, 1, 0)
toggleIcon.Position = UDim2.new(0, 10, 0, 0)
toggleIcon.BackgroundTransparency = 1
toggleIcon.Text = "▶"
toggleIcon.TextColor3 = Color3.fromRGB(255,255,255)
toggleIcon.TextSize = 14
toggleIcon.Font = Enum.Font.GothamBold
toggleIcon.Parent = toggleInner

local toggleText = Instance.new("TextLabel")
toggleText.Size = UDim2.new(1, -50, 1, 0)
toggleText.Position = UDim2.new(0, 40, 0, 0)
toggleText.BackgroundTransparency = 1
toggleText.Text = "Start Hunt"
toggleText.TextColor3 = Color3.fromRGB(255,255,255)
toggleText.TextSize = 13
toggleText.Font = Enum.Font.GothamBold
toggleText.TextXAlignment = Enum.TextXAlignment.Left
toggleText.Parent = toggleInner

-- =============================================
-- STATS ROW (dishes + round)
-- =============================================
local statsRow = Instance.new("Frame")
statsRow.Size = UDim2.new(1, 0, 0, 40)
statsRow.BackgroundTransparency = 1
statsRow.LayoutOrder = 3
statsRow.Parent = content

local statsLayout = Instance.new("UIListLayout", statsRow)
statsLayout.FillDirection = Enum.FillDirection.Horizontal
statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
statsLayout.Padding = UDim.new(0, 8)

local function makeStatBox(label, defaultVal, order)
    local box = Instance.new("Frame")
    box.Size = UDim2.new(0.5, -4, 1, 0)
    box.BackgroundColor3 = C.panel
    box.BorderSizePixel = 0
    box.LayoutOrder = order
    box.Parent = statsRow
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

    local val = Instance.new("TextLabel")
    val.Size = UDim2.new(1, 0, 0, 24)
    val.Position = UDim2.new(0, 0, 0, 4)
    val.BackgroundTransparency = 1
    val.Text = defaultVal
    val.TextColor3 = C.accent
    val.TextSize = 16
    val.Font = Enum.Font.GothamBold
    val.Parent = box

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 14)
    lbl.Position = UDim2.new(0, 0, 1, -16)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = C.textDim
    lbl.TextSize = 10
    lbl.Font = Enum.Font.Gotham
    lbl.Parent = box

    return val
end

local dishesVal = makeStatBox("dishes collected", "0 / 10", 1)
local roundVal  = makeStatBox("round", "—", 2)

-- =============================================
-- TIMER
-- =============================================
local timerBox = Instance.new("Frame")
timerBox.Size = UDim2.new(1, 0, 0, 30)
timerBox.BackgroundColor3 = C.panel
timerBox.BorderSizePixel = 0
timerBox.LayoutOrder = 4
timerBox.Parent = content
Instance.new("UICorner", timerBox).CornerRadius = UDim.new(0, 6)

local timerIcon = Instance.new("TextLabel")
timerIcon.Size = UDim2.new(0, 24, 1, 0)
timerIcon.Position = UDim2.new(0, 8, 0, 0)
timerIcon.BackgroundTransparency = 1
timerIcon.Text = "⏱"
timerIcon.TextSize = 14
timerIcon.Font = Enum.Font.GothamBold
timerIcon.Parent = timerBox

local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(1, -40, 1, 0)
timerLabel.Position = UDim2.new(0, 34, 0, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.Text = "Next hunt: —"
timerLabel.TextColor3 = C.textDim
timerLabel.TextSize = 11
timerLabel.Font = Enum.Font.Code
timerLabel.TextXAlignment = Enum.TextXAlignment.Left
timerLabel.Parent = timerBox

-- =============================================
-- LOG SECTION
-- =============================================
local logHeader = Instance.new("TextLabel")
logHeader.Size = UDim2.new(1, 0, 0, 14)
logHeader.BackgroundTransparency = 1
logHeader.Text = "Activity Log"
logHeader.TextColor3 = C.textDim
logHeader.TextSize = 10
logHeader.Font = Enum.Font.GothamBold
logHeader.TextXAlignment = Enum.TextXAlignment.Left
logHeader.LayoutOrder = 5
logHeader.Parent = content

local logScroll = Instance.new("ScrollingFrame")
logScroll.Size = UDim2.new(1, 0, 0, 105)
logScroll.BackgroundColor3 = C.logBg
logScroll.BorderSizePixel = 0
logScroll.ScrollBarThickness = 3
logScroll.ScrollBarImageColor3 = C.border
logScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
logScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
logScroll.LayoutOrder = 6
logScroll.Parent = content
Instance.new("UICorner", logScroll).CornerRadius = UDim.new(0, 6)

logFrame = Instance.new("Frame")
logFrame.Size = UDim2.new(1, 0, 0, 0)
logFrame.AutomaticSize = Enum.AutomaticSize.Y
logFrame.BackgroundTransparency = 1
logFrame.Parent = logScroll

local logLayout = Instance.new("UIListLayout", logFrame)
logLayout.SortOrder = Enum.SortOrder.LayoutOrder
logLayout.Padding = UDim.new(0, 2)

local logPadding = Instance.new("UIPadding", logFrame)
logPadding.PaddingLeft = UDim.new(0, 4)
logPadding.PaddingTop = UDim.new(0, 4)
logPadding.PaddingBottom = UDim.new(0, 4)

-- =============================================
-- HIDE BUTTON (compact floating pill; stays visible when the main panel is hidden)
-- =============================================
local hideBtn = Instance.new("TextButton")
hideBtn.Size = UDim2.new(0, 66, 0, 25)
hideBtn.Position = UDim2.new(0.5, -33, 0, 405)
hideBtn.BackgroundColor3 = C.panel
hideBtn.Text = "⬆  Hide"
hideBtn.TextColor3 = C.textDim
hideBtn.TextSize = 11
hideBtn.Font = Enum.Font.GothamBold
hideBtn.BorderSizePixel = 0
hideBtn.Parent = screenGui
Instance.new("UICorner", hideBtn).CornerRadius = UDim.new(0, 20)
Instance.new("UIStroke", hideBtn).Color = C.border

makeDraggable(hideBtn)

local guiVisible = true

local hidePressPosition

hideBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        hidePressPosition = input.Position
    end
end)

hideBtn.InputEnded:Connect(function(input)
    if not hidePressPosition then return end

    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        local moved = (input.Position - hidePressPosition).Magnitude
        hidePressPosition = nil

        -- Only toggle on a tap/click; dragging the pill just moves it.
        if moved <= 8 then
            guiVisible = not guiVisible
            mainFrame.Visible = guiVisible
            hideBtn.Text = guiVisible and "⬆  Hide" or "🦃 Show"
        end
    end
end)

-- =============================================
-- UI UPDATE HELPERS
-- =============================================
local function setStatus(text, color)
    statusLabel.Text = text
    statusLabel.TextColor3 = color or C.textDim
    statusDot.BackgroundColor3 = color or C.textDim
end

local function setToggleState(running)
    if running then
        TweenService:Create(toggleBtn, TweenInfo.new(0.2), {BackgroundColor3 = C.toggleOn}):Play()
        toggleText.Text = "Stop Hunt"
        toggleIcon.Text = "■"
    else
        TweenService:Create(toggleBtn, TweenInfo.new(0.2), {BackgroundColor3 = C.toggleOff}):Play()
        toggleText.Text = "Start Hunt"
        toggleIcon.Text = "▶"
    end
end

local function updateDishes(n)
    dishesVal.Text = n .. " / 10"
    if n >= 10 then
        dishesVal.TextColor3 = C.green
    elseif n > 0 then
        dishesVal.TextColor3 = C.accent
    else
        dishesVal.TextColor3 = C.textDim
    end
end

local function startCooldownTimer(seconds)
    cooldownTicking = true
    cooldownRemaining = seconds
    task.spawn(function()
        while cooldownRemaining > 0 and cooldownTicking do
            local m = math.floor(cooldownRemaining / 60)
            local s = cooldownRemaining % 60
            timerLabel.Text = string.format("Next hunt: %d:%02d", m, s)
            timerLabel.TextColor3 = C.accent
            task.wait(1)
            cooldownRemaining = cooldownRemaining - 1
        end
        if cooldownTicking then
            timerLabel.Text = "Next hunt: Ready! 🟢"
            timerLabel.TextColor3 = C.green
            cooldownTicking = false
        end
    end)
end

-- =============================================
-- HUNT LOGIC
-- =============================================
TurkeyHuntEnded.OnClientEvent:Connect(function()
    huntEnded = true
    huntActive = false
    addLog("Hunt ended by server.", C.textDim)
end)

local function dishesExist()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj.Name == "TurkeyHuntDish" then return true end
    end
    return false
end

local function startHunt()
    if dishesExist() or huntActive then
        addLog("Dishes already active, collecting...", C.textDim)
        huntActive = true
        return true
    end

    local ok, rootPart = pcall(function()
        return workspace
            :WaitForChild("ThanksgivingHuntPlatform", 10)
            :WaitForChild("Turkey", 10)
            :WaitForChild("RootPart", 10)
    end)

    if not ok or not rootPart then
        addLog("❌ Turkey NPC not found!", C.red)
        return false
    end

    hrp.CFrame = CFrame.new(rootPart.Position + Vector3.new(0, 3, 0))
    addLog("Teleported to Turkey NPC...", C.textDim)
    task.wait(1.5)

    local success, result = pcall(function()
        return StartTurkeyHunt:InvokeServer()
    end)

    if success and result then
        addLog("✅ Hunt started!", C.green)
        huntActive = true
        return true
    end

    task.wait(3)
    if dishesExist() then
        addLog("✅ Dishes found!", C.green)
        huntActive = true
        return true
    end

    addLog("❌ Failed to start hunt.", C.red)
    return false
end

local function collectDish(dish)
    if not dish or not dish.Parent then return true end

    local huntRoot = dish:FindFirstChild("HuntRoot")
    if not huntRoot then return false end

    local prompt = huntRoot:FindFirstChildOfClass("ProximityPrompt")
    if not prompt then return false end

    hrp.CFrame = CFrame.new(huntRoot.Position + Vector3.new(0, 2, 0))
    task.wait(0.8)

    for i = 1, 5 do
        if not dish.Parent then return true end
        fireproximityprompt(prompt)
        task.wait(0.6)
        if not dish.Parent then return true end
    end

    hrp.CFrame = CFrame.new(huntRoot.Position)
    task.wait(0.5)
    fireproximityprompt(prompt)
    task.wait(0.6)

    return not dish.Parent
end

local function collectAll()
    collected = 0
    updateDishes(0)

    addLog("🔍 Scanning for dishes...", C.textDim)

    while isRunning and collected < 10 and not huntEnded do
        local dishes = {}
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj.Name == "TurkeyHuntDish" then
                table.insert(dishes, obj)
            end
        end

        setStatus("Collecting — " .. collected .. "/10 dishes", C.accent)

        if #dishes == 0 then
            task.wait(1)
            continue
        end

        for _, dish in ipairs(dishes) do
            if not isRunning or huntEnded then break end
            if not dish or not dish.Parent then
                collected = collected + 1
                updateDishes(collected)
                continue
            end

            local success = collectDish(dish)
            if success or not dish.Parent then
                collected = collected + 1
                updateDishes(collected)
                addLog("🍽️ Dish " .. collected .. "/10 collected!", C.green)
            end

            task.wait(0.3)
        end

        task.wait(0.5)
    end

    if collected >= 10 then
        addLog("🎉 All 10 dishes collected!", C.green)
        addLog("🏆 Reward granted by server!", C.accent)
    end
end

local function waitForCooldown()
    huntEnded = false
    huntActive = false
    local waited = 0
    local maxWait = 900 -- 15 minutes

    addLog("⏳ Cooldown started — 15 min wait.", C.textDim)
    setStatus("Cooldown — next hunt in 15:00", C.textDim)
    startCooldownTimer(maxWait)

    while isRunning and not huntEnded and waited < maxWait do
        task.wait(60)
        waited = waited + 60
    end

    cooldownTicking = false
    addLog("✅ Cooldown done! Starting next round...", C.green)
    task.wait(10)
end

local function mainLoop()
    while isRunning do
        roundNumber = roundNumber + 1
        huntEnded = false
        roundVal.Text = "#" .. roundNumber

        addLog("── Round " .. roundNumber .. " starting ──", C.accent)
        setStatus("Starting hunt...", C.accent)

        local started = startHunt()

        if not started then
            addLog("⚠️ Retrying in 15s...", C.red)
            setStatus("Failed to start — retrying", C.red)
            task.wait(15)
            continue
        end

        setStatus("Waiting for dishes to spawn...", C.accent)
        task.wait(5)

        collectAll()

        if isRunning then
            waitForCooldown()
        end
    end

    setStatus("Stopped", C.textDim)
    addLog("── Script stopped ──", C.textDim)
end

-- =============================================
-- TOGGLE BUTTON HANDLER
-- =============================================
toggleBtn.MouseButton1Click:Connect(function()
    isRunning = not isRunning
    setToggleState(isRunning)

    if isRunning then
        huntEnded = false
        huntActive = false
        collected = 0
        updateDishes(0)
        addLog("▶ Hunt started by user.", C.green)
        setStatus("Starting...", C.accent)
        task.spawn(mainLoop)
    else
        cooldownTicking = false
        addLog("■ Hunt stopped by user.", C.red)
        setStatus("Stopped by user", C.red)
        timerLabel.Text = "Next hunt: —"
        timerLabel.TextColor3 = C.textDim
    end
end)

-- =============================================
-- STARTUP LOG
-- =============================================
addLog("Turkey Hunt GUI loaded ✅", C.green)
addLog("Press Start Hunt to begin.", C.textDim)
