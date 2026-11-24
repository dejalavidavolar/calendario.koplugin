-- Subpágina del día: lista de eventos (tocar uno para editarlo) y, debajo del último,
-- la fila "+ Agregar evento". Deslizar izquierda/derecha (o botones físicos) cambia de día.
-- Si la lista no cabe, deslizar hacia arriba/abajo cambia de página.

local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local TitleBar = require("ui/widget/titlebar")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")

local U = require("calendario_util")
local W = require("calendario_widgets")

local DayView = InputContainer:extend{
    name = "calendario_day",
    covers_fullscreen = true,
    ctx = nil,
    date = nil,
    on_change = nil,
    page = 1,
}

function DayView:init()
    -- Si hay barra de ZenOS abajo, no la tapamos (y dejamos que se pinte lo de atrás).
    self.dimen, self.covers_fullscreen = self.ctx:viewDimen()
    self.rows = {}
    self.key_events = {
        NextDay = { { Device.input.group.PgFwd } },
        PrevDay = { { Device.input.group.PgBack } },
    }
    if Device:hasKeys() then
        self.key_events.Close = { { Device.input.group.Back } }
    end
    if Device:isTouchDevice() then
        self.ges_events = {
            Swipe = { GestureRange:new{ ges = "swipe", range = self.dimen } },
        }
    end
    self.ctx:setupView(self)
    self:update()
end

function DayView:releaseWidgets()
    for _, r in ipairs(self.rows) do r:free() end
    self.rows = {}
    if self.title_bar then self.title_bar:free() end
    self.title_bar = nil
end

function DayView:update()
    self:releaseWidgets()
    local w, h = self.dimen.w, self.dimen.h
    local lang = self.ctx:lang()

    -- Filas: un evento por fila y, al final, "+ Agregar evento".
    self.has_color = false
    for _, ev in ipairs(self.ctx.store:getEvents(self.date)) do
        if ev.color ~= "" then self.has_color = true end
        self.rows[#self.rows + 1] = W.EventRow:new{
            ctx = self.ctx,
            ev = ev,
            width = w,
            callback = function() self:editEvent(ev) end,
        }
    end
    self.rows[#self.rows + 1] = W.ActionRow:new{
        text = self.ctx:t("add_event"),
        width = w,
        callback = function() self:addEvent() end,
    }

    local title_probe = TitleBar:new{
        width = w, fullscreen = true, title = U.longDate(lang, self.date), with_bottom_line = true,
    }
    local body_h = h - title_probe:getHeight()
    title_probe:free()

    -- Paginación voraz.
    local pages, cur, cur_h = {}, {}, 0
    for _, r in ipairs(self.rows) do
        local rh = r.dimen.h
        if #cur > 0 and cur_h + rh > body_h then
            pages[#pages + 1] = cur
            cur, cur_h = {}, 0
        end
        cur[#cur + 1] = r
        cur_h = cur_h + rh
    end
    if #cur > 0 then pages[#pages + 1] = cur end
    self.npages = math.max(1, #pages)
    self.page = math.min(math.max(self.page, 1), self.npages)

    local title = U.longDate(lang, self.date)
    if self.npages > 1 then
        title = string.format("%s  (%d/%d)", title, self.page, self.npages)
    end
    self.title_bar = TitleBar:new{
        width = w,
        fullscreen = true,
        title = title,
        with_bottom_line = true,
        close_callback = function() self:onClose() end,             -- X: vista anterior
        show_parent = self,
    }

    local group = VerticalGroup:new{ align = "left", self.title_bar }
    for _, r in ipairs(pages[self.page] or {}) do
        table.insert(group, r)
    end

    self[1] = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 0,
        padding = 0,
        margin = 0,
        width = w,
        height = h,
        group,
    }

    if self._shown then
        self.ctx:refresh(self, self.has_color)
    end
end

-- ── Navegación ─────────────────────────────────────────────────────────────

function DayView:gotoDay(delta)
    self.date = U.addDays(self.date, delta)
    self.page = 1
    self:update()
end

function DayView:gotoPage(p)
    if p < 1 or p > self.npages then return end
    self.page = p
    self:update()
end

function DayView:onNextDay()
    self:gotoDay(1)
    return true
end

function DayView:onPrevDay()
    self:gotoDay(-1)
    return true
end

function DayView:onSwipe(arg, ges)
    local dir = ges.direction
    if dir == "west" then
        self:gotoDay(1)      -- deslizar hacia la izquierda → día siguiente
        return true
    elseif dir == "east" then
        self:gotoDay(-1)     -- deslizar hacia la derecha → día anterior
        return true
    elseif dir == "north" then
        self:gotoPage(self.page + 1)
        return true
    elseif dir == "south" then
        self:gotoPage(self.page - 1)
        return true
    end
end

function DayView:onShow()
    self._shown = true
    self.ctx:refresh(self, self.has_color)
end

function DayView:onCloseWidget()
    self.ctx:releaseView(self)
    self._shown = false
    self[1] = nil
    self:releaseWidgets()
end

function DayView:onClose()
    self.ctx:closeView(self)
    return true
end

-- Tras guardar/eliminar en el editor: refrescar el mes de fondo y esta lista.
-- Si se eliminó el último evento del día, se vuelve al calendario.
function DayView:changed(deleted_last_check)
    if self.on_change then self.on_change() end
    if deleted_last_check and #self.ctx.store:getEvents(self.date) == 0 then
        self.ctx:closeView(self)
    else
        self:update()
    end
end

function DayView:addEvent()
    local Editor = require("calendario_editor")
    UIManager:show(Editor:new{
        ctx = self.ctx,
        date = self.date,
        on_change = function() self:changed(false) end,
    })
end

function DayView:editEvent(ev)
    local Editor = require("calendario_editor")
    UIManager:show(Editor:new{
        ctx = self.ctx,
        date = self.date,
        event = ev,
        on_change = function() self:changed(true) end,
    })
end

return DayView
