local MissionIndex, MissionAircraft, MissionBlip = nil, nil, nil
local passCount = 0
AircraftInfo = {}

function SetMissionBlip(coords, blipType)
    if MissionBlip ~= nil then
        RemoveBlip(MissionBlip)
        MissionBlip = nil
    end
    if coords then
        SetNewWaypoint(coords.x, coords.y)
        local info = Config.Missions.Blips[blipType]
        MissionBlip = CreateBlip({
            Location = coords,
            Label = info.Label,
            ID = info.ID,
            Scale = info.Scale,
            Color = info.Color
        })
    end
end

function DeliveryMission(mission, cb)
    local boxProp = nil

    local function Cleanup()
        SetMissionBlip()

        if boxProp then
            local ped = PlayerPedId()
            DeleteEntity(boxProp)
            ClearPedSecondaryTask(ped)
            boxProp = nil
        end
    end

    Citizen.CreateThread(function()
        local done = false

        ShowNotification(U.package_pickup_notify)
        SetMissionBlip(mission.PackagePickup, "PackagePickup")

        while not done do
            if (not DoesEntityExist(MissionAircraft) or GetEntityHealth(MissionAircraft) <= 0) then
                Cleanup()
                dprint("Mission Aircraft does not exist")
                cb(false)
                return
            end
            local wait = 1000
            local ped = PlayerPedId()
            local coords = mission.PackagePickup
            local pcoords = GetEntityCoords(ped)
            local dist = #(coords - pcoords)
            if (dist < 20) then
                wait = 0
                DrawMarker(2, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.25, 0.25, 0.25, 255, 255, 255, 127, false, true)
                if (dist < 1.25 and not ShowHelpNotification(U.package_pickup) and IsControlJustPressed(1, 51)) then
                    done = true
                    break
                end
            end
            Wait(wait)
        end

        if (not done) then
            Cleanup()
            dprint("not done")
            cb(false)
            return
        end
        done = false

        ShowNotification(U.package_dropoff_notify)
        SetMissionBlip(mission.PackageDropoff, "PackageDropoff")

        while not done do
            if (not DoesEntityExist(MissionAircraft) or GetEntityHealth(MissionAircraft) <= 0) then
                Cleanup()
                cb(false)
                return
            end

            local wait = 1000
            local ped = PlayerPedId()
            local coords = mission.PackageDropoff
            local pcoords = GetEntityCoords(ped)
            local acoords = GetEntityCoords(MissionAircraft)
            local dist = #(coords - pcoords)
            local adist = #(coords - acoords)
            local vehicle = GetVehiclePedIsIn(ped)
            if (vehicle ~= 0 and boxProp) then
                DeleteEntity(boxProp)
                ClearPedSecondaryTask(ped)
                boxProp = nil
            elseif (vehicle == 0) then
                if not IsEntityPlayingAnim(ped, "anim@heists@box_carry@", "idle", 13) then
                    PlayAnim(ped, "anim@heists@box_carry@", "idle", -8.0, 8.0, -1, 49, 1.0)
                    Wait(10)
                end
                if (not boxProp) then
                    local bone = GetPedBoneIndex(ped, 60309)
                    local c, r = vec3(0.025, 0.08, 0.285), vec3(-165.0, 250.0, 0.0)
                    boxProp = CreateProp(`hei_prop_heist_box`, pcoords.x, pcoords.y, pcoords.z, true, true)
                    AttachEntityToEntity(boxProp, ped, bone, c.x, c.y, c.z, r.x, r.y, r.z, false, false, false, false, 2, true)
                elseif (boxProp and dist < 20 and adist < 40) then
                    wait = 0
                    DrawMarker(2, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.25, 0.25, 0.25, 255, 255, 255, 127, false, true)
                    if (dist < 1.25 and not ShowHelpNotification(U.package_dropoff) and IsControlJustPressed(1, 51)) then
                        done = true
                        break
                    end
                end
            end
            Wait(wait)
        end

        Cleanup()

        cb(done)
    end)
end

function PassengerMission(mission, cb)
    local peds = {}
    local seats = AircraftInfo.seats - 2

    local function Cleanup()
        SetMissionBlip()
        passCount = #peds
        for i = 1, #peds do
            DeleteEntity(peds[i])
        end
    end
    Citizen.CreateThread(function()
        local done = false

        ShowNotification(U.passenger_pickup_notify)
        SetMissionBlip(mission.PackagePickup, "PassengerPickup")

        while not done do
            if (not DoesEntityExist(MissionAircraft) or GetEntityHealth(MissionAircraft) <= 0) then
                Cleanup()
                cb(false)
                return
            end
            local wait = 1000
            local ped = PlayerPedId()
            local coords = mission.PackagePickup
            local pcoords = GetEntityCoords(ped)
            local dist = #(coords - pcoords)
            if (dist < 20) then
                wait = 0
                dprint(GetEntityHeightAboveGround(ped))
                DrawMarker(2, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.75, 0.75, 0.75, 255, 255, 255, 127, false, true)
                if (dist < 3.5 and not ShowHelpNotification(U.passenger_pickup) and IsControlJustPressed(1, 51)) then
                    done = true
                    break
                end
            end
            Wait(wait)
        end

        if (done) then
            ShowNotification(U.passenger_loading)
            FreezeEntityPosition(MissionAircraft, true)
            local vehicle = MissionAircraft
            local coords = mission.PackagePickup
            for i = 1, math.random(seats) do
                if IsVehicleSeatFree(vehicle, i) then
                    local ped = CreateNPC(`A_M_M_BevHills_01`, coords.x, coords.y, coords.z + 100.0, 0.0, true, true)
                    peds[#peds + 1] = ped
                    TaskWarpPedIntoVehicle(ped, vehicle, i)
                    Wait(1000)
                end
            end
            FreezeEntityPosition(MissionAircraft, false)
        else
            Cleanup()
            cb(false)
            return
        end

        done = false

        ShowNotification(U.passenger_dropoff_notify..tostring(#peds).." passengers.")
        SetMissionBlip(mission.PackageDropoff, "PassengerDropoff")

        while not done do
            if (not DoesEntityExist(MissionAircraft) or GetEntityHealth(MissionAircraft) <= 0) then
                Cleanup()
                cb(false)
                return
            end

            local wait = 1000
            local ped = PlayerPedId()
            local coords = mission.PackageDropoff
            local pcoords = GetEntityCoords(ped)
            local acoords = GetEntityCoords(MissionAircraft)
            local dist = #(coords - pcoords)
            local adist = #(coords - acoords)
            local vehicle = GetVehiclePedIsIn(ped)
            if (vehicle == MissionAircraft and dist < 20 and adist < 40) then
                wait = 0
                DrawMarker(2, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.75, 0.75, 0.75, 255, 255, 255, 127, false, true)
                if (dist < 1.25 and not ShowHelpNotification(U.passenger_dropoff) and IsControlJustPressed(1, 51)) then
                    done = true
                    break
                end
            end
            Wait(wait)
        end

        if (done) then
            ShowNotification(U.passenger_unloading)
            FreezeEntityPosition(MissionAircraft, true)
            local vehicle = MissionAircraft
            for i = 1, #peds do
                DeleteEntity(peds[i])
                Wait(1000)
            end
            FreezeEntityPosition(MissionAircraft, false)
            Cleanup()
        else
            Cleanup()
            cb(false)
            return
        end


        cb(done)
    end)
end

function GetClosestAirport()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local distance = 1000000
    local closestPos = nil
    for k, v in pairs(Config.Airports) do
        if GetDistanceBetweenCoords(playerCoords, v.Locations.Hangar, false) < distance then
            closestPos = k
            distance = GetDistanceBetweenCoords(playerCoords, v.Locations.Hangar, false)
        end
    end
    return closestPos
end

function GetRandomAirport(airport)
    local chosenAirport = nil
    while chosenAirport == nil do
        local choose = math.random(#Config.AirportNames)
        if airport ~= Config.AirportNames[choose] then
            chosenAirport = Config.AirportNames[choose]
        end
    end
    return chosenAirport
end

function StopMission()
    dprint("StopMission")
    MissionIndex = nil
    MissionAircraft = nil
    AircraftInfo = {}
    PedCount = 0
    SetMissionBlip()
end

function StartMission(index, Type)
    dprint("StartMission")
    local vehicle = (Config.MissionCommand and GetCurrentAircraft() or nil)
    if MissionIndex == nil then
        if not vehicle then
            ShowNotification("You cannot start a mission without being in a aircraft.", 'error')
            return
        end
        if not Type then
            if GetVehicleModelNumberOfSeats(GetEntityModel(vehicle)) - 2 > 0 then
                local random = math.random(1, 2)
                if random == 1 then
                    Type = "Delivery"
                else
                    Type = "Passenger"
                end
            else
                Type = "Delivery"
            end
        end
        local airport = index
        local destination = GetRandomAirport(index)
        local distance = (GetDistanceBetweenCoords(Config.Airports[airport].Locations[Type], Config.Airports[destination].Locations[Type], true))
        dprint(Type, airport, destination, distance)

        MissionIndex = index
        MissionAircraft = vehicle
        AircraftInfo = { speed = GetVehicleEstimatedMaxSpeed(vehicle) * 3.6, weight = (GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fMass') / 1000), seats = GetVehicleModelNumberOfSeats(GetEntityModel(vehicle)) }
        local mission = {
            Type = Type,
            Distance = distance,
            PackagePickup = Config.Airports[airport].Locations[Type],
            PackageDropoff = Config.Airports[destination].Locations[Type],
        }
        if (mission.Type == "Delivery") then
            DeliveryMission(mission, function(result)
                if result then
                    ShowNotification("Mission completed!", 'success')
                    TriggerServerEvent("pickle_airport:finishedMission", mission, AircraftInfo)
                else
                    ShowNotification("Mission failed.", 'error')
                end
                StopMission()
            end)
        elseif (mission.Type == "Passenger") then
            PassengerMission(mission, function(result)
                if result then
                    ShowNotification("Mission completed!", 'success')
                    TriggerServerEvent("pickle_airport:finishedMission", mission, passCount)
                else
                    ShowNotification("Mission failed.", 'error')
                end
                StopMission()
            end)
        end
    else
        StopMission()
    end
end

function OpenMissionMenu(index)
    dprint("OpenMissionMenu")
    local menu_id = "airport_mission_menu"
    local options = {
        { label = "Passenger Flights", description = "Pick up your passengers, fly to your destination, and safely deliver them for payment." },
        { label = "Package Delivery",  description = "Collect a package from the hangar, fly to your destination, and deliver it for payment." },
    }
    lib.registerMenu({
        id = menu_id,
        title = 'Aircraft Spawner',
        position = 'top-left',
        onClose = function(keyPressed)
            Interact = false
        end,
        options = options
    }, function(selected, scrollIndex, args)
        Interact = false
        if (selected == 1) then
            StartMission(index, "Passenger")
        elseif (selected == 2) then
            StartMission(index, "Delivery")
        end
    end)

    lib.showMenu(menu_id)
end

if Config.MissionCommand then
    dprint("MissionCommand")
    RegisterCommand("pilotmission", function()
        if (PermissionCheck("pilot_mission")) then
            OpenMissionMenu(GetClosestAirport())
        else
            ShowNotification(U.permission_denied)
        end
    end)
end
