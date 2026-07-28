-- spec_helper.lua
-- Mock ngx globals, cjson, and resty.http for unit testing.
-- NOTE: Uses package.loaded instead of package.preload because
-- LuaRocks' loader takes precedence over the standard preload searcher.

-- -----------------------------------------------------------
-- Mock cjson and cjson.safe (pure Lua implementation)
-- -----------------------------------------------------------
do
    local json = require("spec.helpers.json")
    local cjson = {}
    function cjson.decode(str) return json.decode(str) end
    function cjson.encode(t) return json.encode(t) end
    package.loaded["cjson"] = cjson

    local safe = {}
    function safe.decode(str)
        local ok, result = pcall(cjson.decode, str)
        if ok and result ~= nil then return result end
        return nil, result or "invalid json"
    end
    function safe.encode(t)
        local ok, result = pcall(cjson.encode, t)
        if ok then return result end
        return nil, result
    end
    package.loaded["cjson.safe"] = safe
end

-- -----------------------------------------------------------
-- Mock ngx global
-- -----------------------------------------------------------
local mock_log = {}
_G.__mock_log = mock_log

local mock_ngx = {
    INFO = 7,
    WARN = 5,
    ERROR = 3,
    log = function(level, ...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[i] = tostring(select(i, ...))
        end
        table.insert(mock_log, { level = level, msg = table.concat(parts, " ") })
    end,
    encode_base64 = function(input)
        local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
        local bytes = {}
        for i = 1, #input do bytes[i] = string.byte(input, i) end
        local result = {}
        for i = 1, #bytes, 3 do
            local a, b1, c = bytes[i], bytes[i+1], bytes[i+2]
            table.insert(result, string.sub(b, math.floor(a / 4) + 1, math.floor(a / 4) + 1))
            local val = (a % 4) * 16
            if b1 then val = val + math.floor(b1 / 16) end
            table.insert(result, string.sub(b, val + 1, val + 1))
            if b1 then
                local val2 = (b1 % 16) * 4
                if c then val2 = val2 + math.floor(c / 64) end
                table.insert(result, string.sub(b, val2 + 1, val2 + 1))
            else
                table.insert(result, "=")
            end
            if c then
                table.insert(result, string.sub(b, (c % 64) + 1, (c % 64) + 1))
            else
                table.insert(result, "=")
            end
        end
        return table.concat(result)
    end,
}

if not _G.ngx then
    _G.ngx = mock_ngx
end

-- -----------------------------------------------------------
-- Mock resty.http (directly in package.loaded to bypass LuaRocks loader)
-- -----------------------------------------------------------
do
    local mt = {}

    function mt.set_timeout(self, timeout)
        self._timeout = timeout
    end

    function mt.request_uri(self, url, params)
        self._request_count = (self._request_count or 0) + 1
        local item = table.remove(self._responses, 1)
        if item then
            if item.err then return nil, item.err end
            return item.res, nil
        end
        return { status = 200, body = '{}', headers = {} }, nil
    end

    function mt.set_keepalive(self, timeout, pool_size)
        self._keepalive_timeout = timeout
        self._keepalive_pool_size = pool_size
        return true
    end

    function mt.___queue_response(self, status, body, headers)
        table.insert(self._responses, {
            res = { status = status, body = body, headers = headers or {} }
        })
    end

    function mt.___queue_error(self, err_msg)
        table.insert(self._responses, { err = err_msg })
    end

    function mt.___clear_queue(self)
        self._responses = {}
    end

    local http_mod = {}
    function http_mod.new()
        local inst = {
            _timeout = nil,
            _responses = {},
            _keepalive_timeout = nil,
            _keepalive_pool_size = nil,
            _request_count = 0,
        }
        setmetatable(inst, { __index = mt })
        return inst
    end
    package.loaded["resty.http"] = http_mod
end

-- -----------------------------------------------------------
-- Test utilities
-- -----------------------------------------------------------
local _M = {}

function _M.queue_response(client, status, body, headers)
    client.httpc:___queue_response(status, body, headers)
end

function _M.queue_error(client, err_msg)
    client.httpc:___queue_error(err_msg)
end

function _M.clear_queue(client)
    if client then client.httpc:___clear_queue() end
end

function _M.clear_log()
    for i = #mock_log, 1, -1 do mock_log[i] = nil end
end

function _M.get_log()
    local copy = {}
    for i, v in ipairs(mock_log) do copy[i] = v end
    return copy
end

function _M.create_client(overrides)
    local jpush = require("resty.jpush")
    local config = {
        app_key = "test_app_key",
        master_secret = "test_master_secret",
        timeout = 5000,
        ssl_verify = false,
    }
    if overrides then
        for k, v in pairs(overrides) do config[k] = v end
    end
    return jpush.new(config)
end

-- Register in package.loaded so that require("spec.spec_helper") from
-- test files returns THIS module (not a fresh copy with separate closures)
package.loaded["spec.spec_helper"] = _M

return _M
