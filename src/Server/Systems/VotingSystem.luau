local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MapHandler = require(ReplicatedStorage.Modules.Shared.MapHandler)
local voting_system = {}

local votes = {}
voting_system.map_handler = MapHandler

function voting_system:init()
    MapHandler:init()

    ReplicatedStorage.Events.SubmitVote.OnServerEvent:Connect(function(plr, voted_for, position)
        warn("Recieved", self.candidates, voted_for)
        print(table.find(self.candidates, voted_for))
        if not self.candidates then return end
        if not table.find(self.candidates, voted_for) then return end

        votes[plr] = voted_for 
		ReplicatedStorage.Events.AuthorizeVote:FireAllClients(plr, position)
    end)
end

function voting_system:start(duration: number)
    local maps = MapHandler:get_random_maps(3)

    votes = {}

    self.candidates = maps
    self.timer = duration or 5
    self.active = true

    ReplicatedStorage.Events.TriggerVote:FireAllClients(maps, true)
    warn("Fired event")
end

function voting_system:update(dt)
    if not self:is_active() then return end
    self.timer -= dt
    if self.timer <= 0 then
		self.active = false
		ReplicatedStorage.Events.TriggerVote:FireAllClients(nil, false)
        return self:get_winner()
    end

    return nil
end

function voting_system:get_winner()
    local counts = {}
    for player, map in votes do
        counts[map] = (counts[map] or 0) + 1
    end

    local winner, highest = nil, 0
    for map, count in counts do
        if count > highest then
            winner = map
            highest = count
        end
    end

    if not winner then
        winner = MapHandler:get_random_map()
    end
	
	print(winner)
    return winner
end

function voting_system:get_votes()
    return votes
end

function voting_system:get_time_remaining()
    return math.max(0, math.floor(self.timer))
end

function voting_system:is_active()
    return self.active
end

return voting_system
