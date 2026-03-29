--[[
    ╔═══════════════════════════════════════════════╗
    ║          SENTINEL GUI LIBRARY v2.0            ║
    ║       GameSense Style • Roblox Lua            ║
    ║                                               ║
    ║  Features:                                    ║
    ║  • RGB Animated Header                        ║
    ║  • Multi-Scaling & Mobile Support             ║
    ║  • Customizable Fonts                         ║
    ║  • Toggle, Slider, Dropdown, Keybind          ║
    ║  • Multi-Bind System (Right-Click)            ║
    ║  • Watermark with FPS/Ping/Time               ║
    ║  • Strict GameSense Animations                ║
    ╚═══════════════════════════════════════════════╝
]]--

-- ═══════════════════════════════════════
-- SECTION 1: SERVICES & CONFIGURATION
-- ═══════════════════════════════════════

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local GuiService = game:GetService("GuiService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ═══════════════════════════════════════
-- SECTION 2: LIBRARY CORE TABLE
-- ═══════════════════════════════════════

local Sentinel = {
    Version = "2.0",
    Windows = {},
    Flags = {},
    Binds = {},
    Connections = {},
    ToggleKey = Enum.KeyCode.RightControl,
    Visible = true,
    Scale = IsMobile and 0.75 or 1,
    RGBSpeed = 1,
    RGBEnabled = true,
    CurrentFont = Enum.Font.Gotham,
    
    Theme = {
        Background    = Color3.fromRGB(16, 16, 16),
        Primary       = Color3.fromRGB(22, 22, 22),
        Secondary     = Color3.fromRGB(28, 28, 28),
        Tertiary      = Color3.fromRGB(36, 36, 36),
        Accent        = Color3.fromRGB(156, 120, 255),
        Text          = Color3.fromRGB(215, 215, 215),
        SubText       = Color3.fromRGB(140, 140, 140),
        Disabled      = Color3.fromRGB(70, 70, 70),
        Border        = Color3.fromRGB(48, 48, 48),
        DarkBorder    = Color3.fromRGB(10, 10, 10),
        ElementBg     = Color3.fromRGB(32, 32, 32),
        ToggleOn      = Color3.fromRGB(156, 120, 255),
        ToggleOff     = Color3.fromRGB(50, 50, 50),
        SliderBg      = Color3.fromRGB(40, 40, 40),
        SliderFill    = Color3.fromRGB(156, 120, 255),
        DropdownBg    = Color3.fromRGB(24, 24, 24),
        Hover         = Color3.fromRGB(42, 42, 42),
        Shadow        = Color3.fromRGB(0, 0, 0),
    },
    
    FontMap = {
        ["Gotham"]         = Enum.Font.Gotham,
        ["GothamBold"]     = Enum.Font.GothamBold,
        ["GothamMedium"]   = Enum.Font.GothamMedium,
        ["SourceSans"]     = Enum.Font.SourceSans,
        ["SourceSansBold"] = Enum.Font.SourceSansBold,
        ["Code"]           = Enum.Font.Code,
        ["Ubuntu"]         = Enum.Font.Ubuntu,
        ["Roboto"]         = Enum.Font.Roboto,
        ["RobotoMono"]     = Enum.Font.RobotoMono,
    },
    
    AllTextLabels = {},
    AllElements = {},
}

-- ═══════════════════════════════════════
-- SECTION 3: UTILITY FUNCTIONS
-- ═══════════════════════════════════════

local function Create(className, props, children)
    local inst = Instance.new(className)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then
            pcall(function() inst[k] = v end)
        end
    end
    for _, child in pairs(children or {}) do
        child.Parent = inst
    end
    if props and props.Parent then
        inst.Parent = props.Parent
    end
    return inst
end

local function Tween(inst, props, duration, style, direction)
    local tweenInfo = TweenInfo.new(
        duration or 0.2,
        style or Enum.EasingStyle.Quad,
        direction or Enum.EasingDirection.Out
    )
    local tween = TweenService:Create(inst, tweenInfo, props)
    tween:Play()
    return tween
end

local function Ripple(frame, posX, posY)
    local circle = Create("Frame", {
        Parent = frame,
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.85,
        Position = UDim2.new(0, posX, 0, posY),
        Size = UDim2.new(0, 0, 0, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ZIndex = frame.ZIndex + 5,
    })
    Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = circle})
    
    local maxSize = math.max(frame.AbsoluteSize.X, frame.AbsoluteSize.Y) * 2
    Tween(circle, {Size = UDim2.new(0, maxSize, 0, maxSize), BackgroundTransparency = 1}, 0.5)
    task.delay(0.5, function()
        if circle then circle:Destroy() end
    end)
end

local function HSVToRGB(h, s, v)
    return Color3.fromHSV(h % 1, s, v)
end

local function GetRGBColor(offset)
    offset = offset or 0
    local time = tick() * Sentinel.RGBSpeed
    return HSVToRGB((time + offset) % 1, 0.7, 1)
end

local function Truncate(number, decimals)
    local mult = 10 ^ (decimals or 0)
    return math.floor(number * mult) / mult
end

local function GetKeyName(keyCode)
    if not keyCode then return "..." end
    local name = keyCode.Name
    local aliases = {
        LeftShift = "LSHIFT", RightShift = "RSHIFT",
        LeftControl = "LCTRL", RightControl = "RCTRL",
        LeftAlt = "LALT", RightAlt = "RALT",
        Return = "ENTER", Backspace = "BKSP",
        CapsLock = "CAPS",
    }
    return aliases[name] or name:upper()
end

local function DeepCopy(t)
    local copy = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            copy[k] = DeepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

local function AddConnection(conn)
    table.insert(Sentinel.Connections, conn)
    return conn
end

-- ═══════════════════════════════════════
-- SECTION 4: SCREEN GUI SETUP
-- ═══════════════════════════════════════

local ScreenGui = Create("ScreenGui", {
    Name = "SentinelGUI_" .. tostring(math.random(1000, 9999)),
    Parent = PlayerGui,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999,
})

-- UI Scale for multi-scaling
local UIScale = Create("UIScale", {
    Scale = Sentinel.Scale,
    Parent = ScreenGui,
})

function Sentinel:SetScale(scale)
    self.Scale = math.clamp(scale, 0.5, 2)
    Tween(UIScale, {Scale = self.Scale}, 0.3)
end

-- ═══════════════════════════════════════
-- SECTION 5: RGB GRADIENT BAR
-- ═══════════════════════════════════════

local RGB_SEGMENTS = 60

local function CreateRGBBar(parent, height, zIndex)
    height = height or 2
    
    local barContainer = Create("Frame", {
        Parent = parent,
        Name = "RGBBar",
        Size = UDim2.new(1, 0, 0, height),
        Position = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        ZIndex = zIndex or 10,
        ClipsDescendants = true,
    })
    
    local segments = {}
    for i = 1, RGB_SEGMENTS do
        local seg = Create("Frame", {
            Parent = barContainer,
            Name = "Seg_" .. i,
            Size = UDim2.new(1 / RGB_SEGMENTS, 1, 1, 0),
            Position = UDim2.new((i - 1) / RGB_SEGMENTS, 0, 0, 0),
            BackgroundColor3 = Color3.fromHSV((i - 1) / RGB_SEGMENTS, 0.75, 1),
            BorderSizePixel = 0,
            ZIndex = zIndex or 10,
        })
        segments[i] = seg
    end
    
    -- Animation connection
    local conn = RunService.Heartbeat:Connect(function()
        if not Sentinel.RGBEnabled then
            for i, seg in ipairs(segments) do
                seg.BackgroundColor3 = Sentinel.Theme.Accent
            end
            return
        end
        
        local time = tick() * Sentinel.RGBSpeed * 0.5
        for i, seg in ipairs(segments) do
            local hue = (time + (i - 1) / RGB_SEGMENTS) % 1
            seg.BackgroundColor3 = Color3.fromHSV(hue, 0.65, 1)
        end
    end)
    AddConnection(conn)
    
    return barContainer
end

-- ═══════════════════════════════════════
-- SECTION 6: WATERMARK
-- ═══════════════════════════════════════

function Sentinel:CreateWatermark()
    local watermark = Create("Frame", {
        Parent = ScreenGui,
        Name = "Watermark",
        Size = UDim2.new(0, 320, 0, 28),
        Position = UDim2.new(1, -330, 0, 12),
        BackgroundColor3 = self.Theme.Primary,
        BorderSizePixel = 0,
        ZIndex = 100,
    })
    
    -- Outer border
    Create("UIStroke", {
        Parent = watermark,
        Color = self.Theme.DarkBorder,
        Thickness = 1,
    })
    
    -- Inner border
    local innerBorder = Create("Frame", {
        Parent = watermark,
        Size = UDim2.new(1, -4, 1, -4),
        Position = UDim2.new(0, 2, 0, 2),
        BackgroundColor3 = self.Theme.Primary,
        BorderSizePixel = 0,
        ZIndex = 101,
    })
    Create("UIStroke", {
        Parent = innerBorder,
        Color = self.Theme.Border,
        Thickness = 1,
    })
    
    -- RGB bar on top
    local rgbBar = CreateRGBBar(watermark, 2, 105)
    
    -- Text
    local wmText = Create("TextLabel", {
        Parent = innerBorder,
        Size = UDim2.new(1, -10, 1, 0),
        Position = UDim2.new(0, 5, 0, 0),
        BackgroundTransparency = 1,
        Text = "SENTINEL",
        TextColor3 = self.Theme.Text,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 102,
    })
    table.insert(self.AllTextLabels, wmText)
    
    -- Update watermark
    local fpsValues = {}
    local conn = RunService.Heartbeat:Connect(function(dt)
        if not watermark or not watermark.Parent then return end
        
        table.insert(fpsValues, 1/dt)
        if #fpsValues > 30 then table.remove(fpsValues, 1) end
        
        local avgFPS = 0
        for _, v in ipairs(fpsValues) do avgFPS = avgFPS + v end
        avgFPS = math.floor(avgFPS / #fpsValues)
        
        local ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        local timeStr = os.date("%H:%M:%S")
        
        wmText.Text = string.format(
            "SENTINEL  |  %s  |  %d fps  |  %dms  |  %s",
            Player.Name, avgFPS, ping, timeStr
        )
        
        -- Auto-resize
        local textWidth = wmText.TextBounds.X + 20
        watermark.Size = UDim2.new(0, math.max(textWidth, 200), 0, 28)
        watermark.Position = UDim2.new(1, -(math.max(textWidth, 200) + 10), 0, 12)
    end)
    AddConnection(conn)
    
    self.Watermark = watermark
    return watermark
end

-- ═══════════════════════════════════════
-- SECTION 7: NOTIFICATION SYSTEM
-- ═══════════════════════════════════════

function Sentinel:Notify(title, text, duration)
    duration = duration or 3
    
    local notif = Create("Frame", {
        Parent = ScreenGui,
        Size = UDim2.new(0, 300, 0, 60),
        Position = UDim2.new(1, 310, 1, -80),
        BackgroundColor3 = self.Theme.Primary,
        BorderSizePixel = 0,
        ZIndex = 200,
    })
    Create("UIStroke", {Parent = notif, Color = self.Theme.DarkBorder, Thickness = 1})
    Create("UICorner", {CornerRadius = UDim.new(0, 3), Parent = notif})
    
    -- RGB bar
    CreateRGBBar(notif, 2, 205)
    
    local titleLabel = Create("TextLabel", {
        Parent = notif,
        Size = UDim2.new(1, -10, 0, 20),
        Position = UDim2.new(0, 8, 0, 6),
        BackgroundTransparency = 1,
        Text = title or "SENTINEL",
        TextColor3 = self.Theme.Accent,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 201,
    })
    
    local textLabel = Create("TextLabel", {
        Parent = notif,
        Size = UDim2.new(1, -10, 0, 20),
        Position = UDim2.new(0, 8, 0, 26),
        BackgroundTransparency = 1,
        Text = text or "",
        TextColor3 = self.Theme.SubText,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 201,
    })
    
    -- Progress bar
    local progressBg = Create("Frame", {
        Parent = notif,
        Size = UDim2.new(1, -16, 0, 2),
        Position = UDim2.new(0, 8, 1, -8),
        BackgroundColor3 = self.Theme.Tertiary,
        BorderSizePixel = 0,
        ZIndex = 201,
    })
    
    local progressFill = Create("Frame", {
        Parent = progressBg,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = self.Theme.Accent,
        BorderSizePixel = 0,
        ZIndex = 202,
    })
    
    -- Animate in
    Tween(notif, {Position = UDim2.new(1, -310, 1, -80)}, 0.4, Enum.EasingStyle.Quart)
    
    -- Progress
    Tween(progressFill, {Size = UDim2.new(0, 0, 1, 0)}, duration, Enum.EasingStyle.Linear)
    
    -- Animate out
    task.delay(duration, function()
        Tween(notif, {Position = UDim2.new(1, 310, 1, -80)}, 0.4, Enum.EasingStyle.Quart)
        task.delay(0.5, function()
            if notif then notif:Destroy() end
        end)
    end)
end

-- ═══════════════════════════════════════
-- SECTION 8: CONTEXT MENU (BIND SYSTEM)
-- ═══════════════════════════════════════

local ContextMenu = nil
local ActiveBindElement = nil

local function ShowContextMenu(element, position, callback)
    -- Remove existing context menu
    if ContextMenu then ContextMenu:Destroy() end
    
    local menu = Create("Frame", {
        Parent = ScreenGui,
        Size = UDim2.new(0, 140, 0, 0),
        Position = UDim2.new(0, position.X, 0, position.Y),
        BackgroundColor3 = Sentinel.Theme.Primary,
        BorderSizePixel = 0,
        ZIndex = 500,
        ClipsDescendants = true,
    })
    Create("UIStroke", {Parent = menu, Color = Sentinel.Theme.Border, Thickness = 1})
    Create("UICorner", {CornerRadius = UDim.new(0, 3), Parent = menu})
    
    local options = {"Bind Key", "Copy Name", "Reset"}
    local optionHeight = 24
    local totalHeight = #options * optionHeight + 4
    
    Tween(menu, {Size = UDim2.new(0, 140, 0, totalHeight)}, 0.15, Enum.EasingStyle.Quart)
    
    for i, optName in ipairs(options) do
        local btn = Create("TextButton", {
            Parent = menu,
            Size = UDim2.new(1, -4, 0, optionHeight),
            Position = UDim2.new(0, 2, 0, (i - 1) * optionHeight + 2),
            BackgroundColor3 = Sentinel.Theme.Primary,
            BackgroundTransparency = 1,
            Text = "  " .. optName,
            TextColor3 = Sentinel.Theme.SubText,
            TextSize = 11,
            Font = Sentinel.CurrentFont,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 501,
            AutoButtonColor = false,
        })
        
        btn.MouseEnter:Connect(function()
            Tween(btn, {BackgroundTransparency = 0, BackgroundColor3 = Sentinel.Theme.Tertiary}, 0.1)
            Tween(btn, {TextColor3 = Sentinel.Theme.Text}, 0.1)
        end)
        btn.MouseLeave:Connect(function()
            Tween(btn, {BackgroundTransparency = 1}, 0.1)
            Tween(btn, {TextColor3 = Sentinel.Theme.SubText}, 0.1)
        end)
        
        btn.MouseButton1Click:Connect(function()
            if optName == "Bind Key" then
                callback("bind")
            elseif optName == "Copy Name" then
                callback("copy")
            elseif optName == "Reset" then
                callback("reset")
            end
            if menu then
                Tween(menu, {Size = UDim2.new(0, 140, 0, 0)}, 0.1)
                task.delay(0.1, function()
                    if menu then menu:Destroy() end
                end)
            end
            ContextMenu = nil
        end)
    end
    
    ContextMenu = menu
    
    -- Close on click elsewhere
    local closeConn
    closeConn = UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            task.wait(0.05)
            if menu and menu.Parent then
                local mousePos = UserInputService:GetMouseLocation()
                local menuPos = menu.AbsolutePosition
                local menuSize = menu.AbsoluteSize
                if mousePos.X < menuPos.X or mousePos.X > menuPos.X + menuSize.X
                    or mousePos.Y < menuPos.Y or mousePos.Y > menuPos.Y + menuSize.Y then
                    Tween(menu, {Size = UDim2.new(0, 140, 0, 0)}, 0.1)
                    task.delay(0.1, function()
                        if menu then menu:Destroy() end
                    end)
                    ContextMenu = nil
                    closeConn:Disconnect()
                end
            else
                closeConn:Disconnect()
            end
        end
    end)
    AddConnection(closeConn)
end

-- ═══════════════════════════════════════
-- SECTION 9: WINDOW CREATION
-- ═══════════════════════════════════════

function Sentinel:CreateWindow(config)
    config = config or {}
    local windowTitle = config.Title or "SENTINEL"
    local windowSize = config.Size or UDim2.new(0, 580, 0, 460)
    local toggleKey = config.ToggleKey or Enum.KeyCode.RightControl
    
    self.ToggleKey = toggleKey
    
    local Window = {
        Tabs = {},
        ActiveTab = nil,
        Elements = {},
    }
    
    -- ═══ MAIN CONTAINER ═══
    
    -- Shadow
    local shadow = Create("ImageLabel", {
        Parent = ScreenGui,
        Name = "WindowShadow",
        Size = UDim2.new(0, windowSize.X.Offset + 40, 0, windowSize.Y.Offset + 40),
        Position = UDim2.new(0.5, -windowSize.X.Offset/2 - 20, 0.5, -windowSize.Y.Offset/2 - 20),
        BackgroundTransparency = 1,
        Image = "rbxassetid://6014261993",
        ImageColor3 = Color3.fromRGB(0, 0, 0),
        ImageTransparency = 0.5,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        ZIndex = 0,
    })
    
    -- Main Window Frame
    local mainFrame = Create("Frame", {
        Parent = ScreenGui,
        Name = "SentinelWindow",
        Size = windowSize,
        Position = UDim2.new(0.5, -windowSize.X.Offset/2, 0.5, -windowSize.Y.Offset/2),
        BackgroundColor3 = self.Theme.Background,
        BorderSizePixel = 0,
        ZIndex = 1,
        ClipsDescendants = true,
    })
    
    -- Outer border
    Create("UIStroke", {
        Parent = mainFrame,
        Color = self.Theme.DarkBorder,
        Thickness = 1,
    })
    
    -- Inner border frame
    local innerFrame = Create("Frame", {
        Parent = mainFrame,
        Size = UDim2.new(1, -6, 1, -6),
        Position = UDim2.new(0, 3, 0, 3),
        BackgroundColor3 = self.Theme.Primary,
        BorderSizePixel = 0,
        ZIndex = 2,
    })
    Create("UIStroke", {
        Parent = innerFrame,
        Color = self.Theme.Border,
        Thickness = 1,
    })
    
    -- ═══ RGB BAR ═══
    local rgbBar = CreateRGBBar(innerFrame, 2, 50)
    
    -- ═══ HEADER ═══
    local header = Create("Frame", {
        Parent = innerFrame,
        Size = UDim2.new(1, 0, 0, 32),
        Position = UDim2.new(0, 0, 0, 2),
        BackgroundTransparency = 1,
        ZIndex = 3,
    })
    
    -- Logo (geometric sentinel icon)
    local logoFrame = Create("Frame", {
        Parent = header,
        Size = UDim2.new(0, 18, 0, 18),
        Position = UDim2.new(0, 10, 0.5, -9),
        BackgroundColor3 = self.Theme.Accent,
        BorderSizePixel = 0,
        Rotation = 45,
        ZIndex = 5,
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 3), Parent = logoFrame})
    
    local logoInner = Create("Frame", {
        Parent = logoFrame,
        Size = UDim2.new(0, 10, 0, 10),
        Position = UDim2.new(0.5, -5, 0.5, -5),
        BackgroundColor3 = self.Theme.Primary,
        BorderSizePixel = 0,
        ZIndex = 6,
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = logoInner})
    
    -- Animate logo with RGB
    AddConnection(RunService.Heartbeat:Connect(function()
        if Sentinel.RGBEnabled then
            logoFrame.BackgroundColor3 = GetRGBColor(0)
        else
            logoFrame.BackgroundColor3 = Sentinel.Theme.Accent
        end
    end))
    
    -- Title
    local titleLabel = Create("TextLabel", {
        Parent = header,
        Size = UDim2.new(0, 200, 1, 0),
        Position = UDim2.new(0, 36, 0, 0),
        BackgroundTransparency = 1,
        Text = windowTitle,
        TextColor3 = self.Theme.Text,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    })
    table.insert(self.AllTextLabels, titleLabel)
    
    -- Version label
    local versionLabel = Create("TextLabel", {
        Parent = header,
        Size = UDim2.new(0, 50, 1, 0),
        Position = UDim2.new(0, 36 + titleLabel.TextBounds.X + 6, 0, 0),
        BackgroundTransparency = 1,
        Text = "v" .. self.Version,
        TextColor3 = self.Theme.SubText,
        TextSize = 10,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    })
    
    -- Close button
    local closeBtn = Create("TextButton", {
        Parent = header,
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(1, -32, 0.5, -14),
        BackgroundTransparency = 1,
        Text = "×",
        TextColor3 = self.Theme.SubText,
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        ZIndex = 5,
        AutoButtonColor = false,
    })
    closeBtn.MouseEnter:Connect(function()
        Tween(closeBtn, {TextColor3 = Color3.fromRGB(255, 80, 80)}, 0.15)
    end)
    closeBtn.MouseLeave:Connect(function()
        Tween(closeBtn, {TextColor3 = self.Theme.SubText}, 0.15)
    end)
    closeBtn.MouseButton1Click:Connect(function()
        self:Toggle()
    end)
    
    -- Minimize button
    local minBtn = Create("TextButton", {
        Parent = header,
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(1, -58, 0.5, -14),
        BackgroundTransparency = 1,
        Text = "—",
        TextColor3 = self.Theme.SubText,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        ZIndex = 5,
        AutoButtonColor = false,
    })
    minBtn.MouseEnter:Connect(function()
        Tween(minBtn, {TextColor3 = self.Theme.Text}, 0.15)
    end)
    minBtn.MouseLeave:Connect(function()
        Tween(minBtn, {TextColor3 = self.Theme.SubText}, 0.15)
    end)
    
    -- ═══ HEADER SEPARATOR ═══
    Create("Frame", {
        Parent = innerFrame,
        Size = UDim2.new(1, -8, 0, 1),
        Position = UDim2.new(0, 4, 0, 34),
        BackgroundColor3 = self.Theme.Border,
        BorderSizePixel = 0,
        ZIndex = 3,
    })
    
    -- ═══ TAB BAR ═══
    local tabBar = Create("Frame", {
        Parent = innerFrame,
        Size = UDim2.new(1, -8, 0, 28),
        Position = UDim2.new(0, 4, 0, 36),
        BackgroundColor3 = self.Theme.Secondary,
        BorderSizePixel = 0,
        ZIndex = 3,
        ClipsDescendants = true,
    })
    Create("UIStroke", {
        Parent = tabBar,
        Color = self.Theme.Border,
        Thickness = 1,
    })
    
    local tabButtonContainer = Create("Frame", {
        Parent = tabBar,
        Size = UDim2.new(1, -4, 1, -4),
        Position = UDim2.new(0, 2, 0, 2),
        BackgroundTransparency = 1,
        ZIndex = 4,
        ClipsDescendants = true,
    })
    
    local tabLayout = Create("UIListLayout", {
        Parent = tabButtonContainer,
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
    })
    
    -- ═══ TAB SEPARATOR ═══
    Create("Frame", {
        Parent = innerFrame,
        Size = UDim2.new(1, -8, 0, 1),
        Position = UDim2.new(0, 4, 0, 65),
        BackgroundColor3 = self.Theme.Border,
        BorderSizePixel = 0,
        ZIndex = 3,
    })
    
    -- ═══ CONTENT AREA ═══
    local contentArea = Create("Frame", {
        Parent = innerFrame,
        Size = UDim2.new(1, -12, 1, -72),
        Position = UDim2.new(0, 6, 0, 68),
        BackgroundTransparency = 1,
        ZIndex = 3,
        ClipsDescendants = true,
    })
    
    -- ═══ DRAGGING ═══
    local dragging, dragStart, startPos
    
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
        end
    end)
    
    header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    AddConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement 
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            local newPos = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
            Tween(mainFrame, {Position = newPos}, 0.08, Enum.EasingStyle.Quart)
            
            -- Update shadow position
            shadow.Position = UDim2.new(
                0, mainFrame.AbsolutePosition.X - 20,
                0, mainFrame.AbsolutePosition.Y - 20
            )
        end
    end))
    
    -- Keep shadow in sync
    AddConnection(RunService.Heartbeat:Connect(function()
        if shadow and mainFrame then
            shadow.Position = UDim2.new(
                0, mainFrame.AbsolutePosition.X - 20,
                0, mainFrame.AbsolutePosition.Y - 20
            )
            shadow.Size = UDim2.new(
                0, mainFrame.AbsoluteSize.X + 40,
                0, mainFrame.AbsoluteSize.Y + 40
            )
        end
    end))
    
    -- ═══ TOGGLE VISIBILITY ═══
    function self:Toggle()
        self.Visible = not self.Visible
        if self.Visible then
            mainFrame.Visible = true
            shadow.Visible = true
            mainFrame.Size = UDim2.new(0, windowSize.X.Offset, 0, windowSize.Y.Offset * 0.95)
            mainFrame.BackgroundTransparency = 0.3
            Tween(mainFrame, {
                Size = windowSize,
                BackgroundTransparency = 0,
            }, 0.3, Enum.EasingStyle.Quart)
            Tween(shadow, {ImageTransparency = 0.5}, 0.3)
        else
            Tween(mainFrame, {
                Size = UDim2.new(0, windowSize.X.Offset, 0, windowSize.Y.Offset * 0.95),
                BackgroundTransparency = 0.3,
            }, 0.2, Enum.EasingStyle.Quart)
            Tween(shadow, {ImageTransparency = 1}, 0.2)
            task.delay(0.2, function()
                mainFrame.Visible = false
                shadow.Visible = false
            end)
        end
    end
    
    -- Toggle key handler
    AddConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == self.ToggleKey then
            self:Toggle()
        end
        
        -- Handle all element binds
        for flag, bindData in pairs(self.Binds) do
            if input.KeyCode == bindData.Key then
                if bindData.Callback then
                    bindData.Callback()
                end
            end
        end
    end))
    
    -- ═══ OPEN ANIMATION ═══
    mainFrame.Size = UDim2.new(0, windowSize.X.Offset, 0, windowSize.Y.Offset * 0.95)
    mainFrame.BackgroundTransparency = 0.5
    Tween(mainFrame, {
        Size = windowSize,
        BackgroundTransparency = 0,
    }, 0.4, Enum.EasingStyle.Quart)
    
    -- ═══════════════════════════════════════
    -- TAB CREATION
    -- ═══════════════════════════════════════
    
    function Window:CreateTab(tabConfig)
        tabConfig = tabConfig or {}
        local tabName = tabConfig.Name or "Tab"
        local tabIcon = tabConfig.Icon or ""
        
        local Tab = {
            Sections = {},
            Elements = {},
            Name = tabName,
        }
        
        -- Tab button
        local tabButton = Create("TextButton", {
            Parent = tabButtonContainer,
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = Sentinel.Theme.Tertiary,
            BackgroundTransparency = 1,
            Text = (tabIcon ~= "" and tabIcon .. "  " or "") .. tabName,
            TextColor3 = Sentinel.Theme.SubText,
            TextSize = 11,
            Font = Sentinel.CurrentFont,
            ZIndex = 5,
            AutoButtonColor = false,
            AutomaticSize = Enum.AutomaticSize.X,
        })
        table.insert(Sentinel.AllTextLabels, tabButton)
        
        local tabPadding = Create("UIPadding", {
            Parent = tabButton,
            PaddingLeft = UDim.new(0, 12),
            PaddingRight = UDim.new(0, 12),
        })
        
        -- Tab content frame (two columns)
        local tabContent = Create("Frame", {
            Parent = contentArea,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Visible = false,
            ZIndex = 3,
        })
        
        -- Left column
        local leftColumn = Create("ScrollingFrame", {
            Parent = tabContent,
            Size = UDim2.new(0.5, -3, 1, 0),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Sentinel.Theme.Accent,
            BorderSizePixel = 0,
            ZIndex = 3,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
        })
        local leftLayout = Create("UIListLayout", {
            Parent = leftColumn,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 6),
        })
        Create("UIPadding", {Parent = leftColumn, PaddingBottom = UDim.new(0, 6)})
        
        -- Right column
        local rightColumn = Create("ScrollingFrame", {
            Parent = tabContent,
            Size = UDim2.new(0.5, -3, 1, 0),
            Position = UDim2.new(0.5, 3, 0, 0),
            BackgroundTransparency = 1,
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = Sentinel.Theme.Accent,
            BorderSizePixel = 0,
            ZIndex = 3,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
        })
        local rightLayout = Create("UIListLayout", {
            Parent = rightColumn,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 6),
        })
        Create("UIPadding", {Parent = rightColumn, PaddingBottom = UDim.new(0, 6)})
        
        -- Tab selection
        local function selectTab()
            -- Deselect all tabs
            for _, tab in ipairs(Window.Tabs) do
                Tween(tab._button, {TextColor3 = Sentinel.Theme.SubText, BackgroundTransparency = 1}, 0.15)
                if tab._underline then
                    Tween(tab._underline, {Size = UDim2.new(0, 0, 0, 2), BackgroundTransparency = 1}, 0.15)
                end
                tab._content.Visible = false
            end
            
            -- Select this tab
            Tween(tabButton, {TextColor3 = Sentinel.Theme.Text, BackgroundTransparency = 0.8}, 0.15)
            tabContent.Visible = true
            
            -- Fade in animation
            for _, child in ipairs(tabContent:GetDescendants()) do
                if child:IsA("GuiObject") then
                    local originalTransparency = child.BackgroundTransparency
                    if originalTransparency < 1 then
                        child.BackgroundTransparency = math.min(originalTransparency + 0.3, 1)
                        Tween(child, {BackgroundTransparency = originalTransparency}, 0.2)
                    end
                end
            end
            
            Window.ActiveTab = Tab
        end
        
        tabButton.MouseButton1Click:Connect(selectTab)
        
        tabButton.MouseEnter:Connect(function()
            if Window.ActiveTab ~= Tab then
                Tween(tabButton, {TextColor3 = Sentinel.Theme.Text}, 0.1)
            end
        end)
        tabButton.MouseLeave:Connect(function()
            if Window.ActiveTab ~= Tab then
                Tween(tabButton, {TextColor3 = Sentinel.Theme.SubText}, 0.1)
            end
        end)
        
        Tab._button = tabButton
        Tab._content = tabContent
        
        -- ═══════════════════════════════════════
        -- SECTION CREATION
        -- ═══════════════════════════════════════
        
        function Tab:CreateSection(sectionConfig)
            sectionConfig = sectionConfig or {}
            local sectionName = sectionConfig.Name or "Section"
            local side = sectionConfig.Side or "Left"
            
            local Section = {
                Elements = {},
            }
            
            local targetColumn = (side == "Left") and leftColumn or rightColumn
            
            -- Section container
            local sectionFrame = Create("Frame", {
                Parent = targetColumn,
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundColor3 = Sentinel.Theme.Secondary,
                BorderSizePixel = 0,
                ZIndex = 4,
                AutomaticSize = Enum.AutomaticSize.Y,
            })
            Create("UIStroke", {
                Parent = sectionFrame,
                Color = Sentinel.Theme.Border,
                Thickness = 1,
            })
            
            -- Section title background
            local titleBg = Create("Frame", {
                Parent = sectionFrame,
                Size = UDim2.new(1, 0, 0, 22),
                BackgroundColor3 = Sentinel.Theme.Tertiary,
                BorderSizePixel = 0,
                ZIndex = 5,
            })
            
            local titleText = Create("TextLabel", {
                Parent = titleBg,
                Size = UDim2.new(1, -10, 1, 0),
                Position = UDim2.new(0, 8, 0, 0),
                BackgroundTransparency = 1,
                Text = sectionName,
                TextColor3 = Sentinel.Theme.Text,
                TextSize = 11,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 6,
            })
            table.insert(Sentinel.AllTextLabels, titleText)
            
            -- Section content
            local sectionContent = Create("Frame", {
                Parent = sectionFrame,
                Size = UDim2.new(1, -8, 0, 0),
                Position = UDim2.new(0, 4, 0, 24),
                BackgroundTransparency = 1,
                ZIndex = 5,
                AutomaticSize = Enum.AutomaticSize.Y,
            })
            
            local contentLayout = Create("UIListLayout", {
                Parent = sectionContent,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 3),
            })
            Create("UIPadding", {
                Parent = sectionContent,
                PaddingTop = UDim.new(0, 2),
                PaddingBottom = UDim.new(0, 6),
            })
            
            -- ═══════════════════════════════
            -- ELEMENT: SEPARATOR
            -- ═══════════════════════════════
            
            function Section:CreateSeparator()
                Create("Frame", {
                    Parent = sectionContent,
                    Size = UDim2.new(1, -4, 0, 1),
                    BackgroundColor3 = Sentinel.Theme.Border,
                    BorderSizePixel = 0,
                    ZIndex = 6,
                })
            end
            
            -- ═══════════════════════════════
            -- ELEMENT: LABEL
            -- ═══════════════════════════════
            
            function Section:CreateLabel(labelConfig)
                labelConfig = labelConfig or {}
                
                local label = Create("TextLabel", {
                    Parent = sectionContent,
                    Size = UDim2.new(1, 0, 0, 18),
                    BackgroundTransparency = 1,
                    Text = labelConfig.Text or "Label",
                    TextColor3 = Sentinel.Theme.SubText,
                    TextSize = 11,
                    Font = Sentinel.CurrentFont,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 6,
                })
                table.insert(Sentinel.AllTextLabels, label)
                
                local LabelObj = {}
                function LabelObj:SetText(text)
                    label.Text = text
                end
                return LabelObj
            end
            
            -- ═══════════════════════════════
            -- ELEMENT: BUTTON
            -- ═══════════════════════════════
            
            function Section:CreateButton(btnConfig)
                btnConfig = btnConfig or {}
                
                local btnFrame = Create("Frame", {
                    Parent = sectionContent,
                    Size = UDim2.new(1, 0, 0, 26),
                    BackgroundTransparency = 1,
                    ZIndex = 6,
                })
                
                local btn = Create("TextButton", {
                    Parent = btnFrame,
                    Size = UDim2.new(1, -4, 0, 22),
                    Position = UDim2.new(0, 2, 0, 2),
                    BackgroundColor3 = Sentinel.Theme.ElementBg,
                    Text = btnConfig.Name or "Button",
                    TextColor3 = Sentinel.Theme.Text,
                    TextSize = 11,
                    Font = Sentinel.CurrentFont,
                    ZIndex = 7,
                    AutoButtonColor = false,
                })
                Create("UIStroke", {Parent = btn, Color = Sentinel.Theme.Border, Thickness = 1})
                Create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = btn})
                table.insert(Sentinel.AllTextLabels, btn)
                
                btn.MouseEnter:Connect(function()
                    Tween(btn, {BackgroundColor3 = Sentinel.Theme.Hover}, 0.1)
                end)
                btn.MouseLeave:Connect(function()
                    Tween(btn, {BackgroundColor3 = Sentinel.Theme.ElementBg}, 0.1)
                end)
                btn.MouseButton1Click:Connect(function()
                    -- Press animation
                    Tween(btn, {BackgroundColor3 = Sentinel.Theme.Accent}, 0.05)
                    task.delay(0.1, function()
                        Tween(btn, {BackgroundColor3 = Sentinel.Theme.ElementBg}, 0.15)
                    end)
                    
                    if btnConfig.Callback then
                        btnConfig.Callback()
                    end
                end)
            end
            
            -- ═══════════════════════════════
            -- ELEMENT: TOGGLE
            -- ═══════════════════════════════
            
            function Section:CreateToggle(toggleConfig)
                toggleConfig = toggleConfig or {}
                local toggled = toggleConfig.Default or false
                local flag = toggleConfig.Flag or ("toggle_" .. tostring(math.random(10000, 99999)))
                local boundKey = nil
                
                -- Register flag
                Sentinel.Flags[flag] = toggled
                
                local toggleFrame = Create("Frame", {
                    Parent = sectionContent,
                    Size = UDim2.new(1, 0, 0, 22),
                    BackgroundTransparency = 1,
                    ZIndex = 6,
                })
                
                -- Checkbox
                local checkbox = Create("Frame", {
                    Parent = toggleFrame,
                    Size = UDim2.new(0, 14, 0, 14),
                    Position = UDim2.new(0, 4, 0.5, -7),
                    BackgroundColor3 = toggled and Sentinel.Theme.ToggleOn or Sentinel.Theme.ToggleOff,
                    BorderSizePixel = 0,
                    ZIndex = 8,
                })
                Create("UICorner", {CornerRadius = UDim.new(0, 3), Parent = checkbox})
                Create("UIStroke", {
                    Parent = checkbox,
                    Color = Sentinel.Theme.Border,
                    Thickness = 1,
                })
                
                -- Checkmark
                local checkmark = Create("TextLabel", {
                    Parent = checkbox,
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    Text = "✓",
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    TextSize = 12,
                    Font = Enum.Font.GothamBold,
                    TextTransparency = toggled and 0 or 1,
                    ZIndex = 9,
                })
                
                -- Label
                local toggleLabel = Create("TextLabel", {
                    Parent = toggleFrame,
                    Size = UDim2.new(1, -60, 1, 0),
                    Position = UDim2.new(0, 24, 0, 0),
                    BackgroundTransparency = 1,
                    Text = toggleConfig.Name or "Toggle",
                    TextColor3 = toggled and Sentinel.Theme.Text or Sentinel.Theme.SubText,
                    TextSize = 11,
                    Font = Sentinel.CurrentFont,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 7,
                })
                table.insert(Sentinel.AllTextLabels, toggleLabel)
                
                -- Bind display
                local bindLabel = Create("TextLabel", {
                    Parent = toggleFrame,
                    Size = UDim2.new(0, 40, 1, 0),
                    Position = UDim2.new(1, -44, 0, 0),
                    BackgroundTransparency = 1,
                    Text = "",
                    TextColor3 = Sentinel.Theme.Disabled,
                    TextSize = 9,
                    Font = Enum.Font.GothamBold,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    ZIndex = 7,
                })
                
                local function setToggle(value)
                    toggled = value
                    Sentinel.Flags[flag] = value
                    
                    Tween(checkbox, {
                        BackgroundColor3 = value and Sentinel.Theme.ToggleOn or Sentinel.Theme.ToggleOff
                    }, 0.2)
                    Tween(checkmark, {
                        TextTransparency = value and 0 or 1
                    }, 0.15)
                    Tween(toggleLabel, {
                        TextColor3 = value and Sentinel.Theme.Text or Sentinel.Theme.SubText
                    }, 0.15)
                    
                    -- RGB pulse on enable
                    if value and Sentinel.RGBEnabled then
                        local original = Sentinel.Theme.ToggleOn
                        checkbox.BackgroundColor3 = GetRGBColor(0)
                        Tween(checkbox, {BackgroundColor3 = original}, 0.5)
                    end
                    
                    if toggleConfig.Callback then
                        toggleConfig.Callback(value)
                    end
                end
                
                -- Click handler
                local clickBtn = Create("TextButton", {
                    Parent = toggleFrame,
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                    Text = "",
                    ZIndex = 10,
                    AutoButtonColor = false,
                })
                
                clickBtn.MouseButton1Click:Connect(function()
                    setToggle(not toggled)
                end)
                
                -- Hover effect
                clickBtn.MouseEnter:Connect(function()
                    if not toggled then
                        Tween(checkbox, {BackgroundColor3 = Sentinel.Theme.Hover}, 0.1)
                    end
                end)
                clickBtn.MouseLeave:Connect(function()
                    if not toggled then
                        Tween(checkbox, {BackgroundColor3 = Sentinel.Theme.ToggleOff}, 0.1)
                    end
                end)
                
                -- Right-click for keybind
                clickBtn.MouseButton2Click:Connect(function()
                    local mousePos = UserInputService:GetMouseLocation()
                    ShowContextMenu(toggleFrame, mousePos, function(action)
                        if action == "bind" then
                            bindLabel.Text = "[...]"
                            bindLabel.TextColor3 = Sentinel.Theme.Accent
                            
                            local bindConn
                            bindConn = UserInputService.InputBegan:Connect(function(input, gp)
                                if input.UserInputType == Enum.UserInputType.Keyboard then
                                    boundKey = input.KeyCode
                                    bindLabel.Text = "[" .. GetKeyName(boundKey) .. "]"
                                    bindLabel.TextColor3 = Sentinel.Theme.Disabled
                                    
                                    -- Register bind
                                    Sentinel.Binds[flag] = {
                                        Key = boundKey,
                                        Callback = function()
                                            setToggle(not toggled)
                                        end
                                    }
                                    
                                    bindConn:Disconnect()
                                end
                            end)
                        elseif action == "reset" then
                            setToggle(toggleConfig.Default or false)
                            boundKey = nil
                            bindLabel.Text = ""
                            Sentinel.Binds[flag] = nil
                        end
                    end)
                end)
                
                -- Initialize
                if toggled then setToggle(true) end
                
                local ToggleObj = {}
                function ToggleObj:Set(value)
                    setToggle(value)
                end
                function ToggleObj:Get()
                    return toggled
                end
                
                table.insert(Section.Elements, ToggleObj)
                return ToggleObj
            end
            
            -- ═══════════════════════════════
            -- ELEMENT: SLIDER
            -- ═══════════════════════════════
            
            function Section:CreateSlider(sliderConfig)
                sliderConfig = sliderConfig or {}
                local minVal = sliderConfig.Min or 0
                local maxVal = sliderConfig.Max or 100
                local currentVal = sliderConfig.Default or minVal
                local increment = sliderConfig.Increment or 1
                local suffix = sliderConfig.Suffix or ""
                local flag = sliderConfig.Flag or ("slider_" .. tostring(math.random(10000, 99999)))
                local boundKey = nil
                
                Sentinel.Flags[flag] = currentVal
                
                local sliderFrame = Create("Frame", {
                    Parent = sectionContent,
                    Size = UDim2.new(1, 0, 0, 36),
                    BackgroundTransparency = 1,
                    ZIndex = 6,
                })
                
                -- Label & value
                local sliderLabel = Create("TextLabel", {
                    Parent = sliderFrame,
                    Size = UDim2.new(0.7, 0, 0, 16),
                    Position = UDim2.new(0, 4, 0, 0),
                    BackgroundTransparency = 1,
                    Text = sliderConfig.Name or "Slider",
                    TextColor3 = Sentinel.Theme.SubText,
                    TextSize = 11,
                    Font = Sentinel.CurrentFont,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 7,
                })
                table.insert(Sentinel.AllTextLabels, sliderLabel)
                
                local valueLabel = Create("TextLabel", {
                    Parent = sliderFrame,
                    Size = UDim2.new(0.3, -4, 0, 16),
                    Position = UDim2.new(0.7, 0, 0, 0),
                    BackgroundTransparency = 1,
                    Text = tostring(currentVal) .. suffix,
                    TextColor3 = Sentinel.Theme.Accent,
                    TextSize = 11,
                    Font = Enum.Font.GothamBold,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    ZIndex = 7,
                })
                
                -- Slider track
                local sliderTrack = Create("Frame", {
                    Parent = sliderFrame,
                    Size = UDim2.new(1, -8, 0, 6),
                    Position = UDim2.new(0, 4, 0, 20),
                    BackgroundColor3 = Sentinel.Theme.SliderBg,
                    BorderSizePixel = 0,
                    ZIndex = 7,
                    ClipsDescendants = true,
                })
                Create("UICorner", {CornerRadius = UDim.new(0, 3), Parent = sliderTrack})
                Create("UIStroke", {
                    Parent = sliderTrack,
                    Color = Sentinel.Theme.Border,
                    Thickness = 1,
                })
                
                -- Fill
                local fillPct = (currentVal - minVal) / (maxVal - minVal)
                local sliderFill = Create("Frame", {
                    Parent = sliderTrack,
                    Size = UDim2.new(fillPct, 0, 1, 0),
                    BackgroundColor3 = Sentinel.Theme.SliderFill,
                    BorderSizePixel = 0,
                    ZIndex = 8,
                })
                Create("UICorner", {CornerRadius = UDim.new(0, 3), Parent = sliderFill})
                
                -- Slider knob (subtle)
                local knob = Create("Frame", {
                    Parent = sliderTrack,
                    Size = UDim2.new(0, 10, 0, 14),
                    Position = UDim2.new(fillPct, -5, 0.5, -7),
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    BorderSizePixel = 0,
                    ZIndex = 9,
                })
                Create("UICorner", {CornerRadius = UDim.new(0, 3), Parent = knob})
                Create("UIStroke", {Parent = knob, Color = Sentinel.Theme.Border, Thickness = 1})
                
                -- Bind label
                local bindLabel = Create("TextLabel", {
                    Parent = sliderFrame,
                    Size = UDim2.new(0, 40, 0, 14),
                    Position = UDim2.new(1, -44, 0, 22),
                    BackgroundTransparency = 1,
                    Text = "",
                    TextColor3 = Sentinel.Theme.Disabled,
                    TextSize = 9,
                    Font = Enum.Font.GothamBold,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    ZIndex = 7,
                })
                
                local sliding = false
                
                local function updateSlider(pct)
                    pct = math.clamp(pct, 0, 1)
                    local rawVal = minVal + (maxVal - minVal) * pct
                    local steppedVal = math.floor(rawVal / increment + 0.5) * increment
                    steppedVal = math.clamp(steppedVal, minVal, maxVal)
                    currentVal = Truncate(steppedVal, 2)
                    
                    Sentinel.Flags[flag] = currentVal
                    
                    local newPct = (currentVal - minVal) / (maxVal - minVal)
                    Tween(sliderFill, {Size = UDim2.new(newPct, 0, 1, 0)}, 0.05, Enum.EasingStyle.Linear)
                    Tween(knob, {Position = UDim2.new(newPct, -5, 0.5, -7)}, 0.05, Enum.EasingStyle.Linear)
                    
                    valueLabel.Text = tostring(currentVal) .. suffix
                    
                    if sliderConfig.Callback then
                        sliderConfig.Callback(currentVal)
                    end
                end
                
                -- Interaction
                local sliderBtn = Create("TextButton", {
                    Parent = sliderTrack,
                    Size = UDim2.new(1, 0, 1, 10),
                    Position = UDim2.new(0, 0, 0, -5),
                    BackgroundTransparency = 1,
                    Text = "",
                    ZIndex = 10,
                    AutoButtonColor = false,
                })
                
                sliderBtn.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 
                        or input.UserInputType == Enum.UserInputType.Touch then
                        sliding = true
                        
                        local relX = input.Position.X - sliderTrack.AbsolutePosition.X
                        local pct = relX / sliderTrack.AbsoluteSize.X
                        updateSlider(pct)
                    end
                end)
                
                sliderBtn.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 
                        or input.UserInputType == Enum.UserInputType.Touch then
                        sliding = false
                    end
                end)
                
                AddConnection(UserInputService.InputChanged:Connect(function(input)
                    if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement 
                        or input.UserInputType == Enum.UserInputType.Touch) then
                        local relX = input.Position.X - sliderTrack.AbsolutePosition.X
                        local pct = relX / sliderTrack.AbsoluteSize.X
                        updateSlider(pct)
                    end
                end))
                
                AddConnection(UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 
                        or input.UserInputType == Enum.UserInputType.Touch then
                        sliding = false
                    end
                end))
                
                -- Hover effects
                sliderBtn.MouseEnter:Connect(function()
                    Tween(sliderLabel, {TextColor3 = Sentinel.Theme.Text}, 0.1)
                    Tween(knob, {Size = UDim2.new(0, 12, 0, 16)}, 0.1)
                end)
                sliderBtn.MouseLeave:Connect(function()
                    if not sliding then
                        Tween(sliderLabel, {TextColor3 = Sentinel.Theme.SubText}, 0.1)
                        Tween(knob, {Size = UDim2.new(0, 10, 0, 14)}, 0.1)
                    end
                end)
                
                -- Right-click bind
                sliderBtn.MouseButton2Click:Connect(function()
                    local mousePos = UserInputService:GetMouseLocation()
                    ShowContextMenu(sliderFrame, mousePos, function(action)
                        if action == "reset" then
                            updateSlider((sliderConfig.Default or minVal - minVal) / (maxVal - minVal))
                        end
                    end)
                end)
                
                -- RGB fill animation
                if Sentinel.RGBEnabled then
                    AddConnection(RunService.Heartbeat:Connect(function()
                        if Sentinel.RGBEnabled and sliding then
                            sliderFill.BackgroundColor3 = GetRGBColor(0)
                        elseif not sliding then
                            sliderFill.BackgroundColor3 = Sentinel.Theme.SliderFill
                        end
                    end))
                end
                
                local SliderObj = {}
                function SliderObj:Set(value)
                    local pct = (value - minVal) / (maxVal - minVal)
                    updateSlider(pct)
                end
                function SliderObj:Get()
                    return currentVal
                end
                
                table.insert(Section.Elements, SliderObj)
                return SliderObj
            end
            
            -- ═══════════════════════════════
            -- ELEMENT: DROPDOWN
            -- ═══════════════════════════════
            
            function Section:CreateDropdown(dropConfig)
                dropConfig = dropConfig or {}
                local options = dropConfig.Options or {}
                local selected = dropConfig.Default or (options[1] or "")
                local flag = dropConfig.Flag or ("dropdown_" .. tostring(math.random(10000, 99999)))
                local isOpen = false
                local multi = dropConfig.Multi or false
                local multiSelected = {}
                
                if multi and type(dropConfig.Default) == "table" then
                    for _, v in ipairs(dropConfig.Default) do
                        multiSelected[v] = true
                    end
                end
                
                Sentinel.Flags[flag] = multi and multiSelected or selected
                
                local dropdownFrame = Create("Frame", {
                    Parent = sectionContent,
                    Size = UDim2.new(1, 0, 0, 40),
                    BackgroundTransparency = 1,
                    ZIndex = 6,
                    ClipsDescendants = false,
                })
                
                -- Label
                local dropLabel = Create("TextLabel", {
                    Parent = dropdownFrame,
                    Size = UDim2.new(1, -4, 0, 14),
                    Position = UDim2.new(0, 4, 0, 0),
                    BackgroundTransparency = 1,
                    Text = dropConfig.Name or "Dropdown",
                    TextColor3 = Sentinel.Theme.SubText,
                    TextSize = 11,
                    Font = Sentinel.CurrentFont,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 7,
                })
                table.insert(Sentinel.AllTextLabels, dropLabel)
                
                -- Dropdown button
                local dropButton = Create("TextButton", {
                    Parent = dropdownFrame,
                    Size = UDim2.new(1, -4, 0, 22),
                    Position = UDim2.new(0, 2, 0, 16),
                    BackgroundColor3 = Sentinel.Theme.ElementBg,
                    Text = "",
                    ZIndex = 7,
                    AutoButtonColor = false,
                })
                Create("UIStroke", {Parent = dropButton, Color = Sentinel.Theme.Border, Thickness = 1})
                Create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = dropButton})
                
                local selectedLabel = Create("TextLabel", {
                    Parent = dropButton,
                    Size = UDim2.new(1, -24, 1, 0),
                    Position = UDim2.new(0, 6, 0, 0),
                    BackgroundTransparency = 1,
                    Text = tostring(selected),
                    TextColor3 = Sentinel.Theme.Text,
                    TextSize = 11,
                    Font = Sentinel.CurrentFont,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    ZIndex = 8,
                })
                table.insert(Sentinel.AllTextLabels, selectedLabel)
                
                -- Arrow
                local arrow = Create("TextLabel", {
                    Parent = dropButton,
                    Size = UDim2.new(0, 16, 1, 0),
                    Position = UDim2.new(1, -20, 0, 0),
                    BackgroundTransparency = 1,
                    Text = "▼",
                    TextColor3 = Sentinel.Theme.SubText,
                    TextSize = 8,
                    Font = Enum.Font.GothamBold,
                    ZIndex = 8,
                })
                
                -- Dropdown list
                local dropList = Create("Frame", {
                    Parent = dropdownFrame,
                    Size = UDim2.new(1, -4, 0, 0),
                    Position = UDim2.new(0, 2, 0, 39),
                    BackgroundColor3 = Sentinel.Theme.DropdownBg,
                    BorderSizePixel = 0,
                    ZIndex = 50,
                    ClipsDescendants = true,
                    Visible = false,
                })
                Create("UIStroke", {Parent = dropList, Color = Sentinel.Theme.Border, Thickness = 1})
                Create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = dropList})
                
                local listContent = Create("ScrollingFrame", {
                    Parent = dropList,
                    Size = UDim2.new(1, -4, 1, -4),
                    Position = UDim2.new(0, 2, 0, 2),
                    BackgroundTransparency = 1,
                    ScrollBarThickness = 2,
                    ScrollBarImageColor3 = Sentinel.Theme.Accent,
                    BorderSizePixel = 0,
                    ZIndex = 51,
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    AutomaticCanvasSize = Enum.AutomaticSize.Y,
                })
                
                local listLayout = Create("UIListLayout", {
                    Parent = listContent,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 1),
                })
                
                local optionItems = {}
                
                local function updateMultiText()
                    local sel = {}
                    for k, v in pairs(multiSelected) do
                        if v then table.insert(sel, k) end
                    end
                    selectedLabel.Text = #sel > 0 and table.concat(sel, ", ") or "None"
                end
                
                local function createOptionItem(optionName)
                    local optItem = Create("TextButton", {
                        Parent = listContent,
                        Size = UDim2.new(1, 0, 0, 22),
                        BackgroundColor3 = Sentinel.Theme.DropdownBg,
                        BackgroundTransparency = 0,
                        Text = "",
                        ZIndex = 52,
                        AutoButtonColor = false,
                    })
                    
                    local optLabel = Create("TextLabel", {
                        Parent = optItem,
                        Size = UDim2.new(1, -10, 1, 0),
                        Position = UDim2.new(0, 8, 0, 0),
                        BackgroundTransparency = 1,
                        Text = optionName,
                        TextColor3 = (not multi and selected == optionName) 
                            and Sentinel.Theme.Accent 
                            or (multi and multiSelected[optionName]) 
                            and Sentinel.Theme.Accent 
                            or Sentinel.Theme.SubText,
                        TextSize = 11,
                        Font = Sentinel.CurrentFont,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 53,
                    })
                    table.insert(Sentinel.AllTextLabels, optLabel)
                    
                    optItem.MouseEnter:Connect(function()
                        Tween(optItem, {BackgroundColor3 = Sentinel.Theme.Tertiary}, 0.08)
                        if not (selected == optionName or (multi and multiSelected[optionName])) then
                            Tween(optLabel, {TextColor3 = Sentinel.Theme.Text}, 0.08)
                        end
                    end)
                    optItem.MouseLeave:Connect(function()
                        Tween(optItem, {BackgroundColor3 = Sentinel.Theme.DropdownBg}, 0.08)
                        if not (selected == optionName or (multi and multiSelected[optionName])) then
                            Tween(optLabel, {TextColor3 = Sentinel.Theme.SubText}, 0.08)
                        end
                    end)
                    
                    optItem.MouseButton1Click:Connect(function()
                        if multi then
                            multiSelected[optionName] = not multiSelected[optionName]
                            Tween(optLabel, {
                                TextColor3 = multiSelected[optionName] 
                                    and Sentinel.Theme.Accent 
                                    or Sentinel.Theme.SubText
                            }, 0.1)
                            updateMultiText()
                            Sentinel.Flags[flag] = multiSelected
                            if dropConfig.Callback then
                                dropConfig.Callback(multiSelected)
                            end
                        else
                            selected = optionName
                            selectedLabel.Text = optionName
                            Sentinel.Flags[flag] = selected
                            
                            -- Update all option colors
                            for _, item in ipairs(optionItems) do
                                local lbl = item:FindFirstChildOfClass("TextLabel")
                                if lbl then
                                    Tween(lbl, {
                                        TextColor3 = lbl.Text == optionName 
                                            and Sentinel.Theme.Accent 
                                            or Sentinel.Theme.SubText
                                    }, 0.1)
                                end
                            end
                            
                            -- Close dropdown
                            isOpen = false
                            Tween(arrow, {Rotation = 0}, 0.15)
                            Tween(dropList, {Size = UDim2.new(1, -4, 0, 0)}, 0.15, Enum.EasingStyle.Quart)
                            task.delay(0.15, function()
                                dropList.Visible = false
                            end)
                            Tween(dropdownFrame, {Size = UDim2.new(1, 0, 0, 40)}, 0.15)
                            
                            if dropConfig.Callback then
                                dropConfig.Callback(selected)
                            end
                        end
                    end)
                    
                    table.insert(optionItems, optItem)
                    return optItem
                end
                
                for _, opt in ipairs(options) do
                    createOptionItem(opt)
                end
                
                if multi then updateMultiText() end
                
                -- Toggle dropdown
                dropButton.MouseButton1Click:Connect(function()
                    isOpen = not isOpen
                    
                    if isOpen then
                        dropList.Visible = true
                        local listHeight = math.min(#options * 23 + 4, 150)
                        Tween(arrow, {Rotation = 180}, 0.2)
                        Tween(dropList, {Size = UDim2.new(1, -4, 0, listHeight)}, 0.2, Enum.EasingStyle.Quart)
                        Tween(dropdownFrame, {Size = UDim2.new(1, 0, 0, 40 + listHeight + 2)}, 0.2)
                    else
                        Tween(arrow, {Rotation = 0}, 0.15)
                        Tween(dropList, {Size = UDim2.new(1, -4, 0, 0)}, 0.15, Enum.EasingStyle.Quart)
                        task.delay(0.15, function()
                            dropList.Visible = false
                        end)
                        Tween(dropdownFrame, {Size = UDim2.new(1, 0, 0, 40)}, 0.15)
                    end
                end)
                
                -- Hover effects
                dropButton.MouseEnter:Connect(function()
                    Tween(dropButton, {BackgroundColor3 = Sentinel.Theme.Hover}, 0.1)
                end)
                dropButton.MouseLeave:Connect(function()
                    Tween(dropButton, {BackgroundColor3 = Sentinel.Theme.ElementBg}, 0.1)
                end)
                
                -- Right-click
                dropButton.MouseButton2Click:Connect(function()
                    local mousePos = UserInputService:GetMouseLocation()
                    ShowContextMenu(dropdownFrame, mousePos, function(action)
                        if action == "reset" then
                            if multi then
                                multiSelected = {}
                                updateMultiText()
                                for _, item in ipairs(optionItems) do
                                    local lbl = item:FindFirstChildOfClass("TextLabel")
                                    if lbl then
                                        Tween(lbl, {TextColor3 = Sentinel.Theme.SubText}, 0.1)
                                    end
                                end
                            else
                                selected = dropConfig.Default or (options[1] or "")
                                selectedLabel.Text = selected
                            end
                            Sentinel.Flags[flag] = multi and multiSelected or selected
                            if dropConfig.Callback then
                                dropConfig.Callback(multi and multiSelected or selected)
                            end
                        end
                    end)
                end)
                
                local DropObj = {}
                function DropObj:Set(value)
                    if multi then
                        multiSelected = value
                        updateMultiText()
                    else
                        selected = value
                        selectedLabel.Text = value
                    end
                    Sentinel.Flags[flag] = multi and multiSelected or selected
                end
                function DropObj:Get()
                    return multi and multiSelected or selected
                end
                function DropObj:Refresh(newOptions)
                    options = newOptions
                    for _, item in ipairs(optionItems) do
                        item:Destroy()
                    end
                    optionItems = {}
                    for _, opt in ipairs(newOptions) do
                        createOptionItem(opt)
                    end
                end
                
                table.insert(Section.Elements, DropObj)
                return DropObj
            end
            
            -- ═══════════════════════════════
            -- ELEMENT: KEYBIND
            -- ═══════════════════════════════
            
            function Section:CreateKeybind(bindConfig)
                bindConfig = bindConfig or {}
                local currentKey = bindConfig.Default or Enum.KeyCode.Unknown
                local flag = bindConfig.Flag or ("keybind_" .. tostring(math.random(10000, 99999)))
                local listening = false
                
                Sentinel.Flags[flag] = currentKey
                
                local bindFrame = Create("Frame", {
                    Parent = sectionContent,
                    Size = UDim2.new(1, 0, 0, 22),
                    BackgroundTransparency = 1,
                    ZIndex = 6,
                })
                
                local bindLabel = Create("TextLabel", {
                    Parent = bindFrame,
                    Size = UDim2.new(0.6, 0, 1, 0),
                    Position = UDim2.new(0, 4, 0, 0),
                    BackgroundTransparency = 1,
                    Text = bindConfig.Name or "Keybind",
                    TextColor3 = Sentinel.Theme.SubText,
                    TextSize = 11,
                    Font = Sentinel.CurrentFont,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 7,
                })
                table.insert(Sentinel.AllTextLabels, bindLabel)
                
                local keyButton = Create("TextButton", {
                    Parent = bindFrame,
                    Size = UDim2.new(0, 60, 0, 18),
                    Position = UDim2.new(1, -64, 0.5, -9),
                    BackgroundColor3 = Sentinel.Theme.ElementBg,
                    Text = currentKey ~= Enum.KeyCode.Unknown and "[" .. GetKeyName(currentKey) .. "]" or "[...]",
                    TextColor3 = Sentinel.Theme.SubText,
                    TextSize = 10,
                    Font = Enum.Font.GothamBold,
                    ZIndex = 8,
                    AutoButtonColor = false,
                    AutomaticSize = Enum.AutomaticSize.X,
                })
                Create("UIStroke", {Parent = keyButton, Color = Sentinel.Theme.Border, Thickness = 1})
                Create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = keyButton})
                Create("UIPadding", {
                    Parent = keyButton,
                    PaddingLeft = UDim.new(0, 6),
                    PaddingRight = UDim.new(0, 6),
                })
                
                keyButton.MouseButton1Click:Connect(function()
                    listening = true
                    keyButton.Text = "[...]"
                    Tween(keyButton, {TextColor3 = Sentinel.Theme.Accent}, 0.1)
                    
                    local bindConn
                    bindConn = UserInputService.InputBegan:Connect(function(input, gp)
                        if input.UserInputType == Enum.UserInputType.Keyboard then
                            if input.KeyCode == Enum.KeyCode.Escape then
                                currentKey = Enum.KeyCode.Unknown
                                keyButton.Text = "[NONE]"
                            else
                                currentKey = input.KeyCode
                                keyButton.Text = "[" .. GetKeyName(currentKey) .. "]"
                            end
                            
                            Sentinel.Flags[flag] = currentKey
                            Tween(keyButton, {TextColor3 = Sentinel.Theme.SubText}, 0.1)
                            listening = false
                            bindConn:Disconnect()
                            
                            if bindConfig.Callback then
                                bindConfig.Callback(currentKey)
                            end
                        end
                    end)
                end)
                
                keyButton.MouseEnter:Connect(function()
                    Tween(keyButton, {BackgroundColor3 = Sentinel.Theme.Hover}, 0.1)
                end)
                keyButton.MouseLeave:Connect(function()
                    Tween(keyButton, {BackgroundColor3 = Sentinel.Theme.ElementBg}, 0.1)
                end)
                
                -- Listen for bound key
                AddConnection(UserInputService.InputBegan:Connect(function(input, gp)
                    if gp or listening then return end
                    if input.KeyCode == currentKey and currentKey ~= Enum.KeyCode.Unknown then
                        if bindConfig.OnPress then
                            bindConfig.OnPress()
                        end
                    end
                end))
                
                local BindObj = {}
                function BindObj:Set(key)
                    currentKey = key
                    Sentinel.Flags[flag] = key
                    keyButton.Text = "[" .. GetKeyName(key) .. "]"
                end
                function BindObj:Get()
                    return currentKey
                end
                
                table.insert(Section.Elements, BindObj)
                return BindObj
            end
            
            -- ═══════════════════════════════
            -- ELEMENT: TEXTBOX
            -- ═══════════════════════════════
            
            function Section:CreateTextbox(tbConfig)
                tbConfig = tbConfig or {}
                local flag = tbConfig.Flag or ("textbox_" .. tostring(math.random(10000, 99999)))
                
                Sentinel.Flags[flag] = tbConfig.Default or ""
                
                local tbFrame = Create("Frame", {
                    Parent = sectionContent,
                    Size = UDim2.new(1, 0, 0, 40),
                    BackgroundTransparency = 1,
                    ZIndex = 6,
                })
                
                local tbLabel = Create("TextLabel", {
                    Parent = tbFrame,
                    Size = UDim2.new(1, -4, 0, 14),
                    Position = UDim2.new(0, 4, 0, 0),
                    BackgroundTransparency = 1,
                    Text = tbConfig.Name or "Textbox",
                    TextColor3 = Sentinel.Theme.SubText,
                    TextSize = 11,
                    Font = Sentinel.CurrentFont,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 7,
                })
                table.insert(Sentinel.AllTextLabels, tbLabel)
                
                local textBox = Create("TextBox", {
                    Parent = tbFrame,
                    Size = UDim2.new(1, -4, 0, 22),
                    Position = UDim2.new(0, 2, 0, 16),
                    BackgroundColor3 = Sentinel.Theme.ElementBg,
                    Text = tbConfig.Default or "",
                    PlaceholderText = tbConfig.Placeholder or "Type here...",
                    PlaceholderColor3 = Sentinel.Theme.Disabled,
                    TextColor3 = Sentinel.Theme.Text,
                    TextSize = 11,
                    Font = Sentinel.CurrentFont,
                    ZIndex = 8,
                    ClearTextOnFocus = false,
                    TextXAlignment = Enum.TextXAlignment.Left,
                })
                Create("UIStroke", {Parent = textBox, Color = Sentinel.Theme.Border, Thickness = 1})
                Create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = textBox})
                Create("UIPadding", {Parent = textBox, PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)})
                table.insert(Sentinel.AllTextLabels, textBox)
                
                textBox.Focused:Connect(function()
                    Tween(textBox, {BackgroundColor3 = Sentinel.Theme.Hover}, 0.1)
                    local stroke = textBox:FindFirstChildOfClass("UIStroke")
                    if stroke then Tween(stroke, {Color = Sentinel.Theme.Accent}, 0.1) end
                end)
                textBox.FocusLost:Connect(function(enterPressed)
                    Tween(textBox, {BackgroundColor3 = Sentinel.Theme.ElementBg}, 0.1)
                    local stroke = textBox:FindFirstChildOfClass("UIStroke")
                    if stroke then Tween(stroke, {Color = Sentinel.Theme.Border}, 0.1) end
                    
                    Sentinel.Flags[flag] = textBox.Text
                    if tbConfig.Callback then
                        tbConfig.Callback(textBox.Text, enterPressed)
                    end
                end)
                
                local TBObj = {}
                function TBObj:Set(text)
                    textBox.Text = text
                    Sentinel.Flags[flag] = text
                end
                function TBObj:Get()
                    return textBox.Text
                end
                
                table.insert(Section.Elements, TBObj)
                return TBObj
            end
            
            -- ═══════════════════════════════
            -- ELEMENT: COLOR PICKER (MINI)
            -- ═══════════════════════════════
            
            function Section:CreateColorPicker(cpConfig)
                cpConfig = cpConfig or {}
                local currentColor = cpConfig.Default or Color3.fromRGB(255, 255, 255)
                local flag = cpConfig.Flag or ("color_" .. tostring(math.random(10000, 99999)))
                local isOpen = false
                
                Sentinel.Flags[flag] = currentColor
                
                local cpFrame = Create("Frame", {
                    Parent = sectionContent,
                    Size = UDim2.new(1, 0, 0, 22),
                    BackgroundTransparency = 1,
                    ZIndex = 6,
                    ClipsDescendants = false,
                })
                
                local cpLabel = Create("TextLabel", {
                    Parent = cpFrame,
                    Size = UDim2.new(0.7, 0, 1, 0),
                    Position = UDim2.new(0, 4, 0, 0),
                    BackgroundTransparency = 1,
                    Text = cpConfig.Name or "Color",
                    TextColor3 = Sentinel.Theme.SubText,
                    TextSize = 11,
                    Font = Sentinel.CurrentFont,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 7,
                })
                table.insert(Sentinel.AllTextLabels, cpLabel)
                
                local colorPreview = Create("TextButton", {
                    Parent = cpFrame,
                    Size = UDim2.new(0, 24, 0, 14),
                    Position = UDim2.new(1, -28, 0.5, -7),
                    BackgroundColor3 = currentColor,
                    Text = "",
                    ZIndex = 8,
                    AutoButtonColor = false,
                })
                Create("UICorner", {CornerRadius = UDim.new(0, 3), Parent = colorPreview})
                Create("UIStroke", {Parent = colorPreview, Color = Sentinel.Theme.Border, Thickness = 1})
                
                -- Color picker panel
                local pickerPanel = Create("Frame", {
                    Parent = cpFrame,
                    Size = UDim2.new(0, 180, 0, 0),
                    Position = UDim2.new(1, -180, 0, 24),
                    BackgroundColor3 = Sentinel.Theme.Primary,
                    BorderSizePixel = 0,
                    ZIndex = 100,
                    ClipsDescendants = true,
                    Visible = false,
                })
                Create("UIStroke", {Parent = pickerPanel, Color = Sentinel.Theme.Border, Thickness = 1})
                Create("UICorner", {CornerRadius = UDim.new(0, 3), Parent = pickerPanel})
                
                -- Hue slider
                local hueBar = Create("Frame", {
                    Parent = pickerPanel,
                    Size = UDim2.new(1, -16, 0, 12),
                    Position = UDim2.new(0, 8, 0, 8),
                    BackgroundColor3 = Color3.fromRGB(255, 0, 0),
                    BorderSizePixel = 0,
                    ZIndex = 101,
                })
                Create("UICorner", {CornerRadius = UDim.new(0, 3), Parent = hueBar})
                Create("UIGradient", {
                    Parent = hueBar,
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
                        ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
                        ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
                        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
                        ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
                        ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
                    }),
                })
                
                -- Quick colors
                local quickColors = {
                    Color3.fromRGB(255, 0, 0),
                    Color3.fromRGB(255, 128, 0),
                    Color3.fromRGB(255, 255, 0),
                    Color3.fromRGB(0, 255, 0),
                    Color3.fromRGB(0, 255, 255),
                    Color3.fromRGB(0, 128, 255),
                    Color3.fromRGB(128, 0, 255),
                    Color3.fromRGB(255, 0, 255),
                    Color3.fromRGB(255, 255, 255),
                    Color3.fromRGB(128, 128, 128),
                }
                
                for i, col in ipairs(quickColors) do
                    local qc = Create("TextButton", {
                        Parent = pickerPanel,
                        Size = UDim2.new(0, 14, 0, 14),
                        Position = UDim2.new(0, 8 + (i - 1) * 17, 0, 28),
                        BackgroundColor3 = col,
                        Text = "",
                        ZIndex = 102,
                        AutoButtonColor = false,
                    })
                    Create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = qc})
                    Create("UIStroke", {Parent = qc, Color = Sentinel.Theme.Border, Thickness = 1})
                    
                    qc.MouseButton1Click:Connect(function()
                        currentColor = col
                        colorPreview.BackgroundColor3 = col
                        Sentinel.Flags[flag] = col
                        if cpConfig.Callback then cpConfig.Callback(col) end
                    end)
                end
                
                -- Hue interaction
                local huePicking = false
                local hueBtn = Create("TextButton", {
                    Parent = hueBar,
                    Size = UDim2.new(1, 0, 1, 4),
                    Position = UDim2.new(0, 0, 0, -2),
                    BackgroundTransparency = 1,
                    Text = "",
                    ZIndex = 103,
                })
                
                hueBtn.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 
                        or input.UserInputType == Enum.UserInputType.Touch then
                        huePicking = true
                    end
                end)
                
                AddConnection(UserInputService.InputChanged:Connect(function(input)
                    if huePicking and (input.UserInputType == Enum.UserInputType.MouseMovement 
                        or input.UserInputType == Enum.UserInputType.Touch) then
                        local relX = math.clamp(
                            (input.Position.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X,
                            0, 1
                        )
                        currentColor = Color3.fromHSV(relX, 0.8, 1)
                        colorPreview.BackgroundColor3 = currentColor
                        Sentinel.Flags[flag] = currentColor
                        if cpConfig.Callback then cpConfig.Callback(currentColor) end
                    end
                end))
                
                AddConnection(UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 
                        or input.UserInputType == Enum.UserInputType.Touch then
                        huePicking = false
                    end
                end))
                
                -- Toggle picker
                colorPreview.MouseButton1Click:Connect(function()
                    isOpen = not isOpen
                    if isOpen then
                        pickerPanel.Visible = true
                        Tween(pickerPanel, {Size = UDim2.new(0, 180, 0, 52)}, 0.2, Enum.EasingStyle.Quart)
                    else
                        Tween(pickerPanel, {Size = UDim2.new(0, 180, 0, 0)}, 0.15, Enum.EasingStyle.Quart)
                        task.delay(0.15, function() pickerPanel.Visible = false end)
                    end
                end)
                
                local CPObj = {}
                function CPObj:Set(color)
                    currentColor = color
                    colorPreview.BackgroundColor3 = color
                    Sentinel.Flags[flag] = color
                end
                function CPObj:Get()
                    return currentColor
                end
                
                table.insert(Section.Elements, CPObj)
                return CPObj
            end
            
            table.insert(Tab.Sections, Section)
            return Section
        end
        
        -- Select first tab automatically
        if #Window.Tabs == 0 then
            task.defer(selectTab)
        end
        
        table.insert(Window.Tabs, Tab)
        return Tab
    end
    
    -- ═══════════════════════════════════════
    -- AUTO SETTINGS TAB
    -- ═══════════════════════════════════════
    
    function Window:CreateSettingsTab()
        local settingsTab = self:CreateTab({Name = "Settings", Icon = "⚙"})
        
        -- GUI Settings Section
        local guiSection = settingsTab:CreateSection({Name = "GUI Settings", Side = "Left"})
        
        -- Font Selector
        local fontNames = {}
        for name, _ in pairs(Sentinel.FontMap) do
            table.insert(fontNames, name)
        end
        table.sort(fontNames)
        
        guiSection:CreateDropdown({
            Name = "Font",
            Options = fontNames,
            Default = "Gotham",
            Flag = "gui_font",
            Callback = function(fontName)
                if Sentinel.FontMap[fontName] then
                    Sentinel.CurrentFont = Sentinel.FontMap[fontName]
                    -- Update all text labels
                    for _, label in ipairs(Sentinel.AllTextLabels) do
                        if label and label.Parent then
                            pcall(function()
                                label.Font = Sentinel.CurrentFont
                            end)
                        end
                    end
                end
            end,
        })
        
        -- UI Scale
        guiSection:CreateSlider({
            Name = "UI Scale",
            Min = 0.5,
            Max = 1.5,
            Default = Sentinel.Scale,
            Increment = 0.05,
            Flag = "gui_scale",
            Callback = function(value)
                Sentinel:SetScale(value)
            end,
        })
        
        -- RGB Toggle
        guiSection:CreateToggle({
            Name = "RGB Animations",
            Default = true,
            Flag = "gui_rgb",
            Callback = function(value)
                Sentinel.RGBEnabled = value
            end,
        })
        
        -- RGB Speed
        guiSection:CreateSlider({
            Name = "RGB Speed",
            Min = 0.1,
            Max = 3,
            Default = 1,
            Increment = 0.1,
            Flag = "gui_rgb_speed",
            Callback = function(value)
                Sentinel.RGBSpeed = value
            end,
        })
        
        -- Accent Color
        guiSection:CreateColorPicker({
            Name = "Accent Color",
            Default = Sentinel.Theme.Accent,
            Flag = "gui_accent",
            Callback = function(color)
                Sentinel.Theme.Accent = color
                Sentinel.Theme.ToggleOn = color
                Sentinel.Theme.SliderFill = color
            end,
        })
        
        -- Keybind Settings Section
        local bindSection = settingsTab:CreateSection({Name = "Keybinds", Side = "Right"})
        
        bindSection:CreateKeybind({
            Name = "Toggle GUI",
            Default = Sentinel.ToggleKey,
            Flag = "gui_toggle_key",
            Callback = function(key)
                Sentinel.ToggleKey = key
            end,
        })
        
        -- Info Section
        local infoSection = settingsTab:CreateSection({Name = "Information", Side = "Right"})
        
        infoSection:CreateLabel({Text = "SENTINEL v" .. Sentinel.Version})
        infoSection:CreateLabel({Text = "GameSense Style UI"})
        infoSection:CreateSeparator()
        infoSection:CreateLabel({Text = "Right-click elements to bind"})
        infoSection:CreateLabel({Text = "keys or reset values."})
        
        infoSection:CreateButton({
            Name = "Destroy GUI",
            Callback = function()
                Sentinel:Destroy()
            end,
        })
        
        return settingsTab
    end
    
    -- ═══════════════════════════════════════
    -- MOBILE TOGGLE BUTTON
    -- ═══════════════════════════════════════
    
    if IsMobile then
        local mobileToggle = Create("TextButton", {
            Parent = ScreenGui,
            Size = UDim2.new(0, 46, 0, 46),
            Position = UDim2.new(0, 10, 0, 10),
            BackgroundColor3 = Sentinel.Theme.Primary,
            Text = "S",
            TextColor3 = Sentinel.Theme.Accent,
            TextSize = 18,
            Font = Enum.Font.GothamBold,
            ZIndex = 1000,
            AutoButtonColor = false,
        })
        Create("UICorner", {CornerRadius = UDim.new(0, 23), Parent = mobileToggle})
        Create("UIStroke", {Parent = mobileToggle, Color = Sentinel.Theme.Accent, Thickness = 2})
        
        -- Draggable mobile button
        local mbDragging, mbDragStart, mbStartPos
        
        mobileToggle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                mbDragging = true
                mbDragStart = input.Position
                mbStartPos = mobileToggle.Position
            end
        end)
        
        mobileToggle.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                if mbDragging then
                    local delta = input.Position - mbDragStart
                    if delta.Magnitude < 10 then
                        -- It's a tap, toggle GUI
                        Sentinel:Toggle()
                    end
                end
                mbDragging = false
            end
        end)
        
        AddConnection(UserInputService.InputChanged:Connect(function(input)
            if mbDragging and input.UserInputType == Enum.UserInputType.Touch then
                local delta = input.Position - mbDragStart
                mobileToggle.Position = UDim2.new(
                    mbStartPos.X.Scale, mbStartPos.X.Offset + delta.X,
                    mbStartPos.Y.Scale, mbStartPos.Y.Offset + delta.Y
                )
            end
        end))
        
        -- RGB border animation
        AddConnection(RunService.Heartbeat:Connect(function()
            if Sentinel.RGBEnabled then
                local stroke = mobileToggle:FindFirstChildOfClass("UIStroke")
                if stroke then
                    stroke.Color = GetRGBColor(0)
                end
                mobileToggle.TextColor3 = GetRGBColor(0.1)
            end
        end))
    end
    
    table.insert(self.Windows, Window)
    return Window
end

-- ═══════════════════════════════════════
-- SECTION 10: GLOBAL FONT UPDATE
-- ═══════════════════════════════════════

function Sentinel:SetFont(fontName)
    if self.FontMap[fontName] then
        self.CurrentFont = self.FontMap[fontName]
        for _, label in ipairs(self.AllTextLabels) do
            if label and label.Parent then
                pcall(function()
                    label.Font = self.CurrentFont
                end)
            end
        end
    end
end

-- ═══════════════════════════════════════
-- SECTION 11: CLEANUP
-- ═══════════════════════════════════════

function Sentinel:Destroy()
    for _, conn in ipairs(self.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    self.Connections = {}
    
    if ScreenGui then
        ScreenGui:Destroy()
    end
    
    self.Windows = {}
    self.Flags = {}
    self.Binds = {}
    self.AllTextLabels = {}
end

-- ═══════════════════════════════════════
-- SECTION 12: FLAG SYSTEM
-- ═══════════════════════════════════════

function Sentinel:GetFlag(flag)
    return self.Flags[flag]
end

function Sentinel:SetFlag(flag, value)
    self.Flags[flag] = value
end

-- ═══════════════════════════════════════
-- RETURN LIBRARY
-- ═══════════════════════════════════════

return Sentinel
