--[[
    DELTA EXECUTOR - CLONE FOLLOWER v7
    Versão Estável - Sem afetar o jogador
    Correção: clones não ficam dentro do jogador
]]

--[ Configurações ]--
local Config = {
    FollowDistance = 5,
    FollowSpeed = 16,
    CloneName = "Clone",
    MaxClones = 5,
    SpawnDistance = 10
}

--[ Variáveis ]--
local Player = game.Players.LocalPlayer
local Clones = {}
local Following = false

--[ Sistema de Log ]--
local Logs = {}
local LogText
local gameLogFrame

local function AddLog(msg, tipo)
    local t = {sucesso="✅", erro="❌", aviso="⚠️", info="ℹ️"}
    local txt = string.format("[%s] %s %s", os.date("%H:%M:%S"), t[tipo] or "ℹ️", msg)
    table.insert(Logs, 1, txt)
    if #Logs > 50 then table.remove(Logs) end
    if gameLogFrame and gameLogFrame.Visible and LogText then
        LogText.Text = table.concat(Logs, "\n")
    end
    print(txt)
end

--[ CRIAÇÃO DO CLONE - MODO SEGURO ]--
function CreateClone()
    pcall(function()
        if #Clones >= Config.MaxClones then
            AddLog("Limite máximo: " .. Config.MaxClones, "aviso")
            return
        end

        local char = Player.Character or Player.CharacterAdded:Wait()
        task.wait(0.3)

        char = Player.Character
        if not char then AddLog("Sem personagem!", "erro") return end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then AddLog("Sem HRP!", "erro") return end

        -- Calcula posição de spawn LONGE do jogador
        local angle = math.random() * math.pi * 2
        local dist = Config.SpawnDistance + (#Clones * 3)
        local spawnPos = Vector3.new(
            hrp.Position.X + math.cos(angle) * dist,
            hrp.Position.Y,
            hrp.Position.Z + math.sin(angle) * dist
        )

        AddLog("Spawn: " .. math.floor(spawnPos.X) .. "," .. math.floor(spawnPos.Z), "info")

        -- Cria modelo do clone
        local clone = Instance.new("Model")
        clone.Name = Config.CloneName .. (#Clones + 1)
        clone.Parent = workspace

        -- Cria HRP do clone na posição de spawn
        local cloneHRP = Instance.new("Part")
        cloneHRP.Name = "HumanoidRootPart"
        cloneHRP.Size = Vector3.new(2, 2, 1)
        cloneHRP.CFrame = CFrame.new(spawnPos)
        cloneHRP.Anchored = false
        cloneHRP.CanCollide = false
        cloneHRP.Transparency = 1
        cloneHRP.Parent = clone

        -- Cria Humanoid
        local humanoid = Instance.new("Humanoid")
        humanoid.WalkSpeed = Config.FollowSpeed
        humanoid.PlatformStand = false
        humanoid.Parent = clone

        -- Offset do HRP original para o spawn
        local hrpOffset = spawnPos - hrp.Position

        -- Copia partes do corpo mantendo offset correto
        local partsToClone = {"Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}

        for _, partName in pairs(partsToClone) do
            local origPart = char:FindFirstChild(partName)
            if origPart then
                local newPart = origPart:Clone()
                newPart.Anchored = false
                newPart.CanCollide = false
                -- Aplica o offset relativo ao HRP original
                local relCFrame = hrp.CFrame:ToObjectSpace(origPart.CFrame)
                newPart.CFrame = cloneHRP.CFrame:ToWorldSpace(relCFrame)
                newPart.Parent = clone
            end
        end

        task.wait(0.1)

        local newTorso = clone:FindFirstChild("Torso")
        local newHead = clone:FindFirstChild("Head")
        local newHRP = clone:FindFirstChild("HumanoidRootPart")

        -- Motor6D: HRP → Torso
        if newTorso and newHRP then
            local origTorso = char:FindFirstChild("Torso")
            local origHRP = hrp

            local rootJoint = Instance.new("Motor6D")
            rootJoint.Name = "RootJoint"
            rootJoint.Part0 = newHRP
            rootJoint.Part1 = newTorso
            -- Usa os mesmos C0/C1 do personagem original se existir
            local origRJ = origHRP:FindFirstChild("RootJoint")
            if origRJ then
                rootJoint.C0 = origRJ.C0
                rootJoint.C1 = origRJ.C1
            else
                rootJoint.C0 = CFrame.new(0, -1, 0) * CFrame.Angles(-math.pi/2, 0, math.pi)
                rootJoint.C1 = CFrame.new(0, -1, 0) * CFrame.Angles(-math.pi/2, 0, math.pi)
            end
            rootJoint.Parent = newHRP
        end

        -- Conecta joints entre Torso e membros (copia do personagem original)
        if newTorso then
            local origTorso = char:FindFirstChild("Torso")
            if origTorso then
                for _, joint in pairs(origTorso:GetChildren()) do
                    if joint:IsA("Motor6D") then
                        local newJoint = joint:Clone()
                        -- Atualiza referências para as partes do clone
                        local p0Name = joint.Part0 and joint.Part0.Name
                        local p1Name = joint.Part1 and joint.Part1.Name
                        local clonePart0 = p0Name and clone:FindFirstChild(p0Name)
                        local clonePart1 = p1Name and clone:FindFirstChild(p1Name)
                        if clonePart0 and clonePart1 then
                            newJoint.Part0 = clonePart0
                            newJoint.Part1 = clonePart1
                            newJoint.Parent = newTorso
                        end
                    end
                end
            end
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

        -- Define PrimaryPart para MoveTo funcionar corretamente
        clone.PrimaryPart = cloneHRP

        table.insert(Clones, clone)
        Following = true

        AddLog("Clone #" .. #Clones .. " criado!", "sucesso")
    end)
end

--[ MOVIMENTO ]--
function MoveClone(clone)
    pcall(function()
        if not Following then return end

        local cloneHRP = clone:FindFirstChild("HumanoidRootPart")
        local playerHRP = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
        local humanoid = clone:FindFirstChild("Humanoid")

        if not cloneHRP or not playerHRP or not humanoid then return end

        local dist = (playerHRP.Position - cloneHRP.Position).Magnitude

        if dist > Config.FollowDistance then
            local dir = (playerHRP.Position - cloneHRP.Position).Unit
            -- Para a FollowDistance studs do jogador, nunca dentro dele
            local target = playerHRP.Position - (dir * Config.FollowDistance)

            humanoid.WalkSpeed = Config.FollowSpeed
            humanoid:MoveTo(target)
            -- Faz o clone olhar para o jogador
            cloneHRP.CFrame = CFrame.new(cloneHRP.Position, Vector3.new(playerHRP.Position.X, cloneHRP.Position.Y, playerHRP.Position.Z))
        end
    end)
end

--[ Loop de Movimento ]--
task.spawn(function()
    while true do
        pcall(function()
            if Following then
                for _, c in pairs(Clones) do
                    if c and c.Parent then MoveClone(c) end
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

local tl = Instance.new("TextLabel")
tl.Text = "👤 Clone Follower v7"
tl.Size = UDim2.new(1, 0, 0, 40)
tl.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
tl.TextColor3 = Color3.new(1, 1, 1)
tl.Font = Enum.Font.GothamBold
tl.Parent = mf
Instance.new("UICorner", tl).CornerRadius = UDim.new(0, 15)

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

local ct = Instance.new("Frame")
ct.Size = UDim2.new(1, -20, 1, -50)
ct.Position = UDim2.new(0, 10, 0, 45)
ct.BackgroundTransparency = 1
ct.Parent = mf

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

local logBtn = Instance.new("TextButton")
logBtn.Text = "📋 VER LOGS"
logBtn.Size = UDim2.new(1, 0, 0, 35)
logBtn.Position = UDim2.new(0, 0, 0, 90)
logBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
logBtn.TextColor3 = Color3.new(1, 1, 1)
logBtn.Font = Enum.Font.GothamBold
logBtn.Parent = ct
Instance.new("UICorner", logBtn).CornerRadius = UDim.new(0, 8)

local status = Instance.new("TextLabel")
status.Text = "❌ Sem clone"
status.Size = UDim2.new(1, 0, 0, 30)
status.Position = UDim2.new(0, 0, 0, 135)
status.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
status.TextColor3 = Color3.new(1, 0.3, 0.3)
status.Font = Enum.Font.Gotham
status.Parent = ct
Instance.new("UICorner", status).CornerRadius = UDim.new(0, 6)

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

gameLogFrame = Instance.new("Frame")
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

LogText = Instance.new("TextLabel")
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

AddLog("Clone Follower v7 iniciado!", "sucesso")
AddLog("Versão estável - não afeta o jogador", "info")
AddLog("Spawn distance: " .. Config.SpawnDistance .. " studs", "info")
