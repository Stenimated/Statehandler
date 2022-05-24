
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local StateHandler = require(ReplicatedStorage.Statehandler).Get()

task.wait(3)

StateHandler:AddListener("tEST", function(...)
    print(...)
end)


--
print("a")
StateHandler.RequestData()