
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local StateHandler = require(ReplicatedStorage.Statehandler).GetServer()

--
local function PlayerAdded(Player:Player)
    StateHandler:AddState(Player, 'tEST', 50, {
        huh_ye = 'huh',
    })
end

--


for _, Player in pairs(Players:GetPlayers()) do
    PlayerAdded(Player)
end
Players.PlayerAdded:Connect(PlayerAdded)