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