local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")

local TowerTypes = require(ReplicatedStorage.Modules.UtilityModules.TowerTypes)
local EnemySystem = require(StarterPlayer.StarterPlayerScripts.Client.Systems.EnemySystem)

local TowerRemote = ReplicatedStorage.Events.TowerRemote

local models = ReplicatedStorage.Models

local plr = Players.LocalPlayer
local player_gui = plr.PlayerGui
local towers_gui = player_gui:WaitForChild("TowerGUI")
local main_frame = towers_gui:WaitForChild("Main")
local scrolling_frame = main_frame:WaitForChild("ScrollingFrame")
local template = scrolling_frame:WaitForChild("Template")

local mouse = plr:GetMouse()

local tower_system = {}
tower_system.data = {}
tower_system.placing_type = nil
tower_system.preview_model = nil
tower_system.preview_cframe = nil
tower_system.preview_rotation = nil
tower_system.preview_range = nil
tower_system.next_id = 1

local function create_tower_button(tower_name)
	local new_button = template:Clone()
	new_button.Name = `{tower_name}_button`
	new_button.Text = tower_name
	new_button.Visible = true
	new_button.Parent = scrolling_frame
	
	new_button.Activated:Connect(function()
		tower_system:start_placement(tower_name)
		warn("test")
	end)
end

local function create_range_visual(range)
	local part = Instance.new("Part")
	part.Name = "RangePreview"
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(158, 224, 255)
	part.Transparency = 0.9

	part.Size = Vector3.new(0.2, range * 2, range * 2)
	part.Parent = workspace

	return part
end

function tower_system:init()
	TowerRemote.OnClientEvent:Connect(function(func, tower_id, tower_type, cframe)
		if func == "Spawn" then
			self:add_tower(tower_id, tower_type, cframe)
		elseif func == "Destroy" then
			self:destroy_tower(tower_id)
		end
	end)
	
	for i, v in TowerTypes do
		create_tower_button(i)
	end
	
	mouse.Button1Down:Connect(function()
		if self.placing_type then
			self:confirm_placement()
		end
	end)
end

function tower_system:cancel_placement()
	if self.preview_model then
		self.preview_model:Destroy()
	end
	
	if self.preview_range then
		self.preview_range:Destroy()
	end

	self.placing_type = nil
	self.preview_model = nil
	self.preview_cframe = nil
	self.preiview_rotation = nil
	self.preview_range = nil
end

function tower_system:confirm_placement()
	if not self.placing_type or not self.preview_model or not self.preview_cframe then
		return
	end
	
	if mouse.Target.Parent.Name == "Boundaries" then
		return
	end

	local tower_id = self.next_id
	self.next_id += 1

	local pos = self.preview_cframe.Position
	local rotation = math.rad(self.preview_rotation or 0)
	local placed_cframe = CFrame.new(pos) * CFrame.Angles(0, rotation, 0)

	self:spawn_tower(tower_id, self.placing_type, placed_cframe)
	self:cancel_placement()
end

function tower_system:start_placement(type_name)
	self:cancel_placement()
	
	local template = models.TowerModels:FindFirstChild(type_name)
	if not template then return end
	
	local tower_info = TowerTypes[type_name]
	if not tower_info then return end
	
	local model = template:Clone()
	
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.Transparency = 0.5
		end
	end
	
	model.Parent = workspace
	self.placing_type = type_name
	self.preview_model = model
	self.preview_cframe = mouse.Hit
	self.preview_rotation = 0
	self.preview_range = create_range_visual(tower_info.range)
end

function tower_system:spawn_tower(tower_id, type_name, cframe, level)
	local tower_info = TowerTypes[type_name]
	if not tower_info then return end

	TowerRemote:FireServer("Spawn", tower_id, type_name, cframe)
	
	self.data[tower_id] = {
		id = tower_id,
		type_name = type_name,
		level = level or 1,
		range = tower_info.range,
		damage = tower_info.damage,
		fire_rate = tower_info.fire_rate,
		target_mode = "First",
		cooldown = 0,
		target = nil,
	}
end

function tower_system:destroy_tower(tower_id, destory_server)
	local entry = self.data[tower_id]
	if not entry then
		return
	end

	if entry.model then
		entry.model:Destroy()
	end
	
	if destory_server then
		TowerRemote:FireServer("Destroy", tower_id)
	end

	self.data[tower_id] = nil
end

function tower_system:add_tower(tower_id, type_name, cframe, level)
	local tower_info = TowerTypes[type_name]
	if not tower_info then return end

	local model = models.TowerModels:FindFirstChild(type_name)
	if not model then return end

	local new_model = model:Clone()
	new_model:PivotTo(cframe)
	new_model.Parent = workspace.Towers

	self.data[tower_id] = {
		id = tower_id,
		type_name = type_name,
		level = level or 1,
		model = new_model,
		range = tower_info.range,
		damage = tower_info.damage,
		fire_rate = tower_info.fire_rate,
		target_mode = "First",
		cooldown = 0,
		target = nil,
	}
end

function tower_system:get_target(tower)
	if not tower or not tower.model or not tower.model.Parent then
		return nil
	end

	local best_target = nil
	local best_value = nil
	local tower_pos = tower.model:GetPivot().Position

	local function set_best(target, value)
		best_target = target
		best_value = value
	end

	for enemy_id, enemy in EnemySystem.enemies do
		if not enemy then
			continue
		end

		if enemy.dead then
			continue
		end

		if not enemy.model or not enemy.model.Parent then
			continue
		end

		local enemy_pos = enemy.model:GetPivot().Position
		local distance = (enemy_pos - tower_pos).Magnitude
		if distance > tower.range then
			continue
		end

		local progress = (enemy.current_node or 0) + (enemy.progress or 0)

		if tower.target_mode == "Closest" then
			if not best_value or distance < best_value then
				set_best(enemy, distance)
			end
		elseif tower.target_mode == "First" then
			if not best_value or progress > best_value then
				set_best(enemy, progress)
			end
		elseif tower.target_mode == "Last" then
			if not best_value or progress < best_value then
				set_best(enemy, progress)
			end
		elseif tower.target_mode == "Strongest" then
			local health = enemy.health or 0
			if not best_value or health > best_value then
				set_best(enemy, health)
			end
		end
	end

	return best_target
end

function tower_system:update(dt)
	-- bluds preview
	if self.preview_model then 
		local target = mouse.Hit
		if not target then return end

		local model_size = self.preview_model:GetExtentsSize()
		local pos = target.Position + Vector3.new(0, model_size.Y / 2, 0)

		self.last_preview_pos = self.last_preview_pos or pos
		local world_delta = pos - self.last_preview_pos
		self.last_preview_pos = pos

		local rotation = math.rad(self.preview_rotation or 0)
		local base_cframe = CFrame.new(pos) * CFrame.Angles(0, rotation, 0)

		local local_delta = base_cframe:VectorToObjectSpace(world_delta)

		local max_tilt = math.rad(15)
		local tilt_x = math.clamp(-local_delta.Z * 2, -max_tilt, max_tilt)
		local tilt_z = math.clamp(local_delta.X * 2, -max_tilt, max_tilt)

		local target_cframe = base_cframe * CFrame.Angles(tilt_x, 0, tilt_z)

		self.preview_cframe = self.preview_cframe and self.preview_cframe:Lerp(target_cframe, 0.25) or target_cframe
		self.preview_model:PivotTo(self.preview_cframe)

		if self.preview_range then
			local range_pos = self.preview_cframe.Position - Vector3.new(0, model_size.Y / 2, 0) + Vector3.new(0, 0.05, 0)
			self.preview_range.CFrame = CFrame.new(range_pos) * CFrame.Angles(0, 0, math.rad(90))
		end
	end

	-- Tower blud target
	
	for tower_id, tower in self.data do
		if not tower.model or not tower.model.Parent then
			self.data[tower_id] = nil
			continue
		end

		tower.cooldown = math.max((tower.cooldown or 0) - dt, 0)

		local target = self:get_target(tower)
		tower.target = target

		if not target then
			tower.target = nil
			continue
		end

		if target.dead then
			tower.target = nil
			continue
		end

		if not target.model or not target.model.Parent then
			tower.target = nil
			continue
		end

		tower.target = target

		local tower_pos = tower.model:GetPivot().Position
		local enemy_pos = target.model:GetPivot().Position
		local look_at = Vector3.new(enemy_pos.X, tower_pos.Y, enemy_pos.Z)

		tower.model:PivotTo(CFrame.lookAt(tower_pos, look_at))

		if tower.cooldown <= 0 then
			tower.cooldown = 1 / tower.fire_rate
			ReplicatedStorage.Events.AttackEnemy:FireServer(tower.id, target.id)
		end
	end
end

UserInputService.InputBegan:Connect(function(inp, gpe)
	if gpe then
		return
	end

	if inp.KeyCode == Enum.KeyCode.R then
		if not tower_system.placing_type or not tower_system.preview_model then
			return
		end

		tower_system.preview_rotation += 36
	elseif inp.KeyCode == Enum.KeyCode.E then
		if tower_system.placing_type then
			tower_system:cancel_placement()
		end
	end
end)

return tower_system
