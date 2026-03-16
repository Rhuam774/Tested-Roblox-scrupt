-- =============================================================
--  MODO LAGATIXA  v4  -  Delta Executor
--  Gravidade redireciona para qualquer superficie.
--  Personagem fica 100% em pe na parede/teto/chao/rampa.
--  Tecnica: PlatformStand + BodyGyro rigido + spring de posicao
-- =============================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local GRAV         = 196.2  -- gravidade padrao Roblox
local DIST_ALVO    = 2.9    -- distancia do centro do HRP ate a superficie (ajuste fino)
local SPRING_K     = 18     -- rigidez do spring (posicao na superficie)
local LERP_NORMAL  = 10     -- velocidade de transicao entre superficies (por segundo)

-- ==============================
-- ESTADO
-- ==============================
local ativo      = false
local conexoes   = {}
local normalAlvo = Vector3.new(0, 1, 0)
local pulando    = false

-- ==============================
-- RAYCAST: encontra superficie mais proxima nas 6 faces locais do HRP
-- ==============================
local function detectarSuperficie(hrp)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { player.Character }

    local pos  = hrp.Position
    local cf   = hrp.CFrame
    local dirs = {
        -cf.UpVector,        -- baixo local (principal: superficie atual)
         cf.UpVector,        -- cima local
         cf.LookVector,
        -cf.LookVector,
         cf.RightVector,
        -cf.RightVector,
    }

    local melhorDist   = math.huge
    local melhorNormal = nil
    local melhorPonto  = nil

    for _, dir in ipairs(dirs) do
        local res = workspace:Raycast(pos, dir * 5.5, params)
        if res then
            local d = (res.Position - pos).Magnitude
            if d < melhorDist then
                melhorDist   = d
                melhorNormal = res.Normal
                melhorPonto  = res.Position
            end
        end
    end

    return melhorNormal, melhorDist, melhorPonto
end

-- ==============================
-- CFrame alvo: personagem perfeitamente em pe na superficie
-- upVector = normal da superficie (EXATO, sem aproximacao)
-- lookVector = direcao da camera projetada no plano
-- ==============================
local function calcTargetCFrame(posicao, normal, cameraLook)
    -- Projeta o olhar da camera no plano perpendicular a normal
    local projLook = cameraLook - cameraLook:Dot(normal) * normal
    if projLook.Magnitude < 0.05 then
        projLook = camera.CFrame.RightVector - camera.CFrame.RightVector:Dot(normal) * normal
    end
    if projLook.Magnitude < 0.05 then
        -- fallback geometrico
        local arb = math.abs(normal:Dot(Vector3.new(0,1,0))) < 0.9
                    and Vector3.new(0,1,0)
                    or  Vector3.new(1,0,0)
        projLook = arb - arb:Dot(normal) * normal
    end
    projLook = projLook.Unit

    --  Base ortonormal:  right = projLook x normal,  look = normal x right
    local right = projLook:Cross(normal).Unit
    local look  = normal:Cross(right).Unit

    -- CFrame.fromMatrix(pos, xAxis=right, yAxis=up, -zAxis=look)
    -- => upVector = normal  (personagem 100% em pe na superficie)
    return CFrame.fromMatrix(posicao, right, normal, -look)
end

-- ==============================
-- LIGAR
-- ==============================
local function ligar()
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    -- PlatformStand = true: para TODA a fisica interna do Humanoid.
    -- Sem isso, o Roblox aplica torques internos para manter o personagem
    -- em pe no eixo Y do mundo, brigando com o BodyGyro.
    hum.PlatformStand = true

    -- ---- BodyGyro: MUITO rigido para rotacao instantanea ----
    local gyro = Instance.new("BodyGyro")
    gyro.MaxTorque = Vector3.new(1e9, 1e9, 1e9)  -- virtualmente infinito
    gyro.P         = 5e4   -- potencia
    gyro.D         = 800   -- amortecimento (sem oscilacao)
    gyro.CFrame    = hrp.CFrame
    gyro.Parent    = hrp

    -- ---- VectorForce (via Attachment): cancela grav mundial + aplica grav da superficie ----
    local att = Instance.new("Attachment")
    att.Position = Vector3.zero
    att.Parent   = hrp

    local vforce = Instance.new("VectorForce")
    vforce.Attachment0 = att
    vforce.RelativeTo  = Enum.ActuatorRelativeTo.World
    vforce.Force       = Vector3.zero
    vforce.Parent      = hrp

    -- ---- BodyVelocity: controla posicao E movimento lateral ----
    -- O truque: BodyVelocity no eixo normal age como um spring de posicao.
    -- No plano da superficie, aplica a velocidade de caminhada.
    local bvelo = Instance.new("BodyVelocity")
    bvelo.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bvelo.Velocity = Vector3.zero
    bvelo.Parent   = hrp

    table.insert(conexoes, gyro)
    table.insert(conexoes, att)
    table.insert(conexoes, vforce)
    table.insert(conexoes, bvelo)

    -- ---- Loop principal ----
    local heartbeat = RunService.Heartbeat:Connect(function(dt)
        if not ativo then return end

        local c = player.Character
        if not c then return end
        local h = c:FindFirstChild("HumanoidRootPart")
        local u = c:FindFirstChildOfClass("Humanoid")
        if not h or not u then return end

        local massa = h.AssemblyMass

        -- 1. DETECTA SUPERFICIE
        local novaNormal, dist, ponto = detectarSuperficie(h)
        if novaNormal then
            -- Suaviza a transicao de normal (evita giro brusco ao passar de parede para teto)
            normalAlvo = normalAlvo:Lerp(novaNormal, math.min(dt * LERP_NORMAL, 1))
        end
        -- Garante vetor unitario apos lerp
        if normalAlvo.Magnitude > 0 then
            normalAlvo = normalAlvo.Unit
        end

        -- 2. GRAVIDADE: cancela mundo + aplica para superficie
        -- Net force = (0, mass*g, 0)  +  (-normal * mass * g)
        -- => personagem "cai" para a superficie como se ela fosse o chao
        vforce.Force = Vector3.new(0, massa * GRAV, 0)
                     + (-normalAlvo * massa * GRAV)

        -- 3. ORIENTACAO: rotaciona instantaneamente para "em pe" na superficie
        -- Com MaxTorque=1e9, o gyro supera qualquer resistencia residual do Roblox
        gyro.CFrame = calcTargetCFrame(h.Position, normalAlvo, camera.CFrame.LookVector)

        -- 4. SPRING DE POSICAO: mantém o personagem exatamente acima da superficie
        -- sem afundar e sem flutuar
        local velNormal = 0
        if ponto and dist then
            local erro = DIST_ALVO - dist
            -- Spring proporcional: puxa ou empurra para DIST_ALVO
            -- Positivo = afastado demais (move para superficie)
            -- Negativo = muito proximo (move para longe)
            velNormal = erro * SPRING_K
        end

        -- 5. MOVIMENTO WASD projetado no plano da superficie
        local mX, mZ = 0, 0
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then mZ = -1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then mZ =  1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then mX = -1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then mX =  1 end

        local velLateral = Vector3.zero
        if mX ~= 0 or mZ ~= 0 then
            local camLook  = camera.CFrame.LookVector
            local camRight = camera.CFrame.RightVector
            -- Projeta direcoes da camera no plano da superficie
            local fwd = camLook  - camLook:Dot(normalAlvo)  * normalAlvo
            local rgt = camRight - camRight:Dot(normalAlvo) * normalAlvo
            if fwd.Magnitude  > 0.01 then fwd = fwd.Unit  end
            if rgt.Magnitude  > 0.01 then rgt = rgt.Unit  end
            local dir = fwd * (-mZ) + rgt * mX
            if dir.Magnitude > 0 then
                velLateral = dir.Unit * u.WalkSpeed
            end
        end

        -- Velocidade final = lateral (WASD na superficie) + normal (spring de posicao)
        bvelo.Velocity = velLateral + (-normalAlvo * velNormal)

        -- 6. PULO: impulso na direcao da normal
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) and not pulando then
            pulando = true
            h.AssemblyLinearVelocity = h.AssemblyLinearVelocity + normalAlvo * 55
            task.delay(0.55, function() pulando = false end)
        end
    end)

    table.insert(conexoes, heartbeat)
end

-- ==============================
-- DESLIGAR
-- ==============================
local function desligar()
    for _, obj in ipairs(conexoes) do
        if typeof(obj) == "RBXScriptConnection" then
            obj:Disconnect()
        elseif typeof(obj) == "Instance" then
            pcall(function() obj:Destroy() end)
        end
    end
    conexoes   = {}
    pulando    = false
    normalAlvo = Vector3.new(0, 1, 0)

    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hum then hum.PlatformStand = false end
        if hrp then
            hrp.AssemblyLinearVelocity  = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            -- Restaura orientacao vertical suavemente
            local pos = hrp.Position
            hrp.CFrame = CFrame.new(pos + Vector3.new(0, 0.5, 0))
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
    stroke.Color        = Color3.fromRGB(50, 150, 255)
    stroke.Thickness    = 1.8
    stroke.Transparency = 0.3

    local grad = Instance.new("UIGradient", win)
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 18, 35)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 20)),
    })
    grad.Rotation = 90

    -- Topbar
    local topbar = Instance.new("Frame", win)
    topbar.Size             = UDim2.new(1, 0, 0, 38)
    topbar.BackgroundColor3 = Color3.fromRGB(20, 22, 48)
    topbar.BorderSizePixel  = 0
    Instance.new("UICorner", topbar).CornerRadius = UDim.new(0, 14)
    local topfix = Instance.new("Frame", topbar)
    topfix.Size             = UDim2.new(1, 0, 0.5, 0)
    topfix.Position         = UDim2.new(0, 0, 0.5, 0)
    topfix.BackgroundColor3 = Color3.fromRGB(20, 22, 48)
    topfix.BorderSizePixel  = 0

    local iconLbl = Instance.new("TextLabel", topbar)
    iconLbl.Size = UDim2.new(0, 30, 1, 0); iconLbl.Position = UDim2.new(0, 8, 0, 0)
    iconLbl.BackgroundTransparency = 1; iconLbl.Text = "🦎"
    iconLbl.TextSize = 18; iconLbl.Font = Enum.Font.Gotham

    local titLbl = Instance.new("TextLabel", topbar)
    titLbl.Size = UDim2.new(1, -45, 1, 0); titLbl.Position = UDim2.new(0, 38, 0, 0)
    titLbl.BackgroundTransparency = 1; titLbl.Text = "Modo Lagatixa"
    titLbl.TextColor3 = Color3.fromRGB(100, 200, 255)
    titLbl.TextSize = 14; titLbl.Font = Enum.Font.GothamBold
    titLbl.TextXAlignment = Enum.TextXAlignment.Left

    -- Dot de status
    local dot = Instance.new("Frame", win)
    dot.Size = UDim2.new(0, 10, 0, 10); dot.Position = UDim2.new(0, 16, 0, 52)
    dot.BackgroundColor3 = Color3.fromRGB(160, 50, 50); dot.BorderSizePixel = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local stLbl = Instance.new("TextLabel", win)
    stLbl.Size = UDim2.new(1, -40, 0, 20); stLbl.Position = UDim2.new(0, 32, 0, 46)
    stLbl.BackgroundTransparency = 1; stLbl.Text = "Desativado"
    stLbl.TextColor3 = Color3.fromRGB(160, 80, 80); stLbl.TextSize = 12
    stLbl.Font = Enum.Font.Gotham; stLbl.TextXAlignment = Enum.TextXAlignment.Left

    -- Botao
    local btn = Instance.new("TextButton", win)
    btn.Size = UDim2.new(1, -20, 0, 44); btn.Position = UDim2.new(0, 10, 0, 82)
    btn.BackgroundColor3 = Color3.fromRGB(30, 120, 70); btn.BorderSizePixel = 0
    btn.Text = "ATIVAR"; btn.TextColor3 = Color3.fromRGB(230, 255, 235)
    btn.TextSize = 14; btn.Font = Enum.Font.GothamBold; btn.AutoButtonColor = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
    local bStroke = Instance.new("UIStroke", btn)
    bStroke.Color = Color3.fromRGB(60, 200, 110); bStroke.Thickness = 1
    bStroke.Transparency = 0.5

    local COR_ON  = Color3.fromRGB(130, 30, 30)
    local COR_OFF = Color3.fromRGB(30, 120, 70)

    local function updateUI()
        if ativo then
            TweenService:Create(btn, TweenInfo.new(0.18), { BackgroundColor3 = COR_ON }):Play()
            bStroke.Color = Color3.fromRGB(220, 70, 70)
            btn.Text = "DESATIVAR"
            dot.BackgroundColor3 = Color3.fromRGB(60, 210, 100)
            stLbl.Text = "Ativado"; stLbl.TextColor3 = Color3.fromRGB(60, 210, 100)
        else
            TweenService:Create(btn, TweenInfo.new(0.18), { BackgroundColor3 = COR_OFF }):Play()
            bStroke.Color = Color3.fromRGB(60, 200, 110)
            btn.Text = "ATIVAR"
            dot.BackgroundColor3 = Color3.fromRGB(160, 50, 50)
            stLbl.Text = "Desativado"; stLbl.TextColor3 = Color3.fromRGB(160, 80, 80)
        end
    end

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {
            BackgroundColor3 = ativo and Color3.fromRGB(160, 40, 40) or Color3.fromRGB(40, 155, 90)
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

print("[Lagatixa v4] Pronto! Ative pela janela.")
