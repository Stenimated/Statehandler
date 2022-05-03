local ReplicatedStorage = game:GetService("ReplicatedStorage")


local StateHandler = require(ReplicatedStorage.Statehandler).GetClient()

local TestRemote = ReplicatedStorage.Test

--

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
        event = false
    }
end


--

StateHandler.AddListener("Test", function(...)
    print(...)
end)

StateHandler.AddListener("Test-Number", function(instance, state)
    PASSED["Test-Number"].event = true
    print(state)
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


TestRemote.OnClientEvent:Connect(function(state:"TestDone")
    if state == "TestDone" then
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
end)

print("[CLIENT]: Running tests")
TestRemote:FireServer("RUN")