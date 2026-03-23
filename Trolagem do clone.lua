-- =============================================================
--  MODO LAGATIXA  v10.2  -  ANIMAÇÃO MANUAL SIMPLES
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
local animState = {
    time = 0,
    isMoving = false,
    moveSpeed = 0,
    isGrounded = true,
    verticalVelocity = 0,
    phase = "idle"
}

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
-- SISTEMA DE ANIMAÇÃO MANUAL
-- ==============================
local bodyMotors = {} 
local animationTime = 0

local function removerRabo(char)
    task.spawn(function()
        while ativo and char and char.Parent do
            for _, obj in ipairs(char:GetDescendants()) do
                if (obj:IsA("Accessory") or obj:IsA("BasePart")) and (obj.Name:lower():find("tail") or obj.Name:lower():find("rabo")) then
                    if obj:IsA("BasePart") then
                        obj.Transparency = 1
                        obj.CanCollide = false
                    elseif obj:IsA("Accessory") and obj:FindFirstChild("Handle") then
                        obj.Handle.Transparency = 1
                        obj.Handle.CanCollide = false
                    end
                end
            end
            task.wait(2) -- Loop leve para garantir que o rabo não volte se o personagem mudar
        end
    end)
end

local function encontrarMotors(char)
    bodyMotors = {}
    
    local mapping = {
        ["LeftShoulder"] = {"LeftShoulder", "Left Shoulder"},
        ["RightShoulder"] = {"RightShoulder", "Right Shoulder"},
        ["LeftHip"] = {"LeftHip", "Left Hip"},
        ["RightHip"] = {"RightHip", "Right Hip"},
        ["Neck"] = {"Neck"},
        ["Waist"] = {"Waist", "RootJoint", "Root Joint"},
        ["Root"] = {"LowerTorso", "Root"}
    }
    
    for _, motor in ipairs(char:GetDescendants()) do
        if motor:IsA("Motor6D") then
            for key, aliases in pairs(mapping) do
                if bodyMotors[key] then continue end -- Evita duplicatas
                for _, alias in ipairs(aliases) do
                    if motor.Name == alias then
                        bodyMotors[key] = {
                            motor = motor,
                            originalC0 = motor.C0,
                            originalC1 = motor.C1
                        }
                        break
                    end
                end
            end
        end
    end
end

local function animarPersonagem(dt, isMoving, moveSpeed)
    local t = tick()
    local breathing = math.sin(t * 1.5) * 0.02
    
    if not isMoving then
        -- Pose Idle de Réptil (corpo baixo, patas abertas)
        for name, data in pairs(bodyMotors) do
            local motor = data.motor
            local target = data.originalC0
            
            if name == "LeftShoulder" or name == "RightShoulder" then
                local side = (name == "LeftShoulder" and -1 or 1)
                target = target * CFrame.Angles(0, 0, side * math.rad(25))
            elseif name == "LeftHip" or name == "RightHip" then
                local side = (name == "LeftHip" and -1 or 1)
                target = target * CFrame.Angles(0, 0, side * math.rad(25))
            elseif name == "Root" or name == "Waist" then
                target = target * CFrame.new(0, -0.2 + breathing, 0)
            end
            
            motor.C0 = motor.C0:Lerp(target, dt * 6)
        end
        return
    end
    
    -- ANIMAÇÃO DE RASTEJAR ULTRA-VISÍVEL
    local speed = 10 + (moveSpeed * 8)
    animationTime = animationTime + dt * speed
    
    local cycle = animationTime
    local sway = math.sin(cycle) * 0.6 -- Balanço lateral forte
    local verticalBob = math.abs(math.sin(cycle * 2)) * 0.2
    
    for name, data in pairs(bodyMotors) do
        local motor = data.motor
        local target = data.originalC0
        
        -- Amplitude exagerada para ser vista de longe
        if name == "LeftShoulder" or name == "RightHip" then
            local move = math.sin(cycle) * 1.5
            local lift = math.max(0, math.cos(cycle)) * 0.8
            target = target * CFrame.new(0, lift, move) * CFrame.Angles(move * 0.8, 0, 0)
        elseif name == "RightShoulder" or name == "LeftHip" then
            local move = math.sin(cycle + math.pi) * 1.5
            local lift = math.max(0, math.cos(cycle + math.pi)) * 0.8
            target = target * CFrame.new(0, lift, move) * CFrame.Angles(move * 0.8, 0, 0)
        elseif name == "Root" or name == "Waist" then
            target = target * CFrame.new(sway * 0.5, -0.25 + verticalBob, 0) * CFrame.Angles(0, -sway, 0)
        elseif name == "Neck" then
            target = target * CFrame.Angles(0, sway * 1.8, 0)
        end
        
        motor.C0 = motor.C0:Lerp(target, math.clamp(dt * 12, 0, 1))
    end
end

-- ==============================
-- CABEÇA OLHA PRA CÂMERA (Versão Melhorada)
-- ==============================
local neckRotation = CFrame.identity -- Para suavização

local function atualizarCabeca(char, surfaceNormal)
    local neck = nil
    
    -- No R15, o Neck costuma ser filho do UpperTorso
    local upperTorso = char:FindFirstChild("UpperTorso")
    if upperTorso then
        neck = upperTorso:FindFirstChild("Neck")
    end
    
    -- Se não achou, tenta no Head (comum no R6)
    if not neck then
        local head = char:FindFirstChild("Head")
        if head then
            neck = head:FindFirstChild("Neck")
        end
    end
    
    if not neck or not neck:IsA("Motor6D") then return end
    
    local torsoParent = neck.Part0
    if not torsoParent then return end
    
    -- 1. Pega a direção da câmera no mundo
    local camLook = camera.CFrame.LookVector
    
    -- 2. Converte essa direção para o espaço local do TORSO
    local localLook = torsoParent.CFrame:VectorToObjectSpace(camLook)
    
    -- 3. Calcula os ângulos
    -- No Roblox, a frente padrão do torso é -Z
    -- Queremos girar o pescoço para que a cabeça aponte para localLook
    local yaw = math.atan2(-localLook.X, -localLook.Z)
    local pitch = math.asin(math.clamp(localLook.Y, -0.9, 0.9))
    
    -- Limites (Lagatixas têm pescoços flexíveis, mas não 360)
    yaw = math.clamp(yaw, -math.rad(80), math.rad(80))
    pitch = math.clamp(pitch, -math.rad(60), math.rad(60))
    
    -- 4. Suavização (Lerp) para não ser instantâneo e tremer
    local targetRot = CFrame.Angles(pitch, yaw, 0)
    neckRotation = neckRotation:Lerp(targetRot, 0.2)
    
    -- 5. Aplica sobre a C0 ORIGINAL que salvamos no ligar()
    -- Se não estiver no bodyMotors (algo deu errado), usa a C0 atual (risco de drift)
    local baseC0 = neck.C0
    if bodyMotors["Neck"] then
        baseC0 = bodyMotors["Neck"].originalC0
    end
    
    neck.C0 = baseC0 * neckRotation
end

-- ==============================
-- CONTROLES MOBILE COM SETAS
-- ==============================
local function criarControlesMobile()
    local gui = player.PlayerGui:FindFirstChild("LagatixaGUI")
    if not gui then return end

    local controls = Instance.new("Frame")
    controls.Name = "MobileControls"
    controls.Size = UDim2.new(1, 0, 1, 0)
    controls.BackgroundTransparency = 1
    controls.Parent = gui

    local moveX = 0
    local moveZ = 0
    local wantsJump = false

    local function criarSeta(nome, texto, posX, posY, parentFrame)
        local btn = Instance.new("TextButton")
        btn.Name = nome
        btn.Size = UDim2.new(0, 65, 0, 65)
        btn.Position = UDim2.new(0, posX, 0, posY)
        btn.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
        btn.BackgroundTransparency = 0.3
        btn.BorderSizePixel = 0
        btn.Text = texto
        btn.TextSize = 32
        btn.TextColor3 = Color3.fromRGB(200, 220, 255)
        btn.Font = Enum.Font.GothamBold
        btn.Parent = parentFrame
        btn.AutoButtonColor = false

        local corner = Instance.new("UICorner", btn)
        corner.CornerRadius = UDim.new(0, 12)

        local stroke = Instance.new("UIStroke", btn)
        stroke.Color = Color3.fromRGB(0, 150, 255)
        stroke.Thickness = 2
        stroke.Transparency = 0.4

        return btn
    end

    -- D-PAD
    local dpadFrame = Instance.new("Frame")
    dpadFrame.Name = "DPad"
    dpadFrame.Size = UDim2.new(0, 220, 0, 220)
    dpadFrame.Position = UDim2.new(0, 20, 1, -240)
    dpadFrame.BackgroundTransparency = 1
    dpadFrame.ZIndex = 10
    dpadFrame.Parent = controls

    local btnCima   = criarSeta("Cima",   "▲", 70, 0,   dpadFrame)
    local btnBaixo  = criarSeta("Baixo",  "▼", 70, 140, dpadFrame)
    local btnEsq    = criarSeta("Esq",    "◀", 0,  70,  dpadFrame)
    local btnDir    = criarSeta("Dir",     "▶", 140, 70, dpadFrame)

    local centro = Instance.new("Frame")
    centro.Size = UDim2.new(0, 55, 0, 55)
    centro.Position = UDim2.new(0, 75, 0, 75)
    centro.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    centro.BackgroundTransparency = 0.5
    centro.BorderSizePixel = 0
    centro.Parent = dpadFrame
    Instance.new("UICorner", centro).CornerRadius = UDim.new(0, 10)

    -- BOTÃO PULO
    local jumpBtn = Instance.new("TextButton")
    jumpBtn.Name = "JumpBtn"
    jumpBtn.Size = UDim2.new(0, 90, 0, 90)
    jumpBtn.Position = UDim2.new(1, -120, 1, -160)
    jumpBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
    jumpBtn.BackgroundTransparency = 0.2
    jumpBtn.BorderSizePixel = 0
    jumpBtn.Text = "⬆"
    jumpBtn.TextSize = 42
    jumpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    jumpBtn.Font = Enum.Font.GothamBold
    jumpBtn.AutoButtonColor = false
    jumpBtn.Parent = controls

    Instance.new("UICorner", jumpBtn).CornerRadius = UDim.new(1, 0)
    local jumpStroke = Instance.new("UIStroke", jumpBtn)
    jumpStroke.Color = Color3.fromRGB(0, 255, 150)
    jumpStroke.Thickness = 3

    local jumpLabel = Instance.new("TextLabel")
    jumpLabel.Size = UDim2.new(1, 0, 0, 20)
    jumpLabel.Position = UDim2.new(0, 0, 1, 5)
    jumpLabel.BackgroundTransparency = 1
    jumpLabel.Text = "PULO"
    jumpLabel.TextColor3 = Color3.fromRGB(0, 220, 120)
    jumpLabel.TextSize = 14
    jumpLabel.Font = Enum.Font.GothamBold
    jumpLabel.Parent = jumpBtn
    jumpBtn.ZIndex = 10

    -- ESTADO DAS SETAS
    local pressing = { Cima = false, Baixo = false, Esq = false, Dir = false }

    local function atualizarMove()
        moveZ = 0
        moveX = 0
        if pressing.Cima then moveZ = moveZ + 1 end
        if pressing.Baixo then moveZ = moveZ - 1 end
        if pressing.Esq then moveX = moveX - 1 end
        if pressing.Dir then moveX = moveX + 1 end
    end

    local corNormal  = Color3.fromRGB(30, 30, 50)
    local corPress   = Color3.fromRGB(0, 120, 255)

    local function conectarSeta(btn, nome)
        btn.MouseButton1Down:Connect(function()
            pressing[nome] = true
            btn.BackgroundColor3 = corPress
            btn.BackgroundTransparency = 0.1
            atualizarMove()
        end)
        
        -- Garante que o movimento pare mesmo se o dedo sair do botão
        btn.MouseButton1Up:Connect(function()
            pressing[nome] = false
            btn.BackgroundColor3 = corNormal
            btn.BackgroundTransparency = 0.3
            atualizarMove()
        end)
        
        btn.MouseLeave:Connect(function()
            if pressing[nome] then
                pressing[nome] = false
                btn.BackgroundColor3 = corNormal
                btn.BackgroundTransparency = 0.3
                atualizarMove()
            end
        end)
    end

    conectarSeta(btnCima,  "Cima")
    conectarSeta(btnBaixo, "Baixo")
    conectarSeta(btnEsq,   "Esq")
    conectarSeta(btnDir,    "Dir")

    jumpBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            wantsJump = true
            jumpBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
            jumpBtn.BackgroundTransparency = 0.1
        end
    end)
    jumpBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            wantsJump = false
            jumpBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
            jumpBtn.BackgroundTransparency = 0.2
        end
    end)

    return {
        getMoveX = function() return moveX end,
        getMoveZ = function() return moveZ end,
        getJump = function() return wantsJump end,
        resetJump = function() wantsJump = false end,
        destroy = function() controls:Destroy() end,
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

    -- Para animações padrão do Roblox
    local animate = char:FindFirstChild("Animate")
    if animate then
        animate.Disabled = true
    end

    -- Para todas as animações atuais
    for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
        track:Stop(0)
    end

    -- Limpeza de acessórios indesejados
    removerRabo(char)
    
    -- Encontra os motors para animação manual
    encontrarMotors(char)
    
    hum.PlatformStand = true
    hum.AutoRotate = false -- CRÍTICO: Para os outros verem sua rotação correta
    hrp.Anchored = false

    local bodyVel = Instance.new("BodyVelocity")
    bodyVel.MaxForce = Vector3.new(1, 1, 1) * 1e8 -- Força bruta para replicação
    bodyVel.Velocity = Vector3.zero
    bodyVel.Parent = hrp

    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(1, 1, 1) * 1e8 -- Força bruta para replicação
    bodyGyro.P = 10000
    bodyGyro.D = 800
    bodyGyro.CFrame = hrp.CFrame
    bodyGyro.Parent = hrp

    mobileControls = criarControlesMobile()
    if not mobileControls then
        warn("Erro ao criar controles mobile!")
        return
    end

    local surfaceNormal = Vector3.new(0, 1, 0)
    local verticalVelocity = 0
    local isGrounded = false
    local canJump = true
    local currentForward = Vector3.new(0, 0, -1)
    local jumpingFromSurface = false
    local jumpSurfaceNormal = Vector3.new(0, 1, 0)

    loop = RunService.Heartbeat:Connect(function(dt)
        if not ativo then return end
        if not char or not char.Parent then return end
        if not hrp or not hrp.Parent then return end

        local mx = mobileControls.getMoveX()
        local mz = mobileControls.getMoveZ()
        local wantsJump = mobileControls.getJump()

        -- Determina se está se movendo (Prioridade para MoveDirection - Mobile/PC)
        local inputMove = Vector3.new(mx, 0, mz)
        local realMove = hum.MoveDirection
        local isMoving = inputMove.Magnitude > 0.1 or realMove.Magnitude > 0.1
        
        -- Atualiza estado da animação
        animState.isMoving = isMoving
        animState.moveSpeed = math.max(inputMove.Magnitude, realMove.Magnitude)
        
        -- Força o estado Physics para replicação de orientação
        hum:ChangeState(Enum.HumanoidStateType.Physics)
        
        -- Anima o personagem apenas quando estiver se movendo
        if isMoving then
            animarPersonagem(dt, isMoving, animState.moveSpeed)
        else
            animarPersonagem(dt, false, 0)
        end

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

        local moveDirWorld = forward * mz + right * mx
        local isMovingWorld = moveDirWorld.Magnitude > 0.1

        if isMovingWorld then
            currentForward = moveDirWorld.Unit
        else
            -- QUANDO PARADO: corpo olha na direção da câmera (projetada na superfície)
            local camForward = (camLook - camLook:Dot(surfaceNormal) * surfaceNormal)
            if camForward.Magnitude > 0.01 then
                currentForward = currentForward:Lerp(camForward.Unit, dt * 5)
                if currentForward.Magnitude > 0 then
                    currentForward = currentForward.Unit
                end
            end
        end

        -- MOVIMENTO LATERAL
        local lateralVel = Vector3.zero
        if isMovingWorld then
            lateralVel = moveDirWorld.Unit * WALK_SPEED
        end

        -- DETECÇÃO DE SUPERFÍCIE
        local hit, dist = raycastChao(hrp.Position, char)

        local isFloor = false
        if hit then
            isFloor = hit.Normal:Dot(Vector3.new(0, 1, 0)) > 0.8
        end

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
                jumpingFromSurface = false

                local stickForce = (hit.Position + hit.Normal * STICK_DIST - hrp.Position) * 10
                bodyVel.Velocity = lateralVel + stickForce
            else
                isGrounded = false

                if jumpingFromSurface then
                    verticalVelocity = verticalVelocity - GRAVITY * dt
                    bodyVel.Velocity = lateralVel + jumpSurfaceNormal * verticalVelocity
                else
                    verticalVelocity = verticalVelocity - GRAVITY * dt
                    bodyVel.Velocity = lateralVel + surfaceNormal * verticalVelocity
                end
            end
        else
            isGrounded = false

            if jumpingFromSurface then
                verticalVelocity = verticalVelocity - GRAVITY * dt
                bodyVel.Velocity = lateralVel + jumpSurfaceNormal * verticalVelocity

                if verticalVelocity < -JUMP_POWER * 2 then
                    jumpingFromSurface = false
                end
            else
                verticalVelocity = verticalVelocity - GRAVITY * dt
                bodyVel.Velocity = lateralVel + Vector3.new(0, verticalVelocity, 0)
                surfaceNormal = surfaceNormal:Lerp(Vector3.new(0, 1, 0), dt * 5)
            end
        end

        -- ============================
        -- PULO
        -- ============================
        if wantsJump and isGrounded and canJump then
            if isFloor then
                verticalVelocity = JUMP_POWER
                isGrounded = false
                jumpingFromSurface = false
            else
                jumpSurfaceNormal = surfaceNormal
                verticalVelocity = JUMP_POWER
                isGrounded = false
                jumpingFromSurface = true
            end

            canJump = false
            mobileControls.resetJump()
            task.delay(0.3, function()
                canJump = true
            end)
        end

        -- ============================
        -- ORIENTAÇÃO DO CORPO
        -- ============================
        local upVec = surfaceNormal
        local lookVec = currentForward

        lookVec = (lookVec - lookVec:Dot(upVec) * upVec)
        if lookVec.Magnitude > 0.01 then
            lookVec = lookVec.Unit
        else
            lookVec = forward
        end

        local rightVec = lookVec:Cross(upVec)
        if rightVec.Magnitude > 0.01 then
            rightVec = rightVec.Unit
        else
            rightVec = Vector3.new(1, 0, 0)
        end
        lookVec = upVec:Cross(rightVec).Unit

        local targetCF = CFrame.fromMatrix(hrp.Position, rightVec, upVec, -lookVec)
        bodyGyro.CFrame = targetCF

        -- ============================
        -- CABEÇA OLHA PRA CÂMERA
        -- ============================
        atualizarCabeca(char, surfaceNormal)
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

        -- Reativa script de animação
        local animate = char:FindFirstChild("Animate")
        if animate then
            animate.Disabled = false
        end

        -- Reseta os motors para posição original
        for motorName, data in pairs(bodyMotors) do
            if data.motor then
                data.motor.C0 = data.originalC0
                data.motor.C1 = data.originalC1
            end
        end
        
        -- Limpa a tabela de motors
        bodyMotors = {}

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
    
    -- Reseta estado da animação
    animState = {
        time = 0,
        isMoving = false,
        moveSpeed = 0,
        isGrounded = true,
        verticalVelocity = 0,
        phase = "idle"
    }
    animationTime = 0
    neckRotation = CFrame.identity
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
    gui.DisplayOrder = 100
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
    title.Text = "🦎 LAGATIXA v10.2"
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

print("[LAGATIXA v10.2] Pronto! Animação manual ativada por movimento")
Já fiz de tudo e o movimento so é visivel para mim, os outros players não veem a animação.
