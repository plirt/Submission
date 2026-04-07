local ReplicatedStorage = game:GetService("ReplicatedStorage")

local enemy_type_system = {}

local enemy_models = ReplicatedStorage.Models.EnemyModels

local TYPES = {
	Normal = {
		health = 175,
		speed = 5,
		damage = 25,
		size = Vector3.new(4, 4, 4),
		color = Color3.fromRGB(255, 0, 0),
		model = enemy_models.Normal
	},
	Fast = {
		health = 75,
		speed = 10,
		damage = 15,
		size = Vector3.new(2, 2, 2),
		color = Color3.fromRGB(255, 150, 0),
		model = enemy_models.Fast
	},
	Slow = {
		health = 300,
		speed = 3,
		damage = 40,
		size = Vector3.new(7, 7, 7),
		color = Color3.fromRGB(150, 0, 255),
		model = enemy_models.Slow
	}
}

local names = {"Normal", "Fast", "Slow"}

function enemy_type_system:init(world)
	self.world = world
	self.types = TYPES
end

function enemy_type_system:get_random_type()
	return names[math.random(#names)]
end

function enemy_type_system:get_type(name)
	return TYPES[name]
end

function enemy_type_system:apply_type(entity_id, type_name, part)
	local type_data = self:get_type(type_name)

	self.world:update_component(entity_id, "Health", { 
		current = type_data.health, 
		max = type_data.health 
	})
	self.world:update_component(entity_id, "Speed", { 
		value = type_data.speed 
	})

	part.Size = type_data.size
	part.Color = type_data.color
end

function enemy_type_system:update(dt)

end

return enemy_type_system
