RegisterNetEvent("pickle_airport:finishedMission", function(mission, info)
    local source = source
    if (PermissionCheck(source, "pilot_mission")) then
       dprint(mission.Type)
        local rewards = Config.Missions.Rewards[mission.Type]
        if Config.Missions.payPerPassenger and mission.Type == "Passenger" and info then
            for _ = 1, info do
                local amount = math.ceil(math.random(Config.Missions.passengerFare.min, Config.Missions.passengerFare.max) / 2)
                AddItem(source, Config.Missions.passengerFare.name, amount)
            end
        elseif Config.Missions.payPerSize and mission.Type == "Delivery" and info then
            --(Tonnage * (TopSpeed/100)) - Seats
            local fare = math.ceil((math.floor(info.weight) * math.floor(info.speed / 100)) - info.seats)
            if fare < 1 then fare = 1 end
           dprint(math.floor(info.weight),"*", math.floor(info.speed / 100),"-", info.seats, "=", fare)
            for _ = 1, fare do
                local amount = math.ceil(math.random(Config.Missions.sizeFare.min, Config.Missions.sizeFare.max) / 2)
                AddItem(source, Config.Missions.sizeFare.name, amount)
            end
        else
            for i = 1, #rewards do
                local amount = math.random(rewards[i].min, rewards[i].max)
                AddItem(source, rewards[i].name, amount)
            end
        end
        if Config.Missions.DistanceMultiplier then
            AddItem(source, 'money', mission.Distance*Config.Missions.DistanceMultiplier)
        end
    else
        ShowNotification(source, U.permission_rewards, 'error')
    end
end)
