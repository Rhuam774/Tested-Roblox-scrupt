-- Script para clonar personagem e fazer clones seguirem
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

-- Configurações
local NUM_CLONES = 3 -- Número de clones que você quer
local FOLLOW_DISTANCE = 5 -- Distância que os clones ficam de você
local CIRCLE_RADIUS = 6 -- Raio do círculo ao seu redor
local FOLLOW_SPEED = 0.5 -- Velocidade de seguimento (0-1)

local clones = {}

-- Função para clonar o personagem
local function createClone()
    local newCharacter = character:Clone()
    newCharacter.Name = character.Name .. "_Clone"
    newCharacter.Parent = workspace
    
    -- Remove scripts perigosos do clone
    for _, script in pairs(newCharacter:GetDescendants()) do
        if script:IsA("LocalScript") or script:IsA("Script") then
            script:Destroy()
        end
    end
    
    -- Garante que o clone não interage com o jogador original
    local cloneHumanoidRootPart = newCharacter:WaitForChild("HumanoidRootPart")
    local cloneHumanoid = newCharacter:WaitForChild("Humanoid")
    
    table.insert(clones, {
        character = newCharacter,
        humanoidRootPart = cloneHumanoidRootPart,
        humanoid = cloneHumanoid,
        index = #clones + 1
    })
    
    return newCharacter
end

-- Cria os clones
for i = 1, NUM_CLONES do
    createClone()
    wait(0.1) -- Pequena pausa entre clones
end

-- Função para calcular posição ao redor do jogador
local function getCirclePosition(index, totalClones)
    local angle = (2 * math.pi * (index - 1)) / totalClones
    local offsetX = math.cos(angle) * CIRCLE_RADIUS
    local offsetZ = math.sin(angle) * CIRCLE_RADIUS
    
    return Vector3.new(offsetX, 0, offsetZ)
end

-- Loop para mover os clones
RunService.Stepped:Connect(function()
    if not humanoidRootPart or not humanoidRootPart.Parent then
        return
    end
    
    for _, cloneData in pairs(clones) do
        if cloneData.character and cloneData.character.Parent and cloneData.humanoidRootPart then
            local cloneHRP = cloneData.humanoidRootPart
            local cloneHumanoid = cloneData.humanoid
            
            -- Calcula a posição alvo (ao redor do jogador)
            local targetOffset = getCirclePosition(cloneData.index, #clones)
            local targetPosition = humanoidRootPart.Position + targetOffset + Vector3.new(0, 3, 0)
            
            -- Usa moveTo para fazer o clone seguir
            cloneHumanoid:MoveTo(targetPosition)
        end
    end
end)

-- Cleanup se o jogador morrer
player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    
    -- Remove clones antigos
    for _, cloneData in pairs(clones) do
        if cloneData.character and cloneData.character.Parent then
            cloneData.character:Destroy()
        end
    end
    
    clones = {}
    
    -- Recriar clones
    for i = 1, NUM_CLONES do
        createClone()
        wait(0.1)
    end
end)

print("Script de clones ativado! Você tem " .. NUM_CLONES .. " clones te seguindo.")
