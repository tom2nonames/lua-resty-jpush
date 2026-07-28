-- utils.lua - 工具函数模块
local cjson = require("cjson.safe")
local ngx_base64 = ngx.encode_base64

local _M = {}

-- 错误码定义
_M.ERROR_CODES = {
    SUCCESS = 0,
    NETWORK_ERROR = 1001,
    AUTH_ERROR = 1002,
    PARAM_ERROR = 1003,
    RATE_LIMIT = 1004,
    SERVER_ERROR = 1005,
    UNKNOWN_ERROR = 1999,
}

-- 连接池默认配置
_M.KEEPALIVE_TIMEOUT = 60000  -- 空闲连接超时（毫秒）
_M.KEEPALIVE_POOL_SIZE = 100  -- 连接池最大连接数

-- 生成 Basic Auth 鉴权头
function _M.generate_auth_header(app_key, master_secret)
    local auth_string = app_key .. ":" .. master_secret
    return "Basic " .. ngx_base64(auth_string)
end

-- 构建标准错误响应
function _M.build_error_response(code, message, http_status)
    return {
        success = false,
        error = {
            code = code,
            message = message,
            http_status = http_status or 500,
        }
    }
end

-- 构建标准成功响应
function _M.build_success_response(data)
    return {
        success = true,
        data = data,
    }
end

-- 解析 JPush API 响应
function _M.parse_response(res, err)
    if not res then
        return _M.build_error_response(
            _M.ERROR_CODES.NETWORK_ERROR,
            "HTTP request failed: " .. (err or "unknown error")
        )
    end

    local body = res.body
    local decoded, decode_err = cjson.decode(body)

    if not decoded then
        return _M.build_error_response(
            _M.ERROR_CODES.SERVER_ERROR,
            "Failed to parse response: " .. (decode_err or "invalid JSON")
        )
    end

    if res.status == 200 then
        return _M.build_success_response(decoded)
    else
        local error_code = decoded.error and decoded.error.code or res.status
        local error_msg = decoded.error and decoded.error.message or "Unknown error"
        return _M.build_error_response(error_code, error_msg, res.status)
    end
end

-- 统一的 HTTP 请求封装，自动处理连接归还到连接池
function _M.request(client, url, params)
    local httpc = client.httpc
    local res, err = httpc:request_uri(url, params)

    -- 记录频率限制信息
    if res and res.headers then
        client.last_rate_limit = _M.extract_rate_limit_info(res.headers)
    end

    -- 将连接归还到连接池
    if httpc.set_keepalive then
        httpc:set_keepalive(_M.KEEPALIVE_TIMEOUT, _M.KEEPALIVE_POOL_SIZE)
    end

    return res, err
end

-- 带调试日志的请求封装
function _M.request_with_debug(client, url, params, tag)
    if client.debug then
        ngx.log(ngx.INFO, "[JPush] " .. (tag or "") .. " request to: " .. url)
    end

    local res, err = _M.request(client, url, params)

    if client.debug and res then
        ngx.log(ngx.INFO, "[JPush] " .. (tag or "") .. " response status: ", res.status)
    end

    return res, err
end

-- 获取频率限制信息（从响应头提取）
function _M.extract_rate_limit_info(headers)
    return {
        limit = tonumber(headers["X-Rate-Limit-Limit"]),
        remaining = tonumber(headers["X-Rate-Limit-Remaining"]),
        reset = tonumber(headers["X-Rate-Limit-Reset"]),
    }
end

return _M
