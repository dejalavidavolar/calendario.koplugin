-- Primera página: vista mensual a pantalla completa.
-- Solo barra de título (menú ☰ a la izquierda, ✕ a la derecha) y la cuadrícula.

local ButtonDialog = require("ui/widget/buttondialog")
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local OverlapGroup = require("ui/widget/overlapgroup")
local NetworkMgr = require("ui/network/manager")
local TitleBar = require("ui/widget/titlebar")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")

local U = require("calendario_util")
local W = require("calendario_widgets")
local Screen = Device.screen

local MonthView = InputContainer:extend{
    name = "calendario_month",
    is_month = true,
    covers_fullscreen = true,
    ctx = nil,
    year = nil,
    month = nil,
}

function MonthView:init()
    -- Si hay barra de ZenOS abajo, no la tapamos (y dejamos que se pinte lo de atrás).
    self.dimen, self.covers_fullscreen = self.ctx:viewDimen()
    if not self.year then
        local now = os.date("*t")
        self.year, self.month = now.year, now.month
    end
    self.key_events = {
        NextMonth = { { Device.input.group.PgFwd } },
        PrevMonth = { { Device.input.group.PgBack } },
    }
    if Device:hasKeys() then
        self.key_events.Close = { { Device.input.group.Back } }
    end
    if Device:isTouchDevice() then
        self.ges_events = {
            TapGrid = {
                GestureRange:new{
                    ges = "tap",
                    range = function()
                        return self.grid and self.grid.dimen or Geom:new{ x = 0, y = 0, w = 0, h = 0 }
                    end,
                },
            },
            Swipe = { GestureRange:new{ ges = "swipe", range = self.dimen } },
        }
    end
    self.ctx:setupView(self)
    self:update()
end

function MonthView:update()
    if self[1] then self[1]:free() end
    local w, h = self.dimen.w, self.dimen.h

    self.title_bar = TitleBar:new{
        width = w,
        fullscreen = true,
        title = " ",   -- el título real (mes en negrita + año) se dibuja encima
        with_bottom_line = false,   -- la cuadrícula dibuja su propia línea superior
        left_icon = U.icon("menu"),
        left_icon_tap_callback = function() self:showMenu() end,
        close_callback = function() self:onClose() end,
        show_parent = self,
    }

    -- Sin márgenes. Con la barra de ZenOS abajo se deja una separación extra (35% más).
    local body_h = h - self.title_bar:getHeight()
    local with_nav = (h < Screen:getHeight())
    local gap = with_nav and self.ctx:navGap() or 0
    self.grid = W.Grid:new{
        width = w,
        height = body_h - gap,
        bottom_line = with_nav,
        year = self.year,
        month = self.month,
        lang = self.ctx:lang(),
        store = self.ctx.store,
    }

    self.has_color = self.grid.has_color

    local th = self.title_bar:getHeight()
    local month_name, month_year = U.monthParts(self.ctx:lang(), self.year, self.month)
    local head = OverlapGroup:new{
        dimen = Geom:new{ w = w, h = th },
        self.title_bar,
        W.titleWidget(month_name, month_year, w, th),
    }
    local group = VerticalGroup:new{ align = "left", head, self.grid }
    if gap > 0 then table.insert(group, VerticalSpan:new{ width = gap }) end
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

function MonthView:onShow()
    self._shown = true
    self.ctx:logDisplay()
    self.ctx:refresh(self, self.has_color)
    if self.ctx:syncOnOpen() and self.ctx:isSyncConfigured() and NetworkMgr:isOnline() then
        UIManager:nextTick(function()
            self.ctx:syncNow(function() self:update() end)
        end)
    end
end

function MonthView:onCloseWidget()
    self.ctx:releaseView(self)
    self._shown = false
    if self[1] then self[1]:free() end
end

function MonthView:onClose()
    self.ctx:exitApp()
    return true
end

-- ── Navegación ─────────────────────────────────────────────────────────────

function MonthView:shift(delta)
    self.year, self.month = U.addMonths(self.year, self.month, delta)
    self:update()
end

function MonthView:onNextMonth()
    self:shift(1)
    return true
end

function MonthView:onPrevMonth()
    self:shift(-1)
    return true
end

function MonthView:onSwipe(arg, ges)
    local dir = ges.direction
    if dir == "west" then
        self:shift(1)
        return true
    elseif dir == "east" then
        self:shift(-1)
        return true
    end
end

function MonthView:onTapGrid(arg, ges)
    local d = self.grid and self.grid:cellAt(ges.pos.x, ges.pos.y)
    if d then self:openDay(d) end
    return true
end

-- Día vacío → editor directo; día con eventos → lista del día.
function MonthView:openDay(d)
    local key = U.dateKey(self.year, self.month, d)
    local refresh = function() self:update() end
    if #self.ctx.store:getEvents(key) == 0 then
        local Editor = require("calendario_editor")
        UIManager:show(Editor:new{ ctx = self.ctx, date = key, on_change = refresh })
    else
        local DayView = require("calendario_day")
        UIManager:show(DayView:new{ ctx = self.ctx, date = key, on_change = refresh })
    end
end

-- Vista semanal (lunes a viernes) de la semana de hoy, o la del día 1 si se mira otro mes.
function MonthView:openWeek()
    local now = os.date("*t")
    local key
    if now.year == self.year and now.month == self.month then
        key = U.dateKey(now.year, now.month, now.day)
    else
        key = U.dateKey(self.year, self.month, 1)
    end
    local Week = require("calendario_week")
    UIManager:show(Week:new{
        ctx = self.ctx,
        monday = U.weekStart(key),
        on_close = function(y, m)
            if y then self.year, self.month = y, m end
            self:update()
        end,
    })
end

-- ── Menú ☰ ─────────────────────────────────────────────────────────────────

function MonthView:showMenu()
    local ctx = self.ctx
    local dlg
    local function entry(text, action)
        return {{
            text = text,
            callback = function()
                UIManager:close(dlg)
                self.ctx:refresh(self, self.has_color)
                action()
            end,
        }}
    end
    dlg = ButtonDialog:new{
        buttons = {
            entry(ctx:t("week_view"), function() self:openWeek() end),
            entry(ctx:t("sync_now"), function()
                ctx:syncNow(function() self:update() end)
            end),
            entry(ctx:t("sync_settings"), function() ctx:syncDialog() end),
        },
    }
    self.ctx:showDialog(dlg)
end

return MonthView
