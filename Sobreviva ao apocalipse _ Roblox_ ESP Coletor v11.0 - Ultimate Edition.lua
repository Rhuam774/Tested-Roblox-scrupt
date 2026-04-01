-- ESP Coletor v10.2 (Anti-Fog + Linhas + Speed Boost + PathFind)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local PathfindingService = game:GetService("PathfindingService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

-- ========================
-- LIMPAR GUI ANTERIOR
-- ========================
if game.CoreGui:FindFirstChild("ESPFarmGui") then
    game.CoreGui:FindFirstChild("ESPFarmGui"):Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ESPFarmGui"
ScreenGui.Parent = game.CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false

-- ========================
-- VARIÁVEIS
-- ========================
local espEnabled = false
local espObjects = {}
local maxDistance = 300
local GENERATOR_IGNORE_RADIUS = 40
local COLLECTION_SPEED = 50
local FREE_SPEED = 16
local freeSpeedEnabled = false
local fogRemoved = false
local ARRIVE_RADIUS = 6

local isCollecting = false
local shouldStopCollecting = false
local lineObjects = {}

-- Guardar configurações originais do fog
local originalFog = {
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
    FogColor = Lighting.FogColor,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    GlobalShadows = Lighting.GlobalShadows,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Ambient = Lighting.Ambient
}

local originalAtmosphere = {}
local originalBlur = {}
local originalColorCorrection = {}

local filters = {
    Crates = true,
    Batteries = true,
    Scrap = true,
    Food = false,
    Ammo = false,
    Weapons = false,
    Medical = false,
    Fuel = false,
    Blueprints = false
}

local topTierCategories = {
    Crates = true,
    Batteries = true
}

local categoryColors = {
    Crates = Color3.fromRGB(255, 100, 255),
    Batteries = Color3.fromRGB(0, 255, 255),
    Scrap = Color3.fromRGB(180, 180, 180),
    Food = Color3.fromRGB(255, 180, 0),
    Ammo = Color3.fromRGB(255, 255, 0),
    Weapons = Color3.fromRGB(255, 80, 80),
    Medical = Color3.fromRGB(0, 255, 100),
    Fuel = Color3.fromRGB(255, 100, 50),
    Blueprints = Color3.fromRGB(150, 100, 255)
}

-- ========================
-- SISTEMA ANTI-FOG COMPLETO
-- ========================
local fogLoopConn = nil

local function saveFogSettings()
    originalFog.FogEnd = Lighting.FogEnd
    originalFog.FogStart = Lighting.FogStart
    originalFog.FogColor = Lighting.FogColor
    originalFog.Brightness = Lighting.Brightness
    originalFog.ClockTime = Lighting.ClockTime
    originalFog.GlobalShadows = Lighting.GlobalShadows
    originalFog.OutdoorAmbient = Lighting.OutdoorAmbient
    originalFog.Ambient = Lighting.Ambient

    -- Salvar Atmosphere
    originalAtmosphere = {}
    for _, child in pairs(Lighting:GetChildren()) do
        if child:IsA("Atmosphere") then
            table.insert(originalAtmosphere, {
                obj = child,
                Density = child.Density,
                Offset = child.Offset,
                Color = child.Color,
                Decay = child.Decay,
                Glare = child.Glare,
                Haze = child.Haze,
                Enabled = true
            })
        end
    end

    -- Salvar BlurEffect
    originalBlur = {}
    for _, child in pairs(Lighting:GetChildren()) do
        if child:IsA("BlurEffect") then
            table.insert(originalBlur, {
                obj = child,
                Size = child.Size,
                Enabled = child.Enabled
            })
        end
    end

    -- Salvar ColorCorrectionEffect
    originalColorCorrection = {}
    for _, child in pairs(Lighting:GetChildren()) do
        if child:IsA("ColorCorrectionEffect") then
            table.insert(originalColorCorrection, {
                obj = child,
                Brightness = child.Brightness,
                Contrast = child.Contrast,
                Saturation = child.Saturation,
                TintColor = child.TintColor,
                Enabled = child.Enabled
            })
        end
    end
end

local function removeFog()
    saveFogSettings()

    -- Remover fog da Lighting
    Lighting.FogEnd = 9999999
    Lighting.FogStart = 9999999
    Lighting.FogColor = Color3.fromRGB(180, 200, 220)

    -- Melhorar visibilidade
    Lighting.Brightness = 2
    Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 150)
    Lighting.Ambient = Color3.fromRGB(100, 100, 100)
    Lighting.GlobalShadows = false

    -- Desabilitar Atmosphere (fog volumétrico)
    for _, child in pairs(Lighting:GetChildren()) do
        if child:IsA("Atmosphere") then
            child.Density = 0
            child.Offset = 0
            child.Glare = 0
            child.Haze = 0
        end
    end

    -- Desabilitar BlurEffect
    for _, child in pairs(Lighting:GetChildren()) do
        if child:IsA("BlurEffect") then
            child.Enabled = false
        end
    end

    -- Ajustar ColorCorrection (tirar escuridão)
    for _, child in pairs(Lighting:GetChildren()) do
        if child:IsA("ColorCorrectionEffect") then
            child.Brightness = 0.1
            child.Contrast = 0.1
            child.Saturation = 0
        end
    end

    -- Remover fog de Terrain também
    pcall(function()
        workspace.Terrain.WaterWaveSize = 0
        workspace.Terrain.WaterTransparency = 1
    end)

    -- Procurar efeitos dentro da câmera
    pcall(function()
        local cam = workspace.CurrentCamera
        for _, child in pairs(cam:GetChildren()) do
            if child:IsA("BlurEffect") or child:IsA("ColorCorrectionEffect") then
                child.Enabled = false
            end
        end
    end)

    -- Loop para impedir o jogo de restaurar o fog
    if fogLoopConn then fogLoopConn:Disconnect() end
    fogLoopConn = RunService.Heartbeat:Connect(function()
        if not fogRemoved then return end
        
        pcall(function()
            if Lighting.FogEnd < 9999999 then
                Lighting.FogEnd = 9999999
            end
            if Lighting.FogStart < 9999999 then
                Lighting.FogStart = 9999999
            end
            
            -- Manter Atmosphere sem fog
            for _, child in pairs(Lighting:GetChildren()) do
                if child:IsA("Atmosphere") then
                    if child.Density > 0 then child.Density = 0 end
                    if child.Haze > 0 then child.Haze = 0 end
                    if child.Glare > 0 then child.Glare = 0 end
                end
                if child:IsA("BlurEffect") then
                    child.Enabled = false
                end
            end

            -- Câmera
            local cam = workspace.CurrentCamera
            for _, child in pairs(cam:GetChildren()) do
                if child:IsA("BlurEffect") then
                    child.Enabled = false
                end
            end
        end)
    end)
end

local function restoreFog()
    if fogLoopConn then fogLoopConn:Disconnect() end

    pcall(function()
        Lighting.FogEnd = originalFog.FogEnd
        Lighting.FogStart = originalFog.FogStart
        Lighting.FogColor = originalFog.FogColor
        Lighting.Brightness = originalFog.Brightness
        Lighting.GlobalShadows = originalFog.GlobalShadows
        Lighting.OutdoorAmbient = originalFog.OutdoorAmbient
        Lighting.Ambient = originalFog.Ambient
    end)

    -- Restaurar Atmosphere
    for _, data in pairs(originalAtmosphere) do
        pcall(function()
            if data.obj and data.obj.Parent then
                data.obj.Density = data.Density
                data.obj.Offset = data.Offset
                data.obj.Glare = data.Glare
                data.obj.Haze = data.Haze
            end
        end)
    end

    -- Restaurar Blur
    for _, data in pairs(originalBlur) do
        pcall(function()
            if data.obj and data.obj.Parent then
                data.obj.Size = data.Size
                data.obj.Enabled = data.Enabled
            end
        end)
    end

    -- Restaurar ColorCorrection
    for _, data in pairs(originalColorCorrection) do
        pcall(function()
            if data.obj and data.obj.Parent then
                data.obj.Brightness = data.Brightness
                data.obj.Contrast = data.Contrast
                data.obj.Saturation = data.Saturation
                data.obj.Enabled = data.Enabled
            end
        end)
    end

    -- Restaurar câmera
    pcall(function()
        local cam = workspace.CurrentCamera
        for _, child in pairs(cam:GetChildren()) do
            if child:IsA("BlurEffect") or child:IsA("ColorCorrectionEffect") then
                child.Enabled = true
            end
        end
    end)
end

-- ========================
-- SPEED BOOST
-- ========================
local speedLoopConn = nil

local function startSpeedLoop()
    if speedLoopConn then speedLoopConn:Disconnect() end
    speedLoopConn = RunService.Heartbeat:Connect(function()
        if not freeSpeedEnabled then return end
        if isCollecting then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.WalkSpeed ~= FREE_SPEED then
            hum.WalkSpeed = FREE_SPEED
        end
    end)
end

-- ========================
-- LINHAS GUIA
-- ========================
local function clearAllLines()
    for _, obj in pairs(lineObjects) do
        if obj and obj.Parent then obj:Destroy() end
    end
    lineObjects = {}
end

local function getClosestItemPerCategory()
    local closest = {}
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return closest end

    for obj, data in pairs(espObjects) do
        if obj and obj.Parent and data.category and filters[data.category] then
            local posObj = data.posObj
            if posObj and posObj:IsA("BasePart") then
                local dist = (root.Position - posObj.Position).Magnitude
                local cat = data.category
                if not closest[cat] or dist < closest[cat].dist then
                    closest[cat] = {
                        obj = obj,
                        data = data,
                        dist = dist,
                        pos = posObj.Position,
                        posObj = posObj
                    }
                end
            end
        end
    end
    return closest
end

local function updateLines()
    clearAllLines()
    if not espEnabled then return end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local closest = getClosestItemPerCategory()

    for cat, info in pairs(closest) do
        local color = categoryColors[cat] or Color3.fromRGB(255, 255, 255)
        local targetPart = info.posObj

        if not targetPart or not targetPart.Parent then continue end

        local att0 = Instance.new("Attachment")
        att0.Name = "LS_" .. cat
        att0.Parent = root

        local att1 = Instance.new("Attachment")
        att1.Name = "LE_" .. cat
        att1.Parent = targetPart

        local beam = Instance.new("Beam")
        beam.Name = "GL_" .. cat
        beam.Attachment0 = att0
        beam.Attachment1 = att1
        beam.Color = ColorSequence.new(color)
        beam.Transparency = NumberSequence.new(0.2)
        beam.Width0 = 0.2
        beam.Width1 = 0.2
        beam.FaceCamera = true
        beam.LightEmission = 1
        beam.Segments = 1
        beam.Parent = root

        table.insert(lineObjects, att0)
        table.insert(lineObjects, att1)
        table.insert(lineObjects, beam)
    end
end

-- ========================
-- MOCHILA
-- ========================
local function equipBackpack()
    local char = LocalPlayer.Character
    local backpackFolder = LocalPlayer:FindFirstChild("Backpack")
    if not char or not backpackFolder then return false end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end

    local equipped = char:FindFirstChildOfClass("Tool")
    if equipped and (equipped.Name:lower():match("backpack") or equipped.Name:lower():match("bag") or equipped.Name:lower():match("mochila")) then
        return true
    end

    for _, tool in pairs(backpackFolder:GetChildren()) do
        if tool:IsA("Tool") and (tool.Name:lower():match("backpack") or tool.Name:lower():match("bag") or tool.Name:lower():match("mochila")) then
            hum:EquipTool(tool)
            task.wait(0.4)
            return true
        end
    end
    return false
end

-- ========================
-- PATHFINDING
-- ========================
local function navigateToItem(targetPart, hum, root)
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = false,
        WaypointSpacing = 4
    })

    local success = pcall(function()
        path:ComputeAsync(root.Position, targetPart.Position)
    end)

    if not success or path.Status ~= Enum.PathStatus.Success then
        hum:MoveTo(targetPart.Position)
        local startTime = tick()
        repeat
            RunService.Heartbeat:Wait()
            if shouldStopCollecting then return false end
            if not targetPart or not targetPart.Parent then return false end
        until (root.Position - targetPart.Position).Magnitude <= ARRIVE_RADIUS or (tick() - startTime) > 20
        hum:MoveTo(root.Position)
        return (root.Position - targetPart.Position).Magnitude <= ARRIVE_RADIUS
    end

    local waypoints = path:GetWaypoints()
    for _, waypoint in ipairs(waypoints) do
        if shouldStopCollecting then
            hum:MoveTo(root.Position)
            return false
        end
        if not targetPart or not targetPart.Parent then
            hum:MoveTo(root.Position)
            return false
        end

        if waypoint.Action == Enum.PathWaypointAction.Jump then
            hum.Jump = true
        end

        hum:MoveTo(waypoint.Position)

        local startTime = tick()
        repeat
            RunService.Heartbeat:Wait()
            if shouldStopCollecting then
                hum:MoveTo(root.Position)
                return false
            end
        until (root.Position - waypoint.Position).Magnitude < 5 or (tick() - startTime) > 4

        if (root.Position - targetPart.Position).Magnitude <= ARRIVE_RADIUS then
            hum:MoveTo(root.Position)
            return true
        end
    end

    return (root.Position - targetPart.Position).Magnitude <= ARRIVE_RADIUS
end

-- ========================
-- COLETA
-- ========================
local function collectCategory(categoryId, btnUI)
    if isCollecting then return end
    isCollecting = true
    shouldStopCollecting = false

    for i = 3, 1, -1 do
        if shouldStopCollecting then
            isCollecting = false
            return
        end
        if btnUI then btnUI.Text = "⏳ " .. i .. "s" end
        task.wait(1)
    end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then isCollecting = false; return end

    equipBackpack()

    local savedSpeed = hum.WalkSpeed
    hum.WalkSpeed = COLLECTION_SPEED

    local collectedCount = 0

    local movementConn
    movementConn = UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        local key = input.KeyCode
        if key == Enum.KeyCode.W or key == Enum.KeyCode.A or
           key == Enum.KeyCode.S or key == Enum.KeyCode.D or
           key == Enum.KeyCode.Q then
            shouldStopCollecting = true
        end
    end)

    if btnUI then btnUI.Text = "🏃 Indo..." end

    local function getNextItem()
        local bestObj, bestData, bestDist = nil, nil, math.huge
        for obj, data in pairs(espObjects) do
            if data.category == categoryId and obj and obj.Parent then
                local posObj = data.posObj
                if posObj and posObj:IsA("BasePart") then
                    local dist = (root.Position - posObj.Position).Magnitude
                    if dist < bestDist then
                        bestObj = obj
                        bestData = data
                        bestDist = dist
                    end
                end
            end
        end
        return bestObj, bestData, bestDist
    end

    while not shouldStopCollecting and collectedCount < 30 do
        local obj, data, dist = getNextItem()
        if not obj or not data then break end

        local targetPart = data.posObj
        if not targetPart or not targetPart:IsA("BasePart") then break end

        if btnUI then
            btnUI.Text = "🏃 #" .. (collectedCount + 1) .. " " .. math.floor(dist) .. "m"
        end

        local arrived = navigateToItem(targetPart, hum, root)

        if shouldStopCollecting then break end

        if arrived then
            if btnUI then btnUI.Text = "📦 Pegando..." end
            task.wait(0.8)

            if not obj.Parent then
                collectedCount = collectedCount + 1
            else
                if btnUI then btnUI.Text = "🔑 Aperte F!" end
                local fWait = tick()
                repeat
                    RunService.Heartbeat:Wait()
                until not obj.Parent or shouldStopCollecting or (tick() - fWait) > 5
                if not obj.Parent then
                    collectedCount = collectedCount + 1
                end
            end
        end

        task.wait(0.3)
    end

    movementConn:Disconnect()
    hum.WalkSpeed = freeSpeedEnabled and FREE_SPEED or savedSpeed
    hum:MoveTo(root.Position)
    isCollecting = false
    shouldStopCollecting = false

    if btnUI then btnUI.Text = "⚡ PEGAR" end
    print("✅ Coleta finalizada! " .. collectedCount .. " itens.")
end

-- ========================
-- GUI PRINCIPAL
-- ========================
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Position = UDim2.new(0.02, 0, 0.05, 0)
MainFrame.Size = UDim2.new(0, 290, 0, 640)
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local stroke = Instance.new("UIStroke", MainFrame)
stroke.Color = Color3.fromRGB(0, 255, 150)
stroke.Thickness = 2

-- Título
local TitleBar = Instance.new("Frame", MainFrame)
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
TitleBar.Size = UDim2.new(1, 0, 0, 35)
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 8)

local TitleText = Instance.new("TextLabel", TitleBar)
TitleText.BackgroundTransparency = 1
TitleText.Size = UDim2.new(1, 0, 1, 0)
TitleText.Font = Enum.Font.GothamBold
TitleText.Text = " 🎒 PathFind Loot v10.2"
TitleText.TextColor3 = Color3.fromRGB(0, 255, 150)
TitleText.TextSize = 14

local yPos = 42

-- Botão ESP
local MasterBtn = Instance.new("TextButton", MainFrame)
MasterBtn.Position = UDim2.new(0.05, 0, 0, yPos)
MasterBtn.Size = UDim2.new(0.9, 0, 0, 30)
MasterBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
MasterBtn.Font = Enum.Font.GothamBold
MasterBtn.Text = "👁️ LIGAR ESP + LINHAS"
MasterBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MasterBtn.TextSize = 12
Instance.new("UICorner", MasterBtn).CornerRadius = UDim.new(0, 6)
yPos = yPos + 35

-- Botão Anti-Fog
local FogBtn = Instance.new("TextButton", MainFrame)
FogBtn.Position = UDim2.new(0.05, 0, 0, yPos)
FogBtn.Size = UDim2.new(0.44, 0, 0, 30)
FogBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
FogBtn.Font = Enum.Font.GothamBold
FogBtn.Text = "🌫️ Fog: ON"
FogBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
FogBtn.TextSize = 11
Instance.new("UICorner", FogBtn).CornerRadius = UDim.new(0, 6)

-- Botão Speed Boost
local SpeedBoostBtn = Instance.new("TextButton", MainFrame)
SpeedBoostBtn.Position = UDim2.new(0.51, 0, 0, yPos)
SpeedBoostBtn.Size = UDim2.new(0.44, 0, 0, 30)
SpeedBoostBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
SpeedBoostBtn.Font = Enum.Font.GothamBold
SpeedBoostBtn.Text = "🚶 Speed: OFF"
SpeedBoostBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedBoostBtn.TextSize = 11
Instance.new("UICorner", SpeedBoostBtn).CornerRadius = UDim.new(0, 6)
yPos = yPos + 38

-- Slider Distância
local SliderLabel = Instance.new("TextLabel", MainFrame)
SliderLabel.BackgroundTransparency = 1
SliderLabel.Position = UDim2.new(0.05, 0, 0, yPos)
SliderLabel.Size = UDim2.new(0.9, 0, 0, 14)
SliderLabel.Font = Enum.Font.Gotham
SliderLabel.Text = "📡 Distância ESP: " .. maxDistance .. "m"
SliderLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
SliderLabel.TextSize = 10
SliderLabel.TextXAlignment = Enum.TextXAlignment.Left
yPos = yPos + 16

local SliderBG = Instance.new("Frame", MainFrame)
SliderBG.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
SliderBG.Position = UDim2.new(0.05, 0, 0, yPos)
SliderBG.Size = UDim2.new(0.9, 0, 0, 10)
Instance.new("UICorner", SliderBG).CornerRadius = UDim.new(1, 0)

local SliderFill = Instance.new("Frame", SliderBG)
SliderFill.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
SliderFill.Size = UDim2.new(maxDistance / 2000, 0, 1, 0)
Instance.new("UICorner", SliderFill).CornerRadius = UDim.new(1, 0)

local SliderBtn = Instance.new("TextButton", SliderBG)
SliderBtn.BackgroundTransparency = 1
SliderBtn.Size = UDim2.new(1, 0, 1, 0)
SliderBtn.Text = ""
yPos = yPos + 16

-- Slider Speed Coleta
local CollectSpeedLabel = Instance.new("TextLabel", MainFrame)
CollectSpeedLabel.BackgroundTransparency = 1
CollectSpeedLabel.Position = UDim2.new(0.05, 0, 0, yPos)
CollectSpeedLabel.Size = UDim2.new(0.9, 0, 0, 14)
CollectSpeedLabel.Font = Enum.Font.Gotham
CollectSpeedLabel.Text = "🏃 Speed Coleta: " .. COLLECTION_SPEED
CollectSpeedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
CollectSpeedLabel.TextSize = 10
CollectSpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
yPos = yPos + 16

local CollectSliderBG = Instance.new("Frame", MainFrame)
CollectSliderBG.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
CollectSliderBG.Position = UDim2.new(0.05, 0, 0, yPos)
CollectSliderBG.Size = UDim2.new(0.9, 0, 0, 10)
Instance.new("UICorner", CollectSliderBG).CornerRadius = UDim.new(1, 0)

local CollectSliderFill = Instance.new("Frame", CollectSliderBG)
CollectSliderFill.BackgroundColor3 = Color3.fromRGB(255, 180, 0)
CollectSliderFill.Size = UDim2.new(COLLECTION_SPEED / 150, 0, 1, 0)
Instance.new("UICorner", CollectSliderFill).CornerRadius = UDim.new(1, 0)

local CollectSliderBtn = Instance.new("TextButton", CollectSliderBG)
CollectSliderBtn.BackgroundTransparency = 1
CollectSliderBtn.Size = UDim2.new(1, 0, 1, 0)
CollectSliderBtn.Text = ""
yPos = yPos + 16

-- Slider Speed Livre
local FreeSpeedLabel = Instance.new("TextLabel", MainFrame)
FreeSpeedLabel.BackgroundTransparency = 1
FreeSpeedLabel.Position = UDim2.new(0.05, 0, 0, yPos)
FreeSpeedLabel.Size = UDim2.new(0.9, 0, 0, 14)
FreeSpeedLabel.Font = Enum.Font.Gotham
FreeSpeedLabel.Text = "🚶 Speed Livre: " .. FREE_SPEED
FreeSpeedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
FreeSpeedLabel.TextSize = 10
FreeSpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
yPos = yPos + 16

local FreeSliderBG = Instance.new("Frame", MainFrame)
FreeSliderBG.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
FreeSliderBG.Position = UDim2.new(0.05, 0, 0, yPos)
FreeSliderBG.Size = UDim2.new(0.9, 0, 0, 10)
Instance.new("UICorner", FreeSliderBG).CornerRadius = UDim.new(1, 0)

local FreeSliderFill = Instance.new("Frame", FreeSliderBG)
FreeSliderFill.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
FreeSliderFill.Size = UDim2.new(FREE_SPEED / 150, 0, 1, 0)
Instance.new("UICorner", FreeSliderFill).CornerRadius = UDim.new(1, 0)

local FreeSliderBtn = Instance.new("TextButton", FreeSliderBG)
FreeSliderBtn.BackgroundTransparency = 1
FreeSliderBtn.Size = UDim2.new(1, 0, 1, 0)
FreeSliderBtn.Text = ""
yPos = yPos + 16

-- Info
local InfoLabel = Instance.new("TextLabel", MainFrame)
InfoLabel.BackgroundTransparency = 1
InfoLabel.Position = UDim2.new(0.05, 0, 0, yPos)
InfoLabel.Size = UDim2.new(0.9, 0, 0, 16)
InfoLabel.Font = Enum.Font.Gotham
InfoLabel.Text = "⚠️ WASD/Q cancela coleta | Clique 2x cancela"
InfoLabel.TextColor3 = Color3.fromRGB(255, 150, 50)
InfoLabel.TextSize = 9
InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
yPos = yPos + 20

-- Scroll Filtros
local ScrollFilters = Instance.new("ScrollingFrame", MainFrame)
ScrollFilters.Position = UDim2.new(0.05, 0, 0, yPos)
ScrollFilters.Size = UDim2.new(0.9, 0, 1, -yPos - 10)
ScrollFilters.BackgroundTransparency = 1
ScrollFilters.ScrollBarThickness = 4
ScrollFilters.CanvasSize = UDim2.new(0, 0, 0, 340)
local Layout = Instance.new("UIListLayout", ScrollFilters)
Layout.Padding = UDim.new(0, 5)

local function createFilterRow(id, text, color)
    local frame = Instance.new("Frame", ScrollFilters)
    frame.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
    frame.BackgroundTransparency = 0.5
    frame.Size = UDim2.new(1, 0, 0, 32)
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 4)

    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.new(0, 24, 0, 24)
    btn.Position = UDim2.new(0, 4, 0.5, -12)
    btn.BackgroundColor3 = filters[id] and color or Color3.fromRGB(50, 50, 50)
    btn.Text = filters[id] and "✔" or ""
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    local lbl = Instance.new("TextLabel", frame)
    lbl.BackgroundTransparency = 1
    lbl.Position = UDim2.new(0, 34, 0, 0)
    lbl.Size = UDim2.new(1, -135, 1, 0)
    lbl.Font = Enum.Font.GothamBold
    lbl.Text = text .. (topTierCategories[id] and " 🌟" or "")
    lbl.TextColor3 = color
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local getBtn = Instance.new("TextButton", frame)
    getBtn.Size = UDim2.new(0, 85, 0, 24)
    getBtn.Position = UDim2.new(1, -90, 0.5, -12)
    getBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
    getBtn.Text = "⚡ PEGAR"
    getBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    getBtn.Font = Enum.Font.GothamBold
    getBtn.TextSize = 10
    Instance.new("UICorner", getBtn).CornerRadius = UDim.new(0, 4)

    btn.MouseButton1Click:Connect(function()
        filters[id] = not filters[id]
        btn.BackgroundColor3 = filters[id] and color or Color3.fromRGB(50, 50, 50)
        btn.Text = filters[id] and "✔" or ""
    end)

    getBtn.MouseButton1Click:Connect(function()
        if isCollecting then
            shouldStopCollecting = true
            return
        end
        getBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 0)
        task.spawn(function()
            collectCategory(id, getBtn)
            getBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
        end)
    end)
end

createFilterRow("Crates", "📦 Caixas", Color3.fromRGB(255, 100, 255))
createFilterRow("Batteries", "🔋 Pilhas", Color3.fromRGB(0, 255, 255))
createFilterRow("Scrap", "⚙️ Sucata", Color3.fromRGB(180, 180, 180))
createFilterRow("Food", "🍔 Comida", Color3.fromRGB(255, 180, 0))
createFilterRow("Ammo", "🎯 Munição", Color3.fromRGB(255, 255, 0))
createFilterRow("Weapons", "🔫 Armas", Color3.fromRGB(255, 80, 80))
createFilterRow("Medical", "💊 Curativos", Color3.fromRGB(0, 255, 100))
createFilterRow("Fuel", "⛽ Combustível", Color3.fromRGB(255, 100, 50))
createFilterRow("Blueprints", "🛠️ Armadilhas", Color3.fromRGB(150, 100, 255))

-- ========================
-- SLIDERS DRAG
-- ========================
local dragging1, dragging2, dragging3 = false, false, false

SliderBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging1 = true
    end
end)
CollectSliderBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging2 = true
    end
end)
FreeSliderBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging3 = true
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging1, dragging2, dragging3 = false, false, false
    end
end)

-- ========================
-- IDENTIFICAÇÃO
-- ========================
local function isNearGenerator(pos)
    if not workspace:FindFirstChild("Structures") then return false end
    for _, struct in pairs(workspace.Structures:GetChildren()) do
        if struct.Name == "Generator" then
            local ok, genPivot = pcall(function() return struct:GetPivot() end)
            if ok and genPivot and (pos - genPivot.Position).Magnitude <= GENERATOR_IGNORE_RADIUS then
                return true
            end
        end
    end
    return false
end

local function identifyItem(obj)
    if obj:GetAttribute("Crate") == true or (obj.Name == "Default" and obj.Parent and obj.Parent.Name == "Crates") then
        return "Crates", "📦 CAIXA", Color3.fromRGB(255, 100, 255)
    end
    local itemType = obj:GetAttribute("ItemType")
    local toolType = obj:GetAttribute("ToolType")
    if obj.Name == "Battery" or (itemType == "Resource" and obj:GetAttribute("Batteries")) then
        return "Batteries", "🔋 PILHA", Color3.fromRGB(0, 255, 255)
    end
    if itemType == "Resource" and (obj:GetAttribute("Scrap") or obj.Name == "Spatula" or obj.Name == "Tray" or obj.Name == "Screws" or obj.Name == "Scrap") then
        return "Scrap", "⚙️ " .. obj.Name:upper(), Color3.fromRGB(180, 180, 180)
    end
    if itemType == "Food" then return "Food", "🍔 " .. obj.Name:upper(), Color3.fromRGB(255, 180, 0) end
    if itemType == "Ammo" then return "Ammo", "🎯 " .. obj.Name:upper(), Color3.fromRGB(255, 255, 0) end
    if itemType == "Fuel" then return "Fuel", "⛽ " .. obj.Name:upper(), Color3.fromRGB(255, 100, 50) end
    if toolType == "Medical" then return "Medical", "💊 " .. obj.Name:upper(), Color3.fromRGB(0, 255, 100) end
    if toolType == "Gun" or toolType == "Melee" then return "Weapons", "🔫 " .. obj.Name:upper(), Color3.fromRGB(255, 80, 80) end
    if toolType == "Blueprint" then return "Blueprints", "🛠️ " .. obj.Name:upper(), Color3.fromRGB(150, 100, 255) end
    return nil, nil, nil
end

-- ========================
-- ESP
-- ========================
local function addESP(obj)
    if espObjects[obj] then return end
    local category, displayName, color = identifyItem(obj)
    if not category then return end

    local posObj = obj
    if obj:IsA("Model") then
        posObj = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart") or obj
    elseif obj:IsA("Tool") then
        posObj = obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart") or obj
    end

    if posObj:IsA("BasePart") and isNearGenerator(posObj.Position) then return end

    local hl = Instance.new("Highlight")
    hl.FillColor = color
    hl.OutlineColor = color
    hl.FillTransparency = 0.75
    hl.OutlineTransparency = 0.1
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = obj
    hl.Parent = obj

    local bb = Instance.new("BillboardGui")
    bb.AlwaysOnTop = true
    bb.Size = UDim2.new(0, 200, 0, 50)
    bb.StudsOffset = Vector3.new(0, 1.5, 0)
    bb.Adornee = obj
    bb.Parent = obj

    local lbl = Instance.new("TextLabel", bb)
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 0.6, 0)
    lbl.Font = Enum.Font.GothamBold
    lbl.Text = displayName
    lbl.TextColor3 = color
    lbl.TextStrokeTransparency = 0.2
    lbl.TextSize = 12

    local distLbl = Instance.new("TextLabel", bb)
    distLbl.BackgroundTransparency = 1
    distLbl.Position = UDim2.new(0, 0, 0.6, 0)
    distLbl.Size = UDim2.new(1, 0, 0.4, 0)
    distLbl.Font = Enum.Font.Gotham
    distLbl.Text = "0m"
    distLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    distLbl.TextStrokeTransparency = 0.5
    distLbl.TextSize = 11

    espObjects[obj] = { hl = hl, bb = bb, distLbl = distLbl, category = category, posObj = posObj }
end

local function scanMap()
    if workspace:FindFirstChild("DroppedItems") then
        for _, item in pairs(workspace.DroppedItems:GetChildren()) do addESP(item) end
    end
    if workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Crates") then
        for _, crate in pairs(workspace.Map.Crates:GetChildren()) do addESP(crate) end
    end
end

-- ========================
-- LOOP PRINCIPAL
-- ========================
local updateConn
local lineTimer = 0

local function startESPUpdate()
    if updateConn then updateConn:Disconnect() end
    updateConn = RunService.RenderStepped:Connect(function(dt)
        if not espEnabled then return end

        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local mouseX = UserInputService:GetMouseLocation().X

        if dragging1 then
            local pos = SliderBG.AbsolutePosition.X
            local size = SliderBG.AbsoluteSize.X
            local pct = math.clamp((mouseX - pos) / size, 0, 1)
            SliderFill.Size = UDim2.new(pct, 0, 1, 0)
            maxDistance = math.floor(pct * 2000)
            SliderLabel.Text = "📡 Distância ESP: " .. maxDistance .. "m"
        end
        if dragging2 then
            local pos = CollectSliderBG.AbsolutePosition.X
            local size = CollectSliderBG.AbsoluteSize.X
            local pct = math.clamp((mouseX - pos) / size, 0, 1)
            CollectSliderFill.Size = UDim2.new(pct, 0, 1, 0)
            COLLECTION_SPEED = math.max(16, math.floor(pct * 150))
            CollectSpeedLabel.Text = "🏃 Speed Coleta: " .. COLLECTION_SPEED
        end
        if dragging3 then
            local pos = FreeSliderBG.AbsolutePosition.X
            local size = FreeSliderBG.AbsoluteSize.X
            local pct = math.clamp((mouseX - pos) / size, 0, 1)
            FreeSliderFill.Size = UDim2.new(pct, 0, 1, 0)
            FREE_SPEED = math.max(16, math.floor(pct * 150))
            FreeSpeedLabel.Text = "🚶 Speed Livre: " .. FREE_SPEED
        end

        for obj, data in pairs(espObjects) do
            if obj and obj.Parent then
                local dist = 9999
                if data.posObj and data.posObj:IsA("BasePart") then
                    dist = math.floor((root.Position - data.posObj.Position).Magnitude)
                end
                local withinDistance = (dist <= maxDistance) or topTierCategories[data.category]
                local isEnabled = filters[data.category] and withinDistance
                data.hl.Enabled = isEnabled
                data.bb.Enabled = isEnabled
                if isEnabled then data.distLbl.Text = tostring(dist) .. "m" end
            else
                pcall(function()
                    if data.hl then data.hl:Destroy() end
                    if data.bb then data.bb:Destroy() end
                end)
                espObjects[obj] = nil
            end
        end

        lineTimer = lineTimer + dt
        if lineTimer >= 0.4 then
            lineTimer = 0
            updateLines()
        end
    end)
end

-- ========================
-- BOTÕES PRINCIPAIS
-- ========================
FogBtn.MouseButton1Click:Connect(function()
    fogRemoved = not fogRemoved
    if fogRemoved then
        FogBtn.Text = "🌫️ Fog: OFF"
        FogBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
        removeFog()
    else
        FogBtn.Text = "🌫️ Fog: ON"
        FogBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        restoreFog()
    end
end)

SpeedBoostBtn.MouseButton1Click:Connect(function()
    freeSpeedEnabled = not freeSpeedEnabled
    if freeSpeedEnabled then
        SpeedBoostBtn.Text = "🏃 Speed: ON"
        SpeedBoostBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
        startSpeedLoop()
    else
        SpeedBoostBtn.Text = "🚶 Speed: OFF"
        SpeedBoostBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        if speedLoopConn then speedLoopConn:Disconnect() end
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = 16 end
        end
    end
end)

MasterBtn.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    if espEnabled then
        MasterBtn.Text = "👁️ DESLIGAR ESP + LINHAS"
        MasterBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 40)
        scanMap()
        startESPUpdate()
    else
        MasterBtn.Text = "👁️ LIGAR ESP + LINHAS"
        MasterBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        if updateConn then updateConn:Disconnect() end
        clearAllLines()
        for obj, data in pairs(espObjects) do
            if data.hl then data.hl.Enabled = false end
            if data.bb then data.bb.Enabled = false end
        end
    end
end)

workspace.DescendantAdded:Connect(function(obj)
    if not espEnabled then return end
    task.wait(0.5)
    if obj and obj:IsDescendantOf(workspace) then
        if obj.Parent and (obj.Parent.Name == "DroppedItems" or obj.Parent.Name == "Crates") then
            addESP(obj)
        end
    end
end)

print("✅ PathFind Loot v10.2 carregado!")
print("🌫️ Anti-Fog disponível")
print("🏃 Speed Boost livre disponível")
print("📌 WASD/Q cancela coleta")
