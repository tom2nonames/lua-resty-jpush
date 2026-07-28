-- init_spec.lua
-- Tests for resty.jpush (main entry point)

describe("jpush", function()
    it("new() creates a client with required config", function()
        local jpush = require("resty.jpush")
        local client = jpush.new({
            app_key = "test_key",
            master_secret = "test_secret",
        })

        assert.not_nil(client)
        assert.equals("test_key", client.app_key)
        assert.equals("test_secret", client.master_secret)
        assert.not_nil(client.auth_header)
    end)

    it("new() throws error without app_key", function()
        local jpush = require("resty.jpush")
        assert.has_error(function()
            jpush.new({ master_secret = "secret" })
        end, "app_key and master_secret are required")
    end)

    it("new() throws error without master_secret", function()
        local jpush = require("resty.jpush")
        assert.has_error(function()
            jpush.new({ app_key = "key" })
        end, "app_key and master_secret are required")
    end)

    it("new() mounts all sub-modules", function()
        local jpush = require("resty.jpush")
        local client = jpush.new({
            app_key = "test_key",
            master_secret = "test_secret",
        })

        assert.not_nil(client.push)
        assert.not_nil(client.device)
        assert.not_nil(client.report)
        assert.not_nil(client.schedule)
    end)

    it("new() respects custom timeout", function()
        local jpush = require("resty.jpush")
        local client = jpush.new({
            app_key = "test_key",
            master_secret = "test_secret",
            timeout = 30000,
        })

        assert.equals(30000, client.timeout)
        assert.equals(30000, client.httpc._timeout)
    end)

    it("new() defaults to SSL verify enabled", function()
        local jpush = require("resty.jpush")
        local client = jpush.new({
            app_key = "test_key",
            master_secret = "test_secret",
        })

        assert.is_true(client.ssl_verify)
    end)

    it("new() allows disabling SSL verify", function()
        local jpush = require("resty.jpush")
        local client = jpush.new({
            app_key = "test_key",
            master_secret = "test_secret",
            ssl_verify = false,
        })

        assert.is_false(client.ssl_verify)
    end)

    it("new() allows custom base URLs", function()
        local jpush = require("resty.jpush")
        local client = jpush.new({
            app_key = "test_key",
            master_secret = "test_secret",
            base_urls = {
                push = "https://bjapi.push.jiguang.cn",
            },
        })

        assert.equals("https://bjapi.push.jiguang.cn", client.base_urls.push)
        -- default URLs for other services should still be present
        assert.not_nil(client.base_urls.report)
        assert.not_nil(client.base_urls.device)
    end)

    it("update_auth() updates credentials at runtime", function()
        local jpush = require("resty.jpush")
        local client = jpush.new({
            app_key = "old_key",
            master_secret = "old_secret",
        })

        local old_auth = client.auth_header
        client:update_auth("new_key", "new_secret")

        assert.equals("new_key", client.app_key)
        assert.equals("new_secret", client.master_secret)
        assert.not_equals(old_auth, client.auth_header)
    end)

    it("get_rate_limit() returns empty table when no requests made", function()
        local jpush = require("resty.jpush")
        local client = jpush.new({
            app_key = "test_key",
            master_secret = "test_secret",
        })

        assert.same({}, client:get_rate_limit())
    end)

    it("has DEFAULT_BASE_URLS defined", function()
        local jpush = require("resty.jpush")
        assert.equals("https://api.jpush.cn", jpush.DEFAULT_BASE_URLS.push)
        assert.equals("https://report.jpush.cn", jpush.DEFAULT_BASE_URLS.report)
        assert.equals("https://device.jpush.cn", jpush.DEFAULT_BASE_URLS.device)
        assert.equals("https://api.jpush.cn", jpush.DEFAULT_BASE_URLS.schedule)
    end)
end)
