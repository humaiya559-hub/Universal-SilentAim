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
    RaycastMethod = "Automatic", -- "Automatic", "Raycast", "Spherecast", "Blockcast", "FindPartOnRay", "FindPartOnRayWithIgnoreList", "FindPartOnRayWithWhitelist", "FindPartOnRayWithCollisionGroup", "ViewportPointToRay", "ScreenPointToRay", "Mouse"
    Include = { Character = true },
    Origin = { Camera = true, Character = true },
    ShowFOV = true,
    FOVRadius = 120,
    ShowTracer = false
}

-- Visuals Configuration
local VisualConfig = {
    Enabled = false,
    TeamCheck = false,
    MaxDistance = 2000,
    Boxes = true,
    BoxStyle = "2D Box", -- "2D Box", "Corner Box"
    BoxColor = Color3.fromRGB(255, 255, 255),
    Names = true,
    NameColor = Color3.fromRGB(255, 255, 255),
    UseDisplayName = false,
    Distance = true,
    DistanceColor = Color3.fromRGB(200, 200, 200),
    HealthBar = true,
    DynamicHealth = true,
    HealthBarColor = Color3.fromRGB(0, 255, 120),
    HealthText = false
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

-- ESP Drawings Container
local espObjects = {}
local playerConnections = {}

local fontUI = 2
if Drawing and Drawing.Fonts and Drawing.Fonts.UI then
    fontUI = Drawing.Fonts.UI
end

local function createEsp(player)
    if player == LocalPlayer or espObjects[player] then return end

    local drawings = {
        -- 2D Box (outer outline, colored core, inner inline)
        BoxOutline = Drawing.new("Square"),
        Box = Drawing.new("Square"),
        BoxInline = Drawing.new("Square"),

        -- Corner Box (8 black outline lines, 8 colored foreground lines)
        CornerOutlines = {},
        CornerLines = {},

        -- Health bar
        HealthOutline = Drawing.new("Square"),
        HealthBg = Drawing.new("Square"),
        HealthBar = Drawing.new("Square"),
        HealthText = Drawing.new("Text"),

        -- Text labels
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text")
    }

    -- 2D Box configuration
    drawings.BoxOutline.Thickness = 1
    drawings.BoxOutline.Filled = false
    drawings.BoxOutline.Color = Color3.fromRGB(0, 0, 0)
    drawings.BoxOutline.Visible = false
    drawings.BoxOutline.ZIndex = 1

    drawings.Box.Thickness = 1
    drawings.Box.Filled = false
    drawings.Box.Color = VisualConfig.BoxColor
    drawings.Box.Visible = false
    drawings.Box.ZIndex = 2

    drawings.BoxInline.Thickness = 1
    drawings.BoxInline.Filled = false
    drawings.BoxInline.Color = Color3.fromRGB(0, 0, 0)
    drawings.BoxInline.Visible = false
    drawings.BoxInline.ZIndex = 1

    -- Corner Box configuration
    for i = 1, 8 do
        local outLine = Drawing.new("Line")
        outLine.Thickness = 3
        outLine.Color = Color3.fromRGB(0, 0, 0)
        outLine.Visible = false
        outLine.ZIndex = 1
        drawings.CornerOutlines[i] = outLine

        local inLine = Drawing.new("Line")
        inLine.Thickness = 1
        inLine.Color = VisualConfig.BoxColor
        inLine.Visible = false
        inLine.ZIndex = 2
        drawings.CornerLines[i] = inLine
    end

    -- Health bar configuration
    drawings.HealthOutline.Thickness = 1
    drawings.HealthOutline.Filled = true
    drawings.HealthOutline.Color = Color3.fromRGB(0, 0, 0)
    drawings.HealthOutline.Visible = false
    drawings.HealthOutline.ZIndex = 1

    drawings.HealthBg.Thickness = 1
    drawings.HealthBg.Filled = true
    drawings.HealthBg.Color = Color3.fromRGB(35, 35, 35)
    drawings.HealthBg.Visible = false
    drawings.HealthBg.ZIndex = 2

    drawings.HealthBar.Thickness = 1
    drawings.HealthBar.Filled = true
    drawings.HealthBar.Color = VisualConfig.HealthBarColor
    drawings.HealthBar.Visible = false
    drawings.HealthBar.ZIndex = 3

    drawings.HealthText.Size = 11
    drawings.HealthText.Font = fontUI
    drawings.HealthText.Center = true
    drawings.HealthText.Outline = true
    drawings.HealthText.OutlineColor = Color3.fromRGB(0, 0, 0)
    drawings.HealthText.Color = Color3.fromRGB(255, 255, 255)
    drawings.HealthText.Visible = false
    drawings.HealthText.ZIndex = 4

    -- Name label configuration
    drawings.Name.Size = 13
    drawings.Name.Font = fontUI
    drawings.Name.Center = true
    drawings.Name.Outline = true
    drawings.Name.OutlineColor = Color3.fromRGB(0, 0, 0)
    drawings.Name.Color = VisualConfig.NameColor
    drawings.Name.Visible = false
    drawings.Name.ZIndex = 4

    -- Distance label configuration
    drawings.Distance.Size = 11
    drawings.Distance.Font = fontUI
    drawings.Distance.Center = true
    drawings.Distance.Outline = true
    drawings.Distance.OutlineColor = Color3.fromRGB(0, 0, 0)
    drawings.Distance.Color = VisualConfig.DistanceColor
    drawings.Distance.Visible = false
    drawings.Distance.ZIndex = 4

    espObjects[player] = drawings
end

local function removeEsp(player)
    local drawings = espObjects[player]
    if drawings then
        pcall(function()
            drawings.BoxOutline:Remove()
            drawings.Box:Remove()
            drawings.BoxInline:Remove()
            for i = 1, 8 do
                drawings.CornerOutlines[i]:Remove()
                drawings.CornerLines[i]:Remove()
            end
            drawings.HealthOutline:Remove()
            drawings.HealthBg:Remove()
            drawings.HealthBar:Remove()
            drawings.HealthText:Remove()
            drawings.Name:Remove()
            drawings.Distance:Remove()
        end)
        espObjects[player] = nil
    end
end

local function setEspVisible(drawings, state)
    drawings.BoxOutline.Visible = state
    drawings.Box.Visible = state
    drawings.BoxInline.Visible = state
    for i = 1, 8 do
        drawings.CornerOutlines[i].Visible = state
        drawings.CornerLines[i].Visible = state
    end
    drawings.HealthOutline.Visible = state
    drawings.HealthBg.Visible = state
    drawings.HealthBar.Visible = state
    drawings.HealthText.Visible = state
    drawings.Name.Visible = state
    drawings.Distance.Visible = state
end

local function updateEsp()
    if not uiLoaded or not VisualConfig.Enabled then
        for _, drawings in pairs(espObjects) do
            setEspVisible(drawings, false)
        end
        return
    end

    local currentCam = workspace.CurrentCamera or Camera
    local camPos = currentCam.CFrame.Position

    for player, drawings in pairs(espObjects) do
        local character = player.Character
        if not character then
            setEspVisible(drawings, false)
            continue
        end

        if VisualConfig.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
            setEspVisible(drawings, false)
            continue
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
        local head = character:FindFirstChild("Head")

        if not humanoid or humanoid.Health <= 0 or not rootPart then
            setEspVisible(drawings, false)
            continue
        end

        local rootPos = rootPart.Position
        local distance = (camPos - rootPos).Magnitude
        if distance > VisualConfig.MaxDistance then
            setEspVisible(drawings, false)
            continue
        end

        local headPos = head and head.Position or (rootPos + Vector3.new(0, 2, 0))
        local topWorld = headPos + Vector3.new(0, (head and head.Size.Y * 0.5 or 1) + 0.5, 0)
        local bottomWorld = rootPos - Vector3.new(0, 3, 0)

        local topScreen, topOn = currentCam:WorldToViewportPoint(topWorld)
        local bottomScreen, bottomOn = currentCam:WorldToViewportPoint(bottomWorld)

        if (not topOn and not bottomOn) or topScreen.Z <= 0 then
            setEspVisible(drawings, false)
            continue
        end

        local boxHeight = math.abs(bottomScreen.Y - topScreen.Y)
        if boxHeight < 4 or boxHeight > 4000 then
            setEspVisible(drawings, false)
            continue
        end

        local boxWidth = math.clamp(math.floor(boxHeight * 0.65), 6, 2000)
        local boxX = math.floor(topScreen.X - boxWidth / 2)
        local boxY = math.floor(math.min(topScreen.Y, bottomScreen.Y))

        -- Box ESP rendering
        if VisualConfig.Boxes then
            if VisualConfig.BoxStyle == "2D Box" then
                for i = 1, 8 do
                    drawings.CornerOutlines[i].Visible = false
                    drawings.CornerLines[i].Visible = false
                end

                drawings.BoxOutline.Position = Vector2.new(boxX - 1, boxY - 1)
                drawings.BoxOutline.Size = Vector2.new(boxWidth + 2, boxHeight + 2)
                drawings.BoxOutline.Visible = true

                drawings.Box.Position = Vector2.new(boxX, boxY)
                drawings.Box.Size = Vector2.new(boxWidth, boxHeight)
                drawings.Box.Color = VisualConfig.BoxColor
                drawings.Box.Visible = true

                drawings.BoxInline.Position = Vector2.new(boxX + 1, boxY + 1)
                drawings.BoxInline.Size = Vector2.new(boxWidth - 2, boxHeight - 2)
                drawings.BoxInline.Visible = true
            elseif VisualConfig.BoxStyle == "Corner Box" then
                drawings.BoxOutline.Visible = false
                drawings.Box.Visible = false
                drawings.BoxInline.Visible = false

                local clX = math.clamp(math.floor(boxWidth / 4), 3, 20)
                local clY = math.clamp(math.floor(boxHeight / 4), 3, 20)

                local pts = {
                    {Vector2.new(boxX, boxY), Vector2.new(boxX + clX, boxY)},
                    {Vector2.new(boxX, boxY), Vector2.new(boxX, boxY + clY)},
                    {Vector2.new(boxX + boxWidth, boxY), Vector2.new(boxX + boxWidth - clX, boxY)},
                    {Vector2.new(boxX + boxWidth, boxY), Vector2.new(boxX + boxWidth, boxY + clY)},
                    {Vector2.new(boxX, boxY + boxHeight), Vector2.new(boxX + clX, boxY + boxHeight)},
                    {Vector2.new(boxX, boxY + boxHeight), Vector2.new(boxX, boxY + boxHeight - clY)},
                    {Vector2.new(boxX + boxWidth, boxY + boxHeight), Vector2.new(boxX + boxWidth - clX, boxY + boxHeight)},
                    {Vector2.new(boxX + boxWidth, boxY + boxHeight), Vector2.new(boxX + boxWidth, boxY + boxHeight - clY)}
                }

                for i = 1, 8 do
                    local outLine = drawings.CornerOutlines[i]
                    outLine.From = pts[i][1]
                    outLine.To = pts[i][2]
                    outLine.Visible = true

                    local inLine = drawings.CornerLines[i]
                    inLine.From = pts[i][1]
                    inLine.To = pts[i][2]
                    inLine.Color = VisualConfig.BoxColor
                    inLine.Visible = true
                end
            end
        else
            drawings.BoxOutline.Visible = false
            drawings.Box.Visible = false
            drawings.BoxInline.Visible = false
            for i = 1, 8 do
                drawings.CornerOutlines[i].Visible = false
                drawings.CornerLines[i].Visible = false
            end
        end

        -- Health bar rendering
        if VisualConfig.HealthBar then
            local health = math.clamp(humanoid.Health, 0, humanoid.MaxHealth)
            local maxHealth = humanoid.MaxHealth > 0 and humanoid.MaxHealth or 100
            local healthPercent = math.clamp(health / maxHealth, 0, 1)

            local barWidth = 3
            local barHeight = boxHeight
            local barX = boxX - 6
            local barY = boxY

            drawings.HealthOutline.Position = Vector2.new(barX - 1, barY - 1)
            drawings.HealthOutline.Size = Vector2.new(barWidth + 2, barHeight + 2)
            drawings.HealthOutline.Visible = true

            drawings.HealthBg.Position = Vector2.new(barX, barY)
            drawings.HealthBg.Size = Vector2.new(barWidth, barHeight)
            drawings.HealthBg.Visible = true

            local filledHeight = math.floor(barHeight * healthPercent)
            local filledY = barY + (barHeight - filledHeight)

            drawings.HealthBar.Position = Vector2.new(barX, filledY)
            drawings.HealthBar.Size = Vector2.new(barWidth, filledHeight)
            drawings.HealthBar.Visible = filledHeight > 0

            local barCol = VisualConfig.HealthBarColor
            if VisualConfig.DynamicHealth then
                if healthPercent > 0.5 then
                    barCol = Color3.fromRGB(255, 210, 0):Lerp(Color3.fromRGB(0, 255, 120), (healthPercent - 0.5) * 2)
                else
                    barCol = Color3.fromRGB(255, 50, 50):Lerp(Color3.fromRGB(255, 210, 0), healthPercent * 2)
                end
            end
            drawings.HealthBar.Color = barCol

            if VisualConfig.HealthText and healthPercent < 1 then
                drawings.HealthText.Text = tostring(math.floor(health))
                drawings.HealthText.Position = Vector2.new(barX - 14, math.clamp(filledY - 4, barY, barY + barHeight - 10))
                drawings.HealthText.Color = barCol
                drawings.HealthText.Visible = true
            else
                drawings.HealthText.Visible = false
            end
        else
            drawings.HealthOutline.Visible = false
            drawings.HealthBg.Visible = false
            drawings.HealthBar.Visible = false
            drawings.HealthText.Visible = false
        end

        -- Name label rendering
        if VisualConfig.Names then
            local displayName = VisualConfig.UseDisplayName and player.DisplayName or player.Name
            drawings.Name.Text = displayName
            drawings.Name.Position = Vector2.new(boxX + boxWidth / 2, boxY - 14)
            drawings.Name.Color = VisualConfig.NameColor
            drawings.Name.Visible = true
        else
            drawings.Name.Visible = false
        end

        -- Distance label rendering
        if VisualConfig.Distance then
            drawings.Distance.Text = string.format("[%d studs]", math.floor(distance))
            drawings.Distance.Position = Vector2.new(boxX + boxWidth / 2, boxY + boxHeight + 2)
            drawings.Distance.Color = VisualConfig.DistanceColor
            drawings.Distance.Visible = true
        else
            drawings.Distance.Visible = false
        end
    end
end

-- Initialize ESP for current players
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        createEsp(player)
    end
end

table.insert(playerConnections, Players.PlayerAdded:Connect(function(player)
    createEsp(player)
end))

table.insert(playerConnections, Players.PlayerRemoving:Connect(function(player)
    removeEsp(player)
end))

-- Target selection: locates valid target part closest to screen cursor within FOV radius
local function getClosestTargetPart()
    local mousePos = GetMouseLocation(UserInputService)
    local closestDistance = Configuration.FOVRadius
    local selectedPart = nil
    local currentCam = workspace.CurrentCamera or Camera

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
                local screenPoint, onScreen = WorldToViewportPoint(currentCam, targetPart.Position)
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
local renderSteppedConn
renderSteppedConn = RunService.RenderStepped:Connect(function()
    if not uiLoaded then
        fovCircle.Visible = false
        tracerLine.Visible = false
        for _, drawings in pairs(espObjects) do
            setEspVisible(drawings, false)
        end
        return
    end

    local mousePos = GetMouseLocation(UserInputService)
    local currentCam = workspace.CurrentCamera or Camera

    -- FOV circle update
    fovCircle.Visible = Configuration.ShowFOV and Configuration.Enabled
    fovCircle.Radius = Configuration.FOVRadius
    fovCircle.Position = mousePos

    -- Tracer line update
    if Configuration.ShowTracer and Configuration.Enabled then
        local target = getClosestTargetPart()
        if target then
            local screenPoint, onScreen = WorldToViewportPoint(currentCam, target.Position)
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

    -- Visuals ESP update
    updateEsp()
end)

-- Automatic method resolution state and helpers
local detectedMethod = nil
local lastRaycastTime = 0
local MethodStatusLabel = nil

local function setDetectedMethod(methodName)
    if detectedMethod ~= methodName then
        detectedMethod = methodName
        if MethodStatusLabel then
            pcall(function()
                MethodStatusLabel:SetText("Auto Method: " .. methodName)
            end)
        end
    end
end

-- Checks if ray origin is associated with the local player (camera, character, or equipped tool)
local function isPlayerOrigin(origin, currentCam)
    if typeof(origin) ~= "Vector3" then return false end

    local camPos = currentCam.CFrame.Position
    if (origin - camPos).Magnitude <= 15 then
        return true
    end

    local character = LocalPlayer.Character
    if character then
        local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("Head")
        if rootPart and (origin - rootPart.Position).Magnitude <= 30 then
            return true
        end
        local tool = character:FindFirstChildWhichIsA("Tool")
        if tool then
            local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart")
            if handle and (origin - handle.Position).Magnitude <= 20 then
                return true
            end
        end
    end

    return false
end

-- Filter out character ground checks (downward rays with short distance)
local function isGroundRay(origin, direction)
    if typeof(direction) == "Vector3" and direction.Magnitude < 15 and direction.Unit.Y < -0.85 then
        return true
    end
    return false
end

-- Validate Origin configuration
local function passesOriginCheck(origin, currentCam)
    local originOptions = Configuration.Origin
    if not originOptions or not next(originOptions) then
        return isPlayerOrigin(origin, currentCam)
    end

    if isSelectionActive(originOptions, "Camera") then
        local camPos = currentCam.CFrame.Position
        if (origin - camPos).Magnitude <= 15 then
            return true
        end
    end

    if isSelectionActive(originOptions, "Character") then
        local character = LocalPlayer.Character
        if character then
            local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("Head")
            if rootPart and (origin - rootPart.Position).Magnitude <= 30 then
                return true
            end
        end
    end

    return isPlayerOrigin(origin, currentCam)
end

-- Validate Include (ignore list) configuration
local function passesIncludeCheck(params, currentCam)
    local includeOptions = Configuration.Include
    if not includeOptions or not next(includeOptions) then
        return true
    end

    local filterList = nil
    local filterType = nil

    if typeof(params) == "RaycastParams" then
        filterList = params.FilterDescendantsInstances
        filterType = params.FilterType
    elseif type(params) == "table" then
        filterList = params
    end

    if not filterList or type(filterList) ~= "table" then
        return true
    end

    if filterType and filterType == Enum.RaycastFilterType.Include then
        return true
    end

    local character = LocalPlayer.Character
    if character and isSelectionActive(includeOptions, "Character") then
        local found = table.find(filterList, character)
        if not found then
            for _, item in ipairs(filterList) do
                if typeof(item) == "Instance" and (item == character or item:IsDescendantOf(character)) then
                    found = true
                    break
                end
            end
        end
        if found then
            return true
        end
    end

    if isSelectionActive(includeOptions, "Camera") and table.find(filterList, currentCam) then
        return true
    end

    return true
end

-- Metamethod Hook: __namecall
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
    local method = getnamecallmethod()

    if not Configuration.Enabled or checkcaller() then
        setnamecallmethod(method)
        return oldNamecall(self, ...)
    end

    local currentCam = workspace.CurrentCamera or Camera
    local isAuto = Configuration.RaycastMethod == "Automatic"
    local selectedMethod = Configuration.RaycastMethod

    if self == workspace then
        local args = {...}

        -- Workspace:Raycast
        if (isAuto or selectedMethod == "Raycast") and method == "Raycast" then
            local origin = args[1]
            local direction = args[2]
            local params = args[3]

            if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
                if not isGroundRay(origin, direction) and passesOriginCheck(origin, currentCam) and passesIncludeCheck(params, currentCam) then
                    lastRaycastTime = os.clock()
                    if isAuto then
                        setDetectedMethod("Raycast")
                    end

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
            end

        -- Workspace:Spherecast
        elseif (isAuto or selectedMethod == "Spherecast") and method == "Spherecast" then
            local origin = args[1]
            local radius = args[2]
            local direction = args[3]
            local params = args[4]

            if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
                if not isGroundRay(origin, direction) and passesOriginCheck(origin, currentCam) and passesIncludeCheck(params, currentCam) then
                    lastRaycastTime = os.clock()
                    if isAuto then
                        setDetectedMethod("Spherecast")
                    end

                    local target = getClosestTargetPart()
                    if target then
                        if Configuration.BulletPenetration then
                            local dir = (target.Position - origin).Unit
                            args[1] = target.Position - (dir * 0.2)
                            args[3] = dir * 10
                        else
                            args[3] = (target.Position - origin).Unit * 1000
                        end
                        setnamecallmethod(method)
                        return oldNamecall(self, unpack(args))
                    end
                end
            end

        -- Workspace:Blockcast
        elseif (isAuto or selectedMethod == "Blockcast") and method == "Blockcast" then
            local cf = args[1]
            local size = args[2]
            local direction = args[3]
            local params = args[4]

            if typeof(cf) == "CFrame" and typeof(direction) == "Vector3" then
                local origin = cf.Position
                if not isGroundRay(origin, direction) and passesOriginCheck(origin, currentCam) and passesIncludeCheck(params, currentCam) then
                    lastRaycastTime = os.clock()
                    if isAuto then
                        setDetectedMethod("Blockcast")
                    end

                    local target = getClosestTargetPart()
                    if target then
                        if Configuration.BulletPenetration then
                            local dir = (target.Position - origin).Unit
                            args[1] = CFrame.new(target.Position - (dir * 0.2), target.Position)
                            args[3] = dir * 10
                        else
                            args[3] = (target.Position - origin).Unit * 1000
                        end
                        setnamecallmethod(method)
                        return oldNamecall(self, unpack(args))
                    end
                end
            end

        -- Workspace:FindPartOnRay methods
        elseif (isAuto or selectedMethod == method) and (method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist" or method == "FindPartOnRayWithCollisionGroup") then
            local ray = args[1]
            if typeof(ray) == "Ray" then
                local origin = ray.Origin
                local direction = ray.Direction
                local ignoreList = (method == "FindPartOnRayWithIgnoreList" and args[2]) or nil

                if not isGroundRay(origin, direction) and passesOriginCheck(origin, currentCam) and passesIncludeCheck(ignoreList, currentCam) then
                    lastRaycastTime = os.clock()
                    if isAuto then
                        setDetectedMethod(method)
                    end

                    local target = getClosestTargetPart()
                    if target then
                        if Configuration.BulletPenetration then
                            local dir = (target.Position - origin).Unit
                            args[1] = Ray.new(target.Position - (dir * 0.2), dir * 10)
                        else
                            args[1] = Ray.new(origin, (target.Position - origin).Unit * 1000)
                        end
                        setnamecallmethod(method)
                        return oldNamecall(self, unpack(args))
                    end
                end
            end
        end

    elseif self == currentCam then
        -- Camera:ViewportPointToRay
        if (isAuto or selectedMethod == "ViewportPointToRay") and method == "ViewportPointToRay" then
            lastRaycastTime = os.clock()
            if isAuto and (detectedMethod == nil or detectedMethod == "Mouse") then
                setDetectedMethod("ViewportPointToRay")
            end

            local target = getClosestTargetPart()
            if target then
                local camPos = currentCam.CFrame.Position
                if Configuration.BulletPenetration then
                    local dir = (target.Position - camPos).Unit
                    return Ray.new(target.Position - (dir * 0.2), dir * 10)
                else
                    return Ray.new(camPos, (target.Position - camPos).Unit * 1000)
                end
            end

        -- Camera:ScreenPointToRay
        elseif (isAuto or selectedMethod == "ScreenPointToRay") and method == "ScreenPointToRay" then
            lastRaycastTime = os.clock()
            if isAuto and (detectedMethod == nil or detectedMethod == "Mouse") then
                setDetectedMethod("ScreenPointToRay")
            end

            local target = getClosestTargetPart()
            if target then
                local camPos = currentCam.CFrame.Position
                if Configuration.BulletPenetration then
                    local dir = (target.Position - camPos).Unit
                    return Ray.new(target.Position - (dir * 0.2), dir * 10)
                else
                    return Ray.new(camPos, (target.Position - camPos).Unit * 1000)
                end
            end

        -- Camera:Raycast
        elseif (isAuto or selectedMethod == "Raycast") and method == "Raycast" then
            local args = {...}
            local origin = args[1]
            local direction = args[2]

            if typeof(origin) == "Vector3" and typeof(direction) == "Vector3" then
                if not isGroundRay(origin, direction) then
                    lastRaycastTime = os.clock()
                    if isAuto then
                        setDetectedMethod("Raycast")
                    end

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
            end
        end
    end

    setnamecallmethod(method)
    return oldNamecall(self, ...)
end))

-- Metamethod Hook: __index
local oldIndex
oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, index)
    if not Configuration.Enabled or checkcaller() then
        return oldIndex(self, index)
    end

    local isAuto = Configuration.RaycastMethod == "Automatic"
    local isMouse = Configuration.RaycastMethod == "Mouse"

    if (isAuto or isMouse) and self == Mouse then
        local allowMouse = isMouse

        -- In Automatic mode, only engage Mouse if no active raycast method is handling weapon firing
        if isAuto then
            if detectedMethod == "Mouse" then
                allowMouse = true
            elseif (detectedMethod == nil or detectedMethod == "ViewportPointToRay" or detectedMethod == "ScreenPointToRay") and (os.clock() - lastRaycastTime) > 3 then
                local char = LocalPlayer.Character
                local tool = char and char:FindFirstChildWhichIsA("Tool")
                if tool then
                    setDetectedMethod("Mouse")
                    allowMouse = true
                end
            end
        end

        if allowMouse then
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
    Visuals = Window:AddTab("Visuals"),
    Settings = Window:AddTab("Settings")
}

-- Main Tab: Silent Tabbox (with Silent and Checks subtabs)
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
    Values = {"Automatic", "Raycast", "Spherecast", "Blockcast", "FindPartOnRay", "FindPartOnRayWithIgnoreList", "FindPartOnRayWithWhitelist", "FindPartOnRayWithCollisionGroup", "ViewportPointToRay", "ScreenPointToRay", "Mouse"},
    Default = 1,
    Multi = false,
    Text = "Raycast Method",
    Tooltip = "Engine raycast/query method to intercept",
    Callback = function(Value)
        Configuration.RaycastMethod = Value
        if Value == "Automatic" then
            detectedMethod = nil
            if MethodStatusLabel then
                MethodStatusLabel:SetText("Auto Method: Searching...")
            end
        else
            if MethodStatusLabel then
                MethodStatusLabel:SetText("Active Method: " .. Value)
            end
        end
    end
})

MethodStatusLabel = SilentGroup:AddLabel("Auto Method: Searching...")

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
    Values = {"Camera", "Character"},
    Tooltip = "Sets the allowed origin of the bullet/ray",
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

-- Visuals Tab: ESP Left Groupbox
local ESPBox = Tabs.Visuals:AddLeftGroupbox("ESP")

ESPBox:AddToggle("ESPEnabled", {
    Text = "Enabled",
    Default = VisualConfig.Enabled,
    Tooltip = "Toggles player ESP visuals",
    Callback = function(Value)
        VisualConfig.Enabled = Value
    end
}):AddKeyPicker("ESPKeyPicker", {
    Default = "None",
    SyncToggleState = true,
    Modes = {"Always", "Toggle", "Hold"},
    Mode = "Toggle",
    Text = "ESP",
    NoUI = false
})

ESPBox:AddToggle("ESPBoxToggle", {
    Text = "Box ESP",
    Default = VisualConfig.Boxes,
    Tooltip = "Renders bounding boxes around players",
    Callback = function(Value)
        VisualConfig.Boxes = Value
    end
}):AddColorPicker("ESPBoxColor", {
    Default = Color3.fromRGB(255, 255, 255),
    Title = "Box Color",
    Callback = function(Value)
        VisualConfig.BoxColor = Value
    end
})

ESPBox:AddDropdown("ESPBoxStyleDropdown", {
    Values = {"2D Box", "Corner Box"},
    Default = 1,
    Multi = false,
    Text = "Box Style",
    Tooltip = "Rendering style for player bounding box",
    Callback = function(Value)
        VisualConfig.BoxStyle = Value
    end
})

ESPBox:AddToggle("ESPNameToggle", {
    Text = "Name ESP",
    Default = VisualConfig.Names,
    Tooltip = "Renders player names above bounding boxes",
    Callback = function(Value)
        VisualConfig.Names = Value
    end
}):AddColorPicker("ESPNameColor", {
    Default = Color3.fromRGB(255, 255, 255),
    Title = "Name Color",
    Callback = function(Value)
        VisualConfig.NameColor = Value
    end
})

ESPBox:AddToggle("ESPDistanceToggle", {
    Text = "Distance ESP",
    Default = VisualConfig.Distance,
    Tooltip = "Renders distance in studs to players below bounding boxes",
    Callback = function(Value)
        VisualConfig.Distance = Value
    end
}):AddColorPicker("ESPDistanceColor", {
    Default = Color3.fromRGB(200, 200, 200),
    Title = "Distance Color",
    Callback = function(Value)
        VisualConfig.DistanceColor = Value
    end
})

ESPBox:AddToggle("ESPHealthBarToggle", {
    Text = "Health Bar",
    Default = VisualConfig.HealthBar,
    Tooltip = "Renders dynamic health bars beside player bounding boxes",
    Callback = function(Value)
        VisualConfig.HealthBar = Value
    end
}):AddColorPicker("ESPHealthColor", {
    Default = Color3.fromRGB(0, 255, 120),
    Title = "Health Bar Color",
    Callback = function(Value)
        VisualConfig.HealthBarColor = Value
    end
})

-- Visuals Tab: Settings Right Groupbox
local ESPOptionsBox = Tabs.Visuals:AddRightGroupbox("Settings")

ESPOptionsBox:AddToggle("ESPTeamCheck", {
    Text = "Team Check",
    Default = VisualConfig.TeamCheck,
    Tooltip = "Hides ESP for teammates",
    Callback = function(Value)
        VisualConfig.TeamCheck = Value
    end
})

ESPOptionsBox:AddToggle("ESPDisplayName", {
    Text = "Use Display Name",
    Default = VisualConfig.UseDisplayName,
    Tooltip = "Shows display names instead of usernames",
    Callback = function(Value)
        VisualConfig.UseDisplayName = Value
    end
})

ESPOptionsBox:AddToggle("ESPDynamicHealth", {
    Text = "Dynamic Health Color",
    Default = VisualConfig.DynamicHealth,
    Tooltip = "Smoothly shifts bar color from green to red based on player health",
    Callback = function(Value)
        VisualConfig.DynamicHealth = Value
    end
})

ESPOptionsBox:AddToggle("ESPHealthText", {
    Text = "Show Health Number",
    Default = VisualConfig.HealthText,
    Tooltip = "Displays numerical health value beside the health bar",
    Callback = function(Value)
        VisualConfig.HealthText = Value
    end
})

ESPOptionsBox:AddSlider("ESPMaxDistance", {
    Text = "Max Distance",
    Default = VisualConfig.MaxDistance,
    Min = 100,
    Max = 5000,
    Rounding = 0,
    Compact = false,
    Callback = function(Value)
        VisualConfig.MaxDistance = Value
    end
})

-- Settings Tab
local MenuBox = Tabs.Settings:AddLeftGroupbox("Menu")

MenuBox:AddButton("Unload", function()
    uiLoaded = false
    pcall(function() fovCircle:Remove() end)
    pcall(function() tracerLine:Remove() end)
    if renderSteppedConn then
        pcall(function() renderSteppedConn:Disconnect() end)
        renderSteppedConn = nil
    end
    for _, conn in ipairs(playerConnections) do
        pcall(function() conn:Disconnect() end)
    end
    playerConnections = {}
    for player in pairs(espObjects) do
        removeEsp(player)
    end
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
