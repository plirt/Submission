local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Signals = require(ReplicatedStorage.Modules.Shared.Signals)

local VotingClient = require(StarterPlayer.StarterPlayerScripts.Client.Systems:WaitForChild("VotingClient"))
local MovementSystem = require(StarterPlayer.StarterPlayerScripts.Client.Systems:WaitForChild("MovementSystem"))
local EnemySystem = require(StarterPlayer.StarterPlayerScripts.Client.Systems:WaitForChild("EnemySystem"))
local WaveSystem = require(StarterPlayer.StarterPlayerScripts.Client.Systems.WaveSystem)
local TowerSystem = require(StarterPlayer.StarterPlayerScripts.Client.Systems.TowerSystem)

VotingClient:init()
WaveSystem:init()
EnemySystem:init()
TowerSystem:init()

Signals.spawn_entity:Connect(function(entity_id, data)
	MovementSystem.data[entity_id] = data
end)

Signals.clear_entity:Connect(function(entity_id)
	WaveSystem:destroy_entity(entity_id)
	MovementSystem.data[entity_id] = nil
end)

RunService.RenderStepped:Connect(function(dt)
	MovementSystem:update(dt)
	WaveSystem:update(dt)
	TowerSystem:update(dt)
end)
