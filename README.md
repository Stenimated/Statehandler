# Statehandler

## Documentation

```lua
Fetching module

-- SERVER
local StateHandler = require(path.to.StateHandler).GetServer()

-- CLIENT
local StateHandler = require(path.to.StateHandler).GetClient()
```

Shared Syntax:

```lua

Statehandler.HasState(Instance: Instance, State: string) -> boolean

-- Called whenever state is added (Duration is present) and whenever it is removed (Duration is nil)
StateHandler.AddListener(State:string, Callback: (Instance: Instance, Duration:number?) -> nil)

-- Fires each heartbeat while state is active
StateHandler.AddListenerStepped(State:string, Callback: (DeltaTime:number, Instance: Instance, Duration:number) -> nil)

```

Server

```lua

-- add state for a duration
-- duration can also be math.huge to replicate a boolean state
--[[
    if first argument is a player or an array with players it'll only fire State info" for those player(s)
        State will be hidden to other players
    
    These cannot stack states, only overwrite
]]
StateHandler.AddState(Instance: Instance | {Instance} | Player | {Player}, State: string, Duration: number)

-- remove state 
StateHandler.RemoveState(Instance: Instance, State: string, Duration: number)

```

Client

```lua

StateHandler.RequestData() -> nil
-- Request server with data, should be called only once

```

### Examples

Poison Example

```lua
-- SERVER
local Players = game:GetService("Players")

local Statehandler = require(path.to.StateHandler).GetServer()

Statehandler.AddListenerStepped("Poison", function(dt, Player:Player, duration)
    if Player and Player.Character and Player.Character:FindFirstChild("Humanoid") then
        -- use delta time to consitently apply poison
        Player.Character.Humanoid.Health -= (5 * dt)
    end
end)

Players.PlayerAdded:Connect(function(Player)
 Player.CharacterAdded:Connect(function(char)
        -- Poison is active for 5 seconds
        Statehandler.AddState(Player, "Poison", 5)
    end)
end)

```

CLIENT

```lua
local Statehandler = require(game.ReplicatedStorage.Statehandler).GetClient()

Statehandler.AddListener('Poison', function(Instance:Player, number)
    if number then
        print("Is Active")
    else
        print("Is not active")
    end
end)

Statehandler.RequestData()
```
