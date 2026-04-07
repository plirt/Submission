local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local EnemySystem = require(StarterPlayer.StarterPlayerScripts.Client.Systems.EnemySystem)

local plr = Players.LocalPlayer
local player_gui = plr.PlayerGui
local towers_gui = player_gui:WaitForChild("TowerGUI")

local wave_event = ReplicatedStorage.Events.StartWave

type spawn_data = {
	entity_id: number,
	type_name: string,
	health: number,
	speed: number,
	position: Vector3,
	current_node: number,
	next_node: number,
	progress: number,
	sync_time: number,
}

type wave_data = {
	wave_number: number,
	total_entities: number,
	spawn_interval: number,
	entities_remaing: number,
	spawn_location: CFrame,
	start_time: number,
	spawns: { spawn_data },
}

local wave_system = {}
wave_system.entities = {}
wave_system.active = false
wave_system.spawn_interval = 1
wave_system.enemies_remaining = 0
wave_system.spawn_location = nil
wave_system.wave = 0
wave_system.start_time = 0
wave_system.spawns = {}
wave_system.next_spawn_index = 1

function wave_system:init()
	wave_event.OnClientEvent:Connect(function(data: wave_data)
		self.active = true
		self.wave = data.wave_number
		self.spawn_interval = data.spawn_interval
		self.enemies_remaining = data.total_entities
		self.spawn_location = data.spawn_location
		self.start_time = data.start_time
		self.spawns = data.spawns or {}
		self.next_spawn_index = 1

		if not towers_gui.Enabled then
			towers_gui.Enabled = true
		end
	end)
end

function wave_system:destroy_entity(entity_id)
	self.entities[entity_id] = nil
end

function wave_system:update(dt)
	if not self.active then
		return
	end

	local now = workspace:GetServerTimeNow()

	while self.next_spawn_index <= #self.spawns do
		local enemy_data = self.spawns[self.next_spawn_index]
		if now < enemy_data.sync_time then
			break
		end

		self.entities[enemy_data.entity_id] = enemy_data
		EnemySystem:spawn_entity(enemy_data)

		self.next_spawn_index += 1
		self.enemies_remaining -= 1
	end
end

return wave_system
