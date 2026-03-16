-- =============================================================
--  MODO LAGATIXA - Script Roblox para Delta Executor
--  Funciona em todos os mapas e superficies (paredes, teto, chao inclinado...)
-- =============================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local player    = Players.LocalPlayer
local camera    = workspace.CurrentCamera
local GRAV      = workspace.Gravity   -- ~196.2

-- -------------------------
-- ESTADO GLOBAL
-- -------------------------
local ativo       = false
local conexoes    = {}
local normalAtual = Vector3.new(0, 1, 0)
local pulando     = false

-- -------------------------
-- RAYCAST: detecta superficie mais proxima em 26 direcoes
-- -------------------------
local function detectarNormal(hrp)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { player.Character }

    local origem  = hrp.Position
    local alcance = 3.5   -- distancia de deteccao

    -- 6 faces + 12 arestas + 8 cantos = deteccao abrangente
    local direcoes = {
        -- faces principais
        Vector3.new( 0, -1,  0), Vector3.new( 0,  1,  0),
        Vector3.new( 1,  0,  0), Vector3.new(-1,  0,  0),
        Vector3.new( 0,  0,  1), Vector3.new( 0,  0, -1),
        -- arestas
        Vector3.new( 1, -1,  0).Unit, Vector3.new(-1, -1,  0).Unit,
        Vector3.new( 0, -1,  1).Unit, Vector3.new( 0, -1, -1).Unit,
        Vector3.new( 1,  1,  0).Unit, Vector3.new(-1,  1,  0).Unit,
        Vector3.new( 0,  1,  1).Unit, Vector3.new( 0,  1, -1).Unit,
        Vector3.new( 1,  0,  1).Unit, Vector3.new( 1,  0, -1).Unit,
        Vector3.new(-1,  0,  1).Unit, Vector3.new(-1,  0, -1).Unit,
        -- cantos
        Vector3.new( 1, -1,  1).Unit, Vector3.new(-1, -1,  1).Unit,
        Vector3.new( 1, -1, -1).Unit, Vector3.new(-1, -1, -1).Unit,
        Vector3.new( 1,  1,  1).Unit, Vector3.new(-1,  1,  1).Unit,
        Vector3.new( 1,  1, -1).Unit, Vector3.new(-1,  1, -1).Unit,
    }

    local melhorDist   = math.huge
    local melhorNormal = nil

    for _, dir in ipairs(direcoes) do
        local res = workspace:Raycast(origem, dir * alcance, params)
        if res then
            local d = (res.Position - origem).Magnitude
            if d < melhorDist then
                melhorDist   = d
                melhorNormal = res.Normal
            end
        end
    end

    return melhorNormal
end

-- -------------------------
-- CONSTROI CFrame "em pe na superficie"
-- up do personagem = normal da superficie
-- frente = direcao da camera projetada no plano da superficie
-- -------------------------
local function cframeNaSurperficie(posicao, normal, cameraLook)
    -- Projeta o olhar da camera no plano perpendicular a normal
    local frente = cameraLook - cameraLook:Dot(normal) * normal

    -- Fallback: se camera estiver olhando direto para a superficie
    if frente.Magnitude < 0.01 then
        frente = camera.CFrame.RightVector - camera.CFrame.RightVector:Dot(normal) * camera.CFrame.RightVector:Dot(normal) * normal
    end
    if frente.Magnitude < 0.01 then
        -- ultimo fallback: usa o look atual do hrp projetado
        frente = Vector3.new(1, 0, 0) - Vector3.new(1, 0, 0):Dot(normal) * normal
    end

    frente = frente.Unit

    -- right e look formam a base junto com a normal (up)
    local right = frente:Cross(normal).Unit
    local look  = normal:Cross(right).Unit

    -- fromMatrix(pos, xAxis=right, yAxis=up, zAxis=-look)
    -- lookVector do CFrame resultante = look (personagem "olha" para frente na superficie)
    return CFrame.fromMatrix(posicao, right, normal, -look)
end

-- -------------------------
-- LIGA MODO LAGATIXA
-- -------------------------
local function ligar()
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    -- PlatformStand: desativa o movimento padrao do Humanoid
    -- para que nosso BodyVelocity tenha controle total
    hum.PlatformStand = true

    -- ---- BodyForce: cancela gravidade do mundo ----
    -- Resultado: gravidade efetiva = -normal * GRAV (puxa para superficie)
    local bodyForce = Instance.new("BodyForce")
    bodyForce.Force  = Vector3.new(0, hrp.AssemblyMass * GRAV, 0)
    bodyForce.Parent = hrp

    -- ---- BodyGyro: orienta o personagem em pe na superficie ----
    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    bodyGyro.P         = 3e4    -- rigidez da rotacao
    bodyGyro.D         = 500    -- amortecimento (evita oscilar)
    bodyGyro.CFrame    = hrp.CFrame
    bodyGyro.Parent    = hrp

    -- ---- BodyVelocity: controla movimento WASD na superficie ----
    local bodyVelo = Instance.new("BodyVelocity")
    bodyVelo.Velocity  = Vector3.zero
    bodyVelo.MaxForce  = Vector3.new(1e4, 1e4, 1e4)
    bodyVelo.Parent    = hrp

    table.insert(conexoes, bodyForce)
    table.insert(conexoes, bodyGyro)
    table.insert(conexoes, bodyVelo)

    -- ---- Loop principal ----
    local heartbeat = RunService.Heartbeat:Connect(function(dt)
        if not ativo then return end

        local c = player.Character
        if not c then return end
        local h = c:FindFirstChild("HumanoidRootPart")
        local u = c:FindFirstChildOfClass("Humanoid")
        if not h or not u then return end

        local massa = h.AssemblyMass

        -- Detecta superficie proxima
        local normal = detectarNormal(h)
        if normal then
            normalAtual = normalAtual:Lerp(normal, 0.15)   -- suaviza troca de normal
        end

        -- ---- 1. GRAVIDADE: cancela world gravity + puxa para superficie ----
        -- forcaAntiGravMundo = +Y * massa * GRAV  (anula o -Y do Roblox)
        -- forcaSuperficie    = -normal * massa * GRAV  (puxa para superficie)
        bodyForce.Force = Vector3.new(0, massa * GRAV, 0) + (-normalAtual * massa * GRAV)

        -- ---- 2. ORIENTACAO: gira personagem para ficar em pe na superficie ----
        local targetCF = cframeNaSurperficie(h.Position, normalAtual, camera.CFrame.LookVector)
        bodyGyro.CFrame = targetCF

        -- ---- 3. MOVIMENTO: WASD relativo a camera, projetado na superficie ----
        local movX = 0
        local movZ = 0
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then movZ = -1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then movZ =  1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then movX = -1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then movX =  1 end

        if movX ~= 0 or movZ ~= 0 then
            -- Projeta direcoes da camera no plano da superficie
            local camLook  = camera.CFrame.LookVector
            local camRight = camera.CFrame.RightVector
            local fwd = (camLook  - camLook:Dot(normalAtual)  * normalAtual)
            local rgt = (camRight - camRight:Dot(normalAtual) * normalAtual)
            if fwd.Magnitude  > 0.01 then fwd = fwd.Unit  end
            if rgt.Magnitude  > 0.01 then rgt = rgt.Unit  end

            local dir = fwd * (-movZ) + rgt * movX
            if dir.Magnitude > 0 then
                dir = dir.Unit
            end
            -- Adiciona componente de "colar na superficie" enquanto se move
            local velocidadeColagem = -normalAtual * 10
            bodyVelo.Velocity  = dir * u.WalkSpeed + velocidadeColagem
            bodyVelo.MaxForce  = Vector3.new(1e4, 1e4, 1e4)
        else
            -- Parado: mantém colado na superficie, sem deslizar
            bodyVelo.Velocity  = -normalAtual * 8
            bodyVelo.MaxForce  = Vector3.new(1e4, 1e4, 1e4)
        end

        -- ---- 4. PULO: impulso na direcao da normal ----
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) and not pulando then
            pulando = true
            h.AssemblyLinearVelocity = h.AssemblyLinearVelocity + normalAtual * (u.JumpPower * 1.2)
            task.delay(0.6, function() pulando = false end)
        end
    end)

    table.insert(conexoes, heartbeat)
end

-- -------------------------
-- DESLIGA MODO LAGATIXA
-- -------------------------
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
    normalAtual = Vector3.new(0, 1, 0)

    -- Restaura personagem
    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hum then hum.PlatformStand = false end
        if hrp then
            -- Reposiciona em orientacao normal (em pe)
            hrp.CFrame = CFrame.new(hrp.Position)
            hrp.AssemblyLinearVelocity  = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end
end

-- -------------------------
-- GUI
-- -------------------------
local function criarGUI()
    local antigo = player.PlayerGui:FindFirstChild("ModoLagatixaGUI")
    if antigo then antigo:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name           = "ModoLagatixaGUI"
    screenGui.ResetOnSpawn   = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent         = player.PlayerGui

    -- Janela
    local janela = Instance.new("Frame")
    janela.Name             = "Janela"
    janela.Size             = UDim2.new(0, 230, 0, 130)
    janela.Position         = UDim2.new(0, 20, 0.5, -65)
    janela.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    janela.BorderSizePixel  = 0
    janela.Active           = true
    janela.Draggable        = true
    janela.Parent           = screenGui

    Instance.new("UICorner", janela).CornerRadius = UDim.new(0, 12)

    local stroke = Instance.new("UIStroke", janela)
    stroke.Color     = Color3.fromRGB(60, 160, 255)
    stroke.Thickness = 1.5

    -- Barra de titulo
    local barra = Instance.new("Frame")
    barra.Size             = UDim2.new(1, 0, 0, 36)
    barra.BackgroundColor3 = Color3.fromRGB(25, 25, 45)
    barra.BorderSizePixel  = 0
    barra.Parent           = janela
    Instance.new("UICorner", barra).CornerRadius = UDim.new(0, 12)

    local titulo = Instance.new("TextLabel")
    titulo.Size                 = UDim2.new(1, -10, 1, 0)
    titulo.Position             = UDim2.new(0, 10, 0, 0)
    titulo.BackgroundTransparency = 1
    titulo.Text                 = "🦎  Modo Lagatixa"
    titulo.TextColor3           = Color3.fromRGB(90, 200, 255)
    titulo.TextSize             = 14
    titulo.Font                 = Enum.Font.GothamBold
    titulo.TextXAlignment       = Enum.TextXAlignment.Left
    titulo.Parent               = barra

    -- Label de status
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name                  = "StatusLabel"
    statusLabel.Size                  = UDim2.new(1, -20, 0, 22)
    statusLabel.Position              = UDim2.new(0, 10, 0, 42)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text                  = "⚫  Desativado"
    statusLabel.TextColor3            = Color3.fromRGB(180, 70, 70)
    statusLabel.TextSize              = 12
    statusLabel.Font                  = Enum.Font.Gotham
    statusLabel.TextXAlignment        = Enum.TextXAlignment.Left
    statusLabel.Parent                = janela

    -- Botao
    local botao = Instance.new("TextButton")
    botao.Name             = "Botao"
    botao.Size             = UDim2.new(1, -20, 0, 42)
    botao.Position         = UDim2.new(0, 10, 0, 72)
    botao.BackgroundColor3 = Color3.fromRGB(35, 130, 75)
    botao.BorderSizePixel  = 0
    botao.Text             = "✅  Ativar"
    botao.TextColor3       = Color3.fromRGB(255, 255, 255)
    botao.TextSize         = 13
    botao.Font             = Enum.Font.GothamBold
    botao.AutoButtonColor  = false
    botao.Parent           = janela
    Instance.new("UICorner", botao).CornerRadius = UDim.new(0, 8)

    local function corBotao()
        return ativo and Color3.fromRGB(150, 35, 35) or Color3.fromRGB(35, 130, 75)
    end

    botao.MouseEnter:Connect(function()
        TweenService:Create(botao, TweenInfo.new(0.12), {
            BackgroundColor3 = ativo and Color3.fromRGB(190, 50, 50) or Color3.fromRGB(50, 160, 95)
        }):Play()
    end)
    botao.MouseLeave:Connect(function()
        TweenService:Create(botao, TweenInfo.new(0.12), { BackgroundColor3 = corBotao() }):Play()
    end)

    botao.MouseButton1Click:Connect(function()
        ativo = not ativo
        if ativo then
            botao.Text             = "❌  Desativar"
            botao.BackgroundColor3 = Color3.fromRGB(150, 35, 35)
            statusLabel.Text       = "🟢  Ativado"
            statusLabel.TextColor3 = Color3.fromRGB(70, 210, 100)
            ligar()
        else
            botao.Text             = "✅  Ativar"
            botao.BackgroundColor3 = Color3.fromRGB(35, 130, 75)
            statusLabel.Text       = "⚫  Desativado"
            statusLabel.TextColor3 = Color3.fromRGB(180, 70, 70)
            desligar()
        end
    end)
end

-- -------------------------
-- INICIALIZACAO
-- -------------------------
criarGUI()

-- Ao respawnar, reinicia o modo se estava ativo
player.CharacterAdded:Connect(function()
    if ativo then
        desligar()
        task.wait(1.2)
        ligar()
    end
end)

print("[Modo Lagatixa] Carregado! Use a janela para ativar.")
