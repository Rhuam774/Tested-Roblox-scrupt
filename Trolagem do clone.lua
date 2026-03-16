-- =============================================================
--  MODO LAGATIXA - Script Roblox para Delta Executor
--  Funciona em todos os mapas e superficies
--  Autor: gerado via Replit
-- =============================================================

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService  = game:GetService("TweenService")

local player        = Players.LocalPlayer
local camera        = workspace.CurrentCamera

-- -------------------------
-- ESTADO GLOBAL
-- -------------------------
local modoLagatixa  = false
local conexoes      = {}
local gravOriginal  = workspace.Gravity  -- salva gravidade original (tipicamente 196.2)
local superficieAtual = nil
local normalAtual   = Vector3.new(0, 1, 0)

-- -------------------------
-- FUNCOES AUXILIARES
-- -------------------------
local function obterPersonagem()
    return player.Character or player.CharacterAdded:Wait()
end

local function obterPartes(char)
    return {
        hrp      = char:FindFirstChild("HumanoidRootPart"),
        humanoide = char:FindFirstChildOfClass("Humanoid"),
        cabeca   = char:FindFirstChild("Head"),
    }
end

-- Raycast em todas as direcoes ao redor do personagem para detectar superficie proxima
local function detectarSuperficie(hrp)
    local origem = hrp.Position
    local tamanho = hrp.Size
    local raioVerificacao = math.max(tamanho.X, tamanho.Y, tamanho.Z) * 0.7 + 0.5

    -- Direcoes para checar (baixo, cima, frente, tras, esquerda, direita)
    local direcoes = {
        Vector3.new(0, -1, 0),
        Vector3.new(0,  1, 0),
        Vector3.new(1,  0, 0),
        Vector3.new(-1, 0, 0),
        Vector3.new(0,  0, 1),
        Vector3.new(0,  0, -1),
    }

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { player.Character }

    local melhorDistancia = math.huge
    local melhorNormal    = nil

    for _, dir in ipairs(direcoes) do
        local resultado = workspace:Raycast(origem, dir * raioVerificacao, params)
        if resultado then
            local dist = (resultado.Position - origem).Magnitude
            if dist < melhorDistancia then
                melhorDistancia = dist
                melhorNormal    = resultado.Normal
            end
        end
    end

    return melhorNormal
end

-- Orienta o HRP para que "baixo" aponte contra a normal da superficie
local function orientarParaSuperficie(hrp, normal)
    -- "Para cima" do personagem = direcao oposta a normal da superficie
    local novoUp   = normal
    local lookAt   = hrp.CFrame.LookVector

    -- Garante que lookAt nao seja paralelo a novoUp
    if math.abs(lookAt:Dot(novoUp)) > 0.99 then
        lookAt = hrp.CFrame.RightVector
    end

    -- Constroi nova CFrame
    local novoDireito = lookAt:Cross(novoUp).Unit
    local novoFrente  = novoUp:Cross(novoDireito).Unit

    local novaCFrame = CFrame.fromMatrix(hrp.Position, novoDireito, novoUp, -novoFrente)

    -- Aplica suavemente
    hrp.CFrame = hrp.CFrame:Lerp(novaCFrame, 0.2)
end

-- -------------------------
-- LIGAR MODO LAGATIXA
-- -------------------------
local function ligarModoLagatixa()
    local char  = obterPersonagem()
    local partes = obterPartes(char)
    if not partes.hrp or not partes.humanoide then return end

    local hrp       = partes.hrp
    local humanoide = partes.humanoide

    -- Desativa gravidade padrao do Roblox no HRP
    local attachment0 = Instance.new("Attachment", hrp)
    local attachment1 = Instance.new("Attachment", hrp)

    -- VectorForce para cancelar gravidade
    local forcaAntiGravidade = Instance.new("VectorForce")
    forcaAntiGravidade.Attachment0 = attachment0
    forcaAntiGravidade.Force        = Vector3.new(0, hrp.AssemblyMass * gravOriginal, 0)
    forcaAntiGravidade.RelativeTo   = Enum.ActuatorRelativeTo.World
    forcaAntiGravidade.Parent       = hrp

    -- AlignOrientation para manter o personagem orientado a superficie
    local alignOri = Instance.new("AlignOrientation")
    alignOri.Attachment0        = attachment0
    alignOri.Attachment1        = attachment1
    alignOri.RigidityEnabled    = false
    alignOri.MaxTorque          = 1e6
    alignOri.Responsiveness     = 50
    alignOri.Parent             = hrp

    -- Bodyvelocity customizado: re-aplica forca de gravidade na direcao da normal
    local bodyVelo = Instance.new("BodyVelocity")
    bodyVelo.Velocity    = Vector3.zero
    bodyVelo.MaxForce    = Vector3.new(0, 0, 0)  -- começa sem forca
    bodyVelo.Parent      = hrp

    -- Armazena instancias para remocao posterior
    table.insert(conexoes, attachment0)
    table.insert(conexoes, attachment1)
    table.insert(conexoes, forcaAntiGravidade)
    table.insert(conexoes, alignOri)
    table.insert(conexoes, bodyVelo)

    -- Loop principal do modo lagatixa
    local heartbeat = RunService.Heartbeat:Connect(function(dt)
        if not modoLagatixa then return end

        local c2 = player.Character
        if not c2 then return end
        local h2 = c2:FindFirstChild("HumanoidRootPart")
        local hum2 = c2:FindFirstChildOfClass("Humanoid")
        if not h2 or not hum2 then return end

        -- Detecta superficie proxima
        local novaNormal = detectarSuperficie(h2)

        if novaNormal then
            normalAtual = novaNormal

            -- Orienta personagem para superficie
            orientarParaSuperficie(h2, normalAtual)

            -- Cancela gravidade world e aplica "gravidade" na direcao da superficie
            local massa = h2.AssemblyMass
            forcaAntiGravidade.Force = Vector3.new(0, massa * gravOriginal, 0)
                + (-normalAtual * massa * gravOriginal * 0.95)

            -- Permite que o Humanoid "caminhe" na superficie
            hum2.PlatformStand = false
        else
            -- Sem superficie proxima: comportamento normal mas mantém orientacao
            forcaAntiGravidade.Force = Vector3.new(0, h2.AssemblyMass * gravOriginal, 0)
        end

        -- Controle de movimento baseado na normal (WASD adaptado a superficie)
        local movX = 0
        local movZ = 0

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then movZ = -1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then movZ =  1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then movX = -1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then movX =  1 end

        if movX ~= 0 or movZ ~= 0 then
            -- Calcula direcao de movimento relativa a camera e a superficie
            local camCFrame = camera.CFrame
            local camFrente = (camCFrame.LookVector - camCFrame.LookVector:Dot(normalAtual) * normalAtual).Unit
            local camDireito = (camCFrame.RightVector - camCFrame.RightVector:Dot(normalAtual) * normalAtual).Unit

            local direcaoMovimento = (camFrente * (-movZ) + camDireito * movX)
            if direcaoMovimento.Magnitude > 0 then
                direcaoMovimento = direcaoMovimento.Unit
                local velocidade = hum2.WalkSpeed
                h2.AssemblyLinearVelocity = h2.AssemblyLinearVelocity:Lerp(
                    direcaoMovimento * velocidade, 0.3
                )
            end
        end

        -- Pulo na direcao da normal
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            if hum2:GetState() ~= Enum.HumanoidStateType.Jumping then
                h2.AssemblyLinearVelocity = h2.AssemblyLinearVelocity + normalAtual * hum2.JumpPower
            end
        end
    end)

    table.insert(conexoes, heartbeat)
end

-- -------------------------
-- DESLIGAR MODO LAGATIXA
-- -------------------------
local function desligarModoLagatixa()
    -- Remove todas as conexoes e instancias criadas
    for _, obj in ipairs(conexoes) do
        if typeof(obj) == "RBXScriptConnection" then
            obj:Disconnect()
        elseif typeof(obj) == "Instance" then
            obj:Destroy()
        end
    end
    conexoes = {}

    -- Restaura estado normal do personagem
    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hum then
            hum.PlatformStand = false
        end
        if hrp then
            -- Restaura orientacao vertical normal
            local pos = hrp.Position
            hrp.CFrame = CFrame.new(pos)
        end
    end
    normalAtual = Vector3.new(0, 1, 0)
end

-- -------------------------
-- GUI
-- -------------------------
local function criarGUI()
    -- Remove GUI antiga se existir
    local antigo = player.PlayerGui:FindFirstChild("ModoLagatixaGUI")
    if antigo then antigo:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name             = "ModoLagatixaGUI"
    screenGui.ResetOnSpawn     = false
    screenGui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
    screenGui.Parent           = player.PlayerGui

    -- Janela principal
    local janela = Instance.new("Frame")
    janela.Name              = "Janela"
    janela.Size              = UDim2.new(0, 220, 0, 120)
    janela.Position          = UDim2.new(0, 20, 0.5, -60)
    janela.BackgroundColor3  = Color3.fromRGB(20, 20, 30)
    janela.BorderSizePixel   = 0
    janela.Active            = true
    janela.Draggable         = true
    janela.Parent            = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = janela

    local stroke = Instance.new("UIStroke")
    stroke.Color     = Color3.fromRGB(80, 180, 255)
    stroke.Thickness = 1.5
    stroke.Parent    = janela

    -- Titulo
    local titulo = Instance.new("TextLabel")
    titulo.Size              = UDim2.new(1, 0, 0, 32)
    titulo.Position          = UDim2.new(0, 0, 0, 0)
    titulo.BackgroundColor3  = Color3.fromRGB(30, 30, 50)
    titulo.BorderSizePixel   = 0
    titulo.Text              = "🦎 Modo Lagatixa"
    titulo.TextColor3        = Color3.fromRGB(80, 200, 255)
    titulo.TextSize          = 14
    titulo.Font              = Enum.Font.GothamBold
    titulo.Parent            = janela

    local cornerTitulo = Instance.new("UICorner")
    cornerTitulo.CornerRadius = UDim.new(0, 10)
    cornerTitulo.Parent = titulo

    -- Status label
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name            = "StatusLabel"
    statusLabel.Size            = UDim2.new(1, -20, 0, 20)
    statusLabel.Position        = UDim2.new(0, 10, 0, 38)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text            = "Status: DESATIVADO"
    statusLabel.TextColor3      = Color3.fromRGB(200, 80, 80)
    statusLabel.TextSize        = 12
    statusLabel.Font            = Enum.Font.Gotham
    statusLabel.TextXAlignment  = Enum.TextXAlignment.Left
    statusLabel.Parent          = janela

    -- Botao principal
    local botao = Instance.new("TextButton")
    botao.Name              = "BotaoAtivar"
    botao.Size              = UDim2.new(1, -20, 0, 38)
    botao.Position          = UDim2.new(0, 10, 0, 66)
    botao.BackgroundColor3  = Color3.fromRGB(40, 140, 80)
    botao.BorderSizePixel   = 0
    botao.Text              = "✅ Ativar Modo Lagatixa"
    botao.TextColor3        = Color3.fromRGB(255, 255, 255)
    botao.TextSize          = 13
    botao.Font              = Enum.Font.GothamBold
    botao.AutoButtonColor   = false
    botao.Parent            = janela

    local cornerBotao = Instance.new("UICorner")
    cornerBotao.CornerRadius = UDim.new(0, 8)
    cornerBotao.Parent = botao

    -- Hover effect
    botao.MouseEnter:Connect(function()
        TweenService:Create(botao, TweenInfo.new(0.15), {
            BackgroundColor3 = modoLagatixa
                and Color3.fromRGB(200, 50, 50)
                or  Color3.fromRGB(50, 170, 100)
        }):Play()
    end)
    botao.MouseLeave:Connect(function()
        TweenService:Create(botao, TweenInfo.new(0.15), {
            BackgroundColor3 = modoLagatixa
                and Color3.fromRGB(160, 40, 40)
                or  Color3.fromRGB(40, 140, 80)
        }):Play()
    end)

    -- Logica do botao
    botao.MouseButton1Click:Connect(function()
        modoLagatixa = not modoLagatixa

        if modoLagatixa then
            statusLabel.Text       = "Status: ATIVADO"
            statusLabel.TextColor3 = Color3.fromRGB(80, 220, 80)
            botao.Text             = "❌ Desativar Modo Lagatixa"
            botao.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
            ligarModoLagatixa()
        else
            statusLabel.Text       = "Status: DESATIVADO"
            statusLabel.TextColor3 = Color3.fromRGB(200, 80, 80)
            botao.Text             = "✅ Ativar Modo Lagatixa"
            botao.BackgroundColor3 = Color3.fromRGB(40, 140, 80)
            desligarModoLagatixa()
        end
    end)

    return screenGui
end

-- -------------------------
-- INICIALIZACAO
-- -------------------------
criarGUI()

-- Recriar GUI ao trocar de personagem (respawn)
player.CharacterAdded:Connect(function()
    if modoLagatixa then
        -- Desliga e religa no novo personagem
        desligarModoLagatixa()
        task.wait(1)  -- espera o personagem carregar completamente
        ligarModoLagatixa()
    end
end)

print("[Modo Lagatixa] Script carregado com sucesso!")
