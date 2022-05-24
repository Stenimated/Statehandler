local RunService = game:GetService("RunService")

local Types = require(script.Parent.Types)


--

local module = {}
module.prototype = {}

--

function module.prototype:HasState(Obj:Instance, State:string)
	self = self :: Class

	assert(typeof(Obj) == "Instance", "Object must be an Instance")
	assert(typeof(State) == "string", "State must be a stringf")
	
	local ServerTimeNow  = workspace:GetServerTimeNow()

	if self.States[Obj] == nil or not self.States[Obj][State] then
		return false
	end

	local CurrentState = self.States[Obj][State]

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

function module.prototype:AddListener(State:string, Callback:(Instance, number) -> nil)
	self = self :: Class

	assert(typeof(State) == "string", "State must be a string or passed self")
	assert(typeof(Callback) == "function", "Callback must be a function")

	if self.Listeners.Normal[State] == nil then
		self.Listeners.Normal[State] = {}
	end

	table.insert(self.Listeners.Normal[State], Callback)

	return function ()
		-- disconnect
		local found = table.find(self.Listeners.Normal[State], Callback)

		if found then
			table.remove(self.Listeners.Normal[State], found)
		end
	end
end

function module.prototype:AddListenerStepped(State:string, Callback:(Instance, number) -> nil)
	self = self :: Class


	assert(typeof(State) == "string", "State must be a string or passed self")
	assert(typeof(Callback) == "function", "Callback must be a function")

	if self.Listeners.Stepped[State] == nil then
		self.Listeners.Stepped[State] = {}
	end

	table.insert(self.Listeners.Stepped[State], Callback)

	return function ()
		-- disconnect
		local found = table.find(self.Listeners.Stepped[State], Callback)

		if found then
			table.remove(self.Listeners.Stepped[State], found)
		end
	end
end

--

function module.new(): Class
    local self = setmetatable({}, {__index = module.prototype})

    self.States = {} :: {
        [Instance]: {
            [string]: {
                value: Types.AcceptableState | {start:number, duration:number},
                extraArguments: {[any]: any}
            }
        }
    }
    self.Listeners = {
        Normal = {} :: {[string]: {
            Callback:(Instance, Types.AcceptableState | nil) -> nil,
        }} | {},
        Stepped = {} :: {[string]: {
            Callback:(number, Instance, Types.AcceptableState | nil) -> nil,
        }} | {}
    }

    RunService.Heartbeat:Connect(function(dt:number)
        local nowTime = workspace:GetServerTimeNow()

        for instance, tbl in pairs(self.States) do
            for stateName, info in pairs(tbl) do
    
                local state = info.value


                if typeof(state) == 'table' then
                    if state.duration + state.start  < nowTime then
                        if self.Listeners.Normal[stateName] ~= nil then
                            for _, listener in pairs(self.Listeners.Normal[state]) do
                                task.defer(listener, instance)
                            end
                        end
						
					    tbl[state] = nil
                        continue
                    end

                    -- fire stepped functions
					if self.Listeners.Stepped[state] ~= nil then
						for _, listener in pairs(self.Listeners.Stepped[state]) do
							task.defer(listener, dt, instance, state.duration)
						end
					end

                elseif typeof(state) == 'boolean' or typeof(state) == 'string'  then
                    if self.Listeners.Stepped[state] ~= nil then
                        for _, listener in pairs(self.Listeners.Stepped[state]) do
                            task.defer(listener, dt, instance, state)
                        end
                    end
                end
            end
        end
    end)


    return self
end

export type Class = typeof(module.new())


return module