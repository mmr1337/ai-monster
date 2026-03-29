--[[
    ╔═══════════════════════════════════════════════╗
    ║          SENTINEL GUI LIBRARY v2.1            ║
    ║       GameSense Style • Fixed Edition         ║
    ║                                               ║
    ║  Fixes:                                       ║
    ║  1. Removed shadow artifact                   ║
    ║  2. Removed slider RGB glow                   ║
    ║  3. Removed all icons                         ║
    ║  4. Redesigned color picker (HSV + Alpha)     ║
    ║  5. Notification stacking                     ║
    ║  6. Fixed context menu positioning            ║
    ║  7. Redesigned toggle/slider/dropdown         ║
    ║  8. Reactive accent color system              ║
    ╚═══════════════════════════════════════════════╝
]]--

-- ═══════════════════════════════════════
-- SERVICES
-- ═══════════════════════════════════════

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local GuiService = game:GetService("GuiService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ═══════════════════════════════════════
-- LIBRARY CORE
-- ═══════════════════════════════════════

local Sentinel = {
    Version = "2.1",
    Windows = {},
    Flags = {},
    Binds = {},
    Connections = {},
    ToggleKey = Enum.KeyCode.RightControl,
    Visible = true,
    Scale = IsMobile and 0.7 or 1,
    RGBSpeed = 1,
    RGBEnabled = true,
    CurrentFont = Enum.Font.Gotham,

    Theme = {
        Background  = Color3.fromRGB(16, 16, 16),
        Primary     = Color3.fromRGB(22, 22, 22),
        Secondary   = Color3.fromRGB(28, 28, 28),
        Tertiary    = Color3.fromRGB(36, 36, 36),
        Accent      = Color3.fromRGB(156, 120, 255),
        Text        = Color3.fromRGB(215, 215, 215),
        SubText     = Color3.fromRGB(140, 140, 140),
        Disabled    = Color3.fromRGB(70, 70, 70),
        Border      = Color3.fromRGB(48, 48, 48),
        DarkBorder  = Color3.fromRGB(10, 10, 10),
        ElementBg   = Color3.fromRGB(32, 32, 32),
        ToggleOff   = Color3.fromRGB(50, 50, 50),
        SliderBg    = Color3.fromRGB(40, 40, 40),
        DropdownBg  = Color3.fromRGB(24, 24, 24),
        Hover       = Color3.fromRGB(42, 42, 42),
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
    _accentCallbacks = {},
    _activeNotifs = {},
}

-- ═══════════════════════════════════════
-- UTILITY
-- ═══════════════════════════════════════

local function Create(cls, props, children)
    local inst = Instance.new(cls)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then pcall(function() inst[k] = v end) end
    end
    for _, c in pairs(children or {}) do c.Parent = inst end
    if props and props.Parent then inst.Parent = props.Parent end
    return inst
end

local function Tween(inst, props, dur, style, dir)
    local ti = TweenInfo.new(dur or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
    local t = TweenService:Create(inst, ti, props)
    t:Play()
    return t
end

local function AddConn(c)
    table.insert(Sentinel.Connections, c)
    return c
end

local function GetKeyName(kc)
    if not kc then return "..." end
    local n = kc.Name
    local a = {
        LeftShift="LSHIFT", RightShift="RSHIFT",
        LeftControl="LCTRL", RightControl="RCTRL",
        LeftAlt="LALT", RightAlt="RALT",
        Return="ENTER", Backspace="BKSP", CapsLock="CAPS",
    }
    return a[n] or n:upper()
end

local function Truncate(n, d)
    local m = 10^(d or 0)
    return math.floor(n * m) / m
end

local function GetGuiInsetY()
    local ok, inset = pcall(function() return GuiService:GetGuiInset() end)
    if ok and inset then return inset.Y end
    return 36
end

-- ═══════════════════════════════════════
-- ACCENT REACTIVITY SYSTEM
-- ═══════════════════════════════════════

function Sentinel:OnAccentChange(cb)
    table.insert(self._accentCallbacks, cb)
end

function Sentinel:SetAccent(color)
    self.Theme.Accent = color
    for _, cb in ipairs(self._accentCallbacks) do
        pcall(cb, color)
    end
end

-- ═══════════════════════════════════════
-- SCREEN GUI
-- ═══════════════════════════════════════

local ScreenGui = Create("ScreenGui", {
    Name = "Sentinel_" .. math.random(1000, 9999),
    Parent = PlayerGui,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999,
})

local UIScaleObj = Create("UIScale", {Scale = Sentinel.Scale, Parent = ScreenGui})

function Sentinel:SetScale(s)
    self.Scale = math.clamp(s, 0.5, 2)
    Tween(UIScaleObj, {Scale = self.Scale}, 0.3)
end

-- ═══════════════════════════════════════
-- RGB BAR
-- ═══════════════════════════════════════

local RGB_SEGS = 50

local function CreateRGBBar(parent, h, z)
    h = h or 2
    local bar = Create("Frame", {
        Parent = parent, Name = "RGBBar",
        Size = UDim2.new(1, 0, 0, h),
        BackgroundTransparency = 1, ZIndex = z or 10,
        ClipsDescendants = true,
    })
    local segs = {}
    for i = 1, RGB_SEGS do
        segs[i] = Create("Frame", {
            Parent = bar, Size = UDim2.new(1/RGB_SEGS, 1, 1, 0),
            Position = UDim2.new((i-1)/RGB_SEGS, 0, 0, 0),
            BackgroundColor3 = Color3.fromHSV((i-1)/RGB_SEGS, 0.75, 1),
            BorderSizePixel = 0, ZIndex = z or 10,
        })
    end
    AddConn(RunService.Heartbeat:Connect(function()
        if not Sentinel.RGBEnabled then
            for i, s in ipairs(segs) do s.BackgroundColor3 = Sentinel.Theme.Accent end
            return
        end
        local t = tick() * Sentinel.RGBSpeed * 0.5
        for i, s in ipairs(segs) do
            s.BackgroundColor3 = Color3.fromHSV((t + (i-1)/RGB_SEGS) % 1, 0.65, 1)
        end
    end))
    return bar
end

-- ═══════════════════════════════════════
-- WATERMARK
-- ═══════════════════════════════════════

function Sentinel:CreateWatermark()
    local wm = Create("Frame", {
        Parent = ScreenGui, Name = "Watermark",
        Size = UDim2.new(0, 320, 0, 28),
        Position = UDim2.new(1, -330, 0, 12),
        BackgroundColor3 = self.Theme.Primary,
        BorderSizePixel = 0, ZIndex = 100,
    })
    Create("UIStroke", {Parent = wm, Color = self.Theme.DarkBorder, Thickness = 1})
    local inner = Create("Frame", {
        Parent = wm,
        Size = UDim2.new(1, -4, 1, -4), Position = UDim2.new(0, 2, 0, 2),
        BackgroundColor3 = self.Theme.Primary, BorderSizePixel = 0, ZIndex = 101,
    })
    Create("UIStroke", {Parent = inner, Color = self.Theme.Border, Thickness = 1})
    CreateRGBBar(wm, 2, 105)

    local txt = Create("TextLabel", {
        Parent = inner,
        Size = UDim2.new(1, -10, 1, 0), Position = UDim2.new(0, 5, 0, 0),
        BackgroundTransparency = 1, Text = "SENTINEL",
        TextColor3 = self.Theme.Text, TextSize = 11,
        Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 102,
    })
    table.insert(self.AllTextLabels, txt)

    local fpsVals = {}
    AddConn(RunService.Heartbeat:Connect(function(dt)
        if not wm or not wm.Parent then return end
        table.insert(fpsVals, 1/dt)
        if #fpsVals > 30 then table.remove(fpsVals, 1) end
        local avg = 0
        for _, v in ipairs(fpsVals) do avg = avg + v end
        avg = math.floor(avg / #fpsVals)
        local ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        txt.Text = string.format("SENTINEL  |  %s  |  %d fps  |  %dms  |  %s",
            Player.Name, avg, ping, os.date("%H:%M:%S"))
        local w = math.max(txt.TextBounds.X + 20, 200)
        wm.Size = UDim2.new(0, w, 0, 28)
        wm.Position = UDim2.new(1, -(w + 10), 0, 12)
    end))
    self.Watermark = wm
end

-- ═══════════════════════════════════════
-- NOTIFICATIONS (STACKING FIX)
-- ═══════════════════════════════════════

function Sentinel:_repositionNotifs()
    for i, data in ipairs(self._activeNotifs) do
        if data.frame and data.frame.Parent then
            local targetY = 12 + (i - 1) * 68
            Tween(data.frame, {Position = UDim2.new(1, -310, 0, targetY)}, 0.3, Enum.EasingStyle.Quart)
        end
    end
end

function Sentinel:Notify(title, text, duration)
    duration = duration or 3

    local idx = #self._activeNotifs + 1
    local yPos = 12 + (idx - 1) * 68

    local notif = Create("Frame", {
        Parent = ScreenGui,
        Size = UDim2.new(0, 300, 0, 60),
        Position = UDim2.new(1, 310, 0, yPos),
        BackgroundColor3 = self.Theme.Primary,
        BorderSizePixel = 0, ZIndex = 200,
    })
    Create("UIStroke", {Parent = notif, Color = self.Theme.DarkBorder, Thickness = 1})
    Create("UICorner", {CornerRadius = UDim.new(0, 3), Parent = notif})
    CreateRGBBar(notif, 2, 205)

    Create("TextLabel", {
        Parent = notif,
        Size = UDim2.new(1, -10, 0, 20), Position = UDim2.new(0, 8, 0, 6),
        BackgroundTransparency = 1, Text = title or "SENTINEL",
        TextColor3 = self.Theme.Accent, TextSize = 12,
        Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 201,
    })
    Create("TextLabel", {
        Parent = notif,
        Size = UDim2.new(1, -10, 0, 20), Position = UDim2.new(0, 8, 0, 26),
        BackgroundTransparency = 1, Text = text or "",
        TextColor3 = self.Theme.SubText, TextSize = 11,
        Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 201,
    })

    local progBg = Create("Frame", {
        Parent = notif,
        Size = UDim2.new(1, -16, 0, 2), Position = UDim2.new(0, 8, 1, -8),
        BackgroundColor3 = self.Theme.Tertiary, BorderSizePixel = 0, ZIndex = 201,
    })
    local progFill = Create("Frame", {
        Parent = progBg,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = self.Theme.Accent,
        BorderSizePixel = 0, ZIndex = 202,
    })

    local notifData = {frame = notif}
    table.insert(self._activeNotifs, notifData)

    -- Slide in
    Tween(notif, {Position = UDim2.new(1, -310, 0, yPos)}, 0.4, Enum.EasingStyle.Quart)
    Tween(progFill, {Size = UDim2.new(0, 0, 1, 0)}, duration, Enum.EasingStyle.Linear)

    task.delay(duration, function()
        Tween(notif, {Position = UDim2.new(1, 310, 0, notif.Position.Y.Offset)}, 0.4, Enum.EasingStyle.Quart)
        task.delay(0.45, function()
            -- Remove from table
            for i, d in ipairs(self._activeNotifs) do
                if d == notifData then
                    table.remove(self._activeNotifs, i)
                    break
                end
            end
            if notif then notif:Destroy() end
            self:_repositionNotifs()
        end)
    end)
end

-- ═══════════════════════════════════════
-- CONTEXT MENU (POSITION FIX)
-- ═══════════════════════════════════════

local ContextMenu = nil

local function ShowContextMenu(element, callback)
    if ContextMenu then ContextMenu:Destroy() ContextMenu = nil end

    local scale = UIScaleObj.Scale
    local elPos = element.AbsolutePosition
    local elSize = element.AbsoluteSize

    -- Position at the right side of element
    local menuX = (elPos.X + elSize.X - 142) / scale
    local menuY = (elPos.Y + elSize.Y + 2) / scale

    local menu = Create("Frame", {
        Parent = ScreenGui,
        Size = UDim2.new(0, 140, 0, 0),
        Position = UDim2.new(0, menuX, 0, menuY),
        BackgroundColor3 = Sentinel.Theme.Primary,
        BorderSizePixel = 0, ZIndex = 500,
        ClipsDescendants = true,
    })
    Create("UIStroke", {Parent = menu, Color = Sentinel.Theme.Border, Thickness = 1})
    Create("UICorner", {CornerRadius = UDim.new(0, 3), Parent = menu})

    local options = {"Bind Key", "Reset"}
    local optH = 24
    Tween(menu, {Size = UDim2.new(0, 140, 0, #options * optH + 4)}, 0.15, Enum.EasingStyle.Quart)

    for i, name in ipairs(options) do
        local btn = Create("TextButton", {
            Parent = menu,
            Size = UDim2.new(1, -4, 0, optH),
            Position = UDim2.new(0, 2, 0, (i-1)*optH + 2),
            BackgroundTransparency = 1, BackgroundColor3 = Sentinel.Theme.Primary,
            Text = "  " .. name, TextColor3 = Sentinel.Theme.SubText,
            TextSize = 11, Font = Sentinel.CurrentFont,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 501, AutoButtonColor = false,
        })
        btn.MouseEnter:Connect(function()
            Tween(btn, {BackgroundTransparency = 0, BackgroundColor3 = Sentinel.Theme.Tertiary, TextColor3 = Sentinel.Theme.Text}, 0.1)
        end)
        btn.MouseLeave:Connect(function()
            Tween(btn, {BackgroundTransparency = 1, TextColor3 = Sentinel.Theme.SubText}, 0.1)
        end)
        btn.MouseButton1Click:Connect(function()
            callback(name == "Bind Key" and "bind" or "reset")
            if menu then
                Tween(menu, {Size = UDim2.new(0, 140, 0, 0)}, 0.1)
                task.delay(0.12, function() if menu then menu:Destroy() end ContextMenu = nil end)
            end
        end)
    end
    ContextMenu = menu

    local closeC
    closeC = UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            task.wait(0.05)
            if not menu or not menu.Parent then closeC:Disconnect() return end
            local mp = UserInputService:GetMouseLocation()
            local mAbs = menu.AbsolutePosition
            local mSz = menu.AbsoluteSize
            if mp.X < mAbs.X or mp.X > mAbs.X+mSz.X or mp.Y < mAbs.Y-36 or mp.Y > mAbs.Y+mSz.Y then
                Tween(menu, {Size = UDim2.new(0, 140, 0, 0)}, 0.1)
                task.delay(0.12, function() if menu then menu:Destroy() end ContextMenu = nil end)
                closeC:Disconnect()
            end
        end
    end)
    AddConn(closeC)
end

-- ═══════════════════════════════════════
-- WINDOW
-- ═══════════════════════════════════════

function Sentinel:CreateWindow(config)
    config = config or {}
    local winTitle = config.Title or "SENTINEL"
    local winSize = config.Size or UDim2.new(0, 580, 0, 460)
    self.ToggleKey = config.ToggleKey or Enum.KeyCode.RightControl

    local Window = {Tabs = {}, ActiveTab = nil}

    -- Main frame (NO SHADOW)
    local main = Create("Frame", {
        Parent = ScreenGui, Name = "SentinelWindow",
        Size = winSize,
        Position = UDim2.new(0.5, -winSize.X.Offset/2, 0.5, -winSize.Y.Offset/2),
        BackgroundColor3 = self.Theme.Background,
        BorderSizePixel = 0, ZIndex = 1, ClipsDescendants = true,
    })
    Create("UIStroke", {Parent = main, Color = self.Theme.DarkBorder, Thickness = 1})

    -- Inner
    local inner = Create("Frame", {
        Parent = main,
        Size = UDim2.new(1, -6, 1, -6), Position = UDim2.new(0, 3, 0, 3),
        BackgroundColor3 = self.Theme.Primary, BorderSizePixel = 0, ZIndex = 2,
    })
    Create("UIStroke", {Parent = inner, Color = self.Theme.Border, Thickness = 1})

    -- RGB bar
    CreateRGBBar(inner, 2, 50)

    -- Header
    local header = Create("Frame", {
        Parent = inner,
        Size = UDim2.new(1, 0, 0, 32), Position = UDim2.new(0, 0, 0, 2),
        BackgroundTransparency = 1, ZIndex = 3,
    })

    -- Logo (diamond)
    local logo = Create("Frame", {
        Parent = header,
        Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(0, 12, 0.5, -8),
        BackgroundColor3 = self.Theme.Accent, BorderSizePixel = 0,
        Rotation = 45, ZIndex = 5,
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 3), Parent = logo})
    local logoInner = Create("Frame", {
        Parent = logo,
        Size = UDim2.new(0, 8, 0, 8), Position = UDim2.new(0.5, -4, 0.5, -4),
        BackgroundColor3 = self.Theme.Primary, BorderSizePixel = 0, ZIndex = 6,
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = logoInner})

    AddConn(RunService.Heartbeat:Connect(function()
        if Sentinel.RGBEnabled then
            logo.BackgroundColor3 = Color3.fromHSV((tick() * Sentinel.RGBSpeed) % 1, 0.65, 1)
        else
            logo.BackgroundColor3 = Sentinel.Theme.Accent
        end
    end))

    -- Title
    local titleLbl = Create("TextLabel", {
        Parent = header,
        Size = UDim2.new(0, 200, 1, 0), Position = UDim2.new(0, 36, 0, 0),
        BackgroundTransparency = 1, Text = winTitle,
        TextColor3 = self.Theme.Text, TextSize = 13,
        Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
    })
    table.insert(self.AllTextLabels, titleLbl)

    Create("TextLabel", {
        Parent = header,
        Size = UDim2.new(0, 30, 1, 0), Position = UDim2.new(0, 36 + titleLbl.TextBounds.X + 6, 0, 0),
        BackgroundTransparency = 1, Text = "v"..self.Version,
        TextColor3 = self.Theme.SubText, TextSize = 10,
        Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
    })

    -- Close btn
    local closeBtn = Create("TextButton", {
        Parent = header,
        Size = UDim2.new(0, 28, 0, 28), Position = UDim2.new(1, -32, 0.5, -14),
        BackgroundTransparency = 1, Text = "×",
        TextColor3 = self.Theme.SubText, TextSize = 18,
        Font = Enum.Font.GothamBold, ZIndex = 5, AutoButtonColor = false,
    })
    closeBtn.MouseEnter:Connect(function() Tween(closeBtn, {TextColor3 = Color3.fromRGB(255,80,80)}, 0.15) end)
    closeBtn.MouseLeave:Connect(function() Tween(closeBtn, {TextColor3 = self.Theme.SubText}, 0.15) end)
    closeBtn.MouseButton1Click:Connect(function() self:Toggle() end)

    -- Separator
    Create("Frame", {
        Parent = inner,
        Size = UDim2.new(1, -8, 0, 1), Position = UDim2.new(0, 4, 0, 34),
        BackgroundColor3 = self.Theme.Border, BorderSizePixel = 0, ZIndex = 3,
    })

    -- Tab bar
    local tabBar = Create("Frame", {
        Parent = inner,
        Size = UDim2.new(1, -8, 0, 28), Position = UDim2.new(0, 4, 0, 36),
        BackgroundColor3 = self.Theme.Secondary, BorderSizePixel = 0, ZIndex = 3,
        ClipsDescendants = true,
    })
    Create("UIStroke", {Parent = tabBar, Color = self.Theme.Border, Thickness = 1})

    local tabBtnContainer = Create("Frame", {
        Parent = tabBar,
        Size = UDim2.new(1, -4, 1, -4), Position = UDim2.new(0, 2, 0, 2),
        BackgroundTransparency = 1, ZIndex = 4, ClipsDescendants = true,
    })
    Create("UIListLayout", {
        Parent = tabBtnContainer, FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2),
    })

    Create("Frame", {
        Parent = inner,
        Size = UDim2.new(1, -8, 0, 1), Position = UDim2.new(0, 4, 0, 65),
        BackgroundColor3 = self.Theme.Border, BorderSizePixel = 0, ZIndex = 3,
    })

    -- Content area
    local contentArea = Create("Frame", {
        Parent = inner,
        Size = UDim2.new(1, -12, 1, -72), Position = UDim2.new(0, 6, 0, 68),
        BackgroundTransparency = 1, ZIndex = 3, ClipsDescendants = true,
    })

    -- Dragging
    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    AddConn(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            Tween(main, {Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)}, 0.06)
        end
    end))

    -- Toggle
    function self:Toggle()
        self.Visible = not self.Visible
        if self.Visible then
            main.Visible = true
            main.BackgroundTransparency = 0.3
            main.Size = UDim2.new(0, winSize.X.Offset, 0, winSize.Y.Offset * 0.96)
            Tween(main, {Size = winSize, BackgroundTransparency = 0}, 0.25, Enum.EasingStyle.Quart)
        else
            Tween(main, {
                Size = UDim2.new(0, winSize.X.Offset, 0, winSize.Y.Offset * 0.96),
                BackgroundTransparency = 0.3,
            }, 0.2, Enum.EasingStyle.Quart)
            task.delay(0.2, function() main.Visible = false end)
        end
    end

    -- Key handler
    AddConn(UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == self.ToggleKey then self:Toggle() end
        for flag, bd in pairs(self.Binds) do
            if input.KeyCode == bd.Key and bd.Callback then bd.Callback() end
        end
    end))

    -- Open anim
    main.BackgroundTransparency = 0.5
    main.Size = UDim2.new(0, winSize.X.Offset, 0, winSize.Y.Offset * 0.96)
    Tween(main, {Size = winSize, BackgroundTransparency = 0}, 0.35, Enum.EasingStyle.Quart)

    -- ═══════════════════════════════════════
    -- TAB
    -- ═══════════════════════════════════════

    function Window:CreateTab(tabCfg)
        tabCfg = tabCfg or {}
        local tabName = tabCfg.Name or "Tab"

        local Tab = {Sections = {}, Name = tabName}

        -- Tab button (NO ICON)
        local tabBtn = Create("TextButton", {
            Parent = tabBtnContainer,
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundTransparency = 1, BackgroundColor3 = Sentinel.Theme.Tertiary,
            Text = tabName, TextColor3 = Sentinel.Theme.SubText,
            TextSize = 11, Font = Sentinel.CurrentFont,
            ZIndex = 5, AutoButtonColor = false,
            AutomaticSize = Enum.AutomaticSize.X,
        })
        Create("UIPadding", {Parent = tabBtn, PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14)})
        table.insert(Sentinel.AllTextLabels, tabBtn)

        local tabContent = Create("Frame", {
            Parent = contentArea,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1, Visible = false, ZIndex = 3,
        })

        -- Columns
        local leftCol = Create("ScrollingFrame", {
            Parent = tabContent,
            Size = UDim2.new(0.5, -3, 1, 0),
            BackgroundTransparency = 1, ScrollBarThickness = 2,
            ScrollBarImageColor3 = Sentinel.Theme.Accent,
            BorderSizePixel = 0, ZIndex = 3,
            CanvasSize = UDim2.new(0,0,0,0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
        })
        Create("UIListLayout", {Parent = leftCol, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6)})
        Create("UIPadding", {Parent = leftCol, PaddingBottom = UDim.new(0, 6)})

        local rightCol = Create("ScrollingFrame", {
            Parent = tabContent,
            Size = UDim2.new(0.5, -3, 1, 0), Position = UDim2.new(0.5, 3, 0, 0),
            BackgroundTransparency = 1, ScrollBarThickness = 2,
            ScrollBarImageColor3 = Sentinel.Theme.Accent,
            BorderSizePixel = 0, ZIndex = 3,
            CanvasSize = UDim2.new(0,0,0,0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
        })
        Create("UIListLayout", {Parent = rightCol, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6)})
        Create("UIPadding", {Parent = rightCol, PaddingBottom = UDim.new(0, 6)})

        local function selectTab()
            for _, t in ipairs(Window.Tabs) do
                Tween(t._btn, {TextColor3 = Sentinel.Theme.SubText, BackgroundTransparency = 1}, 0.15)
                t._content.Visible = false
            end
            Tween(tabBtn, {TextColor3 = Sentinel.Theme.Text, BackgroundTransparency = 0.8}, 0.15)
            tabContent.Visible = true
            Window.ActiveTab = Tab
        end

        tabBtn.MouseButton1Click:Connect(selectTab)
        tabBtn.MouseEnter:Connect(function()
            if Window.ActiveTab ~= Tab then Tween(tabBtn, {TextColor3 = Sentinel.Theme.Text}, 0.1) end
        end)
        tabBtn.MouseLeave:Connect(function()
            if Window.ActiveTab ~= Tab then Tween(tabBtn, {TextColor3 = Sentinel.Theme.SubText}, 0.1) end
        end)

        Tab._btn = tabBtn
        Tab._content = tabContent

        if #Window.Tabs == 0 then task.defer(selectTab) end

        -- ═══════════════════════════════════════
        -- SECTION
        -- ═══════════════════════════════════════

        function Tab:CreateSection(sCfg)
            sCfg = sCfg or {}
            local Section = {Elements = {}}
            local col = (sCfg.Side == "Right") and rightCol or leftCol

            local sFrame = Create("Frame", {
                Parent = col,
                Size = UDim2.new(1, 0, 0, 0),
                BackgroundColor3 = Sentinel.Theme.Secondary,
                BorderSizePixel = 0, ZIndex = 4,
                AutomaticSize = Enum.AutomaticSize.Y,
            })
            Create("UIStroke", {Parent = sFrame, Color = Sentinel.Theme.Border, Thickness = 1})

            local sTitleBg = Create("Frame", {
                Parent = sFrame,
                Size = UDim2.new(1, 0, 0, 22),
                BackgroundColor3 = Sentinel.Theme.Tertiary,
                BorderSizePixel = 0, ZIndex = 5,
            })
            local sTitleTxt = Create("TextLabel", {
                Parent = sTitleBg,
                Size = UDim2.new(1, -10, 1, 0), Position = UDim2.new(0, 8, 0, 0),
                BackgroundTransparency = 1, Text = sCfg.Name or "Section",
                TextColor3 = Sentinel.Theme.Text, TextSize = 11,
                Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 6,
            })
            table.insert(Sentinel.AllTextLabels, sTitleTxt)

            local sContent = Create("Frame", {
                Parent = sFrame,
                Size = UDim2.new(1, -8, 0, 0), Position = UDim2.new(0, 4, 0, 24),
                BackgroundTransparency = 1, ZIndex = 5,
                AutomaticSize = Enum.AutomaticSize.Y,
            })
            Create("UIListLayout", {Parent = sContent, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3)})
            Create("UIPadding", {Parent = sContent, PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 6)})

            -- ═══ SEPARATOR ═══
            function Section:CreateSeparator()
                Create("Frame", {
                    Parent = sContent,
                    Size = UDim2.new(1, -4, 0, 1),
                    BackgroundColor3 = Sentinel.Theme.Border,
                    BorderSizePixel = 0, ZIndex = 6,
                })
            end

            -- ═══ LABEL ═══
            function Section:CreateLabel(cfg)
                cfg = cfg or {}
                local lbl = Create("TextLabel", {
                    Parent = sContent,
                    Size = UDim2.new(1, 0, 0, 18),
                    BackgroundTransparency = 1, Text = cfg.Text or "Label",
                    TextColor3 = Sentinel.Theme.SubText, TextSize = 11,
                    Font = Sentinel.CurrentFont, TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 6,
                })
                table.insert(Sentinel.AllTextLabels, lbl)
                local L = {}
                function L:SetText(t) lbl.Text = t end
                return L
            end

            -- ═══ BUTTON ═══
            function Section:CreateButton(cfg)
                cfg = cfg or {}
                local bf = Create("Frame", {
                    Parent = sContent, Size = UDim2.new(1, 0, 0, 26),
                    BackgroundTransparency = 1, ZIndex = 6,
                })
                local btn = Create("TextButton", {
                    Parent = bf,
                    Size = UDim2.new(1, -4, 0, 22), Position = UDim2.new(0, 2, 0, 2),
                    BackgroundColor3 = Sentinel.Theme.ElementBg,
                    Text = cfg.Name or "Button", TextColor3 = Sentinel.Theme.Text,
                    TextSize = 11, Font = Sentinel.CurrentFont,
                    ZIndex = 7, AutoButtonColor = false,
                })
                Create("UIStroke", {Parent = btn, Color = Sentinel.Theme.Border, Thickness = 1})
                Create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = btn})
                table.insert(Sentinel.AllTextLabels, btn)

                btn.MouseEnter:Connect(function() Tween(btn, {BackgroundColor3 = Sentinel.Theme.Hover}, 0.1) end)
                btn.MouseLeave:Connect(function() Tween(btn, {BackgroundColor3 = Sentinel.Theme.ElementBg}, 0.1) end)
                btn.MouseButton1Click:Connect(function()
                    Tween(btn, {BackgroundColor3 = Sentinel.Theme.Accent}, 0.05)
                    task.delay(0.1, function() Tween(btn, {BackgroundColor3 = Sentinel.Theme.ElementBg}, 0.15) end)
                    if cfg.Callback then cfg.Callback() end
                end)
            end

            -- ═══════════════════════════════
            -- TOGGLE (REDESIGNED — NO CHECKMARK)
            -- ═══════════════════════════════

            function Section:CreateToggle(cfg)
                cfg = cfg or {}
                local toggled = cfg.Default or false
                local flag = cfg.Flag or ("t_"..math.random(10000,99999))
                local boundKey = nil
                Sentinel.Flags[flag] = toggled

                local tFrame = Create("Frame", {
                    Parent = sContent, Size = UDim2.new(1, 0, 0, 22),
                    BackgroundTransparency = 1, ZIndex = 6,
                })

                -- Checkbox outer
                local cbOuter = Create("Frame", {
                    Parent = tFrame,
                    Size = UDim2.new(0, 12, 0, 12), Position = UDim2.new(0, 4, 0.5, -6),
                    BackgroundColor3 = Sentinel.Theme.ToggleOff,
                    BorderSizePixel = 0, ZIndex = 8,
                })
                Create("UICorner", {CornerRadius = UDim.new(0, 3), Parent = cbOuter})
                Create("UIStroke", {Parent = cbOuter, Color = Sentinel.Theme.Border, Thickness = 1})

                -- Inner fill (scale animation instead of checkmark)
                local cbFill = Create("Frame", {
                    Parent = cbOuter,
                    Size = toggled and UDim2.new(1, -4, 1, -4) or UDim2.new(0, 0, 0, 0),
                    Position = UDim2.new(0.5, 0, 0.5, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Sentinel.Theme.Accent,
                    BorderSizePixel = 0, ZIndex = 9,
                })
                Create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = cbFill})

                local tLabel = Create("TextLabel", {
                    Parent = tFrame,
                    Size = UDim2.new(1, -60, 1, 0), Position = UDim2.new(0, 22, 0, 0),
                    BackgroundTransparency = 1,
                    Text = cfg.Name or "Toggle",
                    TextColor3 = toggled and Sentinel.Theme.Text or Sentinel.Theme.SubText,
                    TextSize = 11, Font = Sentinel.CurrentFont,
                    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7,
                })
                table.insert(Sentinel.AllTextLabels, tLabel)

                local bindLbl = Create("TextLabel", {
                    Parent = tFrame,
                    Size = UDim2.new(0, 40, 1, 0), Position = UDim2.new(1, -44, 0, 0),
                    BackgroundTransparency = 1, Text = "",
                    TextColor3 = Sentinel.Theme.Disabled, TextSize = 9,
                    Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 7,
                })

                local function setToggle(val)
                    toggled = val
                    Sentinel.Flags[flag] = val
                    -- Fill scale animation
                    Tween(cbFill, {
                        Size = val and UDim2.new(1, -4, 1, -4) or UDim2.new(0, 0, 0, 0),
                        BackgroundColor3 = val and Sentinel.Theme.Accent or Sentinel.Theme.ToggleOff,
                    }, 0.15, Enum.EasingStyle.Quart)
                    Tween(cbOuter, {
                        BackgroundColor3 = val and Sentinel.Theme.Accent or Sentinel.Theme.ToggleOff,
                    }, 0.2)
                    Tween(tLabel, {
                        TextColor3 = val and Sentinel.Theme.Text or Sentinel.Theme.SubText,
                    }, 0.15)
                    if cfg.Callback then cfg.Callback(val) end
                end

                -- Accent reactivity
                Sentinel:OnAccentChange(function(newColor)
                    if toggled then
                        cbFill.BackgroundColor3 = newColor
                        cbOuter.BackgroundColor3 = newColor
                    end
                end)

                local clickBtn = Create("TextButton", {
                    Parent = tFrame, Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1, Text = "",
                    ZIndex = 10, AutoButtonColor = false,
                })
                clickBtn.MouseButton1Click:Connect(function() setToggle(not toggled) end)
                clickBtn.MouseEnter:Connect(function()
                    if not toggled then Tween(cbOuter, {BackgroundColor3 = Sentinel.Theme.Hover}, 0.1) end
                end)
                clickBtn.MouseLeave:Connect(function()
                    if not toggled then Tween(cbOuter, {BackgroundColor3 = Sentinel.Theme.ToggleOff}, 0.1) end
                end)

                -- Right-click bind
                clickBtn.MouseButton2Click:Connect(function()
                    ShowContextMenu(tFrame, function(action)
                        if action == "bind" then
                            bindLbl.Text = "[...]"
                            bindLbl.TextColor3 = Sentinel.Theme.Accent
                            local bc
                            bc = UserInputService.InputBegan:Connect(function(inp)
                                if inp.UserInputType == Enum.UserInputType.Keyboard then
                                    boundKey = inp.KeyCode
                                    bindLbl.Text = "["..GetKeyName(boundKey).."]"
                                    bindLbl.TextColor3 = Sentinel.Theme.Disabled
                                    Sentinel.Binds[flag] = {Key = boundKey, Callback = function() setToggle(not toggled) end}
                                    bc:Disconnect()
                                end
                            end)
                        elseif action == "reset" then
                            setToggle(cfg.Default or false)
                            boundKey = nil
                            bindLbl.Text = ""
                            Sentinel.Binds[flag] = nil
                        end
                    end)
                end)

                if toggled then setToggle(true) end

                local T = {}
                function T:Set(v) setToggle(v) end
                function T:Get() return toggled end
                return T
            end

            -- ═══════════════════════════════
            -- SLIDER (REDESIGNED — CLEAN, NO RGB, NO KNOB)
            -- ═══════════════════════════════

            function Section:CreateSlider(cfg)
                cfg = cfg or {}
                local minV, maxV = cfg.Min or 0, cfg.Max or 100
                local curV = cfg.Default or minV
                local inc = cfg.Increment or 1
                local suf = cfg.Suffix or ""
                local flag = cfg.Flag or ("s_"..math.random(10000,99999))
                Sentinel.Flags[flag] = curV

                local slFrame = Create("Frame", {
                    Parent = sContent, Size = UDim2.new(1, 0, 0, 32),
                    BackgroundTransparency = 1, ZIndex = 6,
                })

                local slLabel = Create("TextLabel", {
                    Parent = slFrame,
                    Size = UDim2.new(0.7, 0, 0, 14), Position = UDim2.new(0, 4, 0, 0),
                    BackgroundTransparency = 1, Text = cfg.Name or "Slider",
                    TextColor3 = Sentinel.Theme.SubText, TextSize = 11,
                    Font = Sentinel.CurrentFont, TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 7,
                })
                table.insert(Sentinel.AllTextLabels, slLabel)

                local valLabel = Create("TextLabel", {
                    Parent = slFrame,
                    Size = UDim2.new(0.3, -4, 0, 14), Position = UDim2.new(0.7, 0, 0, 0),
                    BackgroundTransparency = 1, Text = tostring(curV)..suf,
                    TextColor3 = Sentinel.Theme.Accent, TextSize = 11,
                    Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right,
                    ZIndex = 7,
                })

                -- Accent reactivity for value label
                Sentinel:OnAccentChange(function(c) valLabel.TextColor3 = c end)

                -- Track (thin, no knob)
                local track = Create("Frame", {
                    Parent = slFrame,
                    Size = UDim2.new(1, -8, 0, 4), Position = UDim2.new(0, 4, 0, 19),
                    BackgroundColor3 = Sentinel.Theme.SliderBg,
                    BorderSizePixel = 0, ZIndex = 7,
                })
                Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = track})
                Create("UIStroke", {Parent = track, Color = Sentinel.Theme.Border, Thickness = 1})

                local fillPct = (curV - minV) / (maxV - minV)
                local fill = Create("Frame", {
                    Parent = track,
                    Size = UDim2.new(fillPct, 0, 1, 0),
                    BackgroundColor3 = Sentinel.Theme.Accent,
                    BorderSizePixel = 0, ZIndex = 8,
                })
                Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = fill})

                -- Accent reactivity for fill
                Sentinel:OnAccentChange(function(c) fill.BackgroundColor3 = c end)

                local sliding = false

                local function updateSlider(pct)
                    pct = math.clamp(pct, 0, 1)
                    local raw = minV + (maxV - minV) * pct
                    local stepped = math.floor(raw / inc + 0.5) * inc
                    curV = math.clamp(Truncate(stepped, 2), minV, maxV)
                    Sentinel.Flags[flag] = curV
                    local nPct = (curV - minV) / (maxV - minV)
                    -- Smooth linear tween (NO RGB)
                    Tween(fill, {Size = UDim2.new(nPct, 0, 1, 0)}, 0.04, Enum.EasingStyle.Linear)
                    valLabel.Text = tostring(curV)..suf
                    if cfg.Callback then cfg.Callback(curV) end
                end

                local slBtn = Create("TextButton", {
                    Parent = track,
                    Size = UDim2.new(1, 0, 1, 12), Position = UDim2.new(0, 0, 0, -6),
                    BackgroundTransparency = 1, Text = "",
                    ZIndex = 10, AutoButtonColor = false,
                })

                slBtn.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                        or input.UserInputType == Enum.UserInputType.Touch then
                        sliding = true
                        local rx = input.Position.X - track.AbsolutePosition.X
                        updateSlider(rx / track.AbsoluteSize.X)
                    end
                end)
                slBtn.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                        or input.UserInputType == Enum.UserInputType.Touch then
                        sliding = false
                    end
                end)
                AddConn(UserInputService.InputChanged:Connect(function(input)
                    if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement
                        or input.UserInputType == Enum.UserInputType.Touch) then
                        local rx = input.Position.X - track.AbsolutePosition.X
                        updateSlider(rx / track.AbsoluteSize.X)
                    end
                end))
                AddConn(UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1
                        or input.UserInputType == Enum.UserInputType.Touch then
                        sliding = false
                    end
                end))

                -- Hover
                slBtn.MouseEnter:Connect(function() Tween(slLabel, {TextColor3 = Sentinel.Theme.Text}, 0.1) end)
                slBtn.MouseLeave:Connect(function()
                    if not sliding then Tween(slLabel, {TextColor3 = Sentinel.Theme.SubText}, 0.1) end
                end)

                -- Right-click
                slBtn.MouseButton2Click:Connect(function()
                    ShowContextMenu(slFrame, function(action)
                        if action == "reset" then
                            updateSlider(((cfg.Default or minV) - minV) / (maxV - minV))
                        end
                    end)
                end)

                local S = {}
                function S:Set(v) updateSlider((v - minV) / (maxV - minV)) end
                function S:Get() return curV end
                return S
            end

            -- ═══════════════════════════════
            -- DROPDOWN (REDESIGNED)
            -- ═══════════════════════════════

            function Section:CreateDropdown(cfg)
                cfg = cfg or {}
                local options = cfg.Options or {}
                local selected = cfg.Default or (options[1] or "")
                local flag = cfg.Flag or ("d_"..math.random(10000,99999))
                local isOpen = false
                local multi = cfg.Multi or false
                local multiSel = {}

                if multi and type(cfg.Default) == "table" then
                    for _, v in ipairs(cfg.Default) do multiSel[v] = true end
                end
                Sentinel.Flags[flag] = multi and multiSel or selected

                local dFrame = Create("Frame", {
                    Parent = sContent, Size = UDim2.new(1, 0, 0, 40),
                    BackgroundTransparency = 1, ZIndex = 6,
                    ClipsDescendants = false,
                })

                local dLabel = Create("TextLabel", {
                    Parent = dFrame,
                    Size = UDim2.new(1, -4, 0, 14), Position = UDim2.new(0, 4, 0, 0),
                    BackgroundTransparency = 1, Text = cfg.Name or "Dropdown",
                    TextColor3 = Sentinel.Theme.SubText, TextSize = 11,
                    Font = Sentinel.CurrentFont, TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 7,
                })
                table.insert(Sentinel.AllTextLabels, dLabel)

                local dBtn = Create("TextButton", {
                    Parent = dFrame,
                    Size = UDim2.new(1, -4, 0, 22), Position = UDim2.new(0, 2, 0, 16),
                    BackgroundColor3 = Sentinel.Theme.ElementBg,
                    Text = "", ZIndex = 7, AutoButtonColor = false,
                })
                Create("UIStroke", {Parent = dBtn, Color = Sentinel.Theme.Border, Thickness = 1})
                Create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = dBtn})

                local selLabel = Create("TextLabel", {
                    Parent = dBtn,
                    Size = UDim2.new(1, -24, 1, 0), Position = UDim2.new(0, 6, 0, 0),
                    BackgroundTransparency = 1, Text = tostring(selected),
                    TextColor3 = Sentinel.Theme.Text, TextSize = 11,
                    Font = Sentinel.CurrentFont, TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8,
                })
                table.insert(Sentinel.AllTextLabels, selLabel)

                local arrow = Create("TextLabel", {
                    Parent = dBtn,
                    Size = UDim2.new(0, 16, 1, 0), Position = UDim2.new(1, -20, 0, 0),
                    BackgroundTransparency = 1, Text = "▾",
                    TextColor3 = Sentinel.Theme.SubText, TextSize = 10,
                    Font = Enum.Font.GothamBold, ZIndex = 8,
                })

                -- Dropdown list
                local dList = Create("Frame", {
                    Parent = dFrame,
                    Size = UDim2.new(1, -4, 0, 0), Position = UDim2.new(0, 2, 0, 39),
                    BackgroundColor3 = Sentinel.Theme.DropdownBg,
                    BorderSizePixel = 0, ZIndex = 50,
                    ClipsDescendants = true, Visible = false,
                })
                Create("UIStroke", {Parent = dList, Color = Sentinel.Theme.Border, Thickness = 1})
                Create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = dList})

                local listScroll = Create("ScrollingFrame", {
                    Parent = dList,
                    Size = UDim2.new(1, -4, 1, -4), Position = UDim2.new(0, 2, 0, 2),
                    BackgroundTransparency = 1, ScrollBarThickness = 2,
                    ScrollBarImageColor3 = Sentinel.Theme.Accent,
                    BorderSizePixel = 0, ZIndex = 51,
                    CanvasSize = UDim2.new(0,0,0,0),
                    AutomaticCanvasSize = Enum.AutomaticSize.Y,
                })
                Create("UIListLayout", {Parent = listScroll, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1)})

                local optItems = {}

                local function updateMultiText()
                    local s = {}
                    for k, v in pairs(multiSel) do if v then table.insert(s, k) end end
                    selLabel.Text = #s > 0 and table.concat(s, ", ") or "None"
                end

                local function createOptItem(optName)
                    local isSelected = (not multi and selected == optName) or (multi and multiSel[optName])
                    local oi = Create("TextButton", {
                        Parent = listScroll,
                        Size = UDim2.new(1, 0, 0, 22),
                        BackgroundColor3 = Sentinel.Theme.DropdownBg,
                        Text = "", ZIndex = 52, AutoButtonColor = false,
                    })
                    local oLabel = Create("TextLabel", {
                        Parent = oi,
                        Size = UDim2.new(1, -10, 1, 0), Position = UDim2.new(0, 8, 0, 0),
                        BackgroundTransparency = 1, Text = optName,
                        TextColor3 = isSelected and Sentinel.Theme.Accent or Sentinel.Theme.SubText,
                        TextSize = 11, Font = Sentinel.CurrentFont,
                        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 53,
                    })
                    table.insert(Sentinel.AllTextLabels, oLabel)

                    -- Accent reactivity for selected items
                    Sentinel:OnAccentChange(function(nc)
                        if (not multi and selected == optName) or (multi and multiSel[optName]) then
                            oLabel.TextColor3 = nc
                        end
                    end)

                    oi.MouseEnter:Connect(function()
                        Tween(oi, {BackgroundColor3 = Sentinel.Theme.Tertiary}, 0.08)
                        if not ((not multi and selected == optName) or (multi and multiSel[optName])) then
                            Tween(oLabel, {TextColor3 = Sentinel.Theme.Text}, 0.08)
                        end
                    end)
                    oi.MouseLeave:Connect(function()
                        Tween(oi, {BackgroundColor3 = Sentinel.Theme.DropdownBg}, 0.08)
                        if not ((not multi and selected == optName) or (multi and multiSel[optName])) then
                            Tween(oLabel, {TextColor3 = Sentinel.Theme.SubText}, 0.08)
                        end
                    end)

                    oi.MouseButton1Click:Connect(function()
                        if multi then
                            multiSel[optName] = not multiSel[optName]
                            Tween(oLabel, {TextColor3 = multiSel[optName] and Sentinel.Theme.Accent or Sentinel.Theme.SubText}, 0.1)
                            updateMultiText()
                            Sentinel.Flags[flag] = multiSel
                            if cfg.Callback then cfg.Callback(multiSel) end
                        else
                            selected = optName
                            selLabel.Text = optName
                            Sentinel.Flags[flag] = selected
                            for _, item in ipairs(optItems) do
                                local l = item:FindFirstChildOfClass("TextLabel")
                                if l then
                                    Tween(l, {TextColor3 = l.Text == optName and Sentinel.Theme.Accent or Sentinel.Theme.SubText}, 0.1)
                                end
                            end
                            -- Close
                            isOpen = false
                            Tween(arrow, {Rotation = 0}, 0.15)
                            Tween(dList, {Size = UDim2.new(1, -4, 0, 0)}, 0.15, Enum.EasingStyle.Quart)
                            task.delay(0.15, function() dList.Visible = false end)
                            Tween(dFrame, {Size = UDim2.new(1, 0, 0, 40)}, 0.15)
                            if cfg.Callback then cfg.Callback(selected) end
                        end
                    end)

                    table.insert(optItems, oi)
                    return oi
                end

                for _, o in ipairs(options) do createOptItem(o) end
                if multi then updateMultiText() end

                dBtn.MouseButton1Click:Connect(function()
                    isOpen = not isOpen
                    if isOpen then
                        dList.Visible = true
                        local lh = math.min(#options * 23 + 4, 150)
                        Tween(arrow, {Rotation = 180}, 0.2)
                        Tween(dList, {Size = UDim2.new(1, -4, 0, lh)}, 0.2, Enum.EasingStyle.Quart)
                        Tween(dFrame, {Size = UDim2.new(1, 0, 0, 40 + lh + 2)}, 0.2)
                    else
                        Tween(arrow, {Rotation = 0}, 0.15)
                        Tween(dList, {Size = UDim2.new(1, -4, 0, 0)}, 0.15, Enum.EasingStyle.Quart)
                        task.delay(0.15, function() dList.Visible = false end)
                        Tween(dFrame, {Size = UDim2.new(1, 0, 0, 40)}, 0.15)
                    end
                end)

                dBtn.MouseEnter:Connect(function() Tween(dBtn, {BackgroundColor3 = Sentinel.Theme.Hover}, 0.1) end)
                dBtn.MouseLeave:Connect(function() Tween(dBtn, {BackgroundColor3 = Sentinel.Theme.ElementBg}, 0.1) end)

                -- Right-click
                dBtn.MouseButton2Click:Connect(function()
                    ShowContextMenu(dFrame, function(action)
                        if action == "reset" then
                            if multi then
                                multiSel = {}
                                updateMultiText()
                                for _, item in ipairs(optItems) do
                                    local l = item:FindFirstChildOfClass("TextLabel")
                                    if l then Tween(l, {TextColor3 = Sentinel.Theme.SubText}, 0.1) end
                                end
                            else
                                selected = cfg.Default or (options[1] or "")
                                selLabel.Text = selected
                                for _, item in ipairs(optItems) do
                                    local l = item:FindFirstChildOfClass("TextLabel")
                                    if l then
                                        Tween(l, {TextColor3 = l.Text == selected and Sentinel.Theme.Accent or Sentinel.Theme.SubText}, 0.1)
                                    end
                                end
                            end
                            Sentinel.Flags[flag] = multi and multiSel or selected
                            if cfg.Callback then cfg.Callback(multi and multiSel or selected) end
                        end
                    end)
                end)

                local D = {}
                function D:Set(v)
                    if multi then multiSel = v; updateMultiText() else selected = v; selLabel.Text = v end
                    Sentinel.Flags[flag] = multi and multiSel or selected
                end
                function D:Get() return multi and multiSel or selected end
                function D:Refresh(newOpts)
                    options = newOpts
                    for _, it in ipairs(optItems) do it:Destroy() end
                    optItems = {}
                    for _, o in ipairs(newOpts) do createOptItem(o) end
                end
                return D
            end

            -- ═══════════════════════════════
            -- KEYBIND
            -- ═══════════════════════════════

            function Section:CreateKeybind(cfg)
                cfg = cfg or {}
                local curKey = cfg.Default or Enum.KeyCode.Unknown
                local flag = cfg.Flag or ("kb_"..math.random(10000,99999))
                local listening = false
                Sentinel.Flags[flag] = curKey

                local kFrame = Create("Frame", {
                    Parent = sContent, Size = UDim2.new(1, 0, 0, 22),
                    BackgroundTransparency = 1, ZIndex = 6,
                })
                local kLabel = Create("TextLabel", {
                    Parent = kFrame,
                    Size = UDim2.new(0.6, 0, 1, 0), Position = UDim2.new(0, 4, 0, 0),
                    BackgroundTransparency = 1, Text = cfg.Name or "Keybind",
                    TextColor3 = Sentinel.Theme.SubText, TextSize = 11,
                    Font = Sentinel.CurrentFont, TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 7,
                })
                table.insert(Sentinel.AllTextLabels, kLabel)

                local kBtn = Create("TextButton", {
                    Parent = kFrame,
                    Size = UDim2.new(0, 60, 0, 18), Position = UDim2.new(1, -64, 0.5, -9),
                    BackgroundColor3 = Sentinel.Theme.ElementBg,
                    Text = curKey ~= Enum.KeyCode.Unknown and "["..GetKeyName(curKey).."]" or "[...]",
                    TextColor3 = Sentinel.Theme.SubText, TextSize = 10,
                    Font = Enum.Font.GothamBold, ZIndex = 8,
                    AutoButtonColor = false, AutomaticSize = Enum.AutomaticSize.X,
                })
                Create("UIStroke", {Parent = kBtn, Color = Sentinel.Theme.Border, Thickness = 1})
                Create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = kBtn})
                Create("UIPadding", {Parent = kBtn, PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)})

                kBtn.MouseButton1Click:Connect(function()
                    listening = true
                    kBtn.Text = "[...]"
                    Tween(kBtn, {TextColor3 = Sentinel.Theme.Accent}, 0.1)
                    local bc
                    bc = UserInputService.InputBegan:Connect(function(inp)
                        if inp.UserInputType == Enum.UserInputType.Keyboard then
                            if inp.KeyCode == Enum.KeyCode.Escape then
                                curKey = Enum.KeyCode.Unknown
                                kBtn.Text = "[NONE]"
                            else
                                curKey = inp.KeyCode
                                kBtn.Text = "["..GetKeyName(curKey).."]"
                            end
                            Sentinel.Flags[flag] = curKey
                            Tween(kBtn, {TextColor3 = Sentinel.Theme.SubText}, 0.1)
                            listening = false
                            bc:Disconnect()
                            if cfg.Callback then cfg.Callback(curKey) end
                        end
                    end)
                end)

                kBtn.MouseEnter:Connect(function() Tween(kBtn, {BackgroundColor3 = Sentinel.Theme.Hover}, 0.1) end)
                kBtn.MouseLeave:Connect(function() Tween(kBtn, {BackgroundColor3 = Sentinel.Theme.ElementBg}, 0.1) end)

                AddConn(UserInputService.InputBegan:Connect(function(inp, gp)
                    if gp or listening then return end
                    if inp.KeyCode == curKey and curKey ~= Enum.KeyCode.Unknown then
                        if cfg.OnPress then cfg.OnPress() end
                    end
                end))

                local K = {}
                function K:Set(k) curKey = k; Sentinel.Flags[flag] = k; kBtn.Text = "["..GetKeyName(k).."]" end
                function K:Get() return curKey end
                return K
            end

            -- ═══════════════════════════════
            -- TEXTBOX
            -- ═══════════════════════════════

            function Section:CreateTextbox(cfg)
                cfg = cfg or {}
                local flag = cfg.Flag or ("tb_"..math.random(10000,99999))
                Sentinel.Flags[flag] = cfg.Default or ""

                local tbFrame = Create("Frame", {
                    Parent = sContent, Size = UDim2.new(1, 0, 0, 40),
                    BackgroundTransparency = 1, ZIndex = 6,
                })
                local tbLabel = Create("TextLabel", {
                    Parent = tbFrame,
                    Size = UDim2.new(1, -4, 0, 14), Position = UDim2.new(0, 4, 0, 0),
                    BackgroundTransparency = 1, Text = cfg.Name or "Textbox",
                    TextColor3 = Sentinel.Theme.SubText, TextSize = 11,
                    Font = Sentinel.CurrentFont, TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 7,
                })
                table.insert(Sentinel.AllTextLabels, tbLabel)

                local tb = Create("TextBox", {
                    Parent = tbFrame,
                    Size = UDim2.new(1, -4, 0, 22), Position = UDim2.new(0, 2, 0, 16),
                    BackgroundColor3 = Sentinel.Theme.ElementBg,
                    Text = cfg.Default or "",
                    PlaceholderText = cfg.Placeholder or "Type here...",
                    PlaceholderColor3 = Sentinel.Theme.Disabled,
                    TextColor3 = Sentinel.Theme.Text, TextSize = 11,
                    Font = Sentinel.CurrentFont, ZIndex = 8,
                    ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
                })
                Create("UIStroke", {Parent = tb, Color = Sentinel.Theme.Border, Thickness = 1})
                Create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = tb})
                Create("UIPadding", {Parent = tb, PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)})
                table.insert(Sentinel.AllTextLabels, tb)

                tb.Focused:Connect(function()
                    Tween(tb, {BackgroundColor3 = Sentinel.Theme.Hover}, 0.1)
                    local s = tb:FindFirstChildOfClass("UIStroke")
                    if s then Tween(s, {Color = Sentinel.Theme.Accent}, 0.1) end
                end)
                tb.FocusLost:Connect(function(ep)
                    Tween(tb, {BackgroundColor3 = Sentinel.Theme.ElementBg}, 0.1)
                    local s = tb:FindFirstChildOfClass("UIStroke")
                    if s then Tween(s, {Color = Sentinel.Theme.Border}, 0.1) end
                    Sentinel.Flags[flag] = tb.Text
                    if cfg.Callback then cfg.Callback(tb.Text, ep) end
                end)

                local TB = {}
                function TB:Set(t) tb.Text = t; Sentinel.Flags[flag] = t end
                function TB:Get() return tb.Text end
                return TB
            end

            -- ═══════════════════════════════════════
            -- COLOR PICKER (COMPLETELY REDESIGNED)
            -- ═══════════════════════════════════════

            function Section:CreateColorPicker(cfg)
                cfg = cfg or {}
                local curColor = cfg.Default or Color3.new(1, 1, 1)
                local flag = cfg.Flag or ("cp_"..math.random(10000,99999))
                local isOpen = false
                Sentinel.Flags[flag] = curColor

                -- Extract initial HSV
                local curH, curS, curV = Color3.toHSV(curColor)
                local curAlpha = cfg.DefaultAlpha or 1

                local cpFrame = Create("Frame", {
                    Parent = sContent, Size = UDim2.new(1, 0, 0, 22),
                    BackgroundTransparency = 1, ZIndex = 6,
                    ClipsDescendants = false,
                })

                local cpLabel = Create("TextLabel", {
                    Parent = cpFrame,
                    Size = UDim2.new(0.7, 0, 1, 0), Position = UDim2.new(0, 4, 0, 0),
                    BackgroundTransparency = 1, Text = cfg.Name or "Color",
                    TextColor3 = Sentinel.Theme.SubText, TextSize = 11,
                    Font = Sentinel.CurrentFont, TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 7,
                })
                table.insert(Sentinel.AllTextLabels, cpLabel)

                -- Preview
                local preview = Create("TextButton", {
                    Parent = cpFrame,
                    Size = UDim2.new(0, 24, 0, 14), Position = UDim2.new(1, -28, 0.5, -7),
                    BackgroundColor3 = curColor, Text = "",
                    ZIndex = 8, AutoButtonColor = false,
                })
                Create("UICorner", {CornerRadius = UDim.new(0, 3), Parent = preview})
                Create("UIStroke", {Parent = preview, Color = Sentinel.Theme.Border, Thickness = 1})

                -- Picker popup (parented to ScreenGui for no clipping)
                local popup = Create("Frame", {
                    Parent = ScreenGui,
                    Size = UDim2.new(0, 200, 0, 0),
                    Position = UDim2.new(0, 0, 0, 0),
                    BackgroundColor3 = Sentinel.Theme.Primary,
                    BorderSizePixel = 0, ZIndex = 300,
                    ClipsDescendants = true, Visible = false,
                })
                Create("UIStroke", {Parent = popup, Color = Sentinel.Theme.Border, Thickness = 1})
                Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = popup})

                -- == HUE BAR ==
                local hueBar = Create("Frame", {
                    Parent = popup,
                    Size = UDim2.new(1, -16, 0, 12), Position = UDim2.new(0, 8, 0, 8),
                    BackgroundColor3 = Color3.new(1,0,0), BorderSizePixel = 0, ZIndex = 301,
                })
                Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = hueBar})
                Create("UIGradient", {
                    Parent = hueBar,
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(255,0,0)),
                        ColorSequenceKeypoint.new(0.167, Color3.fromRGB(255,255,0)),
                        ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0,255,0)),
                        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0,255,255)),
                        ColorSequenceKeypoint.new(0.667, Color3.fromRGB(0,0,255)),
                        ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255,0,255)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(255,0,0)),
                    }),
                })

                -- Hue indicator
                local hueInd = Create("Frame", {
                    Parent = hueBar,
                    Size = UDim2.new(0, 3, 1, 4), Position = UDim2.new(curH, -1, 0, -2),
                    BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 302,
                })
                Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = hueInd})
                Create("UIStroke", {Parent = hueInd, Color = Color3.new(0,0,0), Thickness = 1})

                -- == SV SQUARE ==
                local svSize = 184
                local svFrame = Create("Frame", {
                    Parent = popup,
                    Size = UDim2.new(0, svSize, 0, svSize * 0.7),
                    Position = UDim2.new(0, 8, 0, 26),
                    BackgroundColor3 = Color3.fromHSV(curH, 1, 1),
                    BorderSizePixel = 0, ZIndex = 301,
                    ClipsDescendants = true,
                })
                Create("UICorner", {CornerRadius = UDim.new(0, 3), Parent = svFrame})
                Create("UIStroke", {Parent = svFrame, Color = Sentinel.Theme.Border, Thickness = 1})

                -- White overlay (left=white, right=transparent)
                local whiteOL = Create("Frame", {
                    Parent = svFrame,
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundColor3 = Color3.new(1,1,1),
                    BorderSizePixel = 0, ZIndex = 302,
                })
                Create("UIGradient", {
                    Parent = whiteOL,
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0),
                        NumberSequenceKeypoint.new(1, 1),
                    }),
                })

                -- Black overlay (top=transparent, bottom=black)
                local blackOL = Create("Frame", {
                    Parent = svFrame,
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundColor3 = Color3.new(0,0,0),
                    BorderSizePixel = 0, ZIndex = 303,
                })
                Create("UIGradient", {
                    Parent = blackOL,
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 1),
                        NumberSequenceKeypoint.new(1, 0),
                    }),
                    Rotation = 90,
                })

                -- SV cursor
                local svCursor = Create("Frame", {
                    Parent = svFrame,
                    Size = UDim2.new(0, 8, 0, 8),
                    Position = UDim2.new(curS, -4, 1-curV, -4),
                    BackgroundColor3 = Color3.new(1,1,1),
                    BorderSizePixel = 0, ZIndex = 305,
                })
                Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = svCursor})
                Create("UIStroke", {Parent = svCursor, Color = Color3.new(0,0,0), Thickness = 1})

                -- == ALPHA BAR ==
                local alphaBar = Create("Frame", {
                    Parent = popup,
                    Size = UDim2.new(1, -16, 0, 10),
                    Position = UDim2.new(0, 8, 0, 26 + svSize*0.7 + 6),
                    BackgroundColor3 = curColor,
                    BorderSizePixel = 0, ZIndex = 301,
                })
                Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = alphaBar})
                Create("UIStroke", {Parent = alphaBar, Color = Sentinel.Theme.Border, Thickness = 1})
                Create("UIGradient", {
                    Parent = alphaBar,
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0),
                        NumberSequenceKeypoint.new(1, 0.9),
                    }),
                })

                local alphaInd = Create("Frame", {
                    Parent = alphaBar,
                    Size = UDim2.new(0, 3, 1, 4), Position = UDim2.new(1-curAlpha, -1, 0, -2),
                    BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 302,
                })
                Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = alphaInd})
                Create("UIStroke", {Parent = alphaInd, Color = Color3.new(0,0,0), Thickness = 1})

                -- == PREVIEW + HEX ==
                local previewRow = Create("Frame", {
                    Parent = popup,
                    Size = UDim2.new(1, -16, 0, 18),
                    Position = UDim2.new(0, 8, 0, 26 + svSize*0.7 + 22),
                    BackgroundTransparency = 1, ZIndex = 301,
                })

                local bigPreview = Create("Frame", {
                    Parent = previewRow,
                    Size = UDim2.new(0, 18, 0, 18),
                    BackgroundColor3 = curColor, BorderSizePixel = 0, ZIndex = 302,
                })
                Create("UICorner", {CornerRadius = UDim.new(0, 3), Parent = bigPreview})
                Create("UIStroke", {Parent = bigPreview, Color = Sentinel.Theme.Border, Thickness = 1})

                local hexLabel = Create("TextLabel", {
                    Parent = previewRow,
                    Size = UDim2.new(1, -24, 1, 0), Position = UDim2.new(0, 24, 0, 0),
                    BackgroundTransparency = 1,
                    Text = string.format("#%02X%02X%02X", curColor.R*255, curColor.G*255, curColor.B*255),
                    TextColor3 = Sentinel.Theme.SubText, TextSize = 10,
                    Font = Enum.Font.Code, TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 302,
                })

                local popupH = 26 + svSize*0.7 + 22 + 24

                -- == UPDATE FUNCTION ==
                local function updateColor()
                    curColor = Color3.fromHSV(curH, curS, curV)
                    preview.BackgroundColor3 = curColor
                    bigPreview.BackgroundColor3 = curColor
                    svFrame.BackgroundColor3 = Color3.fromHSV(curH, 1, 1)
                    alphaBar.BackgroundColor3 = curColor
                    hexLabel.Text = string.format("#%02X%02X%02X  A:%.0f%%", curColor.R*255, curColor.G*255, curColor.B*255, curAlpha*100)
                    hueInd.Position = UDim2.new(curH, -1, 0, -2)
                    svCursor.Position = UDim2.new(curS, -4, 1-curV, -4)
                    alphaInd.Position = UDim2.new(1-curAlpha, -1, 0, -2)
                    Sentinel.Flags[flag] = curColor
                    if cfg.Callback then cfg.Callback(curColor, curAlpha) end
                end

                -- == INTERACTIONS ==
                local huePicking, svPicking, alphaPicking = false, false, false

                -- Hue
                local hueBtn = Create("TextButton", {
                    Parent = hueBar, Size = UDim2.new(1, 0, 1, 6), Position = UDim2.new(0,0,0,-3),
                    BackgroundTransparency = 1, Text = "", ZIndex = 304, AutoButtonColor = false,
                })
                hueBtn.InputBegan:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        huePicking = true
                        curH = math.clamp((i.Position.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 0.999)
                        updateColor()
                    end
                end)

                -- SV
                local svBtn = Create("TextButton", {
                    Parent = svFrame, Size = UDim2.new(1,0,1,0),
                    BackgroundTransparency = 1, Text = "", ZIndex = 304, AutoButtonColor = false,
                })
                svBtn.InputBegan:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        svPicking = true
                        curS = math.clamp((i.Position.X - svFrame.AbsolutePosition.X) / svFrame.AbsoluteSize.X, 0, 1)
                        curV = 1 - math.clamp((i.Position.Y - svFrame.AbsolutePosition.Y) / svFrame.AbsoluteSize.Y, 0, 1)
                        updateColor()
                    end
                end)

                -- Alpha
                local alphaBtn = Create("TextButton", {
                    Parent = alphaBar, Size = UDim2.new(1,0,1,6), Position = UDim2.new(0,0,0,-3),
                    BackgroundTransparency = 1, Text = "", ZIndex = 304, AutoButtonColor = false,
                })
                alphaBtn.InputBegan:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        alphaPicking = true
                        curAlpha = 1 - math.clamp((i.Position.X - alphaBar.AbsolutePosition.X) / alphaBar.AbsoluteSize.X, 0, 1)
                        updateColor()
                    end
                end)

                AddConn(UserInputService.InputChanged:Connect(function(i)
                    if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
                    if huePicking then
                        curH = math.clamp((i.Position.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 0.999)
                        updateColor()
                    end
                    if svPicking then
                        curS = math.clamp((i.Position.X - svFrame.AbsolutePosition.X) / svFrame.AbsoluteSize.X, 0, 1)
                        curV = 1 - math.clamp((i.Position.Y - svFrame.AbsolutePosition.Y) / svFrame.AbsoluteSize.Y, 0, 1)
                        updateColor()
                    end
                    if alphaPicking then
                        curAlpha = 1 - math.clamp((i.Position.X - alphaBar.AbsolutePosition.X) / alphaBar.AbsoluteSize.X, 0, 1)
                        updateColor()
                    end
                end))

                AddConn(UserInputService.InputEnded:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        huePicking = false
                        svPicking = false
                        alphaPicking = false
                    end
                end))

                -- Toggle popup
                preview.MouseButton1Click:Connect(function()
                    isOpen = not isOpen
                    if isOpen then
                        -- Position popup near preview
                        local scale = UIScaleObj.Scale
                        local pPos = preview.AbsolutePosition
                        local pSz = preview.AbsoluteSize
                        popup.Position = UDim2.new(0, (pPos.X + pSz.X - 200) / scale, 0, (pPos.Y + pSz.Y + 4) / scale)
                        popup.Visible = true
                        Tween(popup, {Size = UDim2.new(0, 200, 0, popupH)}, 0.2, Enum.EasingStyle.Quart)
                    else
                        Tween(popup, {Size = UDim2.new(0, 200, 0, 0)}, 0.15, Enum.EasingStyle.Quart)
                        task.delay(0.15, function() popup.Visible = false end)
                    end
                end)

                local CP = {}
                function CP:Set(c, a)
                    curColor = c
                    if a then curAlpha = a end
                    curH, curS, curV = Color3.toHSV(c)
                    updateColor()
                    preview.BackgroundColor3 = c
                end
                function CP:Get() return curColor, curAlpha end
                return CP
            end

            table.insert(Tab.Sections, Section)
            return Section
        end

        table.insert(Window.Tabs, Tab)
        return Tab
    end

    -- ═══════════════════════════════════════
    -- SETTINGS TAB
    -- ═══════════════════════════════════════

    function Window:CreateSettingsTab()
        local st = self:CreateTab({Name = "Settings"})

        local guiSec = st:CreateSection({Name = "GUI Settings", Side = "Left"})

        local fontNames = {}
        for n in pairs(Sentinel.FontMap) do table.insert(fontNames, n) end
        table.sort(fontNames)

        guiSec:CreateDropdown({
            Name = "Font", Options = fontNames, Default = "Gotham", Flag = "gui_font",
            Callback = function(fn)
                if Sentinel.FontMap[fn] then
                    Sentinel.CurrentFont = Sentinel.FontMap[fn]
                    for _, l in ipairs(Sentinel.AllTextLabels) do
                        if l and l.Parent then pcall(function() l.Font = Sentinel.CurrentFont end) end
                    end
                end
            end,
        })

        guiSec:CreateSlider({
            Name = "UI Scale", Min = 0.5, Max = 1.5, Default = Sentinel.Scale,
            Increment = 0.05, Flag = "gui_scale",
            Callback = function(v) Sentinel:SetScale(v) end,
        })

        guiSec:CreateToggle({
            Name = "RGB Animations", Default = true, Flag = "gui_rgb",
            Callback = function(v) Sentinel.RGBEnabled = v end,
        })

        guiSec:CreateSlider({
            Name = "RGB Speed", Min = 0.1, Max = 3, Default = 1,
            Increment = 0.1, Flag = "gui_rgb_speed",
            Callback = function(v) Sentinel.RGBSpeed = v end,
        })

        guiSec:CreateColorPicker({
            Name = "Accent Color", Default = Sentinel.Theme.Accent, Flag = "gui_accent",
            Callback = function(c)
                Sentinel:SetAccent(c)
            end,
        })

        local bindSec = st:CreateSection({Name = "Keybinds", Side = "Right"})

        bindSec:CreateKeybind({
            Name = "Toggle GUI", Default = Sentinel.ToggleKey, Flag = "gui_toggle_key",
            Callback = function(k) Sentinel.ToggleKey = k end,
        })

        local infoSec = st:CreateSection({Name = "Information", Side = "Right"})
        infoSec:CreateLabel({Text = "SENTINEL v" .. Sentinel.Version})
        infoSec:CreateLabel({Text = "GameSense Style UI Library"})
        infoSec:CreateSeparator()
        infoSec:CreateLabel({Text = "Right-click elements to bind keys"})
        infoSec:CreateButton({Name = "Destroy GUI", Callback = function() Sentinel:Destroy() end})

        return st
    end

    -- ═══ MOBILE TOGGLE ═══
    if IsMobile then
        local mb = Create("TextButton", {
            Parent = ScreenGui,
            Size = UDim2.new(0, 44, 0, 44), Position = UDim2.new(0, 10, 0, 10),
            BackgroundColor3 = Sentinel.Theme.Primary, Text = "S",
            TextColor3 = Sentinel.Theme.Accent, TextSize = 18,
            Font = Enum.Font.GothamBold, ZIndex = 1000, AutoButtonColor = false,
        })
        Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = mb})
        Create("UIStroke", {Parent = mb, Color = Sentinel.Theme.Accent, Thickness = 2})

        local mbDrag, mbDS, mbSP
        mb.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch then
                mbDrag = true; mbDS = i.Position; mbSP = mb.Position
            end
        end)
        mb.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch then
                if mbDrag and (i.Position - mbDS).Magnitude < 10 then
                    Sentinel:Toggle()
                end
                mbDrag = false
            end
        end)
        AddConn(UserInputService.InputChanged:Connect(function(i)
            if mbDrag and i.UserInputType == Enum.UserInputType.Touch then
                local d = i.Position - mbDS
                mb.Position = UDim2.new(mbSP.X.Scale, mbSP.X.Offset+d.X, mbSP.Y.Scale, mbSP.Y.Offset+d.Y)
            end
        end))
        AddConn(RunService.Heartbeat:Connect(function()
            if Sentinel.RGBEnabled then
                local c = Color3.fromHSV((tick()*Sentinel.RGBSpeed) % 1, 0.65, 1)
                local s = mb:FindFirstChildOfClass("UIStroke")
                if s then s.Color = c end
                mb.TextColor3 = c
            end
        end))
    end

    table.insert(self.Windows, Window)
    return Window
end

-- ═══════════════════════════════════════
-- GLOBAL METHODS
-- ═══════════════════════════════════════

function Sentinel:SetFont(fn)
    if self.FontMap[fn] then
        self.CurrentFont = self.FontMap[fn]
        for _, l in ipairs(self.AllTextLabels) do
            if l and l.Parent then pcall(function() l.Font = self.CurrentFont end) end
        end
    end
end

function Sentinel:GetFlag(f) return self.Flags[f] end
function Sentinel:SetFlag(f, v) self.Flags[f] = v end

function Sentinel:Destroy()
    for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
    self.Connections = {}
    if ScreenGui then ScreenGui:Destroy() end
    self.Windows = {}; self.Flags = {}; self.Binds = {}
    self.AllTextLabels = {}; self._accentCallbacks = {}
end

return Sentinel
