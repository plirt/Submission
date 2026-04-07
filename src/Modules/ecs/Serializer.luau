--!strict

type Entity = number
type ComponentData = { [string]: any }
type Snapshot = { [Entity]: ComponentData }

export type Serializer = {
	serialize: (self: Serializer, archetype_manager: any) -> Snapshot,
	deserialize: (self: Serializer, snapshot: any, archetype_manager: any) -> (),
	serialize_entity: (self: Serializer, entity_id: Entity, archetype_manager: any) -> ComponentData?,
	deserialize_entity: (self: Serializer, entity_id: Entity, data: ComponentData?, archetype_manager: any) -> (),
	validate: (self: Serializer, snapshot: any) -> boolean,
	clear: (self: Serializer, archetype_manager: any) -> (),
	merge: (self: Serializer, snapshot_a: Snapshot, snapshot_b: Snapshot) -> Snapshot,
	count: (self: Serializer, snapshot: Snapshot) -> number,
	to_string: (self: Serializer, snapshot: Snapshot) -> string,
}

local serializer = {} :: Serializer

function serializer:serialize(archetype_manager)
    local snapshots = {}
    for entity_id, archetype in archetype_manager.entity_index do
        snapshots[entity_id] = {}
        local row = archetype.entity_to_row[entity_id]
        for i, component in archetype.components do
            snapshots[entity_id][component] = archetype.columns[component][row]
        end
    end
    return snapshots
end

function serializer:deserialize(snapshot, archetype_manager)
    if not self:validate(snapshot) then return end

    for entity_id, components in snapshot do
        archetype_manager:add_components(entity_id, components)
    end
end

function serializer:serialize_entity(entity_id, archetype_manager)
    local archetype = archetype_manager:get_archetype(entity_id)
    if not archetype then return nil end
    local row = archetype.entity_to_row[entity_id]
    local data: ComponentData = {}
    for i, component in archetype.components do
        data[component] = archetype.columns[component][row]
    end
    return data
end

function serializer:deserialize_entity(entity_id, data, archetype_manager)
    if not data then return end

    for component, component_data in data do
        archetype_manager:add_component(entity_id, component, component_data)
    end
end

function serializer:validate(snapshot)
    if not snapshot then warn("Snapshot is nil"); return false end
    if type(snapshot) ~= "table" then warn("Snapshot is not a table"); return false end

    for entity_id, components in snapshot do
        if type(components) ~= "table" then
            warn(`Entity {entity_id} has invalid data`)
            return false
        end
    end

    return true
end

function serializer:clear(archetype_manager)
    archetype_manager:clear()
end

function serializer:merge(snapshot_a, snapshot_b)
    local merged = table.clone(snapshot_a)

    for entity_id, components in snapshot_b do
        if merged[entity_id] then
            for component, data in components do
                merged[entity_id][component] = data
            end
        else
            merged[entity_id] = components
        end
    end

    return merged
end

function serializer:count(snapshot)
    local entity_index = 0

    for i, v in snapshot do
        entity_index += 1
    end

    return entity_index
end

function serializer:to_string(snapshot)
    return `Snapshot: {self:count(snapshot)} entities`
end

return serializer
