--!strict

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--
export type AcceptableState = number | string | boolean 

local Settings = {
	RemoteEventsContainer = ReplicatedStorage
}

local HasRequestedInitData = false


--

local Util = {} do
	function Util.GetRemoteEvent(Name:string):RemoteEvent
	   if RunService:IsClient() then
			return Settings.RemoteEventsContainer:WaitForChild(Name)
		end 
		local Remote = Instance.new("RemoteEvent")
		Remote.Name = Name
		Remote.Parent = Settings.RemoteEventsContainer
		return Remote
	end
end

--
local StatesRemote = Util.GetRemoteEvent("States")

--

local module = {
} -- shared functions
local server = {} -- server functions
local client = {
} -- client functions


-- SHARED
module._States = {} :: {
	[Instance]: {
		[string]: {
			start: number,
			duration: number
		} | string | boolean
	}
}
module._objDestroying = {} :: {
	[Instance]: RBXScriptConnection
}
module._listeners = {} :: {
	[string]: {
		Callback:(Instance, AcceptableState | nil) -> nil,
	}
}
module._steplisteners = {} :: {
	[string]: {
		Callback:(number, Instance, AcceptableState | nil) -> nil,
	}
}

-- functions

local function DestroyingListener(Instance)
	-- add destroy listener
	if module._objDestroying[Instance] == nil then
		module._objDestroying[Instance] = Instance.AncestryChanged:Connect(function(_Obj, Parent)
			if Parent == nil then
				module._States[Instance] = nil
				module._objDestroying[Instance]:Disconnect()
				module._objDestroying[Instance] = nil
			end
		end)
	end
end

-- main

local function MainHeartbeat(d)
	local nowTime = workspace:GetServerTimeNow()

	for instance, tbl in pairs(module._States) do
		for state, value in pairs(tbl) do

			if typeof(value) == 'table'  then
				if value.start + value.duration < nowTime then
					if module._listeners[state] ~= nil then
						for _, listener in pairs(module._listeners[state]) do
							task.defer(listener, instance)
						end
					end
	
					tbl[state] = nil
				else
					-- fire stepped functions
					if module._steplisteners[state] ~= nil then
						for _, listener in pairs(module._steplisteners[state]) do
							task.defer(listener, d, instance, value.duration)
						end
					end
				end
			elseif typeof(value) == 'boolean' or typeof(value) == 'string'  then
				if module._steplisteners[state] ~= nil then
					for _, listener in pairs(module._steplisteners[state]) do
						task.defer(listener, d, instance, value)
					end
				end
			end
		end
	end
end

-- SHARED FUNCTIONS

function module.HasState(Obj:Instance, State:string)
	assert(Obj ~= module, "Cannot check state on self")
	assert(typeof(Obj) == "Instance", "Object must be an Instance")
	assert(typeof(State) == "string", "State must be a stringf")
	
	local ServerTimeNow  = workspace:GetServerTimeNow()

	if module._States[Obj] == nil or not module._States[Obj][State] then
		return false
	end

	local CurrentState = module._States[Obj][State]


	if typeof(CurrentState) == 'table' then
		return ServerTimeNow <  CurrentState.start + CurrentState.duration 
	elseif typeof(CurrentState) == 'boolean' then
		return CurrentState
	elseif typeof(CurrentState) == 'string' then
		return true		
	end
	print('BRUUUUUUUUUUUUH IGNOREEEEEEEED')
	return false
end

function module.AddListener(State:string, Callback:(Instance, number) -> nil)
	assert(typeof(State) == "string", "State must be a string or passed self")
	assert(typeof(Callback) == "function", "Callback must be a function")

	if module._listeners[State] == nil then
		module._listeners[State] = {}
	end

	table.insert(module._listeners[State], Callback)

	return function ()
		-- disconnect
		local found = table.find(module._listeners[State], Callback)

		if found then
			table.remove(module._listeners[State], found)
		end
	end
end

function module.AddListenerStepped(State:string, Callback:(Instance, number) -> nil)
	assert(typeof(State) == "string", "State must be a string or passed self")
	assert(typeof(Callback) == "function", "Callback must be a function")

	if module._steplisteners[State] == nil then
		module._steplisteners[State] = {}
	end

	table.insert(module._steplisteners[State], Callback)

	return function ()
		-- disconnect
		local found = table.find(module._steplisteners[State], Callback)

		if found then
			table.remove(module._steplisteners[State], found)
		end
	end
end

-- SERVER FUNCTIONS

function server.AddState(Ins:Instance | {Instance}, State:string, value: AcceptableState)
	assert(typeof(Ins) == "Instance" or typeof(Ins) == "table", "Instance or array expected")
	assert(((typeof(Ins) == "table" and Ins ~= module) or typeof(Ins) == 'Instance'), "Cannot pass self as argument")

	assert(typeof(State) == "string", "string expected")

	if typeof(value) == 'number' then
		assert(value > 0, "value must be greater than 0")
	elseif not typeof(value) == 'string' then
		return error("value must be a number or string")
	end
	
	local function apply(obj:Instance)
		if module._States[obj] == nil then
			module._States[obj] = {}
		end
	
		local appliedState = if typeof(value) == 'number' then
			{
				start = workspace:GetServerTimeNow(),
				duration = value
			}
		else
			value

		module._States[obj][State] =  appliedState
		
		if obj:IsA("Player") then
			StatesRemote:FireClient(obj, obj, State, appliedState)
		else
			StatesRemote:FireAllClients(obj, State, appliedState)
		end

		DestroyingListener(obj)
	end

	if typeof(Ins) == "table" then
		for _, obj in pairs(Ins) do
			apply(obj)
		end
	else
		apply(Ins)
	end
	

	-- fire listeners
	if module._listeners[State] then
		for _, listener in pairs(module._listeners[State]) do
			task.defer(listener, Ins, value)
		end
	end
end

function server.RemoveState(Ins:Instance, State:string)
	assert(typeof(Ins) == "Instance", "Instance expected")
	assert(typeof(State) == "string", "string expected")


	if module._States[Ins] == nil then
		return
	end
	module._States[Ins][State] = nil

	if Ins:IsA("Player") then
		StatesRemote:FireClient(Ins :: Player, Ins, State) 
	else
		StatesRemote:FireAllClients(Ins, State)
	end

	-- fire srversided listeners
	if module._listeners[State] then
		for _, listener in pairs(module._listeners[State]) do
			task.defer(listener, Ins)
		end
	end
end


-- CLIENT FUNCTIONS

function module.RequestData()
	if not HasRequestedInitData then
		HasRequestedInitData = true
		StatesRemote:FireServer()
	end
end

--

if RunService:IsServer() then
	module = setmetatable(module, {__index = server})

	local hasRequested:{[Player]: boolean?} = {}

	StatesRemote.OnServerEvent:Connect(function(player)
		-- request states
		if hasRequested[player] == nil then
			hasRequested[player] = true
			for ins, states in pairs(module._States) do

				if (ins:IsA("Player") and ins == player) or not ins:IsA("Player") then
					for state, value in pairs(states) do
						StatesRemote:FireClient(player, ins, state, value)
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(Player)
		hasRequested[Player] = nil
	end)
else
	module = setmetatable(module, {__index = client})

	StatesRemote.OnClientEvent:Connect(function(Inst:Instance, State:string, value: {start: number, duration: number} | string | nil )
		if Inst ~= nil then
			if module._States[Inst] == nil then
				module._States[Inst] = {}
			end

			if value == nil  then
				module._States[Inst][State] = nil
			else
				module._States[Inst][State] = value
			end
			
			-- fire client sided listeners
		
			if module._listeners[State] then
				for _, Callback in pairs(module._listeners[State]) do
					local val = 
						if value ~= nil then 
							if typeof(value) == "table" then 
									value.duration 
								else 
									value 
							else 
								nil 

					task.defer(Callback, Inst, val )
				end
			end

			-- destroy listener
			DestroyingListener(Inst)
		end
	end)
end

export type ServerStateHandler = {
	AddState:(Instance, string, number | string | boolean) -> nil,
	RemoveState:(Instance, string) -> nil,
	HasState:(Instance, string) -> boolean,
	AddListener:(string, (Instance, number?) -> nil) -> nil,
	AddListenerStepped:(string, (number, Instance, number) -> nil) -> nil,
}

export type ClientStateHandler = {
	HasState: (Instance, string) -> boolean,
	AddListener: (string, (Instance, number?) -> nil) -> nil,
	AddListenerStepped:(string, (number, Instance, number) -> nil) -> nil,

	RequestData: () -> nil,
}

-- init

local exportedModule = {}

function exportedModule.GetServer()
	return module :: ServerStateHandler
end

function exportedModule.GetClient()
	return module :: ClientStateHandler
end

RunService.Heartbeat:Connect(MainHeartbeat)

return exportedModule