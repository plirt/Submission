--!strict

local component_registry = {}
component_registry.__index = component_registry

export type ComponentRegistry = {
    components: { [string]: any },
    register: (self: ComponentRegistry, name: string, defaults: any) -> (),
    unregister: (self: ComponentRegistry, name: string) -> (),
    get: (self: ComponentRegistry, name: string) -> any,
    exists: (self: ComponentRegistry, name: string) -> boolean,
    get_all: (self: ComponentRegistry) -> { string },
    count: (self: ComponentRegistry) -> number,
    clear: (self: ComponentRegistry) -> (),
    update_defaults: (self: ComponentRegistry, name: string, defaults: any) -> (),
    validate: (self: ComponentRegistry, name: string, data: { [any]: any }) -> boolean,
    get_all_defaults: (self: ComponentRegistry) -> { [string]: any },
    to_string: (self: ComponentRegistry) -> string,
}

function component_registry.new(): ComponentRegistry
    local self = setmetatable({}, component_registry)
    self.components = {}
    return (self :: any) :: ComponentRegistry
end

local function deep_clone(t)
    if type(t) ~= "table" then return t end
    
    local clone = {}
    for k, v in t do
        clone[k] = deep_clone(v)
    end
    return clone
end

function component_registry:register(name, defaults)
    if self.components[name] then return end
    self.components[name] = defaults
end

function component_registry:unregister(name)
    if not self.components[name] then warn(`Attempt to unregister non-existant component {name}`); return end

    self.components[name] = nil
end

function component_registry:get(name)
    local captured_component = self.components[name]
    if not captured_component then warn(`Attempt to index nil component with {name}`); return end

    return table.clone(captured_component)
end

function component_registry:exists(name)
    return self.components[name] ~= nil
end

function component_registry:get_all()
    local captured_names = {}

    for name, defaults in self.components do
        table.insert(captured_names, name)
    end

    return captured_names
end

function component_registry:count()
    local component_index = 0

    for i, v in self.components do
        component_index+=1
    end

    return component_index
end

function component_registry:clear()
    self.components = {}
end

function component_registry:update_defaults(name, defaults)
    if not self.components[name] then warn(`Component with name: {name} does not exist.`); return end
    self.components[name] = defaults
end

function component_registry:validate(name, data)
    local captured_component = self.components[name]
    if not captured_component then warn(`Component with name: {name} does not exist.`); return end

    for key, _ in captured_component do
        if data[key] == nil then
            warn(`Missing key {key} in data for component {name}`)
            return false
        end
    end
    
    return true
end

function component_registry:get_all_defaults()
    return deep_clone(self.components)
end

function component_registry:to_string()
    local names = self:get_all()
    return `Components: [{table.concat(names, ", ")}]`
end

return component_registry
