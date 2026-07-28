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