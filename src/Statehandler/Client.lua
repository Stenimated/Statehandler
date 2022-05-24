
local BaseClass = require(script.Parent.BaseClass)
local Types = require(script.Parent.Types)
local Util = require(script.Parent.Util)

--
local StatesRemote = Util.GetRemoteEvent("States")

--

type StateInfo = {
    remove: boolean?,
    obj: Instance,
    state: string,
    props: {
        value: Types.AcceptableState | {start:number, duration:number},
        extraArguments: {[any]: any}
    }
}

--

local export = function(): Client
     local self = BaseClass.new() :: BaseClass.Class
    
    --

	local hasRequested = false

    StatesRemote.OnClientEvent:Connect(function(stateInfo:StateInfo)
		if hasRequested == false then
			return print("Returned bitch")
		end
		
		local obj = stateInfo.obj
		local state = stateInfo.state
		local props = stateInfo.props
		local remove = stateInfo.remove	

		if obj then
			if self.States[obj] == nil then
				self.States[obj] = {}
			end

			if remove == true then
				self.States[obj][state] = nil
			else
				self.States[obj][state] = props :: {
					value: Types.AcceptableState | {start:number, duration:number},
					extraArguments: {[any]: any}
				}
			end

			print(stateInfo)
			
			-- fire client sided listeners
		
			if self.Listeners.Normal[state] then
				for _, Callback in pairs(self.Listeners.Normal[state]) do

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
		end
	end)

    --

	self.RequestData = function()
		hasRequested = true
		StatesRemote:FireServer()
	end

    return self
end

export type Client = {
	RequestData: () -> nil,
} & BaseClass.Class

return export