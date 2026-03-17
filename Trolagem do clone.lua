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
    phase = "idle",
    tailSegments = {} -- Guarda as partes do rabo para limpar depois
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
local bodyMotors = {} -- Tabela para guardar os Motor6D e suas C0 originais
local animationTime = 0

local function encontrarMotors(char)
    bodyMotors = {}
    local motorNames = {
        "Left Shoulder", "Right Shoulder", "Left Hip", "Right Hip",
        "Neck", "Waist" -- Para R6, se for R15, são outros nomes
    }
    
    -- Para R15 Completo
    local r15Motors = {
        "LeftShoulder", "RightShoulder", "LeftHip", "RightHip",
        "Neck", "Waist", "Root", "LeftElbow", "RightElbow", "LeftKnee", "RightKnee",
        "LeftWrist", "RightWrist", "LeftAnkle", "RightAnkle"
    }
    
    -- Tenta encontrar os motors no personagem
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("Motor6D") then
            local motorName = part.Name
            -- Verifica se é um motor que queremos animar
            for _, name in ipairs(r15Motors) do
                if motorName == name then
                    bodyMotors[motorName] = {
                        motor = part,
                        originalC0 = part.C0,
                        originalC1 = part.C1
                    }
                    break
                end
            end
        elseif part.Name:find("TailSegMotor") then
            -- Captura os motores do rabo criado procedimentalmente
            bodyMotors[part.Name] = {
                motor = part,
                originalC0 = part.C0,
                originalC1 = part.C1
            }
        end
    end
end

-- ==============================
-- GERADOR DE RABO (TRANSFORMA CABELO)
-- ==============================
local function criarRabo(char)
    -- Limpa rabo anterior se existir
    for _, obj in ipairs(animState.tailSegments) do
        if obj then obj:Destroy() end
    end
    animState.tailSegments = {}

    local corRabo = Color3.fromRGB(50, 70, 50) -- Cor padrão (verde escuro)
    
    -- Tenta pegar a cor do cabelo para o rabo
    for _, acc in ipairs(char:GetChildren()) do
        if acc:IsA("Accessory") then
            local handle = acc:FindFirstChild("Handle")
            if handle and (acc.Name:lower():find("hair") or handle:FindFirstChildOfClass("SpecialMesh")) then
                corRabo = handle.Color
                handle.Transparency = 1 
            end
        end
    end

    local parent = char:FindFirstChild("LowerTorso") or char:FindFirstChild("Torso")
    if not parent then return end

    local lastPart = parent
    local segments = 6 -- Um pouco mais longo
    local config = {
        sizeStart = 0.7,
        sizeEnd = 0.15,
        length = 0.5
    }

    for i = 1, segments do
        local seg = Instance.new("Part")
        seg.Name = "LizardTailSeg" .. i
        seg.Size = Vector3.new(
            config.sizeStart - (i * (config.sizeStart - config.sizeEnd) / segments),
            config.sizeStart - (i * (config.sizeStart - config.sizeEnd) / segments),
            config.length
        )
        seg.Color = corRabo
        seg.Material = Enum.Material.SmoothPlastic
        seg.CanCollide = false
        seg.Massless = true
        seg.Parent = char
        
        local mesh = Instance.new("SpecialMesh", seg)
        mesh.MeshType = Enum.MeshType.Sphere 
        
        local motor = Instance.new("Motor6D")
        motor.Name = "TailSegMotor" .. i
        motor.Part0 = lastPart
        motor.Part1 = seg
        
        if i == 1 then
            motor.C0 = CFrame.new(0, -0.2, 0.5) * CFrame.Angles(math.rad(-15), 0, 0)
        else
            motor.C0 = CFrame.new(0, 0, config.length * 0.8)
        end
        motor.C1 = CFrame.new(0, 0, -config.length * 0.2)
        
        motor.Parent = lastPart
        lastPart = seg
        table.insert(animState.tailSegments, seg)
    end
end

local function animarPersonagem(dt, isMoving, moveSpeed)
    local breathing = math.sin(tick() * 1.5) * 0.015
    local twitch = math.noise(tick() * 5, 0, 0) * 0.02 -- Micro-tremor aleatório
    
    -- Atualiza o tempo da animação (sempre rodando para o rabo)
    local cycleSpeed = isMoving and (12 + (moveSpeed * 6)) or 3
    animationTime = animationTime + dt * cycleSpeed
    
    local sin = math.sin(animationTime)
    local cos = math.cos(animationTime)
    
    -- Configurações de amplitude
    local walkSwing = math.rad(30)
    local walkSplay = math.rad(18)
    local spineSway = math.rad(12)
    local bobAmount = 0.12
    
    for motorName, data in pairs(bodyMotors) do
        local motor = data.motor
        local originalC0 = data.originalC0
        local targetOffset = CFrame.identity
        
        if motorName:find("TailSegMotor") then
            -- ANIMAÇÃO DO RABO (Sempre ativa)
            local segIndex = tonumber(motorName:match("%d+"))
            local wave = math.sin(animationTime - (segIndex * 0.6))
            local intensity = isMoving and (math.rad(15) + (moveSpeed * math.rad(15))) or math.rad(8)
            targetOffset = CFrame.Angles(0, wave * intensity, 0)
        elseif not isMoving then
            -- Lógica IDLE para outros membros
            if motorName == "LeftShoulder" or motorName == "RightShoulder" then
                local side = (motorName == "LeftShoulder" and -1 or 1)
                targetOffset = CFrame.Angles(math.rad(5) + breathing, twitch, side * math.rad(15))
            elseif motorName == "LeftWrist" or motorName == "RightWrist" then
                targetOffset = CFrame.Angles(0, 0, (motorName == "LeftWrist" and 1 or -1) * math.rad(10))
            elseif motorName == "LeftHip" or motorName == "RightHip" then
                local side = (motorName == "LeftHip" and -1 or 1)
                targetOffset = CFrame.Angles(math.rad(-10) - breathing, -twitch, side * math.rad(10))
            elseif motorName == "LeftAnkle" or motorName == "RightAnkle" then
                targetOffset = CFrame.Angles(math.rad(15), 0, 0)
            elseif motorName == "Root" then
                targetOffset = CFrame.new(0, -0.15 + breathing, 0)
            end
        else
            -- Lógica WALKING para outros membros
            if motorName == "LeftShoulder" then
                targetOffset = CFrame.Angles(sin * walkSwing, 0, -walkSplay - (cos * math.rad(10)))
            elseif motorName == "RightShoulder" then
                targetOffset = CFrame.Angles(-sin * walkSwing, 0, walkSplay + (cos * math.rad(10)))
            elseif motorName == "LeftWrist" or motorName == "RightWrist" then
                local side = (motorName == "LeftWrist" and 1 or -1)
                local rot = (motorName == "LeftWrist" and sin or -sin)
                targetOffset = CFrame.Angles(math.rad(10), rot * 0.2, side * math.rad(15))
            elseif motorName == "LeftHip" then
                targetOffset = CFrame.Angles(-sin * walkSwing, 0, -walkSplay + (cos * math.rad(10)))
            elseif motorName == "RightHip" then
                targetOffset = CFrame.Angles(sin * walkSwing, 0, walkSplay - (cos * math.rad(10)))
            elseif motorName == "LeftAnkle" or motorName == "RightAnkle" then
                local rot = (motorName == "LeftAnkle" and -sin or sin)
                targetOffset = CFrame.Angles(rot * 0.4, 0, 0)
            elseif motorName == "LeftElbow" or motorName == "RightElbow" then
                local phase = (motorName == "LeftElbow") and sin or -sin
                local flexion = (phase > 0) and (phase * math.rad(35)) or 0
                targetOffset = CFrame.Angles(-math.rad(20) - flexion, 0, 0)
            elseif motorName == "LeftKnee" or motorName == "RightKnee" then
                local phase = (motorName == "LeftKnee") and -sin or sin
                local flexion = (phase > 0) and (phase * math.rad(35)) or 0
                targetOffset = CFrame.Angles(math.rad(20) + flexion, 0, 0)
            elseif motorName == "Root" then
                local vBob = math.abs(cos) * bobAmount
                targetOffset = CFrame.new(0, -0.1 + vBob, 0) * CFrame.Angles(0, cos * spineSway, 0)
            elseif motorName == "Waist" then
                targetOffset = CFrame.Angles(0, cos * (spineSway * 0.5), 0)
            elseif motorName == "Neck" then
                targetOffset = CFrame.Angles(0, -cos * (spineSway * 1.5), 0)
            end
        end
        
        -- Garante que o motor seja atualizado com lerp
        motor.C0 = motor.C0:Lerp(originalC0 * targetOffset, 0.35)
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
    dpadFrame.Size = UDim2.new(0, 205, 0, 205)
    dpadFrame.Position = UDim2.new(0, 15, 1, -220)
    dpadFrame.BackgroundTransparency = 1
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
        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                pressing[nome] = true
                btn.BackgroundColor3 = corPress
                btn.BackgroundTransparency = 0.1
                atualizarMove()
            end
        end)
        btn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
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

    -- Cria o rabo procedimental antes de encontrar os motors
    criarRabo(char)
    
    -- Encontra os motors para animação manual (inclusive os do rabo agora)
    encontrarMotors(char)
    
    hum.PlatformStand = true
    hrp.Anchored = false

    local bodyVel = Instance.new("BodyVelocity")
    bodyVel.MaxForce = Vector3.new(4e4, 4e4, 4e4)
    bodyVel.Velocity = Vector3.zero
    bodyVel.Parent = hrp

    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(4e4, 4e4, 4e4)
    bodyGyro.P = 3000
    bodyGyro.D = 500
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

        -- Determina se está se movendo
        local moveDir = Vector3.new(mx, 0, mz)
        local isMoving = moveDir.Magnitude > 0.1
        
        -- Atualiza estado da animação
        animState.isMoving = isMoving
        animState.moveSpeed = math.min(moveDir.Magnitude, 1)
        
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
        
        -- Limpa o rabo
        for _, seg in ipairs(animState.tailSegments) do
            if seg then seg:Destroy() end
        end

        -- Mostra o cabelo de volta (targeting hair specifically)
        for _, acc in ipairs(char:GetChildren()) do
            if acc:IsA("Accessory") then
                local handle = acc:FindFirstChild("Handle")
                if handle and (acc.Name:lower():find("hair") or handle:FindFirstChildOfClass("SpecialMesh")) then
                    handle.Transparency = 0 
                end
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
    
    -- Reseta estado da animação mantendo a referência se necessário
    animState.tailSegments = {}
    animState.time = 0
    animState.isMoving = false
    animState.moveSpeed = 0
    
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
