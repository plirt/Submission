--!strict

type System = {
	update: (self: any, dt: number) -> (),
	[any]: any,
}

type SystemEntry = {
	system: System,
	priority: number,
	enabled: boolean,
}

export type SystemManager = {
	systems: { SystemEntry },
	register: (self: SystemManager, system: System, priority: number) -> (),
	unregister: (self: SystemManager, system: System) -> (),
	enable: (self: SystemManager, system: System) -> (),
	disable: (self: SystemManager, system: System) -> (),
	update: (self: SystemManager, dt: number) -> (),
	get_system: (self: SystemManager, system: System) -> SystemEntry?,
	get_all: (self: SystemManager) -> { SystemEntry },
	count: (self: SystemManager) -> number,
	clear: (self: SystemManager) -> (),
	is_registered: (self: SystemManager, system: System) -> boolean,
	set_priority: (self: SystemManager, system: System, priority: number) -> (),
	enable_all: (self: SystemManager) -> (),
	disable_all: (self: SystemManager) -> (),
	to_string: (self: SystemManager) -> string,
}

local system_manager = {}
system_manager.__index = system_manager

function system_manager.new()
    local self = setmetatable({}, system_manager)
    self.systems = {} 
    return self
end

function system_manager:register(system, priority)
    for _, entry in self.systems do
        if entry.system == system then
            warn("System already registered")
            return
        end
    end

    table.insert(self.systems, {
        system = system,
        priority = priority,
        enabled = true
    })
    table.sort(self.systems, function(a: SystemEntry, b: SystemEntry)
        return a.priority < b.priority
    end)
end

function system_manager:unregister(system)
    for i = #self.systems, 1, -1 do
        local entry = self.systems[i]
        if entry.system == system then
            table.remove(self.systems, i)
        end
    end
end

function system_manager:enable(system)
    for i, entry in self.systems do
        if entry.system == system then
            entry.enabled = true
        end
    end
end

function system_manager:disable(system)
    for i, entry in self.systems do
        if entry.system == system then
            entry.enabled = false
        end
    end
end

function system_manager:update(dt)
    for i, entry in self.systems do
        if entry.enabled then entry.system:update(dt) end
    end
end

function system_manager:get_system(system)
    for i, entry in self.systems do
        if entry.system == system then return entry end
    end
    return nil
end

function system_manager:get_all()
    return table.clone(self.systems)
end

function system_manager:count()
    return #self.systems
end

function system_manager:clear()
    table.clear(self.systems)
end

function system_manager:is_registered(system)
    for i, entry in self.systems do
        if entry.system == system then return true end
    end
    return false
end

function system_manager:set_priority(system, priority)
    local entry = self:get_system(system)
    if entry then
        entry.priority = priority
        table.sort(self.systems, function(a: SystemEntry, b: SystemEntry)
            return a.priority < b.priority
        end)
    end
end

function system_manager:enable_all()
    for i, entry in self.systems do
        entry.enabled = true
    end
end

function system_manager:disable_all()
    for i, entry in self.systems do
        entry.enabled = false
    end
end

function system_manager:to_string()
    local total = self:count()
    local enabled = 0

    for i, entry in self.systems do
        if entry.enabled then
            enabled += 1
        end
    end

    return `Systems: {total} | Enabled: {enabled}`
end

return system_manager
