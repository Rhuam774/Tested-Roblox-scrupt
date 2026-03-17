
-- =============================================================
--  MODO LAGATIXA  v9  -  VERSÃO MOBILE COM SETAS
-- =============================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local TweenService     = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ==============================
-- CONSTANTES
-- ==============================
local WALK_SPEED   = 16
local JUMP_POWER   = 50
local GRAVITY      = 196.2
local STICK_DIST   = 3

-- ==============================
-- ESTADO
-- ==============================
local ativo = false
local loop = nil
local mobileControls = nil

-- ==============================
-- RAYCAST SIMPLES
-- ==============================
local function raycastChao(pos, char)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {char}
	params.FilterType = Enum.RaycastFilterType.Exclude

	local dirs = {
		Vector3.new(0, -1, 0),
		Vector3.new(0, 1, 0),
		Vector3.new(1, 0, 0),
		Vector3.new(-1, 0, 0),
		Vector3.new(0, 0, 1),
		Vector3.new(0, 0, -1),
	}

	local melhorHit = nil
	local melhorDist = math.huge

	for _, dir in ipairs(dirs) do
		local result = workspace:Raycast(pos, dir * 10, params)
		if result then
			local dist = (result.Position - pos).Magnitude
			if dist < melhorDist then
				melhorDist = dist
				melhorHit = result
			end
		end
	end

	return melhorHit, melhorDist
end

-- ==============================
-- CONTROLES MOBILE COM SETAS
-- ==============================
local function criarControlesMobile()
	local gui = player.PlayerGui:FindFirstChild("LagatixaGUI")
	if not gui then return end

	local controls = Instance.new("Frame")
	controls.Name = "MobileControls"
	controls.Size = UDim2.new(1, 0, 1, 0)
	controls.BackgroundTransparency = 1
	controls.Parent = gui

	-- Estado do input
	local moveX = 0
	local moveZ = 0
	local wantsJump = false

	-- ============================
	-- FUNÇÃO PARA CRIAR BOTÃO SETA
	-- ============================
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

		local corner = Instance.new("UICorner", btn)
		corner.CornerRadius = UDim.new(0, 12)

		local stroke = Instance.new("UIStroke", btn)
		stroke.Color = Color3.fromRGB(0, 150, 255)
		stroke.Thickness = 2
		stroke.Transparency = 0.4

		return btn
	end

	-- ============================
	-- CONTAINER DAS SETAS (ESQUERDA)
	-- ============================
	local dpadFrame = Instance.new("Frame")
	dpadFrame.Name = "DPad"
	dpadFrame.Size = UDim2.new(0, 205, 0, 205)
	dpadFrame.Position = UDim2.new(0, 15, 1, -220)
	dpadFrame.BackgroundTransparency = 1
	dpadFrame.Parent = controls

	--         [CIMA]
	--  [ESQ] [     ] [DIR]
	--        [BAIXO]

	local btnCima   = criarSeta("Cima",   "▲", 70, 0,   dpadFrame)
	local btnBaixo  = criarSeta("Baixo",  "▼", 70, 140, dpadFrame)
	local btnEsq    = criarSeta("Esq",    "◀", 0,  70,  dpadFrame)
	local btnDir    = criarSeta("Dir",     "▶", 140, 70, dpadFrame)

	-- Centro decorativo
	local centro = Instance.new("Frame")
	centro.Size = UDim2.new(0, 55, 0, 55)
	centro.Position = UDim2.new(0, 75, 0, 75)
	centro.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
	centro.BackgroundTransparency = 0.5
	centro.BorderSizePixel = 0
	centro.Parent = dpadFrame
	Instance.new("UICorner", centro).CornerRadius = UDim.new(0, 10)

	-- ============================
	-- BOTÃO DE PULO (DIREITA)
	-- ============================
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

	local jumpCorner = Instance.new("UICorner", jumpBtn)
	jumpCorner.CornerRadius = UDim.new(1, 0)

	local jumpStroke = Instance.new("UIStroke", jumpBtn)
	jumpStroke.Color = Color3.fromRGB(0, 255, 150)
	jumpStroke.Thickness = 3

	local jumpLabel = Instance.new("TextLabel")
	jumpLabel.Size = UDim2.new(1, 0, 0, 20)
	jumpLabel.Position = UDim2.new(0, 0, 1, 5)
	jumpLabel.BackgroundTransparency = 1
	jumpLabel.Text = "PULO"
	jumpLabel.TextColor3 = Color3.fromRGB(0, 220, 120)
	jumpLabel.TextSize = 14
	jumpLabel.Font = Enum.Font.GothamBold
	jumpLabel.Parent = jumpBtn

	-- ============================
	-- ESTADO DAS SETAS
	-- ============================
	local pressing = {
		Cima = false,
		Baixo = false,
		Esq = false,
		Dir = false,
	}

	local function atualizarMove()
		moveZ = 0
		moveX = 0
		if pressing.Cima then moveZ = moveZ + 1 end
		if pressing.Baixo then moveZ = moveZ - 1 end
		if pressing.Esq then moveX = moveX - 1 end
		if pressing.Dir then moveX = moveX + 1 end
	end

	local corNormal  = Color3.fromRGB(30, 30, 50)
	local corPress   = Color3.fromRGB(0, 120, 255)

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

	conectarSeta(btnCima,  "Cima")
	conectarSeta(btnBaixo, "Baixo")
	conectarSeta(btnEsq,   "Esq")
	conectarSeta(btnDir,    "Dir")

	-- Eventos do Botão de Pulo
	jumpBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			wantsJump = true
			jumpBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 150)
			jumpBtn.BackgroundTransparency = 0.1
		end
	end)

	jumpBtn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			wantsJump = false
			jumpBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
			jumpBtn.BackgroundTransparency = 0.2
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
-- LIGAR
-- ==============================
local function ligar()
	local char = player.Character
	if not char then return end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")

	if not hrp or not hum then return end

	hum.PlatformStand = true
	hrp.Anchored = false

	local bodyVel = Instance.new("BodyVelocity")
	bodyVel.MaxForce = Vector3.new(4e4, 4e4, 4e4)
	bodyVel.Velocity = Vector3.zero
	bodyVel.Parent = hrp

	local bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(4e4, 4e4, 4e4)
	bodyGyro.P = 3000
	bodyGyro.D = 500
	bodyGyro.CFrame = hrp.CFrame
	bodyGyro.Parent = hrp

	mobileControls = criarControlesMobile()
	if not mobileControls then
		warn("Erro ao criar controles mobile!")
		return
	end

	local surfaceNormal = Vector3.new(0, 1, 0)
	local verticalVelocity = 0
	local isGrounded = false
	local canJump = true

	-- Direção do "forward" do personagem (na superfície)
	local currentForward = Vector3.new(0, 0, -1)

	-- Estado do pulo na superfície (parede/teto)
	-- Quando pula, salta na direção da cabeça (surfaceNormal) e
	-- depois a gravidade puxa de volta para a superfície
	local jumpingFromSurface = false
	local jumpSurfaceNormal = Vector3.new(0, 1, 0)

	loop = RunService.Heartbeat:Connect(function(dt)
		if not ativo then return end
		if not char or not char.Parent then return end
		if not hrp or not hrp.Parent then return end

		local mx = mobileControls.getMoveX()
		local mz = mobileControls.getMoveZ()
		local wantsJump = mobileControls.getJump()

		-- DIREÇÕES DA CÂMERA
		local camCF = camera.CFrame
		local camLook = camCF.LookVector
		local camRight = camCF.RightVector

		-- Projeta na superfície
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

		-- Guarda forward atual
		local moveDir = forward * mz + right * mx
		if moveDir.Magnitude > 0.1 then
			currentForward = moveDir.Unit
		end

		-- MOVIMENTO LATERAL
		local lateralVel = Vector3.zero
		if moveDir.Magnitude > 0.1 then
			lateralVel = moveDir.Unit * WALK_SPEED
		end

		-- DETECÇÃO DE SUPERFÍCIE
		local hit, dist = raycastChao(hrp.Position, char)

		-- Verifica se está no chão normal (normal apontando pra cima)
		local isFloor = false
		if hit then
			isFloor = hit.Normal:Dot(Vector3.new(0, 1, 0)) > 0.8
		end

		if hit and dist < 5 then
			surfaceNormal = surfaceNormal:Lerp(hit.Normal, dt * 10)
			if surfaceNormal.Magnitude > 0 then
				surfaceNormal = surfaceNormal.Unit
			else
				surfaceNormal = Vector3.new(0, 1, 0)
			end

			if dist < STICK_DIST and verticalVelocity <= 0 then
				isGrounded = true
				verticalVelocity = 0
				jumpingFromSurface = false

				local stickForce = (hit.Position + hit.Normal * STICK_DIST - hrp.Position) * 10
				bodyVel.Velocity = lateralVel + stickForce
			else
				isGrounded = false

				if jumpingFromSurface then
					-- Gravidade puxa de volta para a superfície de onde pulou
					-- A "gravidade" age na direção OPOSTA à normal da superfície
					verticalVelocity = verticalVelocity - GRAVITY * dt
					bodyVel.Velocity = lateralVel + jumpSurfaceNormal * verticalVelocity
				else
					verticalVelocity = verticalVelocity - GRAVITY * dt
					bodyVel.Velocity = lateralVel + surfaceNormal * verticalVelocity
				end
			end
		else
			isGrounded = false

			if jumpingFromSurface then
				-- Continua com gravidade relativa à superfície
				verticalVelocity = verticalVelocity - GRAVITY * dt
				bodyVel.Velocity = lateralVel + jumpSurfaceNormal * verticalVelocity

				-- Se já caiu demais sem achar superfície, volta ao normal
				if verticalVelocity < -JUMP_POWER * 2 then
					jumpingFromSurface = false
				end
			else
				verticalVelocity = verticalVelocity - GRAVITY * dt
				bodyVel.Velocity = lateralVel + Vector3.new(0, verticalVelocity, 0)
				surfaceNormal = surfaceNormal:Lerp(Vector3.new(0, 1, 0), dt * 5)
			end
		end

		-- ============================
		-- PULO
		-- ============================
		if wantsJump and isGrounded and canJump then
			if isFloor then
				-- CHÃO NORMAL: pulo normal pra cima
				verticalVelocity = JUMP_POWER
				isGrounded = false
				jumpingFromSurface = false
			else
				-- PAREDE OU TETO: salta na direção da cabeça (surfaceNormal)
				-- e depois cai de volta na superfície
				jumpSurfaceNormal = surfaceNormal
				verticalVelocity = JUMP_POWER
				isGrounded = false
				jumpingFromSurface = true
			end

			canJump = false
			mobileControls.resetJump()

			task.delay(0.3, function()
				canJump = true
			end)
		end

		-- ORIENTAÇÃO
		local upVec = surfaceNormal
		local lookVec = currentForward

		-- Garante que lookVec seja perpendicular ao upVec
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
		bodyGyro.CFrame = targetCF
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

	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")

		if hum then
			hum.PlatformStand = false
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

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	title.BorderSizePixel = 0
	title.Text = "🦎 LAGATIXA MOBILE"
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

-- ==============================
-- INICIO
-- ==============================
criarGUI()

player.CharacterAdded:Connect(function()
	if ativo then
		desligar()
		task.wait(2)
		if ativo then ligar() end
	end
end)

print("[LAGATIXA MOBILE v9] Pronto! Setas + Pulo Inteligente")
