local replicated_storage = game:GetService("ReplicatedStorage")
local map_handler = require(replicated_storage.Modules.Shared.MapHandler)

local movement_system = {}

function movement_system:init(world)
	self.world = world
end

function movement_system:update(dt)
	if dt > 1 then
		dt = 1
	end

	self.world:query("CurrentNode", "NextNode", "Movement"):iter(function(entity_id, results)
		local current_node = results[1].value
		local next_node = results[2].value
		local movement = results[3]

		if not current_node or not next_node then
			return
		end

		local current_node_obj = map_handler:get_node_by_number(current_node)
		local next_node_obj = map_handler:get_node_by_number(next_node)

		if not current_node_obj or not next_node_obj then
			return
		end

		local distance = (next_node_obj.Position - current_node_obj.Position).Magnitude
		if distance <= 0 then
			return
		end

		movement.progress += movement.speed * dt / distance

		while movement.progress >= 1 do
			movement.progress -= 1
			current_node = next_node
			self.world:update_component(entity_id, "CurrentNode", { value = current_node })

			local new_next_node_obj = map_handler:get_next_node(current_node)
			if not new_next_node_obj then
				self.world:update_component(entity_id, "NextNode", { value = nil })
				return
			end

			next_node = tonumber(new_next_node_obj.Name)
			self.world:update_component(entity_id, "NextNode", { value = next_node })
		end
	end)
end

return movement_system
