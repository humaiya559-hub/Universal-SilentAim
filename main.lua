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
    TargetPart = "Head", -- "Head", "HumanoidRootPart", or "Random"
    RaycastMethod = "Raycast", -- "Raycast", "FindPartOnRay", "FindPartOnRayWithIgnoreList", "FindPartOnRayWithWhitelist", "Mouse.Hit/Target"
    ShowFOV = true,
    FOVRadius = 120,
    ShowTracer = false
}

-- Visual FOV circle using Drawing API
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1
fovCircle.NumSides = 64
fovCircle.Radius = Configuration.FOVRadius
fovCircle.Filled = false
fovCircle.Visible = Configuration.ShowFOV and Configuration.Enabled
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

-- Metamethod Hook: __namecall
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if Configuration.Enabled and self == workspace and not checkcaller() then
        if method == "Raycast" and Configuration.RaycastMethod == "Raycast" then
            local origin = args[1]
            if typeof(origin) == "Vector3" then
                local target = getClosestTargetPart()
                if target then
                    args[2] = (target.Position - origin).Unit * 1000
                    setnamecallmethod(method)
                    return oldNamecall(self, unpack(args))
                end
            end
        elseif (method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist") and Configuration.RaycastMethod == method then
            local ray = args[1]
            if typeof(ray) == "Ray" then
                local target = getClosestTargetPart()
                if target then
                    args[1] = Ray.new(ray.Origin, (target.Position - ray.Origin).Unit * 1000)
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
    if Configuration.Enabled and not checkcaller() and Configuration.RaycastMethod == "Mouse.Hit/Target" and self == Mouse then
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
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/humaiya559-hub/Universal-SilentAim/main/Library.lua"))()

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

-- Silent Groupbox
local SilentGroup = Tabs.Main:AddLeftGroupbox("Silent")

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
    Values = {"Raycast", "FindPartOnRay", "FindPartOnRayWithIgnoreList", "FindPartOnRayWithWhitelist", "Mouse.Hit/Target"},
    Default = 1,
    Multi = false,
    Text = "Raycast Method",
    Tooltip = "Engine raycast/query method to intercept",
    Callback = function(Value)
        Configuration.RaycastMethod = Value
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

Library:Notify("Universal Silent Aim loaded successfully.")
