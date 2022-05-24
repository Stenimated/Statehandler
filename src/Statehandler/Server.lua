--!strict
local Players = game:GetService("Players")

local BaseClass = require(script.Parent.BaseClass)
local Util = require(script.Parent.Util)

--
local StatesRemote = Util.GetRemoteEvent("States")

--

export type AcceptableState = number | string | boolean 



--

local prototype = {}

-- SERVER FUNCTIONS

function prototype:AddDestroyingListener(Target:Instance, OnDestroyObject:Instance)
	self = self :: Server

	local connection; connection = OnDestroyObject.Destroying:Connect(function()

		if self.States[Target] then
			for name in pairs(self.States[Target]) do
				self:RemoveState(Target, name)	
			end

			self.States[Target] = nil
		end


		connection:Disconnect()
	end)
end

function prototype:AddState(Ins:Instance | {Instance}, State:string, value: AcceptableState, ...)
    self = self :: Server

	if typeof(value) == 'number' then
		assert(value > 0, "value must be greater than 0")
	elseif not typeof(value) == 'string' then
		error("value must be a number or string")
		return 
	end
	local args = {...}
	
	local function apply(obj:Instance)
		self.States[obj] = self.States[obj] or {}
	
		local StateProps = {
			value = if typeof(value) == 'number' then 
				{start = workspace:GetServerTimeNow(), duration =  value} 
			else
				 value,
				 
			extraArguments = args,
		}
	
		self.States[obj][State] =  StateProps
		
		if obj:IsA("Player") then
			StatesRemote:FireClient(obj, {
				obj = obj,
				state = State,
				props = StateProps
			})
		else
			StatesRemote:FireAllClients({
				obj = obj,
				state = State,
				props = StateProps
			})
		end

		self:AddDestroyingListener(obj, obj)
	end

	if typeof(Ins) == "table" then
		for _, obj in pairs(Ins) do
			apply(obj)
		end
	else
		apply(Ins)
	end
	

	-- fire listeners
	if self.Listeners.Normal[State] then
		for _, listener in pairs(self.Listeners.Normal[State]) do
			task.defer(listener, Ins, value, ...)
		end
	end

	return self
end

function prototype:RemoveState(Ins:Instance, State:string)
    self = self :: Server


	assert(typeof(Ins) == "Instance", "Instance expected")
	assert(typeof(State) == "string", "string expected")


	if self.States[Ins] == nil or self.States[Ins][State] == nil then
		return
	end
	self.States[Ins][State] = nil

	if Ins:IsA("Player") then
		StatesRemote:FireClient(Ins :: Player, {
			obj = Ins,
			remove = true,
			state = State
		}) 
	else
		StatesRemote:FireAllClients({
			obj = Ins,
			remove = true,
			state = State
		})
	end

	-- fire srversided listeners
	if self.Listeners.Normal[State] then
		for _, listener in pairs(self.Listeners.Normal[State]) do
			task.defer(listener, Ins)
		end
	end
end


--

local export = function(): Server
    local self = BaseClass.new()
	
    --

	local requestData = {} :: {[Player]: boolean}

    StatesRemote.OnServerEvent:Connect(function(player:Player)
		-- request states
		if requestData[player] == nil then
			requestData[player] = true
			for ins, states in pairs(self.States) do

				if (ins:IsA("Player") and ins == player) or not ins:IsA("Player") then
					for state, value in pairs(states) do
						
						StatesRemote:FireAllClients({
							obj = ins,
							state = state,
							props = value
						})
					end
				end
			end
		end
    end)

	--

	Players.PlayerRemoving:Connect(function(Player:Player)
		requestData[Player] = nil
	end)

    --

	for i, v in pairs(prototype) do
		self[i] = v
	end

    return self 
end


export type Server = {
	AddState: (Instance | {Instance}, string, AcceptableState, ...any) -> nil,
	RemoveState: (Instance, string) -> nil,
	AddDestroyingListener: (Instance, Instance) -> nil,
} & BaseClass.Class



return export