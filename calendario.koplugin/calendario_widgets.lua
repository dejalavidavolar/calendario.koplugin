-- Widgets propios: cuadrícula mensual, fila de evento, fila de campo y fila de acción.

local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local LineWidget = require("ui/widget/linewidget")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Widget = require("ui/widget/widget")

local U = require("calendario_util")
local Screen = Device.screen

local W = {}

-- ── Colores ────────────────────────────────────────────────────────────────
-- OJO: los colores de Blitbuffer son cdata con __eq; compararlos con nil (== / ~=)
-- hace crashear KOReader. Por eso la caché guarda envoltorios { c = color }.

local color_cache = {}

-- Color de Blitbuffer para la clave de un evento (nil = sin color).
local function colorOf(key)
    if not key or key == "" then return nil end
    local entry = color_cache[key]
    if entry then return entry.c end
    local def = U.colorDef(key)
    local c
    if def then
        local ok, v = pcall(Blitbuffer.ColorRGB32, def.rgb[1], def.rgb[2], def.rgb[3], 0xFF)
        if ok and v then
            c = v
        else
            c = Blitbuffer.COLOR_DARK_GRAY
        end
    end
    color_cache[key] = { c = c }
    return c
end
W.colorOf = colorOf

-- Variantes del color de un evento, al estilo de Notion Calendar: relleno claro ("tint") y
-- franja lateral más oscura ("stripe"). Mismas reglas que colorOf (envoltorios, sin nil).
local shade_cache = {}
local function shadeOf(key, kind)
    if not key or key == "" then return nil end
    local ck = kind .. ":" .. key
    local entry = shade_cache[ck]
    if entry then return entry.c end
    local def = U.colorDef(key)
    local c
    if def then
        local r, g, b = def.rgb[1], def.rgb[2], def.rgb[3]
        if kind == "tint" then
            local m = 0.28
            r, g, b = r + (255 - r) * m, g + (255 - g) * m, b + (255 - b) * m
        else
            -- stripe: franja; text: título (muy oscuro); time: hora (intermedio, menos contraste)
            local k = (kind == "text") and 0.28 or (kind == "time") and 0.58 or 0.66
            r, g, b = r * k, g * k, b * k
        end
        local ok, v = pcall(Blitbuffer.ColorRGB32, math.floor(r + 0.5), math.floor(g + 0.5), math.floor(b + 0.5), 0xFF)
        c = (ok and v) or Blitbuffer.COLOR_DARK_GRAY
    end
    shade_cache[ck] = { c = c }
    return c
end

-- OJO: el paintRect de KOReader aplana cualquier color a gris (toma getColor8() primero).
-- Para pintar un color de verdad en un buffer de color hay que usar paintRectRGB32 (su
-- relleno en C) o, si la build no lo tiene, setPixel. Así lo hace Ink Away (ink/paint.lua).
local function fillRectColor(bb, x, y, w, h, color)
    if w <= 0 or h <= 0 then return end
    if bb.paintRectRGB32 then
        bb:paintRectRGB32(x, y, w, h, color)
    else
        for j = y, y + h - 1 do
            for i = x, x + w - 1 do bb:setPixel(i, j, color) end
        end
    end
end

W.fillRectColor = fillRectColor

-- El resaltado al tocar un botón de KOReader es un recuadro redondeado que no cubre todo el
-- botón: se quitan las esquinas redondeadas. Acepta una ButtonTable o un diálogo que la tenga.
function W.squareButtons(obj)
    local bt = obj and (obj.button_table or obj.buttontable or obj)
    if not bt or not bt.buttons_layout then return end
    for _, row in ipairs(bt.buttons_layout) do
        for _, btn in ipairs(row) do
            if btn.frame then btn.frame.radius = 0 end
            btn.radius = 0
        end
    end
end

-- Línea gris divisoria a todo el ancho `width` (la misma en todas las ventanas del plugin).
function W.separator(width)
    return LineWidget:new{
        dimen = Geom:new{ w = width, h = Size.line.medium },
        background = Blitbuffer.COLOR_GRAY,
    }
end

-- Rectángulo con esquinas redondeadas, dibujado por filas con la función `fill(x, y, w, h)`.
local function roundedFill(fill, x, y, w, h, r)
    r = math.min(r or 0, math.floor(math.min(w, h) / 2))
    if r <= 0 then fill(x, y, w, h); return end
    for i = 0, r - 1 do
        local dy = r - i - 0.5
        local off = r - math.floor(math.sqrt(math.max(0, r * r - dy * dy)) + 0.5)
        fill(x + off, y + i, w - 2 * off, 1)
        fill(x + off, y + h - 1 - i, w - 2 * off, 1)
    end
    if h - 2 * r > 0 then fill(x, y + r, w, h - 2 * r) end
end

-- Barrita de color (para la lista del día y el editor).
local Swatch = Widget:extend{ width = 0, height = 0, color = nil }

function Swatch:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = self.width, h = self.height }
end

function Swatch:getSize()
    return self.dimen
end

-- Disco relleno con filas de color (paintRectRGB32 conserva el color real).
local function discColor(bb, cx, cy, r, color)
    for dy = -r, r do
        local half = math.floor(math.sqrt(r * r - dy * dy))
        fillRectColor(bb, cx - half, cy + dy, 2 * half + 1, 1, color)
    end
end
W.discColor = discColor

-- Muestra de color: círculo con borde negro fino.
function Swatch:paintTo(bb, x, y)
    self.dimen.x, self.dimen.y = x, y
    local t = math.max(1, Screen:scaleBySize(1))
    local r = math.floor(math.min(self.width, self.height) / 2)
    local cx, cy = x + math.floor(self.width / 2), y + math.floor(self.height / 2)
    if self.color then
        discColor(bb, cx, cy, r, Blitbuffer.COLOR_BLACK)
        discColor(bb, cx, cy, r - t, self.color)
    else
        -- «Sin color»: círculo blanco con borde negro y una diagonal.
        local ring = math.max(2, Screen:scaleBySize(2))
        discColor(bb, cx, cy, r, Blitbuffer.COLOR_BLACK)
        discColor(bb, cx, cy, r - ring, Blitbuffer.COLOR_WHITE)
        local k = math.floor((r - ring) * 0.62)
        for j = -k, k do
            bb:paintRect(cx + j - 1, cy + j - 1, 3, 3, Blitbuffer.COLOR_BLACK)
        end
    end
end

-- ── Medición de texto ──────────────────────────────────────────────────────

local has_rt, RenderText = pcall(require, "ui/rendertext")

local function makeMeasure(face, bold)
    local cache = {}
    return function(str)
        local w = cache[str]
        if w then return w end
        if has_rt and RenderText.sizeUtf8Text then
            local ok, sz = pcall(RenderText.sizeUtf8Text, RenderText, 0, 100000, face, str, true, bold)
            if ok and type(sz) == "table" and sz.x then w = sz.x end
        end
        if not w then
            local tw = TextWidget:new{ text = str, face = face, bold = bold, padding = 0 }
            w = tw:getSize().w
            tw:free()
        end
        cache[str] = w
        return w
    end
end

local function lineHeight(face, bold)
    local probe = TextWidget:new{ text = "Ag", face = face, bold = bold, padding = 0 }
    local h = probe:getSize().h
    probe:free()
    return h
end

-- Tamaños de letra de los eventos, de mayor a menor (se elige el mayor que quepa).
-- Tamaño de letra de los eventos del mes: fijo, el mismo para todos los cuadros.
-- Si no caben todos los eventos de un día, se reparte el espacio y se muestra "+N más".
local EV_FONT = 11
local EV_SIZES = { EV_FONT }

-- ═══ Base común de las cuadrículas (mes y semana) ═════════════════════════

local GridBase = Widget:extend{ width = 0, height = 0, store = nil, lang = "es" }

function GridBase:getSize()
    return self.dimen
end

function GridBase:freeItems()
    for _, it in ipairs(self.items or {}) do
        if it.w and it.w.free then it.w:free() end
    end
    self.items = {}
    self.bgs = {}
end

function GridBase:free()
    self:freeItems()
end

function GridBase:addText(text, face, x, y, opts)
    opts = opts or {}
    local tw = TextWidget:new{
        text = text,
        face = face,
        bold = opts.bold,
        fgcolor = opts.fgcolor,
        max_width = opts.max_width,
        padding = 0,
    }
    local sz = tw:getSize()
    local px = x
    if opts.align == "right" then
        px = x - sz.w
    elseif opts.align == "center" then
        px = x - math.floor(sz.w / 2)
    end
    self.items[#self.items + 1] = { w = tw, x = px, y = y }
    return sz
end

-- Texto de un evento para el cuadro: descripción (o lugar si no hay descripción), sin la hora.
local function eventLabel(ev)
    local body = (ev.desc or ""):gsub("%s+", " ")
    body = body:gsub("^ ", ""):gsub(" $", "")
    if body == "" then
        body = (ev.place or ""):gsub("%s+", " ")
        body = body:gsub("^ ", ""):gsub(" $", "")
    end
    local label = body
    if label == "" and ev.time ~= "" then label = ev.time end   -- sin texto: al menos la hora
    if label == "" then label = "•" end
    return label
end

-- Métricas por tamaño de letra (con caché): alto de línea y medidor de ancho.
local metrics_cache = {}
local function metrics(size)
    local m = metrics_cache[size]
    if not m then
        local face = Font:getFace("cfont", size)
        m = { face = face, h = lineHeight(face, true), measure = makeMeasure(face, true) }
        metrics_cache[size] = m
    end
    return m.h, m.measure
end

local GRAY_CHIP = Blitbuffer.Color8(0xE4)      -- eventos sin color: relleno gris claro
local GRAY_STRIPE = Blitbuffer.Color8(0x60)    -- y franja gris oscura

-- Coloca los eventos de un día dentro de un rectángulo, al estilo de Notion Calendar: recuadro
-- redondeado de relleno claro con una franja de color a la izquierda; solo el título, en negro.
-- o = { chip_x, chip_w, top, avail, sizes, gap, show_time }
local function placeEvents(g, list, o)
    local n = #list
    if n == 0 or o.avail < 1 then return end
    local sw = Screen:scaleBySize(4)          -- ancho de la franja
    local tpad = Screen:scaleBySize(3)
    local pad_l = Screen:scaleBySize(2)       -- aire entre la franja y el texto
    local pad_r = Screen:scaleBySize(1)       -- y a la derecha (el texto puede llegar casi al borde)
    local rad = Screen:scaleBySize(5)         -- radio de las esquinas
    local text_x = o.chip_x + sw + pad_l
    local text_w = o.chip_w - sw - pad_l - pad_r

    local labels = {}
    for i = 1, n do labels[i] = eventLabel(list[i]) end
    -- En la vista semanal cada evento con hora lleva una línea extra abajo para la hora.
    local extra
    if o.show_time then
        extra = {}
        for i = 1, n do
            if (list[i].time or "") ~= "" then extra[i] = 1 end
        end
    end
    local plan = U.fitEvents(labels, o.avail, o.gap, text_w - 1, o.sizes, metrics, extra)
    local face_ev = Font:getFace("cfont", plan.size)
    local face_time = Font:getFace("cfont", math.max(7, plan.size - 2))
    local ev_h = plan.ev_h

    local ty = o.top
    for i = 1, plan.k do
        local lines, a = plan.lines[i], plan.alloc[i]
        local key = list[i].color
        local tint = shadeOf(key, "tint")
        if tint then
            g.has_color = true
            g.bgs[#g.bgs + 1] = { x = o.chip_x, y = ty, w = o.chip_w, h = a * ev_h, color = tint, r = rad }
            g.bgs[#g.bgs + 1] = { x = o.chip_x, y = ty, w = o.chip_w, h = a * ev_h,
                color = shadeOf(key, "stripe"), r = rad, clip = sw }
        else
            g.bgs[#g.bgs + 1] = { x = o.chip_x, y = ty, w = o.chip_w, h = a * ev_h,
                plain = GRAY_CHIP, r = rad }
            g.bgs[#g.bgs + 1] = { x = o.chip_x, y = ty, w = o.chip_w, h = a * ev_h,
                plain = GRAY_STRIPE, r = rad, clip = sw }
        end
        local with_time = extra and extra[i] and a >= #lines + 1
        local title_rows = with_time and #lines or a
        local text_color = shadeOf(key, "text") or Blitbuffer.COLOR_BLACK
        for j = 1, title_rows do
            local text = lines[j]
            if j == title_rows and #lines > title_rows then
                -- Última línea permitida: el resto del texto, recortado con "…".
                text = table.concat(lines, " ", j)
            end
            g:addText(text, face_ev, text_x, ty + (j - 1) * ev_h,
                { max_width = text_w, fgcolor = text_color, bold = true })
        end
        if with_time then
            local tcolor = shadeOf(key, "time") or GRAY_STRIPE
            g:addText(U.formatRange(list[i].time, list[i].time_end), face_time,
                o.chip_x + o.chip_w - tpad, ty + #lines * ev_h,
                { fgcolor = tcolor, align = "right", max_width = text_w })
        end
        ty = ty + a * ev_h + o.gap
    end
    if plan.k < n and (plan.k > 0 or o.avail >= ev_h) then
        g:addText(U.t(g.lang, "more", n - plan.k), face_ev, o.chip_x + tpad, ty,
            { bold = true, max_width = o.chip_w - 2 * tpad, fgcolor = Blitbuffer.COLOR_BLACK })
    end
end

-- Pinta los fondos (recuadros, franjas) acumulados en g.bgs.
local function paintBgs(g, bb, x, y)
    for _, bg in ipairs(g.bgs) do
        local fill
        if bg.color then
            local col = bg.color
            fill = function(fx, fy, fw, fh) fillRectColor(bb, fx, fy, fw, fh, col) end
        else
            local c = bg.plain or Blitbuffer.COLOR_BLACK
            fill = function(fx, fy, fw, fh) bb:paintRect(fx, fy, fw, fh, c) end
        end
        local bx = x + bg.x
        if bg.clip then
            local limit, f0 = bx + bg.clip, fill
            fill = function(fx, fy, fw, fh)
                local w2 = math.min(fw, limit - fx)
                if w2 > 0 then f0(fx, fy, w2, fh) end
            end
        end
        roundedFill(fill, bx, y + bg.y, bg.w, bg.h, bg.r or 0)
    end
end

-- ═══ Cuadrícula mensual ═══════════════════════════════════════════════════
-- Sin marco exterior; arriba lleva su propia línea (negra) de la que cuelgan las verticales.

local Grid = GridBase:extend{
    year = 2026,
    month = 1,
    bottom_line = false,   -- borde inferior (para separarlo de la barra de ZenOS)
    top_line = true,       -- línea superior, donde nacen las líneas verticales
}

function Grid:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = self.width, h = self.height }
    self.items = {}
    self.bgs = {}
    self:build()
end

function Grid:build()
    self:freeItems()
    self.has_color = false

    local face_head = Font:getFace("cfont", 12)
    local face_day = Font:getFace("cfont", 13)
    local pad = Screen:scaleBySize(3)
    local tpad = Screen:scaleBySize(2)
    local head_top = Screen:scaleBySize(5)
    local gap = Screen:scaleBySize(3)   -- espacio entre eventos

    local off = U.firstOffset(self.year, self.month)
    local nd = U.daysInMonth(self.year, self.month)
    local weeks = math.ceil((off + nd) / 7)
    self.off, self.nd, self.weeks = off, nd, weeks
    self.lw = math.max(1, Screen:scaleBySize(1))

    self.header_h = head_top + lineHeight(face_head, true) + pad

    self.cx = {}
    for c = 0, 7 do self.cx[c] = math.floor(c * self.width / 7) end
    local body_h = self.height - self.header_h
    self.ry = {}
    for r = 0, weeks do self.ry[r] = self.header_h + math.floor(r * body_h / weeks) end

    -- Números de día: centrados en un círculo imaginario en la esquina superior derecha.
    local probe = TextWidget:new{ text = "00", face = face_day, bold = true, padding = 0 }
    local psz = probe:getSize()
    probe:free()
    local R = math.ceil(math.max(psz.w, psz.h) / 2) + Screen:scaleBySize(2)
    local edge = Screen:scaleBySize(3)

    -- Títulos de los días (lunes → domingo).
    for c = 0, 6 do
        local cw = self.cx[c + 1] - self.cx[c]
        self:addText(U.weekdayShort(self.lang, c), face_head,
            self.cx[c] + math.floor(cw / 2), head_top,
            { bold = true, align = "center", max_width = cw - 2 })
    end

    local now = os.date("*t")
    for d = 1, nd do
        local idx = off + d - 1
        local r = math.floor(idx / 7)
        local c = idx % 7
        local cx0, cx1 = self.cx[c], self.cx[c + 1]
        local cy0, cy1 = self.ry[r], self.ry[r + 1]
        local is_today = (now.year == self.year and now.month == self.month and now.day == d)
        local x_start = cx0 + ((c > 0) and self.lw or 0)
        local block_w = cx1 - x_start

        local ccy = cy0 + self.lw + edge + R
        -- Hoy: el número va en una "insignia" negra de esquinas redondeadas (texto blanco).
        local bw = psz.w + 2 * Screen:scaleBySize(5)
        local bx1 = cx1 - edge
        local ccx = bx1 - math.floor(bw / 2)  -- centro del número
        if is_today then
            local bh = psz.h + Screen:scaleBySize(2)
            self.bgs[#self.bgs + 1] = {
                x = bx1 - bw, y = ccy - math.floor(bh / 2), w = bw, h = bh,
                plain = Blitbuffer.COLOR_BLACK, r = Screen:scaleBySize(6),
            }
        end
        self:addText(tostring(d), face_day, ccx, ccy - math.floor(psz.h / 2), {
            bold = true,
            fgcolor = is_today and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK,
            align = "center",
        })

        -- Eventos: el tamaño de letra se adapta al contenido de este cuadro.
        local list = self.store:getEvents(U.dateKey(self.year, self.month, d))
        local top = ccy + R + 2
        local bottom_pad = (self.bottom_line and r == weeks - 1) and self.lw or 0
        local sm = Screen:scaleBySize(2)          -- margen lateral de los eventos
        placeEvents(self, list, {
            chip_x = x_start + sm, chip_w = block_w - 2 * sm, top = top,
            avail = cy1 - top - 1 - bottom_pad,
            sizes = EV_SIZES, gap = gap,
        })
    end
end

function Grid:paintTo(bb, x, y)
    self.dimen.x, self.dimen.y = x, y
    bb:paintRect(x, y, self.width, self.height, Blitbuffer.COLOR_WHITE)

    local col = Blitbuffer.COLOR_DARK_GRAY
    local lw = self.lw
    -- Verticales: arrancan en el borde superior del widget, pegadas a la línea de arriba.
    for c = 1, 6 do
        bb:paintRect(x + self.cx[c], y, lw, self.height, col)
    end
    for r = 0, self.weeks - 1 do
        bb:paintRect(x, y + self.ry[r], self.width, lw, col)
    end
    if self.top_line then
        bb:paintRect(x, y, self.width, Size.line.thick, Blitbuffer.COLOR_BLACK)
    end
    if self.bottom_line then
        -- Mismo grosor y color que las líneas de la cuadrícula.
        bb:paintRect(x, y + self.height - lw, self.width, lw, col)
    end

    paintBgs(self, bb, x, y)
    for _, it in ipairs(self.items) do
        it.w:paintTo(bb, x + it.x, y + it.y)
    end
end

-- Coordenadas absolutas de pantalla → día del mes (o nil).
function Grid:cellAt(px, py)
    local rx, ry = px - self.dimen.x, py - self.dimen.y
    if rx < 0 or rx >= self.width or ry < self.header_h or ry >= self.height then return nil end
    local col, row
    for c = 0, 6 do
        if rx >= self.cx[c] and rx < self.cx[c + 1] then col = c break end
    end
    for r = 0, self.weeks - 1 do
        if ry >= self.ry[r] and ry < self.ry[r + 1] then row = r break end
    end
    if not col or not row then return nil end
    local d = row * 7 + col - self.off + 1
    if d < 1 or d > self.nd then return nil end
    return d
end

W.Grid = Grid

-- ═══ Cuadrícula semanal (lunes a viernes) ═════════════════════════════════
-- 2 filas × 3 columnas: lunes · martes · miércoles / jueves · viernes · sábado+domingo
-- (el sexto cuadro se divide en dos mitades, arriba sábado y abajo domingo).

-- En la semanal hay más espacio: la letra se adapta (la mayor que permita mostrar todo el día).
local WEEK_SIZES = { 20, 18, 17, 16, 15, 14, 13, 12, 11 }

local WeekGrid = GridBase:extend{
    monday = nil,          -- "AAAA-MM-DD" del lunes de la semana
    bottom_line = false,
    top_line = true,
}

function WeekGrid:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = self.width, h = self.height }
    self.items = {}
    self.bgs = {}
    self.cells = {}
    self:build()
end

function WeekGrid:build()
    self:freeItems()
    self.has_color = false
    self.cells = {}
    local lw = math.max(1, Screen:scaleBySize(1))
    self.lw = lw
    local W_, H_ = self.width, self.height
    local cx = { [0] = 0, math.floor(W_ / 3), math.floor(2 * W_ / 3), W_ }
    local ry = { [0] = 0, math.floor(H_ / 2), H_ }
    local mid = ry[1] + math.floor((ry[2] - ry[1]) / 2)
    self.cx, self.ry, self.mid = cx, ry, mid

    local face_wd = Font:getFace("cfont", 14)
    local face_num = Font:getFace("cfont", 22)
    local edge = Screen:scaleBySize(6)
    local gap = Screen:scaleBySize(4)
    local today = os.date("%Y-%m-%d")

    -- Rectángulos de cada día: { key, col0, col1, y0, y1, idx }
    local rects = {}
    for i = 0, 4 do
        local row, col = math.floor(i / 3), i % 3
        rects[#rects + 1] = { idx = i, c0 = cx[col], c1 = cx[col + 1], y0 = ry[row], y1 = ry[row + 1], col = col }
    end
    rects[#rects + 1] = { idx = 5, c0 = cx[2], c1 = cx[3], y0 = ry[1], y1 = mid, col = 2 }
    rects[#rects + 1] = { idx = 6, c0 = cx[2], c1 = cx[3], y0 = mid, y1 = ry[2], col = 2 }

    for _, r in ipairs(rects) do
        local key = U.addDays(self.monday, r.idx)
        local is_today = (key == today)
        local x_start = r.c0 + ((r.col > 0) and lw or 0)
        local block_w = r.c1 - x_start
        local y_start = r.y0 + lw
        local bottom_pad = (self.bottom_line and r.y1 == ry[2]) and lw or 0
        self.cells[#self.cells + 1] = { key = key, x0 = x_start, x1 = r.c1, y0 = y_start, y1 = r.y1 }

        local _, _, d = U.parseKey(key)
        local top_y = y_start + Screen:scaleBySize(6)
        local bpx = Screen:scaleBySize(5)
        -- Hoy: el número va en una "insignia" negra de esquinas redondeadas (texto blanco).
        local num_right = r.c1 - edge - bpx
        local nsz = self:addText(tostring(d), face_num, num_right, top_y,
            { bold = true, fgcolor = is_today and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK, align = "right" })
        if is_today then
            self.bgs[#self.bgs + 1] = {
                x = num_right - nsz.w - bpx, y = top_y - Screen:scaleBySize(1),
                w = nsz.w + 2 * bpx, h = nsz.h + Screen:scaleBySize(2),
                plain = Blitbuffer.COLOR_BLACK, r = Screen:scaleBySize(7),
            }
        end
        self:addText(U.weekdayShort(self.lang, r.idx), face_wd, x_start + edge,
            top_y + math.floor((nsz.h - lineHeight(face_wd, true)) / 2),
            { bold = true, fgcolor = Blitbuffer.COLOR_BLACK, max_width = block_w - nsz.w - 4 * edge })

        local top = top_y + nsz.h + Screen:scaleBySize(4)
        local sm = Screen:scaleBySize(4)
        placeEvents(self, self.store:getEvents(key), {
            chip_x = x_start + sm, chip_w = block_w - 2 * sm, top = top,
            avail = r.y1 - top - 2 - bottom_pad,
            sizes = WEEK_SIZES, gap = gap, show_time = true,
        })
    end
end

function WeekGrid:paintTo(bb, x, y)
    self.dimen.x, self.dimen.y = x, y
    bb:paintRect(x, y, self.width, self.height, Blitbuffer.COLOR_WHITE)
    local col = Blitbuffer.COLOR_DARK_GRAY
    local lw = self.lw
    for c = 1, 2 do bb:paintRect(x + self.cx[c], y, lw, self.height, col) end
    bb:paintRect(x, y + self.ry[1], self.width, lw, col)
    bb:paintRect(x + self.cx[2], y + self.mid, self.cx[3] - self.cx[2], lw, col)   -- sábado | domingo
    if self.top_line then
        bb:paintRect(x, y, self.width, Size.line.thick, Blitbuffer.COLOR_BLACK)
    end
    if self.bottom_line then
        bb:paintRect(x, y + self.height - lw, self.width, lw, col)
    end
    paintBgs(self, bb, x, y)
    for _, it in ipairs(self.items) do
        it.w:paintTo(bb, x + it.x, y + it.y)
    end
end

-- Coordenadas absolutas de pantalla → fecha "AAAA-MM-DD" (o nil).
function WeekGrid:cellAt(px, py)
    local rx, ry = px - self.dimen.x, py - self.dimen.y
    for _, c in ipairs(self.cells) do
        if rx >= c.x0 - self.lw and rx < c.x1 and ry >= c.y0 - self.lw and ry < c.y1 then return c.key end
    end
    return nil
end

W.WeekGrid = WeekGrid

-- Título "Mes" en negrita + " año" normal, centrado sobre la barra de título.
function W.titleWidget(bold_text, rest, width, height)
    local CenterContainer = require("ui/widget/container/centercontainer")
    local face = Font:getFace("cfont", 26)
    return CenterContainer:new{
        dimen = Geom:new{ w = width, h = height },
        HorizontalGroup:new{
            TextWidget:new{ text = bold_text, face = face, bold = true },
            TextWidget:new{ text = " " .. rest, face = face },
        },
    }
end

-- ═══ Filas tocables (lista de eventos, campos del editor, acciones) ═══════

local TapRow = InputContainer:extend{
    width = 0,
    callback = nil,
}

-- `vg` es el VerticalGroup con el contenido; se envuelve con márgenes y una línea inferior.
function TapRow:wrap(vg)
    local pad_h = Screen:scaleBySize(14)
    local pad_v = Screen:scaleBySize(8)
    self[1] = VerticalGroup:new{
        align = "left",
        VerticalSpan:new{ width = pad_v },
        HorizontalGroup:new{
            HorizontalSpan:new{ width = pad_h },
            vg,
        },
        VerticalSpan:new{ width = pad_v },
        LineWidget:new{
            dimen = Geom:new{ w = self.width, h = Size.line.thin },
            background = Blitbuffer.COLOR_GRAY,
        },
    }
    local sz = self[1]:getSize()
    self.dimen = Geom:new{ x = 0, y = 0, w = self.width, h = sz.h }
    self.ges_events = {
        TapSelect = {
            GestureRange:new{ ges = "tap", range = function() return self.dimen end },
        },
    }
end

function TapRow:inner_width()
    return self.width - 2 * Screen:scaleBySize(14)
end

function TapRow:getSize()
    return self.dimen
end

function TapRow:paintTo(bb, x, y)
    self.dimen.x, self.dimen.y = x, y
    if self[1] then self[1]:paintTo(bb, x, y) end
end

function TapRow:onTapSelect()
    if self.callback then self.callback() end
    return true
end

function TapRow:free()
    if self._freed then return end
    self._freed = true
    InputContainer.free(self)
end

-- Una línea de texto con una muestra de color opcional a la izquierda.
local function lineWithSwatch(text, face, bold, fgcolor, swatch, max_width)
    if not swatch then
        return TextWidget:new{
            text = text, face = face, bold = bold, fgcolor = fgcolor, max_width = max_width,
        }
    end
    local gap = Screen:scaleBySize(8)
    local probe = TextWidget:new{ text = "Ag", face = face, bold = bold }
    local sw = math.max(Screen:scaleBySize(14), probe:getSize().h - Screen:scaleBySize(4))   -- diámetro
    probe:free()
    local tw = TextWidget:new{
        text = text, face = face, bold = bold, fgcolor = fgcolor,
        max_width = max_width - sw - gap,
    }
    return HorizontalGroup:new{
        align = "center",
        Swatch:new{ width = sw, height = sw, color = swatch },
        HorizontalSpan:new{ width = gap },
        tw,
    }
end

-- Evento en la lista del día: "hora · lugar" en negrita y la descripción debajo.
local EventRow = TapRow:extend{
    ctx = nil,
    ev = nil,
}

function EventRow:init()
    local iw = self:inner_width()
    local head = (self.ev.time ~= "") and U.formatRange(self.ev.time, self.ev.time_end) or self.ctx:t("no_time")
    if self.ev.place ~= "" then head = head .. "  ·  " .. U.firstLine(self.ev.place) end
    local vg = VerticalGroup:new{ align = "left" }
    table.insert(vg, lineWithSwatch(head, Font:getFace("cfont", 20), true, nil,
        colorOf(self.ev.color), iw))
    if self.ev.desc ~= "" then
        table.insert(vg, VerticalSpan:new{ width = Screen:scaleBySize(3) })
        table.insert(vg, TextBoxWidget:new{
            text = U.clip(self.ev.desc, 240),
            face = Font:getFace("cfont", 20),   -- mismo tamaño que la línea de hora/lugar
            width = iw,
        })
    end
    self:wrap(vg)
end

W.EventRow = EventRow

-- Campo del editor: etiqueta pequeña y valor (o texto de ayuda si está vacío).
local FieldRow = TapRow:extend{
    label = "",
    value = "",
    placeholder = "",
    multiline = false,
    swatch = nil,
    swatch_none = false,   -- sin valor: solo el círculo de «sin color» (con diagonal)
}

function FieldRow:init()
    local iw = self:inner_width()
    local empty = (self.value == nil or self.value == "")
    local text = empty and self.placeholder or self.value
    local color = Blitbuffer.COLOR_BLACK   -- el texto de ayuda también va en negro
    local vg = VerticalGroup:new{ align = "left" }
    table.insert(vg, TextWidget:new{
        text = self.label,
        face = Font:getFace("cfont", 14),
        fgcolor = Blitbuffer.COLOR_DARK_GRAY,
        max_width = iw,
    })
    table.insert(vg, VerticalSpan:new{ width = Screen:scaleBySize(3) })
    if self.multiline then
        table.insert(vg, TextBoxWidget:new{
            text = U.clip(text, 600),
            face = Font:getFace("cfont", 22),   -- mismo tamaño que los campos de una línea
            width = iw,
            fgcolor = color,
        })
    elseif self.swatch_none then
        local probe = TextWidget:new{ text = "Ag", face = Font:getFace("cfont", 22) }
        local d = math.max(Screen:scaleBySize(14), probe:getSize().h - Screen:scaleBySize(4))
        probe:free()
        table.insert(vg, Swatch:new{ width = d, height = d, color = nil })
    else
        table.insert(vg, lineWithSwatch(text, Font:getFace("cfont", 22), false, color,
            self.swatch, iw))
    end
    self:wrap(vg)
end

W.FieldRow = FieldRow

-- Fila de acción (por ejemplo "+ Agregar evento").
local ActionRow = TapRow:extend{
    text = "",
}

function ActionRow:init()
    local vg = VerticalGroup:new{ align = "left" }
    table.insert(vg, TextWidget:new{
        text = self.text,
        face = Font:getFace("cfont", 20),
        bold = true,
        max_width = self:inner_width(),
    })
    self:wrap(vg)
end

W.ActionRow = ActionRow

return W
