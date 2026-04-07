local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local MapHandler = require(ReplicatedStorage.Modules.Shared.MapHandler)
local Signals = require(ReplicatedStorage.Modules.Shared.Signals)

local player = Players.LocalPlayer
local player_gui = player.PlayerGui

local enemy_system = {}
enemy_system.enemies = {}

function enemy_system:init(movement_system, wave_system)
	ReplicatedStorage.Events.EnemyKilled.OnClientEvent:Connect(function(entity_id)
		print(self.enemies[entity_id])
		if not self.enemies[entity_id] then return end
		self:kill_entity(entity_id)
	end)
end

function enemy_system:spawn_entity(spawn_data)
	local model = ReplicatedStorage.Models.EnemyModels[spawn_data.type_name]:Clone()
	local torso = model:WaitForChild("Torso")

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		end
	end

	model.PrimaryPart = torso
	model:SetAttribute("EntityId", spawn_data.entity_id)
	model:SetAttribute("Speed", spawn_data.speed)
	model:PivotTo(CFrame.new(spawn_data.position))
	model.Parent = workspace

	local data = {
		id = spawn_data.entity_id,
		type_name = spawn_data.type_name,
		spawn_location = spawn_data.position,
		model = model,
		primary_part = torso,
		nodes = MapHandler:get_nodes(),
		current_node = spawn_data.current_node,
		next_node = spawn_data.next_node,
		progress = spawn_data.progress or 0,
		base_progress = spawn_data.progress or 0,
		speed = spawn_data.speed,
		dead = false,
		sync_time = spawn_data.sync_time,
	}

	enemy_system.enemies[spawn_data.entity_id] = data
	Signals.spawn_entity:Fire(spawn_data.entity_id, data)
end

function enemy_system:kill_entity(entity_id)
	local entry = self.enemies[entity_id]
	if not entry then
		return
	end

	entry.dead = true
	
	if entry.model then
		entry.model:Destroy()
	end
	
	self.enemies[entity_id] = nil
	Signals.clear_entity:Fire(entity_id)
end


return enemy_system
