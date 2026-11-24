-- Subpágina de edición de un evento: fecha, hora, lugar y descripción.
-- Cada campo se muestra en la página; al tocarlo se escribe con el teclado.

local Blitbuffer = require("ffi/blitbuffer")
local ButtonTable = require("ui/widget/buttontable")
local Device = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local Size = require("ui/size")
local InputContainer = require("ui/widget/container/inputcontainer")
local TitleBar = require("ui/widget/titlebar")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")

local U = require("calendario_util")
local W = require("calendario_widgets")

local Editor = InputContainer:extend{
    name = "calendario_editor",
    covers_fullscreen = true,
    ctx = nil,
    date = nil,      -- AAAA-MM-DD (fecha inicial del evento nuevo)
    event = nil,     -- evento existente (nil = nuevo)
    on_change = nil, -- se llama tras guardar o eliminar
}

function Editor:init()
    -- Si hay barra de ZenOS abajo, no la tapamos (y dejamos que se pinte lo de atrás).
    self.dimen, self.covers_fullscreen = self.ctx:viewDimen()
    if self.event then
        self.draft = {
            id = self.event.id,
            date = self.event.date,
            time = self.event.time,
            time_end = self.event.time_end,
            place = self.event.place,
            desc = self.event.desc,
            color = self.event.color,
        }
    else
        self.draft = { date = self.date, time = "", time_end = "", place = "", desc = "", color = "" }
    end
    self.original = {
        date = self.draft.date, time = self.draft.time, time_end = self.draft.time_end,
        place = self.draft.place, desc = self.draft.desc, color = self.draft.color,
    }
    if Device:hasKeys() then
        self.key_events = { Close = { { Device.input.group.Back } } }
    end
    self.ctx:setupView(self)
    self:update()
end

function Editor:isDirty()
    local d, o = self.draft, self.original
    return d.date ~= o.date or d.time ~= o.time or d.time_end ~= o.time_end or d.place ~= o.place or d.desc ~= o.desc or d.color ~= o.color
end

function Editor:update()
    local ctx = self.ctx
    local w, h = self.dimen.w, self.dimen.h
    if self.title_bar then self.title_bar:free() end
    if self.bar then self.bar:free() end
    for _, r in ipairs(self.rows or {}) do r:free() end
    self.rows = {}

    self.has_color = (self.draft.color or "") ~= ""
    self.title_bar = TitleBar:new{
        width = w,
        fullscreen = true,
        title = ctx:t(self.event and "edit_event" or "new_event"),
        with_bottom_line = true,
        close_callback = function() self:tryClose() end,            -- X: vista anterior
        show_parent = self,
    }

    local function field(label, value, placeholder, multiline, cb, swatch, swatch_none)
        local row = W.FieldRow:new{
            label = label, value = value, placeholder = placeholder,
            multiline = multiline, width = w, callback = cb, swatch = swatch,
            swatch_none = swatch_none,
        }
        self.rows[#self.rows + 1] = row
        return row
    end

    local lang = ctx:lang()
    local group = VerticalGroup:new{ align = "left", self.title_bar }
    table.insert(group, field(ctx:t("f_date"), U.longDate(lang, self.draft.date), "", false,
        function() self:editDate() end))
    table.insert(group, field(ctx:t("f_time"), U.formatRange(self.draft.time, self.draft.time_end), ctx:t("set_time"), false,
        function() self:editTime() end))
    table.insert(group, field(ctx:t("f_desc"), self.draft.desc, ctx:t("add_desc"), true,
        function() self:editDesc() end))
    table.insert(group, field(ctx:t("f_place"), self.draft.place, ctx:t("add_place"), false,
        function() self:editPlace() end))
    local cdef = U.colorDef(self.draft.color)
    -- Sin color: solo el círculo con la diagonal; con color: el círculo y su nombre.
    table.insert(group, field(ctx:t("f_color"), cdef and ctx:t("color_" .. cdef.key) or "", "", false,
        function() self:editColor() end, W.colorOf(self.draft.color), cdef == nil))

    local left_button
    if self.event then
        left_button = { text = ctx:t("delete"), callback = function() self:confirmDelete() end }
    else
        left_button = { text = ctx:t("cancel"), callback = function() self:tryClose() end }
    end
    self.bar = ButtonTable:new{
        width = w,
        show_parent = self,
        buttons = {{
            left_button,
            { text = ctx:t("save"), callback = function() self:save() end },
        }},
    }

    W.squareButtons(self.bar)
    local used = self.title_bar:getHeight()
    for _, r in ipairs(self.rows) do used = used + r.dimen.h end
    local sep_h = Size.line.medium
    table.insert(group, VerticalSpan:new{ width = math.max(0, h - used - self.bar:getSize().h - 2 * sep_h) })
    table.insert(group, W.separator(w))     -- encima de los botones
    table.insert(group, self.bar)
    table.insert(group, W.separator(w))     -- y debajo

    self[1] = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 0,
        padding = 0,
        margin = 0,
        group,
    }

    if self._shown then
        self.ctx:refresh(self, self.has_color)
    end
end

function Editor:onShow()
    self._shown = true
    self.ctx:refresh(self, self.has_color)
end

function Editor:onCloseWidget()
    self.ctx:releaseView(self)
    self._shown = false
    self[1] = nil
    if self.title_bar then self.title_bar:free() end
    if self.bar then self.bar:free() end
    for _, r in ipairs(self.rows or {}) do r:free() end
    self.rows, self.title_bar, self.bar = {}, nil, nil
end

function Editor:onClose()
    self:tryClose()
    return true
end

-- X / Cancelar / botón Atrás: volver a la vista anterior (pregunta si hay cambios).
function Editor:tryClose()
    if self._closing then return end
    if self:isDirty() then
        self.ctx:confirm(self.ctx:t("discard_confirm"), self.ctx:t("discard"), function()
            self.ctx:closeView(self)
        end)
    else
        self.ctx:closeView(self)
    end
end

-- ── Edición de campos ──────────────────────────────────────────────────────

function Editor:editDate()
    local ctx = self.ctx
    local y, m, d = U.parseKey(self.draft.date)
    local shown = string.format("%02d/%02d/%04d", d, m, y)
    ctx:askText(ctx:t("f_date"), shown, false, ctx:t("hint_date"), function(v)
        local ny, nm, nd = U.parseDate(v)
        if not ny or not nd then
            ctx:info(ctx:t("invalid_date"), 3)
            return
        end
        self.draft.date = U.dateKey(ny, nm, nd)
        self:update()
    end)
end

function Editor:editTime()
    local Picker = require("calendario_timepicker")
    self.ctx:showDialog(Picker:new{
        ctx = self.ctx,
        time = self.draft.time,
        time_end = self.draft.time_end,
        on_done = function(t, e)
            self.draft.time, self.draft.time_end = t, e
            self:update()
        end,
    })
end

function Editor:editPlace()
    local ctx = self.ctx
    ctx:askText(ctx:t("f_place"), self.draft.place, false, ctx:t("hint_place"), function(v)
        self.draft.place = (v or ""):gsub("^%s+", ""):gsub("%s+$", "")
        self:update()
    end)
end

function Editor:editDesc()
    local ctx = self.ctx
    ctx:askText(ctx:t("f_desc"), self.draft.desc, true, ctx:t("hint_desc"), function(v)
        local s = ((v or ""):gsub("^%s+", ""))
        self.draft.desc = (s:gsub("%s+$", ""))
        self:update()
    end)
end

function Editor:editColor()
    local Picker = require("calendario_colorpicker")
    self.ctx:showDialog(Picker:new{
        ctx = self.ctx,
        color = self.draft.color,
        on_done = function(key)
            self.draft.color = key
            self:update()
        end,
    })
end

-- ── Guardar / eliminar ─────────────────────────────────────────────────────

function Editor:save()
    if self._closing then return end
    local ctx = self.ctx
    local d = self.draft
    if d.time == "" and d.place == "" and d.desc == "" then
        ctx:info(ctx:t("nothing_to_save"), 3)
        return
    end
    ctx.store:put(d)
    if self.on_change then self.on_change() end
    self.ctx:closeView(self)
end

function Editor:confirmDelete()
    if self._closing then return end
    local ctx = self.ctx
    ctx:confirm(ctx:t("delete_confirm"), ctx:t("delete"), function()
        if self._closing then return end
        ctx.store:delete(self.event.id)
        if self.on_change then self.on_change() end
        self.ctx:closeView(self)
    end)
end

return Editor
