--[[
    ╔═══════════════════════════════════════════════╗
    ║          SENTINEL GUI LIBRARY v2.2            ║
    ║       GameSense Style • Polished Edition      ║
    ║                                               ║
    ║  v2.2 Fixes:                                  ║
    ║  1. Color picker click-outside-to-close       ║
    ║  2. Improved dropdown & overall polish        ║
    ║  3. Minimal open/close animations             ║
    ║  4. Notifications below watermark, smooth     ║
    ║  5. Rounded corners + scale-aware context     ║
    ║  6. Full config system                        ║
    ╚═══════════════════════════════════════════════╝
]]--

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local GuiService = game:GetService("GuiService")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local Sentinel = {
    Version = "2.2",
    Windows = {},
    Flags = {},
    FlagSetters = {},
    Binds = {},
    Connections = {},
    ToggleKey = Enum.KeyCode.RightControl,
    Visible = true,
    Scale = IsMobile and 0.7 or 1,
    RGBSpeed = 1,
    RGBEnabled = true,
    CurrentFont = Enum.Font.Gotham,
    ConfigFolder = "SentinelConfigs",

    Theme = {
        Background  = Color3.fromRGB(15, 15, 15),
        Primary     = Color3.fromRGB(20, 20, 20),
        Secondary   = Color3.fromRGB(28, 28, 28),
        Tertiary    = Color3.fromRGB(35, 35, 35),
        Accent      = Color3.fromRGB(0, 150, 255),
        Text        = Color3.fromRGB(245, 245, 245),
        SubText     = Color3.fromRGB(160, 160, 160),
        Disabled    = Color3.fromRGB(70, 70, 70),
        Border      = Color3.fromRGB(60, 60, 60),
        InnerBorder = Color3.fromRGB(45, 45, 45),
        DarkBorder  = Color3.fromRGB(0, 0, 0),
        ElementBg   = Color3.fromRGB(30, 30, 30),
        ToggleOff   = Color3.fromRGB(55, 55, 55),
        SliderBg    = Color3.fromRGB(40, 40, 40),
        DropdownBg  = Color3.fromRGB(20, 20, 20),
        Hover       = Color3.fromRGB(45, 45, 45),
        GlassTrans  = 0.15,
    },

    FontMap = {
        ["Gotham"] = Enum.Font.Gotham,
        ["GothamBold"] = Enum.Font.GothamBold,
        ["GothamMedium"] = Enum.Font.GothamMedium,
        ["SourceSans"] = Enum.Font.SourceSans,
        ["SourceSansBold"] = Enum.Font.SourceSansBold,
        ["Code"] = Enum.Font.Code,
        ["Ubuntu"] = Enum.Font.Ubuntu,
        ["Roboto"] = Enum.Font.Roboto,
        ["RobotoMono"] = Enum.Font.RobotoMono,
    },

    AllTextLabels = {},
    _accentCbs = {},
    _activeNotifs = {},
    _openPopups = {},
    ActiveBinds = {},
    KeybindListFrame = nil,
}

-- ═══════════════════════════════════════
-- UTILITIES
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
    if not inst or not inst.Parent then return end
    local t = TweenService:Create(inst,
        TweenInfo.new(dur or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        props)
    t:Play()
    return t
end

local function AddConn(c)
    table.insert(Sentinel.Connections, c)
    return c
end

local function GetKeyName(kc)
    if not kc then return "..." end
    local a = {LeftShift="LSHIFT",RightShift="RSHIFT",LeftControl="LCTRL",RightControl="RCTRL",
        LeftAlt="LALT",RightAlt="RALT",Return="ENTER",Backspace="BKSP",CapsLock="CAPS"}
    return a[kc.Name] or kc.Name:upper()
end

local function Truncate(n, d) local m = 10^(d or 0) return math.floor(n*m)/m end

function Sentinel:OnAccentChange(cb) table.insert(self._accentCbs, cb) end
function Sentinel:SetAccent(c)
    self.Theme.Accent = c
    for _, cb in ipairs(self._accentCbs) do pcall(cb, c) end
end

-- Close all open popups (color pickers, etc.)
function Sentinel:CloseAllPopups()
    for i = #self._openPopups, 1, -1 do
        local p = self._openPopups[i]
        if p.close then p.close() end
        table.remove(self._openPopups, i)
    end
end

local function MakeDraggable(frame, handle)
    handle = handle or frame
    local dragging, dragInput, dragStart, startPos

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
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
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
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

function Sentinel:ShowSplash()
    local splash = Create("Frame", {
        Parent = ScreenGui, Name = "Splash",
        Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0,0,0), 
        BackgroundTransparency = 0, ZIndex = 10000
    })

    local content = Create("CanvasGroup", {
        Parent = splash, Size = UDim2.new(0, 250, 0, 100), 
        Position = UDim2.new(0.5, -125, 0.5, -50), BackgroundTransparency = 1,
        GroupTransparency = 1
    })

    local title = Create("TextLabel", {
        Parent = content, Size = UDim2.new(1, 0, 0, 60), 
        BackgroundTransparency = 1, Text = "SENTINEL", 
        TextColor3 = self.Theme.Text, TextSize = 54, 
        Font = Enum.Font.GothamBold, TextStrokeTransparency = 0.6
    })
    
    local glow = Create("Frame", {
        Parent = content, Size = UDim2.new(0, 180, 0, 2), 
        Position = UDim2.new(0.5, -90, 0, 64), BackgroundColor3 = self.Theme.Accent, 
        BorderSizePixel = 0, ZIndex = 23
    })
    Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = glow})

    local version = Create("TextLabel", {
        Parent = content, Size = UDim2.new(1, 0, 0, 20), 
        Position = UDim2.new(0, 0, 0, 68), BackgroundTransparency = 1, 
        Text = "MODERN HYBRID v" .. self.Version, TextColor3 = self.Theme.SubText, 
        TextSize = 13, Font = Enum.Font.GothamMedium
    })

    local barBg = Create("Frame", {
        Parent = content, Size = UDim2.new(0.5, 0, 0, 2), 
        Position = UDim2.new(0.25, 0, 0, 110), BackgroundColor3 = self.Theme.Secondary, 
        BorderSizePixel = 0
    })
    Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = barBg})
    
    local barFill = Create("Frame", {
        Parent = barBg, Size = UDim2.new(0, 0, 1, 0), 
        BackgroundColor3 = self.Theme.Accent, BorderSizePixel = 0
    })
    Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = barFill})

    -- Sequence
    Tween(content, {GroupTransparency = 0, Size = UDim2.new(0, 440, 0, 180), Position = UDim2.new(0.5, -220, 0.5, -90)}, 1.2, Enum.EasingStyle.Quint)
    task.wait(0.4)
    Tween(barFill, {Size = UDim2.new(1, 0, 1, 0)}, 1.8, Enum.EasingStyle.Quart)
    task.wait(2.0)

    Tween(splash, {BackgroundTransparency = 1}, 0.8)
    Tween(content, {GroupTransparency = 1, Size = UDim2.new(0, 500, 0, 220), Position = UDim2.new(0.5, -250, 0.5, -110)}, 0.6, Enum.EasingStyle.Quint)
    task.delay(0.9, function() splash:Destroy() end)
end

function Sentinel:UpdateKeybindList()
    if not self.KeybindListFrame then return end
    local container = self.KeybindListFrame:FindFirstChild("List", true)
    if not container then return end

    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local y = 0
    for flag, data in pairs(self.ActiveBinds) do
        if not self.Flags[flag] then continue end -- Only show if active (ON)
        local item = Create("Frame", {
            Parent = container, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 0, y),
            BackgroundTransparency = 1
        })
        Create("TextLabel", {
            Parent = item, Size = UDim2.new(0, 100, 1, 0), Position = UDim2.new(0, 5, 0, 0),
            BackgroundTransparency = 1, Text = data.Name, TextColor3 = self.Theme.Text, 
            TextSize = 10, Font = self.CurrentFont, TextXAlignment = Enum.TextXAlignment.Left
        })
        Create("TextLabel", {
            Parent = item, Size = UDim2.new(1, -110, 1, 0), Position = UDim2.new(0, 105, 0, 0),
            BackgroundTransparency = 1, Text = "[" .. GetKeyName(data.Key) .. "]", 
            TextColor3 = self.Theme.Accent, TextSize = 10, Font = self.CurrentFont, TextXAlignment = Enum.TextXAlignment.Right
        })
        y = y + 18
    end
    
    self.KeybindListFrame.Size = UDim2.new(0, 180, 0, 24 + y + (y > 0 and 4 or 2))
    self.KeybindListFrame.Visible = y > 0
end

function Sentinel:CreateKeybindList()
    local frame = Create("Frame", {
        Parent = ScreenGui, Name = "KeybindList",
        Size = UDim2.new(0, 180, 0, 24), Position = UDim2.new(0, 10, 0.5, 0),
        BackgroundColor3 = self.Theme.Primary, BorderSizePixel = 0, ZIndex = 500
    })
    self.KeybindListFrame = frame
    Create("UIStroke", {Parent = frame, Color = self.Theme.DarkBorder, Thickness = 1})
    Create("UIStroke", {Parent = frame, Color = self.Theme.Border, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
    
    local title = Create("TextLabel", {
        Parent = frame, Size = UDim2.new(1, 0, 0, 22), 
        BackgroundTransparency = 1, Text = "Keybinds", TextColor3 = self.Theme.Text, 
        TextSize = 11, Font = Enum.Font.GothamBold
    })
    
    local list = Create("Frame", {
        Parent = frame, Name = "List",
        Size = UDim2.new(1, -10, 1, -26), Position = UDim2.new(0, 5, 0, 24),
        BackgroundTransparency = 1
    })
    
    MakeDraggable(frame)
    self:UpdateKeybindList()
    return frame
end

-- ═══════════════════════════════════════
-- RGB BAR
-- ═══════════════════════════════════════

local function CreateRGBBar(parent, h, z)
    h = h or 2
    local bar = Create("Frame", {
        Parent = parent, Name = "RGBBar",
        Size = UDim2.new(1, 0, 0, h),
        BackgroundTransparency = 1, ZIndex = z or 10, ClipsDescendants = true,
    })
    local segs = {}
    for i = 1, 50 do
        segs[i] = Create("Frame", {
            Parent = bar, Size = UDim2.new(1/50, 1, 1, 0),
            Position = UDim2.new((i-1)/50, 0, 0, 0),
            BackgroundColor3 = Color3.fromHSV((i-1)/50, 0.75, 1),
            BorderSizePixel = 0, ZIndex = z or 10,
        })
    end
    AddConn(RunService.Heartbeat:Connect(function()
        if not Sentinel.RGBEnabled then
            for _, s in ipairs(segs) do s.BackgroundColor3 = Sentinel.Theme.Accent end
            return
        end
        local t = tick() * Sentinel.RGBSpeed * 0.5
        for i, s in ipairs(segs) do
            s.BackgroundColor3 = Color3.fromHSV((t + (i-1)/50) % 1, 0.65, 1)
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
        Size = UDim2.new(0, 320, 0, 26),
        Position = UDim2.new(1, -330, 0, 8),
        BackgroundColor3 = self.Theme.Primary,
        BorderSizePixel = 0, ZIndex = 100,
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = wm})
    Create("UIStroke", {Parent = wm, Color = self.Theme.DarkBorder, Thickness = 1})

    local inner = Create("Frame", {
        Parent = wm,
        Size = UDim2.new(1, -4, 1, -4), Position = UDim2.new(0, 2, 0, 2),
        BackgroundColor3 = self.Theme.Primary, BorderSizePixel = 0, ZIndex = 101,
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 3), Parent = inner})
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
        wm.Size = UDim2.new(0, w, 0, 26)
        wm.Position = UDim2.new(1, -(w + 10), 0, 8)
    end))
    self.Watermark = wm
end

-- ═══════════════════════════════════════
-- NOTIFICATIONS (BELOW WATERMARK, SMOOTH)
-- ═══════════════════════════════════════

function Sentinel:_repositionNotifs()
    for i, d in ipairs(self._activeNotifs) do
        if d.frame and d.frame.Parent then
            local y = 40 + (i - 1) * 58
            Tween(d.frame, {Position = UDim2.new(1, -310, 0, y)}, 0.25, Enum.EasingStyle.Quint)
        end
    end
end

function Sentinel:Notify(title, text, duration)
    duration = duration or 3
    local idx = #self._activeNotifs + 1
    local yPos = 40 + (idx - 1) * 58

    local notif = Create("Frame", {
        Parent = ScreenGui,
        Size = UDim2.new(0, 300, 0, 50),
        Position = UDim2.new(1, 310, 0, yPos),
        BackgroundColor3 = self.Theme.Primary,
        BorderSizePixel = 0, ZIndex = 200,
    })
    Create("UIStroke", {Parent = notif, Color = self.Theme.DarkBorder, Thickness = 1})
    Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = notif})

    -- Thin accent line on left
    local accentLine = Create("Frame", {
        Parent = notif,
        Size = UDim2.new(0, 3, 1, -6), Position = UDim2.new(0, 3, 0, 3),
        BackgroundColor3 = self.Theme.Accent,
        BorderSizePixel = 0, ZIndex = 201,
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = accentLine})

    Create("TextLabel", {
        Parent = notif,
        Size = UDim2.new(1, -16, 0, 18), Position = UDim2.new(0, 12, 0, 4),
        BackgroundTransparency = 1, Text = title or "SENTINEL",
        TextColor3 = self.Theme.Text, TextSize = 11,
        Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 201,
    })
    Create("TextLabel", {
        Parent = notif,
        Size = UDim2.new(1, -16, 0, 16), Position = UDim2.new(0, 12, 0, 22),
        BackgroundTransparency = 1, Text = text or "",
        TextColor3 = self.Theme.SubText, TextSize = 10,
        Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 201,
    })

    local progBg = Create("Frame", {
        Parent = notif,
        Size = UDim2.new(1, -20, 0, 2), Position = UDim2.new(0, 10, 1, -6),
        BackgroundColor3 = self.Theme.Tertiary, BorderSizePixel = 0, ZIndex = 201,
    })
    Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = progBg})
    local progFill = Create("Frame", {
        Parent = progBg,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = self.Theme.Accent,
        BorderSizePixel = 0, ZIndex = 202,
    })
    Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = progFill})

    local notifData = {frame = notif}
    table.insert(self._activeNotifs, notifData)

    -- Smooth slide in (Quint easing = very smooth deceleration)
    Tween(notif, {Position = UDim2.new(1, -310, 0, yPos)}, 0.35, Enum.EasingStyle.Quint)
    Tween(progFill, {Size = UDim2.new(0, 0, 1, 0)}, duration, Enum.EasingStyle.Linear)

    task.delay(duration, function()
        -- Smooth slide out
        Tween(notif, {Position = UDim2.new(1, 310, 0, notif.Position.Y.Offset)}, 0.35, Enum.EasingStyle.Quint)
        task.delay(0.4, function()
            for i, d in ipairs(self._activeNotifs) do
                if d == notifData then table.remove(self._activeNotifs, i) break end
            end
            if notif then notif:Destroy() end
            self:_repositionNotifs()
        end)
    end)
end

-- ═══════════════════════════════════════
-- CONTEXT MENU (SCALE-AWARE)
-- ═══════════════════════════════════════

local ContextMenu = nil

local function ShowContextMenu(element, callback)
    if ContextMenu then ContextMenu:Destroy() ContextMenu = nil end

    local scale = UIScaleObj.Scale
    local elPos = element.AbsolutePosition
    local elSize = element.AbsoluteSize

    local menuX = elPos.X / scale
    local menuY = (elPos.Y + elSize.Y + 2) / scale

    -- Clamp to screen
    local screenW = ScreenGui.AbsoluteSize.X / scale
    if menuX + 140 > screenW then menuX = screenW - 145 end

    local menu = Create("Frame", {
        Parent = ScreenGui,
        Size = UDim2.new(0, 140, 0, 0),
        Position = UDim2.new(0, menuX, 0, menuY),
        BackgroundColor3 = Sentinel.Theme.Primary,
        BorderSizePixel = 0, ZIndex = 500, ClipsDescendants = true,
    })
    Create("UIStroke", {Parent = menu, Color = Sentinel.Theme.Border, Thickness = 1})
    Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = menu})

    local options = {"Bind Key", "Reset"}
    local optH = 26
    Tween(menu, {Size = UDim2.new(0, 140, 0, #options * optH + 4)}, 0.12, Enum.EasingStyle.Quart)

    for i, name in ipairs(options) do
        local btn = Create("TextButton", {
            Parent = menu,
            Size = UDim2.new(1, -6, 0, optH),
            Position = UDim2.new(0, 3, 0, (i-1)*optH + 2),
            BackgroundTransparency = 1, BackgroundColor3 = Sentinel.Theme.Tertiary,
            Text = "  " .. name, TextColor3 = Sentinel.Theme.SubText,
            TextSize = 11, Font = Sentinel.CurrentFont,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 501, AutoButtonColor = false,
        })
        Create("UICorner", {CornerRadius = UDim.new(0, 3), Parent = btn})

        btn.MouseEnter:Connect(function()
            Tween(btn, {BackgroundTransparency = 0, TextColor3 = Sentinel.Theme.Text}, 0.08)
        end)
        btn.MouseLeave:Connect(function()
            Tween(btn, {BackgroundTransparency = 1, TextColor3 = Sentinel.Theme.SubText}, 0.08)
        end)
        btn.MouseButton1Click:Connect(function()
            callback(name == "Bind Key" and "bind" or "reset")
            Tween(menu, {Size = UDim2.new(0, 140, 0, 0)}, 0.1)
            task.delay(0.12, function() if menu then menu:Destroy() end ContextMenu = nil end)
        end)
    end
    ContextMenu = menu

    local closeC
    closeC = UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            task.wait(0.03)
            if not menu or not menu.Parent then closeC:Disconnect() return end
            local mp = UserInputService:GetMouseLocation()
            local mAbs, mSz = menu.AbsolutePosition, menu.AbsoluteSize
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
-- CONFIG SYSTEM
-- ═══════════════════════════════════════

function Sentinel:_ensureFolder()
    if isfolder and not isfolder(self.ConfigFolder) then
        makefolder(self.ConfigFolder)
    end
end

function Sentinel:SaveConfig(name)
    self:_ensureFolder()
    local data = {}
    for flag, val in pairs(self.Flags) do
        if type(val) == "boolean" or type(val) == "number" or type(val) == "string" then
            data[flag] = {type = type(val), value = val}
        elseif typeof(val) == "Color3" then
            data[flag] = {type = "Color3", value = {val.R, val.G, val.B}}
        elseif typeof(val) == "EnumItem" then
            data[flag] = {type = "EnumItem", value = tostring(val)}
        elseif type(val) == "table" then
            data[flag] = {type = "table", value = val}
        end
    end
    local json = HttpService:JSONEncode(data)
    if writefile then
        writefile(self.ConfigFolder .. "/" .. name .. ".json", json)
    end
end

function Sentinel:LoadConfig(name)
    self:_ensureFolder()
    local path = self.ConfigFolder .. "/" .. name .. ".json"
    if isfile and isfile(path) then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(path))
        end)
        if ok and data then
            for flag, info in pairs(data) do
                local val
                if info.type == "boolean" or info.type == "number" or info.type == "string" then
                    val = info.value
                elseif info.type == "Color3" then
                    val = Color3.new(info.value[1], info.value[2], info.value[3])
                elseif info.type == "EnumItem" then
                    -- Parse Enum.KeyCode.X format
                    local parts = tostring(info.value):split(".")
                    if #parts == 3 then
                        pcall(function() val = Enum[parts[2]][parts[3]] end)
                    end
                elseif info.type == "table" then
                    val = info.value
                end
                if val ~= nil then
                    self.Flags[flag] = val
                    if self.FlagSetters[flag] then
                        pcall(self.FlagSetters[flag], val)
                    end
                end
            end
        end
    end
end

function Sentinel:DeleteConfig(name)
    self:_ensureFolder()
    local path = self.ConfigFolder .. "/" .. name .. ".json"
    if isfile and isfile(path) then
        delfile(path)
    end
end

function Sentinel:GetConfigs()
    self:_ensureFolder()
    local configs = {}
    if listfiles then
        for _, file in ipairs(listfiles(self.ConfigFolder)) do
            local name = file:match("([^/\\]+)%.json$")
            if name then table.insert(configs, name) end
        end
    end
    return configs
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

    local main = Create("CanvasGroup", {
    Parent = ScreenGui, Name = "SentinelWindow",
        Size = winSize,
        Position = UDim2.new(0.5, -winSize.X.Offset/2, 0.5, -winSize.Y.Offset/2),
        BackgroundColor3 = self.Theme.Background,
        BackgroundTransparency = self.Theme.GlassTrans,
        BorderSizePixel = 0, ZIndex = 1, ClipsDescendants = true,
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = main})
    local mainStroke = Create("UIStroke", {Parent = main, Color = Color3.new(1,1,1), Thickness = 1, Transparency = 0.8})
    mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

    local inner = Create("Frame", {
        Parent = main,
        Size = UDim2.new(1, -6, 1, -6), Position = UDim2.new(0, 3, 0, 3),
        BackgroundColor3 = self.Theme.Primary, BackgroundTransparency = self.Theme.GlassTrans, BorderSizePixel = 0, ZIndex = 2,
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = inner})
    Create("UIStroke", {Parent = inner, Color = self.Theme.Border, Thickness = 1})

    CreateRGBBar(inner, 2, 50)

    -- Header
    local header = Create("Frame", {
        Parent = inner,
        Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0, 2),
        BackgroundTransparency = 1, ZIndex = 3,
    })

    -- Clean Text Logo with thin bar
    local logoBar = Create("Frame", {
        Parent = header,
        Size = UDim2.new(0, 2, 0, 14), Position = UDim2.new(0, 10, 0.5, -7),
        BackgroundColor3 = self.Theme.Accent, BorderSizePixel = 0,
        ZIndex = 5,
    })
    Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = logoBar})

    local titleLbl = Create("TextLabel", {
        Parent = header,
        Size = UDim2.new(0, 200, 1, 0), Position = UDim2.new(0, 18, 0, 0),
        BackgroundTransparency = 1, Text = winTitle,
        TextColor3 = self.Theme.Text, TextSize = 13,
        Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
    })
    table.insert(self.AllTextLabels, titleLbl)

    Create("TextLabel", {
        Parent = header,
        Size = UDim2.new(0, 30, 1, 0), Position = UDim2.new(0, 34 + titleLbl.TextBounds.X + 5, 0, 0),
        BackgroundTransparency = 1, Text = "v"..self.Version,
        TextColor3 = self.Theme.SubText, TextSize = 9,
        Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
    })

    local closeBtn = Create("TextButton", {
        Parent = header,
        Size = UDim2.new(0, 26, 0, 26), Position = UDim2.new(1, -30, 0.5, -13),
        BackgroundTransparency = 1, Text = "×",
        TextColor3 = self.Theme.SubText, TextSize = 16,
        Font = Enum.Font.GothamBold, ZIndex = 5, AutoButtonColor = false,
    })
    closeBtn.MouseEnter:Connect(function() Tween(closeBtn, {TextColor3 = Color3.fromRGB(255,80,80)}, 0.12) end)
    closeBtn.MouseLeave:Connect(function() Tween(closeBtn, {TextColor3 = self.Theme.SubText}, 0.12) end)
    closeBtn.MouseButton1Click:Connect(function() self:Toggle() end)

    Create("Frame", {
        Parent = inner,
        Size = UDim2.new(1, -8, 0, 1), Position = UDim2.new(0, 4, 0, 32),
        BackgroundColor3 = self.Theme.Border, BorderSizePixel = 0, ZIndex = 3,
    })

    -- Left Sidebar for Tabs
    local sideBar = Create("Frame", {
        Parent = inner,
        Size = UDim2.new(0, 150, 1, -38), Position = UDim2.new(0, 4, 0, 34),
        BackgroundColor3 = self.Theme.Secondary, BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 3,
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = sideBar})
    Create("UIStroke", {Parent = sideBar, Color = self.Theme.Border, Thickness = 1})

    local tabBtnCont = Create("ScrollingFrame", {
        Parent = sideBar,
        Size = UDim2.new(1, -4, 1, -4), Position = UDim2.new(0, 2, 0, 2),
        BackgroundTransparency = 1, ZIndex = 4, ScrollBarThickness = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    })
    Create("UIListLayout", {
        Parent = tabBtnCont, FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4),
    })

    local contentArea = Create("Frame", {
        Parent = inner,
        Size = UDim2.new(1, -164, 1, -38), Position = UDim2.new(0, 158, 0, 34),
        BackgroundTransparency = 1, ZIndex = 3, ClipsDescendants = true,
    })

    -- Drag
    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = i.Position; startPos = main.Position
        end
    end)
    header.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    AddConn(UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
        end
    end))

    -- MINIMAL TOGGLE ANIMATION
    function self:Toggle()
        self.Visible = not self.Visible
        self:CloseAllPopups()
        if self.Visible then
            main.Visible = true
            main.GroupTransparency = 1
            Tween(main, {GroupTransparency = 0}, 0.2, Enum.EasingStyle.Quint)
        else
            Tween(main, {GroupTransparency = 1}, 0.15, Enum.EasingStyle.Quint)
            task.delay(0.15, function() main.Visible = false end)
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

    -- Click outside to close popups
    AddConn(UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            task.defer(function()
                local mp = UserInputService:GetMouseLocation()
                for i = #self._openPopups, 1, -1 do
                    local p = self._openPopups[i]
                    if p.frame and p.frame.Parent and p.frame.Visible then
                        local pPos = p.frame.AbsolutePosition
                        local pSz = p.frame.AbsoluteSize
                        -- Also check if click is on the preview button
                        local onPreview = false
                        if p.preview then
                            local prPos = p.preview.AbsolutePosition
                            local prSz = p.preview.AbsoluteSize
                            if mp.X >= prPos.X and mp.X <= prPos.X+prSz.X and mp.Y >= prPos.Y-36 and mp.Y <= prPos.Y+prSz.Y then
                                onPreview = true
                            end
                        end
                        if not onPreview and (mp.X < pPos.X or mp.X > pPos.X+pSz.X or mp.Y < pPos.Y-36 or mp.Y > pPos.Y+pSz.Y) then
                            p.close()
                        end
                    end
                end
            end)
        end
    end))

    -- Open animation (minimal)
local useCanvas = main:IsA("CanvasGroup")
if useCanvas then
    main.GroupTransparency = 1
    Tween(main, {GroupTransparency = 0}, 0.25, Enum.EasingStyle.Quint)
else
    main.BackgroundTransparency = 0.3
    main.Size = UDim2.new(0, winSize.X.Offset, 0, winSize.Y.Offset * 0.97)
    Tween(main, {Size = winSize, BackgroundTransparency = 0}, 0.25, Enum.EasingStyle.Quint)
end

    -- ═══════════════════════════════════════
    -- TAB
    -- ═══════════════════════════════════════

    function Window:CreateTab(tc)
        tc = tc or {}
        local Tab = {Sections = {}, Name = tc.Name or "Tab"}

        local tabBtn = Create("TextButton", {
            Parent = tabBtnCont,
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundTransparency = 1, BackgroundColor3 = Sentinel.Theme.Tertiary,
            Text = "  " .. (tc.Name or "Tab"), TextColor3 = Sentinel.Theme.SubText,
            TextSize = 12, Font = Sentinel.CurrentFont,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 5, AutoButtonColor = false,
        })
        local indicator = Create("Frame", {
            Parent = tabBtn,
            Size = UDim2.new(0, 2, 0, 0), Position = UDim2.new(0, 0, 0.5, 0),
            BackgroundColor3 = Sentinel.Theme.Accent, BorderSizePixel = 0, ZIndex = 6,
        })
        Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = indicator})
        Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = tabBtn})
        table.insert(Sentinel.AllTextLabels, tabBtn)

        local tabContent = Create("Frame", {
            Parent = contentArea,
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1, Visible = false, ZIndex = 3,
        })

        local leftCol = Create("ScrollingFrame", {
            Parent = tabContent,
            Size = UDim2.new(0.5, -3, 1, 0),
            BackgroundTransparency = 1, ScrollBarThickness = 2,
            ScrollBarImageColor3 = Sentinel.Theme.Accent,
            BorderSizePixel = 0, ZIndex = 3,
            CanvasSize = UDim2.new(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        })
        Create("UIListLayout", {Parent = leftCol, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6)})
        Create("UIPadding", {Parent = leftCol, PaddingBottom = UDim.new(0, 6)})

        local rightCol = Create("ScrollingFrame", {
            Parent = tabContent,
            Size = UDim2.new(0.5, -3, 1, 0), Position = UDim2.new(0.5, 3, 0, 0),
            BackgroundTransparency = 1, ScrollBarThickness = 2,
            ScrollBarImageColor3 = Sentinel.Theme.Accent,
            BorderSizePixel = 0, ZIndex = 3,
            CanvasSize = UDim2.new(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        })
        Create("UIListLayout", {Parent = rightCol, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6)})
        Create("UIPadding", {Parent = rightCol, PaddingBottom = UDim.new(0, 6)})

        local function selectTab()
            Sentinel:CloseAllPopups()
            for _, t in ipairs(Window.Tabs) do
                Tween(t._btn, {TextColor3 = Sentinel.Theme.SubText, BackgroundTransparency = 1}, 0.15)
                local ind = t._btn:FindFirstChild("Frame")
                if ind then Tween(ind, {Size = UDim2.new(0, 2, 0, 0), Position = UDim2.new(0, 0, 0.5, 0)}, 0.15) end
                t._content.Visible = false
            end
            Tween(tabBtn, {TextColor3 = Sentinel.Theme.Text, BackgroundTransparency = 0.85}, 0.2)
            Tween(indicator, {Size = UDim2.new(0, 2, 0, 16), Position = UDim2.new(0, 2, 0.5, -8)}, 0.2, Enum.EasingStyle.Back)
            tabContent.Visible = true
            Window.ActiveTab = Tab
        end

        tabBtn.MouseButton1Click:Connect(selectTab)
        tabBtn.MouseEnter:Connect(function()
            if Window.ActiveTab ~= Tab then Tween(tabBtn, {TextColor3 = Sentinel.Theme.Text}, 0.08) end
        end)
        tabBtn.MouseLeave:Connect(function()
            if Window.ActiveTab ~= Tab then Tween(tabBtn, {TextColor3 = Sentinel.Theme.SubText}, 0.08) end
        end)

        Tab._btn = tabBtn
        Tab._content = tabContent
        if #Window.Tabs == 0 then task.defer(selectTab) end

        -- ═══════════════════════════════════════
        -- SECTION
        -- ═══════════════════════════════════════

        function Tab:CreateSection(sc)
            sc = sc or {}
            local Section = {Elements = {}}
            local col = (sc.Side == "Right") and rightCol or leftCol

            local sFrame = Create("Frame", {
                Parent = col, Size = UDim2.new(1, 0, 0, 0),
                BackgroundColor3 = Sentinel.Theme.Secondary,
                BorderSizePixel = 0, ZIndex = 4, AutomaticSize = Enum.AutomaticSize.Y,
            })
            Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = sFrame})
            Create("UIStroke", {Parent = sFrame, Color = Sentinel.Theme.Border, Thickness = 1})

            local sTitleBg = Create("Frame", {
                Parent = sFrame, Size = UDim2.new(1, 0, 0, 22),
                BackgroundColor3 = Sentinel.Theme.Tertiary,
                BorderSizePixel = 0, ZIndex = 5,
            })
            Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = sTitleBg})
            -- Bottom square corners via inner frame
            Create("Frame", {
                Parent = sTitleBg,
                Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 1, -6),
                BackgroundColor3 = Sentinel.Theme.Tertiary,
                BorderSizePixel = 0, ZIndex = 5,
            })

            Create("TextLabel", {
                Parent = sTitleBg,
                Size = UDim2.new(1, -10, 1, 0), Position = UDim2.new(0, 8, 0, 0),
                BackgroundTransparency = 1, Text = sc.Name or "Section",
                TextColor3 = Sentinel.Theme.Text, TextSize = 11,
                Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
            })

            local sCont = Create("Frame", {
                Parent = sFrame,
                Size = UDim2.new(1, -8, 0, 0), Position = UDim2.new(0, 4, 0, 24),
                BackgroundTransparency = 1, ZIndex = 5, AutomaticSize = Enum.AutomaticSize.Y,
            })
            Create("UIListLayout", {Parent = sCont, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3)})
            Create("UIPadding", {Parent = sCont, PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 6)})

            function Section:CreateSeparator()
                Create("Frame", {
                    Parent = sCont, Size = UDim2.new(1, -4, 0, 1),
                    BackgroundColor3 = Sentinel.Theme.Border, BorderSizePixel = 0, ZIndex = 6,
                })
            end

            function Section:CreateLabel(cfg)
                cfg = cfg or {}
                local l = Create("TextLabel", {
                    Parent = sCont, Size = UDim2.new(1, 0, 0, 18),
                    BackgroundTransparency = 1, Text = cfg.Text or "",
                    TextColor3 = Sentinel.Theme.SubText, TextSize = 11,
                    Font = Sentinel.CurrentFont, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6,
                })
                table.insert(Sentinel.AllTextLabels, l)
                local L = {}
                function L:SetText(t) l.Text = t end
                return L
            end

            function Section:CreateButton(cfg)
                cfg = cfg or {}
                local bf = Create("Frame", {
                    Parent = sCont, Size = UDim2.new(1, 0, 0, 26),
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
                Create("UIStroke", {Parent = btn, Color = Sentinel.Theme.DarkBorder, Thickness = 1})
                Create("UIStroke", {Parent = btn, Color = Sentinel.Theme.Border, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
                table.insert(Sentinel.AllTextLabels, btn)

                btn.MouseEnter:Connect(function() Tween(btn, {BackgroundColor3 = Sentinel.Theme.Hover}, 0.08) end)
                btn.MouseLeave:Connect(function() Tween(btn, {BackgroundColor3 = Sentinel.Theme.ElementBg}, 0.08) end)
                btn.MouseButton1Click:Connect(function()
                    Tween(btn, {BackgroundColor3 = Sentinel.Theme.Accent}, 0.05)
                    task.delay(0.12, function() Tween(btn, {BackgroundColor3 = Sentinel.Theme.ElementBg}, 0.12) end)
                    if cfg.Callback then cfg.Callback() end
                end)
            end

            -- ═══ TOGGLE ═══

            function Section:CreateToggle(cfg)
                cfg = cfg or {}
                local toggled = cfg.Default or false
                local flag = cfg.Flag or ("t_"..math.random(10000,99999))
                local boundKey = nil
                Sentinel.Flags[flag] = toggled

                local tF = Create("Frame", {
                    Parent = sCont, Size = UDim2.new(1, 0, 0, 22),
                    BackgroundTransparency = 1, ZIndex = 6,
                })

                local cbOuter = Create("Frame", {
                    Parent = tF,
                    Size = UDim2.new(0, 12, 0, 12), Position = UDim2.new(0, 4, 0.5, -6),
                    BackgroundColor3 = Sentinel.Theme.ToggleOff,
                    BorderSizePixel = 0, ZIndex = 8,
                })
                Create("UIStroke", {Parent = cbOuter, Color = Sentinel.Theme.DarkBorder, Thickness = 1})
                Create("UIStroke", {Parent = cbOuter, Color = Sentinel.Theme.Border, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
                Create("UICorner", {CornerRadius = UDim.new(0, 3), Parent = cbOuter})

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
                    Parent = tF,
                    Size = UDim2.new(1, -60, 1, 0), Position = UDim2.new(0, 22, 0, 0),
                    BackgroundTransparency = 1, Text = cfg.Name or "Toggle",
                    TextColor3 = toggled and Sentinel.Theme.Text or Sentinel.Theme.SubText,
                    TextSize = 11, Font = Sentinel.CurrentFont,
                    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7,
                })
                table.insert(Sentinel.AllTextLabels, tLabel)

                local bindLbl = Create("TextLabel", {
                    Parent = tF,
                    Size = UDim2.new(0, 40, 1, 0), Position = UDim2.new(1, -44, 0, 0),
                    BackgroundTransparency = 1, Text = "",
                    TextColor3 = Sentinel.Theme.Disabled, TextSize = 9,
                    Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 7,
                })

                local function setToggle(v)
                    toggled = v
                    Sentinel.Flags[flag] = v
                    Tween(cbFill, {
                        Size = v and UDim2.new(1, -4, 1, -4) or UDim2.new(0, 0, 0, 0),
                        BackgroundTransparency = v and 0 or 1,
                        BackgroundColor3 = v and Sentinel.Theme.Accent or Sentinel.Theme.ToggleOff,
                    }, 0.15, Enum.EasingStyle.Back)
                    Tween(cbOuter, {BackgroundColor3 = v and Sentinel.Theme.Accent or Sentinel.Theme.ToggleOff, BackgroundTransparency = v and 0.8 or 0}, 0.2)
                    Tween(tLabel, {TextColor3 = v and Sentinel.Theme.Text or Sentinel.Theme.SubText}, 0.15)
                    if cfg.Callback then cfg.Callback(v) end
                end

                Sentinel.FlagSetters[flag] = function(v) setToggle(v) end

                Sentinel:OnAccentChange(function(c)
                    if toggled then cbFill.BackgroundColor3 = c; cbOuter.BackgroundColor3 = c end
                end)

                local click = Create("TextButton", {
                    Parent = tF, Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1, Text = "", ZIndex = 10, AutoButtonColor = false,
                })
                click.MouseButton1Click:Connect(function() setToggle(not toggled) end)
                click.MouseEnter:Connect(function()
                    if not toggled then Tween(cbOuter, {BackgroundColor3 = Sentinel.Theme.Hover}, 0.08) end
                end)
                click.MouseLeave:Connect(function()
                    if not toggled then Tween(cbOuter, {BackgroundColor3 = Sentinel.Theme.ToggleOff}, 0.08) end
                end)

                click.MouseButton2Click:Connect(function()
                    ShowContextMenu(tF, function(act)
                        if act == "bind" then
                            bindLbl.Text = "[...]"; bindLbl.TextColor3 = Sentinel.Theme.Accent
                            local bc
                            bc = UserInputService.InputBegan:Connect(function(inp)
                                if inp.UserInputType == Enum.UserInputType.Keyboard then
                                    boundKey = inp.KeyCode
                                    bindLbl.Text = "["..GetKeyName(boundKey).."]"
                                    bindLbl.TextColor3 = Sentinel.Theme.Disabled
                                    Sentinel.Binds[flag] = {Key = boundKey, Callback = function() setToggle(not toggled) end}
                                    Sentinel.ActiveBinds[flag] = {Name = cfg.Name or "Toggle", Key = boundKey}
                                    Sentinel:UpdateKeybindList()
                                    bc:Disconnect()
                                end
                            end)
                        elseif act == "reset" then
                            setToggle(cfg.Default or false)
                            boundKey = nil; bindLbl.Text = ""; Sentinel.Binds[flag] = nil
                            Sentinel.ActiveBinds[flag] = nil
                            Sentinel:UpdateKeybindList()
                        end
                    end)
                end)

                if toggled then setToggle(true) end
                local T = {}
                function T:Set(v) setToggle(v) end
                function T:Get() return toggled end
                return T
            end

            -- ═══ SLIDER ═══

            function Section:CreateSlider(cfg)
                cfg = cfg or {}
                local minV, maxV = cfg.Min or 0, cfg.Max or 100
                local curV = cfg.Default or minV
                local inc = cfg.Increment or 1
                local suf = cfg.Suffix or ""
                local flag = cfg.Flag or ("s_"..math.random(10000,99999))
                Sentinel.Flags[flag] = curV

                local slF = Create("Frame", {
                    Parent = sCont, Size = UDim2.new(1, 0, 0, 32),
                    BackgroundTransparency = 1, ZIndex = 6,
                })
                local slLabel = Create("TextLabel", {
                    Parent = slF,
                    Size = UDim2.new(0.7, 0, 0, 14), Position = UDim2.new(0, 4, 0, 0),
                    BackgroundTransparency = 1, Text = cfg.Name or "Slider",
                    TextColor3 = Sentinel.Theme.SubText, TextSize = 11,
                    Font = Sentinel.CurrentFont, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7,
                })
                table.insert(Sentinel.AllTextLabels, slLabel)

                local valLbl = Create("TextLabel", {
                    Parent = slF,
                    Size = UDim2.new(0.3, -4, 0, 14), Position = UDim2.new(0.7, 0, 0, 0),
                    BackgroundTransparency = 1, Text = tostring(curV)..suf,
                    TextColor3 = Sentinel.Theme.Accent, TextSize = 11,
                    Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 7,
                })
                Sentinel:OnAccentChange(function(c) valLbl.TextColor3 = c end)

                local track = Create("Frame", {
                    Parent = slF,
                    Size = UDim2.new(1, -8, 0, 4), Position = UDim2.new(0, 4, 0, 19),
                    BackgroundColor3 = Sentinel.Theme.SliderBg,
                    BorderSizePixel = 0, ZIndex = 7,
                })
                Create("UIStroke", {Parent = track, Color = Sentinel.Theme.DarkBorder, Thickness = 1})

                local pct = (curV - minV) / (maxV - minV)
                local fill = Create("Frame", {
                    Parent = track,
                    Size = UDim2.new(pct, 0, 1, 0),
                    BackgroundColor3 = Sentinel.Theme.Accent,
                    BorderSizePixel = 0, ZIndex = 8,
                })
                -- Sharp fill for slider
                Sentinel:OnAccentChange(function(c) fill.BackgroundColor3 = c end)

                local sliding = false

                local function updateSlider(p)
                    p = math.clamp(p, 0, 1)
                    local raw = minV + (maxV - minV) * p
                    local stepped = math.floor(raw / inc + 0.5) * inc
                    curV = math.clamp(Truncate(stepped, 2), minV, maxV)
                    Sentinel.Flags[flag] = curV
                    local np = (curV - minV) / (maxV - minV)
                    fill.Size = UDim2.new(np, 0, 1, 0)
                    valLbl.Text = tostring(curV)..suf
                    if cfg.Callback then cfg.Callback(curV) end
                end

                Sentinel.FlagSetters[flag] = function(v) updateSlider((v-minV)/(maxV-minV)) end

                local slBtn = Create("TextButton", {
                    Parent = track,
                    Size = UDim2.new(1, 0, 1, 14), Position = UDim2.new(0, 0, 0, -7),
                    BackgroundTransparency = 1, Text = "", ZIndex = 10, AutoButtonColor = false,
                })

                slBtn.InputBegan:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        sliding = true
                        updateSlider((i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X)
                    end
                end)
                AddConn(UserInputService.InputChanged:Connect(function(i)
                    if sliding and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                        updateSlider((i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X)
                    end
                end))
                AddConn(UserInputService.InputEnded:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        sliding = false
                    end
                end))

                slBtn.MouseEnter:Connect(function() Tween(slLabel, {TextColor3 = Sentinel.Theme.Text}, 0.08) end)
                slBtn.MouseLeave:Connect(function()
                    if not sliding then Tween(slLabel, {TextColor3 = Sentinel.Theme.SubText}, 0.08) end
                end)

                slBtn.MouseButton2Click:Connect(function()
                    ShowContextMenu(slF, function(act)
                        if act == "reset" then updateSlider(((cfg.Default or minV)-minV)/(maxV-minV)) end
                    end)
                end)

                local S = {}
                function S:Set(v) updateSlider((v-minV)/(maxV-minV)) end
                function S:Get() return curV end
                return S
            end

            -- ═══ DROPDOWN (IMPROVED) ═══

            function Section:CreateDropdown(cfg)
                cfg = cfg or {}
                local options = cfg.Options or {}
                local selected = cfg.Default or (options[1] or "")
                local flag = cfg.Flag or ("d_"..math.random(10000,99999))
                local isOpen = false
                local multi = cfg.Multi or false
                local multiSel = {}
                local openDropdown, closeDropdown -- Forward declarations

                if multi and type(cfg.Default) == "table" then
                    for _, v in ipairs(cfg.Default) do multiSel[v] = true end
                end
                Sentinel.Flags[flag] = multi and multiSel or selected

                local dF = Create("Frame", {
                    Parent = sCont, Size = UDim2.new(1, 0, 0, 40),
                    BackgroundTransparency = 1, ZIndex = 6, ClipsDescendants = false,
                })

                Create("TextLabel", {
                    Parent = dF,
                    Size = UDim2.new(1, -4, 0, 14), Position = UDim2.new(0, 4, 0, 0),
                    BackgroundTransparency = 1, Text = cfg.Name or "Dropdown",
                    TextColor3 = Sentinel.Theme.SubText, TextSize = 11,
                    Font = Sentinel.CurrentFont, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7,
                })

                local dBtn = Create("TextButton", {
                    Parent = dF,
                    Size = UDim2.new(1, -4, 0, 22), Position = UDim2.new(0, 2, 0, 16),
                    BackgroundColor3 = Sentinel.Theme.ElementBg,
                    Text = "", ZIndex = 7, AutoButtonColor = false,
                })
                Create("UIStroke", {Parent = dBtn, Color = Sentinel.Theme.DarkBorder, Thickness = 1})
                local innerStroke = Create("UIStroke", {Parent = dBtn, Color = Sentinel.Theme.Border, Thickness = 1})
                innerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

                local selLbl = Create("TextLabel", {
                    Parent = dBtn,
                    Size = UDim2.new(1, -24, 1, 0), Position = UDim2.new(0, 6, 0, 0),
                    BackgroundTransparency = 1, Text = tostring(selected),
                    TextColor3 = Sentinel.Theme.Text, TextSize = 11,
                    Font = Sentinel.CurrentFont, TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 8,
                })
                table.insert(Sentinel.AllTextLabels, selLbl)

                local arrow = Create("TextLabel", {
                    Parent = dBtn,
                    Size = UDim2.new(0, 16, 1, 0), Position = UDim2.new(1, -20, 0, 0),
                    BackgroundTransparency = 1, Text = "▾",
                    TextColor3 = Sentinel.Theme.SubText, TextSize = 10,
                    Font = Enum.Font.GothamBold, ZIndex = 8, Rotation = 0,
                })

                -- Drop list as popup on ScreenGui (so it's not clipped)
                local dOverlay = Create("TextButton", {
                    Parent = ScreenGui, Size = UDim2.new(1, 0, 1, 0), 
                    BackgroundColor3 = Color3.new(0,0,0), BackgroundTransparency = 1,
                    Text = "", AutoButtonColor = false, Visible = false, ZIndex = 2999
                })
                local dList = Create("Frame", {
                    Parent = ScreenGui,
                    Size = UDim2.new(0, 220, 0, 0),
                    Position = UDim2.new(0.5, -110, 0.5, 0),
                    BackgroundColor3 = Sentinel.Theme.DropdownBg, BackgroundTransparency = 0.05,
                    BorderSizePixel = 0, ZIndex = 3000, ClipsDescendants = true, Visible = false,
                })
                Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = dList})
                local listStroke = Create("UIStroke", {Parent = dList, Color = Color3.new(1,1,1), Thickness = 1, Transparency = 0.8})
                listStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

                local listScroll = Create("ScrollingFrame", {
                    Parent = dList,
                    Size = UDim2.new(1, -4, 1, -4), Position = UDim2.new(0, 2, 0, 2),
                    BackgroundTransparency = 1, ScrollBarThickness = 2,
                    ScrollBarImageColor3 = Sentinel.Theme.Accent,
                    BorderSizePixel = 0, ZIndex = 61,
                    CanvasSize = UDim2.new(0,0,0,0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
                })
                Create("UIListLayout", {Parent = listScroll, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1)})

                local optItems = {}

                local function updateMultiText()
                    local s = {}
                    for k, v in pairs(multiSel) do if v then table.insert(s, k) end end
                    selLbl.Text = #s > 0 and table.concat(s, ", ") or "None"
                end

                local function createOpt(optName)
                    local isSel = (not multi and selected == optName) or (multi and multiSel[optName])
                    local oi = Create("TextButton", {
                        Parent = listScroll,
                        Size = UDim2.new(1, 0, 0, 24),
                        BackgroundColor3 = Sentinel.Theme.DropdownBg,
                        Text = "", ZIndex = 62, AutoButtonColor = false,
                    })
                    Create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = oi})

                    -- Selection indicator dot
                    local dot = Create("Frame", {
                        Parent = oi,
                        Size = UDim2.new(0, 4, 0, 4), Position = UDim2.new(0, 6, 0.5, -2),
                        BackgroundColor3 = isSel and Sentinel.Theme.Accent or Sentinel.Theme.Disabled,
                        BorderSizePixel = 0, ZIndex = 63,
                    })
                    Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = dot})

                    local oLbl = Create("TextLabel", {
                        Parent = oi,
                        Size = UDim2.new(1, -18, 1, 0), Position = UDim2.new(0, 16, 0, 0),
                        BackgroundTransparency = 1, Text = optName,
                        TextColor3 = isSel and Sentinel.Theme.Accent or Sentinel.Theme.SubText,
                        TextSize = 11, Font = Sentinel.CurrentFont,
                        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 63,
                    })
                    table.insert(Sentinel.AllTextLabels, oLbl)

                    Sentinel:OnAccentChange(function(c)
                        if (not multi and selected == optName) or (multi and multiSel[optName]) then
                            oLbl.TextColor3 = c; dot.BackgroundColor3 = c
                        end
                    end)

                    oi.MouseEnter:Connect(function()
                        Tween(oi, {BackgroundColor3 = Sentinel.Theme.Tertiary}, 0.06)
                    end)
                    oi.MouseLeave:Connect(function()
                        Tween(oi, {BackgroundColor3 = Sentinel.Theme.DropdownBg}, 0.06)
                    end)

                    oi.MouseButton1Click:Connect(function()
                        if multi then
                            multiSel[optName] = not multiSel[optName]
                            local s = multiSel[optName]
                            Tween(oLbl, {TextColor3 = s and Sentinel.Theme.Accent or Sentinel.Theme.SubText}, 0.08)
                            Tween(dot, {BackgroundColor3 = s and Sentinel.Theme.Accent or Sentinel.Theme.Disabled}, 0.08)
                            updateMultiText()
                            Sentinel.Flags[flag] = multiSel
                            if cfg.Callback then cfg.Callback(multiSel) end
                        else
                            selected = optName
                            selLbl.Text = optName
                            Sentinel.Flags[flag] = selected
                            for _, item in ipairs(optItems) do
                                local l = item:FindFirstChildOfClass("TextLabel")
                                local d = nil
                                for _, ch in ipairs(item:GetChildren()) do
                                    if ch:IsA("Frame") and ch.Size == UDim2.new(0,4,0,4) then d = ch break end
                                end
                                if l then
                                    local match = l.Text == optName
                                    Tween(l, {TextColor3 = match and Sentinel.Theme.Accent or Sentinel.Theme.SubText}, 0.08)
                                    if d then Tween(d, {BackgroundColor3 = match and Sentinel.Theme.Accent or Sentinel.Theme.Disabled}, 0.08) end
                                end
                            end
                            closeDropdown()
                            if cfg.Callback then cfg.Callback(selected) end
                        end
                    end)
                    table.insert(optItems, oi)
                end

                closeDropdown = function()
                    if not isOpen then return end
                    isOpen = false
                    Tween(arrow, {Rotation = 0}, 0.15)
                    Tween(dOverlay, {BackgroundTransparency = 1}, 0.2)
                    Tween(dList, {Size = UDim2.new(0, 220, 0, 0), Position = UDim2.new(0.5, -110, 0.5, 20), BackgroundTransparency = 1}, 0.2, Enum.EasingStyle.Quint)
                    task.delay(0.2, function() 
                        dList.Visible = false 
                        dOverlay.Visible = false
                        -- Show Main Menu back
                        local win = ScreenGui:FindFirstChild("SentinelWindow")
                        if win then win.Visible = true end
                    end)
                end

                openDropdown = function()
                    isOpen = true
                    -- Hide Main Menu
                    local win = ScreenGui:FindFirstChild("SentinelWindow")
                    if win then win.Visible = false end

                    dOverlay.Visible = true
                    dOverlay.BackgroundTransparency = 1
                    Tween(dOverlay, {BackgroundTransparency = 0.5}, 0.3)

                    dList.Position = UDim2.new(0.5, -110, 0.5, 20)
                    dList.Size = UDim2.new(0, 220, 0, 0)
                    dList.BackgroundTransparency = 1
                    dList.Visible = true
                    
                    local lh = math.min(#options * 25 + 10, 300)
                    Tween(arrow, {Rotation = 180}, 0.15)
                    Tween(dList, {Size = UDim2.new(0, 220, 0, lh), Position = UDim2.new(0.5, -110, 0.5, -lh/2), BackgroundTransparency = 0.05}, 0.25, Enum.EasingStyle.Back)
                end

                dOverlay.MouseButton1Click:Connect(closeDropdown)

                for _, o in ipairs(options) do createOpt(o) end
                if multi then updateMultiText() end

                dBtn.MouseButton1Click:Connect(function()
                    if isOpen then closeDropdown() else openDropdown() end
                end)

                dBtn.MouseEnter:Connect(function() Tween(dBtn, {BackgroundColor3 = Sentinel.Theme.Hover}, 0.08) end)
                dBtn.MouseLeave:Connect(function() Tween(dBtn, {BackgroundColor3 = Sentinel.Theme.ElementBg}, 0.08) end)

                -- Outside click handled by dOverlay

                -- Right-click
                dBtn.MouseButton2Click:Connect(function()
                    ShowContextMenu(dF, function(act)
                        if act == "reset" then
                            if multi then
                                multiSel = {}; updateMultiText()
                                for _, item in ipairs(optItems) do
                                    local l = item:FindFirstChildOfClass("TextLabel")
                                    if l then Tween(l, {TextColor3 = Sentinel.Theme.SubText}, 0.08) end
                                    for _, ch in ipairs(item:GetChildren()) do
                                        if ch:IsA("Frame") and ch.Size == UDim2.new(0,4,0,4) then
                                            Tween(ch, {BackgroundColor3 = Sentinel.Theme.Disabled}, 0.08)
                                        end
                                    end
                                end
                            else
                                selected = cfg.Default or (options[1] or "")
                                selLbl.Text = selected
                            end
                            Sentinel.Flags[flag] = multi and multiSel or selected
                            if cfg.Callback then cfg.Callback(multi and multiSel or selected) end
                        end
                    end)
                end)

                Sentinel.FlagSetters[flag] = function(v)
                    if multi then multiSel = v; updateMultiText()
                    else selected = v; selLbl.Text = v end
                    Sentinel.Flags[flag] = multi and multiSel or selected
                end

                local D = {}
                function D:Set(v)
                    if multi then multiSel = v; updateMultiText() else selected = v; selLbl.Text = v end
                    Sentinel.Flags[flag] = multi and multiSel or selected
                end
                function D:Get() return multi and multiSel or selected end
                function D:Refresh(newOpts)
                    options = newOpts
                    for _, it in ipairs(optItems) do it:Destroy() end
                    optItems = {}
                    for _, o in ipairs(newOpts) do createOpt(o) end
                end
                return D
            end

            -- ═══ KEYBIND ═══

            function Section:CreateKeybind(cfg)
                cfg = cfg or {}
                local curKey = cfg.Default or Enum.KeyCode.Unknown
                local flag = cfg.Flag or ("kb_"..math.random(10000,99999))
                local listening = false
                Sentinel.Flags[flag] = curKey

                local kF = Create("Frame", {
                    Parent = sCont, Size = UDim2.new(1, 0, 0, 22),
                    BackgroundTransparency = 1, ZIndex = 6,
                })
                Create("TextLabel", {
                    Parent = kF,
                    Size = UDim2.new(0.6, 0, 1, 0), Position = UDim2.new(0, 4, 0, 0),
                    BackgroundTransparency = 1, Text = cfg.Name or "Keybind",
                    TextColor3 = Sentinel.Theme.SubText, TextSize = 11,
                    Font = Sentinel.CurrentFont, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7,
                })

                local kBtn = Create("TextButton", {
                    Parent = kF,
                    Size = UDim2.new(0, 60, 0, 18), Position = UDim2.new(1, -64, 0.5, -9),
                    BackgroundColor3 = Sentinel.Theme.ElementBg,
                    Text = curKey ~= Enum.KeyCode.Unknown and "["..GetKeyName(curKey).."]" or "[...]",
                    TextColor3 = Sentinel.Theme.SubText, TextSize = 10,
                    Font = Enum.Font.GothamBold, ZIndex = 8,
                    AutoButtonColor = false, AutomaticSize = Enum.AutomaticSize.X,
                })
                Create("UIStroke", {Parent = kBtn, Color = Sentinel.Theme.DarkBorder, Thickness = 1})
                Create("UIStroke", {Parent = kBtn, Color = Sentinel.Theme.Border, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
                Create("UIPadding", {Parent = kBtn, PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)})

                kBtn.MouseButton1Click:Connect(function()
                    listening = true; kBtn.Text = "[...]"
                    Tween(kBtn, {TextColor3 = Sentinel.Theme.Accent}, 0.08)
                    local bc
                    bc = UserInputService.InputBegan:Connect(function(inp)
                        if inp.UserInputType == Enum.UserInputType.Keyboard then
                            curKey = inp.KeyCode == Enum.KeyCode.Escape and Enum.KeyCode.Unknown or inp.KeyCode
                            kBtn.Text = curKey ~= Enum.KeyCode.Unknown and "["..GetKeyName(curKey).."]" or "[NONE]"
                            Sentinel.Flags[flag] = curKey
                            
                            if curKey ~= Enum.KeyCode.Unknown then
                                Sentinel.ActiveBinds[flag] = {Name = cfg.Name or "Keybind", Key = curKey}
                            else
                                Sentinel.ActiveBinds[flag] = nil
                            end
                            Sentinel:UpdateKeybindList()

                            Tween(kBtn, {TextColor3 = Sentinel.Theme.SubText}, 0.08)
                            listening = false; bc:Disconnect()
                            if cfg.Callback then cfg.Callback(curKey) end
                        end
                    end)
                end)

                kBtn.MouseEnter:Connect(function() Tween(kBtn, {BackgroundColor3 = Sentinel.Theme.Hover}, 0.08) end)
                kBtn.MouseLeave:Connect(function() Tween(kBtn, {BackgroundColor3 = Sentinel.Theme.ElementBg}, 0.08) end)

                AddConn(UserInputService.InputBegan:Connect(function(inp, gp)
                    if gp or listening then return end
                    if inp.KeyCode == curKey and curKey ~= Enum.KeyCode.Unknown and cfg.OnPress then cfg.OnPress() end
                end))

                Sentinel.FlagSetters[flag] = function(v) curKey = v; kBtn.Text = "["..GetKeyName(v).."]" end

                local K = {}
                function K:Set(k) curKey = k; Sentinel.Flags[flag] = k; kBtn.Text = "["..GetKeyName(k).."]" end
                function K:Get() return curKey end
                return K
            end

            -- ═══ TEXTBOX ═══

            function Section:CreateTextbox(cfg)
                cfg = cfg or {}
                local flag = cfg.Flag or ("tb_"..math.random(10000,99999))
                Sentinel.Flags[flag] = cfg.Default or ""

                local tbF = Create("Frame", {
                    Parent = sCont, Size = UDim2.new(1, 0, 0, 40),
                    BackgroundTransparency = 1, ZIndex = 6,
                })
                Create("TextLabel", {
                    Parent = tbF,
                    Size = UDim2.new(1, -4, 0, 14), Position = UDim2.new(0, 4, 0, 0),
                    BackgroundTransparency = 1, Text = cfg.Name or "Textbox",
                    TextColor3 = Sentinel.Theme.SubText, TextSize = 11,
                    Font = Sentinel.CurrentFont, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7,
                })

                local tb = Create("TextBox", {
                    Parent = tbF,
                    Size = UDim2.new(1, -4, 0, 22), Position = UDim2.new(0, 2, 0, 16),
                    BackgroundColor3 = Sentinel.Theme.ElementBg,
                    Text = cfg.Default or "", PlaceholderText = cfg.Placeholder or "...",
                    PlaceholderColor3 = Sentinel.Theme.Disabled,
                    TextColor3 = Sentinel.Theme.Text, TextSize = 11,
                    Font = Sentinel.CurrentFont, ZIndex = 8,
                    ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
                })
                Create("UIStroke", {Parent = tb, Color = Sentinel.Theme.DarkBorder, Thickness = 1})
                Create("UIStroke", {Parent = tb, Color = Sentinel.Theme.Border, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border})
                Create("UIPadding", {Parent = tb, PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)})
                table.insert(Sentinel.AllTextLabels, tb)

                tb.Focused:Connect(function()
                    Tween(tb, {BackgroundColor3 = Sentinel.Theme.Hover}, 0.08)
                    local s = tb:FindFirstChildOfClass("UIStroke")
                    if s then Tween(s, {Color = Sentinel.Theme.Accent}, 0.08) end
                end)
                tb.FocusLost:Connect(function(ep)
                    Tween(tb, {BackgroundColor3 = Sentinel.Theme.ElementBg}, 0.08)
                    local s = tb:FindFirstChildOfClass("UIStroke")
                    if s then Tween(s, {Color = Sentinel.Theme.Border}, 0.08) end
                    Sentinel.Flags[flag] = tb.Text
                    if cfg.Callback then cfg.Callback(tb.Text, ep) end
                end)

                Sentinel.FlagSetters[flag] = function(v) tb.Text = v end

                local TB = {}
                function TB:Set(t) tb.Text = t; Sentinel.Flags[flag] = t end
                function TB:Get() return tb.Text end
                return TB
            end

            -- ═══ COLOR PICKER (CLICK-OUTSIDE-TO-CLOSE) ═══

            function Section:CreateColorPicker(cfg)
                cfg = cfg or {}
                local curColor = cfg.Default or Color3.new(1,1,1)
                local flag = cfg.Flag or ("cp_"..math.random(10000,99999))
                local isOpen = false
                Sentinel.Flags[flag] = curColor

                local curH, curS, curV = Color3.toHSV(curColor)
                local curAlpha = cfg.DefaultAlpha or 1

                local cpF = Create("Frame", {
                    Parent = sCont, Size = UDim2.new(1, 0, 0, 22),
                    BackgroundTransparency = 1, ZIndex = 6, ClipsDescendants = false,
                })
                Create("TextLabel", {
                    Parent = cpF,
                    Size = UDim2.new(0.7, 0, 1, 0), Position = UDim2.new(0, 4, 0, 0),
                    BackgroundTransparency = 1, Text = cfg.Name or "Color",
                    TextColor3 = Sentinel.Theme.SubText, TextSize = 11,
                    Font = Sentinel.CurrentFont, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 7,
                })

                local preview = Create("TextButton", {
                    Parent = cpF,
                    Size = UDim2.new(0, 24, 0, 14), Position = UDim2.new(1, -28, 0.5, -7),
                    BackgroundColor3 = curColor, Text = "", ZIndex = 8, AutoButtonColor = false,
                })
                Create("UICorner", {CornerRadius = UDim.new(0, 3), Parent = preview})
                Create("UIStroke", {Parent = preview, Color = Sentinel.Theme.Border, Thickness = 1})

                -- Popup on ScreenGui
                local svH = 120
                local popupH = 8 + 12 + 6 + svH + 6 + 10 + 6 + 18 + 8
                local popup = Create("Frame", {
                    Parent = ScreenGui,
                    Size = UDim2.new(0, 200, 0, 0),
                    BackgroundColor3 = Sentinel.Theme.Primary,
                    BorderSizePixel = 0, ZIndex = 300, ClipsDescendants = true, Visible = false,
                })
                Create("UIStroke", {Parent = popup, Color = Sentinel.Theme.Border, Thickness = 1})
                Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = popup})

                -- Hue bar
                local hueBar = Create("Frame", {
                    Parent = popup,
                    Size = UDim2.new(1, -16, 0, 12), Position = UDim2.new(0, 8, 0, 8),
                    BackgroundColor3 = Color3.new(1,0,0), BorderSizePixel = 0, ZIndex = 301,
                })
                Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = hueBar})
                Create("UIGradient", {Parent = hueBar, Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255,0,0)),
                    ColorSequenceKeypoint.new(0.167, Color3.fromRGB(255,255,0)),
                    ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0,255,0)),
                    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0,255,255)),
                    ColorSequenceKeypoint.new(0.667, Color3.fromRGB(0,0,255)),
                    ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255,0,255)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(255,0,0)),
                })})

                local hueInd = Create("Frame", {
                    Parent = hueBar,
                    Size = UDim2.new(0, 3, 1, 4), Position = UDim2.new(curH, -1, 0, -2),
                    BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 302,
                })
                Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = hueInd})
                Create("UIStroke", {Parent = hueInd, Color = Color3.new(0,0,0), Thickness = 1})

                -- SV square
                local svFrame = Create("Frame", {
                    Parent = popup,
                    Size = UDim2.new(1, -16, 0, svH), Position = UDim2.new(0, 8, 0, 26),
                    BackgroundColor3 = Color3.fromHSV(curH, 1, 1),
                    BorderSizePixel = 0, ZIndex = 301, ClipsDescendants = true,
                })
                Create("UICorner", {CornerRadius = UDim.new(0, 3), Parent = svFrame})
                Create("UIStroke", {Parent = svFrame, Color = Sentinel.Theme.Border, Thickness = 1})

                local wOL = Create("Frame", {
                    Parent = svFrame, Size = UDim2.new(1,0,1,0),
                    BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 302,
                })
                Create("UIGradient", {Parent = wOL, Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)
                })})

                local bOL = Create("Frame", {
                    Parent = svFrame, Size = UDim2.new(1,0,1,0),
                    BackgroundColor3 = Color3.new(0,0,0), BorderSizePixel = 0, ZIndex = 303,
                })
                Create("UIGradient", {Parent = bOL, Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0)
                }), Rotation = 90})

                local svCursor = Create("Frame", {
                    Parent = svFrame,
                    Size = UDim2.new(0, 8, 0, 8),
                    Position = UDim2.new(curS, -4, 1-curV, -4),
                    BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 305,
                })
                Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = svCursor})
                Create("UIStroke", {Parent = svCursor, Color = Color3.new(0,0,0), Thickness = 1})

                -- Alpha bar
                local alphaY = 26 + svH + 6
                local alphaBar = Create("Frame", {
                    Parent = popup,
                    Size = UDim2.new(1, -16, 0, 10), Position = UDim2.new(0, 8, 0, alphaY),
                    BackgroundColor3 = curColor, BorderSizePixel = 0, ZIndex = 301,
                })
                Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = alphaBar})
                Create("UIStroke", {Parent = alphaBar, Color = Sentinel.Theme.Border, Thickness = 1})
                Create("UIGradient", {Parent = alphaBar, Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.9)
                })})

                local alphaInd = Create("Frame", {
                    Parent = alphaBar,
                    Size = UDim2.new(0, 3, 1, 4), Position = UDim2.new(1-curAlpha, -1, 0, -2),
                    BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 302,
                })
                Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = alphaInd})
                Create("UIStroke", {Parent = alphaInd, Color = Color3.new(0,0,0), Thickness = 1})

                -- Preview + Hex
                local prevY = alphaY + 16
                local bigPrev = Create("Frame", {
                    Parent = popup,
                    Size = UDim2.new(0, 18, 0, 18), Position = UDim2.new(0, 8, 0, prevY),
                    BackgroundColor3 = curColor, BorderSizePixel = 0, ZIndex = 302,
                })
                Create("UICorner", {CornerRadius = UDim.new(0, 3), Parent = bigPrev})
                Create("UIStroke", {Parent = bigPrev, Color = Sentinel.Theme.Border, Thickness = 1})

                local hexLbl = Create("TextLabel", {
                    Parent = popup,
                    Size = UDim2.new(1, -34, 0, 18), Position = UDim2.new(0, 32, 0, prevY),
                    BackgroundTransparency = 1,
                    Text = string.format("#%02X%02X%02X", curColor.R*255, curColor.G*255, curColor.B*255),
                    TextColor3 = Sentinel.Theme.SubText, TextSize = 10,
                    Font = Enum.Font.Code, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 302,
                })

                local function updateColor()
                    curColor = Color3.fromHSV(curH, curS, curV)
                    preview.BackgroundColor3 = curColor
                    bigPrev.BackgroundColor3 = curColor
                    svFrame.BackgroundColor3 = Color3.fromHSV(curH, 1, 1)
                    alphaBar.BackgroundColor3 = curColor
                    hexLbl.Text = string.format("#%02X%02X%02X  A:%.0f%%", curColor.R*255, curColor.G*255, curColor.B*255, curAlpha*100)
                    hueInd.Position = UDim2.new(curH, -1, 0, -2)
                    svCursor.Position = UDim2.new(curS, -4, 1-curV, -4)
                    alphaInd.Position = UDim2.new(1-curAlpha, -1, 0, -2)
                    Sentinel.Flags[flag] = curColor
                    if cfg.Callback then cfg.Callback(curColor, curAlpha) end
                end

                local huePick, svPick, alphaPick = false, false, false

                local hB = Create("TextButton", {Parent = hueBar, Size = UDim2.new(1,0,1,8), Position = UDim2.new(0,0,0,-4),
                    BackgroundTransparency = 1, Text = "", ZIndex = 304, AutoButtonColor = false})
                hB.InputBegan:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        huePick = true
                        curH = math.clamp((i.Position.X - hueBar.AbsolutePosition.X)/hueBar.AbsoluteSize.X, 0, 0.999)
                        updateColor()
                    end
                end)

                local sB = Create("TextButton", {Parent = svFrame, Size = UDim2.new(1,0,1,0),
                    BackgroundTransparency = 1, Text = "", ZIndex = 304, AutoButtonColor = false})
                sB.InputBegan:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        svPick = true
                        curS = math.clamp((i.Position.X - svFrame.AbsolutePosition.X)/svFrame.AbsoluteSize.X, 0, 1)
                        curV = 1 - math.clamp((i.Position.Y - svFrame.AbsolutePosition.Y)/svFrame.AbsoluteSize.Y, 0, 1)
                        updateColor()
                    end
                end)

                local aB = Create("TextButton", {Parent = alphaBar, Size = UDim2.new(1,0,1,8), Position = UDim2.new(0,0,0,-4),
                    BackgroundTransparency = 1, Text = "", ZIndex = 304, AutoButtonColor = false})
                aB.InputBegan:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        alphaPick = true
                        curAlpha = 1 - math.clamp((i.Position.X - alphaBar.AbsolutePosition.X)/alphaBar.AbsoluteSize.X, 0, 1)
                        updateColor()
                    end
                end)

                AddConn(UserInputService.InputChanged:Connect(function(i)
                    if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
                    if huePick then
                        curH = math.clamp((i.Position.X - hueBar.AbsolutePosition.X)/hueBar.AbsoluteSize.X, 0, 0.999)
                        updateColor()
                    end
                    if svPick then
                        curS = math.clamp((i.Position.X - svFrame.AbsolutePosition.X)/svFrame.AbsoluteSize.X, 0, 1)
                        curV = 1 - math.clamp((i.Position.Y - svFrame.AbsolutePosition.Y)/svFrame.AbsoluteSize.Y, 0, 1)
                        updateColor()
                    end
                    if alphaPick then
                        curAlpha = 1 - math.clamp((i.Position.X - alphaBar.AbsolutePosition.X)/alphaBar.AbsoluteSize.X, 0, 1)
                        updateColor()
                    end
                end))

                AddConn(UserInputService.InputEnded:Connect(function(i)
                    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                        huePick = false; svPick = false; alphaPick = false
                    end
                end))

                local function closePopup()
                    if not isOpen then return end
                    isOpen = false
                    Tween(popup, {Size = UDim2.new(0, 200, 0, 0)}, 0.12, Enum.EasingStyle.Quart)
                    task.delay(0.12, function() popup.Visible = false end)
                    -- Remove from open popups
                    for i, p in ipairs(Sentinel._openPopups) do
                        if p.frame == popup then table.remove(Sentinel._openPopups, i) break end
                    end
                end

                preview.MouseButton1Click:Connect(function()
                    if isOpen then
                        closePopup()
                    else
                        -- Close other popups first
                        Sentinel:CloseAllPopups()
                        isOpen = true
                        local s = UIScaleObj.Scale
                        local pPos = preview.AbsolutePosition
                        local pSz = preview.AbsoluteSize
                        popup.Position = UDim2.new(0, (pPos.X + pSz.X - 200)/s, 0, (pPos.Y + pSz.Y + 4)/s)
                        popup.Visible = true
                        Tween(popup, {Size = UDim2.new(0, 200, 0, popupH)}, 0.15, Enum.EasingStyle.Quart)
                        -- Register for click-outside-to-close
                        table.insert(Sentinel._openPopups, {frame = popup, preview = preview, close = closePopup})
                    end
                end)

                Sentinel.FlagSetters[flag] = function(v)
                    curH, curS, curV = Color3.toHSV(v)
                    curColor = v; updateColor()
                end

                local CP = {}
                function CP:Set(c, a)
                    curColor = c; if a then curAlpha = a end
                    curH, curS, curV = Color3.toHSV(c); updateColor()
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
    -- SETTINGS TAB (WITH CONFIGS)
    -- ═══════════════════════════════════════

    function Window:CreateSettingsTab()
        local st = self:CreateTab({Name = "Settings"})

        -- GUI Settings
        local guiSec = st:CreateSection({Name = "GUI Settings", Side = "Left"})

        local fNames = {}
        for n in pairs(Sentinel.FontMap) do table.insert(fNames, n) end
        table.sort(fNames)

        guiSec:CreateDropdown({
            Name = "Font", Options = fNames, Default = "Gotham", Flag = "gui_font",
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
            Callback = function(c) Sentinel:SetAccent(c) end,
        })

        -- Keybinds
        local bindSec = st:CreateSection({Name = "Keybinds", Side = "Right"})
        bindSec:CreateKeybind({
            Name = "Toggle GUI", Default = Sentinel.ToggleKey, Flag = "gui_toggle_key",
            Callback = function(k) Sentinel.ToggleKey = k end,
        })

        -- Config System
        local cfgSec = st:CreateSection({Name = "Configs", Side = "Right"})

        local cfgNameBox = cfgSec:CreateTextbox({
            Name = "Config Name", Placeholder = "my_config", Flag = "cfg_name",
        })

        local cfgList = cfgSec:CreateDropdown({
            Name = "Configs", Options = Sentinel:GetConfigs(),
            Default = "", Flag = "cfg_selected",
        })

        cfgSec:CreateButton({
            Name = "Save Config",
            Callback = function()
                local name = Sentinel:GetFlag("cfg_name")
                if name and name ~= "" then
                    Sentinel:SaveConfig(name)
                    cfgList:Refresh(Sentinel:GetConfigs())
                    Sentinel:Notify("Config", "Saved: " .. name, 2)
                else
                    Sentinel:Notify("Config", "Enter a config name!", 2)
                end
            end,
        })

        cfgSec:CreateButton({
            Name = "Load Config",
            Callback = function()
                local name = Sentinel:GetFlag("cfg_selected")
                if name and name ~= "" then
                    Sentinel:LoadConfig(name)
                    Sentinel:Notify("Config", "Loaded: " .. name, 2)
                else
                    Sentinel:Notify("Config", "Select a config first!", 2)
                end
            end,
        })

        cfgSec:CreateButton({
            Name = "Delete Config",
            Callback = function()
                local name = Sentinel:GetFlag("cfg_selected")
                if name and name ~= "" then
                    Sentinel:DeleteConfig(name)
                    cfgList:Refresh(Sentinel:GetConfigs())
                    Sentinel:Notify("Config", "Deleted: " .. name, 2)
                else
                    Sentinel:Notify("Config", "Select a config first!", 2)
                end
            end,
        })

        cfgSec:CreateButton({
            Name = "Refresh List",
            Callback = function()
                cfgList:Refresh(Sentinel:GetConfigs())
                Sentinel:Notify("Config", "Refreshed", 2)
            end,
        })

        -- Info
        local infoSec = st:CreateSection({Name = "Information", Side = "Left"})
        infoSec:CreateLabel({Text = "SENTINEL v" .. Sentinel.Version})
        infoSec:CreateLabel({Text = "GameSense Style UI"})
        infoSec:CreateSeparator()
        infoSec:CreateLabel({Text = "Right-click to bind keys"})
        infoSec:CreateButton({Name = "Destroy GUI", Callback = function() Sentinel:Destroy() end})

        return st
    end

    -- Mobile button
    if IsMobile then
        local mb = Create("TextButton", {
            Parent = ScreenGui,
            Size = UDim2.new(0, 42, 0, 42), Position = UDim2.new(0, 10, 0, 10),
            BackgroundColor3 = Sentinel.Theme.Primary, Text = "S",
            TextColor3 = Sentinel.Theme.Accent, TextSize = 18,
            Font = Enum.Font.GothamBold, ZIndex = 1000, AutoButtonColor = false,
        })
        Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = mb})
        Create("UIStroke", {Parent = mb, Color = Sentinel.Theme.Accent, Thickness = 2})

        local mbD, mbDS, mbSP
        mb.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch then mbD = true; mbDS = i.Position; mbSP = mb.Position end
        end)
        mb.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch then
                if mbD and (i.Position - mbDS).Magnitude < 10 then Sentinel:Toggle() end
                mbD = false
            end
        end)
        AddConn(UserInputService.InputChanged:Connect(function(i)
            if mbD and i.UserInputType == Enum.UserInputType.Touch then
                local d = i.Position - mbDS
                mb.Position = UDim2.new(mbSP.X.Scale, mbSP.X.Offset+d.X, mbSP.Y.Scale, mbSP.Y.Offset+d.Y)
            end
        end))
        AddConn(RunService.Heartbeat:Connect(function()
            if Sentinel.RGBEnabled then
                local c = Color3.fromHSV((tick()*Sentinel.RGBSpeed)%1, 0.65, 1)
                local s = mb:FindFirstChildOfClass("UIStroke"); if s then s.Color = c end
                mb.TextColor3 = c
            end
        end))
    end

    table.insert(self.Windows, Window)
    return Window
end

-- ═══════════════════════════════════════
-- GLOBAL
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
    self:CloseAllPopups()
    for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
    self.Connections = {}
    if ScreenGui then ScreenGui:Destroy() end
    self.Windows = {}; self.Flags = {}; self.Binds = {}
    self.AllTextLabels = {}; self._accentCbs = {}; self._openPopups = {}
end

return Sentinel
