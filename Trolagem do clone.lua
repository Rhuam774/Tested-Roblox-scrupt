-- =============================================================
--  MODO LAGATIXA  v7  -  ULTRA ROBUSTO
--  Delta Executor / KRNL / Synapse Z
--  Detecção Multi-ponto + Suavização de Cantos + Auto-Respawn
-- =============================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ==============================
-- CONFIGURAÇÕES AVANÇADAS
-- ==============================
local WALK_SPEED    = 17
local JUMP_POWER    = 60
local GRAV_ACCEL    = 90
local STICKY_FORCE  = 120   -- Força que "puxa" para a superfície
local LAND_DIST     = 3.1
local RAY_DIST      = 10
local LERP_SPEED    = 15    -- Velocidade de rotação/alinhamento
local LOOK_AHEAD    = 4     -- Distância para prever quinas

local WALK_ANIM_ID = "rbxassetid://180435571" -- Pode ser trocado por qualquer ID de animação de andar

-- ==============================
-- ESTADO GLOBAL
-- ==============================
local ativo      = false
local loop       = nil
local animTrack  = nil
local connections = {}

local myPos      = Vector3.zero
local myNormal   = Vector3.new(0, 1, 0)
local myVelN     = 0
local noChao     = false
local pulando    = false

-- ==============================
-- UTILITÁRIOS DE DETECÇÃO (MULTI-PONTO)
-- ==============================
local function castRay(pos, dir, params)
    local res = workspace:Raycast(pos, dir * RAY_DIST, params)
    return res
end

local function detectarRobusto(hrp, normal)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { player.Character }

    local pos = hrp.Position
    local cf = hrp.CFrame
    
    -- Pontos de amostragem (centro + 4 cantos do HRP)
    local offsets = {
        Vector3.zero,
        cf.RightVector * 1.5,
        -cf.RightVector * 1.5,
        cf.LookVector * 1.5,
        -cf.LookVector * 1.5
    }

    local sumNormal = Vector3.zero
    local hitCount  = 0
    local bestPt    = nil
    local minDist   = math.huge

    for _, offset in ipairs(offsets) do
        local origin = pos + offset
        -- Tenta 3 direções por ponto: baixo local, normal invertida e lookahead se estiver movendo
        local dirs = { -normal, -cf.UpVector }
        
        for _, dir in ipairs(dirs) do
            local res = castRay(origin, dir, params)
            if res then
                sumNormal = sumNormal + res.Normal
                hitCount = hitCount + 1
                local d = (res.Position - pos).Magnitude
                if d < minDist then
                    minDist = d
                    bestPt = res.Position
                end
                break -- Já achou superfície para este ponto
            end
        end
    end

    if hitCount > 0 then
        return (sumNormal / hitCount).Unit, minDist, bestPt
    end
    return nil, nil, nil
end

-- ==============================
-- ORIENTAÇÃO (CFRAME)
-- ==============================
local function getFinalCF(pos, normal, camLook)
    local fwd = camLook - camLook:Dot(normal) * normal
    if fwd.Magnitude < 0.001 then
        fwd = camera.CFrame.RightVector
        fwd = fwd - fwd:Dot(normal) * normal
    end
    if fwd.Magnitude < 0.001 then
        local arb = math.abs(normal.Y) < 0.9 and Vector3.new(0,1,0) or Vector3.new(1,0,0)
        fwd = arb - arb:Dot(normal) * normal
    end
    fwd = fwd.Unit
    local right = fwd:Cross(normal).Unit
    local look  = normal:Cross(right).Unit
    return CFrame.fromMatrix(pos, right, normal, -look)
end

-- ==============================
-- VIDA E ANIMAÇÃO
-- ==============================
local function stopEverything()
    if loop then loop:Disconnect(); loop = nil end
    if animTrack then animTrack:Stop(); animTrack = nil end
    for _, c in pairs(connections) do c:Disconnect() end
    connections = {}
end

local function loadAnim(hum)
    local anim = Instance.new("Animation")
    anim.AnimationId = WALK_ANIM_ID
    animTrack = hum:LoadAnimation(anim)
    animTrack.Priority = Enum.AnimationPriority.Movement
    animTrack.Looped = true
end

-- ==============================
-- NÚCLEO DO MOVIMENTO (LIGAR)
-- ==============================
local function ligar()
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp  = char:WaitForChild("HumanoidRootPart", 5)
    local hum  = char:WaitForChild("Humanoid", 5)
    if not hrp or not hum then return end

    stopEverything()
    hum.PlatformStand = true
    loadAnim(hum)

    myPos    = hrp.Position
    myNormal = Vector3.new(0, 1, 0)
    myVelN   = 0

    loop = RunService.Heartbeat:Connect(function(dt)
        if not ativo then return end
        local c = player.Character
        local h = c and c:FindFirstChild("HumanoidRootPart")
        local u = c and c:FindFirstChildOfClass("Humanoid")
        if not h or not u or u.Health <= 0 then return end

        -- 1. DETECÇÃO ROBUSTA
        local norm, dist, pt = detectarRobusto(h, myNormal)

        -- 2. MOVIMENTO WASD
        local moveInput = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveInput = moveInput + camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveInput = moveInput - camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveInput = moveInput - camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveInput = moveInput + camera.CFrame.RightVector end

        local velLateral = Vector3.zero
        if moveInput.Magnitude > 0.01 then
            -- Projeta na superfície atual
            local dir = moveInput - moveInput:Dot(myNormal) * myNormal
            if dir.Magnitude > 0.01 then
                velLateral = dir.Unit * WALK_SPEED
            end
        end

        -- 3. GRAVIDADE E ADERÊNCIA (Sticky)
        if noChao then
            myVelN = -STICKY_FORCE * dt -- Puxa para a superfície
        else
            myVelN = myVelN - GRAV_ACCEL * dt
        end

        -- 4. PULO
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) and noChao and not pulando then
            myVelN = JUMP_POWER
            noChao = false
            pulando = true
            task.delay(0.5, function() pulando = false end)
        end

        -- 5. ATUALIZA POSIÇÃO
        myPos = myPos + (myNormal * myVelN * dt) + (velLateral * dt)

        -- 6. COLISÃO E AJUSTE DE NORMAL
        if norm then
            -- Suavização de cantos (Lerp progressivo)
            myNormal = myNormal:Lerp(norm, math.min(dt * LERP_SPEED, 1)).Unit
            
            if dist <= LAND_DIST and myVelN <= 0 then
                myVelN = 0
                noChao = true
                myPos  = pt + norm * LAND_DIST
            else
                noChao = false
            end
        else
            noChao = false
        end

        -- 7. ANIMAÇÃO
        if velLateral.Magnitude > 1 and noChao then
            if not animTrack.IsPlaying then animTrack:Play() end
            animTrack:AdjustSpeed(WALK_SPEED / 14)
        else
            animTrack:Stop(0.15)
        end

        -- 8. APLICAÇÃO FINAL
        h.CFrame = getFinalCF(myPos, myNormal, camera.CFrame.LookVector)
        h.AssemblyLinearVelocity  = Vector3.zero
        h.AssemblyAngularVelocity = Vector3.zero
    end)
end

-- ==============================
-- DESLIGAR
-- ==============================
local function desligar()
    ativo = false
    stopEverything()
    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hum then hum.PlatformStand = false end
        if hrp then
            hrp.AssemblyLinearVelocity  = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end
end

-- ==============================
-- INTERFACE (ESTILO PREMIUM V7)
-- ==============================
local function criarUI()
    local old = player.PlayerGui:FindFirstChild("LagatixaV7")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "LagatixaV7"; gui.ResetOnSpawn = false; gui.Parent = player.PlayerGui

    local main = Instance.new("Frame", gui)
    main.Size = UDim2.new(0, 220, 0, 110); main.Position = UDim2.new(0.5, -110, 0.85, 0)
    main.BackgroundColor3 = Color3.fromRGB(15, 15, 20); main.BorderSizePixel = 0
    main.Active = true; main.Draggable = true
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
    
    local stroke = Instance.new("UIStroke", main)
    stroke.Thickness = 2; stroke.Color = Color3.fromRGB(50, 120, 255); stroke.Transparency = 0.4

    local title = Instance.new("TextLabel", main)
    title.Size = UDim2.new(1, 0, 0, 35); title.BackgroundTransparency = 1
    title.Text = "LAGATIXA ROBUSTA V7"; title.TextColor3 = Color3.new(1,1,1)
    title.Font = Enum.Font.GothamBold; title.TextSize = 13

    local btn = Instance.new("TextButton", main)
    btn.Size = UDim2.new(0.85, 0, 0, 45); btn.Position = UDim2.new(0.075, 0, 0.45, 0)
    btn.BackgroundColor3 = Color3.fromRGB(35, 150, 80); btn.Text = "ATIVAR"
    btn.TextColor3 = Color3.new(1,1,1); btn.Font = Enum.Font.GothamBold; btn.TextSize = 14
    Instance.new("UICorner", btn)

    local function updateUI()
        TweenService:Create(btn, TweenInfo.new(0.3), {
            BackgroundColor3 = ativo and Color3.fromRGB(150, 40, 40) or Color3.fromRGB(35, 150, 80)
        }):Play()
        btn.Text = ativo and "DESATIVAR" or "ATIVAR"
        stroke.Color = ativo and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(50, 120, 255)
    end

    btn.MouseButton1Click:Connect(function()
        ativo = not ativo
        updateUI()
        if ativo then ligar() else desligar() end
    end)
end

-- ==============================
-- GESTÃO DE RESPAWN
-- ==============================
player.CharacterAdded:Connect(function()
    if ativo then
        task.wait(1.5)
        if ativo then ligar() end
    end
end)

task.spawn(function()
    while not player:FindFirstChild("PlayerGui") do task.wait() end
    criarUI()
end)

print("[Lagatixa v7] Sistema de movimento robusto carregado.")
