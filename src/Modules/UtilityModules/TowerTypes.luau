export type damage_context = {
	distance: number;
	enemy_health: number;
	wave: number;
	tower_level: number;
}

export type tower_data = {
	range: number;
	damage: number | ((ctx: damage_context) -> number);
	fire_rate: number;
}

export type tower_registry = {
	[string]: tower_data,
}

local towers: tower_registry = {
	Normal = {
		range = 15,
		damage = 10,
		fire_rate = 1,
	},

	Sniper = {
		range = 30,
		damage = function(ctx: damage_context)
			return 25 + (ctx.distance * 0.1)
		end,
		fire_rate = 0.5,
	},
}

return towers
