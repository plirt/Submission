--!strict

local query_system = {}

function query_system:new(archetype_manager)
    local instance = {
        archetype_manager = archetype_manager;
        _required = {};
        _without = {};
        _changed = {};
        _last_versions = {};
        _cached = nil;
    }
    setmetatable(instance, { __index = query_system })
    return instance
end

function query_system:with(...)
    local new = query_system:new(self.archetype_manager)
    for _, v in self._required do
        table.insert(new._required, v)
    end
    for _, v in {...} do
        table.insert(new._required, v)
    end
    return new
end

function query_system:without(...)
    local new = query_system:new(self.archetype_manager)
    for _, v in self._without do
        table.insert(new._without, v)
    end
    for _, v in {...} do
        table.insert(new._without, v)
    end
    return new
end

function query_system:match()
    if self._cached then return self._cached end
    if #self._required == 0 then return {} end

    local candidates = self.archetype_manager:get_archetypes_with(self._required[1])
    local included_archetypes = {}

    for i, archetype in candidates do
        local valid = true

        for _, requirement in self._required do
            if not archetype.columns[requirement] then valid = false; break end
        end

        for _, requirement in self._without do
            if archetype.columns[requirement] then valid = false; break end
        end

        if valid then
            table.insert(included_archetypes, archetype)
        end
    end
    
    self._cached = included_archetypes
    return self._cached
end

function query_system:changed(...)
    for _, v in {...} do
        table.insert(self._changed, v)
    end
    return self
end

function query_system:iter(callback)
    local matched = self:match()
    local results = {}
    for i, archetype in matched do
        local snapshot = table.clone(archetype.entities)
        for row, entity_id in snapshot do
            if not entity_id then continue end

            local should_yield = #self._changed == 0
            if not should_yield then
                for _, name in self._changed do
                    local current_version = archetype.versions[name] and archetype.versions[name][row] or 0
                    local last_version = self._last_versions[entity_id] and self._last_versions[entity_id][name] or -1
                    if current_version ~= last_version then
                        should_yield = true
                        self._last_versions[entity_id] = self._last_versions[entity_id] or {}
                        self._last_versions[entity_id][name] = current_version
                        break
                    end
                end
            end

            if should_yield then
                for j, requirement in self._required do
                    if archetype.columns[requirement] then
                        results[j] = archetype.columns[requirement][row]
                    end
                end
                callback(entity_id, results)
            end
        end
    end
end

function query_system:count()
    local archetypes = self:match()
    local index = 0
    for i, archetype in archetypes do
        index += #archetype.entities
    end
    return index
end

function query_system:first()
    for _, archetype in self:match() do
        if #archetype.entities > 0 then
            return archetype.entities[1]
        end
    end
    return nil
end

function query_system:to_table()
    local results = {}

    self:iter(function(entity_id, components)
        table.insert(results, { entity_id = entity_id, components = components })
    end)

    return results
end

function query_system:reset()
    self._required = {}
    self._without = {}
    self._cached = nil

    return self
end

function query_system:is_empty()
    for _, archetype in self:match() do
        if #archetype.entities > 0 then
            return false
        end
    end
    return true
end

function query_system:to_string()
    local required_str = table.concat(self._required, ", ")
    local without_str = table.concat(self._without, ", ")
    return `Query: [{required_str}] without [{without_str}] | Matches: {self:count()}`
end

return query_system
