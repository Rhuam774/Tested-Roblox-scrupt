-- =============================================================
--  MODO LAGATIXA  v10.1  -  ANIMAÇÃO PROCEDURAL
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
-- SISTEMA DE ANIMAÇÃO PROCEDURAL
-- ==============================
local function criarAnimacaoProcedural(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    -- Encontra todas as partes do corpo
    local bodyParts = {}
    local partNames = {
        "LeftUpperArm", "LeftLowerArm", "LeftHand",
        "RightUpperArm", "RightLowerArm", "RightHand",
        "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
        "RightUpperLeg", "RightLowerLeg", "RightFoot",
        "UpperTorso", "LowerTorso"
    }
    
    for _, name in ipairs(partNames) do
        local part = char:FindFirstChild(name)
        if part then
            bodyParts[name] = {
                part = part,
                originalC0 = part:FindFirstChild("Motor6D") and part:FindFirstChild("Motor6D").C0 or CFrame.new(),
                motor = part:FindFirstChild("Motor6D")
            }
        end
    end
    
    return bodyParts
end

local function animarMembros(bodyParts, dt, animState)
    if not bodyParts then return end
    
    animState.time = animState.time + dt * animState.moveSpeed
    
    -- Para cada membro, aplicar uma animação procedural
    for partName, data in pairs(bodyParts) do
        if data.motor then
            local offset = CFrame.new()
            local rotOffset = CFrame.Angles(0, 0, 0)
            
            -- Lógica de animação baseada no tipo de membro
            if string.find(partName, "Arm") then
                -- Braços: balançar como um réptil
                local swingAmount = math.sin(animState.time * 8) * 0.3
                if animState.phase == "walk" then
                    if string.find(partName, "Left") then
                        rotOffset = CFrame.Angles(swingAmount, 0, swingAmount * 0.5)
                    else
                        rotOffset = CFrame.Angles(-swingAmount, 0, -swingAmount * 0.5)
                    end
                end
                
            elseif string.find(partName, "Leg") then
                -- Pernas: movimento alternado
                local stepAmount = math.sin(animState.time * 8) * 0.4
                if animState.phase == "walk" then
                    if string.find(partName, "Left") then
                        rotOffset = CFrame.Angles(stepAmount, 0, 0)
                    else
                        rotOffset = CFrame.Angles(-stepAmount, 0, 0)
                    end
                end
                
            elseif partName == "UpperTorso" then
                -- Torso: leve rotação
                local torsoTwist = math.sin(animState.time * 4) * 0.1
                if animState.phase == "walk" then
                    rotOffset = CFrame.Angles(0, torsoTwist, 0)
                end
            end
            
            -- Aplicar animação
            local finalC0 = data.originalC0 * rotOffset
            data.motor.C0 = finalC0
        end
    end
end

-- ==============================
-- CABEÇA OLHA PRA CÂMERA (Versão Melhorada)
-- ==============================
local function atualizarCabeca(char, surfaceNormal)
    local neck = nil
    local head = char:FindFirstChild("Head")
    
    if head then
        for _, obj in ipairs(head:GetChildren()) do
            if obj:IsA("Motor6D") and obj.Name == "Neck" then
                neck = obj
                break
            end
        end
    end
    
    if not neck then
        local upperTorso = char:FindFirstChild("UpperTorso")
        if upperTorso then
            for _, obj in ipairs(upperTorso:GetChildren()) do
                if obj:IsA("Motor6D") and obj.Name == "Neck" then
                    neck = obj
                    break
                end
            end
        end
    end
    
    if not neck then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    -- Direção da câmera relativa ao corpo, considerando a normal da superfície
    local camLook = camera.CFrame.LookVector
    
    -- Projeta o look vector no plano da superfície para evitar rotações verticais indesejadas
    local projectedLook = camLook - camLook:Dot(surfaceNormal) * surfaceNormal
    if projectedLook.Magnitude > 0.01 then
        projectedLook = projectedLook.Unit
    else
        projectedLook = Vector3.new(0, 0, -1)
    end
    
    -- Converte para espaço local do torso
    local torsoParent = neck.Part0
    if not torsoParent then return end
    
    local torsoCF = torsoParent.CFrame
    local localLook = torsoCF:VectorToObjectSpace(projectedLook)
    
    -- Calcula ângulos (apenas yaw para evitar rotações verticais estranhas)
    local yaw = math.atan2(-localLook.X, -localLook.Z)
    
    -- Limita os ângulos
    yaw = math.clamp(yaw, -math.rad(70), math.rad(70))
    
    -- Aplica no C0 do Neck (preservando a posição original)
    local originalC0 = CFrame.new(0, 1, 0)
    
    local rotacao = CFrame.Angles(0, yaw, 0) -- Sem pitch para evitar inclinações verticais
    neck.C0 = originalC0 * rotacao
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

    -- Cria sistema de animação procedural
    local bodyParts = criarAnimacaoProcedural(char)
    
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

    -- Estado da animação
    local lastMoveTime = tick()

    loop = RunService.Heartbeat:Connect(function(dt)
        if not ativo then return end
        if not char or not char.Parent then return end
        if not hrp or not hrp.Parent then return end

        local mx = mobileControls.getMoveX()
        local mz = mobileControls.getMoveZ()
        local wantsJump = mobileControls.getJump()

        -- Atualiza estado da animação
        local moveDir = Vector3.new(mx, 0, mz)
        local isMoving = moveDir.Magnitude > 0.1
        
        if isMoving then
            animState.isMoving = true
            animState.moveSpeed = math.min(moveDir.Magnitude, 1)
            animState.phase = "walk"
            lastMoveTime = tick()
        elseif tick() - lastMoveTime < 0.5 then
            -- Continua animação por um breve período após parar
            animState.moveSpeed = math.max(0, animState.moveSpeed - dt * 2)
        else
            animState.isMoving = false
            animState.moveSpeed = 0
            animState.phase = "idle"
        end
        
        animState.isGrounded = isGrounded
        animState.verticalVelocity = verticalVelocity
        
        -- Anima os membros proceduralmente
        animarMembros(bodyParts, dt, animState)

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
        -- ORIENTAÇÃO DO CORPO (VERSÃO ESTABILIZADA)
        -- ============================
        local upVec = surfaceNormal
        local lookVec = currentForward

        -- Remove a componente do look vector na direção da normal da superfície
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

        -- Para paredes, mantém o personagem mais "em pé" em relação ao mundo
        -- Isso evita que ele fique totalmente de lado em superfícies verticais
        if upVec:Dot(Vector3.new(0, 1, 0)) < 0.5 then
            -- Estamos em uma superfície inclinada/vertical
            -- Mistura a up vector com a vertical do mundo para uma orientação mais natural
            local blendedUp = upVec:Lerp(Vector3.new(0, 1, 0), 0.3)
            if blendedUp.Magnitude > 0.01 then
                blendedUp = blendedUp.Unit
                rightVec = lookVec:Cross(blendedUp)
                if rightVec.Magnitude > 0.01 then
                    rightVec = rightVec.Unit
                else
                    rightVec = Vector3.new(1, 0, 0)
                end
                lookVec = blendedUp:Cross(rightVec).Unit
                upVec = blendedUp
            end
        end

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

        -- Reseta o Neck
        local function resetNeck(parent)
            if not parent then return end
            for _, obj in ipairs(parent:GetChildren()) do
                if obj:IsA("Motor6D") and obj.Name == "Neck" then
                    local isR6 = char:FindFirstChild("Torso") ~= nil and char:FindFirstChild("UpperTorso") == nil
                    if isR6 then
                        obj.C0 = CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
                    else
                        obj.C0 = CFrame.new(0, 1, 0)
                    end
                end
            end
        end

        resetNeck(char:FindFirstChild("Head"))
        resetNeck(char:FindFirstChild("UpperTorso"))
        resetNeck(char:FindFirstChild("Torso"))

        -- Reseta todos os Motor6D para posição original
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("Motor6D") then
                part.C0 = part.C0 -- Mantém a posição atual, que foi alterada pela animação procedural
            end
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
    
    -- Reseta estado da animação
    animState = {
        time = 0,
        isMoving = false,
        moveSpeed = 0,
        isGrounded = true,
        verticalVelocity = 0,
        phase = "idle"
    }
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
    title.Text = "🦎 LAGATIXA v10.1"
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

print("[LAGATIXA v10.1] Pronto! Animação procedural ativa")
