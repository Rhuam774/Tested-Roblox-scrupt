-- =============================================================
--  MODO LAGATIXA  v5  -  Delta Executor
--  Controlador de personagem proprio: sem BodyGyro, sem BodyVelocity.
--  Define CFrame direto a cada frame. Funciona 100%.
-- =============================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ==============================
-- CONSTANTES
-- ==============================
local WALK_SPEED   = 16     -- velocidade de caminhada (studs/s)
local JUMP_POWER   = 55     -- impulso do pulo (studs/s na direcao da normal)
local GRAV_ACCEL   = 80     -- aceleracao de gravidade em direcao a superficie
local LAND_DIST    = 3.1    -- distancia do HRP ate a superficie quando "no chao"
local RAY_DIST     = 9      -- alcance do raycast de deteccao
local NORMAL_SPEED = 12     -- velocidade de suavizacao da normal (por segundo)
local ANIM_ID      = "rbxassetid://180426354" -- ID da animação de andar (padrão ou custom)

-- ==============================
-- ESTADO
-- ==============================
local ativo    = false
local loop     = nil   -- conexao do Heartbeat

-- Estado do controlador (redefinido ao ativar)
local myPos       = Vector3.zero
local myNormal    = Vector3.new(0, 1, 0)
local myVelN      = 0       -- velocidade no eixo da normal (pulo/queda)
local noChao      = false
local pulando     = false
local animTrack   = nil

-- ==============================
-- RAYCAST: encontra superficie mais proxima
-- Verifica direcao da normal atual E as 5 outras faces locais
-- ==============================
local function detectar(pos, cf, normal, char)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { char }
    local dirs = {
        -normal,           -- principal: direcao atual da gravidade
        -cf.UpVector,
         cf.UpVector,
         cf.LookVector,
        -cf.LookVector,
         cf.RightVector,
        -cf.RightVector,
    }

    local bestDist = math.huge
    local bestNorm = nil
    local bestPt   = nil

    for _, dir in ipairs(dirs) do
        local res = workspace:Raycast(pos, dir * RAY_DIST, params)
        if res then
            local d = (res.Position - pos).Magnitude
            if d < bestDist then
                bestDist = d
                bestNorm = res.Normal
                bestPt   = res.Position
            end
        end
    end

    return bestNorm, bestDist, bestPt
end

-- ==============================
-- CFrame final: personagem 100% em pe na superficie
-- up = normal, look = camera projetada no plano
-- ==============================
local function makeCF(pos, normal, camLook)
    local fwd = camLook - camLook:Dot(normal) * normal
    if fwd.Magnitude < 0.01 then
        local camUp = camera.CFrame.UpVector
        fwd = camUp - camUp:Dot(normal) * normal
    end
    if fwd.Magnitude < 0.01 then
        local arb = math.abs(normal.Y) < 0.9 and Vector3.new(0,1,0) or Vector3.new(1,0,0)
        fwd = arb - arb:Dot(normal) * normal
    end
    fwd = fwd.Unit
    local right = fwd:Cross(normal).Unit
    local look  = normal:Cross(right).Unit
    return CFrame.fromMatrix(pos, right, normal, -look)
end

-- ==============================
-- LIGAR
-- ==============================
local function ligar()
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    -- Para a fisica do Humanoid para ele nao brigar com nossa posicao
    hum.PlatformStand = true

    -- Estado inicial
    myPos    = hrp.Position
    myNormal = Vector3.new(0, 1, 0)
    myVelN   = 0
    noChao   = false
    pulando  = false

    -- Inicializa animação
    if animTrack then animTrack:Stop() end
    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_ID
    animTrack = hum:LoadAnimation(anim)
    animTrack.Looped = true

    loop = RunService.Heartbeat:Connect(function(dt)
        if not ativo then return end

        local c = player.Character
        if not c then return end
        local h = c:FindFirstChild("HumanoidRootPart")
        local u = c:FindFirstChildOfClass("Humanoid")
        if not h or not u then return end

        local mX, mZ = 0, 0
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then mZ = -1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then mZ =  1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then mX = -1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then mX =  1 end

        local camLook  = camera.CFrame.LookVector
        local camRight = camera.CFrame.RightVector
        
        local fwd = camLook - camLook:Dot(myNormal) * myNormal
        if fwd.Magnitude < 0.1 then
            local camUp = camera.CFrame.UpVector
            fwd = camUp - camUp:Dot(myNormal) * myNormal
        end
        
        local rgt = camRight - camRight:Dot(myNormal) * myNormal
        if fwd.Magnitude  > 0.01 then fwd = fwd.Unit  end
        if rgt.Magnitude  > 0.01 then rgt = rgt.Unit  end

        local velLateral = Vector3.zero
        if mX ~= 0 or mZ ~= 0 then
            local dir = fwd * (-mZ) + rgt * mX
            if dir.Magnitude > 0 then
                velLateral = dir.Unit * WALK_SPEED
                if animTrack and not animTrack.IsPlaying then
                    animTrack:Play()
                end
            end
        else
            if animTrack and animTrack.IsPlaying then
                animTrack:Stop()
            end
        end

        -- --------------------------------------------------
        -- 4. PULO
        -- --------------------------------------------------
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) and noChao and not pulando then
            myVelN  = JUMP_POWER
            noChao  = false
            pulando = true
            task.delay(0.55, function() pulando = false end)
        end

        -- --------------------------------------------------
        -- 2. MOVIMENTO E GRAVIDADE
        -- --------------------------------------------------
        myVelN = myVelN - GRAV_ACCEL * dt
        myPos = myPos + myNormal * myVelN * dt + velLateral * dt

        -- --------------------------------------------------
        -- 3. DETECTA SUPERFICIE NA NOVA POSICAO
        -- --------------------------------------------------
        local norm, dist, pt = detectar(myPos, h.CFrame, myNormal, c)

        if norm then
            -- Suaviza normal APENAS quando proximo da superficie
            if dist < RAY_DIST * 0.8 then
                myNormal = myNormal:Lerp(norm, math.min(dt * NORMAL_SPEED, 1))
                if myNormal.Magnitude > 0 then
                    myNormal = myNormal.Unit
                end
            end

            if dist <= LAND_DIST and myVelN <= 0 then
                -- Aterrisou: para queda, posiciona exatamente acima da superficie
                myVelN = 0
                noChao = true
                myPos  = pt + norm * LAND_DIST
                -- Atualiza normal imediatamente ao aterrissar
                myNormal = myNormal:Lerp(norm, 0.4)
                if myNormal.Magnitude > 0 then myNormal = myNormal.Unit end
            else
                noChao = false
            end
        else
            noChao = false
        end

        -- --------------------------------------------------
        -- 4. APLICA POSICAO E ROTACAO DIRETO NO HRP
        -- --------------------------------------------------
        local cf = makeCF(myPos, myNormal, camera.CFrame.LookVector)
        h.CFrame = cf
        -- Zera velocidade fisica para o motor do Roblox nao interferir
        h.AssemblyLinearVelocity  = Vector3.zero
        h.AssemblyAngularVelocity = Vector3.zero
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

    pulando  = false
    noChao   = false
    myVelN   = 0
    myNormal = Vector3.new(0, 1, 0)

    if animTrack then
        animTrack:Stop()
        animTrack = nil
    end

    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hum then hum.PlatformStand = false end
        if hrp then
            hrp.AssemblyLinearVelocity  = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            hrp.CFrame = CFrame.new(hrp.Position)
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
    gui.Name           = "LagatixaGUI"
    gui.ResetOnSpawn   = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent         = player.PlayerGui

    local win = Instance.new("Frame")
    win.Name             = "Janela"
    win.Size             = UDim2.new(0, 240, 0, 140)
    win.Position         = UDim2.new(0, 16, 0.45, 0)
    win.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
    win.BorderSizePixel  = 0
    win.Active           = true
    win.Draggable        = true
    win.Parent           = gui
    Instance.new("UICorner", win).CornerRadius = UDim.new(0, 14)

    local stroke = Instance.new("UIStroke", win)
    stroke.Color = Color3.fromRGB(50, 150, 255)
    stroke.Thickness = 1.8; stroke.Transparency = 0.3

    local grad = Instance.new("UIGradient", win)
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 18, 35)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 20)),
    })
    grad.Rotation = 90

    local topbar = Instance.new("Frame", win)
    topbar.Size = UDim2.new(1, 0, 0, 38)
    topbar.BackgroundColor3 = Color3.fromRGB(20, 22, 48)
    topbar.BorderSizePixel = 0
    Instance.new("UICorner", topbar).CornerRadius = UDim.new(0, 14)
    local fix = Instance.new("Frame", topbar)
    fix.Size = UDim2.new(1,0,0.5,0); fix.Position = UDim2.new(0,0,0.5,0)
    fix.BackgroundColor3 = Color3.fromRGB(20, 22, 48); fix.BorderSizePixel = 0

    local icoLbl = Instance.new("TextLabel", topbar)
    icoLbl.Size = UDim2.new(0,30,1,0); icoLbl.BackgroundTransparency = 1
    icoLbl.Text = "🦎"; icoLbl.TextSize = 18; icoLbl.Font = Enum.Font.Gotham

    local titLbl = Instance.new("TextLabel", topbar)
    titLbl.Size = UDim2.new(1,-42,1,0); titLbl.Position = UDim2.new(0,36,0,0)
    titLbl.BackgroundTransparency = 1; titLbl.Text = "Modo Lagatixa"
    titLbl.TextColor3 = Color3.fromRGB(100,200,255)
    titLbl.TextSize = 14; titLbl.Font = Enum.Font.GothamBold
    titLbl.TextXAlignment = Enum.TextXAlignment.Left

    local dot = Instance.new("Frame", win)
    dot.Size = UDim2.new(0,10,0,10); dot.Position = UDim2.new(0,16,0,52)
    dot.BackgroundColor3 = Color3.fromRGB(160,50,50); dot.BorderSizePixel = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1,0)

    local stLbl = Instance.new("TextLabel", win)
    stLbl.Size = UDim2.new(1,-40,0,20); stLbl.Position = UDim2.new(0,32,0,46)
    stLbl.BackgroundTransparency = 1; stLbl.Text = "Desativado"
    stLbl.TextColor3 = Color3.fromRGB(160,80,80); stLbl.TextSize = 12
    stLbl.Font = Enum.Font.Gotham; stLbl.TextXAlignment = Enum.TextXAlignment.Left

    local btn = Instance.new("TextButton", win)
    btn.Size = UDim2.new(1,-20,0,44); btn.Position = UDim2.new(0,10,0,82)
    btn.BackgroundColor3 = Color3.fromRGB(30,120,70); btn.BorderSizePixel = 0
    btn.Text = "ATIVAR"; btn.TextColor3 = Color3.fromRGB(230,255,235)
    btn.TextSize = 14; btn.Font = Enum.Font.GothamBold; btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,10)
    local bs = Instance.new("UIStroke", btn)
    bs.Color = Color3.fromRGB(60,200,110); bs.Thickness = 1; bs.Transparency = 0.5

    local function updateUI()
        if ativo then
            TweenService:Create(btn,TweenInfo.new(0.18),{BackgroundColor3=Color3.fromRGB(130,30,30)}):Play()
            bs.Color = Color3.fromRGB(220,70,70); btn.Text = "DESATIVAR"
            dot.BackgroundColor3 = Color3.fromRGB(60,210,100)
            stLbl.Text = "Ativado"; stLbl.TextColor3 = Color3.fromRGB(60,210,100)
        else
            TweenService:Create(btn,TweenInfo.new(0.18),{BackgroundColor3=Color3.fromRGB(30,120,70)}):Play()
            bs.Color = Color3.fromRGB(60,200,110); btn.Text = "ATIVAR"
            dot.BackgroundColor3 = Color3.fromRGB(160,50,50)
            stLbl.Text = "Desativado"; stLbl.TextColor3 = Color3.fromRGB(160,80,80)
        end
    end

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn,TweenInfo.new(0.1),{
            BackgroundColor3 = ativo and Color3.fromRGB(160,40,40) or Color3.fromRGB(40,155,90)
        }):Play()
    end)
    btn.MouseLeave:Connect(function() updateUI() end)

    btn.MouseButton1Click:Connect(function()
        ativo = not ativo
        updateUI()
        if ativo then ligar() else desligar() end
    end)
end

-- ==============================
-- INICIO
-- ==============================
criarGUI()

player.CharacterAdded:Connect(function()
    if ativo then
        desligar()
        task.wait(1.5)
        if ativo then ligar() end
    end
end)

print("[Lagatixa v5] Pronto!")
