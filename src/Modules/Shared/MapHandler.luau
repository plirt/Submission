local ReplicatedStorage = game:GetService("ReplicatedStorage")

local map_folder = workspace.Map
local maps = ReplicatedStorage:FindFirstChild("Maps")

local map_handler = {}

map_handler.map_list = nil
map_handler.current_map = nil

function map_handler:init()
    self.map_list = maps:GetChildren()
    if not self.map_list then
        self.map_list = {}
        warn("Maps folder not found in ReplicatedStorage!")
    end
end

function map_handler:get_random_map()
    return self.map_list[math.random(#self.map_list)].Name
end

function map_handler:get_random_maps(total)
    local all = self.map_list
    local maps = {}

    for i = 1, math.min(total, #all) do
        local index = math.random(i, #all)
        all[i], all[index] = all[index], all[i]
        table.insert(maps, all[i].Name)
    end

    return maps
end

function map_handler:load_map(map_name: string, players: {Player})
	if not maps:FindFirstChild(map_name) then return end
	
	map_folder:ClearAllChildren()
	game.Lighting:ClearAllChildren()
	
	local map = maps:FindFirstChild(map_name):Clone()
	local map_lighting = map:FindFirstChild("Lighting")
	
	if map_lighting then
		for _, item in map_lighting:GetChildren() do
			item:Clone().Parent = game.Lighting
		end
	end
	
	map.Name = "Map"
	
	map.Parent = map_folder
	self.current_map = map
	
	if players then
		self:teleport_players(players)
	end
end

function map_handler:unload_map()
	map_folder:ClearAllChildren()
	game.Lighting:ClearAllChildren()
	self.current_map = nil
end

function map_handler:teleport_players(group: {Player})
	for _, player in group do
		player.Character.HumanoidRootPart.CFrame = self.current_map:FindFirstChild("PlayerSpawn").CFrame
	end
end

function map_handler:get_current_map()
	return self.current_map
end

function map_handler:get_nodes()
	local current_map = self:get_current_map()
	if not current_map then
		self.current_map = workspace.Map:FindFirstChildWhichIsA("Folder")
	end
	local nodes = self.current_map.Map.Paths
	
	return nodes
end

function map_handler:get_last_node()
	local current_map = self:get_current_map()
	if not current_map then
		self.current_map = workspace.Map:FindFirstChildWhichIsA("Folder")
	end
	local nodes = self.current_map.Map.Paths
	
	local last_node = nil
	for _, node in nodes:GetChildren() do
		if node:HasTag("end_node") then
			last_node = node
		end
	end
	
	return last_node
end

function map_handler:get_node_by_number(number: number)
	local current_map = self:get_current_map()
	if not current_map then
		self.current_map = workspace.Map:FindFirstChildWhichIsA("Folder")
	end
	local nodes = self.current_map.Map.Paths
	
	local nodes = self.current_map.Map.Paths
	if not nodes:FindFirstChild(tostring(number)) then return end
	
	return nodes:FindFirstChild(tostring(number))
end

function map_handler:get_next_node(node)
	local current_map = self:get_current_map()
	if not current_map then
		self.current_map = workspace.Map:FindFirstChildWhichIsA("Folder")
	end
	local nodes = self.current_map.Map.Paths
	
	if type(node) ~= "number" then return end

	local nodes = self.current_map.Map.Paths
	if not nodes:FindFirstChild(tostring(node)) then return end

	local next_node = node + 1
	return nodes:FindFirstChild(tostring(next_node))
end

function map_handler:get_next_node_from_position(position)
	local current_node = self:get_node_from_position(position)
	if not current_node then
		local closest = nil
		local closest_distance = math.huge

		for _, node in self.current_map.Map.Paths:GetChildren() do
			local distance = (position - node.Position).Magnitude
			if distance < closest_distance then
				closest = node
				closest_distance = distance
			end
		end

		current_node = closest
	end

	if not current_node then
		return nil
	end

	return self:get_next_node(tonumber(current_node.Name))
end

function map_handler:get_node_from_position(position)
	local current_map = self:get_current_map()
	if not current_map then
		self.current_map = workspace.Map:FindFirstChildWhichIsA("Folder")
	end

	local nodes = self.current_map.Map.Paths
	local closest = nil
	local closest_distance = math.huge

	for _, node in nodes:GetChildren() do
		local distance = (position - node.Position).Magnitude
		if distance < closest_distance then
			closest = node
			closest_distance = distance
		end
	end

	return closest
end

return map_handler
