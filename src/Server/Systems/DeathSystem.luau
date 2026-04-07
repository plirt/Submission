local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MapHandler = require(ReplicatedStorage.Modules.Shared.MapHandler)

local Signals = require(ReplicatedStorage.Modules.Shared.Signals)

local death_system = {}

function death_system:init(world)
	self.world = world
end

function death_system:update(dt)
	local dead = {}

	self.world:query("Enemy", "Health", "CurrentNode"):changed("Health", "CurrentNode"):iter(function(entity_id, results)
		local health = results[2]
		local current_node = results[3]
		
		local damage = self.world:get_component(entity_id, "Damage")

		local node = MapHandler:get_node_by_number(current_node.value)
		if node and node:HasTag("end_node") then
			
			self.world:query("Tower", "Health", "Instance"):iter(function(tower_id, tower_results)
				Signals.damage_tower:Fire(tower_id, damage.value)
			end)

			self.world:update_component(entity_id, "Health", {
				current = 0,
				max = health.max,
			})
		end

		if health.current <= 0 then
			table.insert(dead, entity_id)
		end
	end)
	
	for _, entity_id in dead do
		ReplicatedStorage.Events.EnemyKilled:FireAllClients(entity_id)
		self.world:remove_entity(entity_id)
	end
	
	self.world:query("Tower", "Health"):changed("Health"):iter(function(entity_id, results)
		local health = results[2]
		
		if health.current <= 0 then
			for i, v in game.Players:GetPlayers() do
				v:Kick("You lost")
			end
			
			self.world:remove_entity(entity_id)
		end
	end)
	
end

return death_system
