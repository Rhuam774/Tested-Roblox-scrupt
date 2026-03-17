
-- =============================================================
--  MODO LAGATIXA  v10.1  -  VERSÃO MOBILE COMPLETA (CORRIGIDO)
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
local animTracks = {}
local animInstances = {}  -- ← NOVO: guarda as Animation instances vivas

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
-- SISTEMA DE ANIMAÇÕES (CORRIGIDO)
-- ==============================
local function pararTodasAnimacoes()
	for nome, track in pairs(animTracks) do
		if track and track.IsPlaying then
			track:Stop(0.1)
		end
	end
end

local function limparAnimacoes()
	pararTodasAnimacoes()
	animTracks = {}
	for _, inst in ipairs(animInstances) do
		if inst and inst.Parent then
			inst:Destroy()
		end
	end
	animInstances = {}
end

local function carregarAnimacoes(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then
		warn("[LAGATIXA] Humanoid não encontrado!")
		return
	end

	limparAnimacoes()

	-- ★ USA ANIMATOR (não deprecado)
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end

	-- ★ PARA TODAS AS ANIMAÇÕES EXISTENTES DO ANIMATOR
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		track:Stop(0)
	end

	-- ★ DETECTA R6 vs R15 e usa IDs corretas
	local isR6 = char:FindFirstChild("Torso") ~= nil and char:FindFirstChild("UpperTorso") == nil

	local anims
	if isR6 then
		anims = {
			idle = "rbxassetid://180435571",
			walk = "rbxassetid://180426354",
			jump = "rbxassetid://125750702",
			fall = "rbxassetid://180436148",
		}
		print("[LAGATIXA] Rig detectado: R6")
	else
		anims = {
			idle = "rbxassetid://507766666",
			walk = "rbxassetid://507777826",
			jump = "rbxassetid://507765000",
			fall = "rbxassetid://507767968",
		}
		print("[LAGATIXA] Rig detectado: R15")
	end

	for nome, id in pairs(anims) do
		local ok, err = pcall(function()
			local animObj = Instance.new("Animation")
			animObj.AnimationId = id
			animObj.Name = "Lagatixa_" .. nome
			-- ★ NÃO DESTRÓI — mantém viva dentro do char
			animObj.Parent = char

			local track = animator:LoadAnimation(animObj)
			-- ★ PRIORIDADE ALTA para sobrescrever qualquer outra
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = (nome == "idle" or nome == "walk" or nome == "fall")

			animTracks[nome] = track
			table.insert(animInstances, animObj)

			print("[LAGATIXA] Animação carregada: " .. nome .. " (" .. id .. ")")
		end)
		if not ok then
			warn("[LAGATIXA] ERRO ao carregar animação " .. nome .. ": " .. tostring(err))
		end
	end

	-- ★ Espera um frame pra garantir que as animações estejam prontas
	task.wait()

	print("[LAGATIXA] Total de animações carregadas: " .. tostring(#animInstances))
end

local function tocarAnimacao(nome, velocidade)
	velocidade = velocidade or 1

	local track = animTracks[nome]
	if not track then
		return
	end

	-- Se já está tocando, só ajusta velocidade
	if track.IsPlaying then
		track:AdjustSpeed(velocidade)
		return
	end

	-- ★ PARA TODAS as outras animações ANTES de tocar a nova
	for n, t in pairs(animTracks) do
		if n ~= nome and t and t.IsPlaying then
			t:Stop(0.15)
		end
	end

	-- ★ Pequeno delay pra garantir que as outras pararam
	track:Play(0.15)
	track:AdjustSpeed(velocidade)
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

		local corner = Instance.new("UICorner", btn)
		corner.CornerRadius = UDim.new(0, 12)

		local stroke = Instance.new("UIStroke", btn)
		stroke.Color = Color3.fromRGB(0, 150, 255)
		stroke.Thickness = 2
		stroke.Transparency = 0.4

		return btn
	end

	-- D-PAD
	local dpadFrame = Instance.new("Frame")
	dpadFrame.Name = "DPad"
	dpadFrame.Size = UDim2.new(0, 205, 0, 205)
	dpadFrame.Position = UDim2.new(0, 15, 1, -220)
	dpadFrame.BackgroundTransparency = 1
	dpadFrame.Parent = controls

	local btnCima   = criarSeta("Cima",   "▲", 70, 0,   dpadFrame)
	local btnBaixo  = criarSeta("Baixo",  "▼", 70, 140, dpadFrame)
	local btnEsq    = criarSeta("Esq",    "◀", 0,  70,  dpadFrame)
	local btnDir    = criarSeta("Dir",     "▶", 140, 70, dpadFrame)

	local centro = Instance.new("Frame")
	centro.Size = UDim2.new(0, 55, 0, 55)
	centro.Position = UDim2.new(0, 75, 0, 75)
	centro.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
	centro.BackgroundTransparency = 0.5
	centro.BorderSizePixel = 0
	centro.Parent = dpadFrame
	Instance.new("UICorner", centro).CornerRadius = UDim.new(0, 10)

	-- BOTÃO PULO
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

	-- ESTADO DAS SETAS
	local pressing = { Cima = false, Baixo = false, Esq = false, Dir = false }

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
-- CABEÇA OLHA PRA CÂMERA
-- ==============================
local function atualizarCabeca(char, surfaceNormal)
	local neck = nil

	local head = char:FindFirstChild("Head")
	if head then
		for _, obj in ipairs(head:GetChildren()) do
			if obj:IsA("Motor6D") and obj.Name == "Neck" then
				neck = obj
				break
			end
		end
	end

	if not neck then
		local upperTorso = char:FindFirstChild("UpperTorso")
		if upperTorso then
			for _, obj in ipairs(upperTorso:GetChildren()) do
				if obj:IsA("Motor6D") and obj.Name == "Neck" then
					neck = obj
					break
				end
			end
		end
	end

	if not neck then
		local torso = char:FindFirstChild("Torso")
		if torso then
			for _, obj in ipairs(torso:GetChildren()) do
				if obj:IsA("Motor6D") and obj.Name == "Neck" then
					neck = obj
					break
				end
			end
		end
	end

	if not neck then return end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local camLook = camera.CFrame.LookVector

	local torsoParent = neck.Part0
	if not torsoParent then return end

	local torsoCF = torsoParent.CFrame
	local localLook = torsoCF:VectorToObjectSpace(camLook)

	local yaw = math.atan2(-localLook.X, -localLook.Z)
	local pitch = math.asin(math.clamp(localLook.Y, -1, 1))

	yaw = math.clamp(yaw, -math.rad(70), math.rad(70))
	pitch = math.clamp(pitch, -math.rad(60), math.rad(60))

	local isR6 = char:FindFirstChild("Torso") ~= nil and char:FindFirstChild("UpperTorso") == nil

	local originalC0
	if isR6 then
		originalC0 = CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	else
		originalC0 = CFrame.new(0, 1, 0)
	end

	local rotacao = CFrame.Angles(pitch, yaw, 0)
	neck.C0 = originalC0 * rotacao
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

	-- ★ DESLIGA O ANIMATE PRIMEIRO
	local animate = char:FindFirstChild("Animate")
	if animate then
		animate.Disabled = true
	end

	-- ★ PARA TODAS as animações atuais via Animator
	local animator = hum:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			track:Stop(0)
		end
	end

	-- ★ Espera um pouco pra tudo parar
	task.wait(0.1)

	-- ★ CARREGA NOSSAS ANIMAÇÕES
	carregarAnimacoes(char)

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
	local currentForward = Vector3.new(0, 0, -1)
	local jumpingFromSurface = false
	local jumpSurfaceNormal = Vector3.new(0, 1, 0)

	local currentAnim = ""  -- ★ Começa vazio pra forçar a primeira animação
	local animTimer = 0

	-- ★ Toca idle imediatamente
	task.wait(0.2)
	tocarAnimacao("idle", 1)
	currentAnim = "idle"

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
		else
			local camForward = (camLook - camLook:Dot(surfaceNormal) * surfaceNormal)
			if camForward.Magnitude > 0.01 then
				currentForward = currentForward:Lerp(camForward.Unit, dt * 5)
				if currentForward.Magnitude > 0 then
					currentForward = currentForward.Unit
				end
			end
		end

		-- MOVIMENTO LATERAL
		local lateralVel = Vector3.zero
		if isMoving then
			lateralVel = moveDir.Unit * WALK_SPEED
		end

		-- DETECÇÃO DE SUPERFÍCIE
		local hit, dist = raycastChao(hrp.Position, char)

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
				verticalVelocity = verticalVelocity - GRAVITY * dt
				bodyVel.Velocity = lateralVel + jumpSurfaceNormal * verticalVelocity

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
			task.delay(0.3, function()
				canJump = true
			end)
		end

		-- ============================
		-- ★ ANIMAÇÕES (CORRIGIDO)
		-- ============================
		local newAnim = "idle"

		if not isGrounded then
			if verticalVelocity > 5 then
				newAnim = "jump"
			else
				newAnim = "fall"
			end
		elseif isMoving then
			newAnim = "walk"
		else
			newAnim = "idle"
		end

		-- ★ SÓ TROCA SE MUDOU
		if newAnim ~= currentAnim then
			currentAnim = newAnim

			-- ★ Velocidade baseada no tipo
			local speed = 1
			if newAnim == "walk" then
				speed = math.clamp(lateralVel.Magnitude / WALK_SPEED, 0.5, 2)
			end

			tocarAnimacao(newAnim, speed)
		end

		-- ★ ATUALIZA VELOCIDADE DO WALK CONTINUAMENTE
		if currentAnim == "walk" and animTracks["walk"] then
			local speed = math.clamp(lateralVel.Magnitude / WALK_SPEED, 0.5, 2)
			if animTracks["walk"].IsPlaying then
				animTracks["walk"]:AdjustSpeed(speed)
			else
				-- ★ Se parou de tocar sozinha, força de novo
				tocarAnimacao("walk", speed)
			end
		end

		-- ★ VERIFICA SE ANIMAÇÃO ATUAL AINDA ESTÁ TOCANDO
		-- (proteção contra animações que param sozinhas)
		if animTracks[currentAnim] and not animTracks[currentAnim].IsPlaying then
			if currentAnim == "idle" or currentAnim == "walk" or currentAnim == "fall" then
				tocarAnimacao(currentAnim, 1)
			end
		end

		-- ============================
		-- ORIENTAÇÃO DO CORPO
		-- ============================
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
		bodyGyro.CFrame = targetCF

		-- ============================
		-- CABEÇA OLHA PRA CÂMERA
		-- ============================
		atualizarCabeca(char, surfaceNormal)
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

	-- ★ LIMPA ANIMAÇÕES COMPLETAMENTE
	limparAnimacoes()

	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")

		if hum then
			hum.PlatformStand = false
		end

		-- Reativa script de animação
		local animate = char:FindFirstChild("Animate")
		if animate then
			animate.Disabled = false
		end

		-- Reseta o Neck
		local function resetNeck(parent)
			if not parent then return end
			for _, obj in ipairs(parent:GetChildren()) do
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

		resetNeck(char:FindFirstChild("Head"))
		resetNeck(char:FindFirstChild("UpperTorso"))
		resetNeck(char:FindFirstChild("Torso"))

		-- ★ Remove Animation instances que ficaram no char
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

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
	title.BorderSizePixel = 0
	title.Text = "🦎 LAGATIXA v10.1"
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

print("[LAGATIXA v10.1] Pronto! Animações corrigidas ✓")
