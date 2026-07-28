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

-- 获取设备的标签和别名
-- GET /v3/devices/{registration_id}
function _M:get_tags(registration_id)
    local url = self.base_url .. "/devices/" .. registration_id

    local res, err = utils.request(self.client, url, {
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
-- POST /v3/devices/{registration_id} with body { "tags": ["tag1", "tag2"] }
function _M:set_tags(registration_id, tags)
    local url = self.base_url .. "/devices/" .. registration_id

    local payload = {
        tags = tags or {},
    }

    local res, err = utils.request(self.client, url, {
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
-- POST /v3/devices/{registration_id} with body { "tags": { "add": [...], "remove": [...] } }
function _M:update_tags(registration_id, add_tags, remove_tags)
    local url = self.base_url .. "/devices/" .. registration_id

    local payload = {
        tags = {
            add = add_tags or {},
            remove = remove_tags or {},
        },
    }

    local res, err = utils.request(self.client, url, {
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

-- 获取设备信息（别名、标签、手机号）
-- GET /v3/devices/{registration_id}
function _M:get_device_info(registration_id)
    local url = self.base_url .. "/devices/" .. registration_id

    local res, err = utils.request(self.client, url, {
        method = "GET",
        headers = {
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    local result = utils.parse_response(res, err)
    if result.success then
        result.data = {
            alias = result.data.alias,
            tags = result.data.tags,
            mobile = result.data.mobile,
        }
    end
    return result
end

-- 设置设备的别名
-- POST /v3/devices/{registration_id} with body { "alias": "user_1" }
function _M:set_alias(registration_id, alias)
    local url = self.base_url .. "/devices/" .. registration_id

    local payload = {
        alias = alias,
    }

    local res, err = utils.request(self.client, url, {
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

-- 查询别名下的设备列表
-- GET /v3/aliases/{alias_value}
function _M:get_aliases(alias_value)
    local url = self.base_url .. "/aliases/" .. alias_value

    local res, err = utils.request(self.client, url, {
        method = "GET",
        headers = {
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

-- 删除别名
-- DELETE /v3/aliases/{alias_value}
function _M:delete_alias(alias_value, platforms)
    local url = self.base_url .. "/aliases/" .. alias_value

    local query_params = {}
    if platforms then
        query_params.platform = platforms
    end

    local res, err = utils.request(self.client, url, {
        method = "DELETE",
        query = query_params,
        headers = {
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

-- 获取标签列表
-- GET /v3/tags/
function _M:get_tags_list()
    local url = self.base_url .. "/tags/"

    local res, err = utils.request(self.client, url, {
        method = "GET",
        headers = {
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

-- 查询标签下的设备
-- GET /v3/tags/{tag_value}/registration_ids/
function _M:get_devices_by_tag(tag_value, registration_id)
    local url = self.base_url .. "/tags/" .. tag_value .. "/registration_ids/"

    local query_params = {}
    if registration_id then
        query_params.registration_id = registration_id
    end

    local res, err = utils.request(self.client, url, {
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
-- GET /v3/tags/{tag_value}/registration_ids/{registration_id}
function _M:check_device_in_tag(registration_id, tag_value)
    local url = self.base_url .. "/tags/" .. tag_value .. "/registration_ids/" .. registration_id

    local res, err = utils.request(self.client, url, {
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
-- POST /v3/tags/{tag_value}
function _M:update_tag_devices(tag_value, add_reg_ids, remove_reg_ids)
    local url = self.base_url .. "/tags/" .. tag_value

    local payload = {
        registration_ids = {
            add = add_reg_ids or {},
            remove = remove_reg_ids or {},
        },
    }

    local res, err = utils.request(self.client, url, {
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
-- DELETE /v3/tags/{tag_value}
function _M:delete_tag(tag_value, platforms)
    local url = self.base_url .. "/tags/" .. tag_value

    local query_params = {}
    if platforms then
        query_params.platform = platforms
    end

    local res, err = utils.request(self.client, url, {
        method = "DELETE",
        query = query_params,
        headers = {
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

-- 批量查询设备在线状态
-- POST /v3/devices/status/
function _M:get_devices_status(registration_ids)
    local url = self.base_url .. "/devices/status/"

    local payload = {
        registration_ids = registration_ids,
    }

    local res, err = utils.request(self.client, url, {
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

return _M
