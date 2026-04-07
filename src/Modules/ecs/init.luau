--!strict

local world = {}
world.__index = world

local ENTITY_MANAGER = require(script.EntityManager)
local COMPONENT_REGISTRY = require(script.ComponentRegistry)
local ARCHETYPE_MANAGER = require(script.ArchetypeManager)
local QUERY_SYSTEM = require(script.QuerySystem)
local SYSTEM_MANAGER = require(script.SystemManager)
local CHANGE_DETECTION = require(script.ChangeDetection)
local SERIALIZER = require(script.Serializer)

function world.new()
    local self = setmetatable({}, world)

    self.entity_manager = ENTITY_MANAGER.new() 
    self.component_registry = COMPONENT_REGISTRY.new()
    self.archetype_manager = ARCHETYPE_MANAGER.new()
    self.system_manager = SYSTEM_MANAGER.new()
    self.change_detection = CHANGE_DETECTION.new()

    self.query_system = QUERY_SYSTEM
    self.serializer = SERIALIZER

    self._query_cache = {}
    self._last_versions = {}

    self.archetype_manager.on_archetype_created = function()
        self._query_cache = {}
    end

    return self
end

function world:create_entity()
    return self.entity_manager:create()
end

function world:destroy_entity(id)
    self.entity_manager:destroy(id)
end

function world:is_alive(id)
    return self.entity_manager:is_alive(id)
end

function world:get_all_entities()
    return self.entity_manager:get_all()
end

function world:entity_count()
    return self.entity_manager:count()
end

function world:create_entities(count)
    return self.entity_manager:get_batch(count)
end

function world:destroy_entities(ids)
    self.entity_manager:destroy_batch(ids)
end

function world:destroy_all_entities()
    self.entity_manager:destroy_all()
end

function world:random_entity()
    return self.entity_manager:get_random()
end

function world:is_valid(id)
    return self.entity_manager:is_valid(id)
end

function world:register_component(name, defaults)
    self.component_registry:register(name, defaults)
end

function world:unregister_component(name)
    self.component_registry:unregister(name)
end

function world:add_component(entity_id, name, data)
    if not self.component_registry:exists(name) then
        warn(`Attempt to add unregistered component: {name}`)
        return
    end
    local component_data = data or self.component_registry:get(name)
    self.archetype_manager:add_component(entity_id, name, component_data)
    self.change_detection:fire_added(name, entity_id, component_data)
end

function world:add_components(entity_id, components)
    for name, data in components do
        self:add_component(entity_id, name, data)
    end
end

function world:remove_component(entity_id, name)
    self.change_detection:fire_removed(name, entity_id)
    self.archetype_manager:remove_component(entity_id, name)
end

function world:get_component(entity_id, name)
    return self.archetype_manager:get_component(entity_id, name)
end

function world:has_component(entity_id, name)
    return self.archetype_manager:has_component(entity_id, name)
end

function world:update_component(entity_id, name, data)
    self.archetype_manager:update_component(entity_id, name, data)
end

function world:get_all_components(entity_id)
    return self.archetype_manager:get_all_components(entity_id)
end

function world:clone_entity(entity_id, new_entity_id)
    self.archetype_manager:clone_entity(entity_id, new_entity_id)
end

function world:remove_entity(entity_id)
    self.archetype_manager:remove_entity(entity_id)
    self.entity_manager:destroy(entity_id)
    self._last_versions[entity_id] = nil
end

function world:get_all_components_registered()
    return self.component_registry:get_all()
end

function world:update_defaults(name, defaults)
    self.component_registry:update_defaults(name, defaults)
end

function world:validate_component(name, data)
    return self.component_registry:validate(name, data)
end

function world:query(...)
    local key = table.concat({...}, ",")
    if not self._query_cache[key] then
        local q = self.query_system:new(self.archetype_manager):with(...)
        q._last_versions = self._last_versions
        self._query_cache[key] = q
    end
    return self._query_cache[key]
end

function world:register_system(system, priority)
    self.system_manager:register(system, priority)
end

function world:unregister_system(system)
    self.system_manager:unregister(system)
end

function world:enable_system(system)
    self.system_manager:enable(system)
end

function world:disable_system(system)
    self.system_manager:disable(system)
end

function world:enable_all_systems()
    self.system_manager:enable_all()
end

function world:disable_all_systems()
    self.system_manager:disable_all()
end

function world:set_system_priority(system, priority)
    self.system_manager:set_priority(system, priority)
end

function world:update(dt)
    self.system_manager:update(dt)
end

function world:on_added(component_name, callback)
    self.change_detection:on_added(component_name, callback)
end

function world:on_removed(component_name, callback)
    self.change_detection:on_removed(component_name, callback)
end

function world:once(component_name, callback)
    self.change_detection:once(component_name, callback)
end

function world:clear_hooks(component_name)
    self.change_detection:clear(component_name)
end

function world:clear_all_hooks()
    self.change_detection:clear_all()
end

function world:serialize()
    return self.serializer:serialize(self.archetype_manager)
end

function world:deserialize(snapshot)
    self.serializer:deserialize(snapshot, self.archetype_manager)
end

function world:serialize_entity(entity_id)
    return self.serializer:serialize_entity(entity_id, self.archetype_manager)
end

function world:deserialize_entity(entity_id, data)
    self.serializer:deserialize_entity(entity_id, data, self.archetype_manager)
end

function world:merge_snapshots(a, b)
    return self.serializer:merge(a, b)
end

function world:clear()
    self.archetype_manager:clear()
    self.entity_manager:clear()
    self.change_detection:clear_all()
    self.system_manager:clear()
end

function world:cleanup()
    self.archetype_manager:cleanup_empty()
end

function world:to_string()
    return self.archetype_manager:to_string()
end

return world
