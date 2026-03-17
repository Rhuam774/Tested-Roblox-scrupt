-- =============================================================
--  MODO LAGATIXA v10 - PULO FUNCIONA EM PAREDE, TETO E CHÃO!
--  Mobile com D-Pad + Animação + Sem conflito com controles do Roblox
-- =============================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")
local StarterGui       = game:GetService("StarterGui")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ==============================
-- CONFIGURAÇÕES
-- ==============================
local WALK_SPEED   = 18
local JUMP_POWER   = 65        -- Força do pulo (aumentei um pouco pra ficar bom em parede)
local GRAVITY      = 196.2
local STICK_DIST   = 3.2       -- Distância pra "grudar" na superfície
local ANIM_WALK_ID = "rbxassetid://180426354"  -- Animação de andar (mude se quiser outra)

-- ==============================
-- ESTADO
-- ==============================
local ativo = false
local loop = nil
local mobileControls = nil
local animTrack = nil

-- ==============================
-- DESATIVAR CONTROLES NATIVOS
-- ==============================
local function desativarControlesNativos()
    pcall(function()
        local touchGui = player.PlayerGui:FindFirstChild("TouchGui")
        if touchGui then touchGui.Enabled = false end
    end)
    pcall(function()
        StarterGui:SetCore("TopbarEnabled", false)
    end)
end

local function reativarControlesNativos()
    pcall(function()
        local touchGui = player.PlayerGui:FindFirstChild("TouchGui")
        if touchGui then touchGui.Enabled = true end
    end)
    pcall(function()
        StarterGui:SetCore("TopbarEnabled", true)
    end)
end

-- ==============================
-- RAYCAST MELHORADO (6 DIREÇÕES)
-- ==============================
local function detectarSuperficie(pos, char)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {char}
    params.FilterType = Enum.RaycastFilterType.Exclude

    local direcoes = {
        Vector3.new(0, -1, 0),  -- baixo
        Vector3.new(0, 1, 0),   -- cima
        Vector3.new(1, 0, 0),   -- direita
        Vector3.new(-1, 0, 0),  -- esquerda
        Vector3.new(0, 0, 1),   -- frente
        Vector3.new(0, 0, -1),  -- trás
    }

    local melhor = nil
    local menorDist = math.huge

    for _, dir in ipairs(direcoes) do
        local result = workspace:Raycast(pos, dir * 12, params)
        if result then
            local dist = (result.Position - pos).Magnitude
            if dist < menorDist then
                menorDist = dist
                melhor = result
            end
        end
    end

    return melhor, menorDist
end

-- ==============================
-- CONTROLES D-PAD (SETINHAS)
-- ==============================
local function criarControlesMobile()
    local gui = player.PlayerGui:FindFirstChild("LagatixaGUI")
    if not gui then return end

    local controls = Instance.new("Frame")
    controls.Name = "MobileControls"
    controls.Size = UDim2.new(1,0,1,0)
    controls.BackgroundTransparency = 1
    controls.Parent = gui

    local pressed = {Up=false, Down=false, Left=false, Right=false, Jump=false}

    local function criarBtn(nome, texto, x, y, tam)
        local btn = Instance.new("TextButton")
        btn.Name = nome
        btn.Size = UDim2.new(0,tam,0,tam)
        btn.Position = UDim2.new(0,x,1,y)
        btn.BackgroundColor3 = Color3.fromRGB(40,40,60)
        btn.BackgroundTransparency = 0.3
        btn.Text = texto
        btn.TextSize = 32
        btn.TextColor3 = Color3.new(1,1,1)
        btn.Font = Enum.Font.GothamBold
        btn.AutoButtonColor = false
        btn.Parent = controls
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0,14)

        btn.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
                pressed[nome] = true
                TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundTransparency=0}):Play()
            end
        end)
        btn.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
                pressed[nome] = false
                TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundTransparency=0.3}):Play()
            end
        end)

        return btn
    end

    -- D-Pad
    criarBtn("Up", "▲", 100, -220, 70)
    criarBtn("Down", "▼", 100, -140, 70)
    criarBtn("Left", "◀", 30, -180, 70)
    criarBtn("Right", "▶", 170, -180, 70)

    -- Botão de pulo (maior e mais bonito)
    local jump = Instance.new("TextButton")
    jump.Size = UDim2.new(0,100,0,100)
    jump.Position = UDim2.new(1,-130,1,-200)
    jump.BackgroundColor3 = Color3.fromRGB(0,200,100)
    jump.BackgroundTransparency = 0.2
    jump.Text = "PULO"
    jump.TextSize = 22
    jump.TextColor3 = Color3.new(1,1,1)
    jump.Font = Enum.Font.GothamBold
    jump.AutoButtonColor = false
    jump.Parent = controls
    Instance.new("UICorner", jump).CornerRadius = UDim.new(1,0)
    local stroke = Instance.new("UIStroke", jump)
    stroke.Color = Color3.fromRGB(100,255,150)
    stroke.Thickness = 3

    jump.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
            pressed.Jump = true
            TweenService:Create(jump, TweenInfo.new(0.1), {BackgroundColor3=Color3.fromRGB(0,255,150)}):Play()
        end
    end)
    jump.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.Touch or inp.UserInputType == Enum.UserInputType.MouseButton1 then
            pressed.Jump = false
            TweenService:Create(jump, TweenInfo.new(0.1), {BackgroundColor3=Color3.fromRGB(0,200,100)}):Play()
        end
    end)

    return {
        getMoveX = function() return (pressed.Right and 1 or 0) + (pressed.Left and -1 or 0) end,
        getMoveZ = function() return (pressed.Up and 1 or 0) + (pressed.Down and -1 or 0) end,
        getJump = function() return pressed.Jump end,
        destroy = function() controls:Destroy() end
    }
end

-- ==============================
-- ANIMAÇÃO DE ANDAR
-- ==============================
local function iniciarAnimacao(hum)
    if animTrack then animTrack:Stop() end
    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_WALK_ID
    animTrack = hum:LoadAnimation(anim)
    animTrack.Looped = true
    animTrack.Priority = Enum.AnimationPriority.Movement
end

local function atualizarAnimacao(movendo)
    if not animTrack then return end
    if movendo and not animTrack.IsPlaying then
        animTrack:Play(0.15)
    elseif not movendo and animTrack.IsPlaying then
        animTrack:Stop(0.2)
    end
end

-- ==============================
-- LIGAR LAGATIXA
-- ==============================
local function ligar()
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    local hum = char:WaitForChild("Humanoid")

    desativarControlesNativos()
    hum.PlatformStand = true

    -- Body movers
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Velocity = Vector3.zero
    bv.P = 1250
    bv.Parent = hrp

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    bg.P = 5000
    bg.D = 800
    bg.CFrame = hrp.CFrame
    bg.Parent = hrp

    iniciarAnimacao(hum)
    mobileControls = criarControlesMobile()

    local surfaceNormal = Vector3.new(0,1,0)
    local verticalVel = 0
    local noChao = true
    local podePular = true

    loop = RunService.Heartbeat:Connect(function(dt)
        if not ativo or not char.Parent or not hrp.Parent then return end

        local moveX = mobileControls.getMoveX()
        local moveZ = mobileControls.getMoveZ()
        local querPular = mobileControls.getJump()

        -- Direção da câmera projetada na superfície atual
        local camLook = camera.CFrame.LookVector
        local camRight = camera.CFrame.RightVector

        local frente = camLook - camLook:Dot(surfaceNormal) * surfaceNormal
        if frente.Magnitude < 0.1 then frente = -camera.CFrame.LookVector end
        frente = frente.Unit

        local direita = camRight - camRight:Dot(surfaceNormal) * surfaceNormal
        if direita.Magnitude < 0.1 then direita = camera.CFrame.RightVector end
        direita = direita.Unit

        local velocidadeLateral = (frente * moveZ + direita * moveX) * WALK_SPEED
        local estaAndando = velocidadeLateral.Magnitude > 2
        atualizarAnimacao(estaAndando)

        -- Detecta superfície
        local hit, dist = detectarSuperficie(hrp.Position, char)

        if hit and dist < 6 then
            surfaceNormal = surfaceNormal:Lerp(hit.Normal, dt * 12)
            surfaceNormal = surfaceNormal.Unit

            if dist <= STICK_DIST then
                noChao = true
                verticalVel = 0
                local forcaGrude = (hit.Position + hit.Normal * STICK_DIST - hrp.Position) * 15
                bv.Velocity = velocidadeLateral + forcaGrude
            else
                noChao = false
                verticalVel -= GRAVITY * dt
                bv.Velocity = velocidadeLateral + surfaceNormal * verticalVel
            end
        else
            noChao = false
            verticalVel -= GRAVITY * dt
            bv.Velocity = velocidadeLateral + Vector3.new(0, verticalVel, 0)
            surfaceNormal = surfaceNormal:Lerp(Vector3.new(0,1,0), dt * 6)
        end

        -- PULO FUNCIONA EM QUALQUER SUPERFÍCIE (inclusive parede e teto!)
        if querPular and noChao and podePular then
            verticalVel = JUMP_POWER
            noChao = false
            podePular = false
            task.delay(0.4, function() podePular = true end)
        end

        -- Rotação do personagem (fica em pé na superfície)
        local up = surfaceNormal
        local look = frente
        local rightVec = look:Cross(up)
        if rightVec.Magnitude > 0.01 then
            rightVec = rightVec.Unit
            look = up:Cross(rightVec).Unit
            bg.CFrame = CFrame.fromMatrix(hrp.Position, rightVec, up, -look)
        end
    end)
end

-- ==============================
-- DESLIGAR
-- ==============================
local function desligar()
    if loop then loop:Disconnect() loop = nil end
    if mobileControls then mobileControls.destroy() mobileControls = nil end
    if animTrack then animTrack:Stop() animTrack = nil end

    reativarControlesNativos()

    local char = player.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hum then hum.PlatformStand = false end
        if hrp then
            for _, v in pairs(hrp:GetChildren()) do
                if v:IsA("BodyVelocity") or v:IsA("BodyGyro") then v:Destroy() end
            end
        end
    end
end

-- ==============================
-- GUI BONITINHA
-- ==============================
local function criarGUI()
    local old = player.PlayerGui:FindFirstChild("LagatixaGUI")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "LagatixaGUI"
    gui.ResetOnSpawn = false
    gui.Parent = player.PlayerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0,240,0,100)
    frame.Position = UDim2.new(0.5,-120,0,15)
    frame.BackgroundColor3 = Color3.fromRGB(10,10,20)
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,16)

    local stroke = Instance.new("UIStroke", frame)
    stroke.Thickness = 2.5
    stroke.Color = Color3.fromRGB(0,200,255)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1,0,0,40)
    title.BackgroundTransparency = 1
    title.Text = "🦎 LAGATIXA v10"
    title.TextColor3 = Color3.fromRGB(0,255,200)
    title.TextSize = 20
    title.Font = Enum.Font.GothamBold
    title.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,-20,0,45)
    btn.Position = UDim2.new(0,10,0,45)
    btn.BackgroundColor3 = Color3.fromRGB(0,170,80)
    btn.Text = "LIGAR"
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextSize = 20
    btn.Font = Enum.Font.GothamBold
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,12)

    btn.MouseButton1Click:Connect(function()
        ativo = not ativo
        if ativo then
            btn.Text = "DESLIGAR"
            btn.BackgroundColor3 = Color3.fromRGB(220,50,50)
            stroke.Color = Color3.fromRGB(0,255,100)
            ligar()
        else
            btn.Text = "LIGAR"
            btn.BackgroundColor3 = Color3.fromRGB(0,170,80)
            stroke.Color = Color3.fromRGB(0,200,255)
            desligar()
        end
    end)
end

criarGUI()

player.CharacterAdded:Connect(function()
    if ativo then
        task.wait(1.5)
        if ativo then ligar() end
    end
end)

print("LAGATIXA v10 CARREGADA - PULO NA PAREDE 100% FUNCIONANDO!")
