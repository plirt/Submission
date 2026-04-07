--!strict

local entity_manager = {}
entity_manager.__index = entity_manager

local maximum_entity_count = (2^20)

export type EntityManager = typeof(setmetatable({} :: {
    next_id: number,
    pool: { number },
    alive: { [number]: boolean },
    _count: number,
    generations: {[number]: number},
}, entity_manager))

function entity_manager.new(): EntityManager
    local self = setmetatable({}, entity_manager)
    
    self.next_id = 0
    self.pool = {}
    self.alive = {}
    self._count = 0
    self.generations = {}

    return self
end

function entity_manager.create(self: EntityManager): number
    if #self.pool > 0 then
        local index = table.remove(self.pool) :: number
        local gen = self.generations[index] or 0
        local id = gen * maximum_entity_count + index
        self.alive[id] = true
        return id
    end
    self.next_id += 1
    local index = self.next_id
    local gen = self.generations[index] or 0
    local id = gen * maximum_entity_count + index
    self.alive[id] = true
    self._count += 1
    return id
end

function entity_manager.destroy(self: EntityManager, id: number)
    if not self.alive[id] then return end

    self.alive[id] = nil
    self._count -= 1

    local index = id % maximum_entity_count
    self.generations[index] = (self.generations[index] or 0) + 1
    table.insert(self.pool, index)
end

function entity_manager:is_alive(id): boolean
    return self.alive[id] ~= nil
end

function entity_manager:get_all()
    local captured_ids = table.create(self._count)

    for entity_id, v in self.alive do
        table.insert(captured_ids, entity_id)
    end

    return captured_ids
end

function entity_manager:get_all_dead()
    return table.clone(self.pool)
end

function entity_manager:count(): number
    return self._count
end

function entity_manager:clear()
    self.alive = {}
    self.pool = {}
    self.next_id = 0
    self._count = 0
    self.generations = {}
end

function entity_manager:is_valid(id)
    if id == nil then return false end
    if typeof(id) ~= "number" then return false end

    local index = id % maximum_entity_count
    local gen = math.floor(id / maximum_entity_count)
    local current_gen = self.generations[index] or 0

    return gen == current_gen and self.alive[id] ~= nil
end

function entity_manager:get_first()
    for entity_id in self.alive do
        return entity_id
    end
    return nil
end

function entity_manager:get_batch(count)
    local batched_ids = {}

    for i=1, count do
        table.insert(batched_ids, self:create())
    end

    return batched_ids
end

function entity_manager:destroy_batch(batch)
    for i, id in batch do
        self:destroy(id)
    end
end

function entity_manager:is_empty(): boolean
    return self._count == 0
end

function entity_manager:recycle_count()
    return #self.pool
end

function entity_manager:get_random()
    local all = self:get_all()
    if #all == 0 then return nil end
    return all[math.random(#all)]
end

function entity_manager:destroy_all()
    for entity_id, v in self:get_all() do
        self:destroy(entity_id)
    end
end

function entity_manager:get_range(min, max)
    local captured_ids = {}

    for entity_id in self.alive do
        local index = entity_id % maximum_entity_count
        if index >= min and index <= max then
            table.insert(captured_ids, entity_id)
        end
    end

    return captured_ids
end

function entity_manager:contains(id)
    if self.alive[id] then return true end
    if table.find(self.pool, id) then return true end

    return false
end

function entity_manager:pool_to_string()
    return `Pool: [{table.concat(self.pool, ", ")}]`
end

function entity_manager:to_string()
    local all = self:get_all()
    return `Alive: [{table.concat(all, ", ")}] | Count: {self:count()}`
end

return entity_manager
