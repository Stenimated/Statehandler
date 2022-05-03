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
			return Settings.RemoteEventsContainer:WaitForChild(Name) :: RemoteEvent
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
			value: AcceptableState | {start:number, duration:number},
			extraArguments: {[any]: any}
		}
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
	if not module._objDestroying[Instance] then

		module._objDestroying[Instance] = Instance.AncestryChanged:Connect(function()
			if not Instance.Parent then
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

			local val = value.value

			if typeof(val) == 'table'  then
				if val.duration + val.start  < nowTime then
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
							task.defer(listener, d, instance, val.duration)
						end
					end
				end
			elseif typeof(val) == 'boolean' or typeof(val) == 'string'  then
				if module._steplisteners[state] ~= nil then
					for _, listener in pairs(module._steplisteners[state]) do
						task.defer(listener, d, instance, val)
					end
				end
			end
		end
	end
end

-- SHARED FUNCTIONS

function module.HasState(Obj:Instance, State:string)
	assert(typeof(Obj) == "Instance", "Object must be an Instance")
	assert(typeof(State) == "string", "State must be a stringf")
	
	local ServerTimeNow  = workspace:GetServerTimeNow()

	if module._States[Obj] == nil or not module._States[Obj][State] then
		return false
	end

	local CurrentState = module._States[Obj][State]

	local value = CurrentState.value

	if typeof(value) == 'table' then
		return ServerTimeNow <  value.start + value.duration 
	elseif typeof(value) == 'boolean' then
		return value
	elseif typeof(value) == 'string' then
		return true		
	end
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

function server.AddState(Ins:Instance | {Instance}, State:string, value: AcceptableState, ...)
	assert(typeof(Ins) == "Instance" or typeof(Ins) == "table", "Instance or array expected")
	assert(((typeof(Ins) == "table" and Ins ~= module) or typeof(Ins) == 'Instance'), "Cannot pass self as argument")

	assert(typeof(State) == "string", "string expected")

	if typeof(value) == 'number' then
		assert(value > 0, "value must be greater than 0")
	elseif not typeof(value) == 'string' then
		return error("value must be a number or string")
	end
	local args = {...}
	
	local function apply(obj:Instance)
		if module._States[obj] == nil then
			module._States[obj] = {}
		end
	
		local StateProps = {
			value = if typeof(value) == 'number' then {start = workspace:GetServerTimeNow(), duration =  value} else value,
			extraArguments = args,
		}

		print(StateProps)
	
		module._States[obj][State] =  StateProps
		
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
			task.defer(listener, Ins, value, ...)
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
		StatesRemote:FireClient(Ins :: Player, {
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

	Players.PlayerRemoving:Connect(function(Player)
		hasRequested[Player] = nil
	end)
else
	module = setmetatable(module, {__index = client})

	type StateInfo = {
		remove: boolean?,
		obj: Instance,
		state: string,
		props: {
			value: AcceptableState | {start:number, duration:number},
			extraArguments: {[any]: any}
		}
	}

	StatesRemote.OnClientEvent:Connect(function(stateInfo:StateInfo)
		local obj = stateInfo.obj
		local state = stateInfo.state
		local props = stateInfo.props
		local remove = stateInfo.remove	

		if obj then
			if module._States[obj] == nil then
				module._States[obj] = {}
			end

			if remove then
				module._States[obj][state] = nil
			else
				module._States[obj][state] = props :: {
					value: AcceptableState | {start:number, duration:number},
					extraArguments: {[any]: any}
				}
			end
			
			-- fire client sided listeners
		
			if module._listeners[state] then
				for _, Callback in pairs(module._listeners[state]) do

					local val = 
						if props ~= nil then 
							if typeof(props.value) == "table" then 
									props.value.duration
								else 
									props.value
							else 
								nil 
				
					
					if props then
						task.defer(Callback, obj, val, table.unpack(props.extraArguments))
					else
						task.defer(Callback, obj, val)
					end
				end
			end

			-- destroy listener
			DestroyingListener(obj)
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