# 基于 OpenResty LuaJIT 的极光推送 REST API 调用库

极光推送官方提供了 Java、Python、PHP、Go 等多种语言的 SDK，但并未提供 OpenResty/Lua 版本。极光推送的核心 API 包括推送 API（`POST /v3/push`）、统计 API（`GET /v3/received`）、标签别名 API（`/v3/devices`）以及定时任务 API（`/v3/schedules`），通过 Base URL 分别为 `https://api.jpush.cn`、`https://report.jpush.cn`、`https://device.jpush.cn` 进行区分。本文提供一个完整的 `resty.jpush` 库实现，帮助开发者在 OpenResty 环境中便捷地调用极光推送服务。

---

## 一、库的整体设计

### 1.1 设计原则

1. **模块化**：按照 API 资源类型将功能拆分到独立的子模块中（Push、Device、Report、Schedule）。
2. **面向对象**：通过 `new()` 工厂方法创建客户端实例，支持多应用配置。
3. **错误统一处理**：定义标准错误码和统一的错误返回格式。
4. **连接复用**：利用 `lua-resty-http` 的连接池机制，提高 HTTPS 请求性能。

### 1.2 目录结构

```
/usr/local/openresty/lualib/resty/jpush/
├── init.lua           -- 主入口，客户端类
├── push.lua           -- 推送 API 模块
├── device.lua         -- 标签别名 API 模块
├── report.lua         -- 统计 API 模块
├── schedule.lua       -- 定时任务 API 模块
└── utils.lua          -- 工具函数（鉴权、HTTP 请求封装）
```

### 1.3 依赖

- `lua-resty-http`：用于发起 HTTPS 请求的 cosocket 驱动库，可通过 opm 安装
- `cjson`：OpenResty 内置的 JSON 编解码库

---

## 二、核心模块实现

### 2.1 工具模块 (`utils.lua`)

```lua
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

-- 获取频率限制信息（从响应头提取）
function _M.extract_rate_limit_info(headers)
    return {
        limit = tonumber(headers["X-Rate-Limit-Limit"]),
        remaining = tonumber(headers["X-Rate-Limit-Remaining"]),
        reset = tonumber(headers["X-Rate-Limit-Reset"]),
    }
end

return _M
```

### 2.2 主入口模块 (`init.lua`)

```lua
-- init.lua - 主入口，客户端类
local http = require("resty.http")
local utils = require("resty.jpush.utils")
local push = require("resty.jpush.push")
local device = require("resty.jpush.device")
local report = require("resty.jpush.report")
local schedule = require("resty.jpush.schedule")

local _M = {}

-- 默认 API 地址
_M.DEFAULT_BASE_URLS = {
    push = "https://api.jpush.cn",
    report = "https://report.jpush.cn",
    device = "https://device.jpush.cn",
    schedule = "https://api.jpush.cn",  -- 定时任务复用推送 API 地址
}

-- 客户端元表
local client_mt = {}
client_mt.__index = client_mt

-- 创建新的 JPush 客户端实例
function _M.new(config)
    local app_key = config.app_key
    local master_secret = config.master_secret

    if not app_key or not master_secret then
        error("app_key and master_secret are required")
    end

    local client = {
        app_key = app_key,
        master_secret = master_secret,
        auth_header = utils.generate_auth_header(app_key, master_secret),
        base_urls = config.base_urls or _M.DEFAULT_BASE_URLS,
        timeout = config.timeout or 10000,  -- 默认 10 秒
        ssl_verify = config.ssl_verify ~= false,  -- 默认开启 SSL 验证
        debug = config.debug or false,
    }

    -- 创建 HTTP 客户端
    client.httpc = http.new()
    client.httpc:set_timeout(client.timeout)

    -- 挂载子模块
    client.push = push.new(client)
    client.device = device.new(client)
    client.report = report.new(client)
    client.schedule = schedule.new(client)

    return setmetatable(client, client_mt)
end

-- 获取频率限制信息（从最近一次请求）
function client_mt:get_rate_limit()
    return self.last_rate_limit or {}
end

-- 更新鉴权信息（用于动态更新 app_key 和 master_secret）
function client_mt:update_auth(app_key, master_secret)
    self.app_key = app_key
    self.master_secret = master_secret
    self.auth_header = utils.generate_auth_header(app_key, master_secret)
    return true
end

return _M
```

### 2.3 推送 API 模块 (`push.lua`)

推送 API 支持向单设备或设备列表推送通知、消息，推送内容必须是 JSON 格式的推送对象，核心字段包括 `platform`（推送平台）、`audience`（推送设备指定）、`notification`（通知内容）、`message`（自定义消息）。

```lua
-- push.lua - 推送 API 模块
local cjson = require("cjson.safe")
local utils = require("resty.jpush.utils")

local _M = {}

function _M.new(client)
    local self = {
        client = client,
        base_url = client.base_urls.push .. "/v3/push",
    }
    return setmetatable(self, { __index = _M })
end

-- 验证推送对象
local function validate_push_payload(payload)
    if not payload.platform then
        return false, "platform is required"
    end
    if not payload.audience then
        return false, "audience is required"
    end
    if not payload.notification and not payload.message then
        return false, "at least one of notification or message is required"
    end
    return true
end

-- 发送推送
function _M:send(payload)
    local ok, err_msg = validate_push_payload(payload)
    if not ok then
        return utils.build_error_response(
            utils.ERROR_CODES.PARAM_ERROR,
            err_msg,
            400
        )
    end

    local httpc = self.client.httpc
    local res, err = httpc:request_uri(self.base_url, {
        method = "POST",
        body = cjson.encode(payload),
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = self.client.auth_header,
            ["User-Agent"] = "OpenResty-JPush-Client/1.0",
        },
        ssl_verify = self.client.ssl_verify,
    })

    -- 记录频率限制信息
    if res and res.headers then
        self.client.last_rate_limit = utils.extract_rate_limit_info(res.headers)
    end

    -- 记录调试日志
    if self.client.debug and res then
        ngx.log(ngx.INFO, "[JPush] Push response status: ", res.status)
    end

    return utils.parse_response(res, err)
end

-- 便捷方法：向所有用户推送通知
function _M:send_to_all(alert, options)
    local payload = {
        platform = options and options.platform or "all",
        audience = "all",
        notification = { alert = alert },
        options = options or {},
    }
    return self:send(payload)
end

-- 便捷方法：向指定别名推送通知
function _M:send_to_alias(alias, alert, options)
    local audience = type(alias) == "table" and { alias = alias } or { alias = { alias } }
    local payload = {
        platform = options and options.platform or "all",
        audience = audience,
        notification = { alert = alert },
        options = options or {},
    }
    return self:send(payload)
end

-- 便捷方法：向指定标签推送通知
function _M:send_to_tag(tag, alert, options)
    local audience = type(tag) == "table" and { tag = tag } or { tag = { tag } }
    local payload = {
        platform = options and options.platform or "all",
        audience = audience,
        notification = { alert = alert },
        options = options or {},
    }
    return self:send(payload)
end

-- 便捷方法：向指定 registration_id 推送通知
function _M:send_to_registration_id(reg_id, alert, options)
    local audience = type(reg_id) == "table"
        and { registration_id = reg_id }
        or { registration_id = { reg_id } }
    local payload = {
        platform = options and options.platform or "all",
        audience = audience,
        notification = { alert = alert },
        options = options or {},
    }
    return self:send(payload)
end

-- 便捷方法：发送自定义消息（不展示通知栏）
function _M:send_message(audience, msg_content, options)
    local payload = {
        platform = options and options.platform or "all",
        audience = audience,
        message = {
            msg_content = msg_content,
            content_type = options and options.content_type or "text",
            title = options and options.title,
            extras = options and options.extras,
        },
        options = options or {},
    }
    return self:send(payload)
end

-- 验证推送对象是否有效（用于预览）
function _M:validate(payload)
    local ok, err_msg = validate_push_payload(payload)
    if not ok then
        return { valid = false, error = err_msg }
    end
    return { valid = true, error = nil }
end

return _M
```

### 2.4 标签别名 API 模块 (`device.lua`)

标签别名 API 用于管理设备的标签（tag）和别名（alias）。每个设备（通过 registration_id 标识）最多可绑定 1000 个标签，每个别名下最多可绑定 10 个设备。

```lua
-- device.lua - 标签别名 API 模块
local cjson = require("cjson.safe")
local utils = require("resty.jpush.utils")

local _M = {}

function _M.new(client)
    local self = {
        client = client,
        base_url = client.base_urls.device .. "/v3",
    }
    return setmetatable(self, { __index = _M })
end

-- 获取设备的标签列表
function _M:get_tags(registration_id)
    local httpc = self.client.httpc
    local url = self.base_url .. "/devices/" .. registration_id

    local res, err = httpc:request_uri(url, {
        method = "GET",
        headers = {
            ["Authorization"] = self.client.auth_header,
            ["User-Agent"] = "OpenResty-JPush-Client/1.0",
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

-- 更新设备的标签（覆盖式更新）
function _M:set_tags(registration_id, tags)
    local httpc = self.client.httpc
    local url = self.base_url .. "/devices/" .. registration_id

    local payload = {
        tags = {
            add = tags or {},
        },
    }

    local res, err = httpc:request_uri(url, {
        method = "POST",
        body = cjson.encode(payload),
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

-- 添加/删除设备的标签
function _M:update_tags(registration_id, add_tags, remove_tags)
    local httpc = self.client.httpc
    local url = self.base_url .. "/devices/" .. registration_id

    local payload = {
        tags = {
            add = add_tags or {},
            remove = remove_tags or {},
        },
    }

    local res, err = httpc:request_uri(url, {
        method = "POST",
        body = cjson.encode(payload),
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

-- 清除设备的所有标签
function _M:clear_tags(registration_id)
    return self:set_tags(registration_id, {})
end

-- 获取设备的别名
function _M:get_alias(registration_id)
    local httpc = self.client.httpc
    local url = self.base_url .. "/aliases/" .. registration_id

    local res, err = httpc:request_uri(url, {
        method = "GET",
        headers = {
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

-- 设置设备的别名
function _M:set_alias(registration_id, alias)
    local httpc = self.client.httpc
    local url = self.base_url .. "/devices/" .. registration_id

    local payload = {
        alias = alias,
    }

    local res, err = httpc:request_uri(url, {
        method = "POST",
        body = cjson.encode(payload),
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

-- 删除别名
function _M:delete_alias(alias, platforms)
    local httpc = self.client.httpc
    local url = self.base_url .. "/aliases/" .. alias

    local query_params = {}
    if platforms then
        query_params.platform = platforms
    end

    local res, err = httpc:request_uri(url, {
        method = "DELETE",
        query = query_params,
        headers = {
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

-- 获取标签下的所有设备
function _M:get_devices_by_tag(tag, registration_id)
    local httpc = self.client.httpc
    local url = self.base_url .. "/tags/" .. tag

    local query_params = {}
    if registration_id then
        query_params.registration_id = registration_id
    end

    local res, err = httpc:request_uri(url, {
        method = "GET",
        query = query_params,
        headers = {
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

-- 判断设备是否在标签下
function _M:check_device_in_tag(registration_id, tag)
    local httpc = self.client.httpc
    local url = self.base_url .. "/tags/" .. tag .. "/registration_ids/" .. registration_id

    local res, err = httpc:request_uri(url, {
        method = "GET",
        headers = {
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    local result = utils.parse_response(res, err)
    if result.success then
        result.data = { exists = result.data.result or false }
    end
    return result
end

-- 批量添加/删除标签下的设备
function _M:update_tag_devices(tag, add_reg_ids, remove_reg_ids)
    local httpc = self.client.httpc
    local url = self.base_url .. "/tags/" .. tag

    local payload = {
        registration_ids = {
            add = add_reg_ids or {},
            remove = remove_reg_ids or {},
        },
    }

    local res, err = httpc:request_uri(url, {
        method = "POST",
        body = cjson.encode(payload),
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

-- 删除标签
function _M:delete_tag(tag, platforms)
    local httpc = self.client.httpc
    local url = self.base_url .. "/tags/" .. tag

    local query_params = {}
    if platforms then
        query_params.platform = platforms
    end

    local res, err = httpc:request_uri(url, {
        method = "DELETE",
        query = query_params,
        headers = {
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

return _M
```

### 2.5 统计 API 模块 (`report.lua`)

统计 API 用于获取推送消息的送达统计数据。每条推送消息的统计数据最多保留一个月。

```lua
-- report.lua - 统计 API 模块
local utils = require("resty.jpush.utils")

local _M = {}

function _M.new(client)
    local self = {
        client = client,
        base_url = client.base_urls.report .. "/v3",
    }
    return setmetatable(self, { __index = _M })
end

-- 获取消息送达统计
function _M:get_received(msg_ids)
    local httpc = self.client.httpc
    local url = self.base_url .. "/received"

    local msg_id_str
    if type(msg_ids) == "table" then
        msg_id_str = table.concat(msg_ids, ",")
    else
        msg_id_str = tostring(msg_ids)
    end

    local res, err = httpc:request_uri(url, {
        method = "GET",
        query = { msg_ids = msg_id_str },
        headers = {
            ["Authorization"] = self.client.auth_header,
            ["User-Agent"] = "OpenResty-JPush-Client/1.0",
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

-- 获取消息详情（含送达状态）
function _M:get_message_detail(msg_id, registration_ids)
    local httpc = self.client.httpc
    local url = self.base_url .. "/messages/" .. msg_id

    local query_params = {}
    if registration_ids then
        if type(registration_ids) == "table" then
            query_params.registration_ids = table.concat(registration_ids, ",")
        else
            query_params.registration_ids = tostring(registration_ids)
        end
    end

    local res, err = httpc:request_uri(url, {
        method = "GET",
        query = query_params,
        headers = {
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

-- 获取用户统计（在线状态、活跃度等）
function _M:get_user_stat(registration_ids)
    local httpc = self.client.httpc
    local url = self.base_url .. "/users"

    local reg_id_str
    if type(registration_ids) == "table" then
        reg_id_str = table.concat(registration_ids, ",")
    else
        reg_id_str = tostring(registration_ids)
    end

    local res, err = httpc:request_uri(url, {
        method = "GET",
        query = { registration_ids = reg_id_str },
        headers = {
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

return _M
```

### 2.6 定时任务 API 模块 (`schedule.lua`)

定时任务 API 用于创建、查询、更新和删除定时推送任务，支持单次定时任务和周期性任务。

```lua
-- schedule.lua - 定时任务 API 模块
local cjson = require("cjson.safe")
local utils = require("resty.jpush.utils")

local _M = {}

function _M.new(client)
    local self = {
        client = client,
        base_url = client.base_urls.schedule .. "/v3/schedules",
    }
    return setmetatable(self, { __index = _M })
end

-- 创建单次定时任务
function _M:create_single(name, push_payload, trigger_time)
    local httpc = self.client.httpc

    local payload = {
        name = name,
        enabled = true,
        trigger = {
            single = {
                time = trigger_time,  -- 格式: "2026-12-31 23:59:59"
            },
        },
        push = push_payload,
    }

    local res, err = httpc:request_uri(self.base_url, {
        method = "POST",
        body = cjson.encode(payload),
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

-- 创建周期性定时任务
function _M:create_periodical(name, push_payload, periodical_config)
    local httpc = self.client.httpc

    local payload = {
        name = name,
        enabled = true,
        trigger = {
            periodical = periodical_config,  -- { start, end, time, time_unit, frequency, point }
        },
        push = push_payload,
    }

    local res, err = httpc:request_uri(self.base_url, {
        method = "POST",
        body = cjson.encode(payload),
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

-- 获取定时任务列表
function _M:get_list(page)
    local httpc = self.client.httpc
    local query_params = page and { page = page } or {}

    local res, err = httpc:request_uri(self.base_url, {
        method = "GET",
        query = query_params,
        headers = {
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

-- 获取指定定时任务详情
function _M:get(schedule_id)
    local httpc = self.client.httpc
    local url = self.base_url .. "/" .. schedule_id

    local res, err = httpc:request_uri(url, {
        method = "GET",
        headers = {
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

-- 更新定时任务
function _M:update(schedule_id, update_data)
    local httpc = self.client.httpc
    local url = self.base_url .. "/" .. schedule_id

    local res, err = httpc:request_uri(url, {
        method = "PUT",
        body = cjson.encode(update_data),
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

-- 删除定时任务
function _M:delete(schedule_id)
    local httpc = self.client.httpc
    local url = self.base_url .. "/" .. schedule_id

    local res, err = httpc:request_uri(url, {
        method = "DELETE",
        headers = {
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

return _M
```

---

## 三、错误处理与频率控制

极光 API 具有频率控制机制，免费版本每分钟有调用次数限制，广播推送每天限制 10 次。当超出频率限制时，API 返回 HTTP 429 状态码和错误码 2002。库中已通过 `utils.parse_response` 统一处理各种错误响应，并在每次请求后提取响应头中的频率限制信息（`X-Rate-Limit-Limit`、`X-Rate-Limit-Remaining`、`X-Rate-Limit-Reset`），可通过 `client:get_rate_limit()` 获取。

```lua
-- 检查频率限制示例
local result = client.push:send_to_all("Hello")
if not result.success then
    if result.error.code == 2002 then
        ngx.log(ngx.WARN, "Rate limit exceeded")
    end
else
    local rate_info = client:get_rate_limit()
    ngx.log(ngx.INFO, "Remaining calls: ", rate_info.remaining)
end
```

---

## 四、安装与配置

### 4.1 安装依赖

```bash
# 使用 opm 安装 lua-resty-http
opm get ledgetech/lua-resty-http

# 或手动下载
cd /usr/local/openresty/lualib/resty/
wget https://raw.githubusercontent.com/ledgetech/lua-resty-http/master/lib/resty/http.lua
wget https://raw.githubusercontent.com/ledgetech/lua-resty-http/master/lib/resty/http_headers.lua
```

### 4.2 配置 Nginx

```nginx
http {
    lua_package_path "/usr/local/openresty/lualib/?.lua;;";
    lua_shared_dict jpush_config 10m;  -- 可选：存储配置信息

    server {
        listen 8080;

        location /jpush/send {
            content_by_lua_block {
                local jpush = require("resty.jpush")

                -- 创建客户端实例
                local client = jpush.new({
                    app_key = "your_app_key",
                    master_secret = "your_master_secret",
                    timeout = 10000,  -- 10 秒超时
                    ssl_verify = true,
                    debug = false,
                })

                -- 读取请求体并调用推送 API
                ngx.req.read_body()
                local body = ngx.req.get_body_data()
                local cjson = require("cjson.safe")
                local payload = cjson.decode(body)

                local result = client.push:send(payload)
                ngx.say(cjson.encode(result))
            }
        }
    }
}
```

---

## 五、完整使用示例

### 5.1 推送通知

```lua
local jpush = require("resty.jpush")

-- 创建客户端
local client = jpush.new({
    app_key = "your_app_key",
    master_secret = "your_master_secret",
})

-- 向所有用户推送通知
local result = client.push:send_to_all("Hello from OpenResty!")

-- 向指定别名推送
result = client.push:send_to_alias("user_123", "You have a new message")

-- 向多个别名推送
result = client.push:send_to_alias({"user_123", "user_456"}, "Group notification")

-- 向指定标签推送
result = client.push:send_to_tag("vip_users", "VIP exclusive offer")

-- 自定义推送内容（支持 Android/iOS 差异化配置）
local payload = {
    platform = {"android", "ios"},
    audience = { tag = {"active_users"} },
    notification = {
        alert = "Hello",
        android = {
            title = "New Message",
            alert = "You have a new message",
            builder_id = 1,
            extras = { key = "value" }
        },
        ios = {
            alert = "You have a new message",
            sound = "default",
            badge = "+1",
            extras = { key = "value" }
        }
    },
    options = {
        time_to_live = 60,
        apns_production = false,  -- 开发环境，生产环境需设为 true
    }
}
result = client.push:send(payload)
```

### 5.2 设备管理

```lua
-- 设置设备标签
local result = client.device:set_tags("191e35f7e07c2b2315f", {"active", "vip"})

-- 添加/删除标签
result = client.device:update_tags("191e35f7e07c2b2315f", {"new_tag"}, {"old_tag"})

-- 设置设备别名
result = client.device:set_alias("191e35f7e07c2b2315f", "user_123")

-- 查询设备标签
result = client.device:get_tags("191e35f7e07c2b2315f")
```

### 5.3 统计查询

```lua
-- 查询消息送达统计
local result = client.report:get_received("1828256757")

-- 查询多个消息的统计
result = client.report:get_received({"1828256757", "1828256758"})

-- 查询消息详情
result = client.report:get_message_detail("1828256757", {"191e35f7e07c2b2315f"})
```

### 5.4 定时任务

```lua
-- 创建单次定时任务（2026年12月31日23:59:59推送）
local payload = {
    platform = "all",
    audience = "all",
    notification = { alert = "Happy New Year!" }
}
local result = client.schedule:create_single("NewYearPush", payload, "2026-12-31 23:59:59")

-- 创建每日定时任务
local periodical_config = {
    start = "2026-01-01 09:00:00",
    end = "2026-12-31 09:00:00",
    time = "09:00:00",
    time_unit = "DAY",
    frequency = 1,
    point = {}
}
result = client.schedule:create_periodical("DailyNews", payload, periodical_config)

-- 获取定时任务列表
result = client.schedule:get_list(1)

-- 删除定时任务
result = client.schedule:delete("schedule_id_here")
```

---

## 六、注意事项

1. **鉴权信息保管**：MasterSecret 拥有完全的 API 调用权限，切勿暴露在客户端代码中。建议使用 OpenResty 的 `lua_shared_dict` 或环境变量存储配置信息。
2. **iOS 环境配置**：推送 iOS 设备时需正确设置 `options.apns_production` 参数，`true` 表示生产环境，`false` 表示开发环境。
3. **频率限制**：注意 API 调用频率，超出限制会返回 429 状态码和错误码 2002。广播推送每天限制 10 次。
4. **连接池优化**：生产环境中建议调用 `httpc:set_keepalive()` 复用 HTTPS 连接，提升性能。
5. **SSL 验证**：生产环境务必开启 `ssl_verify = true`，防止中间人攻击。
6. **北京机房**：如果应用部署在北京机房且调用方服务器也在北京，可使用 `https://bjapi.push.jiguang.cn/v3/push` 获得更快的响应速度。