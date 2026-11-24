local Dispatcher = require("dispatcher")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local Calendario = WidgetContainer:extend{
    name = "calendario",
    is_doc_only = false,
}

function Calendario:onDispatcherRegisterActions()
    Dispatcher:registerAction("calendario_open", {
        category = "none",
        event = "OpenCalendario",
        title = _("Calendario"),
        general = true,
    })
end

function Calendario:init()
    self:onDispatcherRegisterActions()
    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
end

function Calendario:addToMainMenu(menu_items)
    menu_items.calendario = {
        text = _("Calendario"),
        sorting_hint = "more_tools",
        callback = function() self:onOpenCalendario() end,
    }
end

function Calendario:onOpenCalendario()
    if not self.ctx then
        self.ctx = require("calendario_ctx"):new()
    end
    self.ctx.ui = self.ui   -- para abrir el menú de KOReader/ZenOS desde la barra de título
    -- Si ya hay vistas del calendario abiertas (p. ej. se abrió el menú de ZenOS encima), se
    -- cierran antes de abrir otra, para no apilar calendarios.
    self.ctx:closeAllViews()
    -- Recuerda la última vista: si fue la semanal, se abre directamente (sin pasar por el mes).
    if self.ctx:lastView() == "week" then
        local WeekView = require("calendario_week")
        UIManager:show(WeekView:new{ ctx = self.ctx, sync_on_open = true })
    else
        local MonthView = require("calendario_month")
        UIManager:show(MonthView:new{ ctx = self.ctx })
    end
    return true
end

return Calendario
