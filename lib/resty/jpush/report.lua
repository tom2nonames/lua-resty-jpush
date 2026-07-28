-- report.lua - 统计 API 模块
-- 覆盖 JPush Report API V3 全部接口
local cjson = require("cjson.safe")
local utils = require("resty.jpush.utils")

local _M = {}

function _M.new(client)
    local self = {
        client = client,
        base_url = client.base_urls.report .. "/v3",
    }
    return setmetatable(self, { __index = _M })
end

-- 获取消息送达统计（老接口）
-- GET /v3/received?msg_ids=...
-- 每批最多 100 个 msg_id
function _M:get_received(msg_ids)
    local url = self.base_url .. "/received"

    local msg_id_str
    if type(msg_ids) == "table" then
        msg_id_str = table.concat(msg_ids, ",")
    else
        msg_id_str = tostring(msg_ids)
    end

    local res, err = utils.request(self.client, url, {
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

-- 获取消息送达统计详情（新接口，字段更丰富）
-- GET /v3/received/detail?msg_ids=...
-- 每批最多 100 个 msg_id
function _M:get_received_detail(msg_ids)
    local url = self.base_url .. "/received/detail"

    local msg_id_str
    if type(msg_ids) == "table" then
        msg_id_str = table.concat(msg_ids, ",")
    else
        msg_id_str = tostring(msg_ids)
    end

    local res, err = utils.request(self.client, url, {
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

-- 获取消息统计详情（老接口）
-- GET /v3/messages?msg_ids=...
-- 提供针对一个 msg_id 的更多统计数据
function _M:get_messages(msg_ids)
    local url = self.base_url .. "/messages"

    local msg_id_str
    if type(msg_ids) == "table" then
        msg_id_str = table.concat(msg_ids, ",")
    else
        msg_id_str = tostring(msg_ids)
    end

    local res, err = utils.request(self.client, url, {
        method = "GET",
        query = { msg_ids = msg_id_str },
        headers = {
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

-- 获取消息统计详情（新接口，VIP 专属，字段更丰富）
-- GET /v3/messages/detail?msg_ids=...
function _M:get_messages_detail(msg_ids)
    local url = self.base_url .. "/messages/detail"

    local msg_id_str
    if type(msg_ids) == "table" then
        msg_id_str = table.concat(msg_ids, ",")
    else
        msg_id_str = tostring(msg_ids)
    end

    local res, err = utils.request(self.client, url, {
        method = "GET",
        query = { msg_ids = msg_id_str },
        headers = {
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

-- 查询消息在某组设备上的送达状态
-- POST /v3/status/message
-- 建议仅作为排查工具使用
function _M:get_message_status(msg_id, registration_ids)
    local url = self.base_url .. "/status/message"

    local body = {
        msg_id = msg_id,
        registration_ids = registration_ids,
    }

    local res, err = utils.request(self.client, url, {
        method = "POST",
        body = cjson.encode(body),
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

-- 获取用户统计（在线状态、活跃度等）
-- GET /v3/users?time_unit=DAY&start=2014-06-10&duration=3
function _M:get_users(time_unit, start, duration)
    local url = self.base_url .. "/users"

    local res, err = utils.request(self.client, url, {
        method = "GET",
        query = {
            time_unit = time_unit,
            start = start,
            duration = duration,
        },
        headers = {
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

return _M
