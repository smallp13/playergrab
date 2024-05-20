local grabPlayer = {
    allowedWeapons = {
        `WEAPON_UNARMED`, -- Modify to unarmed as we're not using weapons for grabbing
    },
    InProgress = false,
    type = "",
    targetSrc = -1,
    agressor = {
        animDict = "amb@world_human_drinking@coffee@male@base",
        anim = "base",
        flag = 49,
    },
    grabbedPlayer = {
        animDict = "mp_arresting",
        anim = "idle", -- Change to the appropriate animation for grabbing
        attachX = 0.20,
        attachY = 0.45,
        attachZ = 0.0,
        flag = 32,
    }
}

local function drawNativeNotification(text)
    SetTextComponentFormat("STRING")
    AddTextComponentString(text)
    DisplayHelpTextFromStringLabel(0, 0, 1, -1)
end

local function GetClosestPlayer(radius)
    local players = GetActivePlayers()
    local closestDistance = -1
    local closestPlayer = -1
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    for _, playerId in ipairs(players) do
        local targetPed = GetPlayerPed(playerId)
        if targetPed ~= playerPed then
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(targetCoords - playerCoords)
            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = playerId
                closestDistance = distance
            end
        end
    end
    if closestDistance ~= -1 and closestDistance <= radius then
        return closestPlayer
    else
        return nil
    end
end

local function ensureAnimDict(animDict)
    if not HasAnimDictLoaded(animDict) then
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do
            Wait(0)
        end
    end
    return animDict
end

local function drawNativeText(str)
    SetTextEntry_2("STRING")
    AddTextComponentString(str)
    EndTextCommandPrint(1000, 1)
end

RegisterCommand("grabplayer", function()
    callGrabPlayer()
end)

RegisterCommand("gp", function()
    callGrabPlayer()
end)

function callGrabPlayer()
    ClearPedSecondaryTask(PlayerPedId())
    DetachEntity(PlayerPedId(), true, false)

    local canGrabPlayer = false
    for i = 1, #grabPlayer.allowedWeapons do
        if HasPedGotWeapon(PlayerPedId(), grabPlayer.allowedWeapons[i], false) then
            canGrabPlayer = true
            break
        end
    end

    if not canGrabPlayer then
        drawNativeNotification("You need to be unarmed to grab a player!")
        return
    end

    if not grabPlayer.InProgress and canGrabPlayer then
        local closestPlayer = GetClosestPlayer(3) -- Radius to search player
        if closestPlayer then
            local targetSrc = GetPlayerServerId(closestPlayer)
            if targetSrc ~= -1 then
                grabPlayer.InProgress = true
                grabPlayer.targetSrc = targetSrc
                TriggerServerEvent("GrabPlayer:sync", targetSrc)
                ensureAnimDict(grabPlayer.agressor.animDict)
                grabPlayer.type = "agressor"
            else
                drawNativeNotification("~r~No one nearby to grab!")
            end
        else
            drawNativeNotification("~r~No one nearby to grab!")
        end
    end
end


RegisterNetEvent("GrabPlayer:syncTarget")
AddEventHandler("GrabPlayer:syncTarget", function(target)
    grabPlayer.InProgress = true
    ensureAnimDict(grabPlayer.grabbedPlayer.animDict)
    AttachEntityToEntity(PlayerPedId(), GetPlayerPed(GetPlayerFromServerId(target)), 0, grabPlayer.grabbedPlayer.attachX, grabPlayer.grabbedPlayer.attachY, grabPlayer.grabbedPlayer.attachZ, 0.5, 0.5, 0.0, false, false, false, false, 2, false)
    grabPlayer.type = "grabbed"
    
end)

RegisterNetEvent("GrabPlayer:release")
AddEventHandler("GrabPlayer:release", function()
    grabPlayer.InProgress = false
    grabPlayer.type = ""
    DetachEntity(PlayerPedId(), true, false)
    ClearPedTasks(PlayerPedId())

    -- Example of TaskPlayAnim, replace "animDict" and "animName" with your desired animation
    local animDict = "mp_arresting"
    local animName = "idle"

    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Citizen.Wait(100)
    end

    TaskPlayAnim(PlayerPedId(), animDict, animName, 8.0, -8.0, -1, 49, 0, false, false, false)
end)


Citizen.CreateThread(function()
    while true do
        if grabPlayer.type == "agressor" then
            if not IsEntityPlayingAnim(PlayerPedId(), grabPlayer.agressor.animDict, grabPlayer.agressor.anim, 3) then
                TaskPlayAnim(PlayerPedId(), grabPlayer.agressor.animDict, grabPlayer.agressor.anim, 8.0, -8.0, 100000, grabPlayer.agressor.flag, 0, false, false, false)
            end
        elseif grabPlayer.type == "grabbed" then
            if not IsEntityPlayingAnim(PlayerPedId(), grabPlayer.grabbedPlayer.animDict, grabPlayer.grabbedPlayer.anim, 3) then
                TaskPlayAnim(PlayerPedId(), grabPlayer.grabbedPlayer.animDict, grabPlayer.grabbedPlayer.anim, 8.0, -8.0, 100000, grabPlayer.grabbedPlayer.flag, 0, false, false, false)
            end
        end
        Wait(0)
    end
end)

Citizen.CreateThread(function()
    while true do
        if grabPlayer.type == "agressor" then
            DisableControlAction(0, 24, true) -- disable attack
            DisableControlAction(0, 25, true) -- disable aim
            DisableControlAction(0, 47, true) -- disable weapon
            DisableControlAction(0, 58, true) -- disable weapon
            DisableControlAction(0, 21, true) -- disable sprint
            DisablePlayerFiring(PlayerPedId(), true)
            drawNativeText("Press [G] to release")

            if IsEntityDead(PlayerPedId()) then
                grabPlayer.type = ""
                grabPlayer.InProgress = false
                DetachEntity(PlayerPedId(), true, false)
                TriggerServerEvent("GrabPlayer:release", grabPlayer.targetSrc)
            end

            if IsDisabledControlJustPressed(0, 47) then -- release
                ClearPedTasks(PlayerPedId()) -- Clear pedestrian tasks here
                grabPlayer.type = ""
                grabPlayer.InProgress = false
                DetachEntity(PlayerPedId(), true, false)
                TriggerServerEvent("GrabPlayer:release", grabPlayer.targetSrc)
            end
        end
        Wait(0)
    end
end)


Citizen.CreateThread(function()
    while true do
        if grabPlayer.type == "grabbed" then
            DisableControlAction(0, 24, true) -- Attack
            DisableControlAction(0, 25, true) -- Aim
            DisableControlAction(0, 12, true) -- Weapon Wheel
            DisableControlAction(0, 14, true) -- Sprint
            DisableControlAction(0, 15, true) -- Jump
            DisableControlAction(0, 36, true) -- Duck
            DisableControlAction(0, 47, true) -- Weapon Drop
            DisableControlAction(0, 58, true) -- Weapon Wheel Next
            DisableControlAction(0, 140, true) -- Melee Attack 1
            DisableControlAction(0, 141, true) -- Melee Attack 2
            DisableControlAction(0, 142, true) -- Melee Attack 3
            DisableControlAction(0, 143, true) -- Melee Attack 4
            DisableControlAction(0, 263, true) -- Melee Attack 5
            DisableControlAction(0, 264, true) -- Melee Attack 6
            DisableControlAction(0, 257, true) -- Attack 2
            DisableControlAction(0, 22, true) -- Jump
            DisableControlAction(0, 75, true) -- Exit Vehicle
            DisableControlAction(27, 75, true) -- Exit Vehicle (Gamepad)
            DisableControlAction(0, 73, true) -- Enter Vehicle
            DisableControlAction(27, 73, true) -- Enter Vehicle (Gamepad)
        end
        Wait(0)
    end
end)
