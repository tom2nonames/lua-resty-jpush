-- plan.lua - 推送计划管理 API 模块
local cjson = require("cjson.safe")
local utils = require("resty.jpush.utils")

local _M = {}

function _M.new(client)
    local self = {
        client = client,
        base_url = client.base_urls.push .. "/v3/push_plan",
    }
    return setmetatable(self, { __index = _M })
end

-- 创建推送计划
-- POST /v3/push_plan/create
function _M:create(plan_data)
    local res, err = utils.request(self.client, self.base_url .. "/create", {
        method = "POST",
        body = cjson.encode(plan_data),
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })
    return utils.parse_response(res, err)
end

-- 获取推送计划列表
-- POST /v3/push_plan/list
function _M:list(params)
    local res, err = utils.request(self.client, self.base_url .. "/list", {
        method = "POST",
        body = cjson.encode(params or {}),
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })
    return utils.parse_response(res, err)
end

-- 更新推送计划
-- POST /v3/push_plan/update
function _M:update(plan_data)
    local res, err = utils.request(self.client, self.base_url .. "/update", {
        method = "POST",
        body = cjson.encode(plan_data),
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })
    return utils.parse_response(res, err)
end

return _M
