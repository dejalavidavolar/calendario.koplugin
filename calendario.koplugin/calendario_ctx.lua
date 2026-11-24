-- Contexto compartido: almacenamiento, ajustes, idioma, diálogos de texto y sincronización.

local Blitbuffer = require("ffi/blitbuffer")
local ConfirmBox = require("ui/widget/confirmbox")
local Device = require("device")
local Event = require("ui/event")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local DataStorage = require("datastorage")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local LuaSettings = require("luasettings")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local NetworkMgr = require("ui/network/manager")
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")

local Store = require("calendario_store")
local Sync = require("calendario_sync")
local U = require("calendario_util")
local Widget = require("ui/widget/widget")

-- Fondo rayado detrás de las ventanas (mismo estilo que el "Blur menu background" de ZenOS:
-- bb:hatchRect con líneas de 2 px, negro al 40%). Se pinta sobre lo que haya debajo.
local Backdrop = Widget:extend{ covers_fullscreen = false }

function Backdrop:init()
    local s = Device.screen
    self.dimen = Geom:new{ x = 0, y = 0, w = s:getWidth(), h = s:getHeight() }
end

function Backdrop:getSize()
    return self.dimen
end

function Backdrop:paintTo(bb, x, y)
    self.dimen.x, self.dimen.y = x, y
    if bb.hatchRect then
        local stripe = math.max(1, Device.screen:scaleBySize(2))
        bb:hatchRect(x, y, self.dimen.w, self.dimen.h, stripe, Blitbuffer.COLOR_BLACK, 0.4)
    end
end

local Ctx = {}
Ctx.__index = Ctx

function Ctx.settingsPath()
    return DataStorage:getSettingsDir() .. "/calendario.lua"
end

local function log(...)
    local ok, logger = pcall(require, "logger")
    if ok and logger then logger.info("Calendario:", ...) end
end

-- Última vista abierta. Se guarda en tres sitios para que no dependa de qué instancia del
-- plugin la use (el gestor de archivos y el lector tienen cada uno la suya, con ajustes leídos
-- en momentos distintos): en este módulo (compartido en todo el proceso), en los ajustes
-- globales de KOReader y en el archivo propio del plugin (que se reabre al leer y al escribir).
local shared = { view = nil }
local G_KEY = "calendario_last_view"

function Ctx:new()
    local dir = DataStorage:getDataDir() .. "/calendario"
    lfs.mkdir(dir)
    local o = setmetatable({
        settings = LuaSettings:open(Ctx.settingsPath()),
        store = Store:new(dir .. "/eventos.json"),
    }, self)
    return o
end

-- ── Idioma (automático, según el idioma de KOReader) y pantalla ──────────

function Ctx:lang()
    local code
    local ok, gt = pcall(require, "gettext")
    if ok and type(gt) == "table" and type(gt.current_lang) == "string" then
        code = gt.current_lang
    end
    if (not code or code == "" or code == "C") and G_reader_settings then
        code = G_reader_settings:readSetting("language")
    end
    code = tostring(code or ""):lower()
    return code:match("^es") and "es" or "en"
end

function Ctx:t(key, ...)
    return U.t(self:lang(), key, ...)
end

-- Alto que ocupa por abajo la barra de navegación de ZenOS (0 si no hay).
-- ZenOS publica la altura en _G.__ZEN_UI_NAVBAR_HEIGHT (la usan sus propias páginas) y la
-- deja con el último valor aunque se desactive la barra; por eso se confirma con su
-- configuración (features.navbar). La barra solo existe en la biblioteca (FileManager).
function Ctx:reservedBottom()
    local sh = Device.screen:getHeight()
    local okfm, FM = pcall(require, "apps/filemanager/filemanager")
    if not (okfm and type(FM) == "table" and FM.instance) then return 0 end

    local h = tonumber(rawget(_G, "__ZEN_UI_NAVBAR_HEIGHT")) or 0
    if h <= 0 or h >= sh * 0.25 then return 0 end

    local okc, cm = pcall(require, "config/manager")
    if okc and type(cm) == "table" and type(cm.get) == "function" then
        local okg, cfg = pcall(cm.get)
        if okg and type(cfg) == "table" and type(cfg.features) == "table"
            and cfg.features.navbar ~= true then
            return 0
        end
    end
    return math.ceil(h)
end

-- Área disponible para nuestras vistas (deja libre la barra de ZenOS si está activa).
-- Devuelve dimen y si cubre toda la pantalla.
function Ctx:viewDimen()
    local Screen = Device.screen
    local reserved = self:reservedBottom()
    return Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() - reserved },
        reserved == 0
end

-- ── Refresco de pantalla ───────────────────────────────────────────────────
-- Un solo refresco por cambio. Si lo que se ve tiene bloques de color, se usa la forma de
-- onda "partial" (sin destello negro) con dithering, de una vez, en lugar de dibujar rápido
-- y "asentar" después (eso eran dos refrescos).

function Ctx:refreshMode()
    -- Sin destello: "partial" no parpadea (la forma de onda "full" sí, en negro).
    if G_reader_settings and G_reader_settings:isTrue("avoid_flashing_ui") then return "ui" end
    return "partial"
end

function Ctx:isColorScreen()
    local s = Device.screen
    return s.isColorScreen ~= nil and s:isColorScreen() or false
end

-- ¿Es `widget` la vista nuestra que está más arriba? (ignora diálogos y avisos encima)
function Ctx:isFrontView(widget)
    local stack = UIManager._window_stack
    if not stack then return true end
    for i = #stack, 1, -1 do
        local w = stack[i].widget
        if self.views and self.views[w] then return w == widget end
    end
    return true   -- aún no está en la pila (se está mostrando): sí es la de arriba
end

-- Refresca la vista una sola vez. Si hay otra vista nuestra encima, no hace nada: lo que
-- esté debajo se refresca cuando la de arriba se cierre.
function Ctx:refresh(widget, has_color)
    if not self:isFrontView(widget) then return end
    if has_color and self:isColorScreen() then
        UIManager:setDirty(widget, function()
            return self:refreshMode(), widget.dimen, true
        end)
    else
        UIManager:setDirty(widget, function() return "partial", widget.dimen end)
    end
end

-- Vuelve a la vista anterior: cierra `widget` y pide UN refresco explícito de toda la pantalla
-- (si no, a veces KOReader deja la imagen vieja hasta el siguiente toque). Si debajo queda el
-- mes con color, ese refresco es en modo color.
function Ctx:closeView(widget)
    if widget._closing then return end
    widget._closing = true
    local month, others = nil, 0
    for w in pairs(self.views or {}) do
        if w ~= widget then
            if w.is_month then
                if not (month and month.has_color) then month = w end
            else
                others = others + 1
            end
        end
    end
    local mode, dither = "partial", false
    if month and others == 0 and month.has_color and self:isColorScreen() then
        mode, dither = self:refreshMode(), true
    end
    UIManager:close(widget)
    UIManager:setDirty("all", mode, nil, dither)
end

-- Sale del calendario (X): cierra todas las vistas y repinta lo que haya debajo (ZenOS).
function Ctx:exitApp()
    local list = {}
    for w in pairs(self.views or {}) do
        w._closing = true
        list[#list + 1] = w
    end
    for _, w in ipairs(list) do UIManager:close(w) end
    self.views = {}
    UIManager:setDirty("all", "partial")
end

-- Separación extra entre el calendario y la barra de ZenOS: la barra deja arriba un relleno
-- propio (navbar_v_padding = scaleBySize(4)); se le suma un 35% y, además, 7 px.
Ctx.NAV_GAP_EXTRA = 0.35
Ctx.NAV_GAP_PX = 7

function Ctx:navGap()
    local base = math.max(1, math.floor(Ctx.NAV_GAP_EXTRA * Device.screen:scaleBySize(4) + 0.5))
    return base + Ctx.NAV_GAP_PX
end

-- Abre el menú de KOReader/ZenOS (el mismo que abre un toque en el borde superior).
function Ctx:openSystemMenu()
    local menu = self.ui and self.ui.menu
    if menu and menu.onShowMenu then
        local ok = pcall(menu.onShowMenu, menu)
        if ok then return true end
    end
    UIManager:sendEvent(Event:new("ShowMenu"))
    return true
end

-- Datos de pantalla al crash.log, para diagnosticar problemas de color.
function Ctx:logDisplay()
    -- Solo diagnóstico: nunca debe romper la app.
    pcall(function() self:_logDisplay() end)
end

function Ctx:_logDisplay()
    local ok, logger = pcall(require, "logger")
    if not ok then return end
    local Screen = Device.screen
    local function try(f) local o, v = pcall(f); return o and tostring(v) or "?" end
    logger.info("Calendario: isColorScreen=" .. try(function() return Screen:isColorScreen() end)
        .. " isColorEnabled=" .. try(function() return Screen:isColorEnabled() end)
        .. " bb_type=" .. try(function() return Screen.bb:getType() end)
        .. " night=" .. tostring(Screen.night_mode)
        .. " avoid_flashing_ui=" .. tostring(G_reader_settings and G_reader_settings:isTrue("avoid_flashing_ui"))
        .. " reserved_bottom=" .. try(function() return self:reservedBottom() end))
end

-- Registro de vistas abiertas, para cerrarlas todas si se toca la barra de ZenOS.
-- Última vista abierta ("month" / "week"): al volver al calendario se abre esa.
function Ctx:lastView()
    local v, src = shared.view, "memoria"
    if v == nil and G_reader_settings then
        local ok, r = pcall(function() return G_reader_settings:readSetting(G_KEY) end)
        if ok and r then v, src = r, "ajustes globales" end
    end
    if v == nil then
        local ok, r = pcall(function() return LuaSettings:open(Ctx.settingsPath()):readSetting("last_view") end)
        if ok and r then v, src = r, "archivo" end
    end
    log("última vista =", tostring(v), "(" .. src .. ")")
    return v == "week" and "week" or "month"
end

function Ctx:setLastView(v)
    shared.view = v
    if self.settings then self.settings:saveSetting("last_view", v) end
    local ok1 = pcall(function()
        local s = LuaSettings:open(Ctx.settingsPath())   -- reabrir: no pisar otros ajustes con datos viejos
        s:saveSetting("last_view", v)
        s:flush()
    end)
    local ok2 = true
    if G_reader_settings then
        ok2 = pcall(function()
            G_reader_settings:saveSetting(G_KEY, v)
            G_reader_settings:flush()
        end)
    end
    log("guardar última vista =", v, "archivo:", tostring(ok1), "globales:", tostring(ok2))
end

function Ctx:setupView(w)
    self.views = self.views or {}
    self.views[w] = true
    if not Device:isTouchDevice() then return end
    local Screen = Device.screen
    local sh = Screen:getHeight()
    w.ges_events = w.ges_events or {}

    -- Tocar la barra de título (sector del título, sin los iconos) abre el menú de KOReader/ZenOS.
    w.ges_events.TapTitle = {
        GestureRange:new{
            ges = "tap",
            range = function()
                local th = w.title_bar and w.title_bar:getHeight() or 0
                local x0 = math.floor(th * 1.6)
                return Geom:new{ x = x0, y = 0, w = math.max(0, w.dimen.w - 2 * x0), h = th }
            end,
        },
    }
    w.onTapTitle = function()
        self:openSystemMenu()
        return true
    end

    -- Tocar la barra de ZenOS de abajo: cerrar el calendario y reenviar el toque.
    if w.dimen.h < sh then
        w.ges_events.TapNavbar = {
            GestureRange:new{
                ges = "tap",
                range = Geom:new{ x = 0, y = w.dimen.h, w = w.dimen.w, h = sh - w.dimen.h },
            },
        }
        w.onTapNavbar = function(_, _, ges)
            self:closeAllViews()
            -- Reenviar el toque para que lo reciba la barra de ZenOS (pestaña tocada).
            UIManager:nextTick(function()
                UIManager:sendEvent(Event:new("Gesture", ges))
            end)
            return true
        end
    end
end

function Ctx:releaseView(w)
    if self.views then self.views[w] = nil end
end

function Ctx:closeAllViews()
    local list = {}
    for w in pairs(self.views or {}) do list[#list + 1] = w end
    for _, w in ipairs(list) do UIManager:close(w) end
    self.views = {}
end

function Ctx:syncOnOpen()
    return self.settings:readSetting("sync_on_open") == true
end

-- ── Diálogos ───────────────────────────────────────────────────────────────

-- Muestra una ventana (menú, confirmación, teclado…) con el resto de la pantalla rayado.
-- El fondo se cierra solo cuando la ventana se cierra.
function Ctx:showDialog(dialog)
    local backdrop = Backdrop:new{}
    -- El refresco del rayado se pide de forma explícita y para TODA la pantalla; si no, solo se
    -- refresca la zona de la ventana y el rayado se ve apenas alrededor de ella.
    -- Modo "partial" + dither (no "ui"): la forma de onda rápida deja restos de color de la vista
    -- anterior (p. ej. los círculos de color del editor asomando bajo la ventana).
    local mode = self:refreshMode()
    UIManager:show(backdrop, mode, backdrop.dimen, nil, nil, true)
    require("calendario_widgets").squareButtons(dialog)
    UIManager:show(dialog)
    UIManager:setDirty(backdrop, function() return mode, backdrop.dimen, true end)
    local orig = dialog.onCloseWidget
    dialog.onCloseWidget = function(this, ...)
        UIManager:close(backdrop, mode, backdrop.dimen, true)
        if orig then return orig(this, ...) end
    end
end

function Ctx:info(text, timeout)
    UIManager:show(InfoMessage:new{ text = text, timeout = timeout })
end

function Ctx:confirm(text, ok_text, on_ok)
    self:showDialog(ConfirmBox:new{
        text = text,
        ok_text = ok_text,
        cancel_text = self:t("cancel"),
        ok_callback = on_ok,
    })
end

-- Pide un texto (una línea o varias) y llama on_done(valor).
function Ctx:askText(title, value, multiline, hint, on_done)
    local dlg
    dlg = InputDialog:new{
        title = title,
        input = value or "",
        input_hint = hint,
        allow_newline = multiline and true or false,
        buttons = {{
            {
                text = self:t("cancel"),
                id = "close",
                callback = function() UIManager:close(dlg) end,
            },
            {
                text = self:t("ok"),
                is_enter_default = not multiline,
                callback = function()
                    local v = dlg:getInputText()
                    UIManager:close(dlg)
                    on_done(v)
                end,
            },
        }},
    }
    self:showDialog(dlg)
    dlg:onShowKeyboard()
end

-- ── WebDAV ─────────────────────────────────────────────────────────────────

function Ctx:getSyncConfig()
    return {
        url = self.settings:readSetting("dav_url") or "",
        user = self.settings:readSetting("dav_user") or "",
        pass = self.settings:readSetting("dav_pass") or "",
        file = self.settings:readSetting("dav_file") or "",
    }
end

function Ctx:isSyncConfigured()
    return self:getSyncConfig().url ~= ""
end

function Ctx:syncDialog()
    local cfg = self:getSyncConfig()
    local sync_open = self:syncOnOpen()
    local function toggle_label()
        return self:t("sync_on_open", self:t(sync_open and "yes" or "no"))
    end
    local dlg
    dlg = MultiInputDialog:new{
        title = self:t("sync_title"),
        fields = {
            { text = cfg.url, hint = self:t("sync_hint_url") },
            { text = cfg.user, hint = self:t("sync_hint_user") },
            { text = cfg.pass, hint = self:t("sync_hint_pass"), text_type = "password" },
            { text = cfg.file, hint = self:t("sync_hint_file") },
        },
        buttons = {
        {
            {
                text = toggle_label(),
                id = "toggle_open",
                callback = function()
                    sync_open = not sync_open
                    local btn = dlg.button_table and dlg.button_table:getButtonById("toggle_open")
                    if btn then
                        btn:setText(toggle_label(), btn.width)
                        UIManager:setDirty(dlg, "ui")
                    end
                end,
            },
        },
        {
            {
                text = self:t("cancel"),
                id = "close",
                callback = function() UIManager:close(dlg) end,
            },
            {
                text = self:t("save"),
                callback = function()
                    local f = dlg:getFields()
                    UIManager:close(dlg)
                    local url = ((f[1] or ""):gsub("^%s+", ""))
                    url = (url:gsub("%s+$", ""))
                    local file = ((f[4] or ""):gsub("%s+", ""))
                    self.settings:saveSetting("dav_url", url)
                    self.settings:saveSetting("dav_user", f[2] or "")
                    self.settings:saveSetting("dav_pass", f[3] or "")
                    self.settings:saveSetting("dav_file", file)
                    self.settings:saveSetting("sync_on_open", sync_open)
                    self.settings:flush()
                    self:info(self:t("sync_saved"), 2)
                end,
            },
        },
        },
    }
    self:showDialog(dlg)
    dlg:onShowKeyboard()
end

-- Sincroniza ahora. on_done(ok) se llama al terminar (para refrescar la vista).
function Ctx:syncNow(on_done)
    if not self:isSyncConfigured() then
        self:info(self:t("sync_not_configured"))
        return
    end
    NetworkMgr:runWhenOnline(function()
        local info = InfoMessage:new{ text = self:t("syncing") }
        UIManager:show(info)
        UIManager:forceRePaint()
        local tr = function(k, ...) return self:t(k, ...) end
        local pok, ok, msg = pcall(Sync.run, self.store, self:getSyncConfig(), tr)
        if not pok then
            ok, msg = false, self:t("sync_net_error", tostring(ok))
        end
        UIManager:close(info)
        self:info(msg, ok and 2 or nil)
        if ok then
            self.settings:saveSetting("last_sync", os.time())
            self.settings:flush()
        end
        if on_done then on_done(ok) end
    end)
end

return Ctx
