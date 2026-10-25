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
    TargetPart = "Head", -- "Head" or "HumanoidRootPart"
    RaycastMethod = "Raycast", -- "Raycast", "FindPartOnRay", "FindPartOnRayWithIgnoreList", "FindPartOnRayWithWhitelist", "Mouse.Hit/Target"
    ShowFOV = true,
    FOVRadius = 120
}

-- Visual FOV circle
local fovCircle = Drawing.new("Circle")
fovCircle.Thickness = 1
fovCircle.NumSides = 64
fovCircle.Radius = Configuration.FOVRadius
fovCircle.Filled = false
fovCircle.Visible = Configuration.ShowFOV and Configuration.Enabled
fovCircle.Transparency = 1
fovCircle.Color = Color3.fromRGB(255, 255, 255)

RunService.RenderStepped:Connect(function()
    fovCircle.Visible = Configuration.ShowFOV and Configuration.Enabled
    fovCircle.Radius = Configuration.FOVRadius
    fovCircle.Position = GetMouseLocation(UserInputService)
end)

-- Target selection
local function getClosestTargetPart()
    local mousePos = GetMouseLocation(UserInputService)
    local closestDistance = Configuration.FOVRadius
    local selectedPart = nil

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
            local targetPart = player.Character:FindFirstChild(Configuration.TargetPart)

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

-- Linoria UI Library Integration
local repo = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()

local Window = Library:CreateWindow({
    Title = "Universal Silent Aim",
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local Tabs = {
    Main = Window:AddTab("Main")
}

local LeftGroup = Tabs.Main:AddLeftGroupbox("Targeting")

LeftGroup:AddToggle("SilentAimEnabled", {
    Text = "Enabled",
    Default = Configuration.Enabled,
    Tooltip = "Toggles universal silent aim",
    Callback = function(Value)
        Configuration.Enabled = Value
    end
}):AddKeyPicker("SilentAimKeyPicker", {
    Default = "RightAlt",
    SyncToggleState = true,
    Mode = "Toggle",
    Text = "Silent Aim",
    NoUI = false
})

LeftGroup:AddDropdown("TargetPartDropdown", {
    Values = {"Head", "HumanoidRootPart"},
    Default = 1,
    Multi = false,
    Text = "Target Part",
    Tooltip = "Body part to redirect rays toward",
    Callback = function(Value)
        Configuration.TargetPart = Value
    end
})

LeftGroup:AddDropdown("RaycastMethodDropdown", {
    Values = {"Raycast", "FindPartOnRay", "FindPartOnRayWithIgnoreList", "FindPartOnRayWithWhitelist", "Mouse.Hit/Target"},
    Default = 1,
    Multi = false,
    Text = "Raycast Method",
    Tooltip = "Engine raycast/query method to intercept",
    Callback = function(Value)
        Configuration.RaycastMethod = Value
    end
})

local RightGroup = Tabs.Main:AddRightGroupbox("Visuals")

RightGroup:AddToggle("ShowFOVToggle", {
    Text = "Show FOV Circle",
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

RightGroup:AddSlider("FOVRadiusSlider", {
    Text = "FOV Radius",
    Default = Configuration.FOVRadius,
    Min = 10,
    Max = 600,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        Configuration.FOVRadius = Value
    end
})

Library:Notify("Universal Silent Aim loaded successfully.")
