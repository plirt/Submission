local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TowerTypes = require(ReplicatedStorage.Modules.UtilityModules.TowerTypes)
local MapHandler = require(ReplicatedStorage.Modules.Shared.MapHandler)

local TowerRemote = ReplicatedStorage.Events.TowerRemote

local models = ReplicatedStorage.Models

local tower_system = {}
tower_system.data = {}

function tower_system:init(world)
	self.world = world
	TowerRemote.OnServerEvent:Connect(function(plr, func: string, tower_id: number, tower_type: string, cframe: CFrame)
		if func == "Spawn" then
			if typeof(tower_id) ~= "number" or typeof(tower_type) ~= "string" or typeof(cframe) ~= "CFrame" then
				return
			end

			local tower_info = TowerTypes[tower_type]
			if not tower_info then
				return
			end

			self.data[tower_id] = {
				id = tower_id,
				type_name = tower_type,
				cframe = cframe,
				damage = tower_info.damage,
				range = tower_info.range,
				fire_rate = tower_info.fire_rate,
				level = 1,
			}
		elseif func == "Destroy" then
			self.data[tower_id] = nil
		end

		TowerRemote:FireAllClients(func, tower_id, tower_type, cframe)
	end)

	ReplicatedStorage.Events.AttackEnemy.OnServerEvent:Connect(function(plr, tower_id, target_id)
		if typeof(tower_id) ~= "number" or typeof(target_id) ~= "number" then
			return
		end

		local tower = self.data[tower_id]
		if not tower then
			return
		end
		
		if not self.world:is_alive(target_id) then
			ReplicatedStorage.Events.EnemyKilled:FireAllClients(entity_id)
			return
		end

		local health = self.world:get_component(target_id, "Health")
		local enemy = self.world:get_component(target_id, "Enemy")
		if not health or not enemy then
			return
		end

		local enemy_position = self:get_enemy_position(target_id)
		if not enemy_position then
			return
		end

		local distance = (tower.cframe.Position - enemy_position).Magnitude

		local damage = self:get_damage(tower_id, {
			distance = distance,
			enemy_health = health.current,
			wave = enemy.wave,
		})

		local new_health = math.max(health.current - damage, 0)

		self.world:update_component(target_id, "Health", {
			current = new_health,
			max = health.max,
		})

		if new_health <= 0 then
			warn(`Killed enemy with id {target_id}`)
			return
		end
	end)
end

function tower_system:get_damage(tower_id, ctx)
	local entry = self.data[tower_id]
	if not entry then return 0 end

	if type(entry.damage) == "function" then
		return entry.damage({
			distance = ctx.distance,
			enemy_health = ctx.enemy_health,
			wave = ctx.wave,
			tower_level = entry.level,
		})
	end

	return entry.damage
end

function tower_system:get_enemy_position(entity_id)
	local current_node = self.world:get_component(entity_id, "CurrentNode")
	local next_node = self.world:get_component(entity_id, "NextNode")
	local progress = self.world:get_component(entity_id, "Movement")

	if not current_node then return nil end

	local current_node_object = MapHandler:get_node_by_number(current_node.value)
	if not current_node_object then return nil end

	if next_node and next_node.value and progress then
		local next_node_object = MapHandler:get_node_by_number(next_node.value)
		if not next_node_object then return nil end

		return current_node_object.Position:Lerp(next_node_object.Position, progress.progress or 0)
	end

	return current_node_object.Position
end

function tower_system:update(dt)
end

return tower_system
