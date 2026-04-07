--!strict

local change_detection = {}
change_detection.__index = change_detection

function change_detection.new()
    local self = setmetatable({}, change_detection)
    self.hooks = {}
    return (self :: any)
end

local function ensure_hook(hooks, component_name)
    if not hooks[component_name] then
        hooks[component_name] = {
            added = {};
            removed = {};
        }
    end
end

function change_detection:on_added(component_name, callback)
    ensure_hook(self.hooks, component_name)
    table.insert(self.hooks[component_name].added, callback)
end

function change_detection:on_removed(component_name, callback)
    ensure_hook(self.hooks, component_name)
    table.insert(self.hooks[component_name].removed, callback)
end

function change_detection:fire_added(component_name, entity_id, data)
    local captured_hook = self.hooks[component_name]
    if not captured_hook then return end

    for i, callback in captured_hook.added do
        callback(entity_id, data)
    end
end

function change_detection:fire_removed(component_name, entity_id)
    local captured_hook = self.hooks[component_name]
    if not captured_hook then return end

    for i, callback in captured_hook.removed do
        callback(entity_id)
    end
end

function change_detection:once(component_name, callback)
    local wrapper = nil
    wrapper = function(entity_id, data)
        callback(entity_id, data)

        local hooks = self.hooks[component_name]
        if hooks then
            table.remove(hooks.added, table.find(hooks.added, wrapper))
        end
    end
    self:on_added(component_name, wrapper)
end

function change_detection:clear(component_name)
    self.hooks[component_name] = nil
end

function change_detection:clear_all()
    self.hooks = {}
end

function change_detection:has_hooks(component_name)
    return self.hooks[component_name] ~= nil
end

function change_detection:count(component_name)
    local hook = self.hooks[component_name]
    if not hook then return 0 end
    return #hook.added + #hook.removed
end

function change_detection:fire_all(entity_id)
    for component, hook in self.hooks do
        for i, callback in hook.added do
            callback(entity_id)
        end
    end
end

function change_detection:to_string()
    local count = 0
    for _ in self.hooks do
        count += 1
    end
    return `Hooks: {count} components registered`
end

return change_detection
