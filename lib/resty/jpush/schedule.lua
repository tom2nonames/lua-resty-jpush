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