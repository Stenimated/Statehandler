--!strict
local RunService = game:GetService("RunService")

local Server = require(script.Server)
local Client = require(script.Client)


local exportedModule = {}


function exportedModule.GetServer()
	return Server()
end

function exportedModule.GetClient()
	return Client()
end


export type Server = Server.Server
export type Client = Client.Client

return exportedModule