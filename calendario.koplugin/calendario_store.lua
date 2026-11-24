-- Almacenamiento local de eventos (JSON) con fusión por evento (último gana).
-- Cada evento: id, date (AAAA-MM-DD), time (HH:MM o ""), place, desc,
--              created, updated (epoch), deleted (tombstone para sincronizar borrados).

local json = require("json")

local Store = {}
Store.__index = Store

math.randomseed(os.time())

local function newId()
    return string.format("%d%06d", os.time(), math.random(0, 999999))
end

local function str(v)
    if type(v) == "string" then return v end
    return ""
end

local function sanitize(ev)
    return {
        id = str(ev.id),
        date = str(ev.date),
        time = str(ev.time),
        time_end = str(ev.time_end),
        place = str(ev.place),
        desc = str(ev.desc),
        color = str(ev.color),
        created = tonumber(ev.created) or 0,
        updated = tonumber(ev.updated) or 0,
        deleted = ev.deleted == true,
    }
end

local function sortEvents(a, b)
    if a.time ~= b.time then return a.time < b.time end
    if a.created ~= b.created then return a.created < b.created end
    return a.id < b.id
end

function Store:new(path)
    local o = setmetatable({ path = path, events = {}, by_date = nil }, self)
    o:load()
    return o
end

function Store:load()
    self.events = {}
    self.by_date = nil
    local f = io.open(self.path, "rb")
    if not f then return end
    local content = f:read("*a")
    f:close()
    local ok, data = pcall(json.decode, content)
    if not ok or type(data) ~= "table" or type(data.events) ~= "table" then return end
    for _, ev in ipairs(data.events) do
        if type(ev) == "table" and str(ev.id) ~= "" then
            self.events[ev.id] = sanitize(ev)
        end
    end
end

function Store:list()
    local list = {}
    for _, ev in pairs(self.events) do list[#list + 1] = ev end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

function Store:serialize()
    local ok, s = pcall(json.encode, { version = 1, events = self:list() })
    if ok then return s end
    return nil
end

function Store:save()
    local s = self:serialize()
    if not s then return false end
    local tmp = self.path .. ".tmp"
    local f = io.open(tmp, "wb")
    if not f then return false end
    f:write(s)
    f:close()
    os.remove(self.path)
    return os.rename(tmp, self.path) and true or false
end

function Store:_index()
    if self.by_date then return end
    self.by_date = {}
    for _, ev in pairs(self.events) do
        if not ev.deleted and ev.date ~= "" then
            local day = self.by_date[ev.date]
            if not day then
                day = {}
                self.by_date[ev.date] = day
            end
            day[#day + 1] = ev
        end
    end
    for _, day in pairs(self.by_date) do table.sort(day, sortEvents) end
end

-- Lista ordenada de eventos vivos de un día (no modificar los elementos).
function Store:getEvents(date)
    self:_index()
    return self.by_date[date] or {}
end

-- Inserta o actualiza. `ev` es un borrador (id nil para nuevo). Devuelve el evento guardado.
function Store:put(ev)
    local now = os.time()
    local prev = ev.id and self.events[ev.id] or nil
    local rec = sanitize(ev)
    if rec.id == "" then
        rec.id = newId()
        rec.created = now
    elseif prev then
        rec.created = prev.created
    end
    rec.updated = math.max(now, (prev and prev.updated or 0) + 1)
    rec.deleted = false
    self.events[rec.id] = rec
    self.by_date = nil
    self:save()
    return rec
end

function Store:delete(id)
    local rec = self.events[id]
    if not rec then return end
    rec.deleted = true
    rec.time, rec.time_end, rec.place, rec.desc, rec.color = "", "", "", "", ""
    rec.updated = math.max(os.time(), rec.updated + 1)
    self.by_date = nil
    self:save()
end

-- Fusiona la lista remota en la local. Devuelve true si algo cambió.
function Store:mergeRemote(remote_list)
    local changed = false
    for _, r in ipairs(remote_list or {}) do
        if type(r) == "table" and str(r.id) ~= "" then
            local l = self.events[r.id]
            if not l or (tonumber(r.updated) or 0) > l.updated then
                self.events[r.id] = sanitize(r)
                changed = true
            end
        end
    end
    if changed then
        self.by_date = nil
        self:save()
    end
    return changed
end

-- ¿Hay algo local que el remoto no tenga (o que sea más nuevo)?
function Store:needsUpload(remote_list)
    local rmap = {}
    for _, r in ipairs(remote_list or {}) do
        if type(r) == "table" and str(r.id) ~= "" then rmap[r.id] = r end
    end
    for id, l in pairs(self.events) do
        local r = rmap[id]
        if not r or l.updated > (tonumber(r.updated) or 0) then return true end
    end
    return false
end

return Store
