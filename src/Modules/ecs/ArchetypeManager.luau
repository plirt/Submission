--!strict

type Entity = number
type Edge = { add: Archetype?, remove: Archetype? }

type Archetype = {
    key: string,
    components: { string },
    entities: { Entity },
    entity_to_row: { [Entity]: number },
    columns: { [string]: { [number]: any } },
    edges: { [string]: Edge },
    versions: {[string]: {[number]: any}},
}

local archetype_manager = {}
archetype_manager.__index = archetype_manager

function archetype_manager.new()
    local self = setmetatable({}, archetype_manager)
    self.archetypes = {}
    self.entity_index = {}
    self.on_archetype_created = nil :: (() -> ())?
    self.component_to_archetypes = {}
    return self
end

local function get_key(component_list)
    local sorted = table.clone(component_list)
    table.sort(sorted)

    return table.concat(sorted, ",")
end

function archetype_manager:get_archetype(entity_id)
    return self.entity_index[entity_id]
end

function archetype_manager:get_or_create(component_list)
    local key = get_key(component_list)
    local captured_archetype = self.archetypes[key]

    if not captured_archetype then
        captured_archetype = {
            key = key;
            components = table.clone(component_list);
            entities = {};
            entity_to_row = {};
            columns = {};
            versions = {};
        }
        self.archetypes[key] = captured_archetype

        if self.on_archetype_created then
            self.on_archetype_created()
        end
        
        for i, v in component_list do
            captured_archetype.columns[v] = {}
            captured_archetype.versions[v] = {}

            self.component_to_archetypes[v] = self.component_to_archetypes[v] or {}
            self.component_to_archetypes[v][key] = captured_archetype
        end
    end

    return captured_archetype
end

function archetype_manager:add_component(entity_id, name, data)
    local current = self:get_archetype(entity_id)

    if current then
        current.edges = current.edges or {}

        if not current.edges[name] then
            current.edges[name] = {} :: Edge
        end

        local edge = current.edges[name] :: Edge

        if not edge.add then
            local new_components = table.clone(current.components)
            table.insert(new_components, name)
            edge.add = self:get_or_create(new_components)
        end

        local new_archetype = edge.add :: Archetype
        local old_row = current.entity_to_row[entity_id]
        local new_row = #new_archetype.entities + 1
        local last_row = #current.entities
        local last_entity = current.entities[last_row]

        for i, v in current.components do
            new_archetype.columns[v][new_row] = current.columns[v][old_row]
        end

        for i, v in current.components do
            current.columns[v][old_row] = current.columns[v][last_row]
            current.columns[v][last_row] = nil
        end

        current.entities[old_row] = last_entity
        current.entity_to_row[last_entity] = old_row
        current.entities[last_row] = nil
        current.entity_to_row[entity_id] = nil

        new_archetype.entities[new_row] = entity_id
        new_archetype.entity_to_row[entity_id] = new_row
        new_archetype.columns[name][new_row] = data
        self.entity_index[entity_id] = new_archetype
    else
        local new_archetype = self:get_or_create({name})
        if not new_archetype then 
            warn("Failed to retrieve or create archetype for entity:", entity_id)
            return 
        end


        local row = #new_archetype.entities + 1
        new_archetype.entities[row] = entity_id
        new_archetype.entity_to_row[entity_id] = row
        new_archetype.columns[name][row] = data
        self.entity_index[entity_id] = new_archetype
    end
end

function archetype_manager:remove_component(entity_id, name)
    local current = self:get_archetype(entity_id)
    if not current then warn(`There is no valid archetype tied to entity id: {entity_id}`); return end

    current.edges = current.edges or {}
    current.edges[name] = current.edges[name] or {}

    if not current.edges[name] then
        current.edges[name] = {} :: Edge
    end
    local edge = current.edges[name] :: Edge

    if not edge.remove then
        local new_components: {string} = {}
        for _, v in current.components do
            if v ~= name then
                table.insert(new_components, v)
            end
        end
        edge.remove = self:get_or_create(new_components)
    end

    local new_archetype = edge.remove
    if not new_archetype then return end

    if #current.components == 1 then
        local old_row = current.entity_to_row[entity_id]
        local last_row = #current.entities
        local last_entity = current.entities[last_row]
        
        for _, v in current.components do
            current.columns[v][old_row] = nil
            current.columns[v][last_row] = nil
        end

        current.entities[old_row] = last_entity
        current.entity_to_row[last_entity] = old_row
        current.entities[last_row] = nil
        current.entity_to_row[entity_id] = nil
        self.entity_index[entity_id] = nil

        self:cleanup_empty()
        return
    end

    local old_row = current.entity_to_row[entity_id]
    local new_row = #new_archetype.entities + 1

    for i, v in current.components do
        local component_name = v :: string 
    
        if component_name ~= name then
            new_archetype.columns[component_name][new_row] = current.columns[component_name][old_row]
        end
    end

    local last_row = #current.entities
    local last_entity = current.entities[last_row]

    current.entities[old_row] = last_entity
    current.entity_to_row[last_entity] = old_row

    current.entities[last_row] = nil
    current.entity_to_row[entity_id] = nil

    for i, v in current.components do
        current.columns[v][old_row] = current.columns[v][last_row]
        current.columns[v][last_row] = nil
    end

    new_archetype.entities[new_row] = entity_id
    new_archetype.entity_to_row[entity_id] = new_row

    self.entity_index[entity_id] = new_archetype
end

function archetype_manager:get_component(entity_id, name)
    local current = self:get_archetype(entity_id)
    if not current then warn(`There is no valid archetype tied to entity id: {entity_id}`); return end
    if not current.columns[name] then warn("Component doesn't exist"); return end
    local row = current.entity_to_row[entity_id]
    return current.columns[name][row]
end

function archetype_manager:has_component(entity_id, name)
    local current = self:get_archetype(entity_id)
    if not current then return false end
    local row = current.entity_to_row[entity_id]
    return current.columns[name] ~= nil and current.columns[name][row] ~= nil
end

function archetype_manager:add_components(entity_id, components)
    local current = self:get_archetype(entity_id)
    local new_components = {}
    if current then
        for _, name in current.components do
            table.insert(new_components, name)
        end
    end
    for name, _ in components do
        table.insert(new_components, name)
    end

    local new_archetype = self:get_or_create(new_components)

    if current then
        local old_row = current.entity_to_row[entity_id]
        local new_row = #new_archetype.entities + 1
        local last_row = #current.entities
        local last_entity = current.entities[last_row]

        for _, name in current.components do
            new_archetype.columns[name][new_row] = current.columns[name][old_row]
        end

        for _, name in current.components do
            current.columns[name][old_row] = current.columns[name][last_row]
            current.columns[name][last_row] = nil
        end

        current.entities[old_row] = last_entity
        current.entity_to_row[last_entity] = old_row
        current.entities[last_row] = nil
        current.entity_to_row[entity_id] = nil

        for name, data in components do
            new_archetype.columns[name][new_row] = data
        end

        new_archetype.entities[new_row] = entity_id
        new_archetype.entity_to_row[entity_id] = new_row
    else
        local row = #new_archetype.entities + 1
        for name, data in components do
            new_archetype.columns[name][row] = data
        end
        new_archetype.entities[row] = entity_id
        new_archetype.entity_to_row[entity_id] = row
    end

    self.entity_index[entity_id] = new_archetype
end

function archetype_manager:get_all_components(entity_id): { [string]: any }?
    local current = self:get_archetype(entity_id)
    if not current then return nil end
    local row = current.entity_to_row[entity_id]
    local entity_components: { [string]: any } = {}
    for component_name, column in current.columns do
        if column[row] ~= nil then
            entity_components[component_name] = column[row]
        end
    end
    return entity_components
end

function archetype_manager:remove_entity(entity_id)
    local current = self:get_archetype(entity_id)
    if not current then return end
    local old_row = current.entity_to_row[entity_id]
    local last_row = #current.entities
    local last_entity = current.entities[last_row]
    current.entities[old_row] = last_entity
    current.entity_to_row[last_entity] = old_row
    current.entities[last_row] = nil
    current.entity_to_row[entity_id] = nil
    for component_name, column in current.columns do
        column[old_row] = column[last_row]
        column[last_row] = nil
    end
    self.entity_index[entity_id] = nil
    self:cleanup_empty()
end

function archetype_manager:clear()
    self.archetypes = {}
    self.entity_index = {}
    self.component_to_archetypes = {}
end

function archetype_manager:entity_count()
    local entity_index = 0
    for i, archetype in self.archetypes do
        entity_index += #archetype.entities
    end

    return entity_index
end

function archetype_manager:archetype_count()
    local archetype_index = 0
    for i, v in self.archetypes do
        archetype_index += 1
    end

    return archetype_index
end

function archetype_manager:cleanup_empty()
    for i, archetype in self.archetypes do
        if #archetype.entities == 0 then
            for _, component_name in archetype.components do
                if self.component_to_archetypes[component_name] then
                    self.component_to_archetypes[component_name][i] = nil
                end
            end

            self.archetypes[i] = nil
        end
    end
end

function archetype_manager:to_string()
    return `Archetypes: {self:archetype_count()} | Entities: {self:entity_count()}`
end

function archetype_manager:get_sibling_entities(entity_id)
    local current = self:get_archetype(entity_id)
    if not current then return nil end

    return current.entities
end

function archetype_manager:move_entity(entity_id, target_archetype_key)
    local captured_archetype = self.archetypes[target_archetype_key]
    if not captured_archetype then return end
    local current = self:get_archetype(entity_id)
    if not current then return end

    for _, name in current.components do
        if not captured_archetype.columns[name] then
            warn(`Cannot move entity {entity_id}: target archetype missing component {name}`)
            return
        end
    end

    local old_row = current.entity_to_row[entity_id]
    local new_row = #captured_archetype.entities + 1

    for component_name, column in current.columns do
        captured_archetype.columns[component_name][new_row] = column[old_row]
    end

    local last_row = #current.entities
    local last_entity = current.entities[last_row]

    for component_name, column in current.columns do
        column[old_row] = column[last_row]
        column[last_row] = nil
    end

    current.entities[old_row] = last_entity
    current.entity_to_row[last_entity] = old_row
    current.entities[last_row] = nil
    current.entity_to_row[entity_id] = nil

    captured_archetype.entities[new_row] = entity_id
    captured_archetype.entity_to_row[entity_id] = new_row
    self.entity_index[entity_id] = captured_archetype
end

function archetype_manager:get_archetypes_with(name)
    return self.component_to_archetypes[name] or {}
end

function archetype_manager:clone_entity(entity_id, new_entity_id)
    local all_components = self:get_all_components(entity_id)
    if not all_components then return end

    self:add_components(new_entity_id, all_components)
end

function archetype_manager:update_component(entity_id, name, data)
    local current = self:get_archetype(entity_id)
    if not current then return end
    if not current.columns[name] then warn(`Column with name {name} does not exist`); return end
    local row = current.entity_to_row[entity_id]
    local old = current.columns[name][row]

    local changed = false
    for i, v in data do
        if old[i] ~= v then
            changed = true
            break
        end
    end

    if changed then
        current.columns[name][row] = data
        current.versions[name][row] = (current.versions[name][row] or 0) + 1
    end
end

return archetype_manager
