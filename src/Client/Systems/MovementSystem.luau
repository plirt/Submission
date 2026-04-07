local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local MapHandler = require(ReplicatedStorage.Modules.Shared.MapHandler)
local EnemySystem = require(StarterPlayer.StarterPlayerScripts.Client.Systems.EnemySystem)

local movement_system = {}
movement_system.data = {}

function movement_system:init()
end

function movement_system:update(dt)
	for entity_id, entry in self.data do
		if entry.dead or not entry.model or not entry.model.Parent then
			self.data[entity_id] = nil
			continue
		end

		if not entry.current_node or not entry.next_node then
			continue
		end

		local current_node = entry.current_node
		local next_node = entry.next_node

		local current_node_obj = MapHandler:get_node_by_number(current_node)
		local next_node_obj = MapHandler:get_node_by_number(next_node)

		if not current_node_obj or not next_node_obj then
			continue
		end

		local start_pos = current_node_obj.Position
		local end_pos = next_node_obj.Position
		local distance = (end_pos - start_pos).Magnitude
		if distance <= 0 then
			continue
		end

		entry.progress = (entry.progress or 0) + (entry.speed * dt / distance)
		local progress = entry.progress

		while progress >= 1 do
			progress -= 1
			current_node = next_node

			local new_next_node_obj = MapHandler:get_next_node(current_node)
			if not new_next_node_obj then
				next_node = nil
				break
			end

			next_node = tonumber(new_next_node_obj.Name)

			current_node_obj = MapHandler:get_node_by_number(current_node)
			next_node_obj = MapHandler:get_node_by_number(next_node)
			if not current_node_obj or not next_node_obj then
				next_node = nil
				break
			end

			start_pos = current_node_obj.Position
			end_pos = next_node_obj.Position
			distance = (end_pos - start_pos).Magnitude
			if distance <= 0 then
				next_node = nil
				break
			end
		end

		entry.current_node = current_node
		entry.next_node = next_node
		entry.progress = progress
		
		if next_node_obj:HasTag("end_node") and progress >= .85 then
			EnemySystem:kill_entity(entity_id)
		end

		if not next_node then
			continue
		end

		local pos = start_pos:Lerp(end_pos, math.clamp(progress, 0, 1))
		local half_height = entry.model:GetExtentsSize().Y / 2
		local world_pos = Vector3.new(pos.X, pos.Y + half_height, pos.Z)

		entry.model:PivotTo(CFrame.lookAt(world_pos, Vector3.new(end_pos.X, world_pos.Y, end_pos.Z)))
	end
end

return movement_system
