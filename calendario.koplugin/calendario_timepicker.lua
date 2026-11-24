-- Selector de hora estilo Android: reloj circular. Se elige el inicio y (opcional) el fin
-- de un rango; para cada uno primero la hora (anillo exterior 12,1…11 e interior 00,13…23)
-- y luego los minutos. Se puede tocar o deslizar el dedo sobre el reloj.
-- Todo se dibuja en blanco, negro y gris (sin color) para que la e-ink lo refresque rápido.

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
local VerticalSpan = require("ui/widget/verticalspan")
local Widget = require("ui/widget/widget")

local U = require("calendario_util")
local W = require("calendario_widgets")
local Screen = Device.screen

local FACE_BG = Blitbuffer.COLOR_GRAY_E or Blitbuffer.COLOR_LIGHT_GRAY
local discColor = W.discColor
local fillRectColor = W.fillRectColor

-- Acento de color (lila oscuro, buen contraste con texto blanco) y un lila muy claro para la
-- esfera. Si la pantalla/versión no admite color RGB, se usa el gris/negro de siempre.
local function rgb(r, g, b)
    local ok, c = pcall(Blitbuffer.ColorRGB32, r, g, b, 0xFF)
    if ok and c then return c, true end
    return nil, false
end
local ACCENT, HAS_RGB = rgb(0x6B, 0x46, 0xC8)
local FACE_TINT = HAS_RGB and rgb(0xEE, 0xE9, 0xFA) or nil
if not HAS_RGB then ACCENT = Blitbuffer.COLOR_BLACK end

local function floor(x) return math.floor(x + 0.5) end

-- ── Cuerpo: cabecera (inicio – fin) + reloj ────────────────────────────────

local Body = Widget:extend{
    picker = nil,   -- TimePicker dueño (estado en picker.state / picker.target / picker.mode)
    width = 0,
    dial_d = 0,     -- diámetro del reloj
}

function Body:init()
    local s = Screen
    self.box_w = s:scaleBySize(84)   -- diámetro de cada círculo
    self.box_h = s:scaleBySize(74)
    self.colon_w = s:scaleBySize(22)
    self.label_h = 0
    self.head_h = self.label_h + self.box_h
    self.gap = s:scaleBySize(14)
    self.dimen = Geom:new{ x = 0, y = 0, w = self.width, h = self.head_h + self.gap + self.dial_d }
    self.rects = {}
    self.dial = { cx = 0, cy = 0, R = self.dial_d / 2 }
end

function Body:getSize() return self.dimen end

local function text(bb, str, size, bold, color, cx, cy)
    local tw = TextWidget:new{
        text = str, face = Font:getFace("cfont", size), bold = bold or false, fgcolor = color,
    }
    local sz = tw:getSize()
    tw:paintTo(bb, floor(cx - sz.w / 2), floor(cy - sz.h / 2))
    tw:free()
end

local function circle(bb, cx, cy, r, color)
    r = floor(r)
    if bb.paintCircle then
        bb:paintCircle(floor(cx), floor(cy), r, color)
    else
        bb:paintRect(floor(cx - r), floor(cy - r), 2 * r, 2 * r, color)
    end
end

-- Círculo relleno: en color real (acento) o gris/negro con paintCircle.
local function ccircle(bb, cx, cy, r, color, is_rgb)
    if is_rgb then
        discColor(bb, floor(cx), floor(cy), floor(r), color)
    else
        circle(bb, cx, cy, r, color)
    end
end

local function dot_line(bb, x1, y1, x2, y2, t, color, is_rgb)
    local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
    local n = math.max(1, math.ceil(len / 2))
    for i = 0, n do
        local x = x1 + (x2 - x1) * i / n
        local y = y1 + (y2 - y1) * i / n
        if is_rgb then
            fillRectColor(bb, floor(x - t / 2), floor(y - t / 2), t, t, color)
        else
            bb:paintRect(floor(x - t / 2), floor(y - t / 2), t, t, color)
        end
    end
end

function Body:paintTo(bb, x, y)
    self.dimen.x, self.dimen.y = x, y
    local p = self.picker
    local st, target, mode = p.state, p.target, p.mode
    local BLACK, WHITE, GRAY = Blitbuffer.COLOR_BLACK, Blitbuffer.COLOR_WHITE, Blitbuffer.COLOR_DARK_GRAY
    local W = self.width

    -- Cabecera: [Inicio  HH:MM]  –  [Fin  HH:MM]
    local group_w = 2 * self.box_w + self.colon_w
    local dash_w = Screen:scaleBySize(46)
    local total = 2 * group_w + dash_w
    local x0 = x + floor((W - total) / 2)
    local by = y + self.label_h
    local function group(gx, key, val)
        local hh = val and string.format("%02d", math.floor(val / 60)) or "--"
        local mm = val and string.format("%02d", val % 60) or "--"
        local function box(bx, k, str, selected)
            local ccx, ccy, rad = bx + self.box_w / 2, by + self.box_h / 2, floor(self.box_w / 2)
            if selected then
                ccircle(bb, ccx, ccy, rad, ACCENT, HAS_RGB)
            else
                circle(bb, ccx, ccy, rad, BLACK)
                circle(bb, ccx, ccy, rad - Size.border.thick, WHITE)
            end
            text(bb, str, 40, true, selected and WHITE or BLACK, bx + self.box_w / 2, by + self.box_h / 2)
            self.rects[k] = Geom:new{ x = bx, y = by, w = self.box_w, h = self.box_h }
        end
        box(gx, key .. "_h", hh, target == key and mode == "hour")
        text(bb, ":", 40, true, BLACK, gx + self.box_w + self.colon_w / 2, by + self.box_h / 2)
        box(gx + self.box_w + self.colon_w, key .. "_m", mm, target == key and mode == "minute")
    end
    group(x0, "s", st.s)
    text(bb, "–", 40, true, BLACK, x0 + group_w + dash_w / 2, by + self.box_h / 2)
    group(x0 + group_w + dash_w, "e", st.e)

    -- Reloj.
    local R = self.dial_d / 2
    local cx = x + floor(W / 2)
    local cy = y + self.head_h + self.gap + floor(R)
    self.dial.cx, self.dial.cy, self.dial.R = cx, cy, R
    if FACE_TINT then ccircle(bb, cx, cy, R, FACE_TINT, true) else circle(bb, cx, cy, R, FACE_BG) end

    local r_out, r_in = R * 0.80, R * 0.50
    local disk = math.min(Screen:scaleBySize(27), R * 0.12)

    local cur = (target == "s") and st.s or st.e
    local value                      -- valor en el reloj (hora 0-23 o minuto 0-59)
    if cur then
        value = (mode == "hour") and math.floor(cur / 60) or (cur % 60)
    end

    -- Posición del valor seleccionado.
    local sx, sy
    if value then
        local ang, ring = U.dialPos(mode, value)
        local rr = (ring == "inner") and r_in or r_out
        local a = math.rad(ang)
        sx, sy = cx + rr * math.sin(a), cy - rr * math.cos(a)
    end

    -- Mano y disco (debajo de los números).
    if sx then
        dot_line(bb, cx, cy, sx, sy, 3, ACCENT, HAS_RGB)
        ccircle(bb, cx, cy, Screen:scaleBySize(5), ACCENT, HAS_RGB)
        ccircle(bb, sx, sy, disk, ACCENT, HAS_RGB)
    end

    -- Números.
    local function put(str, ang, rr, size, selected)
        local a = math.rad(ang)
        text(bb, str, size, true, selected and WHITE or BLACK, cx + rr * math.sin(a), cy - rr * math.cos(a))
    end
    if mode == "hour" then
        for k = 0, 11 do
            local outer = (k == 0) and 12 or k
            put(tostring(outer), k * 30, r_out, 26, value == outer)
            local inner = (k == 0) and 0 or (12 + k)
            put(string.format("%02d", inner), k * 30, r_in, 20, value == inner)
        end
    else
        for m = 0, 55, 5 do
            put(string.format("%02d", m), m * 6, r_out, 26, value == m)
        end
    end
end

-- ── Ventana ────────────────────────────────────────────────────────────────

local TimePicker = InputContainer:extend{
    name = "calendario_timepicker",
    modal = true,
    ctx = nil,
    time = "",          -- "HH:MM" o ""
    time_end = "",      -- "HH:MM" o ""
    on_done = nil,      -- function(time, time_end)
}

function TimePicker:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    self.state = { s = U.toMin(self.time), e = U.toMin(self.time_end) }
    if self.state.e and (not self.state.s or self.state.e < self.state.s + 5) then
        self.state.e = nil
    end
    self.target = "s"
    self.mode = "hour"
    if Device:hasKeys() then
        self.key_events = { Close = { { Device.input.group.Back } } }
    end
    if Device:isTouchDevice() then
        self.ges_events = {
            Tap = { GestureRange:new{ ges = "tap", range = self.dimen } },
            Pan = { GestureRange:new{ ges = "pan", range = self.dimen } },
            PanRelease = { GestureRange:new{ ges = "pan_release", range = self.dimen } },
        }
    end
    self:update()
end

function TimePicker:current()
    return (self.target == "s") and self.state.s or self.state.e
end

function TimePicker:update()
    if self[1] then self[1]:free() end
    local ctx, st = self.ctx, self.state
    local pad = Screen:scaleBySize(14)
    local frame_w = math.floor(self.dimen.w * 0.92)
    if frame_w > Screen:scaleBySize(760) then frame_w = Screen:scaleBySize(760) end
    local inner = frame_w - 2 * pad - 2 * Size.border.window
    local dial_d = math.min(floor(inner * 0.92), floor(self.dimen.h * 0.40))

    local function gap(n) return VerticalSpan:new{ width = Screen:scaleBySize(n) } end

    self.body = Body:new{ picker = self, width = inner, dial_d = dial_d }

    local content = VerticalGroup:new{ align = "left" }
    table.insert(content, self.body)

    local frame_inner = frame_w - 2 * Size.border.window
    local buttons_tbl = ButtonTable:new{
        width = frame_inner, show_parent = self,
        buttons = {{
            { text = ctx:t("cancel"), callback = function() self:onClose() end },
            { text = ctx:t("ok"), callback = function() self:accept() end },
        }},
    }
    W.squareButtons(buttons_tbl)
    local group = VerticalGroup:new{
        align = "left",
        FrameContainer:new{
            bordersize = 0, padding = pad, padding_bottom = Screen:scaleBySize(10),
            TextWidget:new{
                text = ctx:t("time_title"), face = Font:getFace("cfont", 24), bold = true, max_width = inner,
            },
        },
        LineWidget:new{
            dimen = Geom:new{ w = frame_inner, h = Size.line.medium },
            background = Blitbuffer.COLOR_BLACK,
        },
        FrameContainer:new{ bordersize = 0, padding = pad, padding_top = Screen:scaleBySize(14), content },
        -- Botones a todo el ancho de la ventana, con la línea gris superior (como InputDialog).
        W.separator(frame_inner),
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

    if self._shown then
        local mode = self.ctx:refreshMode()
        UIManager:setDirty(self, function() return mode, self.frame.dimen or self.dimen, true end)
    end
end

-- Solo redibuja el cuerpo (cabecera + reloj).
-- `fast`: mientras se desliza el dedo ("ui", rápido, sin fidelidad de color); al soltar o tocar,
-- "partial" con dither para que el color y el gris queden limpios.
function TimePicker:repaintBody(fast)
    local b = self.body
    if b and b.dimen then
        local mode = fast and "ui" or self.ctx:refreshMode()
        UIManager:setDirty(self, function() return mode, b.dimen, not fast end)
    end
end

-- Asegura que exista el valor del objetivo actual. Devuelve true si hubo que crearlo.
function TimePicker:ensure()
    local st = self.state
    if self.target == "s" then
        if st.s == nil then U.pickerShiftStart(st, 0); return true end
    else
        if st.e == nil then U.pickerShiftEnd(st, 0); return true end
    end
    return false
end

function TimePicker:setValue(v, fast)
    local st = self.state
    local created = self:ensure()
    local old_s, old_e = st.s, st.e
    local cur = self:current()
    local newm
    if self.mode == "hour" then
        newm = v * 60 + cur % 60
    else
        newm = math.floor(cur / 60) * 60 + v
    end
    if self.target == "s" then U.pickerSetStartAbs(st, newm) else U.pickerSetEndAbs(st, newm) end
    if created then
        self:update()
        return true
    end
    if st.s ~= old_s or st.e ~= old_e then
        self:repaintBody(fast)
        return true
    end
    return false
end

-- Valor del reloj bajo un punto de pantalla (o nil si cae lejos del reloj).
function TimePicker:valueAt(pos, tolerance)
    local d = self.body and self.body.dial
    if not d or not pos then return nil end
    local dx, dy = pos.x - d.cx, pos.y - d.cy
    if math.sqrt(dx * dx + dy * dy) > d.R * (tolerance or 1.0) then return nil end
    return U.dialPick(self.mode, dx, dy, d.R)
end

function TimePicker:selectBox(key)
    local target, mode = key:sub(1, 1), (key:sub(3, 3) == "h") and "hour" or "minute"
    self.target, self.mode = target, mode
    self:ensure()
    self:update()   -- refresca cabecera, reloj y estado de los botones ±1
end

function TimePicker:onTap(_, ges)
    if not (ges and ges.pos) then return true end
    local b = self.body
    if b and b.rects then
        for key, r in pairs(b.rects) do
            if r:contains(ges.pos) then
                self:selectBox(key)
                return true
            end
        end
    end
    local v = self:valueAt(ges.pos, 1.0)
    if v then
        local was_hour = self.mode == "hour"
        self:setValue(v)
        if was_hour then
            self.mode = "minute"
            self:update()
        end
    end
    return true
end

function TimePicker:onPan(_, ges)
    if not (ges and ges.pos) then return true end
    if self.pan_active == nil then
        -- El gesto debe haber empezado sobre el reloj.
        self.pan_active = self:valueAt(ges.pos, 1.15) ~= nil
        self.panned = false
    end
    if not self.pan_active then return true end
    local v = self:valueAt(ges.pos, 1.5)
    if v then
        if self:setValue(v, true) then self.panned = true end
    end
    return true
end

function TimePicker:onPanRelease()
    local was = self.pan_active
    local panned = self.panned
    self.pan_active, self.panned = nil, nil
    if was and panned then
        if self.mode == "hour" then
            self.mode = "minute"
            self:update()
        else
            self:repaintBody()      -- refresco final, limpio y con color
        end
    end
    return true
end

function TimePicker:onShow()
    self._shown = true
    local mode = self.ctx:refreshMode()
    UIManager:setDirty(self, function() return mode, self.dimen, true end)
end

function TimePicker:onCloseWidget()
    self._shown = false
    if self[1] then self[1]:free() end
    self[1] = nil
end

function TimePicker:accept()
    local st = self.state
    local t = st.s and U.fromMin(st.s) or ""
    local e = (st.s and st.e) and U.fromMin(st.e) or ""
    UIManager:close(self)
    if self.on_done then self.on_done(t, e) end
end

function TimePicker:onClose()
    UIManager:close(self)
    return true
end

return TimePicker
