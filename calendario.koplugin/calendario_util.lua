-- Utilidades: textos (es/en), fechas, normalización de hora, iconos.

local U = {}

local STR = {
    es = {
        today = "Hoy",
        prev_month = "Mes anterior",
        next_month = "Mes siguiente",
        goto_date = "Ir a fecha…",
        goto_title = "Ir a fecha",
        goto_hint = "DD/MM/AAAA o MM/AAAA",
        goto_invalid = "Fecha no válida.",
        week_view = "Vista semanal",
        month_view = "Vista mensual",
        sync_now = "Sincronizar calendario",
        sync_settings = "Configurar WebDAV…",
        sync_on_open = "Sincronizar al abrir: %s",
        yes = "sí",
        no = "no",
        font_size = "Tamaño de letra…",
        font_title = "Tamaño de letra de los eventos",
        font_small = "Pequeña",
        font_medium = "Media",
        font_large = "Grande",
        cancel = "Cancelar",
        ok = "Aceptar",
        save = "Guardar",
        delete = "Eliminar",
        add_event = "+ Agregar evento",
        new_event = "Nuevo evento",
        edit_event = "Editar evento",
        f_date = "Fecha",
        f_time = "Hora",
        f_place = "Lugar",
        f_desc = "Descripción",
        no_time = "Sin hora",
        set_time = "Configurar hora",
        color_red = "Rojo",
        color_orange = "Naranja",
        color_yellow = "Amarillo",
        color_green = "Verde",
        color_cyan = "Celeste",
        color_blue = "Azul",
        color_purple = "Violeta",
        add_place = "Agrega un lugar",
        add_desc = "Agrega una descripción",
        hint_time = "HH:MM (vacío = sin hora)",
        hint_place = "Lugar",
        hint_desc = "Descripción",
        hint_date = "DD/MM/AAAA",
        invalid_time = "Hora no válida. Usa HH:MM (por ejemplo 09:30).",
        invalid_date = "Fecha no válida. Usa DD/MM/AAAA.",
        nothing_to_save = "Escribe al menos una hora, un lugar o una descripción.",
        discard_confirm = "¿Descartar los cambios de este evento?",
        discard = "Descartar",
        delete_confirm = "¿Eliminar este evento?",
        more = "+%d más",
        f_color = "Color",
        time_title = "Hora del evento",
        lbl_start = "Inicio",
        lbl_end = "Fin",
        to_word = "a",
        lbl_duration = "Duración",
        add_end = "Agregar hora de fin",
        remove_end = "Quitar hora de fin",
        no_end = "sin hora de fin",
        sync_title = "Sincronización WebDAV",
        sync_hint_url = "URL de la carpeta (https://servidor/remote.php/dav/files/USUARIO/Calendario)",
        sync_hint_user = "Usuario",
        sync_hint_pass = "Contraseña (Nextcloud: contraseña de aplicación)",
        sync_hint_file = "Nombre del archivo (por defecto calendario.json)",
        sync_saved = "Configuración guardada.",
        syncing = "Sincronizando…",
        sync_not_configured = "Primero configura la sincronización WebDAV en el menú.",
        sync_net_error = "Error de red: %s",
        sync_auth_error = "Usuario o contraseña incorrectos (HTTP 401/403).",
        sync_http_error = "El servidor respondió con error HTTP %s.",
        sync_bad_remote = "El archivo remoto no es válido; no se modificó nada.",
        sync_ok = "Calendario sincronizado.",
        sync_conflict = "El archivo cambió varias veces durante la sincronización. Intenta de nuevo.",
        sync_folder_missing = "La carpeta remota no existe y no se pudo crear. Créala en tu servidor.",
    },
    en = {
        today = "Today",
        prev_month = "Previous month",
        next_month = "Next month",
        goto_date = "Go to date…",
        goto_title = "Go to date",
        goto_hint = "DD/MM/YYYY or MM/YYYY",
        goto_invalid = "Invalid date.",
        week_view = "Weekly view",
        month_view = "Monthly view",
        sync_now = "Sync calendar",
        sync_settings = "WebDAV settings…",
        sync_on_open = "Sync on open: %s",
        yes = "yes",
        no = "no",
        font_size = "Font size…",
        font_title = "Event font size",
        font_small = "Small",
        font_medium = "Medium",
        font_large = "Large",
        cancel = "Cancel",
        ok = "OK",
        save = "Save",
        delete = "Delete",
        add_event = "+ Add event",
        new_event = "New event",
        edit_event = "Edit event",
        f_date = "Date",
        f_time = "Time",
        f_place = "Place",
        f_desc = "Description",
        no_time = "No time",
        set_time = "Set time",
        color_red = "Red",
        color_orange = "Orange",
        color_yellow = "Yellow",
        color_green = "Green",
        color_cyan = "Light blue",
        color_blue = "Blue",
        color_purple = "Violet",
        add_place = "Add a place",
        add_desc = "Add a description",
        hint_time = "HH:MM (empty = no time)",
        hint_place = "Place",
        hint_desc = "Description",
        hint_date = "DD/MM/YYYY",
        invalid_time = "Invalid time. Use HH:MM (for example 09:30).",
        invalid_date = "Invalid date. Use DD/MM/YYYY.",
        nothing_to_save = "Enter at least a time, a place or a description.",
        discard_confirm = "Discard the changes to this event?",
        discard = "Discard",
        delete_confirm = "Delete this event?",
        more = "+%d more",
        f_color = "Color",
        time_title = "Event time",
        lbl_start = "Start",
        lbl_end = "End",
        to_word = "to",
        lbl_duration = "Duration",
        add_end = "Add end time",
        remove_end = "Remove end time",
        no_end = "no end time",
        sync_title = "WebDAV sync",
        sync_hint_url = "Folder URL (https://server/remote.php/dav/files/USER/Calendar)",
        sync_hint_user = "Username",
        sync_hint_pass = "Password (Nextcloud: app password)",
        sync_hint_file = "File name (default calendario.json)",
        sync_saved = "Settings saved.",
        syncing = "Syncing…",
        sync_not_configured = "Set up WebDAV sync from the menu first.",
        sync_net_error = "Network error: %s",
        sync_auth_error = "Wrong username or password (HTTP 401/403).",
        sync_http_error = "The server answered with HTTP error %s.",
        sync_bad_remote = "The remote file is not valid; nothing was changed.",
        sync_ok = "Calendar synced.",
        sync_conflict = "The file kept changing during sync. Please try again.",
        sync_folder_missing = "The remote folder does not exist and could not be created. Create it on your server.",
    },
}

local MONTHS = {
    es = { "enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto",
           "septiembre", "octubre", "noviembre", "diciembre" },
    en = { "January", "February", "March", "April", "May", "June", "July", "August",
           "September", "October", "November", "December" },
}

local WEEKDAYS_SHORT = {
    es = { "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom" },
    en = { "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" },
}

local WEEKDAYS_LONG = {
    es = { "lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo" },
    en = { "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" },
}

function U.t(lang, key, ...)
    local tbl = STR[lang] or STR.es
    local s = tbl[key] or STR.es[key] or key
    if select("#", ...) > 0 then
        local ok, r = pcall(string.format, s, ...)
        return ok and r or s
    end
    return s
end

local function capitalize(s)
    -- Solo para nombres de mes en minúscula que empiezan con letra ASCII.
    return (s:gsub("^%l", string.upper))
end

-- ── Fechas ─────────────────────────────────────────────────────────────────

function U.daysInMonth(y, m)
    return os.date("*t", os.time{ year = y, month = m + 1, day = 0, hour = 12 }).day
end

-- 0 = lunes … 6 = domingo, del día 1 del mes.
function U.firstOffset(y, m)
    local wd = os.date("*t", os.time{ year = y, month = m, day = 1, hour = 12 }).wday
    return (wd + 5) % 7
end

function U.weekdayIndex(y, m, d)
    local wd = os.date("*t", os.time{ year = y, month = m, day = d, hour = 12 }).wday
    return (wd + 5) % 7
end

function U.dateKey(y, m, d)
    return string.format("%04d-%02d-%02d", y, m, d)
end

function U.parseKey(key)
    local y, m, d = tostring(key):match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
    if not y then return nil end
    return tonumber(y), tonumber(m), tonumber(d)
end

function U.addMonths(y, m, delta)
    local idx = y * 12 + (m - 1) + delta
    return math.floor(idx / 12), idx % 12 + 1
end

function U.weekdayShort(lang, col)
    return (WEEKDAYS_SHORT[lang] or WEEKDAYS_SHORT.es)[col + 1]
end

-- Nombre del mes (con mayúscula inicial en español) y año por separado.
function U.monthParts(lang, y, m)
    local name = (MONTHS[lang] or MONTHS.es)[m]
    if lang ~= "en" then name = capitalize(name) end
    return name, tostring(y)
end

-- Título de la vista semanal: ("Noviembre", "2026") o ("Noviembre - Diciembre", "2027") si la
-- semana (lunes a domingo) cruza de mes; el año mostrado es el del último mes.
function U.weekTitle(lang, monday)
    local y1, m1 = U.parseKey(monday)
    local y2, m2 = U.parseKey(U.addDays(monday, 6))
    local n1 = U.monthParts(lang, y1, m1)
    if m1 == m2 then return n1, tostring(y1) end
    local n2 = U.monthParts(lang, y2, m2)
    return n1 .. " - " .. n2, tostring(y2)
end

-- Lunes de la semana que contiene `key`.
function U.weekStart(key)
    local y, m, d = U.parseKey(key)
    if not y then return key end
    return U.addDays(key, -U.weekdayIndex(y, m, d))
end

function U.longDate(lang, key)
    local y, m, d = U.parseKey(key)
    if not y then return tostring(key) end
    local wd = (WEEKDAYS_LONG[lang] or WEEKDAYS_LONG.es)[U.weekdayIndex(y, m, d) + 1]
    local mn = (MONTHS[lang] or MONTHS.es)[m]
    if lang == "en" then
        return string.format("%s, %s %d, %d", wd, mn, d, y)
    end
    return string.format("%s %d de %s de %d", capitalize(wd), d, mn, y)
end

-- Acepta DD/MM/AAAA, AAAA-MM-DD, MM/AAAA, AAAA-MM. Devuelve y, m, d (d puede ser nil).
function U.parseDate(s)
    s = (s or ""):gsub("%s+", "")
    local y, m, d
    local a, b, c = s:match("^(%d%d%d%d)[%-/%.](%d%d?)[%-/%.](%d%d?)$")
    if a then
        y, m, d = tonumber(a), tonumber(b), tonumber(c)
    else
        a, b, c = s:match("^(%d%d?)[%-/%.](%d%d?)[%-/%.](%d%d%d%d)$")
        if a then
            d, m, y = tonumber(a), tonumber(b), tonumber(c)
        else
            a, b = s:match("^(%d%d?)[%-/%.](%d%d%d%d)$")
            if a then
                m, y = tonumber(a), tonumber(b)
            else
                a, b = s:match("^(%d%d%d%d)[%-/%.](%d%d?)$")
                if a then y, m = tonumber(a), tonumber(b) end
            end
        end
    end
    if not y or not m or m < 1 or m > 12 or y < 1971 or y > 2099 then return nil end
    if d and (d < 1 or d > U.daysInMonth(y, m)) then return nil end
    return y, m, d
end

-- Suma `delta` días a una fecha AAAA-MM-DD.
function U.addDays(key, delta)
    local y, m, d = U.parseKey(key)
    if not y then return key end
    local t = os.date("*t", os.time{ year = y, month = m, day = d + delta, hour = 12 })
    return U.dateKey(t.year, t.month, t.day)
end

-- ── Horas y selector de rango ──────────────────────────────────────────────

function U.toMin(t)
    local h, m = tostring(t or ""):match("^(%d%d):(%d%d)$")
    if not h then return nil end
    h, m = tonumber(h), tonumber(m)
    if h > 23 or m > 59 then return nil end
    return h * 60 + m
end

function U.fromMin(m)
    return string.format("%02d:%02d", math.floor(m / 60), m % 60)
end

-- "09:00 – 10:30", "09:00" o "" según lo que haya.
function U.formatRange(a, b)
    if not a or a == "" then return "" end
    if b and b ~= "" then return a .. " – " .. b end
    return a
end

-- Estado del selector: { s = minutos de inicio | nil, e = minutos de fin | nil }.
-- Reglas: inicio 00:00–23:54, fin siempre al menos 5 min después del inicio y ≤ 23:59;
-- mover el inicio arrastra el fin (se conserva la duración).
local MAXM = 1439
local STEP = 5

function U.pickerShiftStart(st, delta)
    if st.s == nil then st.s = 9 * 60 end
    local old = st.s
    st.s = math.max(0, math.min(MAXM - STEP, old + delta))
    if st.e then
        st.e = math.min(MAXM, st.s + (st.e - old))
        if st.e < st.s + STEP then st.e = st.s + STEP end
    end
end

-- Mueve el fin (si no hay, lo crea 1 h después del inicio y luego aplica delta).
function U.pickerShiftEnd(st, delta)
    if st.s == nil then st.s = 9 * 60 end
    if st.e == nil then st.e = math.min(MAXM, st.s + 60) end
    st.e = math.max(st.s + STEP, math.min(MAXM, st.e + delta))
end

-- Fijar el inicio / el fin en un valor absoluto (lo que entrega el dial circular).
-- El fin se queda donde está; solo se mueve si el inicio lo alcanza (entonces conserva la
-- duración anterior, o 1 h si no había).
function U.pickerSetStartAbs(st, minutes)
    minutes = math.max(0, math.min(MAXM - STEP, minutes))
    local dur = (st.s and st.e) and (st.e - st.s) or nil
    st.s = minutes
    if st.e and st.e < st.s + STEP then
        st.e = math.min(MAXM, st.s + math.max(STEP, dur or 60))
        if st.e < st.s + STEP then st.e = st.s + STEP end
    end
end

function U.pickerSetEndAbs(st, minutes)
    if st.s == nil then st.s = 9 * 60 end
    st.e = math.max(st.s + STEP, math.min(MAXM, minutes))
end

-- ── Geometría del reloj circular ───────────────────────────────────────────
-- Horas (24 h): anillo exterior 12,1…11; anillo interior 00,13…23 (como el selector de
-- Android). Minutos: un solo anillo, de 5 en 5 al tocar/deslizar.

local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

-- Ángulo en grados, 0 = arriba y creciente en sentido horario, [0, 360).
function U.dialAngle(dx, dy)
    local a = math.deg(atan2(dx, -dy))
    if a < 0 then a = a + 360 end
    return a
end

-- Valor elegido al tocar en (dx, dy) respecto del centro; R = radio del dial.
-- mode "hour" → 0..23, "minute" → 0..55 (múltiplos de 5).
function U.dialPick(mode, dx, dy, R)
    local a = U.dialAngle(dx, dy)
    if mode == "hour" then
        local k = math.floor(a / 30 + 0.5) % 12
        local inner = math.sqrt(dx * dx + dy * dy) < 0.66 * R
        if inner then return (k == 0) and 0 or (12 + k) end
        return (k == 0) and 12 or k
    end
    local m = math.floor(a / 6 + 0.5) % 60
    return (math.floor(m / 5 + 0.5) * 5) % 60
end

-- Dónde se dibuja un valor: ángulo en grados y anillo ("inner" / "outer").
function U.dialPos(mode, value)
    if mode == "hour" then
        local inner = (value == 0) or (value >= 13)
        return (value % 12) * 30, inner and "inner" or "outer"
    end
    return value * 6, "outer"
end

-- ── Colores de evento ──────────────────────────────────────────────────────
-- Tonos claros y saturados: el texto de los eventos es siempre negro y debe leerse bien
-- sobre ellos (contraste ≥ 8:1), y en Kaleido los tonos oscuros se ven casi grises.

U.COLORS = {
    { key = "red",    rgb = { 0xFF, 0x7A, 0x7A } },   -- Rojo
    { key = "orange", rgb = { 0xFF, 0xB4, 0x54 } },   -- Naranja
    { key = "yellow", rgb = { 0xFF, 0xE0, 0x66 } },   -- Amarillo
    { key = "green",  rgb = { 0x7B, 0xE0, 0x8F } },   -- Verde
    { key = "cyan",   rgb = { 0x86, 0xDD, 0xF2 } },   -- Celeste
    { key = "blue",   rgb = { 0x6F, 0x9C, 0xFF } },   -- Azul
    { key = "purple", rgb = { 0xC9, 0xA0, 0xFF } },   -- Violeta
}

function U.colorDef(key)
    for _, c in ipairs(U.COLORS) do
        if c.key == key then return c end
    end
    return nil
end

-- ── Texto ──────────────────────────────────────────────────────────────────

-- Reparte `L` líneas entre eventos con necesidades `needs[i]` (líneas que querrían).
-- Todos parten con 1 línea y el resto se reparte de a una, empezando por el que
-- tiene menos y aún necesita más. Devuelve alloc[i].
function U.allocate(needs, L)
    local k = #needs
    local alloc = {}
    for i = 1, k do alloc[i] = 1 end
    local rem = L - k
    while rem > 0 do
        local best
        for i = 1, k do
            if needs[i] > alloc[i] and (not best or alloc[i] < alloc[best]) then best = i end
        end
        if not best then break end
        alloc[best] = alloc[best] + 1
        rem = rem - 1
    end
    return alloc
end

-- Elige el mayor tamaño de letra (de `sizes`, de mayor a menor) con el que TODOS los
-- eventos caben en `avail` px. `labels[i]` = texto de cada evento, `gap` = px entre eventos,
-- `metrics(size)` → alto de línea, medidor de ancho. Si ni el menor tamaño alcanza, usa
-- ese y reparte las líneas disponibles (el resto se muestra como "+N más").
-- Devuelve { size, ev_h, lines = {{...}}, alloc = {n...}, k = cuántos se muestran }.
function U.fitEvents(labels, avail, gap, width, sizes, metrics, extra)
    local n = #labels
    local plan
    for _, size in ipairs(sizes) do
        local ev_h, measure = metrics(size)
        local lines, alloc, total = {}, {}, 0
        for i = 1, n do
            lines[i] = U.wrap(labels[i], width, measure)
            alloc[i] = #lines[i] + ((extra and extra[i]) or 0)   -- extra: líneas añadidas (la hora)
            total = total + alloc[i]
        end
        plan = { size = size, ev_h = ev_h, lines = lines, alloc = alloc, k = n }
        if total * ev_h + (n - 1) * gap <= avail then return plan end
    end
    -- No cabe ni con la letra más chica: mostrar los que se pueda.
    local ev_h = plan.ev_h
    local function cap(k, truncated)
        return math.floor((avail - (k - 1) * gap) / ev_h) - (truncated and 1 or 0)
    end
    local k = n
    while k > 0 and cap(k, k < n) < k do k = k - 1 end
    local L = (k > 0) and cap(k, k < n) or 0
    local needs = {}
    for i = 1, k do needs[i] = #plan.lines[i] + ((extra and extra[i]) or 0) end
    plan.alloc = U.allocate(needs, L)
    plan.k = k
    return plan
end

-- Ajuste de texto por palabras a `width`; `measure(str)` devuelve el ancho en px.
-- Las palabras más anchas que la línea se parten por caracteres (UTF-8).
function U.wrap(text, width, measure)
    local lines, cur = {}, ""
    for word in (text or ""):gmatch("%S+") do
        local try = (cur == "") and word or (cur .. " " .. word)
        if measure(try) <= width then
            cur = try
        else
            if cur ~= "" then
                lines[#lines + 1] = cur
                cur = ""
            end
            if measure(word) <= width then
                cur = word
            else
                for ch in word:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
                    local t2 = cur .. ch
                    if cur == "" or measure(t2) <= width then
                        cur = t2
                    else
                        lines[#lines + 1] = cur
                        cur = ch
                    end
                end
            end
        end
    end
    if cur ~= "" then lines[#lines + 1] = cur end
    if #lines == 0 then lines[1] = "" end
    return lines
end

function U.firstLine(s)
    local line = (s or ""):match("^[^\r\n]*") or ""
    return (line:gsub("^%s+", ""))
end

-- Corta a n bytes sin partir caracteres UTF-8.
function U.clip(s, n)
    s = s or ""
    if #s <= n then return s end
    local cut = n
    while cut > 0 do
        local b = s:byte(cut + 1)
        if not b or b < 0x80 or b >= 0xC0 then break end
        cut = cut - 1
    end
    return s:sub(1, cut) .. "…"
end

-- ── Iconos ─────────────────────────────────────────────────────────────────

local function iconExists(name)
    local ok, lfs = pcall(require, "libs/libkoreader-lfs")
    if not ok then return false end
    for _, dir in ipairs({ "resources/icons/mdlight/", "resources/icons/" }) do
        if lfs.attributes(dir .. name .. ".svg", "mode") == "file"
            or lfs.attributes(dir .. name .. ".png", "mode") == "file" then
            return true
        end
    end
    return false
end

local ICON_PREFS = {
    menu = { "appbar.menu", "appbar.settings", "plus" },
    back = { "chevron.left", "back" },
}

-- Devuelve el primer icono existente; si no se puede comprobar, el preferido.
function U.icon(kind)
    local prefs = ICON_PREFS[kind]
    if not iconExists("close") then return prefs[1] end -- no se puede verificar
    for _, name in ipairs(prefs) do
        if iconExists(name) then return name end
    end
    return prefs[1]
end

return U
