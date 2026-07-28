-- image.lua - 图片管理 API 模块
-- 覆盖 JPush Image API V3
local cjson = require("cjson.safe")
local utils = require("resty.jpush.utils")

local _M = {}

function _M.new(client)
    local self = {
        client = client,
        base_url = client.base_urls.push .. "/v3/images",
    }
    return setmetatable(self, { __index = _M })
end

-- 通过 URL 上传图片
-- POST /v3/images/byurls
-- urls: 图片 URL 列表，单次最多 5 个
function _M:upload_by_urls(urls)
    local url = self.base_url .. "/byurls"

    local payload = {
        urls = urls,
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

-- 通过 URL 更新图片
-- PUT /v3/images/byurls/{media_id}
function _M:update_by_url(media_id, image_url)
    local url = self.base_url .. "/byurls/" .. media_id

    local payload = {
        url = image_url,
    }

    local res, err = utils.request(self.client, url, {
        method = "PUT",
        body = cjson.encode(payload),
        headers = {
            ["Content-Type"] = "application/json",
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

-- 通过文件上传图片
-- POST /v3/images/byfiles
function _M:upload_by_file(file_path)
    local url = self.base_url .. "/byfiles"

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

    local boundary = "----JPushBoundary" .. tostring(math.random(100000, 999999))
    local header_part = '------JPushBoundary' .. boundary:match("JPushBoundary(.+)$") .. '\r\n'
        .. 'Content-Disposition: form-data; name="image"; filename="image.png"\r\n'
        .. 'Content-Type: image/png\r\n\r\n'
    local footer_part = '\r\n------JPushBoundary' .. boundary:match("JPushBoundary(.+)$") .. '--\r\n'

    local body = header_part .. content .. footer_part

    local res, err = utils.request(self.client, url, {
        method = "POST",
        body = body,
        headers = {
            ["Content-Type"] = "multipart/form-data; boundary=" .. boundary,
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

-- 通过文件更新图片
-- PUT /v3/images/byfiles/{media_id}
function _M:update_by_file(media_id, file_path)
    local url = self.base_url .. "/byfiles/" .. media_id

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

    local boundary = "----JPushBoundary" .. tostring(math.random(100000, 999999))
    local header_part = '------JPushBoundary' .. boundary:match("JPushBoundary(.+)$") .. '\r\n'
        .. 'Content-Disposition: form-data; name="image"; filename="image.png"\r\n'
        .. 'Content-Type: image/png\r\n\r\n'
    local footer_part = '\r\n------JPushBoundary' .. boundary:match("JPushBoundary(.+)$") .. '--\r\n'

    local body = header_part .. content .. footer_part

    local res, err = utils.request(self.client, url, {
        method = "PUT",
        body = body,
        headers = {
            ["Content-Type"] = "multipart/form-data; boundary=" .. boundary,
            ["Authorization"] = self.client.auth_header,
        },
        ssl_verify = self.client.ssl_verify,
    })

    return utils.parse_response(res, err)
end

return _M
