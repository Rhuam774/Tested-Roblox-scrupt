-- =============================================================
--  MODO LAGATIXA v10  —  ANIMAÇÃO PROCEDURAL REALISTA
-- =============================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ═══════════════════════════════════════════════════════════════
--  CONSTANTES
-- ═══════════════════════════════════════════════════════════════
local WALK_SPEED = 16
local JUMP_POWER = 50
local GRAVITY    = 196.2
local STICK_DIST = 3

-- Animação
local WALK_PHASE_SPEED  = 2.8   -- velocidade base do ciclo
local ARM_SWING         = 0.65  -- amplitude do braço (rad)
local LEG_SWING         = 0.60  -- amplitude da perna (rad)
local BODY_BOB          = 0.10  -- vertical sobe-e-desce
local BODY_SWAY         = 0.04  -- balanço lateral
local SHOULDER_CTR      = 0.10  -- contra-rotação dos ombros
local IDLE_BREATH       = 0.06  -- respiração sutil
local IDLE_HEAD_SWAY    = 0.08  -- movimento de cabeça parado

-- ═══════════════════════════════════════════════════════════════
--  ESTADO
-- ═══════════════════════════════════════════════════════════════
local ativo     = false
local loopConn  = nil
local mobileControls = nil

local walkPhase     = 0
local verticalVel   = 0
local isGrounded    = false
local jumpFromWall  = false
local jumpNormal    = Vector3.yAxis
local surfaceNormal = Vector3.yAxis
local smoothUp      = Vector3.yAxis
local smoothFwd     = -Vector3.zAxis
local canJump       = true

-- Referências do personagem
local char, hrp, hum

-- Juntas (Motor6D) — R6 ou R15
local J = {}          -- ex: J.LArm, J.RHip ...
local cachedC0 = {}   -- C0 original de cada junta

-- ═══════════════════════════════════════════════════════════════
--  UTILITÁRIOS
-- ═══════════════════════════════════════════════════════════════
local function smoothstep(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- ═══════════════════════════════════════════════════════════════
--  SISTEMA DE JUNTAS
-- ═══════════════════════════════════════════════════════════════
local function findJoints(c)
	J = {}
	if not c then return end

	local function findIn(name, parts)
		for _, pName in ipairs(parts) do
			local part = c:FindFirstChild(pName)
			if part then
				for _, obj in ipairs(part:GetChildren()) do
					if obj:IsA("Motor6D") and obj.Name == name then
						return obj
					end
				end
			end
		end
		return nil
	end

	J.Neck      = findIn("Neck",      {"Head", "UpperTorso", "Torso"})
	J.RootJoint = findIn("RootJoint", {"HumanoidRootPart"})
	J.Root      = findIn("Root",      {"HumanoidRootPart"})

	if c:FindFirstChild("UpperTorso") then -- R15
		J.LArm = findIn("LeftShoulder",  {"LeftUpperArm"})
		J.RArm = findIn("RightShoulder", {"RightUpperArm"})
		J.LLeg = findIn("LeftHip",       {"LeftUpperLeg"})
		J.RLeg = findIn("RightHip",      {"RightUpperLeg"})
		J.LElb = findIn("LeftElbow",     {"LeftLowerArm"})
		J.RElb = findIn("RightElbow",    {"RightLowerArm"})
	else -- R6
		J.LArm = findIn("Left Shoulder",  {"Torso"})
		J.RArm = findIn("Right Shoulder", {"Torso"})
		J.LLeg = findIn("Left Hip",       {"Torso"})
		J.RLeg = findIn("Right Hip",      {"Torso"})
	end
end

local function cacheOriginals()
	cachedC0 = {}
	for name, j in pairs(J) do
		if j then cachedC0[name] = j.C0 end
	end
end

-- ═══════════════════════════════════════════════════════════════
--  CÁLCULO DE POSE PROCEDURAL
-- ═══════════════════════════════════════════════════════════════
local function calcPose(phase, isMoving, isGround, spd)
	-- spd: fator de velocidade (0..1+) para intensificar a animação

	if not isGround then
		-- NO AR: braços para cima / pernas levemente dobradas
		return {
			LArm = CFrame.Angles(-1.1, 0, 0.1),
			RArm = CFrame.Angles(-1.1, 0, -0.1),
			LLeg = CFrame.Angles(0.25, 0, 0),
			RLeg = CFrame.Angles(0.25, 0, 0),
			Root = CFrame.new(0, 0, 0),
			Neck = CFrame.new(0, 0, 0),
			LElb = CFrame.Angles(-0.5, 0, 0),
			RElb = CFrame.Angles(-0.5, 0, 0),
		}
	end

	if isMoving then
		-- ═══ ANDANDO ═══
		-- Pernas: oposição perfeita
		local lLeg =  math.sin(phase) * LEG_SWING
		local rLeg =  math.sin(phase + math.pi) * LEG_SWING
		-- Pequena deflexão lateral (joelho para fora)
		local lLegZ = math.sin(phase) * 0.08
		local rLegZ = -math.sin(phase) * 0.08

		-- Braços: oposição às pernas
		local lArm = math.sin(phase + math.pi) * ARM_SWING
		local rArm = math.sin(phase) * ARM_SWING
		-- Balanço lateral dos braços
		local lArmZ = math.sin(phase + math.pi) * 0.12
		local rArmZ = -math.sin(phase) * 0.12

		-- Contra-rotação dos ombros (o corpo acompanha o balanço)
		local shoulderRoll = math.sin(phase) * SHOULDER_CTR

		-- Bob vertical (passo)
		local bob = math.abs(math.sin(phase * 2)) * BODY_BOB
		-- Sway lateral
		local sway = math.sin(phase) * BODY_SWAY

		-- Pescoço sutilmente compensa o bob
		local neckBob = -bob * 0.3

		-- Cotovelos levemente flexionados
		local elbowBend = 0.3 + math.abs(math.sin(phase)) * 0.2

		return {
			LArm = CFrame.Angles(lArm, 0, lArmZ + shoulderRoll),
			RArm = CFrame.Angles(rArm, 0, rArmZ + shoulderRoll),
			LLeg = CFrame.Angles(lLeg, 0, lLegZ),
			RLeg = CFrame.Angles(rLeg, 0, rLegZ),
			Root = CFrame.new(sway, bob, 0),
			Neck = CFrame.new(0, neckBob, 0),
			LElb = CFrame.Angles(-elbowBend, 0, 0),
			RElb = CFrame.Angles(-elbowBend, 0, 0),
		}
	else
		-- ═══ PARADO (IDLE) ═══
		local t = tick()
		local breath = math.sin(t * 1.8) * IDLE_BREATH
		local headSway = math.sin(t * 0.7) * IDLE_HEAD_SWAY

		-- Braços levemente afastados do corpo, com "respiração"
		local armRest = 0.12 + breath * 0.5

		return {
			LArm = CFrame.Angles(armRest, 0, 0.08),
			RArm = CFrame.Angles(armRest, 0, -0.08),
			LLeg = CFrame.Angles(0, 0, 0.03),
			RLeg = CFrame.Angles(0, 0, -0.03),
			Root = CFrame.new(0, breath * 0.4, 0),
			Neck = CFrame.Angles(0, headSway, 0),
			LElb = CFrame.Angles(-0.15, 0, 0),
			RElb = CFrame.Angles(-0.15, 0, 0),
		}
	end
end

-- ═══════════════════════════════════════════════════════════════
--  APLICAR / RESETAR POSE
-- ═══════════════════════════════════════════════════════════════
local function applyPose(pose, lerpFactor)
	for name, j in pairs(J) do
		if j then
			local orig = cachedC0[name]
			local delta = pose[name]
			if orig and delta then
				j.C0 = orig:Lerp(delta, lerpFactor)
			end
		end
	end
end

local function resetAllJoints()
	for name, j in pairs(J) do
		if j and cachedC0[name] then
			j.C0 = cachedC0[name]
		end
	end
end

-- ═══════════════════════════════════════════════════════════════
--  RAYCAST — DETECÇÃO DE SUPERFÍCIE
-- ═══════════════════════════════════════════════════════════════
local function castSixDirections(pos)
	if not char then return nil, math.huge end
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {char}
	params.FilterType = Enum.RaycastFilterType.Exclude

	local dirs = {
		Vector3.yAxis,    -Vector3.yAxis,
		Vector3.xAxis,    -Vector3.xAxis,
		Vector3.zAxis,    -Vector3.zAxis,
	}
	local best, bestDist = nil, math.huge
	for _, d in ipairs(dirs) do
		local r = workspace:Raycast(pos, d * 10, params)
		if r then
			local dist = (r.Position - pos).Magnitude
			if dist < bestDist then best, bestDist = r, dist end
		end
	end
	return best, bestDist
end

-- ═══════════════════════════════════════════════════════════════
--  CONTROLES MOBILE
-- ═══════════════════════════════════════════════════════════════
local function createMobileControls()
	local gui = player.PlayerGui:FindFirstChild("LagatixaGUI")
	if not gui then return nil end

	local container = Instance.new("Frame")
	container.Name = "MobileControls"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Parent = gui

	local mx, mz = 0, 0
	local wJump = false

	local function btn(parent, name, txt, x, y, w, h)
		local b = Instance.new("TextButton")
		b.Name = name
		b.Size = UDim2.new(0, w, 0, h)
		b.Position = UDim2.new(0, x, 0, y)
		b.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
		b.BackgroundTransparency = 0.3
		b.BorderSizePixel = 0
		b.Text = txt
		b.TextSize = 32
		b.TextColor3 = Color3.fromRGB(200, 220, 255)
		b.Font = Enum.Font.GothamBold
		b.AutoButtonColor = false
		b.Parent = parent
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 12)
		local s = Instance.new("UIStroke", b)
		s.Color = Color3.fromRGB(0, 150, 255)
		s.Thickness = 2
		s.Transparency = 0.4
		return b
	end

	-- D-PAD
	local pad = Instance.new("Frame")
	pad.Name = "DPad"
	pad.Size = UDim2.new(0, 205, 0, 205)
	pad.Position = UDim2.new(0, 15, 1, -220)
	pad.BackgroundTransparency = 1
	pad.Parent = container

	local bU = btn(pad, "Cima",  "▲",  70, 0,   65, 65)
	local bD = btn(pad, "Baixo", "▼",  70, 140, 65, 65)
	local bL = btn(pad, "Esq",   "◀",  0,  70,  65, 65)
	local bR = btn(pad, "Dir",   "▶",  140, 70,  65, 65)

	local centro = Instance.new("Frame")
	centro.Size = UDim2.new(0, 55, 0, 55)
	centro.Position = UDim2.new(0, 75, 0, 75)
	centro.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
	centro.BackgroundTransparency = 0.5
	centro.BorderSizePixel = 0
	centro.Parent = pad
	Instance.new("UICorner", centro).CornerRadius = UDim.new(0, 10)

	-- JUMP
	local jBtn = Instance.new("TextButton")
	jBtn.Name = "JumpBtn"
	jBtn.Size = UDim2.new(0, 90, 0, 90)
	jBtn.Position = UDim2.new(1, -120, 1, -160)
	jBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
	jBtn.BackgroundTransparency = 0.2
	jBtn.BorderSizePixel = 0
	jBtn.Text = "⬆"
	jBtn.TextSize = 42
	jBtn.TextColor3 = Color3.new(1, 1, 1)
	jBtn.Font = Enum.Font.GothamBold
	jBtn.AutoButtonColor = false
	jBtn.Parent = container
	Instance.new("UICorner", jBtn).CornerRadius = UDim.new(1, 0)
	local js = Instance.new("UIStroke", jBtn)
	js.Color = Color3.fromRGB(0, 255, 150)
	js.Thickness = 3
	local jl = Instance.new("TextLabel")
	jl.Size = UDim2.new(1, 0, 0, 20)
	jl.Position = UDim2.new(0, 0, 1, 5)
	jl.BackgroundTransparency = 1
	jl.Text = "PULO"
	jl.TextColor3 = Color3.fromRGB(0, 220, 120)
	jl.TextSize = 14
	jl.Font = Enum.Font.GothamBold
	jl.Parent = jBtn

	-- Lógica de input
	local pressing = { Cima = false, Baixo = false, Esq = false, Dir = false }
	local cN = Color3.fromRGB(30, 30, 50)
	local cP = Color3.fromRGB(0, 120, 255)

	local function updM()
		mz = 0; mx = 0
		if pressing.Cima  then mz += 1 end
		if pressing.Baixo then mz -= 1 end
		if pressing.Esq   then mx -= 1 end
		if pressing.Dir   then mx += 1 end
	end

	local function hook(b, nm)
		b.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
				pressing[nm] = true; b.BackgroundColor3 = cP; b.BackgroundTransparency = 0.1; updM()
			end
		end)
		b.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
				pressing[nm] = false; b.BackgroundColor3 = cN; b.BackgroundTransparency = 0.3; updM()
			end
		end)
	end
	hook(bU, "Cima");  hook(bD, "Baixo");  hook(bL, "Esq");  hook(bR, "Dir")

	jBtn.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			wJump = true
			jBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
			jBtn.BackgroundTransparency = 0.1
		end
	end)
	jBtn.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			wJump = false
			jBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
			jBtn.BackgroundTransparency = 0.2
		end
	end)

	return {
		getX = function() return mx end,
		getZ = function() return mz end,
		getJump = function() return wJump end,
		resetJump = function() wJump = false end,
		destroy = function() container:Destroy() end,
	}
end

-- ═══════════════════════════════════════════════════════════════
--  LIGAR  (ativa o modo lagatixa)
-- ═══════════════════════════════════════════════════════════════
local function ligar()
	char = player.Character
	if not char then return end
	hrp = char:FindFirstChild("HumanoidRootPart")
	hum = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return end

	-- Desativa animações padrão
	local animScript = char:FindFirstChild("Animate")
	if animScript then animScript.Disabled = true end
	for _, t in ipairs(hum:GetPlayingAnimationTracks()) do t:Stop(0) end

	-- Encontra e armazena juntas
	findJoints(char)
	cacheOriginals()

	hum.PlatformStand = true

	-- Motores de física
	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(4e4, 4e4, 4e4)
	bv.Velocity = Vector3.zero
	bv.Parent = hrp

	local bg = Instance.new("BodyGyro")
	bg.MaxTorque = Vector3.new(4e4, 4e4, 4e4)
	bg.P = 3000
	bg.D = 500
	bg.CFrame = hrp.CFrame
	bg.Parent = hrp

	-- Controles
	mobileControls = createMobileControls()
	if not mobileControls then return end

	-- Reseta estado
	walkPhase   = 0
	verticalVel = 0
	isGrounded  = false
	jumpFromWall = false
	surfaceNormal = Vector3.yAxis
	smoothUp  = Vector3.yAxis
	smoothFwd = -Vector3.zAxis
	canJump   = true

	-- ══════════════════════════════════════════════════════════════
	--  LOOP PRINCIPAL
	-- ══════════════════════════════════════════════════════════════
	loopConn = RunService.Heartbeat:Connect(function(dt)
		if not ativo or not char or not char.Parent or not hrp or not hrp.Parent then return end

		local inpX = mobileControls.getX()
		local inpZ = mobileControls.getZ()
		local wJump = mobileControls.getJump()

		-- ────────────────────────────────
		--  DIREÇÕES BASEADAS NA CÂMERA
		-- ────────────────────────────────
		local camCF    = camera.CFrame
		local camLook  = camCF.LookVector
		local camRight = camCF.RightVector

		-- Projeta no plano da superfície
		local fwd = camLook - camLook:Dot(surfaceNormal) * surfaceNormal
		if fwd.Magnitude > 0.01 then fwd = fwd.Unit else fwd = Vector3.new(0, 0, -1) end

		local rgt = camRight - camRight:Dot(surfaceNormal) * surfaceNormal
		if rgt.Magnitude > 0.01 then rgt = rgt.Unit else rgt = Vector3.new(1, 0, 0) end

		-- Direção de movimento
		local moveDir = fwd * inpZ + rgt * inpX
		local isMoving = moveDir.Magnitude > 0.1

		if isMoving then
			moveDir = moveDir.Unit
		end

		-- Forward do corpo
		if isMoving then
			smoothFwd = smoothFwd:Lerp(moveDir, dt * 8)
		else
			-- Parado: olha na direção da câmera (projetada)
			local camF = camLook - camLook:Dot(surfaceNormal) * surfaceNormal
			if camF.Magnitude > 0.01 then
				smoothFwd = smoothFwd:Lerp(camF.Unit, dt * 5)
			end
		end
		if smoothFwd.Magnitude > 0.001 then smoothFwd = smoothFwd.Unit end

		-- ────────────────────────────────
		--  DETECÇÃO DE CHÃO
		-- ────────────────────────────────
		local hit, dist = castSixDirections(hrp.Position)

		if hit and dist < 5 then
			surfaceNormal = surfaceNormal:Lerp(hit.Normal, dt * 10)
			if surfaceNormal.Magnitude > 0.001 then
				surfaceNormal = surfaceNormal.Unit
			else
				surfaceNormal = Vector3.yAxis
			end
		end

		-- ────────────────────────────────
		--  VELOCIDADE HORIZONTAL
		-- ────────────────────────────────
		local hVel = Vector3.zero
		if isMoving then
			hVel = moveDir * WALK_SPEED
		end

		-- ────────────────────────────────
		--  FÍSICA VERTICAL / PULO
		-- ────────────────────────────────
		if hit and dist < STICK_DIST + 0.5 and verticalVel <= 0 then
			isGrounded = true
			jumpFromWall = false
			verticalVel = 0

			local stick = (hit.Position + surfaceNormal * STICK_DIST - hrp.Position) * 12
			bv.Velocity = hVel + stick
		else
			isGrounded = false
			verticalVel = verticalVel - GRAVITY * dt

			if jumpFromWall then
				bv.Velocity = hVel + jumpNormal * verticalVel
				if verticalVel < -JUMP_POWER * 2 then
					jumpFromWall = false
				end
			else
				bv.Velocity = hVel + Vector3.new(0, verticalVel, 0)
			end

			if not hit then
				surfaceNormal = surfaceNormal:Lerp(Vector3.yAxis, dt * 5)
			end
		end

		if wJump and isGrounded and canJump then
			local isFloor = surfaceNormal:Dot(Vector3.yAxis) > 0.7
			if isFloor then
				verticalVel = JUMP_POWER
				jumpFromWall = false
			else
				jumpNormal   = surfaceNormal
				verticalVel  = JUMP_POWER
				jumpFromWall = true
			end
			isGrounded = false
			canJump = false
			mobileControls.resetJump()
			task.delay(0.35, function() canJump = true end)
		end

		-- ────────────────────────────────
		--  FASE DA ANIMAÇÃO
		-- ────────────────────────────────
		if isMoving and isGrounded then
			-- Velocidade real do BodyVelocity (para ajustar ritmo)
			local actualSpeed = math.max(bv.Velocity.X, 0) ^ 2
			+ math.max(bv.Velocity.Z, 0) ^ 2
			actualSpeed = math.sqrt(actualSpeed)

			local speedFactor = math.clamp(actualSpeed / WALK_SPEED, 0.3, 1.5)
			walkPhase = walkPhase + dt * WALK_PHASE_SPEED * speedFactor * 3.0
		end

		-- ────────────────────────────────
		--  ORIENTAÇÃO DO CORPO (BodyGyro)
		-- ────────────────────────────────
		smoothUp = smoothUp:Lerp(surfaceNormal, dt * 8)
		if smoothUp.Magnitude > 0.001 then smoothUp = smoothUp.Unit end

		local upF = smoothFwd - smoothFwd:Dot(smoothUp) * smoothUp
		if upF.Magnitude > 0.001 then upF = upF.Unit else upF = fwd end

		local upR = upF:Cross(smoothUp)
		if upR.Magnitude > 0.001 then upR = upR.Unit end

		upF = smoothUp:Cross(upR).Unit
		bg.CFrame = CFrame.fromMatrix(hrp.Position, upR, smoothUp, -upF)

		-- ────────────────────────────────
		--  ANIMAÇÃO PROCEDURAL
		-- ────────────────────────────────
		local speedFactor = 0
		if isMoving and isGrounded then
			speedFactor = 1
		end
		local pose = calcPose(walkPhase, isMoving and isGrounded, isGrounded, speedFactor)
		applyPose(pose, 0.85)
	end)
end

-- ═══════════════════════════════════════════════════════════════
--  DESLIGAR
-- ═══════════════════════════════════════════════════════════════
local function desligar()
	if loopConn then loopConn:Disconnect(); loopConn = nil end
	if mobileControls then mobileControls.destroy(); mobileControls = nil end

	resetAllJoints()
	J = {}; cachedC0 = {}

	if char then
		local h = char:FindFirstChildOfClass("Humanoid")
		local r = char:FindFirstChild("HumanoidRootPart")
		if h then h.PlatformStand = false end
		local as = char:FindFirstChild("Animate")
		if as then as.Disabled = false end
		if r then
			for _, o in ipairs(r:GetChildren()) do
				if o:IsA("BodyVelocity") or o:IsA("BodyGyro") then o:Destroy() end
			end
			r.AssemblyLinearVelocity  = Vector3.zero
			r.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

-- ═══════════════════════════════════════════════════════════════
--  GUI
-- ═══════════════════════════════════════════════════════════════
local function criarGUI()
	local old = player.PlayerGui:FindFirstChild("LagatixaGUI")
	if old then old:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "LagatixaGUI"
	gui.ResetOnSpawn = false
	gui.Parent = player.PlayerGui

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 280, 0, 120)
	frame.Position = UDim2.new(0.5, -140, 0, 20)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	frame.BorderSizePixel = 2
	frame.BorderColor3 = Color3.fromRGB(0, 170, 255)
	frame.Active = true
	frame.Draggable = true
	frame.Parent = gui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	title.BorderSizePixel = 0
	title.Text = "🦎 LAGATIXA v10"
	title.TextColor3 = Color3.fromRGB(0, 200, 255)
	title.TextSize = 18
	title.Font = Enum.Font.GothamBold
	title.Parent = frame

	local status = Instance.new("TextLabel")
	status.Size = UDim2.new(1, -20, 0, 20)
	status.Position = UDim2.new(0, 10, 0, 50)
	status.BackgroundTransparency = 1
	status.Text = "OFF"
	status.TextColor3 = Color3.fromRGB(255, 100, 100)
	status.TextSize = 16
	status.Font = Enum.Font.GothamBold
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.Parent = frame

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -20, 0, 40)
	btn.Position = UDim2.new(0, 10, 1, -50)
	btn.BackgroundColor3 = Color3.fromRGB(0, 150, 100)
	btn.BorderSizePixel = 0
	btn.Text = "LIGAR"
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextSize = 18
	btn.Font = Enum.Font.GothamBold
	btn.Parent = frame

	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

	btn.MouseButton1Click:Connect(function()
		ativo = not ativo
		if ativo then
			btn.Text = "DESLIGAR"
			btn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
			status.Text = "ON ✓"
			status.TextColor3 = Color3.fromRGB(100, 255, 100)
			ligar()
		else
			btn.Text = "LIGAR"
			btn.BackgroundColor3 = Color3.fromRGB(0, 150, 100)
			status.Text = "OFF"
			status.TextColor3 = Color3.fromRGB(255, 100, 100)
			desligar()
		end
	end)
end

-- ═══════════════════════════════════════════════════════════════
--  INÍCIO
-- ═══════════════════════════════════════════════════════════════
criarGUI()

player.CharacterAdded:Connect(function()
	if ativo then
		desligar()
		task.wait(2)
		if ativo then ligar() end
	end
end)

print("[LAGATIXA v10] Pronto! Animação procedural realista")
