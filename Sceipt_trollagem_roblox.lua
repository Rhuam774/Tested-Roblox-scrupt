-- ============================================================
-- MOD MENU DELTA v9.2
-- CORRECOES v9.2:
--   - CLONES FUNCIONAM: spawn PERTO de voce (8-15 studs)
--   - Clones formam RODA ao redor do alvo
--   - Clones tem COLISAO real com players e entre si
--   - Raycast do chao corrigido (Y+200 para baixo)
--   - Clone ancorado por 0.5s ao spawnar (nao cai)
--   - Todas as correcoes anteriores mantidas
-- ============================================================

print("[DELTA v9.2] Iniciando...")

-- ============================================================
-- CARREGAR RAYFIELD
-- ============================================================
local Rayfield = nil
do
    local ok, result = pcall(function()
        return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
    end)
    if not ok or not result then
        warn("[DELTA] ERRO Rayfield: " .. tostring(result))
        return
    end
    Rayfield = result
    print("[DELTA] Rayfield carregado!")
end

-- ============================================================
-- SERVICOS
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- VARIAVEIS GLOBAIS
-- ============================================================
local seguindo = false
local playerAlvo = nil
local playerAlvoNome = nil
local conexaoSeguir = nil
local distanciaSeguir = 3
local walkSpeedOriginal = 16
local modoInvisivel = false
local modoSeguir = "normal"

local waypointIndex = 1
local waypoints = {}
local ultimaPosAlvo = nil
local pathRecalcTimer = 0

local selecaoPorToque = false
local conexaoToque = nil
local toqueCooldownAtivo = false
local toqueCooldownTimer = 0
local TOQUE_COOLDOWN_DURACAO = 3

local highlightSelecionado = nil
local playerSelecionadoNome = nil

local speedAtivo = false
local speedValor = 50
local conexaoSpeed = nil

local alvoUltimaPos = nil
local alvoParadoTimer = 0
local alvoParadoThreshold = 0.8
local alvoEstaParado = false
local estaDancando = false
local meuPersonagemPerto = false
local dancaCancelada = false

-- FUGIR
local fugindo = false
local playerPerseguidor = nil
local playerPerseguidorNome = nil
local conexaoFugir = nil
local fugirHighlight = nil
local fugirDistanciaSegura = 30
local fugirDistanciaMinima = 8
local inimigoPosAnterior = nil
local fugirMemoriaPosicoes = {}
local FUGIR_MEMORIA_MAX = 20
local fugirMemoriaTimer = 0
local fantasmaAtivo = false
local fantasmaTimer = 0
local FANTASMA_DURACAO = 1.5
local fugirJukeTimer = 0
local fugirJukeInterval = 0.8
local fugirCollisionsBackup = {}

-- CLONES
local clonesAtivos = {}
local cloneAlvo = nil
local cloneAlvoNome = nil
local cloneDistancia = 5
local cloneSpawnRaio = 15
local cloneVelocidade = 22
local cloneDancar = true
local cloneContador = 0
local clonePasta = nil

-- ============================================================
-- ANIMACOES
-- ============================================================
local ANIM_SENTADO = "rbxassetid://2506281703"

local ANIMS_ANDAR = {
    {nome = "Andar Normal", id = "rbxassetid://180426354"},
    {nome = "Andar Ninja", id = "rbxassetid://656118852"},
    {nome = "Andar Zombie", id = "rbxassetid://616163682"},
    {nome = "Andar Velho", id = "rbxassetid://616006778"},
    {nome = "Andar Cowboy", id = "rbxassetid://5765898383"},
    {nome = "Andar Confiante", id = "rbxassetid://616010382"},
    {nome = "Andar Sorrateiro", id = "rbxassetid://616003713"},
    {nome = "Andar Manco", id = "rbxassetid://616008087"},
    {nome = "Andar Robozinho", id = "rbxassetid://616013216"},
    {nome = "Andar Feliz", id = "rbxassetid://5765891244"},
}

local DANCAS = {
    {nome = "Floss Dance", id = "rbxassetid://5917459365"},
    {nome = "Hype Dance", id = "rbxassetid://5918726674"},
    {nome = "Twerk", id = "rbxassetid://3360816860"},
    {nome = "Orange Justice", id = "rbxassetid://5918580760"},
    {nome = "Default Dance", id = "rbxassetid://5915773155"},
    {nome = "Robot Dance", id = "rbxassetid://616006778"},
    {nome = "Electro Shuffle", id = "rbxassetid://5913382268"},
    {nome = "Capoeira", id = "rbxassetid://5862461553"},
    {nome = "Breakdance", id = "rbxassetid://5917600302"},
    {nome = "Macarena", id = "rbxassetid://5915791549"},
    {nome = "Gangnam Style", id = "rbxassetid://4212455378"},
    {nome = "Dab", id = "rbxassetid://5915693819"},
    {nome = "Salsa", id = "rbxassetid://5915827002"},
    {nome = "Twist", id = "rbxassetid://5915831765"},
    {nome = "Chicken Dance", id = "rbxassetid://5915805935"},
    {nome = "Running Man", id = "rbxassetid://5917468522"},
    {nome = "Kick It", id = "rbxassetid://5918634604"},
    {nome = "Pop Lock", id = "rbxassetid://5913287938"},
    {nome = "Celebrate", id = "rbxassetid://5915779043"},
}

local animSentadoTrack = nil
local animAndarTrack = nil
local animDancaTrack = nil
local animAndarAtual = 1
local animDancaAtual = 1
local dancarAoParar = true

-- ============================================================
-- FUNCOES UTILITARIAS
-- ============================================================
local function getRootPart(player)
    if player and player.Character then
        return player.Character:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

local function getHumanoid(player)
    if player and player.Character then
        return player.Character:FindFirstChildOfClass("Humanoid")
    end
    return nil
end

local function getListaPlayers()
    local lista = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(lista, player.Name)
        end
    end
    return lista
end

local function getPlayerByName(nome)
    if not nome or nome == "" then return nil end
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name:lower() == nome:lower() then return player end
    end
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name:lower():find(nome:lower(), 1, true) then return player end
    end
    return nil
end

-- ============================================================
-- FORCAR PARAR TODAS AS TRACKS
-- ============================================================
local function forcarPararTodasTracks()
    pcall(function()
        local character = LocalPlayer.Character
        if not character then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in pairs(animator:GetPlayingAnimationTracks()) do
                pcall(function() track:Stop(0); track:AdjustWeight(0) end)
            end
        end
    end)
end

-- ============================================================
-- FUNCOES DE ANIMACAO
-- ============================================================
local function pararAnimsMovimento()
    pcall(function() if animSentadoTrack then animSentadoTrack:Stop(0); animSentadoTrack = nil end end)
    pcall(function() if animAndarTrack then animAndarTrack:Stop(0); animAndarTrack = nil end end)
end

local function pararDanca()
    pcall(function()
        if animDancaTrack then
            animDancaTrack:Stop(0)
            pcall(function() animDancaTrack:AdjustWeight(0) end)
            pcall(function() animDancaTrack:Destroy() end)
            animDancaTrack = nil
        end
    end)
    estaDancando = false
    forcarPararTodasTracks()
end

local function pararTodasAnimacoes()
    pararAnimsMovimento()
    pararDanca()
    forcarPararTodasTracks()
end

local function tocarAnimacao(animId, looped, fadeIn)
    local character = LocalPlayer.Character
    if not character then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then animator = Instance.new("Animator"); animator.Parent = humanoid end
    local anim = Instance.new("Animation"); anim.AnimationId = animId
    local track = nil
    pcall(function() track = animator:LoadAnimation(anim) end)
    if not track then pcall(function() track = humanoid:LoadAnimation(anim) end) end
    if track then
        track.Looped = looped or false
        track.Priority = Enum.AnimationPriority.Action4
        track:Play(fadeIn or 0.2)
    end
    return track
end

local function iniciarAnimSentado()
    pcall(function() if animAndarTrack then animAndarTrack:Stop(0); animAndarTrack = nil end end)
    if not animSentadoTrack then animSentadoTrack = tocarAnimacao(ANIM_SENTADO, true, 0.3) end
end

local function iniciarAnimAndar()
    pcall(function() if animSentadoTrack then animSentadoTrack:Stop(0); animSentadoTrack = nil end end)
    if not animAndarTrack then
        local ad = ANIMS_ANDAR[animAndarAtual]
        if ad then animAndarTrack = tocarAnimacao(ad.id, true, 0.3) end
    end
end

local function iniciarDanca(manual)
    if not manual and dancaCancelada then return end
    if not manual and not seguindo then return end
    pararAnimsMovimento()
    if estaDancando and animDancaTrack then return end
    if animDancaTrack then
        pcall(function() animDancaTrack:Stop(0); pcall(function() animDancaTrack:Destroy() end); animDancaTrack = nil end)
    end
    task.wait(0.1)
    if not manual and dancaCancelada then return end
    if not manual and not seguindo then return end
    local animData = DANCAS[animDancaAtual]
    if not animData then return end
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if not animator then animator = Instance.new("Animator"); animator.Parent = humanoid end
    local anim = Instance.new("Animation"); anim.AnimationId = animData.id
    local track = nil
    pcall(function() track = animator:LoadAnimation(anim) end)
    if not track then pcall(function() track = humanoid:LoadAnimation(anim) end) end
    if track then
        track.Looped = true; track.Priority = Enum.AnimationPriority.Action4; track:Play(0.1)
        animDancaTrack = track; estaDancando = true
    end
end

-- ============================================================
-- HIGHLIGHTS
-- ============================================================
local function limparHighlightSelecionado()
    pcall(function() if highlightSelecionado and highlightSelecionado.Parent then highlightSelecionado:Destroy() end; highlightSelecionado = nil end)
    for _, player in ipairs(Players:GetPlayers()) do
        pcall(function() if player.Character then local hl = player.Character:FindFirstChild("DELTA_SELECIONADO"); if hl then hl:Destroy() end end end)
    end
end

local function marcarPlayerSelecionado(player)
    limparHighlightSelecionado()
    if not player or not player.Character then return end
    playerSelecionadoNome = player.Name
    local highlight = Instance.new("Highlight")
    highlight.Name = "DELTA_SELECIONADO"
    highlight.FillTransparency = 0.5
    highlight.FillColor = Color3.fromRGB(0, 255, 80)
    highlight.OutlineColor = Color3.fromRGB(0, 255, 80)
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = player.Character
    highlightSelecionado = highlight
    Rayfield:Notify({Title = "Selecionado", Content = player.Name, Duration = 2})
end

local function limparHighlightPerseguidor()
    pcall(function() if fugirHighlight and fugirHighlight.Parent then fugirHighlight:Destroy() end; fugirHighlight = nil end)
    for _, p in ipairs(Players:GetPlayers()) do
        pcall(function() if p.Character then local hl = p.Character:FindFirstChild("DELTA_PERSEGUIDOR"); if hl then hl:Destroy() end end end)
    end
end

local function marcarPerseguidor(player)
    limparHighlightPerseguidor()
    if not player or not player.Character then return end
    local hl = Instance.new("Highlight")
    hl.Name = "DELTA_PERSEGUIDOR"
    hl.FillTransparency = 0.3; hl.FillColor = Color3.fromRGB(255, 0, 0)
    hl.OutlineColor = Color3.fromRGB(255, 50, 50); hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = player.Character
    fugirHighlight = hl
end

local function selecionarPlayer(nome)
    local player = getPlayerByName(nome)
    if player then marcarPlayerSelecionado(player); playerSelecionadoNome = player.Name; return player
    else Rayfield:Notify({Title = "Erro", Content = "'" .. tostring(nome) .. "' nao encontrado!", Duration = 3}); return nil end
end

-- ============================================================
-- SPEED HACK
-- ============================================================
local function iniciarSpeedLoop()
    if conexaoSpeed then conexaoSpeed:Disconnect(); conexaoSpeed = nil end
    conexaoSpeed = RunService.Heartbeat:Connect(function()
        if speedAtivo and not fugindo then
            local hum = getHumanoid(LocalPlayer)
            if hum then hum.WalkSpeed = speedValor end
        end
    end)
end

local function setSpeed(ativo, valor)
    speedAtivo = ativo; speedValor = valor
    if ativo then
        local hum = getHumanoid(LocalPlayer)
        if hum then walkSpeedOriginal = hum.WalkSpeed; hum.WalkSpeed = valor end
        iniciarSpeedLoop()
    else
        if conexaoSpeed then conexaoSpeed:Disconnect(); conexaoSpeed = nil end
        if not fugindo then local hum = getHumanoid(LocalPlayer); if hum then hum.WalkSpeed = walkSpeedOriginal end end
    end
end

-- ============================================================
-- PATHFINDING
-- ============================================================
local function calcularPath(origem, destino)
    local path = PathfindingService:CreatePath({
        AgentRadius = 2, AgentHeight = 5, AgentCanJump = true,
        AgentCanClimb = false, WaypointSpacing = 4,
    })
    local ok = pcall(function() path:ComputeAsync(origem, destino) end)
    if ok and path.Status == Enum.PathStatus.Success then return path:GetWaypoints() end
    return nil
end

-- ============================================================
-- DETECTAR ALVO PARADO
-- ============================================================
local function verificarAlvoParado(targetRoot, dt)
    if not targetRoot then alvoEstaParado = false; return end
    local posAtual = targetRoot.Position
    local vel = Vector3.new(0,0,0)
    pcall(function() vel = targetRoot.AssemblyLinearVelocity or targetRoot.Velocity or Vector3.new(0,0,0) end)
    local velH = Vector3.new(vel.X, 0, vel.Z).Magnitude
    local posicaoMudou = false
    if alvoUltimaPos then
        local d = (Vector3.new(posAtual.X, 0, posAtual.Z) - Vector3.new(alvoUltimaPos.X, 0, alvoUltimaPos.Z)).Magnitude
        posicaoMudou = d > 0.3
    end
    local alvoMovendo = false
    if playerAlvo and playerAlvo.Character then
        local alvoHum = playerAlvo.Character:FindFirstChildOfClass("Humanoid")
        if alvoHum then alvoMovendo = alvoHum.MoveDirection.Magnitude > 0.1 end
    end
    local paradoAgora = (velH < 1) and (not posicaoMudou) and (not alvoMovendo)
    if paradoAgora then
        alvoParadoTimer = alvoParadoTimer + dt
        if alvoParadoTimer >= alvoParadoThreshold then alvoEstaParado = true end
    else alvoParadoTimer = 0; alvoEstaParado = false end
    alvoUltimaPos = posAtual
end

-- ============================================================
-- GERENCIAR DANCA DURANTE SEGUIR
-- ============================================================
local function gerenciarDancaDuranteSeguir(meuRoot, targetRoot)
    if modoSeguir == "encosto" then
        if estaDancando then pararDanca() end; return
    end
    if not dancarAoParar then
        if estaDancando then pararDanca() end; return
    end
    local distancia = (meuRoot.Position - targetRoot.Position).Magnitude
    meuPersonagemPerto = distancia <= (distanciaSeguir + 3)
    if alvoEstaParado and meuPersonagemPerto then
        if not estaDancando then
            pararAnimsMovimento()
            task.spawn(function() iniciarDanca(false) end)
        end
    else
        if estaDancando then pararDanca(); animAndarTrack = nil end
    end
end

-- ============================================================
-- MODOS DE SEGUIR
-- ============================================================
local function modoEncostoUpdate(meuRoot, meuHum, targetRoot)
    local lookDir = targetRoot.CFrame.LookVector
    local posAtras = targetRoot.Position - (lookDir * distanciaSeguir)
    posAtras = Vector3.new(posAtras.X, targetRoot.Position.Y - 0.1, posAtras.Z)
    meuRoot.CFrame = CFrame.new(posAtras, targetRoot.Position)
    pcall(function() meuRoot.Velocity = Vector3.new(0,0,0) end)
    pcall(function() meuRoot.AssemblyLinearVelocity = Vector3.new(0,0,0) end)
    iniciarAnimSentado()
end

local function modoPathfindingUpdate(meuRoot, meuHum, targetRoot, dt)
    local distancia = (meuRoot.Position - targetRoot.Position).Magnitude
    if not estaDancando then iniciarAnimAndar() end
    if speedAtivo then meuHum.WalkSpeed = speedValor end
    if distancia > 60 then
        meuRoot.CFrame = CFrame.new(targetRoot.Position - (targetRoot.CFrame.LookVector * distanciaSeguir), targetRoot.Position)
        waypoints = {}; waypointIndex = 1; return
    end
    if alvoEstaParado and distancia < distanciaSeguir + 3 then
        meuRoot.CFrame = CFrame.new(meuRoot.Position, Vector3.new(targetRoot.Position.X, meuRoot.Position.Y, targetRoot.Position.Z)); return
    end
    if distancia < distanciaSeguir + 2 then
        meuHum:MoveTo(targetRoot.Position - (targetRoot.CFrame.LookVector * distanciaSeguir))
        meuRoot.CFrame = CFrame.new(meuRoot.Position, Vector3.new(targetRoot.Position.X, meuRoot.Position.Y, targetRoot.Position.Z)); return
    end
    pathRecalcTimer = pathRecalcTimer + dt
    local precisaRecalc = (ultimaPosAlvo == nil) or ((targetRoot.Position - (ultimaPosAlvo or Vector3.new(0,0,0))).Magnitude > 8) or (pathRecalcTimer > 1) or (#waypoints == 0)
    if precisaRecalc then
        pathRecalcTimer = 0; ultimaPosAlvo = targetRoot.Position
        local destino = targetRoot.Position - (targetRoot.CFrame.LookVector * distanciaSeguir)
        local novaRota = calcularPath(meuRoot.Position, destino)
        if novaRota then waypoints = novaRota; waypointIndex = 1
        else meuHum:MoveTo(destino); return end
    end
    if #waypoints > 0 and waypointIndex <= #waypoints then
        local wp = waypoints[waypointIndex]
        if wp.Action == Enum.PathWaypointAction.Jump then meuHum.Jump = true end
        meuHum:MoveTo(wp.Position)
        if (meuRoot.Position - wp.Position).Magnitude < 4 then waypointIndex = waypointIndex + 1 end
    end
end

local function modoNormalUpdate(meuRoot, meuHum, targetRoot)
    local posAtras = targetRoot.Position - (targetRoot.CFrame.LookVector * distanciaSeguir)
    local distancia = (meuRoot.Position - targetRoot.Position).Magnitude
    if not estaDancando then iniciarAnimAndar() end
    if speedAtivo then meuHum.WalkSpeed = speedValor end
    if distancia > 60 then
        meuRoot.CFrame = CFrame.new(posAtras, targetRoot.Position)
    elseif alvoEstaParado and distancia < distanciaSeguir + 3 then
        meuRoot.CFrame = CFrame.new(meuRoot.Position, Vector3.new(targetRoot.Position.X, meuRoot.Position.Y, targetRoot.Position.Z))
    else
        meuHum:MoveTo(posAtras)
        if distancia < distanciaSeguir + 3 then
            meuRoot.CFrame = CFrame.new(meuRoot.Position, Vector3.new(targetRoot.Position.X, meuRoot.Position.Y, targetRoot.Position.Z))
        end
    end
end

-- ============================================================
-- FORWARD DECLARATIONS
-- ============================================================
local pararFugir
local pararSeguir

-- ============================================================
-- INICIAR SEGUIR
-- ============================================================
local function iniciarSeguir(alvo)
    if not alvo then Rayfield:Notify({Title = "Erro", Content = "Nenhum player selecionado!", Duration = 3}); return end
    local alvoRoot = getRootPart(alvo)
    if not alvoRoot then Rayfield:Notify({Title = "Erro", Content = alvo.Name .. " sem personagem!", Duration = 3}); return end
    if fugindo then pcall(pararFugir) end
    pararTodasAnimacoes(); limparHighlightSelecionado()
    local meuHum = getHumanoid(LocalPlayer)
    if meuHum and not speedAtivo then walkSpeedOriginal = meuHum.WalkSpeed end
    playerAlvo = alvo; playerAlvoNome = alvo.Name; seguindo = true; dancaCancelada = false
    waypoints = {}; waypointIndex = 1; ultimaPosAlvo = nil; pathRecalcTimer = 0
    alvoUltimaPos = nil; alvoParadoTimer = 0; alvoEstaParado = false; estaDancando = false; meuPersonagemPerto = false
    local modoTexto = "Normal"
    if modoSeguir == "encosto" then modoTexto = "ENCOSTO"
    elseif modoSeguir == "pathfinding" then modoTexto = "Pathfinding" end
    Rayfield:Notify({Title = "Seguindo!", Content = alvo.Name .. " | " .. modoTexto, Duration = 3})
    if conexaoSeguir then conexaoSeguir:Disconnect(); conexaoSeguir = nil end
    conexaoSeguir = RunService.Heartbeat:Connect(function(dt)
        if not seguindo or not playerAlvo then
            if conexaoSeguir then conexaoSeguir:Disconnect(); conexaoSeguir = nil end; return
        end
        local meuRoot = getRootPart(LocalPlayer)
        local meuHum2 = getHumanoid(LocalPlayer)
        local targetRoot = getRootPart(playerAlvo)
        if not meuRoot or not targetRoot or not meuHum2 then return end
        if speedAtivo then meuHum2.WalkSpeed = speedValor end
        pcall(function() verificarAlvoParado(targetRoot, dt) end)
        pcall(function() gerenciarDancaDuranteSeguir(meuRoot, targetRoot) end)
        pcall(function()
            if modoSeguir == "encosto" then modoEncostoUpdate(meuRoot, meuHum2, targetRoot)
            elseif modoSeguir == "pathfinding" then
                if not (estaDancando and meuPersonagemPerto) then modoPathfindingUpdate(meuRoot, meuHum2, targetRoot, dt)
                else meuRoot.CFrame = CFrame.new(meuRoot.Position, Vector3.new(targetRoot.Position.X, meuRoot.Position.Y, targetRoot.Position.Z)) end
            else
                if not (estaDancando and meuPersonagemPerto) then modoNormalUpdate(meuRoot, meuHum2, targetRoot)
                else meuRoot.CFrame = CFrame.new(meuRoot.Position, Vector3.new(targetRoot.Position.X, meuRoot.Position.Y, targetRoot.Position.Z)) end
            end
        end)
        if modoInvisivel then
            pcall(function()
                for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                    if part:IsA("BasePart") then part.Transparency = 1
                    elseif part:IsA("Decal") or part:IsA("Texture") then part.Transparency = 1 end
                end
            end)
        end
    end)
end

-- ============================================================
-- PARAR SEGUIR
-- ============================================================
pararSeguir = function()
    local nomeAlvo = playerAlvoNome
    seguindo = false; dancaCancelada = true
    if conexaoSeguir then conexaoSeguir:Disconnect(); conexaoSeguir = nil end
    pararAnimsMovimento(); pararDanca(); forcarPararTodasTracks()
    task.spawn(function() for i = 1, 5 do task.wait(0.1); forcarPararTodasTracks()
        pcall(function() if animDancaTrack then animDancaTrack:Stop(0); animDancaTrack:AdjustWeight(0); animDancaTrack:Destroy(); animDancaTrack = nil end end)
    end end)
    estaDancando = false; alvoEstaParado = false; alvoParadoTimer = 0; alvoUltimaPos = nil; meuPersonagemPerto = false
    animSentadoTrack = nil; animAndarTrack = nil; animDancaTrack = nil
    waypoints = {}; waypointIndex = 1; ultimaPosAlvo = nil
    if not speedAtivo then local hum = getHumanoid(LocalPlayer); if hum then hum.WalkSpeed = walkSpeedOriginal end end
    if modoInvisivel then
        pcall(function() for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then part.Transparency = 0
            elseif part:IsA("Decal") or part:IsA("Texture") then part.Transparency = 0 end
        end end)
    end
    Rayfield:Notify({Title = "Parou!", Content = "Parou de seguir" .. (nomeAlvo and (" " .. nomeAlvo) or ""), Duration = 3})
    if selecaoPorToque then toqueCooldownAtivo = true; toqueCooldownTimer = TOQUE_COOLDOWN_DURACAO end
    if playerAlvo then pcall(function() marcarPlayerSelecionado(playerAlvo) end) end
    playerAlvo = nil
end

-- ============================================================
-- FUGA IMPOSSIVEL
-- ============================================================
local function raycastDirecao(origem, direcao, maxDist)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local filtro = {}
    if LocalPlayer.Character then table.insert(filtro, LocalPlayer.Character) end
    if playerPerseguidor and playerPerseguidor.Character then table.insert(filtro, playerPerseguidor.Character) end
    if clonePasta then table.insert(filtro, clonePasta) end
    rayParams.FilterDescendantsInstances = filtro; rayParams.IgnoreWater = true
    local result = Workspace:Raycast(origem, direcao * maxDist, rayParams)
    if result then return (result.Position - origem).Magnitude end
    return maxDist
end

local function predizirPosicaoInimigo(inimigoRoot)
    local vel = Vector3.new(0,0,0)
    pcall(function() vel = inimigoRoot.AssemblyLinearVelocity or inimigoRoot.Velocity or Vector3.new(0,0,0) end)
    if inimigoPosAnterior then
        local velEst = (inimigoRoot.Position - inimigoPosAnterior) * 60
        vel = vel * 0.3 + velEst * 0.7
    end
    return inimigoRoot.Position + vel * 0.5
end

local function calcularVelocidadeFuga(dist)
    if dist < 3 then return 300
    elseif dist < 5 then return 250
    elseif dist < 8 then return 200
    elseif dist < 12 then return math.clamp(200 - (dist - 8) * 15, 120, 200)
    elseif dist < 20 then return math.clamp(120 - (dist - 12) * 8, 50, 120)
    elseif dist < fugirDistanciaSegura then return math.clamp(50 - (dist - 20) * 2, 20, 50)
    else return 16 end
end

local function ativarFantasma()
    if fantasmaAtivo then return end
    fantasmaAtivo = true; fantasmaTimer = FANTASMA_DURACAO; fugirCollisionsBackup = {}
    pcall(function()
        if not LocalPlayer.Character then return end
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then fugirCollisionsBackup[part] = part.CanCollide; part.CanCollide = false end
        end
    end)
end

local function desativarFantasma()
    if not fantasmaAtivo then return end; fantasmaAtivo = false
    pcall(function() for part, orig in pairs(fugirCollisionsBackup) do if part and part.Parent then part.CanCollide = orig end end end)
    fugirCollisionsBackup = {}
end

local function microTeleporteFuga(meuRoot, dirFuga, velocidade, dt)
    local novaPosicao = meuRoot.Position + (dirFuga * velocidade * dt)
    pcall(function()
        local rayParams = RaycastParams.new(); rayParams.FilterType = Enum.RaycastFilterType.Exclude
        local filtro = {}; if LocalPlayer.Character then table.insert(filtro, LocalPlayer.Character) end
        if clonePasta then table.insert(filtro, clonePasta) end
        rayParams.FilterDescendantsInstances = filtro
        local r = Workspace:Raycast(novaPosicao + Vector3.new(0,5,0), Vector3.new(0,-15,0), rayParams)
        if r then novaPosicao = Vector3.new(novaPosicao.X, r.Position.Y + 3, novaPosicao.Z)
        else novaPosicao = Vector3.new(novaPosicao.X, meuRoot.Position.Y, novaPosicao.Z) end
    end)
    meuRoot.CFrame = CFrame.new(novaPosicao, novaPosicao + dirFuga)
    pcall(function() meuRoot.Velocity = Vector3.new(0,0,0); meuRoot.AssemblyLinearVelocity = Vector3.new(0,0,0) end)
end

local function escapeEmergencia(meuRoot, inimigoRoot)
    local melhorDir, melhorScore = nil, -9999
    for i = 0, 11 do
        local ang = (i / 12) * math.pi * 2
        local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
        local espaco = raycastDirecao(meuRoot.Position + Vector3.new(0,1,0), dir, 40)
        local pt = meuRoot.Position + dir * math.min(espaco - 1, 35)
        local score = (pt - inimigoRoot.Position).Magnitude * 2 + espaco
        if score > melhorScore then melhorScore = score; melhorDir = dir end
    end
    if melhorDir then
        local espaco = raycastDirecao(meuRoot.Position + Vector3.new(0,1,0), melhorDir, 40)
        local distTP = math.max(math.min(espaco - 1, 35), 10)
        local pt = meuRoot.Position + melhorDir * distTP
        pcall(function()
            local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude
            rp.FilterDescendantsInstances = {LocalPlayer.Character}
            local r = Workspace:Raycast(pt + Vector3.new(0,10,0), Vector3.new(0,-30,0), rp)
            if r then pt = Vector3.new(pt.X, r.Position.Y + 3, pt.Z) end
        end)
        meuRoot.CFrame = CFrame.new(pt, pt + melhorDir)
        pcall(function() meuRoot.Velocity = Vector3.new(0,0,0); meuRoot.AssemblyLinearVelocity = Vector3.new(0,0,0) end)
    end
end

local function calcularDirecaoFuga(meuRoot, inimigoRoot, distancia, dt)
    local futuro = predizirPosicaoInimigo(inimigoRoot)
    local dirBase = (meuRoot.Position - futuro); dirBase = Vector3.new(dirBase.X, 0, dirBase.Z)
    if dirBase.Magnitude < 0.1 then dirBase = meuRoot.CFrame.LookVector; dirBase = Vector3.new(dirBase.X, 0, dirBase.Z) end
    dirBase = dirBase.Unit
    if distancia < 5 then
        local espaco = raycastDirecao(meuRoot.Position + Vector3.new(0,1,0), dirBase, 20)
        if espaco > 5 then return dirBase end
        for _, ang in ipairs({math.rad(30), math.rad(-30), math.rad(60), math.rad(-60), math.rad(90), math.rad(-90)}) do
            local cosA, sinA = math.cos(ang), math.sin(ang)
            local alt = Vector3.new(dirBase.X*cosA - dirBase.Z*sinA, 0, dirBase.X*sinA + dirBase.Z*cosA)
            if raycastDirecao(meuRoot.Position + Vector3.new(0,1,0), alt, 20) > 5 then return alt end
        end
        ativarFantasma(); return dirBase
    end
    if distancia < 15 then
        fugirJukeTimer = fugirJukeTimer + dt
        if fugirJukeTimer >= fugirJukeInterval then
            fugirJukeTimer = 0
            local juke = math.rad((math.random() - 0.5) * 120)
            local c, s = math.cos(juke), math.sin(juke)
            dirBase = Vector3.new(dirBase.X*c - dirBase.Z*s, 0, dirBase.X*s + dirBase.Z*c).Unit
        end
    end
    local espaco = raycastDirecao(meuRoot.Position + Vector3.new(0,1,0), dirBase, 30)
    if espaco > 8 then return dirBase end
    local melhor, melhorScore2 = dirBase, -9999
    local inimigoPosXZ = Vector3.new(futuro.X, 0, futuro.Z)
    local minhaPosXZ = Vector3.new(meuRoot.Position.X, 0, meuRoot.Position.Z)
    local dirParaInimigo = inimigoPosXZ - minhaPosXZ
    if dirParaInimigo.Magnitude > 0.1 then dirParaInimigo = dirParaInimigo.Unit else dirParaInimigo = Vector3.new(1,0,0) end
    for i = 0, 15 do
        local ang2 = (i / 16) * math.pi * 2
        local dir = Vector3.new(math.cos(ang2), 0, math.sin(ang2))
        local esp = raycastDirecao(meuRoot.Position + Vector3.new(0,1,0), dir, 60)
        local destino = meuRoot.Position + dir * math.min(esp - 2, 50)
        local distDoInimigo = (Vector3.new(destino.X,0,destino.Z) - inimigoPosXZ).Magnitude
        local ganho = distDoInimigo - (minhaPosXZ - inimigoPosXZ).Magnitude
        local dot = dir.X * dirParaInimigo.X + dir.Z * dirParaInimigo.Z
        local sc = (esp/60)*35 + math.clamp(ganho, -15, 30)
        if dot > 0.3 then sc = sc - 40*dot elseif dot < -0.3 then sc = sc + 15*math.abs(dot) end
        for _, pm in ipairs(fugirMemoriaPosicoes) do
            local dm = (Vector3.new(destino.X,0,destino.Z) - Vector3.new(pm.X,0,pm.Z)).Magnitude
            if dm < 12 then sc = sc - (12 - dm) * 1.5 end
        end
        if sc > melhorScore2 then melhorScore2 = sc; melhor = dir end
    end
    return melhor
end

pararFugir = function()
    local nome = playerPerseguidorNome; fugindo = false
    if conexaoFugir then conexaoFugir:Disconnect(); conexaoFugir = nil end
    pararTodasAnimacoes(); desativarFantasma()
    task.spawn(function() for i=1,3 do task.wait(0.1); forcarPararTodasTracks() end end)
    limparHighlightPerseguidor()
    fugirMemoriaPosicoes = {}; fugirJukeTimer = 0; inimigoPosAnterior = nil; fugirCollisionsBackup = {}
    local hum = getHumanoid(LocalPlayer)
    if hum then if speedAtivo then hum.WalkSpeed = speedValor else hum.WalkSpeed = walkSpeedOriginal end end
    animAndarTrack = nil; animSentadoTrack = nil; animDancaTrack = nil
    Rayfield:Notify({Title = "Parou de Fugir", Content = nome or "", Duration = 3})
    playerPerseguidor = nil; playerPerseguidorNome = nil
end

local function iniciarFugir(alvo)
    if not alvo then Rayfield:Notify({Title = "Erro", Content = "Selecione de quem fugir!", Duration = 3}); return end
    local r = getRootPart(alvo)
    if not r then Rayfield:Notify({Title = "Erro", Content = alvo.Name .. " sem personagem!", Duration = 3}); return end
    if seguindo then pararSeguir() end
    if fugindo then pararFugir() end
    pararTodasAnimacoes(); limparHighlightSelecionado()
    local hum = getHumanoid(LocalPlayer); if hum then walkSpeedOriginal = hum.WalkSpeed end
    playerPerseguidor = alvo; playerPerseguidorNome = alvo.Name; fugindo = true
    fugirMemoriaPosicoes = {}; fugirJukeTimer = 0; inimigoPosAnterior = nil
    fantasmaAtivo = false; fantasmaTimer = 0; fugirCollisionsBackup = {}; fugirMemoriaTimer = 0
    marcarPerseguidor(alvo)
    Rayfield:Notify({Title = "FUGA!", Content = "Fugindo de " .. alvo.Name, Duration = 4})
    if conexaoFugir then conexaoFugir:Disconnect(); conexaoFugir = nil end
    conexaoFugir = RunService.Heartbeat:Connect(function(dt)
        if not fugindo or not playerPerseguidor then
            if conexaoFugir then conexaoFugir:Disconnect(); conexaoFugir = nil end; return
        end
        local meuRoot = getRootPart(LocalPlayer); local meuHum = getHumanoid(LocalPlayer)
        local inimigoRoot = getRootPart(playerPerseguidor)
        if not meuRoot or not inimigoRoot or not meuHum then return end
        local dist = (meuRoot.Position - inimigoRoot.Position).Magnitude
        if fantasmaAtivo then
            fantasmaTimer = fantasmaTimer - dt
            if fantasmaTimer <= 0 then desativarFantasma()
            else pcall(function() for _, p in pairs(LocalPlayer.Character:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end) end
        end
        fugirMemoriaTimer = (fugirMemoriaTimer or 0) + dt
        if fugirMemoriaTimer >= 0.5 then fugirMemoriaTimer = 0
            table.insert(fugirMemoriaPosicoes, meuRoot.Position)
            if #fugirMemoriaPosicoes > FUGIR_MEMORIA_MAX then table.remove(fugirMemoriaPosicoes, 1) end
        end
        meuHum.WalkSpeed = calcularVelocidadeFuga(dist)
        pcall(function() if not animAndarTrack then iniciarAnimAndar() end end)
        if dist < 10 and math.random() < 0.03 then pcall(function() meuHum.Jump = true end) end
        if dist < 3 then pcall(function() escapeEmergencia(meuRoot, inimigoRoot) end)
        elseif dist < fugirDistanciaMinima then
            pcall(function() local dirF = calcularDirecaoFuga(meuRoot, inimigoRoot, dist, dt); microTeleporteFuga(meuRoot, dirF, calcularVelocidadeFuga(dist) * 1.5, dt) end)
        elseif dist < fugirDistanciaSegura then
            pcall(function() local dirF = calcularDirecaoFuga(meuRoot, inimigoRoot, dist, dt)
                if dist < 20 then microTeleporteFuga(meuRoot, dirF, calcularVelocidadeFuga(dist), dt)
                else meuHum:MoveTo(meuRoot.Position + dirF * 15); microTeleporteFuga(meuRoot, dirF, calcularVelocidadeFuga(dist) * 0.3, dt) end
            end)
        end
        inimigoPosAnterior = inimigoRoot.Position
    end)
end

-- ============================================================
-- SISTEMA DE CLONES v2 - REESCRITO
-- ============================================================

local function getClonesFolder()
    if clonePasta and clonePasta.Parent then return clonePasta end
    clonePasta = Instance.new("Folder")
    clonePasta.Name = "DELTA_CLONES"
    clonePasta.Parent = Workspace
    return clonePasta
end

-- Achar posicao no chao com raycast robusto
local function acharChao(posXZ, posYRef)
    local posY = posYRef or 50
    local resultado = nil
    pcall(function()
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        local filtro = {}
        if LocalPlayer.Character then table.insert(filtro, LocalPlayer.Character) end
        if clonePasta then table.insert(filtro, clonePasta) end
        rp.FilterDescendantsInstances = filtro
        -- Raycast de MUITO alto para baixo
        local origin = Vector3.new(posXZ.X, posY + 300, posXZ.Z)
        resultado = Workspace:Raycast(origin, Vector3.new(0, -600, 0), rp)
    end)
    if resultado then
        return Vector3.new(posXZ.X, resultado.Position.Y + 3.5, posXZ.Z)
    end
    -- Fallback: mesma altura de referencia
    return Vector3.new(posXZ.X, posY + 3, posXZ.Z)
end

-- Animar clone
local function cloneTocarAnimacao(cloneHum, animId, looped)
    if not cloneHum then return nil end
    local animator = cloneHum:FindFirstChildOfClass("Animator")
    if not animator then animator = Instance.new("Animator"); animator.Parent = cloneHum end
    local anim = Instance.new("Animation"); anim.AnimationId = animId
    local track = nil
    pcall(function() track = animator:LoadAnimation(anim) end)
    if not track then pcall(function() track = cloneHum:LoadAnimation(anim) end) end
    if track then track.Looped = looped or false; track.Priority = Enum.AnimationPriority.Action4; track:Play(0.2) end
    return track
end

local function clonePararAnimacoes(cloneHum)
    pcall(function()
        if not cloneHum then return end
        local animator = cloneHum:FindFirstChildOfClass("Animator")
        if animator then for _, t in pairs(animator:GetPlayingAnimationTracks()) do pcall(function() t:Stop(0) end) end end
    end)
end

-- Forcar colisao em todas as partes do clone
local function forcarColisaoClone(modelo)
    pcall(function()
        for _, part in pairs(modelo:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
                part.Anchored = false
                -- Garantir que nao eh transparente
                if part.Name ~= "HumanoidRootPart" then
                    -- Manter transparencia original
                else
                    part.Transparency = 1 -- HRP sempre invisivel
                end
            end
        end
    end)
end

-- Calcular posicao em RODA ao redor do alvo
local function calcularPosRoda(alvoPos, indice, totalClones)
    local angulo = (indice / math.max(totalClones, 1)) * math.pi * 2
    local offsetX = math.cos(angulo) * cloneDistancia
    local offsetZ = math.sin(angulo) * cloneDistancia
    return Vector3.new(alvoPos.X + offsetX, alvoPos.Y, alvoPos.Z + offsetZ)
end

-- Recalcular total de clones ativos (para redistribuir a roda)
local function getTotalClonesAtivos()
    local total = 0
    for _, cd in ipairs(clonesAtivos) do
        if cd.modelo and cd.modelo.Parent then total = total + 1 end
    end
    return total
end

-- Remover um clone
local function removerClone(cd)
    if cd.conexao then cd.conexao:Disconnect(); cd.conexao = nil end
    pcall(function() if cd.animAndarTrack then cd.animAndarTrack:Stop(0) end end)
    pcall(function() if cd.animDancaTrack then cd.animDancaTrack:Stop(0); cd.animDancaTrack:Destroy() end end)
    pcall(function() if cd.modelo and cd.modelo.Parent then cd.modelo:Destroy() end end)
end

local function removerTodosClones()
    for _, cd in ipairs(clonesAtivos) do removerClone(cd) end
    clonesAtivos = {}
    if clonePasta then pcall(function() for _, c in pairs(clonePasta:GetChildren()) do c:Destroy() end end) end
    cloneContador = 0
    Rayfield:Notify({Title = "Clones", Content = "Todos removidos!", Duration = 3})
end

-- CRIAR UM CLONE
local function criarClone(alvoPlayer, indice, totalNovos)
    local character = LocalPlayer.Character
    if not character then
        print("[CLONE] Erro: sem character local")
        return nil
    end
    local meuRoot = getRootPart(LocalPlayer)
    if not meuRoot then
        print("[CLONE] Erro: sem HumanoidRootPart local")
        return nil
    end
    local alvoRoot = getRootPart(alvoPlayer)
    if not alvoRoot then
        print("[CLONE] Erro: alvo sem character")
        return nil
    end

    local folder = getClonesFolder()

    -- Clonar personagem
    local cloneModel = nil
    local ok2 = pcall(function() cloneModel = character:Clone() end)
    if not ok2 or not cloneModel then
        print("[CLONE] Erro: falha ao clonar character")
        return nil
    end

    cloneContador = cloneContador + 1
    cloneModel.Name = "DeltaClone_" .. cloneContador

    -- Remover scripts
    for _, obj in pairs(cloneModel:GetDescendants()) do
        if obj:IsA("Script") or obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
            pcall(function() obj:Destroy() end)
        end
    end

    -- Posicao de spawn: PERTO DE MIM (8-15 studs em direcao aleatoria)
    local anguloSpawn = math.random() * math.pi * 2
    local distSpawn = math.random(8, cloneSpawnRaio)
    local spawnXZ = Vector3.new(
        meuRoot.Position.X + math.cos(anguloSpawn) * distSpawn,
        0,
        meuRoot.Position.Z + math.sin(anguloSpawn) * distSpawn
    )

    -- Achar chao nessa posicao
    local spawnPos = acharChao(spawnXZ, meuRoot.Position.Y)

    print("[CLONE] Spawn #" .. cloneContador .. " em " .. tostring(spawnPos))

    -- Posicionar o clone
    local cRoot = cloneModel:FindFirstChild("HumanoidRootPart")
    if cRoot then
        -- Ancorar temporariamente para nao cair
        cRoot.Anchored = true
        cRoot.CFrame = CFrame.new(spawnPos, alvoRoot.Position)
        pcall(function() cRoot.Velocity = Vector3.new(0,0,0) end)
        pcall(function() cRoot.AssemblyLinearVelocity = Vector3.new(0,0,0) end)
    else
        print("[CLONE] Erro: clone sem HumanoidRootPart")
        pcall(function() cloneModel:Destroy() end)
        return nil
    end

    -- Colocar no workspace
    cloneModel.Parent = folder

    -- Configurar humanoid
    local cHum = cloneModel:FindFirstChildOfClass("Humanoid")
    if cHum then
        cHum.WalkSpeed = cloneVelocidade
        pcall(function() cHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end)
        -- Evitar que morra sozinho
        pcall(function() cHum.BreakJointsOnDeath = false end)
    end

    -- Forcar colisao em todas as partes
    forcarColisaoClone(cloneModel)

    -- Desancorar depois de um delay (para dar tempo de posicionar)
    task.spawn(function()
        task.wait(0.5)
        if cRoot and cRoot.Parent then
            cRoot.Anchored = false
            -- Forcar colisao de novo apos desancorar
            forcarColisaoClone(cloneModel)
        end
    end)

    -- Criar dados do clone
    local totalAtual = getTotalClonesAtivos() + 1
    local cd = {
        modelo = cloneModel,
        conexao = nil,
        animAndarTrack = nil,
        animDancaTrack = nil,
        dancando = false,
        waypoints2 = {},
        wpIndex2 = 1,
        pathTimer2 = 0,
        ultimaPosAlvo2 = nil,
        alvoParado2 = false,
        alvoParadoTimer2 = 0,
        alvoUltimaPos2 = nil,
        alvoPlayer = alvoPlayer,
        id = cloneContador,
        indiceRoda = totalAtual, -- posicao na roda
        prontoPraAndar = false, -- esperar desancorar
    }

    -- Timer para comecar a andar
    task.spawn(function()
        task.wait(0.6)
        cd.prontoPraAndar = true
    end)

    -- IA DO CLONE - Loop principal
    cd.conexao = RunService.Heartbeat:Connect(function(dt)
        -- Verificar se clone ainda existe
        if not cd.modelo or not cd.modelo.Parent then
            if cd.conexao then cd.conexao:Disconnect(); cd.conexao = nil end
            return
        end

        local cr = cd.modelo:FindFirstChild("HumanoidRootPart")
        local ch = cd.modelo:FindFirstChildOfClass("Humanoid")
        if not cr or not ch then
            if cd.conexao then cd.conexao:Disconnect(); cd.conexao = nil end
            return
        end

        -- Pegar alvo
        local tr = nil
        if cd.alvoPlayer and cd.alvoPlayer.Character then
            tr = cd.alvoPlayer.Character:FindFirstChild("HumanoidRootPart")
        end
        if not tr then return end

        -- Se morreu, remover
        if ch.Health <= 0 then
            if cd.conexao then cd.conexao:Disconnect(); cd.conexao = nil end
            pcall(function() cd.modelo:Destroy() end)
            return
        end

        -- Esperar desancorar
        if not cd.prontoPraAndar then return end

        -- Garantir velocidade
        ch.WalkSpeed = cloneVelocidade

        -- Manter colisao
        pcall(function()
            for _, part in pairs(cd.modelo:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end)

        local dist3 = (cr.Position - tr.Position).Magnitude

        -- ==========================================
        -- DETECTAR SE O ALVO PAROU (para o clone)
        -- ==========================================
        pcall(function()
            local posAt = tr.Position
            local vl = Vector3.new(0,0,0)
            pcall(function() vl = tr.AssemblyLinearVelocity or tr.Velocity or Vector3.new(0,0,0) end)
            local vlH = Vector3.new(vl.X, 0, vl.Z).Magnitude
            local posMudou = false
            if cd.alvoUltimaPos2 then
                posMudou = (Vector3.new(posAt.X,0,posAt.Z) - Vector3.new(cd.alvoUltimaPos2.X,0,cd.alvoUltimaPos2.Z)).Magnitude > 0.3
            end
            local mov = false
            if cd.alvoPlayer and cd.alvoPlayer.Character then
                local ah = cd.alvoPlayer.Character:FindFirstChildOfClass("Humanoid")
                if ah then mov = ah.MoveDirection.Magnitude > 0.1 end
            end
            local parado = (vlH < 1) and (not posMudou) and (not mov)
            if parado then
                cd.alvoParadoTimer2 = cd.alvoParadoTimer2 + dt
                if cd.alvoParadoTimer2 >= alvoParadoThreshold then cd.alvoParado2 = true end
            else
                cd.alvoParadoTimer2 = 0; cd.alvoParado2 = false
            end
            cd.alvoUltimaPos2 = posAt
        end)

        -- ==========================================
        -- POSICAO NA RODA ao redor do alvo
        -- ==========================================
        local totalClones = getTotalClonesAtivos()
        local angOff = (cd.indiceRoda / math.max(totalClones, 1)) * math.pi * 2
        local offDir = Vector3.new(math.cos(angOff), 0, math.sin(angOff))
        local posDest = tr.Position + offDir * cloneDistancia
        local clonePerto2 = dist3 <= (cloneDistancia + 4)

        -- ==========================================
        -- DANCA DO CLONE
        -- ==========================================
        if cloneDancar and cd.alvoParado2 and clonePerto2 then
            if not cd.dancando then
                -- Parar animacao de andar
                if cd.animAndarTrack then
                    pcall(function() cd.animAndarTrack:Stop(0) end)
                    cd.animAndarTrack = nil
                end
                -- Iniciar danca
                local dancaData = DANCAS[animDancaAtual]
                if dancaData then
                    cd.animDancaTrack = cloneTocarAnimacao(ch, dancaData.id, true)
                    cd.dancando = true
                end
            end
            -- Olhar para o alvo enquanto danca
            pcall(function()
                cr.CFrame = CFrame.new(cr.Position, Vector3.new(tr.Position.X, cr.Position.Y, tr.Position.Z))
            end)
            return -- Nao mover enquanto danca
        else
            -- Parar danca se estava dancando
            if cd.dancando then
                if cd.animDancaTrack then
                    pcall(function() cd.animDancaTrack:Stop(0) end)
                    pcall(function() cd.animDancaTrack:Destroy() end)
                    cd.animDancaTrack = nil
                end
                clonePararAnimacoes(ch)
                cd.dancando = false
                cd.animAndarTrack = nil -- resetar para tocar anim de andar
            end
        end

        -- ==========================================
        -- ANIMACAO DE ANDAR
        -- ==========================================
        if not cd.dancando and not cd.animAndarTrack then
            local ad = ANIMS_ANDAR[animAndarAtual]
            if ad then cd.animAndarTrack = cloneTocarAnimacao(ch, ad.id, true) end
        end

        -- ==========================================
        -- TELEPORTE SE MUITO LONGE
        -- ==========================================
        if dist3 > 80 then
            -- TP para perto do meu personagem
            local meuRoot2 = getRootPart(LocalPlayer)
            local centroRef = meuRoot2 and meuRoot2.Position or tr.Position
            local angTP = math.random() * math.pi * 2
            local distTP = math.random(5, 15)
            local posTP = acharChao(
                Vector3.new(centroRef.X + math.cos(angTP)*distTP, 0, centroRef.Z + math.sin(angTP)*distTP),
                centroRef.Y
            )
            cr.CFrame = CFrame.new(posTP, tr.Position)
            cd.waypoints2 = {}; cd.wpIndex2 = 1
            return
        end

        -- ==========================================
        -- PERTO O SUFICIENTE - so ajustar posicao
        -- ==========================================
        if dist3 < cloneDistancia + 2 then
            ch:MoveTo(posDest)
            pcall(function()
                cr.CFrame = CFrame.new(cr.Position, Vector3.new(tr.Position.X, cr.Position.Y, tr.Position.Z))
            end)
            return
        end

        -- ==========================================
        -- PATHFINDING PARA CHEGAR AO ALVO
        -- ==========================================
        cd.pathTimer2 = cd.pathTimer2 + dt
        local precisa = (cd.ultimaPosAlvo2 == nil)
            or ((tr.Position - (cd.ultimaPosAlvo2 or Vector3.new(0,0,0))).Magnitude > 8)
            or (cd.pathTimer2 > 1.5)
            or (#cd.waypoints2 == 0)

        if precisa then
            cd.pathTimer2 = 0
            cd.ultimaPosAlvo2 = tr.Position

            local rota = nil
            pcall(function()
                rota = calcularPath(cr.Position, posDest)
            end)

            if rota then
                cd.waypoints2 = rota; cd.wpIndex2 = 1
            else
                -- Fallback: MoveTo direto
                ch:MoveTo(posDest)
                return
            end
        end

        -- Seguir waypoints
        if #cd.waypoints2 > 0 and cd.wpIndex2 <= #cd.waypoints2 then
            local wp = cd.waypoints2[cd.wpIndex2]
            if wp.Action == Enum.PathWaypointAction.Jump then ch.Jump = true end
            ch:MoveTo(wp.Position)
            if (cr.Position - wp.Position).Magnitude < 5 then
                cd.wpIndex2 = cd.wpIndex2 + 1
            end
        else
            ch:MoveTo(posDest)
        end
    end)

    table.insert(clonesAtivos, cd)
    print("[CLONE] Clone #" .. cd.id .. " criado com sucesso!")
    return cd
end

-- Adicionar multiplos clones
local function adicionarClones(qtd, alvoPlayer)
    if not alvoPlayer then
        Rayfield:Notify({Title = "Erro", Content = "Selecione um alvo!", Duration = 3})
        return
    end
    if not getRootPart(alvoPlayer) then
        Rayfield:Notify({Title = "Erro", Content = alvoPlayer.Name .. " sem personagem!", Duration = 3})
        return
    end

    local totalAntes = getTotalClonesAtivos()

    for i = 1, qtd do
        task.spawn(function()
            task.wait(i * 0.3) -- delay entre clones para nao travar
            local cd = criarClone(alvoPlayer, totalAntes + i, totalAntes + qtd)
            if cd then
                -- Atualizar indice na roda para todos os clones
                local totalNovo = getTotalClonesAtivos()
                local idx = 0
                for _, c in ipairs(clonesAtivos) do
                    if c.modelo and c.modelo.Parent then
                        idx = idx + 1
                        c.indiceRoda = idx
                    end
                end
            end
        end)
    end

    Rayfield:Notify({
        Title = "Clones!",
        Content = "Criando " .. qtd .. " clone(s) -> " .. alvoPlayer.Name,
        Duration = 4,
    })
end

-- Redirecionar clones para novo alvo
local function redirecionarClones(novoAlvo)
    if not novoAlvo then return end
    for _, cd in ipairs(clonesAtivos) do
        cd.alvoPlayer = novoAlvo
        cd.ultimaPosAlvo2 = nil; cd.waypoints2 = {}
        cd.wpIndex2 = 1; cd.pathTimer2 = 999
        cd.alvoParado2 = false; cd.alvoParadoTimer2 = 0; cd.alvoUltimaPos2 = nil
    end
    cloneAlvo = novoAlvo; cloneAlvoNome = novoAlvo.Name
    Rayfield:Notify({Title = "Redirecionados", Content = getTotalClonesAtivos() .. " clones -> " .. novoAlvo.Name, Duration = 3})
end

-- ============================================================
-- SELECAO POR TOQUE
-- ============================================================
local function ativarSelecaoPorToque()
    if conexaoToque then conexaoToque:Disconnect(); conexaoToque = nil end
    selecaoPorToque = true; toqueCooldownAtivo = false; toqueCooldownTimer = 0
    conexaoToque = RunService.Heartbeat:Connect(function(dt)
        if not selecaoPorToque then if conexaoToque then conexaoToque:Disconnect(); conexaoToque = nil end; return end
        if toqueCooldownAtivo then
            toqueCooldownTimer = toqueCooldownTimer - dt
            if toqueCooldownTimer <= 0 then toqueCooldownAtivo = false; toqueCooldownTimer = 0
                Rayfield:Notify({Title = "Toque Reativado", Content = "Seguir ao encostar ativo!", Duration = 2})
            end; return
        end
        if seguindo or fugindo then return end
        local meuRoot = getRootPart(LocalPlayer); if not meuRoot then return end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local root = getRootPart(player)
                if root and (meuRoot.Position - root.Position).Magnitude < 5 then
                    iniciarSeguir(player); break
                end
            end
        end
    end)
end

local function desativarSelecaoPorToque()
    selecaoPorToque = false; toqueCooldownAtivo = false; toqueCooldownTimer = 0
    if conexaoToque then conexaoToque:Disconnect(); conexaoToque = nil end
end

-- ============================================================
-- TELEPORTE
-- ============================================================
local function teleportarParaPlayer(nome)
    local player = getPlayerByName(nome)
    if not player then Rayfield:Notify({Title = "Erro", Content = "Player nao encontrado!", Duration = 3}); return end
    local root = getRootPart(player); local meuRoot = getRootPart(LocalPlayer)
    if not root or not meuRoot then Rayfield:Notify({Title = "Erro", Content = "Sem personagem!", Duration = 3}); return end
    meuRoot.CFrame = CFrame.new(root.Position - root.CFrame.LookVector * distanciaSeguir, root.Position)
    Rayfield:Notify({Title = "TP!", Content = "Atras de " .. player.Name, Duration = 3})
end

-- ============================================================
-- PARAR TUDO
-- ============================================================
local function pararTudo()
    if seguindo then pararSeguir() end
    if fugindo then pararFugir() end
    if selecaoPorToque then desativarSelecaoPorToque() end
    setSpeed(false, 16)
    pararTodasAnimacoes(); desativarFantasma(); removerTodosClones()
    task.spawn(function() for i=1,5 do task.wait(0.1); forcarPararTodasTracks() end end)
    limparHighlightSelecionado(); limparHighlightPerseguidor()
    estaDancando = false; alvoEstaParado = false; dancaCancelada = true
    toqueCooldownAtivo = false; toqueCooldownTimer = 0
    animSentadoTrack = nil; animAndarTrack = nil; animDancaTrack = nil
    pcall(function()
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then part.Transparency = 0
            elseif part:IsA("Decal") or part:IsA("Texture") then part.Transparency = 0 end
        end
    end)
    Rayfield:Notify({Title = "Tudo Parado", Content = "Tudo desativado.", Duration = 3})
end

-- ============================================================
-- TRANSPARENCIA DO MENU
-- ============================================================
local function aplicarTransparencia(transparencia)
    local tipos = {"Frame", "ScrollingFrame", "ImageLabel", "ImageButton", "TextLabel", "TextButton", "TextBox", "CanvasGroup"}
    local function ehUI(obj) for _, t in ipairs(tipos) do if obj:IsA(t) then return true end end; return false end
    local function aplicar(gui)
        pcall(function()
            for _, desc in pairs(gui:GetDescendants()) do
                if ehUI(desc) then
                    if not desc:GetAttribute("_OBG") then desc:SetAttribute("_OBG", desc.BackgroundTransparency) end
                    local o = desc:GetAttribute("_OBG") or 0
                    desc.BackgroundTransparency = o + (1-o) * transparencia
                    if desc:IsA("ImageLabel") or desc:IsA("ImageButton") then
                        if not desc:GetAttribute("_OIG") then desc:SetAttribute("_OIG", desc.ImageTransparency) end
                        local oi = desc:GetAttribute("_OIG") or 0
                        desc.ImageTransparency = oi + (1-oi) * transparencia
                    end
                end
            end
        end)
    end
    pcall(function() for _, g in pairs(game:GetService("CoreGui"):GetChildren()) do if g:IsA("ScreenGui") then aplicar(g) end end end)
    pcall(function() local pg = LocalPlayer:FindFirstChild("PlayerGui"); if pg then for _, g in pairs(pg:GetChildren()) do if g:IsA("ScreenGui") then aplicar(g) end end end end)
    pcall(function() if gethui then local h = gethui(); if h then for _, g in pairs(h:GetChildren()) do if g:IsA("ScreenGui") then aplicar(g) end end end end end)
end

-- ============================================================
-- RAYFIELD UI
-- ============================================================
print("[DELTA] Criando janela...")

local Window = Rayfield:CreateWindow({
    Name = "Delta v9.2",
    LoadingTitle = "Delta v9.2",
    LoadingSubtitle = "Carregando...",
    ConfigurationSaving = {Enabled = false},
    Discord = {Enabled = false},
    KeySystem = false,
})

print("[DELTA] Janela criada!")

-- ============================================================
-- ABA SEGUIR
-- ============================================================
pcall(function()
    local tab = Window:CreateTab("Seguir", 4483362458)
    tab:CreateSection("Selecionar Player")
    tab:CreateDropdown({
        Name = "Escolher Player", Options = getListaPlayers(),
        CurrentOption = {}, MultipleOptions = false, Flag = "DropSeguir",
        Callback = function(o) if o and o[1] then local p = getPlayerByName(o[1]); if p then marcarPlayerSelecionado(p) end end end,
    })
    tab:CreateInput({
        Name = "Digitar Nome", PlaceholderText = "Nome...",
        RemoveTextAfterFocusLost = false, Flag = "InputPlayer",
        Callback = function(t) if t and t ~= "" then selecionarPlayer(t) end end,
    })
    tab:CreateSection("Modo de Seguir")
    tab:CreateDropdown({
        Name = "Modo",
        Options = {"Normal (Andar)", "Pathfinding (Andar)", "Encosto (Sentado)"},
        CurrentOption = {"Normal (Andar)"}, MultipleOptions = false, Flag = "DropModo",
        Callback = function(o)
            local m = o[1]
            if m == "Encosto (Sentado)" then modoSeguir = "encosto"
            elseif m == "Pathfinding (Andar)" then modoSeguir = "pathfinding"
            else modoSeguir = "normal" end
        end,
    })
    tab:CreateSection("Acoes")
    tab:CreateButton({
        Name = "SEGUIR",
        Callback = function()
            local nome = nil
            pcall(function() local f = Rayfield.Flags
                if f and f.DropSeguir and f.DropSeguir.CurrentOption then
                    local opt = f.DropSeguir.CurrentOption; nome = type(opt) == "table" and opt[1] or opt
                end
            end)
            if (not nome or nome == "") then
                pcall(function() local f = Rayfield.Flags
                    if f and f.InputPlayer then
                        local v = f.InputPlayer.CurrentValue or f.InputPlayer
                        if type(v) == "string" and v ~= "" then nome = v end
                    end
                end)
            end
            if (not nome or nome == "") and playerSelecionadoNome then nome = playerSelecionadoNome end
            if not nome or nome == "" then Rayfield:Notify({Title = "Erro", Content = "Selecione um player!", Duration = 3}); return end
            local p = getPlayerByName(nome)
            if p then iniciarSeguir(p) else Rayfield:Notify({Title = "Erro", Content = nome .. " nao encontrado!", Duration = 3}) end
        end,
    })
    tab:CreateButton({
        Name = "PARAR",
        Callback = function()
            if seguindo then pararSeguir()
            else Rayfield:Notify({Title = "Info", Content = "Nao esta seguindo!", Duration = 2}) end
        end,
    })
    tab:CreateSection("Extras")
    tab:CreateToggle({
        Name = "Seguir ao Encostar", CurrentValue = false, Flag = "ToggleToque",
        Callback = function(v) if v then ativarSelecaoPorToque() else desativarSelecaoPorToque() end end,
    })
    print("[DELTA] Aba Seguir OK!")
end)

-- ============================================================
-- ABA CLONES
-- ============================================================
pcall(function()
    local tab = Window:CreateTab("Clones", 4483362458)

    tab:CreateSection("Alvo dos Clones")

    tab:CreateDropdown({
        Name = "Alvo", Options = getListaPlayers(),
        CurrentOption = {}, MultipleOptions = false, Flag = "DropCloneAlvo",
        Callback = function(o)
            if o and o[1] then
                local p = getPlayerByName(o[1])
                if p then cloneAlvo = p; cloneAlvoNome = p.Name; marcarPlayerSelecionado(p) end
            end
        end,
    })

    tab:CreateInput({
        Name = "Digitar Nome", PlaceholderText = "Nome do alvo...",
        RemoveTextAfterFocusLost = false, Flag = "InputCloneAlvo",
        Callback = function(t)
            if t and t ~= "" then
                local p = getPlayerByName(t)
                if p then cloneAlvo = p; cloneAlvoNome = p.Name; selecionarPlayer(t) end
            end
        end,
    })

    tab:CreateSection("Adicionar Clones")

    local function getCloneAlvo()
        local a = cloneAlvo
        if not a and playerSelecionadoNome then a = getPlayerByName(playerSelecionadoNome) end
        if not a and playerAlvo then a = playerAlvo end
        return a
    end

    tab:CreateButton({Name = "+1 Clone", Callback = function()
        local a = getCloneAlvo()
        if a then adicionarClones(1, a) else Rayfield:Notify({Title="Erro",Content="Selecione alvo!",Duration=3}) end
    end})

    tab:CreateButton({Name = "+3 Clones", Callback = function()
        local a = getCloneAlvo()
        if a then adicionarClones(3, a) else Rayfield:Notify({Title="Erro",Content="Selecione alvo!",Duration=3}) end
    end})

    tab:CreateButton({Name = "+5 Clones", Callback = function()
        local a = getCloneAlvo()
        if a then adicionarClones(5, a) else Rayfield:Notify({Title="Erro",Content="Selecione alvo!",Duration=3}) end
    end})

    tab:CreateButton({Name = "+10 Clones", Callback = function()
        local a = getCloneAlvo()
        if a then adicionarClones(10, a) else Rayfield:Notify({Title="Erro",Content="Selecione alvo!",Duration=3}) end
    end})

    tab:CreateSlider({
        Name = "Quantidade Custom", Range = {1, 50}, Increment = 1,
        Suffix = " clones", CurrentValue = 5, Flag = "SliderCloneQtd",
        Callback = function() end,
    })

    tab:CreateButton({
        Name = "Adicionar (qtd acima)",
        Callback = function()
            local a = getCloneAlvo()
            if not a then Rayfield:Notify({Title="Erro",Content="Selecione alvo!",Duration=3}); return end
            local qtd = 5
            pcall(function() local f = Rayfield.Flags
                if f and f.SliderCloneQtd then
                    local v = f.SliderCloneQtd.CurrentValue or f.SliderCloneQtd
                    if type(v) == "number" then qtd = math.floor(v) end
                end
            end)
            adicionarClones(qtd, a)
        end,
    })

    tab:CreateSection("Gerenciar")

    tab:CreateButton({
        Name = "Redirecionar Clones",
        Callback = function()
            local a = getCloneAlvo()
            if a then redirecionarClones(a) else Rayfield:Notify({Title="Erro",Content="Selecione alvo!",Duration=3}) end
        end,
    })

    tab:CreateButton({Name = "Remover TODOS", Callback = function() removerTodosClones() end})

    tab:CreateSection("Config Clones")

    tab:CreateSlider({
        Name = "Velocidade",
        Range = {10,100}, Increment = 2, Suffix = " speed",
        CurrentValue = 22, Flag = "SliderCloneSpeed",
        Callback = function(v) cloneVelocidade = v end,
    })

    tab:CreateSlider({
        Name = "Distancia (roda)",
        Range = {2,20}, Increment = 0.5, Suffix = " studs",
        CurrentValue = 5, Flag = "SliderCloneDist",
        Callback = function(v) cloneDistancia = v end,
    })

    tab:CreateSlider({
        Name = "Raio de Spawn",
        Range = {5,50}, Increment = 1, Suffix = " studs",
        CurrentValue = 15, Flag = "SliderCloneRaio",
        Callback = function(v) cloneSpawnRaio = v end,
    })

    tab:CreateToggle({
        Name = "Clones Dancam", CurrentValue = true, Flag = "ToggleCloneDanca",
        Callback = function(v)
            cloneDancar = v
            if not v then
                for _, cd in ipairs(clonesAtivos) do
                    if cd.dancando then
                        pcall(function() if cd.animDancaTrack then cd.animDancaTrack:Stop(0); cd.animDancaTrack:Destroy() end end)
                        cd.animDancaTrack = nil
                        local ch = cd.modelo and cd.modelo:FindFirstChildOfClass("Humanoid")
                        if ch then clonePararAnimacoes(ch) end
                        cd.dancando = false; cd.animAndarTrack = nil
                    end
                end
            end
        end,
    })

    tab:CreateSection("Info")
    tab:CreateButton({
        Name = "Ver Qtd Ativos",
        Callback = function()
            local total = getTotalClonesAtivos()
            Rayfield:Notify({Title = "Clones Ativos", Content = tostring(total) .. " clones no mapa", Duration = 3})
        end,
    })

    print("[DELTA] Aba Clones OK!")
end)

-- ============================================================
-- ABA FUGIR
-- ============================================================
pcall(function()
    local tab = Window:CreateTab("Fugir", 4483362458)
    tab:CreateSection("FUGA IMPOSSIVEL")
    tab:CreateDropdown({
        Name = "Fugir de quem?", Options = getListaPlayers(),
        CurrentOption = {}, MultipleOptions = false, Flag = "DropFugir",
        Callback = function(o) if o and o[1] then local p = getPlayerByName(o[1]); if p then marcarPlayerSelecionado(p) end end end,
    })
    tab:CreateInput({
        Name = "Digitar Nome", PlaceholderText = "Perseguidor...",
        RemoveTextAfterFocusLost = false, Flag = "InputFugir",
        Callback = function(t) if t and t ~= "" then selecionarPlayer(t) end end,
    })
    tab:CreateSection("Acoes")
    tab:CreateButton({
        Name = "FUGIR!",
        Callback = function()
            local nome = nil
            pcall(function() local f = Rayfield.Flags
                if f and f.DropFugir and f.DropFugir.CurrentOption then
                    local opt = f.DropFugir.CurrentOption; nome = type(opt) == "table" and opt[1] or opt
                end
            end)
            if (not nome or nome == "") then
                pcall(function() local f = Rayfield.Flags
                    if f and f.InputFugir then
                        local v = f.InputFugir.CurrentValue or f.InputFugir
                        if type(v) == "string" and v ~= "" then nome = v end
                    end
                end)
            end
            if (not nome or nome == "") and playerSelecionadoNome then nome = playerSelecionadoNome end
            if not nome or nome == "" then Rayfield:Notify({Title = "Erro", Content = "Selecione de quem fugir!", Duration = 3}); return end
            local p = getPlayerByName(nome)
            if p then iniciarFugir(p) else Rayfield:Notify({Title = "Erro", Content = nome .. " nao encontrado!", Duration = 3}) end
        end,
    })
    tab:CreateButton({
        Name = "PARAR DE FUGIR",
        Callback = function()
            if fugindo then pararFugir() else Rayfield:Notify({Title = "Info", Content = "Nao esta fugindo!", Duration = 2}) end
        end,
    })
    tab:CreateSection("Config Fuga")
    tab:CreateSlider({Name = "Dist Minima", Range = {3,20}, Increment = 1, Suffix = " studs", CurrentValue = 8, Flag = "SliderDistMin", Callback = function(v) fugirDistanciaMinima = v end})
    tab:CreateSlider({Name = "Dist Segura", Range = {15,80}, Increment = 5, Suffix = " studs", CurrentValue = 30, Flag = "SliderFugirDist", Callback = function(v) fugirDistanciaSegura = v end})
    tab:CreateSlider({Name = "Intervalo Juke", Range = {0.3,3}, Increment = 0.1, Suffix = "s", CurrentValue = 0.8, Flag = "SliderJuke", Callback = function(v) fugirJukeInterval = v end})
    tab:CreateSlider({Name = "Duracao Fantasma", Range = {0.5,5}, Increment = 0.5, Suffix = "s", CurrentValue = 1.5, Flag = "SliderFantasma", Callback = function(v) FANTASMA_DURACAO = v end})
    print("[DELTA] Aba Fugir OK!")
end)

-- ============================================================
-- ABA ANIMACOES
-- ============================================================
pcall(function()
    local tab = Window:CreateTab("Anim", 4483362458)
    tab:CreateSection("Andar")
    local na = {}; for _, a in ipairs(ANIMS_ANDAR) do table.insert(na, a.nome) end
    tab:CreateDropdown({
        Name = "Estilo de Andar", Options = na,
        CurrentOption = {ANIMS_ANDAR[1].nome}, MultipleOptions = false, Flag = "DropAndar",
        Callback = function(o)
            for i, a in ipairs(ANIMS_ANDAR) do
                if a.nome == o[1] then
                    animAndarAtual = i
                    if animAndarTrack then pcall(function() animAndarTrack:Stop(0) end); animAndarTrack = nil end
                    for _, cd in ipairs(clonesAtivos) do
                        if cd.animAndarTrack then pcall(function() cd.animAndarTrack:Stop(0) end); cd.animAndarTrack = nil end
                    end; break
                end
            end
        end,
    })
    tab:CreateSection("Danca")
    tab:CreateToggle({
        Name = "Dancar quando alvo para", CurrentValue = true, Flag = "ToggleDancar",
        Callback = function(v) dancarAoParar = v; if not v and estaDancando then pararDanca() end end,
    })
    tab:CreateSlider({Name = "Tempo para dancar", Range = {0.3,3}, Increment = 0.1, Suffix = "s", CurrentValue = 0.8, Flag = "SliderDancaDelay", Callback = function(v) alvoParadoThreshold = v end})
    local nd = {}; for _, d in ipairs(DANCAS) do table.insert(nd, d.nome) end
    tab:CreateDropdown({
        Name = "Escolher Danca", Options = nd,
        CurrentOption = {DANCAS[1].nome}, MultipleOptions = false, Flag = "DropDanca",
        Callback = function(o)
            for i, d in ipairs(DANCAS) do
                if d.nome == o[1] then
                    animDancaAtual = i
                    if estaDancando then pararDanca(); task.spawn(function() task.wait(0.15); iniciarDanca(true) end) end
                    for _, cd in ipairs(clonesAtivos) do
                        if cd.dancando and cd.animDancaTrack then
                            pcall(function() cd.animDancaTrack:Stop(0); cd.animDancaTrack:Destroy() end)
                            cd.animDancaTrack = nil; cd.dancando = false
                        end
                    end; break
                end
            end
        end,
    })
    tab:CreateSection("Testar")
    tab:CreateButton({Name = "Dancar Agora!", Callback = function() dancaCancelada = false; task.spawn(function() iniciarDanca(true) end) end})
    tab:CreateButton({Name = "Testar Andar", Callback = function()
        pararTodasAnimacoes()
        local ad = ANIMS_ANDAR[animAndarAtual]; if ad then animAndarTrack = tocarAnimacao(ad.id, true, 0.2) end
    end})
    tab:CreateButton({Name = "Parar Animacoes", Callback = function()
        pararTodasAnimacoes()
        task.spawn(function() for i=1,3 do task.wait(0.1); forcarPararTodasTracks() end end)
    end})
    print("[DELTA] Aba Anim OK!")
end)

-- ============================================================
-- ABA CONFIG
-- ============================================================
pcall(function()
    local tab = Window:CreateTab("Config", 4483362458)
    tab:CreateSection("Distancia")
    tab:CreateSlider({Name = "Distancia do Alvo", Range = {1,20}, Increment = 0.5, Suffix = " studs", CurrentValue = 3, Flag = "SliderDist", Callback = function(v) distanciaSeguir = v end})
    tab:CreateSection("Speed Hack")
    tab:CreateToggle({Name = "Speed Hack", CurrentValue = false, Flag = "ToggleSpeed", Callback = function(v) setSpeed(v, speedValor) end})
    tab:CreateSlider({Name = "Velocidade", Range = {16,200}, Increment = 2, Suffix = "", CurrentValue = 50, Flag = "SliderSpeed", Callback = function(v) speedValor = v; if speedAtivo then setSpeed(true, v) end end})
    tab:CreateSection("Invisibilidade")
    tab:CreateToggle({
        Name = "Invisivel ao Seguir", CurrentValue = false, Flag = "ToggleInvis",
        Callback = function(v)
            modoInvisivel = v
            if not v and LocalPlayer.Character then
                pcall(function() for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then part.Transparency = 0
                    elseif part:IsA("Decal") or part:IsA("Texture") then part.Transparency = 0 end
                end end)
            end
        end,
    })
    tab:CreateSection("Transparencia do Menu")
    tab:CreateSlider({
        Name = "Transparencia", Range = {0,100}, Increment = 5, Suffix = "%", CurrentValue = 0, Flag = "SliderTransp",
        Callback = function(v) aplicarTransparencia(v / 100) end,
    })
    print("[DELTA] Aba Config OK!")
end)

-- ============================================================
-- ABA TELEPORTE
-- ============================================================
pcall(function()
    local tab = Window:CreateTab("TP", 4483362458)
    tab:CreateSection("Teleporte")
    tab:CreateDropdown({
        Name = "Player", Options = getListaPlayers(),
        CurrentOption = {}, MultipleOptions = false, Flag = "DropTP",
        Callback = function(o) if o[1] then local p = getPlayerByName(o[1]); if p then marcarPlayerSelecionado(p) end end end,
    })
    tab:CreateInput({Name = "Digitar Nome", PlaceholderText = "Nome...", RemoveTextAfterFocusLost = false, Flag = "InputTP", Callback = function(t) if t and t ~= "" then selecionarPlayer(t) end end})
    tab:CreateButton({
        Name = "Teleportar",
        Callback = function()
            local nome = nil
            pcall(function() local f = Rayfield.Flags; if f and f.DropTP and f.DropTP.CurrentOption then local o = f.DropTP.CurrentOption; nome = type(o) == "table" and o[1] or o end end)
            if (not nome or nome == "") and playerSelecionadoNome then nome = playerSelecionadoNome end
            if nome and nome ~= "" then teleportarParaPlayer(nome) else Rayfield:Notify({Title = "Erro", Content = "Selecione um player!", Duration = 3}) end
        end,
    })
    tab:CreateButton({
        Name = "TP + Seguir",
        Callback = function()
            local nome = nil
            pcall(function() local f = Rayfield.Flags; if f and f.DropTP and f.DropTP.CurrentOption then local o = f.DropTP.CurrentOption; nome = type(o) == "table" and o[1] or o end end)
            if (not nome or nome == "") and playerSelecionadoNome then nome = playerSelecionadoNome end
            if nome and nome ~= "" then
                local p = getPlayerByName(nome)
                if p then teleportarParaPlayer(nome); task.wait(0.3); iniciarSeguir(p) end
            else Rayfield:Notify({Title = "Erro", Content = "Selecione um player!", Duration = 3}) end
        end,
    })
    print("[DELTA] Aba TP OK!")
end)

-- ============================================================
-- ABA GERAL
-- ============================================================
pcall(function()
    local tab = Window:CreateTab("Geral", 4483362458)
    tab:CreateSection("Controle")
    tab:CreateButton({Name = "PARAR TUDO", Callback = function() pararTudo() end})
    tab:CreateButton({
        Name = "Atualizar Lista",
        Callback = function()
            local lista = getListaPlayers()
            for _, d in ipairs({"DropSeguir", "DropTP", "DropFugir", "DropCloneAlvo"}) do
                pcall(function() local f = Rayfield.Flags; if f and f[d] then f[d]:Refresh(lista) end end)
            end
            Rayfield:Notify({Title = "Atualizado", Content = #lista .. " players", Duration = 3})
        end,
    })
    print("[DELTA] Aba Geral OK!")
end)

-- ============================================================
-- EVENTOS
-- ============================================================
pcall(function()
    Players.PlayerRemoving:Connect(function(player)
        if playerAlvo and playerAlvo == player then pararSeguir(); Rayfield:Notify({Title = "Saiu", Content = player.Name, Duration = 4}) end
        if playerPerseguidor and playerPerseguidor == player then pararFugir(); Rayfield:Notify({Title = "Saiu", Content = player.Name, Duration = 4}) end
        if playerSelecionadoNome == player.Name then limparHighlightSelecionado() end
        if cloneAlvo and cloneAlvo == player then removerTodosClones(); cloneAlvo = nil; cloneAlvoNome = nil end
        task.wait(1)
        local lista = getListaPlayers()
        for _, d in ipairs({"DropSeguir","DropTP","DropFugir","DropCloneAlvo"}) do
            pcall(function() local f = Rayfield.Flags; if f and f[d] then f[d]:Refresh(lista) end end)
        end
    end)

    Players.PlayerAdded:Connect(function()
        task.wait(2)
        local lista = getListaPlayers()
        for _, d in ipairs({"DropSeguir","DropTP","DropFugir","DropCloneAlvo"}) do
            pcall(function() local f = Rayfield.Flags; if f and f[d] then f[d]:Refresh(lista) end end)
        end
    end)

    LocalPlayer.CharacterAdded:Connect(function()
        animSentadoTrack = nil; animAndarTrack = nil; animDancaTrack = nil; estaDancando = false
        desativarFantasma()
        if seguindo then task.wait(2)
            if playerAlvo and getRootPart(playerAlvo) then iniciarSeguir(playerAlvo) else pararSeguir() end
        end
        if fugindo then task.wait(2)
            if playerPerseguidor and getRootPart(playerPerseguidor) then iniciarFugir(playerPerseguidor) else pararFugir() end
        end
        if speedAtivo and not fugindo then task.wait(1); local h = getHumanoid(LocalPlayer); if h then h.WalkSpeed = speedValor end end
    end)

    print("[DELTA] Eventos OK!")
end)

-- ============================================================
-- PRONTO
-- ============================================================
Rayfield:Notify({Title = "Delta v9.2", Content = "Clones corrigidos! Spawn perto + roda + colisao", Duration = 5})
print("[DELTA v9.2] Carregado com sucesso!")
print("[DELTA v9.2] Clones agora: spawn perto, roda ao redor, colisao real")
