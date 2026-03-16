-- Simplified Trolagem do clone.lua

local Players = game:GetService("Players")
local character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()

-- Function to spawn the clone
local function spawnClone()
    local clone = character:Clone()
    clone.Parent = workspace
    clone:SetPrimaryPartCFrame(character.PrimaryPart.CFrame + Vector3.new(5, 0, 0)) -- Move clone 5 studs away
    return clone
end

-- Function to handle errors and provide feedback
local function safeExecute(func)
    local success, err = pcall(func)
    if not success then
        warn("Error occurred: " .. err)
    end
end

-- Bind the function to a key (e.g., "E")
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gameProcessedState)
    if not gameProcessedState then
        if input.KeyCode == Enum.KeyCode.E then
            safeExecute(spawnClone)
        end
    end
end)