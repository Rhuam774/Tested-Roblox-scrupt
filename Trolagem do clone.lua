-- =============================================================
--  MODO LAGATIXA  v11  -  GRAVIDADE LOCAL + PULO NA PAREDE
-- =============================================================

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ==============================
-- CONSTANTES
-- ==============================
local WALK_SPEED   = 16          -- velocidade de caminhada
local JUMP_POWER   = 55          -- intensidade do pulo
local GRAVITY      = 120         -- força da gravidade local
local STICK_DIST   = 3           -- distância "ideal" da superfície
local MAX_SURF_DIST= 10          -- distância máxima para considerar uma superfície

local ANIM_WALK = "rbxassetid://180426354"

-- ==============================
-- ESTADO
-- ==============================
local ativo          = false
local loop           = nil
local mobileControls = nil
local animTrack      = nil

-- ==============================
-- CONTROLES NATIVOS
-- ==============================
local function disableDefaultControls()
    local playerGui = player:WaitForChild("PlayerGui")
    pcall(function()
        local touchGui = playerGui:FindFirstChild("TouchGui")
        if touchGui then
            touchGui.Enabled = false
        end
    end)
    pcall(function()
        local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
        local controls = playerModule:GetControls()
        controls:Disable()
    end)
end

local function enableDefaultControls()
    pcall(function()
        local playerGui = player:WaitForChild("PlayerGui")
        local touchGui = playerGui:FindFirstChild("TouchGui")
        if touchGui then
            touchGui.Enabled = true
        end
    end)
    pcall(function()
        local playerModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
        local controls = playerModule:GetControls()
        controls:Enable()
    end)
end

-- ==============================
-- RAYCAST SUPERFÍCIE MAIS PRÓXIMA
-- ==============================
local function raycastSuperficie(pos, char)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {char}
    params.FilterType = Enum.RaycastFilterType.Exclude

    local dirs = {
        Vector3.new( 0,-1, 0),
        Vector3.new( 0, 1, 0),
        Vector3.new( 1, 0, 0),
        Vector3.new(-1, 0, 0),
        Vector3.new( 0, 0, 1),
        Vector3.new( 0, 0,-1),
    }

    local bestHit, bestDist = nil, math.huge

    for _, dir in ipairs(dirs) do
        local result = workspace:Raycast(pos, dir * MAX_SURF_DIST, params)
        if result then
            local dist = (result.Position - pos).Magnitude
            if dist < bestDist then
                bestDist = dist
                bestHit  = result
            end
        end
    end

    return bestHit, bestDist
end

-- ==============================
-- D-PAD MOBILE (SETAS + PULO)
-- ==============================
local function criarControlesMobile()
    local gui = player.PlayerGui:FindFirstChild("LagatixaGUI")
    if not gui then return end

    local controls = Instance.new("Frame")
    controls.Name = "MobileControls"
    controls.Size = UDim2.new(1, 0, 1, 0)
    controls.BackgroundTransparency = 1
    controls.Parent = gui

    local pressedUp, pressedDown = false, false
    local pressedLeft, pressedRight = false, false
    local pressedJump = false

    local function criarBotaoSeta(nome, texto, posX, posY, tamanho)
        local btn = Instance.new("TextButton")
        btn.Name = nome
        btn.Size = UDim2.new(0, tamanho, 0, tamanho)
        btn.Position = UDim2.new(0, posX, 1, posY)
        btn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
        btn.BackgroundTransparency = 0.3
        btn.BorderSizePixel = 0
        btn.Text = texto
        btn.TextSize = 28
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.AutoButtonColor = false
        btn.Parent = controls
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)
        local stroke = Instance.new("UIStroke", btn)
        stroke.Color = Color3.fromRGB(100, 150, 255)
        stroke.Thickness = 2
        stroke.Transparency = 0.5
        return btn
    end

    local tam = 60
    local esp = 5
    local baseX = 30
    local baseY = -200

    local btnUp    = criarBotaoSeta("Up",    "▲", baseX + tam + esp,       baseY - tam*2 - esp, tam)
    local btnDown  = criarBotaoSeta("Down",  "▼", baseX + tam + esp,       baseY,               tam)
    local btnLeft  = criarBotaoSeta("Left",  "◀", baseX,                   baseY - tam - esp,   tam)
    local btnRight = criarBotaoSeta("Right", "▶", baseX + tam*2 + esp*2,   baseY - tam - esp,   tam)

    local center = Instance.new("Frame")
    center.Size = UDim2.new(0, tam-10, 0, tam-10)
    center.Position = UDim2.new(0, baseX + tam + esp + 5, 1, baseY - tam - esp + 5)
    center.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
    center.BackgroundTransparency = 0.5
    center.BorderSizePixel = 0
    center.Parent = controls
    Instance.new("UICorner", center).CornerRadius = UDim.new(0, 10)

    local btnJump = Instance.new("TextButton")
    btnJump.Name = "Jump"
    btnJump.Size = UDim2.new(0, 90, 0, 90)
    btnJump.Position = UDim2.new(1, -120, 1, -180)
    btnJump.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
    btnJump.BackgroundTransparency = 0.2
    btnJump.BorderSizePixel = 0
    btnJump.Text = "PULO"
    btnJump.TextSize = 18
    btnJump.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnJump.Font = Enum.Font.GothamBold
    btnJump.AutoButtonColor = false
    btnJump.Parent = controls
    Instance.new("UICorner", btnJump).CornerRadius = UDim.new(1, 0)
    local jumpStroke = Instance.new("UIStroke", btnJump)
    jumpStroke.Color = Color3.fromRGB(100, 255, 150)
    jumpStroke.Thickness = 3

    local function highlight(btn, on)
        local goal = on and {
            BackgroundColor3 = Color3.fromRGB(100,150,255),
            BackgroundTransparency = 0.1
        } or {
            BackgroundColor3 = Color3.fromRGB(50,50,70),
            BackgroundTransparency = 0.3
        }
        TweenService:Create(btn, TweenInfo.new(0.08), goal):Play()
    end
    local function highlightJump(on)
        local goal = on and {
            BackgroundColor3 = Color3.fromRGB(50,255,150),
            BackgroundTransparency = 0
        } or {
            BackgroundColor3 = Color3.fromRGB(0,180,100),
            BackgroundTransparency = 0.2
        }
        TweenService:Create(btnJump, TweenInfo.new(0.08), goal):Play()
    end

    local function bindDir(btn, flag)
        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                if flag == "Up"    then pressedUp    = true end
                if flag == "Down"  then pressedDown  = true end
                if flag == "Left"  then pressedLeft  = true end
                if flag == "Right" then pressedRight = true end
                highlight(btn, true)
            end
        end)
        btn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                if flag == "Up"    then pressedUp    = false end
                if flag == "Down"  then pressedDown  = false end
                if flag == "Left"  then pressedLeft  = false end
                if flag == "Right" then pressedRight = false end
                highlight(btn, false)
            end
        end)
    end

    bindDir(btnUp, "Up")
    bindDir(btnDown, "Down")
    bindDir(btnLeft, "Left")
    bindDir(btnRight, "Right")

    btnJump.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            pressedJump = true
            highlightJump(true)
        end
    end)
    btnJump.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            pressedJump = false
            highlightJump(false)
        end
    end)

    return {
        getMoveX = function()
            local x = 0
            if pressedLeft  then x -= 1 end
            if pressedRight then x += 1 end
            return x
        end,
        getMoveZ = function()
            local z = 0
            if pressedUp   then z += 1 end
            if pressedDown then z -= 1 end
            return z
        end,
        getJump = function()
            return pressedJump
        end,
        destroy = function()
            controls:Destroy()
        end
    }
end

-- ==============================
-- ANIMAÇÃO
-- ==============================
local function setupAnimacao(hum)
    if animTrack then
        animTrack:Stop()
        animTrack = nil
    end
    local ok, track = pcall(function()
        local animator = hum:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = hum
        end
        local anim = Instance.new("Animation")
        anim.AnimationId = ANIM_WALK
        return animator:LoadAnimation(anim)
    end)
    if ok and track then
        animTrack = track
        animTrack.Looped = true
        animTrack.Priority = Enum.AnimationPriority.Movement
    end
end

local function atualizarAnimacao(andando)
    if not animTrack then return end
    if andando then
        if not animTrack.IsPlaying then
            animTrack:Play(0.1)
        end
    else
        if animTrack.IsPlaying then
            animTrack:Stop(0.1)
        end
    end
end

-- ==============================
-- LIGAR
-- ==============================
local function ligar()
    local char = player.Character
    if not char then return end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    disableDefaultControls()

    hum.PlatformStand = true
    hrp.Anchored = false

    local bodyVel = Instance.new("BodyVelocity")
    bodyVel.Name = "LagatixaVel"
    bodyVel.MaxForce = Vector3.new(5e4, 5e4, 5e4)
    bodyVel.Velocity = Vector3.zero
    bodyVel.Parent = hrp

    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.Name = "LagatixaGyro"
    bodyGyro.MaxTorque = Vector3.new(5e4, 5e4, 5e4)
    bodyGyro.P = 4000
    bodyGyro.D = 600
    bodyGyro.CFrame = hrp.CFrame
    bodyGyro.Parent = hrp

    setupAnimacao(hum)

    mobileControls = criarControlesMobile()
    if not mobileControls then return end

    -- ESTADO FÍSICO LOCAL
    local surfNormal   = Vector3.new(0,1,0)   -- "cima" local (normal da superfície)
    local surfVel      = 0                    -- velocidade ao longo da normal (positivo: indo pra dentro da superfície)
    local onSurface    = false
    local canJump      = true

    loop = RunService.Heartbeat:Connect(function(dt)
        if not ativo then return end
        if not char or not char.Parent then return end
        if not hrp or not hrp.Parent then return end

        local velObj  = hrp:FindFirstChild("LagatixaVel")
        local gyroObj = hrp:FindFirstChild("LagatixaGyro")
        if not velObj or not gyroObj then return end

        local moveX = mobileControls.getMoveX()
        local moveZ = mobileControls.getMoveZ()
        local wantsJump = mobileControls.getJump()

        -- DIREÇÕES PROJETADAS NA SUPERFÍCIE
        local camCF    = camera.CFrame
        local camLook  = camCF.LookVector
        local camRight = camCF.RightVector

        local forward = camLook - camLook:Dot(surfNormal) * surfNormal
        if forward.Magnitude < 0.01 then
            forward = Vector3.new(0,0,-1)
        else
            forward = forward.Unit
        end

        local right = camRight - camRight:Dot(surfNormal) * surfNormal
        if right.Magnitude < 0.01 then
            right = Vector3.new(1,0,0)
        else
            right = right.Unit
        end

        local moveDir = forward * moveZ + right * moveX
        local lateralVel = Vector3.zero
        local andando = false
        if moveDir.Magnitude > 0.1 then
            lateralVel = moveDir.Unit * WALK_SPEED
            andando = true
        end
        atualizarAnimacao(andando)

        -- DETECTA SUPERFÍCIE MAIS PRÓXIMA
        local hit, dist = raycastSuperficie(hrp.Position, char)
        if hit and dist <= MAX_SURF_DIST then
            -- Normal da superfície: "cima" local
            surfNormal = surfNormal:Lerp(hit.Normal, dt * 12)
            if surfNormal.Magnitude < 0.001 then
                surfNormal = Vector3.new(0,1,0)
            else
                surfNormal = surfNormal.Unit
            end

            -- Gravidade sempre puxa PARA a superfície
            -- => velocidade ao longo da normal aumenta NO SENTIDO DA NORMAL
            surfVel = surfVel + GRAVITY * dt   -- positivo: indo "pra dentro" da superfície

            -- Ver se está "encostado" na superfície
            if dist < STICK_DIST and surfVel > 0 then
                onSurface = true
                surfVel = 0

                -- Corrige posição para ficar a STICK_DIST da superfície
                local alvoPos = hit.Position + hit.Normal * STICK_DIST
                local corr = (alvoPos - hrp.Position) * 10
                velObj.Velocity = lateralVel + corr
            else
                onSurface = false
                -- Movimento no eixo da normal
                velObj.Velocity = lateralVel + surfNormal * surfVel
            end
        else
            -- Sem superfície próxima: gravidade tradicional pra baixo
            onSurface = false
            surfNormal = surfNormal:Lerp(Vector3.new(0,1,0), dt * 3)
            surfVel = surfVel + GRAVITY * dt
            velObj.Velocity = lateralVel + Vector3.new(0, -surfVel, 0)
        end

        -- PULO LOCAL:
        -- Se está encostado em uma superfície, pulo = impulso CONTRA a normal (pra fora da parede/teto)
        if wantsJump and onSurface and canJump then
            surfVel = -JUMP_POWER     -- negativo => vai na direção oposta da superfície
            onSurface = false
            canJump = false
            task.delay(0.35, function()
                canJump = true
            end)
        end

        -- ORIENTAÇÃO: em pé na superfície
        local upVec   = surfNormal
        local lookVec = forward
        if lookVec.Magnitude < 0.01 then
            lookVec = Vector3.new(0,0,-1)
        end

        local rightVec = lookVec:Cross(upVec)
        if rightVec.Magnitude < 0.01 then
            rightVec = Vector3.new(1,0,0)
        end
        rightVec = rightVec.Unit
        lookVec  = upVec:Cross(rightVec).Unit

        local targetCF = CFrame.fromMatrix(hrp.Position, rightVec, upVec, -lookVec)
        gyroObj.CFrame = targetCF
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
    if animTrack then
        animTrack:Stop()
        animTrack = nil
    end

    enableDefaultControls()

    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hum then hum.PlatformStand = false end
        if hrp then
            local v = hrp:FindFirstChild("LagatixaVel")
            local g = hrp:FindFirstChild("LagatixaGyro")
            if v then v:Destroy() end
            if g then g:Destroy() end
            hrp.AssemblyLinearVelocity  = Vector3.zero
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
    gui.Name = "LagatixaGUI"
    gui.ResetOnSpawn = false
    gui.Parent = player.PlayerGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 220, 0, 100)
    frame.Position = UDim2.new(0.5, -110, 0, 10)
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 14)
    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Color3.fromRGB(0, 170, 255)
    stroke.Thickness = 2

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 35)
    title.BackgroundTransparency = 1
    title.Text = "🦎 LAGATIXA v11"
    title.TextColor3 = Color3.fromRGB(0, 220, 255)
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 45)
    btn.Position = UDim2.new(0, 10, 0, 45)
    btn.BackgroundColor3 = Color3.fromRGB(0, 150, 100)
    btn.BorderSizePixel = 0
    btn.Text = "▶ LIGAR"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 18
    btn.Font = Enum.Font.GothamBold
    btn.Parent = frame
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

    btn.MouseButton1Click:Connect(function()
        ativo = not ativo
        if ativo then
            btn.Text = "■ DESLIGAR"
            btn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            TweenService:Create(stroke, TweenInfo.new(0.3), {Color = Color3.fromRGB(0, 255, 100)}):Play()
            ligar()
        else
            btn.Text = "▶ LIGAR"
            btn.BackgroundColor3 = Color3.fromRGB(0, 150, 100)
            TweenService:Create(stroke, TweenInfo.new(0.3), {Color = Color3.fromRGB(0, 170, 255)}):Play()
            desligar()
        end
    end)
end

-- ==============================
-- INÍCIO
-- ==============================
criarGUI()

player.CharacterAdded:Connect(function()
    if ativo then
        desligar()
        task.wait(2)
        if ativo then ligar() end
    end
end)

print("[LAGATIXA v11] Pronto!")
