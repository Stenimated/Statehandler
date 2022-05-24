local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Settings = {
	RemoteEventsContainer = ReplicatedStorage
}

--

local Util = {}

function Util.GetRemoteEvent(Name:string):RemoteEvent
    if RunService:IsClient() then
         return Settings.RemoteEventsContainer:WaitForChild(Name) :: RemoteEvent
     end 
     local Remote = Instance.new("RemoteEvent")
     Remote.Name = Name
     Remote.Parent = Settings.RemoteEventsContainer
     return Remote
 end

return Util