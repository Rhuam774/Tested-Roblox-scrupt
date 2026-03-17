-- =============================================================
--  MODO LAGATIXA  v8  -  VERSÃO MOBILE/CELULAR
-- =============================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ==============================
-- CONSTANTES
-- ==============================
local WALK_SPEED   = 16
local JUMP_POWER   = 50
local GRAVITY      = 196.2
local STICK_DIST   = 3

-- ==============================
-- ESTADO
-- ==============================
local ativo = false
local loop = nil
local mobileControls = nil

-- ==============================
-- RAYCAST SIMPLES
-- ==============================
local function raycastChao(pos, char)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    
    local dirs = {
        Vector3.new(0, -1, 0),
        Vector3.new(0, 1, 0),
        Vector3.new(1, 0, 0),
        Vector3.new(-1, 0, 0),
        Vector3.new(0, 0, 1),
        Vector3.new(0, 0, -1),
    }
    
    local melhorHit = nil
    local melhorDist = math.huge
    
    for _, dir in ipairs(dirs) do
        local result = workspace:Raycast(pos, dir * 10, params)
        if result then
            local dist = (result.Position - pos).Magnitude
            if dist < melhorDist then
                melhorDist = dist
                melhorHit = result
            end
        end
    end
    
    return melhorHit, melhorDist
end

-- ==============================
-- CONTROLES MOBILE
-- ==============================
local function criarControlesMobile()
    local gui = player.PlayerGui:FindFirstChild("LagatixaGUI")
    if not gui then return end
    
    -- Container dos controles
    local controls = Instance.new("Frame")
    controls.Name = "MobileControls"
    controls.Size = UDim2.new(1, 0, 1, 0)
    controls.BackgroundTransparency = 1
    controls.Parent = gui
    
    -- JOYSTICK ESQUERDO (Movimento)
    local joyBack = Instance.new("Frame")
    joyBack.Name = "JoyBack"
    joyBack.Size = UDim2.new(0, 120, 0, 120)
    joyBack.Position = UDim2.new(0, 30, 1, -150)
    joyBack.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    joyBack.BackgroundTransparency = 0.6
    joyBack.BorderSizePixel = 0
    joyBack.Parent = controls
    
    local joyCorner = Instance.new("UICorner", joyBack)
    joyCorner.CornerRadius = UDim.new(1, 0)
    
    local joyStick = Instance.new("Frame")
    joyStick.Name = "Stick"
    joyStick.Size = UDim2.new(0, 50, 0, 50)
    joyStick.Position = UDim2.new(0.5, -25, 0.5, -25)
    joyStick.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    joyStick.BackgroundTransparency = 0.4
    joyStick.BorderSizePixel = 0
    joyStick.Parent = joyBack
    
    local stickCorner = Instance.new("UICorner", joyStick)
    stickCorner.CornerRadius = UDim.new(1, 0)
    
    -- BOTÃO DE PULO (Direita)
    local jumpBtn = Instance.new("TextButton")
    jumpBtn.Name = "JumpBtn"
    jumpBtn.Size = UDim2.new(0, 80, 0, 80)
    jumpBtn.Position = UDim2.new(1, -110, 1, -150)
    jumpBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
    jumpBtn.BackgroundTransparency = 0.3
    jumpBtn.BorderSizePixel = 0
    jumpBtn.Text = "⬆"
    jumpBtn.TextSize = 40
    jumpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    jumpBtn.Font = Enum.Font.GothamBold
    jumpBtn.Parent = controls
    
    local jumpCorner = Instance.new("UICorner", jumpBtn)
    jumpCorner.CornerRadius = UDim.new(1, 0)
    
    -- Estado do joystick
    local moveX = 0
    local moveZ = 0
    local touching = false
    local wantsJump = false
    
    -- Função do Joystick
    local function updateJoystick(input)
        local center = joyBack.AbsolutePosition + joyBack.AbsoluteSize / 2
        local delta = Vector2.new(input.Position.X, input.Position.Y) - center
        local distance = math.min(delta.Magnitude, 60)
        local angle = math.atan2(delta.Y, delta.X)
        
        if distance > 10 then
            moveX = math.cos(angle) * (distance / 60)
            moveZ = -math.sin(angle) * (distance / 60)
            
            local offset = Vector2.new(math.cos(angle), math.sin(angle)) * distance
            joyStick.Position = UDim2.new(0.5, offset.X - 25, 0.5, offset.Y - 25)
        else
            moveX = 0
            moveZ = 0
            joyStick.Position = UDim2.new(0.5, -25, 0.5, -25)
        end
    end
    
    -- Eventos do Joystick
    joyBack.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            touching = true
            updateJoystick(input)
        end
    end)
    
    joyBack.InputChanged:Connect(function(input)
        if touching and input.UserInputType == Enum.UserInputType.Touch then
            updateJoystick(input)
        end
    end)
    
    joyBack.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            touching = false
            moveX = 0
            moveZ = 0
            joyStick.Position = UDim2.new(0.5, -25, 0.5, -25)
        end
    end)
    
    -- Eventos do Botão de Pulo
    jumpBtn.MouseButton1Down:Connect(function()
        wantsJump = true
        jumpBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
    end)
    
    jumpBtn.MouseButton1Up:Connect(function()
        wantsJump = false
        jumpBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
    end)
    
    -- Retorna funções para ler o input
    return {
        getMoveX = function() return moveX end,
        getMoveZ = function() return moveZ end,
        getJump = function() return wantsJump end,
        destroy = function() controls:Destroy() end
    }
end

-- ==============================
-- LIGAR
-- ==============================
local function ligar()
    local char = player.Character
    if not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    
    if not hrp or not hum then return end
    
    -- Desativa controles normais
    hum.PlatformStand = true
    hrp.Anchored = false
    
    -- Cria BodyVelocity
    local bodyVel = Instance.new("BodyVelocity")
    bodyVel.MaxForce = Vector3.new(4e4, 4e4, 4e4)
    bodyVel.Velocity = Vector3.zero
    bodyVel.Parent = hrp
    
    -- Cria BodyGyro
    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(4e4, 4e4, 4e4)
    bodyGyro.P = 3000
    bodyGyro.D = 500
    bodyGyro.CFrame = hrp.CFrame
    bodyGyro.Parent = hrp
    
    -- Cria controles mobile
    mobileControls = criarControlesMobile()
    if not mobileControls then
        warn("Erro ao criar controles mobile!")
        return
    end
    
    -- Estado
    local surfaceNormal = Vector3.new(0, 1, 0)
    local verticalVelocity = 0
    local isGrounded = false
    local canJump = true
    
    loop = RunService.Heartbeat:Connect(function(dt)
        if not ativo then return end
        if not char or not char.Parent then return end
        if not hrp or not hrp.Parent then return end
        
        -- LÊ INPUT DOS CONTROLES MOBILE
        local moveX = mobileControls.getMoveX()
        local moveZ = mobileControls.getMoveZ()
        local wantsJump = mobileControls.getJump()
        
        -- DIREÇÕES DA CÂMERA
        local camCF = camera.CFrame
        local camLook = camCF.LookVector
        local camRight = camCF.RightVector
        
        -- Projeta na superfície
        local forward = (camLook - camLook:Dot(surfaceNormal) * surfaceNormal)
        if forward.Magnitude > 0.01 then
            forward = forward.Unit
        else
            forward = Vector3.new(0, 0, -1)
        end
        
        local right = (camRight - camRight:Dot(surfaceNormal) * surfaceNormal)
        if right.Magnitude > 0.01 then
            right = right.Unit
        else
            right = Vector3.new(1, 0, 0)
        end
        
        -- MOVIMENTO LATERAL
        local moveDir = forward * moveZ + right * moveX
        local lateralVel = Vector3.zero
        
        if moveDir.Magnitude > 0.1 then
            lateralVel = moveDir.Unit * WALK_SPEED
        end
        
        -- DETECÇÃO DE SUPERFÍCIE
        local hit, dist = raycastChao(hrp.Position, char)
        
        if hit and dist < 5 then
            surfaceNormal = surfaceNormal:Lerp(hit.Normal, dt * 10)
            if surfaceNormal.Magnitude > 0 then
                surfaceNormal = surfaceNormal.Unit
            else
                surfaceNormal = Vector3.new(0, 1, 0)
            end
            
            if dist < STICK_DIST and verticalVelocity <= 0 then
                isGrounded = true
                verticalVelocity = 0
                local stickForce = (hit.Position + hit.Normal * STICK_DIST - hrp.Position) * 10
                bodyVel.Velocity = lateralVel + stickForce
            else
                isGrounded = false
                verticalVelocity = verticalVelocity - GRAVITY * dt
                bodyVel.Velocity = lateralVel + surfaceNormal * verticalVelocity
            end
        else
            isGrounded = false
            verticalVelocity = verticalVelocity - GRAVITY * dt
            bodyVel.Velocity = lateralVel + Vector3.new(0, verticalVelocity, 0)
            surfaceNormal = surfaceNormal:Lerp(Vector3.new(0, 1, 0), dt * 5)
        end
        
        -- PULO
        if wantsJump and isGrounded and canJump then
            verticalVelocity = JUMP_POWER
            isGrounded = false
            canJump = false
            task.delay(0.5, function()
                canJump = true
            end)
        end
        
        -- ORIENTAÇÃO
        local upVec = surfaceNormal
        local lookVec = forward
        local rightVec = lookVec:Cross(upVec).Unit
        lookVec = upVec:Cross(rightVec).Unit
        
        local targetCF = CFrame.fromMatrix(hrp.Position, rightVec, upVec, -lookVec)
        bodyGyro.CFrame = targetCF
    end)
end

-- ==============================
-- DESLIGAR
-- ==============================
local function desligar()
    if loop then
        loop:Disconnect()
        loop = nil
    end
    
    if mobileControls then
        mobileControls.destroy()
        mobileControls = nil
    end
    
    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        
        if hum then
            hum.PlatformStand = false
        end
        
        if hrp then
            for _, obj in ipairs(hrp:GetChildren()) do
                if obj:IsA("BodyVelocity") or obj:IsA("BodyGyro") then
                    obj:Destroy()
                end
            end
            
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end
end

-- ==============================
-- GUI
-- ==============================
local function criarGUI()
    local old = player.PlayerGui:FindFirstChild("LagatixaGUI")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "LagatixaGUI"
    gui.ResetOnSpawn = false
    gui.Parent = player.PlayerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 280, 0, 120)
    frame.Position = UDim2.new(0.5, -140, 0, 20)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    frame.BorderSizePixel = 2
    frame.BorderColor3 = Color3.fromRGB(0, 170, 255)
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    title.BorderSizePixel = 0
    title.Text = "🦎 LAGATIXA MOBILE"
    title.TextColor3 = Color3.fromRGB(0, 200, 255)
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.Parent = frame

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -20, 0, 20)
    status.Position = UDim2.new(0, 10, 0, 50)
    status.BackgroundTransparency = 1
    status.Text = "OFF"
    status.TextColor3 = Color3.fromRGB(255, 100, 100)
    status.TextSize = 16
    status.Font = Enum.Font.GothamBold
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 40)
    btn.Position = UDim2.new(0, 10, 1, -50)
    btn.BackgroundColor3 = Color3.fromRGB(0, 150, 100)
    btn.BorderSizePixel = 0
    btn.Text = "LIGAR"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 18
    btn.Font = Enum.Font.GothamBold
    btn.Parent = frame

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    btn.MouseButton1Click:Connect(function()
        ativo = not ativo
        
        if ativo then
            btn.Text = "DESLIGAR"
            btn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            status.Text = "ON ✓"
            status.TextColor3 = Color3.fromRGB(100, 255, 100)
            ligar()
        else
            btn.Text = "LIGAR"
            btn.BackgroundColor3 = Color3.fromRGB(0, 150, 100)
            status.Text = "OFF"
            status.TextColor3 = Color3.fromRGB(255, 100, 100)
            desligar()
        end
    end)
end

-- ==============================
-- INICIO
-- ==============================
criarGUI()

player.CharacterAdded:Connect(function()
    if ativo then
        desligar()
        task.wait(2)
        if ativo then ligar() end
    end
end)

print("[LAGATIXA MOBILE] Pronto!")
