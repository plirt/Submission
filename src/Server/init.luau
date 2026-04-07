local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local players = game:GetService("Players")
local server_script_service = game:GetService("ServerScriptService")

local Signals = require(ReplicatedStorage.Modules.Shared.Signals)

local GameStateManager = require(ReplicatedStorage.Modules.GameStateManager)
local VotingSystem = require(script.Systems.VotingSystem)
local World = require(ReplicatedStorage.Modules.ecs)
local WaveSystem = require(script.Systems.WaveSystem)
local teleport_system = require(server_script_service.Server.Systems.TeleportSystem)
local MapHandler = require(ReplicatedStorage.Modules.Shared.MapHandler)
local EnemyTypeSystem = require(ReplicatedStorage.Modules.Shared.EnemyTypeSystem)
local MovementSystem = require(ServerScriptService.Server.Systems.MovementSystem)
local DeathSystem = require(ServerScriptService.Server.Systems.DeathSystem)
local TowerSystem = require(ServerScriptService.Server.Systems.TowerSystem)

local world = World.new()

world:register_component("Health", { current = 100, max = 100 })
world:register_component("Speed", { value = 10 })
world:register_component("Damage", { value = 10 })
world:register_component("Model", { model = nil })
world:register_component("Enemy", { wave = 1 })
world:register_component("CurrentNode", { value = nil })
world:register_component("NextNode", { value = nil })
world:register_component("Movement", { progress = 0,  speed = 10 })
world:register_component("Tower", { value = nil })

WaveSystem:init(world, EnemyTypeSystem)
MovementSystem:init(world)
DeathSystem:init(world)
TowerSystem:init(world)

world:register_system(WaveSystem, 1)
world:register_system(MovementSystem, 2)
world:register_system(DeathSystem, 3)
world:register_system(TowerSystem, 4)

VotingSystem:init()

local vote_winner = nil

GameStateManager:on_entered("Voting",  function()
	world:disable_all_systems()
	task.wait(2)
	VotingSystem:start(1)
end)

GameStateManager:on_exit("Voting", function()
	if type(vote_winner) ~= "string" then
		vote_winner = MapHandler:get_random_map()
	end

	print(`Loading map: {vote_winner}`)
	MapHandler:load_map(vote_winner, players:GetPlayers())
end)

GameStateManager:on_entered("Started", function()
	world:enable_all_systems()
	WaveSystem:start_round(30)
end)

GameStateManager:on_exit("Started", function()
	world:disable_all_systems()
	MapHandler:unload_map()
end)

GameStateManager:transition("Voting")

RunService.Heartbeat:Connect(function(dt)
	world:update(dt)
	teleport_system:update(dt)

	if GameStateManager:is("Voting") then
		local winner = VotingSystem:update(dt)
		if winner then
			vote_winner = winner
			GameStateManager:transition("Started")
			vote_winner = nil
		end
	end
end)

Signals.damage_tower:Connect(function(entity_id, damage)
	warn("Test")
	if world:has_component(entity_id, "Health") then
		local health = world:get_component(entity_id, "Health")
		
		local new_health = health.current - damage
		world:update_component(entity_id, "Health", {
			current = new_health,
			max = health.max,
		})
	end
end)
