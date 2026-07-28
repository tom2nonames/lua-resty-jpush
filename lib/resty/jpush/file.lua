-- file.lua - 文件管理 API 模块
local cjson = require("cjson.safe")
local utils = require("resty.jpush.utils")

local _M = {}

function _M.new(client)
    local self = {
        client = client,
        base_url = client.base_urls.push .. "/v3/files",
    }
    return setmetatable(self, { __index = _M })
end

-- 上传 registration_id CSV 文件
-- POST /v3/files/registration_id
-- CSV 文件格式：单列，每行一个 registration_id
function _M:upload_registration_ids(file_path)
    local url = self.base_url .. "/registration_id"

    local file, open_err = io.open(file_path, "r")
    if not file then
        return utils.build_error_response(
            utils.ERROR_CODES.PARAM_ERROR,
            "Failed to open file: " .. (open_err or "unknown error"),
            400
        )
    end
    local content = file:read("*all")
    file:close()

    local boundary = "----JPushFormBoundary" .. tostring(ngx.now()):gsub("%.", "")
    local b = boundary

    local body = "--" .. b .. "\r\n"
        .. 'Content-Disposition: form-data; name="registration_ids"; filename="rids.csv"\r\n'
        .. "Content-Type: application/octet-stream\r\n\r\n"
        .. content .. "\r\n--" .. b .. "--\r\n"

    local res, err = utils.request(self.client, url, {
        method = "POST",
        body = body,
        headers = {
            ["Content-Type"] = "multipart/form-data; boundary=" .. b,
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

-- 获取文件信息
-- GET /v3/files/{file_id}
function _M:get(file_id)
    local res, err = utils.request(self.client, self.base_url .. "/" .. file_id, {
        method = "GET",
        headers = {
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })
    return utils.parse_response(res, err)
end

-- 按类型列出文件
-- GET /v3/files/{file_type}
function _M:list(file_type)
    local res, err = utils.request(self.client, self.base_url .. "/" .. file_type, {
        method = "GET",
        headers = {
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })
    return utils.parse_response(res, err)
end

-- 删除文件
-- DELETE /v3/files/{file_id}
function _M:delete(file_id)
    local res, err = utils.request(self.client, self.base_url .. "/" .. file_id, {
        method = "DELETE",
        headers = {
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })
    return utils.parse_response(res, err)
end

return _M
