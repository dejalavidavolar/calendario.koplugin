-- Selector de color: una fila de círculos seleccionables (el primero es «sin color»).

local Blitbuffer = require("ffi/blitbuffer")
local ButtonTable = require("ui/widget/buttontable")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local LineWidget = require("ui/widget/linewidget")
local InputContainer = require("ui/widget/container/inputcontainer")
local Size = require("ui/size")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local Widget = require("ui/widget/widget")

local U = require("calendario_util")
local W = require("calendario_widgets")
local Screen = Device.screen

local function round(x) return math.floor(x + 0.5) end

-- Disco relleno (en color real: filas con paintRectRGB32, como el resto del plugin).
local function disc(bb, cx, cy, r, color)
    for dy = -r, r do
        local half = math.floor(math.sqrt(r * r - dy * dy))
        W.fillRectColor(bb, cx - half, cy + dy, 2 * half + 1, 1, color)
    end
end

local Row = Widget:extend{ width = 0, picker = nil }

function Row:init()
    self.items = { { key = "" } }
    for _, c in ipairs(U.COLORS) do self.items[#self.items + 1] = { key = c.key } end
    self.slot = self.width / #self.items
    self.d = math.min(round(self.slot * 0.78), Screen:scaleBySize(86))
    self.dimen = Geom:new{ x = 0, y = 0, w = self.width, h = self.d + Screen:scaleBySize(10) }
end

function Row:getSize() return self.dimen end

function Row:paintTo(bb, x, y)
    self.dimen.x, self.dimen.y = x, y
    local BLACK, WHITE = Blitbuffer.COLOR_BLACK, Blitbuffer.COLOR_WHITE
    local r = math.floor(self.d / 2)
    local cy = y + round(self.dimen.h / 2)
    for i, it in ipairs(self.items) do
        local cx = x + round((i - 0.5) * self.slot)
        local selected = (self.picker.color or "") == it.key
        local ring = selected and Screen:scaleBySize(5) or Size.border.thick
        disc(bb, cx, cy, r, BLACK)
        local col = W.colorOf(it.key)
        if col then
            disc(bb, cx, cy, r - ring, col)      -- anillo negro y el color pegado, sin blanco
        else
            disc(bb, cx, cy, r - ring, WHITE)
            -- «Sin color»: círculo blanco con una barra diagonal.
            local k = math.floor((r - ring) * 0.62)
            for j = -k, k do
                bb:paintRect(cx + j - 1, cy + j - 1, 3, 3, BLACK)
            end
        end
        it.rect = Geom:new{ x = cx - round(self.slot / 2), y = y, w = round(self.slot), h = self.dimen.h }
    end
end

local ColorPicker = InputContainer:extend{
    name = "calendario_colorpicker",
    modal = true,
    ctx = nil,
    color = "",
    on_done = nil,      -- function(key)
}

function ColorPicker:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    if Device:hasKeys() then
        self.key_events = { Close = { { Device.input.group.Back } } }
    end
    if Device:isTouchDevice() then
        self.ges_events = { Tap = { GestureRange:new{ ges = "tap", range = self.dimen } } }
    end
    local pad = Screen:scaleBySize(16)
    local frame_w = math.min(math.floor(self.dimen.w * 0.92), Screen:scaleBySize(760))
    local inner = frame_w - 2 * pad - 2 * Size.border.window

    self.row = Row:new{ width = inner, picker = self }
    local content = VerticalGroup:new{ align = "left" }
    table.insert(content, self.row)
    local buttons_tbl = ButtonTable:new{
        width = frame_w - 2 * Size.border.window, show_parent = self,
        buttons = {{ { text = self.ctx:t("cancel"), callback = function() self:onClose() end } }},
    }
    W.squareButtons(buttons_tbl)
    local group = VerticalGroup:new{
        align = "left",
        FrameContainer:new{
            bordersize = 0, padding = pad, padding_bottom = Screen:scaleBySize(10),
            TextWidget:new{
                text = self.ctx:t("f_color"), face = Font:getFace("cfont", 24), bold = true, max_width = inner,
            },
        },
        LineWidget:new{
            dimen = Geom:new{ w = frame_w - 2 * Size.border.window, h = Size.line.medium },
            background = Blitbuffer.COLOR_BLACK,
        },
        FrameContainer:new{ bordersize = 0, padding = pad, padding_top = Screen:scaleBySize(18), content },
        W.separator(frame_w - 2 * Size.border.window),
        buttons_tbl,
    }
    self.frame = FrameContainer:new{
        background = Blitbuffer.COLOR_WHITE,
        bordersize = Size.border.window,
        radius = Size.radius.window,
        padding = 0,
        group,
    }
    self[1] = CenterContainer:new{ dimen = self.dimen, self.frame }
end

function ColorPicker:onTap(_, ges)
    if not (ges and ges.pos) then return true end
    for _, it in ipairs(self.row.items) do
        if it.rect and it.rect:contains(ges.pos) then
            UIManager:close(self)
            if self.on_done then self.on_done(it.key) end
            return true
        end
    end
    return true
end

function ColorPicker:onShow()
    UIManager:setDirty(self, function() return "partial", self.dimen, true end)
end

function ColorPicker:onCloseWidget()
    if self[1] then self[1]:free() end
    self[1] = nil
end

function ColorPicker:onClose()
    UIManager:close(self)
    return true
end

return ColorPicker
