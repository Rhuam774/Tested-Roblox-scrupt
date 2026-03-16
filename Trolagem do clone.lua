-- Script para clonar personagem e fazer clones seguirem o jogador
-- Compatível com executor Delta

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- Configurações
local CLONE_COUNT = 5 -- Quantidade de clones (ajuste conforme necessário)
local FOLLOW_DISTANCE = 5 -- Distância que os clones mantêm do jogador
local FOLLOW_SPEED = 0.5 -- Velocidade de movimento dos clones (0.1 a 1.0)
local OFFSET_RADIUS = 3 -- Raio do círculo ao redor do jogador

local clones = {}
local cloneConnections = {}

-- Função para clonar o personagem
local function cloneCharacter()
    local newClone = character:Clone()
    newClone.Name = "Clone_" .. #clones + 1
    
    -- Remove scripts perigosos
    for _, script in pairs(newClone:GetDescendants()) do
        if script:IsA("Script") or script:IsA("LocalScript") then
            script:Destroy()
        end
    end
    
    -- Move o clone para perto do jogador
    newClone:MoveTo(humanoidRootPart.Position + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)))
    newClone.Parent = workspace
    
    table.insert(clones, newClone)
    return newClone
end

-- Função para fazer um clone seguir o jogador
local function makeCloneFollow(clone, index)
    local cloneHumanoidRootPart = clone:WaitForChild("HumanoidRootPart")
    local cloneHumanoid = clone:WaitForChild("Humanoid")
    
    -- Calcula ângulo para posicionar em círculo
    local angleStep = (2 * math.pi) / CLONE_COUNT
    local angle = angleStep * index
    
    -- Cria conexão para atualizar posição
    local connection = RunService.Heartbeat:Connect(function()
        if not clone.Parent or not character.Parent then
            connection:Disconnect()
            clone:Destroy()
            return
        end
        
        -- Calcula posição alvo em volta do jogador
        local offsetX = math.cos(angle) * OFFSET_RADIUS
        local offsetZ = math.sin(angle) * OFFSET_RADIUS
        local targetPos = humanoidRootPart.Position + Vector3.new(offsetX, 0, offsetZ)
        
        -- Move o clone para a posição alvo
        if cloneHumanoid.Health > 0 then
            cloneHumanoidRootPart.CanCollide = false -- Evita colisão com o jogador
            cloneHumanoidRootPart.CFrame = cloneHumanoidRootPart.CFrame:Lerp(
                CFrame.new(targetPos, humanoidRootPart.Position),
                FOLLOW_SPEED
            )
        end
    end)
    
    table.insert(cloneConnections, connection)
end

-- Cria os clones
print("Criando " .. CLONE_COUNT .. " clones...")
for i = 1, CLONE_COUNT do
    local clone = cloneCharacter()
    makeCloneFollow(clone, i)
    wait(0.1) -- Pequeno delay entre clones
end

print("✓ Script ativado! Você tem " .. CLONE_COUNT .. " clones seguindo você.")
print("Dica: Ajuste CLONE_COUNT, FOLLOW_DISTANCE e FOLLOW_SPEED no topo do script.")

-- Limpeza ao morrer
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    
    -- Destrói todos os clones
    for _, clone in pairs(clones) do
        clone:Destroy()
    end
    
    -- Desconecta todas as conexões
    for _, conn in pairs(cloneConnections) do
        conn:Disconnect()
    end
    
    clones = {}
    cloneConnections = {}
end)

-- Mantém o script rodando
while true do
    wait(1)
end
