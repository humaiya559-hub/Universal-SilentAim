-- universal_silent_aim.lua
-- concise universal indirect targeting module for roblox (luau) with linoria ui

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

local WorldToViewportPoint = Camera.WorldToViewportPoint
local GetMouseLocation = UserInputService.GetMouseLocation

-- Configuration
local Configuration = {
    Enabled = true,
    BulletPenetration = false,
    TeamCheck = false,
    TargetPart = "Head", -- "Head", "HumanoidRootPart", or "Random"
    RaycastMethod = "Automatic", -- "Automatic", "Raycast", "FindPartOnRay", "FindPartOnRayWithIgnoreList", "FindPartOnRayWithWhitelist", "Mouse"
    Include = { Character = true, Camera = true },
    Origin = { Camera = true },
    ShowFOV = true,
    FOVRadius = 120,
    ShowTracer = false
}

local function normalizeSelection(selection)
    if not selection then
        return {}
    end

    local normalized = {}

    if type(selection) ~= "table" then
        normalized[selection] = true
        return normalized
    end

    local hasNumericKeys = false
    for key in pairs(selection) do
        if type(key) == "number" then
            hasNumericKeys = true
            break
        end
    end

    if hasNumericKeys then
        for _, value in ipairs(selection) do
            normalized[value] = true
        end
    else
        for key, value in pairs(selection) do
            if type(key) == "string" then
                if value == true or type(value) == "string" then
                    normalized[key] = true
                end
            end
        end
    end

    return normalized
end

local function isSelectionActive(selection, option)
    return selection and selection[option] or false
end

Configuration.Include = normalizeSelection(Configuration.Include)
Configuration.Origin = normalizeSelection(Configuration.Origin)

local uiLoaded = false

-- Visual FOV circle using Drawing API
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1
fovCircle.NumSides = 64
fovCircle.Radius = Configuration.FOVRadius
fovCircle.Filled = false
fovCircle.Visible = false
fovCircle.Transparency = 1
fovCircle.Color = Color3.fromRGB(255, 255, 255)

-- Visual Tracer line using Drawing API
local tracerLine = Drawing.new("Line")
tracerLine.Thickness = 1
tracerLine.Visible = false
tracerLine.Transparency = 1
tracerLine.Color = Color3.fromRGB(255, 255, 255)

-- Target selection: locates valid target part closest to screen cursor within FOV radius
local function getClosestTargetPart()
    local mousePos = GetMouseLocation(UserInputService)
    local closestDistance = Configuration.FOVRadius
    local selectedPart = nil

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            if Configuration.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
                continue
            end

            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            local partName = Configuration.TargetPart
            if partName == "Random" then
                local validParts = {"Head", "HumanoidRootPart"}
                partName = validParts[math.random(1, #validParts)]
            end
            local targetPart = player.Character:FindFirstChild(partName)

            if humanoid and humanoid.Health > 0 and targetPart then
                local screenPoint, onScreen = WorldToViewportPoint(Camera, targetPart.Position)
                if onScreen then
                    local distance = (Vector2.new(screenPoint.X, screenPoint.Y) - mousePos).Magnitude
                    if distance <= closestDistance then
                        closestDistance = distance
                        selectedPart = targetPart
                    end
                end
            end
        end
    end

    return selectedPart
end

-- Update visuals per frame
RunService.RenderStepped:Connect(function()
    if not uiLoaded then
        fovCircle.Visible = false
        tracerLine.Visible = false
        return
    end

    local mousePos = GetMouseLocation(UserInputService)
    
    -- FOV circle update
    fovCircle.Visible = Configuration.ShowFOV and Configuration.Enabled
    fovCircle.Radius = Configuration.FOVRadius
    fovCircle.Position = mousePos

    -- Tracer line update
    if Configuration.ShowTracer and Configuration.Enabled then
        local target = getClosestTargetPart()
        if target then
            local screenPoint, onScreen = WorldToViewportPoint(Camera, target.Position)
            if onScreen then
                tracerLine.Visible = true
                tracerLine.From = mousePos
                tracerLine.To = Vector2.new(screenPoint.X, screenPoint.Y)
            else
                tracerLine.Visible = false
            end
        else
            tracerLine.Visible = false
        end
    else
        tracerLine.Visible = false
    end
end)

local function getIgnoredList(method, args)
    if method == "Raycast" then
        local params = args[3]
        if typeof(params) == "RaycastParams" then
            return params.FilterDescendantsInstances
        end
    elseif method == "FindPartOnRayWithIgnoreList" then
        return args[2]
    end
    return nil
end

local function getOriginalOrigin(method, args)
    if method == "Raycast" then
        if typeof(args[1]) == "Vector3" then
            return args[1]
        end
    elseif method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist" or method == "FindPartOnRay" or method == "findPartOnRay" then
        local ray = args[1]
        if typeof(ray) == "Ray" then
            return ray.Origin
        end
    end
    return nil
end

-- Metamethod Hook: __namecall
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if Configuration.Enabled and self == workspace and not checkcaller() then
        local originOptions = Configuration.Origin
        local includeOptions = Configuration.Include
        local originalOrigin = getOriginalOrigin(method, args)
        local ignoredList = getIgnoredList(method, args)

        if originalOrigin and originOptions and next(originOptions) then
            local matchesOrigin = false
            if isSelectionActive(originOptions, "Camera") then
                local camPos = Camera.CFrame.Position
                if (originalOrigin - camPos).Magnitude < 0.1 or originalOrigin == camPos then
                    matchesOrigin = true
                end
            end
            if not matchesOrigin then
                setnamecallmethod(method)
                return oldNamecall(self, ...)
            end
        end

        if ignoredList and includeOptions and next(includeOptions) then
            if isSelectionActive(includeOptions, "Camera") and not table.find(ignoredList, Camera) then
                setnamecallmethod(method)
                return oldNamecall(self, ...)
            end
            local character = LocalPlayer.Character
            if character and isSelectionActive(includeOptions, "Character") and not table.find(ignoredList, character) then
                setnamecallmethod(method)
                return oldNamecall(self, ...)
            end
        end
        local isAuto = Configuration.RaycastMethod == "Automatic"
        if (isAuto or Configuration.RaycastMethod == "Raycast") and method == "Raycast" then
            local origin = args[1]
            if typeof(origin) == "Vector3" then
                local target = getClosestTargetPart()
                if target then
                    if Configuration.BulletPenetration then
                        local dir = (target.Position - origin).Unit
                        args[1] = target.Position - (dir * 0.2)
                        args[2] = dir * 10
                    else
                        args[2] = (target.Position - origin).Unit * 1000
                    end
                    setnamecallmethod(method)
                    return oldNamecall(self, unpack(args))
                end
            end
        elseif (isAuto or Configuration.RaycastMethod == method) and (method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist") then
            local ray = args[1]
            if typeof(ray) == "Ray" then
                local target = getClosestTargetPart()
                if target then
                    if Configuration.BulletPenetration then
                        local dir = (target.Position - ray.Origin).Unit
                        args[1] = Ray.new(target.Position - (dir * 0.2), dir * 10)
                    else
                        args[1] = Ray.new(ray.Origin, (target.Position - ray.Origin).Unit * 1000)
                    end
                    setnamecallmethod(method)
                    return oldNamecall(self, unpack(args))
                end
            end
        end
    end

    setnamecallmethod(method)
    return oldNamecall(self, ...)
end))

-- Metamethod Hook: __index
local oldIndex
oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, index)
    local isAuto = Configuration.RaycastMethod == "Automatic"
    if Configuration.Enabled and not checkcaller() and (isAuto or Configuration.RaycastMethod == "Mouse") and self == Mouse then
        local target = getClosestTargetPart()
        if target then
            if index == "Hit" or index == "hit" then
                return target.CFrame
            elseif index == "Target" or index == "target" then
                return target
            elseif index == "UnitRay" then
                return Ray.new(self.Origin, (target.Position - self.Origin).Unit)
            end
        end
    end

    return oldIndex(self, index)
end))

-- Linoria UI Library Integration (hosted in repository)
local libSource = game:HttpGet("https://raw.githubusercontent.com/humaiya559-hub/Universal-SilentAim/main/Library.lua")
if string.byte(libSource, 1) == 239 and string.byte(libSource, 2) == 187 and string.byte(libSource, 3) == 191 then
    libSource = string.sub(libSource, 4)
end
local Library = loadstring(libSource)()

local Window = Library:CreateWindow({
    Title = "Universal Silent Aim",
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local Tabs = {
    Main = Window:AddTab("Main"),
    Settings = Window:AddTab("Settings")
}

-- Silent Tabbox (with Silent and Checks subtabs)
local SilentTabbox = Tabs.Main:AddLeftTabbox("Silent")
local SilentGroup = SilentTabbox:AddTab("Silent")
local ChecksGroup = SilentTabbox:AddTab("Checks")

-- Silent Subtab elements
SilentGroup:AddToggle("SilentAimEnabled", {
    Text = "Enabled",
    Default = Configuration.Enabled,
    Tooltip = "Toggles universal silent aim",
    Callback = function(Value)
        Configuration.Enabled = Value
    end
}):AddKeyPicker("SilentAimKeyPicker", {
    Default = "RightAlt",
    SyncToggleState = true,
    Modes = {"Always", "Toggle", "Hold"},
    Mode = "Toggle",
    Text = "Silent Aim",
    NoUI = false
})

SilentGroup:AddToggle("BulletPenetrationEnabled", {
    Text = "Bullet Penetration",
    Default = Configuration.BulletPenetration,
    Tooltip = "Allows projectiles to penetrate structures and reach targets directly",
    Callback = function(Value)
        Configuration.BulletPenetration = Value
    end
})

SilentGroup:AddDropdown("TargetPartDropdown", {
    Values = {"Head", "HumanoidRootPart", "Random"},
    Default = 1,
    Multi = false,
    Text = "Target Part",
    Tooltip = "Body part to redirect rays toward",
    Callback = function(Value)
        Configuration.TargetPart = Value
    end
})

SilentGroup:AddDropdown("RaycastMethodDropdown", {
    Values = {"Automatic", "Raycast", "FindPartOnRay", "FindPartOnRayWithIgnoreList", "FindPartOnRayWithWhitelist", "Mouse"},
    Default = 1,
    Multi = false,
    Text = "Raycast Method",
    Tooltip = "Engine raycast/query method to intercept",
    Callback = function(Value)
        Configuration.RaycastMethod = Value
    end
})

SilentGroup:AddDropdown("IncludeDropdown", {
    AllowNull = true,
    Multi = true,
    Text = "Include",
    Default = Configuration.Include,
    Values = {"Camera", "Character"},
    Tooltip = "Includes these objects in the ignore list",
    Callback = function(Value)
        Configuration.Include = normalizeSelection(Value)
    end
})

SilentGroup:AddDropdown("OriginDropdown", {
    AllowNull = true,
    Multi = true,
    Text = "Origin",
    Default = Configuration.Origin,
    Values = {"Camera"},
    Tooltip = "Sets the origin of the bullet/ray",
    Callback = function(Value)
        Configuration.Origin = normalizeSelection(Value)
    end
})

-- Checks Subtab elements
ChecksGroup:AddToggle("TeamCheckToggle", {
    Text = "Team Check",
    Default = Configuration.TeamCheck,
    Tooltip = "Prevents targeting teammates",
    Callback = function(Value)
        Configuration.TeamCheck = Value
    end
})

-- Field of View Groupbox
local FOVGroup = Tabs.Main:AddRightGroupbox("Field of View")

FOVGroup:AddToggle("ShowFOVToggle", {
    Text = "Show FOV",
    Default = Configuration.ShowFOV,
    Tooltip = "Renders the visual FOV radius indicator",
    Callback = function(Value)
        Configuration.ShowFOV = Value
    end
}):AddColorPicker("FOVColorPicker", {
    Default = Color3.fromRGB(255, 255, 255),
    Title = "FOV Color",
    Callback = function(Value)
        fovCircle.Color = Value
    end
})

FOVGroup:AddSlider("FOVRadiusSlider", {
    Text = "Radius",
    Default = Configuration.FOVRadius,
    Min = 10,
    Max = 600,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        Configuration.FOVRadius = Value
    end
})

FOVGroup:AddToggle("ShowTracerToggle", {
    Text = "Show Tracer On Target",
    Default = Configuration.ShowTracer,
    Tooltip = "Renders a tracer line from mouse cursor to the current target",
    Callback = function(Value)
        Configuration.ShowTracer = Value
    end
}):AddColorPicker("TracerColorPicker", {
    Default = Color3.fromRGB(255, 255, 255),
    Title = "Tracer Color",
    Callback = function(Value)
        tracerLine.Color = Value
    end
})

-- Settings Tab
local MenuBox = Tabs.Settings:AddLeftGroupbox("Menu")

MenuBox:AddButton("Unload", function()
    uiLoaded = false
    pcall(function() fovCircle:Remove() end)
    pcall(function() tracerLine:Remove() end)
    Library:Unload()
end)

MenuBox:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift",
    NoUI = true,
    Text = "Menu keybind"
})
Library.ToggleKeybind = Options.MenuKeybind

uiLoaded = true
if Configuration.ShowFOV and Configuration.Enabled then
    fovCircle.Visible = true
end

Library:Notify("Universal Silent Aim loaded successfully.")
