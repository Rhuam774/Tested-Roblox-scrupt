--[[
    DELTA EXECUTOR - CLONE FOLLOWER v6 (CORRIGIDO)
    Versao Estavel - Sem afetar o jogador
    Fix: Motor6Ds completos, repulsao, clones nao ficam dentro do jogador
]]

--[ Configuracoes ]--
local Config = {
    FollowDistance = 6,
    MinDistance = 3,
    FollowSpeed = 16,
    CloneName = "Clone",
    MaxClones = 5,
    SpawnDistance = 12
}

--[ Variaveis ]--
local Player = game.Players.LocalPlayer
local Clones = {}
local Following = false

--[ Sistema de Log ]--
local Logs = {}
local function AddLog(msg, tipo)
    local t = {sucesso="✅", erro="❌", aviso="⚠️", info="ℹ️"}
    local txt = string.format("[%s] %s %s", os.date("%H:%M:%S"), t[tipo]or"ℹ️", msg)
    table.insert(Logs, 1, txt)
    if #Logs > 50 then table.remove(Logs) end
    if gameLogFrame and gameLogFrame.Visible then LogText.Text = table.concat(Logs, "\n") end
    print(txt)
end

--[ HELPER: Criar Motor6D ]--
local function CreateMotor6D(name, part0, part1, c0, c1)
    local motor = Instance.new("Motor6D")
    motor.Name = name
    motor.Part0 = part0
    motor.Part1 = part1
    motor.C0 = c0
    motor.C1 = c1
    motor.Parent = part0
    return motor
end

--[ HELPER: Posicao de formacao ao redor do jogador ]--
local function GetFormationOffset(index, total)
    -- Distribui clones em circulo ao redor do jogador
    local angle = (index / math.max(total, 1)) * math.pi * 2
    return Vector3.new(
        math.cos(angle) * Config.FollowDistance,
        0,
        math.sin(angle) * Config.FollowDistance
    )
end

--[ CRIACAO DO CLONE - MODO SEGURO ]--
function CreateClone()
    pcall(function()
        if #Clones >= Config.MaxClones then
            AddLog("Limite maximo: " .. Config.MaxClones, "aviso")
            return
        end

        -- Espera personagem
        local char = Player.Character or Player.CharacterAdded:Wait()
        task.wait(0.3)

        char = Player.Character
        if not char then AddLog("Sem personagem!", "erro") return end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then AddLog("Sem HRP!", "erro") return end

        -- Calcula posicao de spawn LONGE do jogador
        local cloneIndex = #Clones + 1
        local angle = (cloneIndex / Config.MaxClones) * math.pi * 2
        local dist = Config.SpawnDistance + (cloneIndex * 3)
        local spawnPos = Vector3.new(
            hrp.Position.X + math.cos(angle) * dist,
            hrp.Position.Y,
            hrp.Position.Z + math.sin(angle) * dist
        )

        AddLog("Spawn: " .. math.floor(spawnPos.X) .. "," .. math.floor(spawnPos.Z), "info")

        -- Cria clone Model
        local clone = Instance.new("Model")
        clone.Name = Config.CloneName .. cloneIndex
        clone.Parent = workspace

        -- Cria HRP do clone
        local cloneHRP = Instance.new("Part")
        cloneHRP.Name = "HumanoidRootPart"
        cloneHRP.Size = Vector3.new(2, 2, 1)
        cloneHRP.CFrame = CFrame.new(spawnPos)
        cloneHRP.Anchored = false
        cloneHRP.CanCollide = false
        cloneHRP.Transparency = 1
        cloneHRP.Parent = clone

        clone.PrimaryPart = cloneHRP

        -- Cria Humanoid
        local humanoid = Instance.new("Humanoid")
        humanoid.WalkSpeed = Config.FollowSpeed
        humanoid.PlatformStand = false
        humanoid.Parent = clone

        -- Offset do spawn relativo ao jogador
        local offset = spawnPos - hrp.Position

        -- Copia partes do corpo
        local partsToClone = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}

        for _, partName in pairs(partsToClone) do
            local origPart = char:FindFirstChild(partName)
            if origPart then
                local newPart = origPart:Clone()
                newPart.Anchored = false
                newPart.CanCollide = false
                newPart.CFrame = origPart.CFrame + offset
                newPart.Parent = clone
            end
        end

        task.wait(0.1)

        -- Pega referencias das partes do clone
        local newHRP = clone:FindFirstChild("HumanoidRootPart")
        local newTorso = clone:FindFirstChild("Torso")
        local newHead = clone:FindFirstChild("Head")
        local newLA = clone:FindFirstChild("Left Arm")
        local newRA = clone:FindFirstChild("Right Arm")
        local newLL = clone:FindFirstChild("Left Leg")
        local newRL = clone:FindFirstChild("Right Leg")

        -- CRIA TODOS OS MOTOR6Ds (isso e essencial para o Humanoid funcionar!)
        if newHRP and newTorso then
            -- RootJoint: HRP -> Torso
            CreateMotor6D("RootJoint", newHRP, newTorso,
                CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
                CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
            )
        end

        if newTorso and newHead then
            -- Neck: Torso -> Head
            CreateMotor6D("Neck", newTorso, newHead,
                CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
                CFrame.new(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
            )
        end

        if newTorso and newLA then
            -- Left Shoulder: Torso -> Left Arm
            CreateMotor6D("Left Shoulder", newTorso, newLA,
                CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
                CFrame.new(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
            )
        end

        if newTorso and newRA then
            -- Right Shoulder: Torso -> Right Arm
            CreateMotor6D("Right Shoulder", newTorso, newRA,
                CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
                CFrame.new(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
            )
        end

        if newTorso and newLL then
            -- Left Hip: Torso -> Left Leg
            CreateMotor6D("Left Hip", newTorso, newLL,
                CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
                CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
            )
        end

        if newTorso and newRL then
            -- Right Hip: Torso -> Right Leg
            CreateMotor6D("Right Hip", newTorso, newRL,
                CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
                CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
            )
        end

        -- Face
        local origHead = char:FindFirstChild("Head")
        if origHead and newHead and origHead:FindFirstChild("face") then
            origHead:FindFirstChild("face"):Clone().Parent = newHead
        end

        -- Roupas
        for _, child in pairs(char:GetChildren()) do
            if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("BodyColors") then
                child:Clone().Parent = clone
            end
        end

        -- Acessorios
        for _, child in pairs(char:GetChildren()) do
            if child:IsA("Accessory") then
                pcall(function()
                    child:Clone().Parent = clone
                end)
            end
        end

        table.insert(Clones, clone)
        Following = true

        -- Teleporta clone para posicao correta DEPOIS de montar tudo
        task.wait(0.2)
        if clone.PrimaryPart then
            clone:SetPrimaryPartCFrame(CFrame.new(spawnPos))
        end

        AddLog("Clone #" .. #Clones .. " criado!", "sucesso")
    end)
end

--[ MOVIMENTO - COM REPULSAO ]--
function MoveClone(clone, index)
    pcall(function()
        if not Following then return end

        local cloneHRP = clone:FindFirstChild("HumanoidRootPart")
        local playerHRP = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
        local humanoid = clone:FindFirstChild("Humanoid")

        if not cloneHRP or not playerHRP or not humanoid then return end

        local diff = cloneHRP.Position - playerHRP.Position
        local dist = diff.Magnitude

        -- Calcula posicao alvo em formacao ao redor do jogador
        local formationOffset = GetFormationOffset(index, #Clones)
        local targetPos = playerHRP.Position + formationOffset

        -- REPULSAO: Se muito perto, empurra para fora imediatamente
        if dist < Config.MinDistance then
            local pushDir
            if dist < 0.1 then
                -- Se praticamente sobreposto, escolhe direcao baseada no index
                local pushAngle = (index / math.max(#Clones, 1)) * math.pi * 2
                pushDir = Vector3.new(math.cos(pushAngle), 0, math.sin(pushAngle))
            else
                pushDir = (diff * Vector3.new(1, 0, 1)).Unit
            end
            -- Teleporta para fora imediatamente
            local safePos = playerHRP.Position + pushDir * Config.FollowDistance
            cloneHRP.CFrame = CFrame.new(
                safePos.X,
                playerHRP.Position.Y,
                safePos.Z
            )
            AddLog("Clone #" .. index .. " reposicionado (muito perto)", "aviso")
            return
        end

        -- Movimento normal: vai ate a posicao de formacao
        local distToTarget = (targetPos - cloneHRP.Position).Magnitude

        if distToTarget > 1 then
            humanoid.WalkSpeed = Config.FollowSpeed
            humanoid:MoveTo(targetPos)
            -- Faz o clone olhar pro jogador
            cloneHRP.CFrame = CFrame.new(cloneHRP.Position, Vector3.new(playerHRP.Position.X, cloneHRP.Position.Y, playerHRP.Position.Z))
        end

        -- Se ficou muito longe, teleporta pra perto
        if dist > 50 then
            local tp = playerHRP.Position + formationOffset
            cloneHRP.CFrame = CFrame.new(tp.X, playerHRP.Position.Y, tp.Z)
            AddLog("Clone #" .. index .. " teleportado (muito longe)", "info")
        end
    end)
end

--[ Loop ]--
task.spawn(function()
    while true do
        pcall(function()
            if Following then
                for i, c in pairs(Clones) do
                    if c and c.Parent then
                        MoveClone(c, i)
                    end
                end
            end
        end)
        task.wait(0.1)
    end
end)

--[ Deletar ]--
function DeleteClone()
    if #Clones > 0 then
        local c = table.remove(Clones)
        if c then c:Destroy() end
        if #Clones == 0 then Following = false end
        AddLog("Clone deletado", "sucesso")
    end
end

function DeleteAll()
    for _, c in pairs(Clones) do if c then c:Destroy() end end
    Clones = {}
    Following = false
    AddLog("Todos deletados", "sucesso")
end

--[ GUI ]--
local sg = Instance.new("ScreenGui")
sg.Name = "CloneGUI"
sg.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

local mf = Instance.new("Frame")
mf.Size = UDim2.new(0, 350, 0, 300)
mf.Position = UDim2.new(0.5, -175, 0.5, -150)
mf.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
mf.Active = true
mf.Draggable = true
mf.Parent = sg
Instance.new("UICorner", mf).CornerRadius = UDim.new(0, 15)

-- Titulo
local tl = Instance.new("TextLabel")
tl.Text = "👤 Clone Follower v6"
tl.Size = UDim2.new(1, 0, 0, 40)
tl.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
tl.TextColor3 = Color3.new(1, 1, 1)
tl.Font = Enum.Font.GothamBold
tl.Parent = mf
Instance.new("UICorner", tl).CornerRadius = UDim.new(0, 15)

-- Minimizar
local minBtn = Instance.new("TextButton")
minBtn.Text = "—"
minBtn.Size = UDim2.new(0, 30, 0, 25)
minBtn.Position = UDim2.new(1, -40, 0, 8)
minBtn.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
minBtn.TextColor3 = Color3.new(1, 1, 1)
minBtn.Font = Enum.Font.GothamBold
minBtn.Parent = tl

local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    mf:TweenSize(minimized and UDim2.new(0, 350, 0, 45) or UDim2.new(0, 350, 0, 300), "Out", "Quad", 0.3)
    minBtn.Text = minimized and "+" or "—"
end)

-- Container
local ct = Instance.new("Frame")
ct.Size = UDim2.new(1, -20, 1, -50)
ct.Position = UDim2.new(0, 10, 0, 45)
ct.BackgroundTransparency = 1
ct.Parent = mf

-- +
local addBtn = Instance.new("TextButton")
addBtn.Text = "+"
addBtn.Size = UDim2.new(0, 45, 0, 40)
addBtn.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
addBtn.TextColor3 = Color3.new(1, 1, 1)
addBtn.Font = Enum.Font.GothamBold
addBtn.TextSize = 20
addBtn.Parent = ct
Instance.new("UICorner", addBtn).CornerRadius = UDim.new(0, 8)
addBtn.MouseButton1Click:Connect(CreateClone)

-- Criar
local crBtn = Instance.new("TextButton")
crBtn.Text = "🎭 CRIAR CLONE"
crBtn.Size = UDim2.new(1, -55, 0, 40)
crBtn.Position = UDim2.new(0, 50, 0, 0)
crBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 255)
crBtn.TextColor3 = Color3.new(1, 1, 1)
crBtn.Font = Enum.Font.GothamBold
crBtn.Parent = ct
Instance.new("UICorner", crBtn).CornerRadius = UDim.new(0, 8)
crBtn.MouseButton1Click:Connect(CreateClone)

-- Deletar
local delBtn = Instance.new("TextButton")
delBtn.Text = "🗑️ DELETAR"
delBtn.Size = UDim2.new(0.48, 0, 0, 35)
delBtn.Position = UDim2.new(0, 0, 0, 48)
delBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
delBtn.TextColor3 = Color3.new(1, 1, 1)
delBtn.Font = Enum.Font.GothamBold
delBtn.Parent = ct
Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0, 8)
delBtn.MouseButton1Click:Connect(DeleteClone)

-- Todos
local delAllBtn = Instance.new("TextButton")
delAllBtn.Text = "🗑️ TODOS"
delAllBtn.Size = UDim2.new(0.48, 0, 0, 35)
delAllBtn.Position = UDim2.new(0.52, 0, 0, 48)
delAllBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
delAllBtn.TextColor3 = Color3.new(1, 1, 1)
delAllBtn.Font = Enum.Font.GothamBold
delAllBtn.Parent = ct
Instance.new("UICorner", delAllBtn).CornerRadius = UDim.new(0, 8)
delAllBtn.MouseButton1Click:Connect(DeleteAll)

-- Logs
local logBtn = Instance.new("TextButton")
logBtn.Text = "📋 VER LOGS"
logBtn.Size = UDim2.new(1, 0, 0, 35)
logBtn.Position = UDim2.new(0, 0, 0, 90)
logBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
logBtn.TextColor3 = Color3.new(1, 1, 1)
logBtn.Font = Enum.Font.GothamBold
logBtn.Parent = ct
Instance.new("UICorner", logBtn).CornerRadius = UDim.new(0, 8)

-- Status
local status = Instance.new("TextLabel")
status.Text = "❌ Sem clone"
status.Size = UDim2.new(1, 0, 0, 30)
status.Position = UDim2.new(0, 0, 0, 135)
status.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
status.TextColor3 = Color3.new(1, 0.3, 0.3)
status.Font = Enum.Font.Gotham
status.Parent = ct
Instance.new("UICorner", status).CornerRadius = UDim.new(0, 6)

-- Info
local info = Instance.new("TextLabel")
info.Text = "📍 Dist: " .. Config.FollowDistance .. " | Spawn: " .. Config.SpawnDistance .. " | 👥: 0/" .. Config.MaxClones
info.Size = UDim2.new(1, 0, 0, 25)
info.Position = UDim2.new(0, 0, 0, 175)
info.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
info.TextColor3 = Color3.new(0.6, 0.6, 0.6)
info.Font = Enum.Font.Gotham
info.TextSize = 10
info.Parent = ct

--[ TELA DE LOGS ]--
local lg = Instance.new("ScreenGui")
lg.Name = "LogGui"
lg.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

local gameLogFrame = Instance.new("Frame")
gameLogFrame.Size = UDim2.new(0, 450, 0, 280)
gameLogFrame.Position = UDim2.new(0.5, -225, 0.5, -140)
gameLogFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
gameLogFrame.Active = true
gameLogFrame.Draggable = true
gameLogFrame.Visible = false
gameLogFrame.Parent = lg
Instance.new("UICorner", gameLogFrame).CornerRadius = UDim.new(0, 12)

local ltl = Instance.new("TextLabel")
ltl.Text = "📜 LOGS"
ltl.Size = UDim2.new(1, 0, 0, 35)
ltl.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
ltl.TextColor3 = Color3.new(1, 1, 1)
ltl.Font = Enum.Font.GothamBold
ltl.Parent = gameLogFrame
Instance.new("UICorner", ltl).CornerRadius = UDim.new(0, 12)

local clsBtn = Instance.new("TextButton")
clsBtn.Text = "✕"
clsBtn.Size = UDim2.new(0, 25, 0, 25)
clsBtn.Position = UDim2.new(1, -35, 0, 5)
clsBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
clsBtn.TextColor3 = Color3.new(1, 1, 1)
clsBtn.Font = Enum.Font.GothamBold
clsBtn.Parent = ltl
clsBtn.MouseButton1Click:Connect(function() gameLogFrame.Visible = false end)

local ls = Instance.new("ScrollingFrame")
ls.Size = UDim2.new(1, -20, 1, -70)
ls.Position = UDim2.new(0, 10, 0, 40)
ls.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
ls.ScrollBarThickness = 5
ls.Parent = gameLogFrame

local LogText = Instance.new("TextLabel")
LogText.Size = UDim2.new(1, 0, 0, 0)
LogText.BackgroundTransparency = 1
LogText.TextColor3 = Color3.new(0.8, 0.8, 0.8)
LogText.Font = Enum.Font.Code
LogText.TextSize = 11
LogText.TextXAlignment = Enum.TextXAlignment.Left
LogText.AutomaticSize = Enum.AutomaticSize.Y
LogText.Parent = ls

local copyBtn = Instance.new("TextButton")
copyBtn.Text = "📋 COPIAR"
copyBtn.Size = UDim2.new(1, -20, 0, 25)
copyBtn.Position = UDim2.new(0, 10, 1, -30)
copyBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 80)
copyBtn.TextColor3 = Color3.new(1, 1, 1)
copyBtn.Font = Enum.Font.GothamBold
copyBtn.Parent = gameLogFrame
Instance.new("UICorner", copyBtn).CornerRadius = UDim.new(0, 6)
copyBtn.MouseButton1Click:Connect(function()
    setclipboard(table.concat(Logs, "\n"))
    AddLog("Copiado!", "sucesso")
end)

logBtn.MouseButton1Click:Connect(function()
    gameLogFrame.Visible = true
    LogText.Text = table.concat(Logs, "\n")
end)

--[ Status Loop ]--
task.spawn(function()
    while true do
        pcall(function()
            local c = #Clones
            if c > 0 and Following then
                status.Text = "✅ " .. c .. " clone(s) seguindo!"
                status.TextColor3 = Color3.new(0.3, 1, 0.3)
            elseif c > 0 then
                status.Text = "⚠️ " .. c .. " clone(s) criado(s)"
                status.TextColor3 = Color3.new(1, 1, 0)
            else
                status.Text = "❌ Sem clone"
                status.TextColor3 = Color3.new(1, 0.3, 0.3)
            end
            info.Text = "📍 Dist: " .. Config.FollowDistance .. " | Spawn: " .. Config.SpawnDistance .. " | 👥: " .. c .. "/" .. Config.MaxClones
        end)
        task.wait(0.5)
    end
end)

AddLog("Clone Follower v6 iniciado!", "sucesso")
AddLog("Versao estavel - nao afeta o jogador", "info")
AddLog("Spawn distance: " .. Config.SpawnDistance .. " studs", "info")
