-- =============================================================
--  MODO LAGATIXA  v6  -  Delta Executor
--  Movimento manual na superfície (parede/teto/chão)
--  Direção baseada na Câmera + Animação de Andar
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
local WALK_SPEED   = 16
local JUMP_POWER   = 55
local GRAV_ACCEL   = 80
local LAND_DIST    = 3.1
local RAY_DIST     = 9
local NORMAL_SPEED = 12

-- ID da animação de andar (padrão do Roblox)
local WALK_ANIM_ID = "rbxassetid://180435571" -- "OldSchool" ou similar, pode ser trocado

-- ==============================
-- ESTADO
-- ==============================
local ativo      = false
local loop       = nil
local animTrack  = nil

local myPos      = Vector3.zero
local myNormal   = Vector3.new(0, 1, 0)
local myVelN     = 0
local noChao     = false
local pulando    = false

-- ==============================
-- RAYCAST
-- ==============================
local function detectar(hrp, normal)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { player.Character }

    local pos = hrp.Position
    local cf = hrp.CFrame
    local dirs = {
        -normal,
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
-- CFRAME: Alinha o personagem à superfície e rotaciona com a câmera
-- ==============================
local function makeCF(pos, normal, camLook)
    -- Projeta o LookVector no plano da superfície
    local fwd = camLook - camLook:Dot(normal) * normal
    if fwd.Magnitude < 0.01 then
        fwd = camera.CFrame.RightVector
        fwd = fwd - fwd:Dot(normal) * normal
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
-- ANIMAÇÕES
-- ==============================
local function loadAnim(hum)
    local anim = Instance.new("Animation")
    anim.AnimationId = WALK_ANIM_ID
    animTrack = hum:LoadAnimation(anim)
    animTrack.Priority = Enum.AnimationPriority.Movement
    animTrack.Looped = true
end

local function stopAnim()
    if animTrack then
        animTrack:Stop()
        animTrack = nil
    end
end

-- ==============================
-- LIGAR
-- ==============================
local function ligar()
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    hum.PlatformStand = true
    loadAnim(hum)

    myPos    = hrp.Position
    myNormal = Vector3.new(0, 1, 0)
    myVelN   = 0
    noChao   = false
    pulando  = false

    loop = RunService.Heartbeat:Connect(function(dt)
        if not ativo then return end
        
        local c = player.Character
        local h = c and c:FindFirstChild("HumanoidRootPart")
        local u = c and c:FindFirstChildOfClass("Humanoid")
        if not h or not u then return end

        -- 1. DETECÇÃO
        local norm, dist, pt = detectar(h, myNormal)

        -- 2. GRAVIDADE
        myVelN = myVelN - GRAV_ACCEL * dt

        -- 3. MOVIMENTO WASD (Intuitivo com a Câmera)
        local mX, mZ = 0, 0
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then mZ = -1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then mZ =  1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then mX = -1 end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then mX =  1 end

        -- Direções da câmera (LookVector e RightVector)
        local camCF = camera.CFrame
        local cLook = camCF.LookVector
        local cRgt  = camCF.RightVector

        -- Projeção no plano da superfície
        local moveDir = Vector3.zero
        if mZ ~= 0 or mX ~= 0 then
            -- Para o W e S, usamos o LookVector (mesmo que aponte para cima/baixo)
            -- Para o A e D, o RightVector
            local dirW = cLook * (-mZ)
            local dirA = cRgt * mX
            moveDir = (dirW + dirA)
            
            -- Removemos a componente da normal para garantir que estamos no plano
            moveDir = moveDir - moveDir:Dot(myNormal) * myNormal
            if moveDir.Magnitude > 0.01 then
                moveDir = moveDir.Unit * WALK_SPEED
            end
        end

        -- 4. ANIMAÇÃO
        if moveDir.Magnitude > 1 and noChao then
            if not animTrack.IsPlaying then
                animTrack:Play()
            end
            animTrack:AdjustSpeed(1)
        else
            animTrack:Stop(0.2)
        end

        -- 5. PULO
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) and noChao and not pulando then
            myVelN  = JUMP_POWER
            noChao  = false
            pulando = true
            task.delay(0.55, function() pulando = false end)
        end

        -- 6. ATUALIZA POSIÇÃO
        myPos = myPos + (myNormal * myVelN * dt) + (moveDir * dt)

        -- 7. COLISÃO/ATERRIZAGEM
        if norm then
            -- Magnetismo suave para a superfície
            if dist < RAY_DIST * 0.9 then
                myNormal = myNormal:Lerp(norm, math.min(dt * NORMAL_SPEED, 1)).Unit
            end

            if dist <= LAND_DIST and myVelN <= 0 then
                myVelN = 0
                noChao = true
                myPos  = pt + norm * LAND_DIST
                myNormal = myNormal:Lerp(norm, 0.5).Unit
            else
                noChao = false
            end
        else
            noChao = false
        end

        -- 8. APLICA CFRAME
        h.CFrame = makeCF(myPos, myNormal, cLook)
        h.AssemblyLinearVelocity  = Vector3.zero
        h.AssemblyAngularVelocity = Vector3.zero
    end)
end

-- ==============================
-- DESLIGAR
-- ==============================
local function desligar()
    ativo = false
    if loop then loop:Disconnect(); loop = nil end
    stopAnim()

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
    gui.Name = "LagatixaGUI"
    gui.ResetOnSpawn = false
    gui.Parent = player.PlayerGui

    local win = Instance.new("Frame", gui)
    win.Size = UDim2.new(0, 200, 0, 100)
    win.Position = UDim2.new(0, 50, 0.5, -50)
    win.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    win.Active = true
    win.Draggable = true
    Instance.new("UICorner", win)

    local btn = Instance.new("TextButton", win)
    btn.Size = UDim2.new(0.8, 0, 0.4, 0)
    btn.Position = UDim2.new(0.1, 0, 0.3, 0)
    btn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
    btn.Text = "ATIVAR LAGATIXA"
    btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamBold
    Instance.new("UICorner", btn)

    local function updateUI()
        btn.Text = ativo and "DESATIVAR" or "ATIVAR LAGATIXA"
        btn.BackgroundColor3 = ativo and Color3.fromRGB(180, 40, 40) or Color3.fromRGB(40, 180, 80)
    end

    btn.MouseButton1Click:Connect(function()
        ativo = not ativo
        updateUI()
        if ativo then ligar() else desligar() end
    end)
end

criarGUI()

player.CharacterAdded:Connect(function()
    if ativo then
        desligar()
        task.wait(1)
        if ativo then ligar() end
    end
end)

print("[Lagatixa v6] Ativado!")
!")
