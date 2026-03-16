--[[
    DELTA EXECUTOR - CLONE FOLLOWER v7
    VERSÃO CORRIGIDA - Sem dependência de PathfindingService
]]

--[ Configurações ]--
local Config = {
    FollowDistance = 4,
    FollowSpeed = 16,
    CloneName = "Clone",
    MaxClones = 5,
    SpawnDistance = 12,
    JumpWhenBlocked = true
}

--[ Variáveis ]--
local Player = game.Players.LocalPlayer
local Clones = {}
local Following = false

--[ Sistema de Log ]--
local Logs = {}
local LogText
local gameLogFrame

local function UpdateLogDisplay()
    if LogText then
        LogText.Text = table.concat(Logs, "\n")
    end
end

local function AddLog(message, tipo)
    local hora = os.date("%H:%M:%S")
    local tipos = { sucesso = "✅", erro = "❌", aviso = "⚠️", info = "ℹ️" }
    local icone = tipos[tipo] or "ℹ️"
    local logCompleto = string.format("[%s] %s %s", hora, icone, message)
    table.insert(Logs, 1, logCompleto)
    if #Logs > 50 then table.remove(Logs) end
    if gameLogFrame and gameLogFrame.Visible then UpdateLogDisplay() end
    print(logCompleto)
end

--[ CRIAÇÃO DO CLONE ]--
function CreateClone()
    pcall(function()
        if #Clones >= Config.MaxClones then
            AddLog("Limite máximo: " .. Config.MaxClones, "aviso")
            return
        end

        local char = Player.Character or Player.CharacterAdded:Wait()
        task.wait(0.2)
        char = Player.Character
        if not char then AddLog("Sem personagem!", "erro") return end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then AddLog("Sem HRP!", "erro") return end

        -- Posição de spawn longe do jogador
        local angle = math.random() * math.pi * 2
        local dist = Config.SpawnDistance + (#Clones * 4)
        local spawnPos = Vector3.new(
            hrp.Position.X + math.cos(angle) * dist,
            hrp.Position.Y,
            hrp.Position.Z + math.sin(angle) * dist
        )

        AddLog("Spawn: " .. math.floor(spawnPos.X) .. "," .. math.floor(spawnPos.Z), "info")

        -- Clona o personagem inteiro
        local clone = char:Clone()
        clone.Name = Config.CloneName .. "_" .. (#Clones + 1)

        -- Remove scripts do clone
        for _, v in pairs(clone:GetDescendants()) do
            if v:IsA("BaseScript") or v:IsA("ModuleScript") then
                v:Destroy()
            end
        end

        -- Desativa colisão
        for _, v in pairs(clone:GetDescendants()) do
            if v:IsA("BasePart") then
                v.CanCollide = false
            end
        end

        -- Ajusta Humanoid
        local cloneHumanoid = clone:FindFirstChildOfClass("Humanoid")
        if cloneHumanoid then
            cloneHumanoid.WalkSpeed = Config.FollowSpeed
            cloneHumanoid.PlatformStand = false
            cloneHumanoid.AutoJumpEnabled = Config.JumpWhenBlocked
        end

        clone.Parent = workspace

        -- Teleporta para o spawn
        local cloneHRP = clone:FindFirstChild("HumanoidRootPart")
        if not cloneHRP then
            AddLog("Clone sem HRP!", "erro")
            clone:Destroy()
            return
        end

        cloneHRP.Anchored = true
        clone:SetPrimaryPartCFrame(CFrame.new(spawnPos))
        task.wait(0.05)
        cloneHRP.Anchored = false

        table.insert(Clones, clone)
        Following = true
        AddLog("Clone #" .. #Clones .. " criado!", "sucesso")

        -- Inicia loop de movimento dedicado
        StartCloneFollow(clone)
    end)
end

--[ MOVIMENTO DO CLONE - SEM PATHFINDING ]--
function StartCloneFollow(clone)
    task.spawn(function()
        while clone and clone.Parent and Following do
            pcall(function()
                local cloneHRP = clone:FindFirstChild("HumanoidRootPart")
                local playerChar = Player.Character
                local playerHRP = playerChar and playerChar:FindFirstChild("HumanoidRootPart")
                local humanoid = clone:FindFirstChildOfClass("Humanoid")

                if not cloneHRP or not playerHRP or not humanoid then return end
                if humanoid.Health <= 0 then return end

                local dist = (playerHRP.Position - cloneHRP.Position).Magnitude

                -- Se estiver perto do suficiente, não move
                if dist <= Config.FollowDistance then
                    task.wait(0.1)
                    return
                end

                -- Movimento direto em direção ao jogador
                local direction = (playerHRP.Position - cloneHRP.Position).Unit
                local targetPos = playerHRP.Position - (direction * Config.FollowDistance)

                -- Move o clone para o alvo
                humanoid:MoveTo(targetPos)

                -- Aguarda um pouco antes de recalcular
                task.wait(0.15)

            end)
        end
    end)
end

--[ Deletar Clone ]--
function DeleteClone()
    if #Clones > 0 then
        local clone = table.remove(Clones)
        if clone then clone:Destroy() end
        if #Clones == 0 then Following = false end
        AddLog("Último clone deletado!", "sucesso")
    else
        AddLog("Nenhum clone para deletar!", "aviso")
    end
end

--[ Deletar Todos ]--
function DeleteAllClones()
    for _, clone in pairs(Clones) do
        if clone then clone:Destroy() end
    end
    Clones = {}
    Following = false
    AddLog("Todos os clones deletados!", "sucesso")
end

--[ Interface GUI ]--
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CloneFollowerGUI"
ScreenGui.Parent = Player:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 360, 0, 320)
MainFrame.Position = UDim2.new(0.5, -180, 0.5, -160)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 15)

local Title = Instance.new("TextLabel")
Title.Text = "👤 Clone Follower v7 FIXED"
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
Title.TextColor3 = Color3.new(1, 1, 1)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.Parent = MainFrame
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 15)

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Text = "—"
MinimizeBtn.Size = UDim2.new(0, 30, 0, 25)
MinimizeBtn.Position = UDim2.new(1, -40, 0, 8)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
MinimizeBtn.TextColor3 = Color3.new(1, 1, 1)
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 14
MinimizeBtn.Parent = Title

local isMinimized = false
MinimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    MainFrame:TweenSize(
        isMinimized and UDim2.new(0, 360, 0, 45) or UDim2.new(0, 360, 0, 320),
        "Out", "Quad", 0.3
    )
    MinimizeBtn.Text = isMinimized and "+" or "—"
end)

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -20, 1, -50)
Content.Position = UDim2.new(0, 10, 0, 45)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

local AddBtn = Instance.new("TextButton")
AddBtn.Text = "+"
AddBtn.Size = UDim2.new(0, 45, 0, 40)
AddBtn.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
AddBtn.TextColor3 = Color3.new(1, 1, 1)
AddBtn.Font = Enum.Font.GothamBold
AddBtn.TextSize = 20
AddBtn.Parent = Content
Instance.new("UICorner", AddBtn).CornerRadius = UDim.new(0, 8)
AddBtn.MouseButton1Click:Connect(CreateClone)

local CreateBtn = Instance.new("TextButton")
CreateBtn.Text = "🎭 CRIAR CLONE"
CreateBtn.Size = UDim2.new(1, -55, 0, 40)
CreateBtn.Position = UDim2.new(0, 50, 0, 0)
CreateBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 255)
CreateBtn.TextColor3 = Color3.new(1, 1, 1)
CreateBtn.Font = Enum.Font.GothamBold
CreateBtn.TextSize = 14
CreateBtn.Parent = Content
Instance.new("UICorner", CreateBtn).CornerRadius = UDim.new(0, 8)
CreateBtn.MouseButton1Click:Connect(CreateClone)

local DeleteBtn = Instance.new("TextButton")
DeleteBtn.Text = "🗑️ DELETAR"
DeleteBtn.Size = UDim2.new(0.48, 0, 0, 35)
DeleteBtn.Position = UDim2.new(0, 0, 0, 48)
DeleteBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
DeleteBtn.TextColor3 = Color3.new(1, 1, 1)
DeleteBtn.Font = Enum.Font.GothamBold
DeleteBtn.TextSize = 12
DeleteBtn.Parent = Content
Instance.new("UICorner", DeleteBtn).CornerRadius = UDim.new(0, 8)
DeleteBtn.MouseButton1Click:Connect(DeleteClone)

local DeleteAllBtn = Instance.new("TextButton")
DeleteAllBtn.Text = "🗑️ TODOS"
DeleteAllBtn.Size = UDim2.new(0.48, 0, 0, 35)
DeleteAllBtn.Position = UDim2.new(0.52, 0, 0, 48)
DeleteAllBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
DeleteAllBtn.TextColor3 = Color3.new(1, 1, 1)
DeleteAllBtn.Font = Enum.Font.GothamBold
DeleteAllBtn.TextSize = 12
DeleteAllBtn.Parent = Content
Instance.new("UICorner", DeleteAllBtn).CornerRadius = UDim.new(0, 8)
DeleteAllBtn.MouseButton1Click:Connect(DeleteAllClones)

local LogBtn = Instance.new("TextButton")
LogBtn.Text = "📋 VER LOGS"
LogBtn.Size = UDim2.new(1, 0, 0, 35)
LogBtn.Position = UDim2.new(0, 0, 0, 90)
LogBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 120)
LogBtn.TextColor3 = Color3.new(1, 1, 1)
LogBtn.Font = Enum.Font.GothamBold
LogBtn.TextSize = 13
LogBtn.Parent = Content
Instance.new("UICorner", LogBtn).CornerRadius = UDim.new(0, 8)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Text = "❌ Sem clone"
StatusLabel.Size = UDim2.new(1, 0, 0, 30)
StatusLabel.Position = UDim2.new(0, 0, 0, 135)
StatusLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
StatusLabel.TextColor3 = Color3.new(1, 0.3, 0.3)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 12
StatusLabel.Parent = Content
Instance.new("UICorner", StatusLabel).CornerRadius = UDim.new(0, 6)

local InfoLabel = Instance.new("TextLabel")
InfoLabel.Text = "📍 Dist: " .. Config.FollowDistance .. " | ⚡ Speed: " .. Config.FollowSpeed .. " | 👥: 0/" .. Config.MaxClones
InfoLabel.Size = UDim2.new(1, 0, 0, 25)
InfoLabel.Position = UDim2.new(0, 0, 0, 175)
InfoLabel.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
InfoLabel.TextColor3 = Color3.new(0.6, 0.6, 0.6)
InfoLabel.Font = Enum.Font.Gotham
InfoLabel.TextSize = 10
InfoLabel.Parent = Content

--[ TELA DE LOGS ]--
local LogGui = Instance.new("ScreenGui")
LogGui.Name = "LogGui"
LogGui.Parent = Player:WaitForChild("PlayerGui")

gameLogFrame = Instance.new("Frame")
gameLogFrame.Name = "LogFrame"
gameLogFrame.Size = UDim2.new(0, 450, 0, 300)
gameLogFrame.Position = UDim2.new(0.5, -225, 0.5, -150)
gameLogFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
gameLogFrame.BorderSizePixel = 0
gameLogFrame.Active = true
gameLogFrame.Draggable = true
gameLogFrame.Visible = false
gameLogFrame.Parent = LogGui
Instance.new("UICorner", gameLogFrame).CornerRadius = UDim.new(0, 12)

local LogTitle = Instance.new("TextLabel")
LogTitle.Text = "📜 LOGS DO SCRIPT"
LogTitle.Size = UDim2.new(1, 0, 0, 35)
LogTitle.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
LogTitle.TextColor3 = Color3.new(1, 1, 1)
LogTitle.Font = Enum.Font.GothamBold
LogTitle.TextSize = 14
LogTitle.Parent = gameLogFrame
Instance.new("UICorner", LogTitle).CornerRadius = UDim.new(0, 12)

local CloseLogBtn = Instance.new("TextButton")
CloseLogBtn.Text = "✕"
CloseLogBtn.Size = UDim2.new(0, 25, 0, 25)
CloseLogBtn.Position = UDim2.new(1, -35, 0, 5)
CloseLogBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
CloseLogBtn.TextColor3 = Color3.new(1, 1, 1)
CloseLogBtn.Font = Enum.Font.GothamBold
CloseLogBtn.TextSize = 12
CloseLogBtn.Parent = LogTitle
CloseLogBtn.MouseButton1Click:Connect(function()
    gameLogFrame.Visible = false
end)

local LogScroll = Instance.new("ScrollingFrame")
LogScroll.Size = UDim2.new(1, -20, 1, -80)
LogScroll.Position = UDim2.new(0, 10, 0, 45)
LogScroll.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
LogScroll.BorderSizePixel = 0
LogScroll.ScrollBarThickness = 5
LogScroll.Parent = gameLogFrame

LogText = Instance.new("TextLabel")
LogText.Size = UDim2.new(1, 0, 0, 0)
LogText.BackgroundTransparency = 1
LogText.TextColor3 = Color3.new(0.8, 0.8, 0.8)
LogText.Font = Enum.Font.Code
LogText.TextSize = 11
LogText.TextXAlignment = Enum.TextXAlignment.Left
LogText.TextYAlignment = Enum.TextYAlignment.Top
LogText.AutomaticSize = Enum.AutomaticSize.Y
LogText.Parent = LogScroll

local CopyBtn = Instance.new("TextButton")
CopyBtn.Text = "📋 COPIAR LOGS"
CopyBtn.Size = UDim2.new(1, -20, 0, 30)
CopyBtn.Position = UDim2.new(0, 10, 1, -35)
CopyBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 80)
CopyBtn.TextColor3 = Color3.new(1, 1, 1)
CopyBtn.Font = Enum.Font.GothamBold
CopyBtn.TextSize = 12
CopyBtn.Parent = gameLogFrame
Instance.new("UICorner", CopyBtn).CornerRadius = UDim.new(0, 6)
CopyBtn.MouseButton1Click:Connect(function()
    setclipboard(table.concat(Logs, "\n"))
    AddLog("Logs copiados!", "sucesso")
end)

LogBtn.MouseButton1Click:Connect(function()
    gameLogFrame.Visible = true
    UpdateLogDisplay()
end)

--[ Loop de Status ]--
task.spawn(function()
    while true do
        pcall(function()
            local c = #Clones
            if c > 0 and Following then
                StatusLabel.Text = "✅ " .. c .. " clone(s) te seguindo!"
                StatusLabel.TextColor3 = Color3.new(0.3, 1, 0.3)
            elseif c > 0 then
                StatusLabel.Text = "⚠️ " .. c .. " clone(s) criado(s)"
                StatusLabel.TextColor3 = Color3.new(1, 1, 0)
            else
                StatusLabel.Text = "❌ Sem clone"
                StatusLabel.TextColor3 = Color3.new(1, 0.3, 0.3)
            end
            InfoLabel.Text = "📍 Dist: " .. Config.FollowDistance .. " | ⚡ Speed: " .. Config.FollowSpeed .. " | 👥: " .. c .. "/" .. Config.MaxClones
        end)
        task.wait(0.5)
    end
end)

AddLog("Clone Follower v7 FIXED iniciado!", "sucesso")
AddLog("Movimento direto ativo - sem dependência PathFinding", "info")
AddLog("Clique em + para adicionar clones!", "info")
