local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapHandler = require(ReplicatedStorage.Modules.Shared.MapHandler)

local wave_system = {}

local current_map = nil
local spawn_location = nil

function wave_system:init(world, enemy_type_system)
	self.world = world
	self.enemy_type_system = enemy_type_system
	self.wave = 0
	self.enemies_remaining = 0
	self.wave_active = false
	self.spawn_timer = 0
	self.total_waves = 0
	self.enemies_per_wave = 5
	self.spawn_interval = 1
	self.round_active = false
	self.pending_spawns = {}
	self.next_spawn_index = 1
	self.start_time = 0
end

function wave_system:start_round(total_waves)
	local base = self.world:create_entity()

	self.world:add_component(base, "Tower", { value = base })
	self.world:add_component(base, "Health", { current = 1000, max = 1000 })
	
	self.round_active = true
	self.wave = 0
	self.total_waves = total_waves or 5

	task.delay(1, function()
		if self.round_active and not self.wave_active then
			self:start_wave()
		end
	end)
end

function wave_system:start_wave()
	self.wave += 1
	self.enemies_remaining = math.ceil((self.enemies_per_wave + self.wave) * 1.5)
	self.wave_active = true
	self.spawn_timer = 0
	self.pending_spawns = {}
	self.next_spawn_index = 1
	self.start_time = workspace:GetServerTimeNow()

	if not spawn_location then
		spawn_location = MapHandler:get_node_by_number(1)
	end

	for i = 1, self.enemies_remaining do
		local enemy_id = self.world:create_entity()
		local type_name = self.enemy_type_system:get_random_type()
		local type_data = self.enemy_type_system:get_type(type_name)

		table.insert(self.pending_spawns, {
			entity_id = enemy_id,
			type_name = type_name,
			health = type_data.health,
			speed = type_data.speed,
			damage = type_data.damage,
			position = spawn_location.Position,
			current_node = 1,
			next_node = 2,
			progress = 0,
			sync_time = self.start_time + (i * self.spawn_interval),
		})
	end

	ReplicatedStorage.Events.StartWave:FireAllClients({
		wave_number = self.wave,
		total_entities = self.enemies_remaining,
		spawn_interval = self.spawn_interval,
		entities_remaing = self.enemies_remaining,
		spawn_location = spawn_location.CFrame,
		start_time = self.start_time,
		spawns = self.pending_spawns,
	})

	print(`Wave {self.wave} started`)
end

function wave_system:spawn_enemy(spawn_data)
	self.world:add_components(spawn_data.entity_id, {
		Health = { current = spawn_data.health, max = spawn_data.health },
		Speed = { value = spawn_data.speed },
		Damage = { value = spawn_data.damage },
		Enemy = { wave = self.wave, type = spawn_data.type_name },
		CurrentNode = { value = spawn_data.current_node },
		NextNode = { value = spawn_data.next_node },
		Movement = { progress = spawn_data.progress, speed = spawn_data.speed },
	})
end

function wave_system:update(dt)
	if not self.round_active then
		return
	end

	if current_map == nil then
		current_map = MapHandler:get_current_map()
		if current_map then
			spawn_location = current_map.Map.Paths:FindFirstChild("1")
		end
	end

	if self.wave_active then
		local now = workspace:GetServerTimeNow()

		while self.next_spawn_index <= #self.pending_spawns do
			local spawn_data = self.pending_spawns[self.next_spawn_index]
			if now < spawn_data.sync_time then
				break
			end

			self:spawn_enemy(spawn_data)
			self.next_spawn_index += 1
			self.enemies_remaining -= 1
		end

		if self.enemies_remaining <= 0 and self.world:query("Enemy"):count() == 0 then
			self.wave_active = false
			print(`Wave {self.wave} complete!`)

			if self.wave >= self.total_waves then
				self.round_active = false
				warn("Game end")

				for _, player in game.Players:GetPlayers() do
					player:Kick("end")
				end

				return
			end

			task.delay(5, function()
				if self.round_active and not self.wave_active then
					self:start_wave()
				end
			end)
		end
	end
end

return wave_system
