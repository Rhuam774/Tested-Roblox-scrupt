-- =============================================================
--  LAGATIXA v11 - WALL JUMP PERFEITO DE LAGARTIXA 🦎
--  Salta pra fora da parede e gruda de volta automaticamente
-- =============================================================

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- CONFIGS
local WALK_SPEED   = 18
local JUMP_POWER   = 80      -- força do salto pra fora
local GRAVITY      = 196.2
local STICK_DIST   = 3.3
local ANIM_WALK_ID = "rbxassetid://180426354"

-- ESTADO
local ativo = false
local loop = nil
local controls = nil
local animTrack = nil
local surfaceNormal = Vector3.new(0,1,0)
local lastWallNormal = Vector3.new(0,1,0)  -- guarda a última parede que grudou

-- RAYCAST 6 DIREÇÕES
local function detectarSuperficie(pos, char)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {char}
    params.FilterType = Enum.RaycastFilterType.Exclude

    local dirs = {
        Vector3.new(0,-1,0), Vector3.new(0,1,0),
        Vector3.new(1,0,0), Vector3.new(-1,0,0),
        Vector3.new(0,0,1), Vector3.new(0,0,-1)
    }

    local melhor = nil
    local menorDist = math.huge

    for _, dir in dirs do
        local res = workspace:Raycast(pos, dir * 12, params)
        if res then
            local d = (res.Position - pos).Magnitude
            if d < menorDist then
                menorDist = d
                melhor = res
            end
        end
    end

    return melhor, menorDist
end

-- CONTROLES MOBILE (D-PAD)
local function criarControles()
    local gui = player.PlayerGui:FindFirstChild("LagatixaGUI")
    if not gui then return end

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1,0,1,0)
    frame.BackgroundTransparency = 1
    frame.Name = "LagatixaControls"
    frame.Parent = gui

    local pressed = {W=false, S=false, A=false, D=false, Jump=false}

    local function btn(nome, texto, x, y, size)
        local b = Instance.new("TextButton")
        b.Name = nome
        b.Size = UDim2.new(0,size,0,size)
        b.Position = UDim2.new(0,x,1,y)
        b.BackgroundColor3 = Color3.fromRGB(30,30,50)
        b.BackgroundTransparency = 0.3
        b.Text = texto
        b.TextSize = 34
        b.TextColor3 = Color3.new(1,1,1)
        b.Font = Enum.Font.GothamBold
        b.AutoButtonColor = false
        b.Parent = frame
        Instance.new("UICorner", b).CornerRadius = UDim.new(0,16)

        b.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch then
                pressed[nome] = true
                TweenService:Create(b, TweenInfo.new(0.1), {BackgroundTransparency = 0}):Play()
            end
        end)
        b.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.Touch then
                pressed[nome] = false
                TweenService:Create(b, TweenInfo.new(0.1), {BackgroundTransparency = 0.3}):Play()
            end
        end)
    end

    btn("W", "▲", 110, -210, 68)
    btn("S", "▼", 110, -134, 68)
    btn("A", "◀", 42, -172, 68)
    btn("D", "▶", 178, -172, 68)

    -- BOTÃO PULO
    local jump = Instance.new("TextButton")
    jump.Size = UDim2.new(0,110,0,110)
    jump.Position = UDim2.new(1,-140,1,-190)
    jump.BackgroundColor3 = Color3.fromRGB(0,220,110)
    jump.BackgroundTransparency = 0.2
    jump.Text = "PULO"
    jump.TextSize = 24
    jump.TextColor3 = Color3.new(1,1,1)
    jump.Font = Enum.Font.GothamBold
    jump.Parent = frame
    Instance.new("UICorner", jump).CornerRadius = UDim.new(1,0)

    jump.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch then
            pressed.Jump = true
            jump.BackgroundColor3 = Color3.fromRGB(0,255,140)
        end
    end)
    jump.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch then
            pressed.Jump = false
            jump.BackgroundColor3 = Color3.fromRGB(0,220,110)
        end
    end)

    return {
        getX = function() return (pressed.D and 1 or 0) + (pressed.A and -1 or 0) end,
        getZ = function() return (pressed.W and 1 or 0) + (pressed.S and -1 or 0) end,
        getJump = function() return pressed.Jump end,
        destroy = function() frame:Destroy() end
    }
end

-- ANIMAÇÃO
local function setupAnim(hum)
    if animTrack then animTrack:Stop() end
    local anim = Instance.new("Animation")
    anim.AnimationId = ANIM_WALK_ID
    animTrack = hum:LoadAnimation(anim)
    animTrack.Looped = true
    animTrack.Priority = Enum.AnimationPriority.Movement
end

local function playWalk(movendo)
    if not animTrack then return end
    if movendo then
        if not animTrack.IsPlaying then animTrack:Play(0.1) end
    else
        if animTrack.IsPlaying then animTrack:Stop(0.2) end
    end
end

-- LIGAR
local function ligar()
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    local hum = char:WaitForChild("Humanoid")

    -- Desativa controles do jogo
    pcall(function() player.PlayerGui.TouchGui.Enabled = false end)
    hum.PlatformStand = true

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e5,1e5,1e5)
    bv.Velocity = Vector3.zero
    bv.P = 1500
    bv.Parent = hrp

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e5,1e5,1e5)
    bg.P = 6000
    bg.D = 1000
    bg.CFrame = hrp.CFrame
    bg.Parent = hrp

    setupAnim(hum)
    controls = criarControles()

    local noChao = true
    local podePular = true

    loop = RunService.Heartbeat:Connect(function(dt)
        if not ativo then return end

        local moveX = controls.getX()
        local moveZ = controls.getZ()
        local pulando = controls.getJump()

        local camLook = camera.CFrame.LookVector
        local camRight = camera.CFrame.RightVector

        -- Direção de movimento na superfície
        local frente = camLook - camLook:Dot(surfaceNormal) * surfaceNormal
        frente = frente.Magnitude > 0.1 and frente.Unit or -camLook.Unit

        local direita = camRight - camRight:Dot(surfaceNormal) * surfaceNormal
        direita = direita.Magnitude > 0.1 and direita.Unit or camRight.Unit

        local velLateral = (frente * moveZ + direita * moveX) * WALK_SPEED
        playWalk(velLateral.Magnitude > 3)

        -- Detecta superfície
        local hit, dist = detectarSuperficie(hrp.Position, char)

        if hit and dist < 6 then
            -- Atualiza normal suavemente
            surfaceNormal = surfaceNormal:Lerp(hit.Normal, dt * 15)
            surfaceNormal = surfaceNormal.Unit
            lastWallNormal = surfaceNormal  -- guarda a parede atual

            if dist <= STICK_DIST then
                noChao = true
                local grude = (hit.Position + hit.Normal * STICK_DIST - hrp.Position) * 20
                bv.Velocity = velLateral + grude
            else
                noChao = false
                bv.Velocity = velLateral + surfaceNormal * (-GRAVITY * dt * 30)
            end
        else
            noChao = false
            surfaceNormal = surfaceNormal:Lerp(Vector3.new(0,1,0), dt * 5)
        end

        -- === WALL JUMP PERFEITO DA LAGARTIXA ===
        if pulando and noChao and podePular then
            -- Impulso pra FORA da parede (direção da cabeça)
            bv.Velocity = lastWallNormal * JUMP_POWER + velLateral * 0.4
            noChao = false
            podePular = false

            -- Força o personagem a virar de costas pra parede (efeito lagartixa)
            task.wait(0.08)  -- momento exato do ápice do salto
            if ativo and hrp.Parent then
                surfaceNormal = -lastWallNormal  -- inverte a gravidade!
                bg.CFrame = CFrame.fromMatrix(hrp.Position, 
                    camera.CFrame.RightVector, 
                    -lastWallNormal, 
                    camera.CFrame.LookVector)
            end

            task.delay(0.5, function() podePular = true end)
        end

        -- Orientação correta
        local up = surfaceNormal
        local look = frente
        local rightVec = look:Cross(up).Unit
        if rightVec.Magnitude > 0.01 then
            look = up:Cross(rightVec).Unit
            bg.CFrame = CFrame.fromMatrix(hrp.Position, rightVec, up, -look)
        end
    end)
end

-- DESLIGAR
local function desligar()
    if loop then loop:Disconnect() loop = nil end
    if controls then controls.destroy() controls = nil end
    if animTrack then animTrack:Stop() animTrack = nil end

    pcall(function() player.PlayerGui.TouchGui.Enabled = true end)

    local char = player.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hum then hum.PlatformStand = false end
        if hrp then
            for _, v in hrp:GetChildren() do
                if v:IsA("BodyVelocity") or v:IsA("BodyGyro") then v:Destroy() end
            end
        end
    end
end

-- GUI
local function criarGUI()
    local old = player.PlayerGui:FindFirstChild("LagatixaGUI")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "LagatixaGUI"
    gui.ResetOnSpawn = false
    gui.Parent = player.PlayerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0,260,0,110)
    frame.Position = UDim2.new(0.5,-130,0,10)
    frame.BackgroundColor3 = Color3.fromRGB(8,8,18)
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0,18)

    local stroke = Instance.new("UIStroke", frame)
    stroke.Thickness = 3
    stroke.Color = Color3.fromRGB(0,255,200)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1,0,0,44)
    title.BackgroundTransparency = 1
    title.Text = "🦎 LAGATIXA v11"
    title.TextColor3 = Color3.fromRGB(0,255,200)
    title.TextSize = 22
    title.Font = Enum.Font.GothamBold
    title.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,-24,0,50)
    btn.Position = UDim2.new(0,12,0,54)
    btn.BackgroundColor3 = Color3.fromRGB(0,200,100)
    btn.Text = "ATIVAR"
    btn.TextColor3 = Color3.new(1,1,1)
    btn.TextSize = 22
    btn.Font = Enum.Font.GothamBold
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,14)

    btn.MouseButton1Click:Connect(function()
        ativo = not ativo
        if ativo then
            btn.Text = "DESATIVAR"
            btn.BackgroundColor3 = Color3.fromRGB(230,50,50)
            stroke.Color = Color3.fromRGB(255,100,100)
            ligar()
        else
            btn.Text = "ATIVAR"
            btn.BackgroundColor3 = Color3.fromRGB(0,200,100)
            stroke.Color = Color3.fromRGB(0,255,200)
            desligar()
        end
    end)
end

criarGUI()
print("LAGATIXA v11 CARREGADA - WALL JUMP PERFEITO DA LAGARTIXA!")

-- Recomenda-se usar em jogos com paredes grandes (ex: Tower of Hell, Parkour, etc)
