local SinisterSignal = require(script.SinisterSignal)

local signals = {
	spawn_entity = SinisterSignal.new();
	clear_entity = SinisterSignal.new();
	damage_tower = SinisterSignal.new()
}

return signals
