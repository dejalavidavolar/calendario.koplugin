-- Vista semanal: lunes a viernes en 2 filas de 3 cuadros (sábado y domingo comparten el sexto).

local ButtonDialog = require("ui/widget/buttondialog")
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local NetworkMgr = require("ui/network/manager")
local OverlapGroup = require("ui/widget/overlapgroup")
local TitleBar = require("ui/widget/titlebar")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")

local U = require("calendario_util")
local W = require("calendario_widgets")
local Screen = Device.screen

local WeekView = InputContainer:extend{
    name = "calendario_week",
    is_month = true,          -- cuenta como "vista principal" para los refrescos
    covers_fullscreen = true,
    ctx = nil,
    monday = nil,             -- "AAAA-MM-DD"
    on_close = nil,           -- function(year, month) al volver al mes (nil: se crea el mes)
    sync_on_open = false,     -- sincronizar al mostrarse (si se abrió directamente)
}

function WeekView:init()
    self.dimen, self.covers_fullscreen = self.ctx:viewDimen()
    if not self.monday then self.monday = U.weekStart(os.date("%Y-%m-%d")) end
    self.key_events = {
        NextWeek = { { Device.input.group.PgFwd } },
        PrevWeek = { { Device.input.group.PgBack } },
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
    self.ctx:setLastView("week")
    self.ctx:setupView(self)
    self:update()
end

function WeekView:update()
    if self[1] then self[1]:free() end
    local w, h = self.dimen.w, self.dimen.h
    self.title_bar = TitleBar:new{
        width = w,
        fullscreen = true,
        title = " ",
        with_bottom_line = false,
        left_icon = U.icon("menu"),
        left_icon_tap_callback = function() self:showMenu() end,
        close_callback = function() self:onClose() end,
        show_parent = self,
    }
    local th = self.title_bar:getHeight()
    local title_bold, title_rest = U.weekTitle(self.ctx:lang(), self.monday)
    local head = OverlapGroup:new{
        dimen = Geom:new{ w = w, h = th },
        self.title_bar,
        W.titleWidget(title_bold, title_rest, w, th),
    }

    local body_h = h - th
    local with_nav = (h < Screen:getHeight())
    local gap = with_nav and self.ctx:navGap() or 0
    self.grid = W.WeekGrid:new{
        width = w,
        height = body_h - gap,
        bottom_line = with_nav,
        monday = self.monday,
        lang = self.ctx:lang(),
        store = self.ctx.store,
    }
    self.has_color = self.grid.has_color

    local group = VerticalGroup:new{ align = "left", head, self.grid }
    if gap > 0 then table.insert(group, VerticalSpan:new{ width = gap }) end
    self[1] = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 0, padding = 0, margin = 0,
        group,
    }
    if self._shown then
        self.ctx:refresh(self, self.has_color)
    end
end

function WeekView:onShow()
    self._shown = true
    self.ctx:logDisplay()
    self.ctx:refresh(self, self.has_color)
    if self.sync_on_open and self.ctx:syncOnOpen() and self.ctx:isSyncConfigured() and NetworkMgr:isOnline() then
        UIManager:nextTick(function()
            self.ctx:syncNow(function() self:update() end)
        end)
    end
end

function WeekView:onCloseWidget()
    self.ctx:releaseView(self)
    self._shown = false
    if self[1] then self[1]:free() end
end

-- X / Atrás: sale del calendario (la semana queda como última vista).
function WeekView:onClose()
    if self._closing then return true end
    self.ctx:exitApp()
    return true
end

-- ☰ → Vista mensual: vuelve al mes (que se reconstruye antes, por si hubo cambios).
function WeekView:toMonth()
    if self._closing then return true end
    self.ctx:setLastView("month")
    local y, m = U.parseKey(U.addDays(self.monday, 3))   -- el jueves decide el mes
    if self.on_close then
        self.on_close(y, m)
    else
        -- La semana se abrió directamente (última vista): no hay mes debajo; se crea.
        local MonthView = require("calendario_month")
        UIManager:show(MonthView:new{ ctx = self.ctx, year = y, month = m })
    end
    self.ctx:closeView(self)
    return true
end

function WeekView:shift(weeks)
    self.monday = U.addDays(self.monday, 7 * weeks)
    self:update()
end

function WeekView:onNextWeek() self:shift(1); return true end
function WeekView:onPrevWeek() self:shift(-1); return true end

function WeekView:onSwipe(arg, ges)
    local dir = ges.direction
    if dir == "west" then self:shift(1); return true
    elseif dir == "east" then self:shift(-1); return true end
end

function WeekView:onTapGrid(arg, ges)
    local key = self.grid and self.grid:cellAt(ges.pos.x, ges.pos.y)
    if key then self:openDay(key) end
    return true
end

function WeekView:openDay(key)
    local refresh = function() self:update() end
    if #self.ctx.store:getEvents(key) == 0 then
        local Editor = require("calendario_editor")
        UIManager:show(Editor:new{ ctx = self.ctx, date = key, on_change = refresh })
    else
        local DayView = require("calendario_day")
        UIManager:show(DayView:new{ ctx = self.ctx, date = key, on_change = refresh })
    end
end

function WeekView:showMenu()
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
            entry(ctx:t("month_view"), function() self:toMonth() end),
            entry(ctx:t("sync_now"), function() ctx:syncNow(function() self:update() end) end),
            entry(ctx:t("sync_settings"), function() ctx:syncDialog() end),
        },
    }
    self.ctx:showDialog(dlg)
end

return WeekView
