local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local run_service = game:GetService("RunService")

local MapHandler = require(ReplicatedStorage.Modules.Shared.MapHandler)

local map_folder = workspace.Map
local y_threshold = -25

local teleport_system = {}

function teleport_system:update(dt)
	local current_map = MapHandler:get_current_map()
	local current_spawn_cframe = nil
	if current_map then
		current_spawn_cframe = current_map.PlayerSpawn.CFrame
	end
	if not current_spawn_cframe then return end
	
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		
		if hrp and hrp.Position.Y < y_threshold then
			local humanoid = char:FindFirstChild("Humanoid")
			if humanoid and humanoid.Health > 0 then
				hrp.CFrame = current_spawn_cframe
			end
		end
	end
end

return teleport_system
