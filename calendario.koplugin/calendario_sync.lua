-- Sincronización bilateral vía WebDAV (Nextcloud, ownCloud, etc.).
-- Un único archivo JSON remoto. Ciclo: GET → fusionar → (si hace falta) PUT condicional
-- con If-Match / If-None-Match para no pisar cambios de otro dispositivo.

local json = require("json")

local Sync = {}

local function request(cfg, method, target, headers, body)
    local ltn12 = require("ltn12")
    local mime = require("mime")
    local socketutil = require("socketutil")
    local http
    if target:match("^https://") then
        http = require("ssl.https")
    else
        http = require("socket.http")
    end

    local chunks = {}
    headers = headers or {}
    headers["Authorization"] = "Basic " .. mime.b64((cfg.user or "") .. ":" .. (cfg.pass or ""))
    if body then
        headers["Content-Type"] = "application/json; charset=utf-8"
        headers["Content-Length"] = tostring(#body)
    end

    local sink
    if socketutil.table_sink then
        sink = socketutil.table_sink(chunks)
    else
        sink = ltn12.sink.table(chunks)
    end

    socketutil:set_timeout(15, 45)
    local ok, r, code, resp_headers = pcall(http.request, {
        url = target,
        method = method,
        headers = headers,
        source = body and ltn12.source.string(body) or nil,
        sink = sink,
    })
    socketutil:reset_timeout()

    if not ok then return nil, tostring(r) end
    if r == nil then return nil, tostring(code) end
    return { code = tonumber(code), headers = resp_headers or {}, body = table.concat(chunks) }
end

-- cfg = { url=, user=, pass=, file= }, t = función de traducción t(key, ...)
-- Devuelve ok (bool), mensaje (string).
function Sync.run(store, cfg, t)
    if not cfg.url or cfg.url == "" then return false, t("sync_not_configured") end
    local base = (cfg.url:gsub("/+$", ""))
    local file = (cfg.file and cfg.file ~= "") and cfg.file or "calendario.json"
    local target = base .. "/" .. file
    local mkcol_tried = false

    for _ = 1, 4 do
        local res, err = request(cfg, "GET", target)
        if not res then return false, t("sync_net_error", err) end

        local remote_list, etag
        if res.code == 200 then
            local ok, data = pcall(json.decode, res.body)
            if not ok or type(data) ~= "table" then return false, t("sync_bad_remote") end
            remote_list = type(data.events) == "table" and data.events or {}
            etag = res.headers["etag"]
        elseif res.code == 404 then
            remote_list = nil
        elseif res.code == 401 or res.code == 403 then
            return false, t("sync_auth_error")
        else
            return false, t("sync_http_error", tostring(res.code))
        end

        store:mergeRemote(remote_list or {})

        if remote_list ~= nil and not store:needsUpload(remote_list) then
            return true, t("sync_ok")
        end

        local body = store:serialize()
        if not body then return false, t("sync_net_error", "json") end
        local headers = {}
        if remote_list == nil then
            headers["If-None-Match"] = "*"
        elseif etag then
            headers["If-Match"] = etag
        end

        local put, perr = request(cfg, "PUT", target, headers, body)
        if not put then return false, t("sync_net_error", perr) end
        local c = put.code
        if c == 200 or c == 201 or c == 204 then
            return true, t("sync_ok")
        elseif c == 401 or c == 403 then
            return false, t("sync_auth_error")
        elseif c == 409 then
            -- Falta la carpeta: intentar crearla una vez.
            if mkcol_tried then return false, t("sync_folder_missing") end
            mkcol_tried = true
            local mk = request(cfg, "MKCOL", base)
            if not mk or not (mk.code == 201 or mk.code == 405) then
                return false, t("sync_folder_missing")
            end
        elseif c == 412 then
            -- Cambió en el servidor mientras sincronizábamos: repetir el ciclo.
        else
            return false, t("sync_http_error", tostring(c))
        end
    end
    return false, t("sync_conflict")
end

return Sync
