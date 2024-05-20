RegisterServerEvent("GrabPlayer:sync")
AddEventHandler("GrabPlayer:sync", function(target)
    -- Trigger an event on the target client to synchronize the grab
    TriggerClientEvent("GrabPlayer:syncTarget", target, source)
end)

RegisterServerEvent("GrabPlayer:release")
AddEventHandler("GrabPlayer:release", function(target)
    -- Trigger an event on the target client to release the grabbed player
    TriggerClientEvent("GrabPlayer:release", target)
end)
