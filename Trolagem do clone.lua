-- =============================================================
--  MODO LAGATIXA  v14  -  SEM TREMOR (CORRIGIDO)
-- =============================================================

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local WALK_SPEED = 16
local JUMP_POWER = 50
local GRAVITY    = 196.2
local STICK_DIST = 1.5  -- FIX: valor menor para evitar oscilação

local ativo = false
local loop = nil
local mobileControls = nil
local animTracks = {}
local animInstances = {}

local savedWalkSpeed = 16
local savedJumpPower = 50
local savedJumpHeight = 7.2

-- Estado de movimento
local surfaceNormal = Vector3.new(0, 1, 0)
local verticalVelocity = 0
local isGrounded = false
local canJump = true
local currentForward = Vector3.new(0, 0, -1)
local jumpingFromSurface = false
local jumpSurfaceNormal = Vector3.new(0, 1, 0)
local currentAnim = ""
local smoothGyroCF = nil

-- =============================================================
-- FIX #1: Raycast simplificado — só para baixo (não 6 direções)
-- O raycast em 6 direções detectava paredes/tetos e causava
-- oscilação na força de "grudar no chão"
-- =============================================================
local function raycastChao(pos, char)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {char}
	params.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(pos, Vector3.new(0, -10, 0), params)
	return result
end

-- ==============================
-- ANIMAÇÕES
-- ==============================
local function pararTodasAnimacoes()
	for _, track in pairs(animTracks) do
		if track and track.IsPlaying then
			track:Stop(0.2)
		end
	end
end

local function limparAnimacoes()
	pararTodasAnimacoes()
	animTracks = {}
	for _, inst in ipairs(animInstances) do
		if inst and inst.Parent then inst:Destroy() end
	end
	animInstances = {}
end

local function carregarAnimacoes(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return false end

	limparAnimacoes()

	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		track:Stop(0)
	end

	local isR6 = char:FindFirstChild("Torso") ~= nil and char:FindFirstChild("UpperTorso") == nil

	local anims
	if isR6 then
		anims = {
			idle = "rbxassetid://180435571",
			walk = "rbxassetid://180426354",
			jump = "rbxassetid://125750702",
			fall = "rbxassetid://180436148",
		}
	else
		anims = {
			idle = "rbxassetid://507766666",
			walk = "rbxassetid://507777826",
			jump = "rbxassetid://507765000",
			fall = "rbxassetid://507767968",
		}
	end

	local carregadas = 0
	for nome, id in pairs(anims) do
		local ok = pcall(function()
			local animObj = Instance.new("Animation")
			animObj.AnimationId = id
			animObj.Name = "Lagatixa_" .. nome
			animObj.Parent = char

			local track = animator:LoadAnimation(animObj)
			-- FIX: Action3 em vez de Action4 — menos agressivo,
			-- permite que a animação complete sem ser interrompida
			track.Priority = Enum.AnimationPriority.Action3
			track.Looped = (nome ~= "jump")

			animTracks[nome] = track
			table.insert(animInstances, animObj)
			carregadas += 1
		end)
	end

	return carregadas > 0
end

-- =============================================================
-- FIX #2: Só troca animação quando muda de estado
-- NÃO reinicia a cada frame — isso impedia a animação de completar
-- =============================================================
local function tocarAnimacao(nome, velocidade)
	velocidade = velocidade or 1
	local track = animTracks[nome]
	if not track then return end

	if currentAnim == nome and track.IsPlaying then
		-- Já está tocando a animação certa, só ajusta velocidade
		track:AdjustSpeed(velocidade)
		return
	end

	-- Para outras animações
	for n, t in pairs(animTracks) do
		if n ~= nome and t and t.IsPlaying then
			t:Stop(0.2)
		end
	end

	currentAnim = nome
	track:Play(0.2)
	track:AdjustSpeed(velocidade)
end

-- ==============================
-- CONTROLES MOBILE
-- ==============================
local function criarControlesMobile()
	local gui = player.PlayerGui:FindFirstChild("LagatixaGUI")
	if not gui then return end

	local controls = Instance.new("Frame")
	controls.Name = "MobileControls"
	controls.Size = UDim2.new(1, 0, 1, 0)
	controls.BackgroundTransparency = 1
	controls.Parent = gui

	local moveX = 0
	local moveZ = 0
	local wantsJump = false

	local function criarSeta(nome, texto, posX, posY, parentFrame)
		local btn = Instance.new("TextButton")
		btn.Name = nome
		btn.Size = UDim2.new(0, 65, 0, 65)
		btn.Position = UDim2.new(0, posX, 0, posY)
		btn.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
		btn.BackgroundTransparency = 0.3
		btn.BorderSizePixel = 0
		btn.Text = texto
		btn.TextSize = 32
		btn.TextColor3 = Color3.fromRGB(200, 220, 255)
		btn.Font = Enum.Font.GothamBold
		btn.Parent = parentFrame
		btn.AutoButtonColor = false
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)
		local stroke = Instance.new("UIStroke", btn)
		stroke.Color = Color3.fromRGB(0, 150, 255)
		stroke.Thickness = 2
		stroke.Transparency = 0.4
		return btn
	end

	local dpadFrame = Instance.new("Frame")
	dpadFrame.Name = "DPad"
	dpadFrame.Size = UDim2.new(0, 205, 0, 205)
	dpadFrame.Position = UDim2.new(0, 15, 1, -220)
	dpadFrame.BackgroundTransparency = 1
	dpadFrame.Parent = controls

	local btnCima  = criarSeta("Cima",  "▲", 70, 0,   dpadFrame)
	local btnBaixo = criarSeta("Baixo", "▼", 70, 140, dpadFrame)
	local btnEsq   = criarSeta("Esq",  "◀", 0,  70,  dpadFrame)
	local btnDir   = criarSeta("Dir",  "▶", 140, 70, dpadFrame)

	local centro = Instance.new("Frame")
	centro.Size = UDim2.new(0, 55, 0, 55)
	centro.Position = UDim2.new(0, 75, 0, 75)
	centro.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
	centro.BackgroundTransparency = 0.5
	centro.BorderSizePixel = 0
	centro.Parent = dpadFrame
	Instance.new("UICorner", centro).CornerRadius = UDim.new(0, 10)

	local jumpBtn = Instance.new("TextButton")
	jumpBtn.Name = "JumpBtn"
	jumpBtn.Size = UDim2.new(0, 90, 0, 90)
	jumpBtn.Position = UDim2.new(1, -120, 1, -160)
	jumpBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
	jumpBtn.BackgroundTransparency = 0.2
	jumpBtn.BorderSizePixel = 0
	jumpBtn.Text = "⬆"
	jumpBtn.TextSize = 42
	jumpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	jumpBtn.Font = Enum.Font.GothamBold
	jumpBtn.AutoButtonColor = false
	jumpBtn.Parent = controls
	Instance.new("UICorner", jumpBtn).CornerRadius = UDim.new(1, 0)
	Instance.new("UIStroke", jumpBtn).Color = Color3.fromRGB(0, 255, 150)

	local jumpLabel = Instance.new("TextLabel")
	jumpLabel.Size = UDim2.new(1, 0, 0, 20)
	jumpLabel.Position = UDim2.new(0, 0, 1, 5)
	jumpLabel.BackgroundTransparency = 1
	jumpLabel.Text = "PULO"
	jumpLabel.TextColor3 = Color3.fromRGB(0, 220, 120)
	jumpLabel.TextSize = 14
	jumpLabel.Font = Enum.Font.GothamBold
	jumpLabel.Parent = jumpBtn

	local pressing = { Cima = false, Baixo = false, Esq = false, Dir = false }

	local function atualizarMove()
		moveZ = 0; moveX = 0
		if pressing.Cima then moveZ += 1 end
		if pressing.Baixo then moveZ -= 1 end
		if pressing.Esq then moveX -= 1 end
		if pressing.Dir then moveX += 1 end
	end

	local corNormal = Color3.fromRGB(30, 30, 50)
	local corPress  = Color3.fromRGB(0, 120, 255)

	local function conectarSeta(btn, nome)
		btn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				pressing[nome] = true
				btn.BackgroundColor3 = corPress
				btn.BackgroundTransparency = 0.1
				atualizarMove()
			end
		end)
		btn.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				pressing[nome] = false
				btn.BackgroundColor3 = corNormal
				btn.BackgroundTransparency = 0.3
				atualizarMove()
			end
		end)
	end

	conectarSeta(btnCima, "Cima")
	conectarSeta(btnBaixo, "Baixo")
	conectarSeta(btnEsq, "Esq")
	conectarSeta(btnDir, "Dir")

	jumpBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			wantsJump = true
			jumpBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
		end
	end)
	jumpBtn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			wantsJump = false
			jumpBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
		end
	end)

	return {
		getMoveX = function() return moveX end,
		getMoveZ = function() return moveZ end,
		getJump = function() return wantsJump end,
		resetJump = function() wantsJump = false end,
		destroy = function() controls:Destroy() end,
	}
end

-- ==============================
-- CABEÇA
-- ==============================
local function atualizarCabeca(char)
	local neck = nil
	for _, partName in ipairs({"Head", "UpperTorso", "Torso"}) do
		local part = char:FindFirstChild(partName)
		if part then
			for _, obj in ipairs(part:GetChildren()) do
				if obj:IsA("Motor6D") and obj.Name == "Neck" then
					neck = obj; break
				end
			end
		end
		if neck then break end
	end
	if not neck or not neck.Part0 then return end

	local localLook = neck.Part0.CFrame:VectorToObjectSpace(camera.CFrame.LookVector)
	local yaw = math.clamp(math.atan2(-localLook.X, -localLook.Z), -1.2, 1.2)
	local pitch = math.clamp(math.asin(math.clamp(localLook.Y, -1, 1)), -1.0, 1.0)

	local isR6 = char:FindFirstChild("Torso") ~= nil and char:FindFirstChild("UpperTorso") == nil
	local base = isR6 and CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0) or CFrame.new(0, 1, 0)
	neck.C0 = base * CFrame.Angles(pitch, yaw, 0)
end

-- ==============================
-- LIGAR
-- ==============================
local function ligar()
	local char = player.Character
	if not char then return end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return end

	local animate = char:FindFirstChild("Animate")
	if animate then animate.Disabled = true end

	local animator = hum:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			track:Stop(0)
		end
	end

	task.wait(0.1)
	carregarAnimacoes(char)

	savedWalkSpeed = hum.WalkSpeed
	savedJumpPower = hum.JumpPower
	savedJumpHeight = hum.JumpHeight

	-- FIX #3: Usar PlatformStand em vez de desativar estados + Physics
	-- PlatformStand diz ao Humanoid para NÃO controlar o personagem,
	-- eliminando a luta entre BodyVelocity/BodyGyro e o motor de física
	hum.PlatformStand = true
	hum.AutoRotate = false

	hrp.Anchored = false

	-- FIX #4: BodyVelocity com valores mais suaves
	-- MaxForce alto, mas P moderado (não excessivo) para evitar oscilação
	local bodyVel = Instance.new("BodyVelocity")
	bodyVel.MaxForce = Vector3.new(1e5, 0, 1e5)  -- FIX: Y = 0, dejamos que a gravidade funcione
	bodyVel.Velocity = Vector3.zero
	bodyVel.P = 2500  -- FIX: valor moderado (era 1250, mas com Y=0 precisa de mais responsividade no XZ)
	bodyVel.Parent = hrp

	local bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
	bodyGyro.P = 3000   -- FIX: valor moderado (era 5000) — menos rígido = menos tremor
	bodyGyro.D = 200    -- FIX: valor moderado (era 500) — damping suficiente sem causar atraso
	bodyGyro.CFrame = hrp.CFrame
	bodyGyro.Parent = hrp

	mobileControls = criarControlesMobile()
	if not mobileControls then return end

	-- Resetar estado
	surfaceNormal = Vector3.new(0, 1, 0)
	verticalVelocity = 0
	isGrounded = false
	canJump = true
	currentForward = hrp.CFrame.LookVector
	jumpingFromSurface = false
	jumpSurfaceNormal = Vector3.new(0, 1, 0)
	currentAnim = ""
	smoothGyroCF = hrp.CFrame

	task.wait(0.2)
	tocarAnimacao("idle", 1)

	-- FIX #5: REMOVIDO o stateTimer que forçava Physics a cada 0.5s
	-- Isso causava micro-interrupções no movimento

	-- FIX #6: Variável para debounce de animação (não restartar desnecessariamente)
	local animCheckTimer = 0

	loop = RunService.Heartbeat:Connect(function(dt)
		if not ativo then return end
		if not char or not char.Parent then return end
		if not hrp or not hrp.Parent then return end

		-- FIX: Clampa dt para evitar teleporte em lag spikes
		dt = math.min(dt, 0.05)

		local mx = mobileControls.getMoveX()
		local mz = mobileControls.getMoveZ()
		local wantsJump = mobileControls.getJump()

		local camCF = camera.CFrame
		local camLook = camCF.LookVector
		local camRight = camCF.RightVector

		-- Projetar câmera no plano da superfície
		local forward = (camLook - camLook:Dot(surfaceNormal) * surfaceNormal)
		if forward.Magnitude > 0.01 then
			forward = forward.Unit
		else
			forward = Vector3.new(0, 0, -1)
		end

		local right = (camRight - camRight:Dot(surfaceNormal) * surfaceNormal)
		if right.Magnitude > 0.01 then
			right = right.Unit
		else
			right = Vector3.new(1, 0, 0)
		end

		local moveDir = forward * mz + right * mx
		local isMoving = moveDir.Magnitude > 0.1

		if isMoving then
			currentForward = moveDir.Unit
		end

		local lateralVel = Vector3.zero
		if isMoving then
			lateralVel = moveDir.Unit * WALK_SPEED
		end

		-- RAYCAST SIMPLIFICADO: só para baixo
		local hit = raycastChao(hrp.Position, char)

		if hit then
			local dist = (hit.Position - hrp.Position).Magnitude

			-- Suavizar normal da superfície
			surfaceNormal = surfaceNormal:Lerp(hit.Normal, math.min(dt * 8, 1))
			if surfaceNormal.Magnitude > 0.01 then
				surfaceNormal = surfaceNormal.Unit
			else
				surfaceNormal = Vector3.new(0, 1, 0)
			end

			if dist < STICK_DIST and verticalVelocity <= 0 then
				-- No chão
				isGrounded = true
				verticalVelocity = 0
				jumpingFromSurface = false

				-- FIX: Força de stick mais suave (menos agressiva)
				-- Usa lerp suave em vez de correção brusca
				local targetPos = hit.Position + hit.Normal * STICK_DIST
				local stickForce = (targetPos - hrp.Position) * 5  -- FIX: valor menor (era 10)

				bodyVel.Velocity = lateralVel + stickForce
			else
				-- No ar perto do chão
				isGrounded = false
				verticalVelocity -= GRAVITY * dt

				if jumpingFromSurface then
					bodyVel.Velocity = lateralVel + jumpSurfaceNormal * verticalVelocity
				else
					bodyVel.Velocity = lateralVel + surfaceNormal * verticalVelocity
				end
			end
		else
			-- Longe de superfícies
			isGrounded = false
			verticalVelocity -= GRAVITY * dt

			if jumpingFromSurface then
				bodyVel.Velocity = lateralVel + jumpSurfaceNormal * verticalVelocity
				if verticalVelocity < -JUMP_POWER * 2 then
					jumpingFromSurface = false
				end
			else
				bodyVel.Velocity = lateralVel + Vector3.new(0, verticalVelocity, 0)
				surfaceNormal = surfaceNormal:Lerp(Vector3.new(0, 1, 0), math.min(dt * 3, 1))
			end
		end

		-- PULO
		if wantsJump and isGrounded and canJump then
			local isFloor = hit and hit.Normal:Dot(Vector3.new(0, 1, 0)) > 0.8

			if isFloor then
				verticalVelocity = JUMP_POWER
				isGrounded = false
				jumpingFromSurface = false
			else
				jumpSurfaceNormal = surfaceNormal
				verticalVelocity = JUMP_POWER
				isGrounded = false
				jumpingFromSurface = true
			end
			canJump = false
			mobileControls.resetJump()
			task.delay(0.3, function() canJump = true end)
		end

		-- ANIMAÇÕES — FIX #7: Só muda quando o estado muda
		local newAnim = "idle"
		if not isGrounded then
			if verticalVelocity > 5 then
				newAnim = "jump"
			else
				newAnim = "fall"
			end
		elseif isMoving then
			newAnim = "walk"
		end

		-- Só toca animação quando muda de estado (não a cada frame)
		if newAnim ~= currentAnim then
			tocarAnimacao(newAnim, 1)
		end

		-- Ajusta velocidade da animação de andar
		if currentAnim == "walk" and animTracks["walk"] and animTracks["walk"].IsPlaying then
			local speed = math.clamp(lateralVel.Magnitude / WALK_SPEED, 0.3, 1.5)
			animTracks["walk"]:AdjustSpeed(speed)
		end

		-- FIX #8: Só verifica se animação parou a cada 0.3s (não a cada frame)
		animCheckTimer += dt
		if animCheckTimer >= 0.3 then
			animCheckTimer = 0
			if animTracks[currentAnim] and not animTracks[currentAnim"].IsPlaying then
				tocarAnimacao(currentAnim, 1)
			end
		end

		-- ORIENTAÇÃO SUAVIZADA
		local upVec = surfaceNormal
		local lookVec = currentForward

		lookVec = (lookVec - lookVec:Dot(upVec) * upVec)
		if lookVec.Magnitude > 0.01 then
			lookVec = lookVec.Unit
		else
			lookVec = forward
		end

		local rightVec = lookVec:Cross(upVec)
		if rightVec.Magnitude > 0.01 then
			rightVec = rightVec.Unit
		else
			rightVec = Vector3.new(1, 0, 0)
		end
		lookVec = upVec:Cross(rightVec).Unit

		local targetCF = CFrame.fromMatrix(hrp.Position, rightVec, upVec, -lookVec)

		-- FIX #9: Suavização adaptativa
		-- Quando parado: lerp suave (não causa tremor por micro-correções)
		-- Quando andando: lerp mais rápido (responsivo)
		local lerpRate = isMoving and 15 or 6
		local lerpSpeed = math.min(dt * lerpRate, 1)
		smoothGyroCF = smoothGyroCF:Lerp(targetCF, lerpSpeed)
		bodyGyro.CFrame = smoothGyroCF

		-- CABEÇA
		atualizarCabeca(char)
	end)
end

-- ==============================
-- DESLIGAR
-- ==============================
local function desligar()
	if loop then loop:Disconnect(); loop = nil end
	if mobileControls then mobileControls.destroy(); mobileControls = nil end

	limparAnimacoes()

	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")

		if hum then
			hum.PlatformStand = false
			hum.WalkSpeed = savedWalkSpeed or 16
			hum.JumpPower = savedJumpPower or 50
			hum.JumpHeight = savedJumpHeight or 7.2
			hum.AutoRotate = true
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end

		local animate = char:FindFirstChild("Animate")
		if animate then animate.Disabled = false end

		-- Reset Neck
		for _, partName in ipairs({"Head", "UpperTorso", "Torso"}) do
			local part = char:FindFirstChild(partName)
			if part then
				for _, obj in ipairs(part:GetChildren()) do
					if obj:IsA("Motor6D") and obj.Name == "Neck" then
						local isR6 = char:FindFirstChild("Torso") ~= nil and char:FindFirstChild("UpperTorso") == nil
						if isR6 then
							obj.C0 = CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
						else
							obj.C0 = CFrame.new(0, 1, 0)
						end
					end
				end
			end
		end

		for _, obj in ipairs(char:GetChildren()) do
			if obj:IsA("Animation") and obj.Name:find("Lagatixa_") then
				obj:Destroy()
			end
		end

		if hrp then
			for _, obj in ipairs(hrp:GetChildren()) do
				if obj:IsA("BodyVelocity") or obj:IsA("BodyGyro") then
					obj:Destroy()
				end
			end
			hrp.AssemblyLinearVelocity = Vector3.zero
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
	frame.Size = UDim2.new(0, 280, 0, 120)
	frame.Position = UDim2.new(0.5, -140, 0, 20)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	frame.BorderSizePixel = 2
	frame.BorderColor3 = Color3.fromRGB(0, 170, 255)
	frame.Active = true
	frame.Draggable = true
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	title.BorderSizePixel = 0
	title.Text = "🦎 LAGATIXA v14"
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

criarGUI()

player.CharacterAdded:Connect(function()
	if ativo then
		desligar()
		task.wait(2)
		if ativo then ligar() end
	end
end)

print("[LAGATIXA v14] Sem tremor ✓")
