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