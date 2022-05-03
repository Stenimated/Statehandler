local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateHandler = require(ReplicatedStorage.Statehandler).GetServer()



local TestRemote = ReplicatedStorage.Test

--

local function RunTests(player:Player)
    print("[SERVER]: Running tests")
    -- run tests

    local SHOULDPASS = {
        "Test-Number",
        "Test-String",
        "Test-Boolean",
        "Test-Number-ExtraArgument",
        "Test-String-ExtraArgument",
        "Test-Boolean-ExtraArgument",
    }
    
    local PASSED = {} :: {
        [string]: {
            stepped: boolean,
            event: boolean
        }
    }
    
    --
    
    for _, name in ipairs(SHOULDPASS) do
        PASSED[name] = {
            stepped = false,
            event = false,
            has = false
        }
    end
    
    --

    StateHandler.AddListener("Test-Number", function(instance, state)
        PASSED["Test-Number"].event = true
    end)
    StateHandler.AddListenerStepped("Test-Number", function(instance, state)
        PASSED["Test-Number"].stepped = true
    end)
    
    StateHandler.AddListener("Test-String", function(instance, state)
        PASSED["Test-String"].event = true
    end)
    StateHandler.AddListenerStepped("Test-String", function(instance, state)
        PASSED["Test-String"].stepped = true
    end)
    
    StateHandler.AddListener("Test-Boolean", function(instance, state)
        PASSED["Test-Boolean"].event = true
    end)
    StateHandler.AddListenerStepped("Test-Boolean", function(instance, state)
        PASSED["Test-Boolean"].stepped = true
    end)
    
    -- extra arguments
    
    StateHandler.AddListener("Test-Number-ExtraArgument", function(instance, state)
        PASSED["Test-Number-ExtraArgument"].event = true
    end)
    StateHandler.AddListenerStepped("Test-Number-ExtraArgument", function(instance, state)
        PASSED["Test-Number-ExtraArgument"].stepped = true
    end)
    
    StateHandler.AddListener("Test-String-ExtraArgument", function(instance, state)
        PASSED["Test-String-ExtraArgument"].event = true
    end)
    StateHandler.AddListenerStepped("Test-String-ExtraArgument", function(instance, state)
        PASSED["Test-String-ExtraArgument"].stepped = true
    end)
    
    StateHandler.AddListener("Test-Boolean-ExtraArgument", function(instance, state)
        PASSED["Test-Boolean-ExtraArgument"].event = true
    end)
    StateHandler.AddListenerStepped("Test-Boolean-ExtraArgument", function(instance, state)
        PASSED["Test-Boolean-ExtraArgument"].stepped = true
    end)

    --

    StateHandler.AddState(player, "Test-Number", 5)
    StateHandler.AddState(player, "Test-String", "Test")
    StateHandler.AddState(player, "Test-Boolean", true)
    StateHandler.AddState(player, "Test-Number-ExtraArgument", 5, {Test = true})
    StateHandler.AddState(player, "Test-String-ExtraArgument", "Test", {2, 3})
    StateHandler.AddState(player, "Test-Boolean-ExtraArgument", true, {1, 2, 3})
    

    if StateHandler.HasState(player, "Test-Number") then
        PASSED["Test-Number"].has = true
    end
    if StateHandler.HasState(player, "Test-String") then
        PASSED["Test-String"].has = true
    end
    if StateHandler.HasState(player, "Test-Boolean") then
        PASSED["Test-Boolean"].has = true
    end
    if StateHandler.HasState(player, "Test-Number-ExtraArgument") then
        PASSED["Test-Number-ExtraArgument"].has = true
    end
    if StateHandler.HasState(player, "Test-String-ExtraArgument") then
        PASSED["Test-String-ExtraArgument"].has = true
    end
    if StateHandler.HasState(player, "Test-Boolean-ExtraArgument") then
        PASSED["Test-Boolean-ExtraArgument"].has = true
    end


    task.wait(3)

    TestRemote:FireClient(player, "TestDone")

    for _, name in ipairs(SHOULDPASS) do
        if not PASSED[name].event then
            error("[SERVER]: Event for " .. name .. " was not called")
        end
        if not PASSED[name].stepped then
            error("[SERVER]: Stepped for " .. name .. " was not called")
        end
    end
    print("[SERVER]: All tests passed")
end

--

TestRemote.OnServerEvent:Connect(function(player, state:string)

    if state == "RUN" then
        RunTests(player)
    end
end)