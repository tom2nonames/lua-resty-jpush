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