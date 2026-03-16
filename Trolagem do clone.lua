-- =============================================================
--  MODO LAGATIXA  v3  -  Delta Executor / Qualquer Executor
--  Abordagem: gravity redirect + BodyGyro + Humanoid:Move()
--  Personagem fica em pe em qualquer superficie sem afundar
-- =============================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local PhysicsService   = game:GetService("PhysicsService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local GRAV   = 196.2   -- constante padrao do Roblox

-- ==============================
-- ESTADO
-- ==============================
local ativo       = false
local conexoes    = {}
local normalAlvo  = Vector3.new(0, 1, 0)  -- normal suavizada
local normalReal  = Vector3.new(0, 1, 0)  -- normal crua do raycast
local pulando     = false
local emSuperficie = false

-- ==============================
-- RAYCAST: 6 direcoes do personagem (espaco local do HRP)
-- Retorna a normal da superficie mais proxima
-- ==============================
local ALCANCE_DETECCAO = 4.0

local function detectarNormal(hrp)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { player.Character }

    local pos = hrp.Position
    -- 6 direcoes no espaco WORLD: baixo, cima, frente, tras, dir, esq do personagem
    local dirs = {
        hrp.CFrame.UpVector    * -1,   -- baixo local (para superficie atual)
        hrp.CFrame.UpVector,           -- cima local
        hrp.CFrame.LookVector,
        hrp.CFrame.LookVector  * -1,
        hrp.CFrame.RightVector,
        hrp.CFrame.RightVector * -1,
    }

    local melhorDist   = math.huge
    local melhorNormal = nil

    for _, dir in ipairs(dirs) do
        local res = workspace:Raycast(pos, dir * ALCANCE_DETECCAO, params)
        if res then
            local dist = (res.Position - pos).Magnitude
            if dist < melhorDist then
                melhorDist   = dist
                melhorNormal = res.Normal
            end
        end
    end

    return melhorNormal, melhorDist
end

-- ==============================
-- Constroi o CFrame alvo: personagem em pe na superficie
-- up = normal, frente = direcao da camera projetada no plano
-- ==============================
local function targetCFrame(hrp, normal)
    local camLook = camera.CFrame.LookVector

    -- projeta o olhar da camera no plano da superficie
    local frente = camLook - camLook:Dot(normal) * normal
    if frente.Magnitude < 0.05 then
        -- camera olhando direto para superficie: usa RightVector da camera
        frente = camera.CFrame.RightVector - camera.CFrame.RightVector:Dot(normal) * normal
    end
    if frente.Magnitude < 0.05 then
        -- fallback: usa o look atual do hrp projetado
        local lk = hrp.CFrame.LookVector
        frente = lk - lk:Dot(normal) * normal
    end
    frente = frente.Unit

    -- base ortonormal: right, up(=normal), look
    local right = frente:Cross(normal).Unit
    local look  = normal:Cross(right).Unit

    -- CFrame.fromMatrix(pos, xAxis=right, yAxis=up, zAxis=-look)
    return CFrame.fromMatrix(hrp.Position, right, normal, -look)
end

-- ==============================
-- LIGAR
-- ==============================
local function ligar()
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    -- Guarda estado original
    local autoRotateOriginal = hum.AutoRotate
    hum.AutoRotate = false   -- impede que o Roblox gire o personagem sozinho

    -- ---- BodyGyro: orienta o personagem em pe na superficie ----
    -- Usa torque fisico (nao seta CFrame diretamente) -> sem jitter
    local gyro = Instance.new("BodyGyro")
    gyro.MaxTorque = Vector3.new(4e5, 4e5, 4e5)
    gyro.P         = 2e4
    gyro.D         = 800
    gyro.CFrame    = hrp.CFrame
    gyro.Parent    = hrp

    -- ---- VectorForce: redireciona a gravidade para a superficie ----
    -- Attachment no centro do HRP (mundo, sem offset)
    local att = Instance.new("Attachment")
    att.Position = Vector3.zero
    att.Parent   = hrp

    local vf = Instance.new("VectorForce")
    vf.Attachment0 = att
    vf.RelativeTo  = Enum.ActuatorRelativeTo.World
    vf.Force       = Vector3.zero
    vf.Parent      = hrp

    -- O Humanoid continua ativo e controlando colisoes/andar
    -- Apenas redirecionamos onde e a gravidade e orientamos o corpo

    table.insert(conexoes, gyro)
    table.insert(conexoes, att)
    table.insert(conexoes, vf)

    -- ---- Loop principal ----
    local heartbeat = RunService.Heartbeat:Connect(function(dt)
        if not ativo then return end

        local c = player.Character
        if not c then return end
        local h = c:FindFirstChild("HumanoidRootPart")
        local u = c:FindFirstChildOfClass("Humanoid")
        if not h or not u then return end

        local massa = h.AssemblyMass

        -- 1. Detecta superficie
        local novaNormal, dist = detectarNormal(h)

        if novaNormal then
            emSuperficie = dist < 3.0
            -- Suaviza a transicao entre normais (evita salto brusco ao mudar superficie)
            normalAlvo = normalAlvo:Lerp(novaNormal, math.min(dt * 8, 1))
        else
            emSuperficie = false
            -- Sem superficie: volta gradualmente para "chao normal"
            normalAlvo = normalAlvo:Lerp(Vector3.new(0, 1, 0), math.min(dt * 4, 1))
        end

        -- 2. Gravidade customizada
        -- Cancela a gravidade do mundo (+Y * massa * GRAV)
        -- e aplica gravidade em direcao a superficie (-normal * massa * GRAV)
        local forcaGrav = Vector3.new(0, massa * GRAV, 0)   -- cancela world gravity
                        + (-normalAlvo * massa * GRAV)       -- aplica grav da superficie
        vf.Force = forcaGrav

        -- 3. Orienta o personagem em pe na superficie
        gyro.CFrame = targetCFrame(h, normalAlvo)

        -- 4. Movimento WASD projetado na superficie
        local mX = 0
        local mZ = 0
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then mZ = -1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then mZ =  1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then mX = -1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then mX =  1 end

        if mX ~= 0 or mZ ~= 0 then
            local camLook  = camera.CFrame.LookVector
            local camRight = camera.CFrame.RightVector
            local fwd = camLook  - camLook:Dot(normalAlvo)  * normalAlvo
            local rgt = camRight - camRight:Dot(normalAlvo) * normalAlvo

            if fwd.Magnitude  > 0.01 then fwd = fwd.Unit  end
            if rgt.Magnitude  > 0.01 then rgt = rgt.Unit  end

            local dir = (fwd * (-mZ) + rgt * mX)
            if dir.Magnitude > 0 then
                dir = dir.Unit
                -- Humanoid:Move() em espaco world projetado na superficie
                u:Move(dir, false)
            end
        else
            u:Move(Vector3.zero, false)
        end

        -- 5. Pulo: impulso na direcao da normal (saindo da superficie)
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) and not pulando and emSuperficie then
            pulando = true
            h.AssemblyLinearVelocity = h.AssemblyLinearVelocity + normalAlvo * 50
            task.delay(0.5, function() pulando = false end)
        end
    end)

    table.insert(conexoes, heartbeat)

    -- Restaurar AutoRotate ao desligar
    table.insert(conexoes, function()
        local c2 = player.Character
        if c2 then
            local u2 = c2:FindFirstChildOfClass("Humanoid")
            if u2 then
                u2.AutoRotate     = autoRotateOriginal
                u2:Move(Vector3.zero, false)
            end
        end
    end)
end

-- ==============================
-- DESLIGAR
-- ==============================
local function desligar()
    for _, obj in ipairs(conexoes) do
        if typeof(obj) == "RBXScriptConnection" then
            obj:Disconnect()
        elseif typeof(obj) == "function" then
            pcall(obj)
        elseif typeof(obj) == "Instance" then
            pcall(function() obj:Destroy() end)
        end
    end
    conexoes   = {}
    pulando    = false
    emSuperficie = false
    normalAlvo = Vector3.new(0, 1, 0)
    normalReal = Vector3.new(0, 1, 0)

    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            -- Suavemente retorna para orientacao normal
            local pos = hrp.Position + Vector3.new(0, 0.1, 0)
            hrp.CFrame = CFrame.new(pos)
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
    gui.Name           = "LagatixaGUI"
    gui.ResetOnSpawn   = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent         = player.PlayerGui

    -- Janela (arrastavel)
    local win = Instance.new("Frame")
    win.Name             = "Janela"
    win.Size             = UDim2.new(0, 240, 0, 140)
    win.Position         = UDim2.new(0, 16, 0.45, 0)
    win.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
    win.BorderSizePixel  = 0
    win.Active           = true
    win.Draggable        = true
    win.Parent           = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 14)
    corner.Parent = win

    local stroke = Instance.new("UIStroke")
    stroke.Color     = Color3.fromRGB(50, 150, 255)
    stroke.Thickness = 1.8
    stroke.Transparency = 0.3
    stroke.Parent    = win

    -- Gradiente sutil no fundo
    local grad = Instance.new("UIGradient")
    grad.Color    = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(18, 18, 35)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(10, 10, 20)),
    })
    grad.Rotation = 90
    grad.Parent   = win

    -- Titulo
    local topbar = Instance.new("Frame")
    topbar.Size             = UDim2.new(1, 0, 0, 38)
    topbar.BackgroundColor3 = Color3.fromRGB(20, 22, 48)
    topbar.BorderSizePixel  = 0
    topbar.Parent           = win
    Instance.new("UICorner", topbar).CornerRadius = UDim.new(0, 14)

    -- Cobre cantos inferiores da topbar
    local topfix = Instance.new("Frame")
    topfix.Size             = UDim2.new(1, 0, 0.5, 0)
    topfix.Position         = UDim2.new(0, 0, 0.5, 0)
    topfix.BackgroundColor3 = Color3.fromRGB(20, 22, 48)
    topfix.BorderSizePixel  = 0
    topfix.Parent           = topbar

    local icon = Instance.new("TextLabel")
    icon.Size                  = UDim2.new(0, 30, 1, 0)
    icon.Position              = UDim2.new(0, 8, 0, 0)
    icon.BackgroundTransparency = 1
    icon.Text                  = "🦎"
    icon.TextSize              = 18
    icon.Font                  = Enum.Font.Gotham
    icon.Parent                = topbar

    local titLbl = Instance.new("TextLabel")
    titLbl.Size                  = UDim2.new(1, -45, 1, 0)
    titLbl.Position              = UDim2.new(0, 38, 0, 0)
    titLbl.BackgroundTransparency = 1
    titLbl.Text                  = "Modo Lagatixa"
    titLbl.TextColor3            = Color3.fromRGB(100, 200, 255)
    titLbl.TextSize              = 14
    titLbl.Font                  = Enum.Font.GothamBold
    titLbl.TextXAlignment        = Enum.TextXAlignment.Left
    titLbl.Parent                = topbar

    -- Status
    local statusDot = Instance.new("Frame")
    statusDot.Size             = UDim2.new(0, 10, 0, 10)
    statusDot.Position         = UDim2.new(0, 16, 0, 52)
    statusDot.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
    statusDot.BorderSizePixel  = 0
    statusDot.Parent           = win
    Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)

    local statusTxt = Instance.new("TextLabel")
    statusTxt.Name                  = "StatusTxt"
    statusTxt.Size                  = UDim2.new(1, -40, 0, 20)
    statusTxt.Position              = UDim2.new(0, 32, 0, 46)
    statusTxt.BackgroundTransparency = 1
    statusTxt.Text                  = "Desativado"
    statusTxt.TextColor3            = Color3.fromRGB(160, 80, 80)
    statusTxt.TextSize              = 12
    statusTxt.Font                  = Enum.Font.Gotham
    statusTxt.TextXAlignment        = Enum.TextXAlignment.Left
    statusTxt.Parent                = win

    -- Botao
    local btn = Instance.new("TextButton")
    btn.Name             = "Btn"
    btn.Size             = UDim2.new(1, -20, 0, 44)
    btn.Position         = UDim2.new(0, 10, 0, 82)
    btn.BackgroundColor3 = Color3.fromRGB(30, 120, 70)
    btn.BorderSizePixel  = 0
    btn.Text             = "ATIVAR"
    btn.TextColor3       = Color3.fromRGB(230, 255, 235)
    btn.TextSize         = 14
    btn.Font             = Enum.Font.GothamBold
    btn.AutoButtonColor  = false
    btn.Parent           = win
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color       = Color3.fromRGB(60, 200, 110)
    btnStroke.Thickness   = 1
    btnStroke.Transparency = 0.5
    btnStroke.Parent      = btn

    local function atualizarUI()
        if ativo then
            TweenService:Create(btn, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(130, 30, 30)
            }):Play()
            btnStroke.Color       = Color3.fromRGB(220, 70, 70)
            btn.Text              = "DESATIVAR"
            statusDot.BackgroundColor3 = Color3.fromRGB(60, 210, 100)
            statusTxt.Text        = "Ativado"
            statusTxt.TextColor3  = Color3.fromRGB(60, 210, 100)
        else
            TweenService:Create(btn, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(30, 120, 70)
            }):Play()
            btnStroke.Color       = Color3.fromRGB(60, 200, 110)
            btn.Text              = "ATIVAR"
            statusDot.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
            statusTxt.Text        = "Desativado"
            statusTxt.TextColor3  = Color3.fromRGB(160, 80, 80)
        end
    end

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {
            BackgroundColor3 = ativo
                and Color3.fromRGB(160, 40, 40)
                or  Color3.fromRGB(40, 155, 90)
        }):Play()
    end)
    btn.MouseLeave:Connect(function() atualizarUI() end)

    btn.MouseButton1Click:Connect(function()
        ativo = not ativo
        atualizarUI()
        if ativo then
            ligar()
        else
            desligar()
        end
    end)
end

-- ==============================
-- INICIALIZACAO
-- ==============================
criarGUI()

player.CharacterAdded:Connect(function()
    if ativo then
        desligar()
        task.wait(1.5)
        if ativo then ligar() end
    end
end)

print("[Lagatixa v3] Pronto!")
