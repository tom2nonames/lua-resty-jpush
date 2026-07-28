-- push_spec.lua
-- Tests for resty.jpush.push

describe("jpush.push", function()
    local helper

    setup(function()
        helper = require("spec.spec_helper")
        helper.clear_log()
    end)

    after_each(function()
        helper.clear_log()
    end)

    it("send() returns success when API responds 200", function()
        local client = helper.create_client()
        helper.queue_response(client, 200, '{"msg_id":"abc123","sendno":"sendno123"}')

        local result = client.push:send({
            platform = "all",
            audience = "all",
            notification = { alert = "Hello" },
        })

        assert.is_true(result.success)
        assert.equals("abc123", result.data.msg_id)
    end)

    it("send() validates required fields", function()
        local client = helper.create_client()

        -- missing platform
        local result = client.push:send({
            audience = "all",
            notification = { alert = "Hello" },
        })
        assert.is_false(result.success)
        assert.equals(1003, result.error.code)
        assert.match("platform", result.error.message)

        -- missing audience
        result = client.push:send({
            platform = "all",
            notification = { alert = "Hello" },
        })
        assert.is_false(result.success)
        assert.equals(1003, result.error.code)
        assert.match("audience", result.error.message)

        -- missing both notification and message
        result = client.push:send({
            platform = "all",
            audience = "all",
        })
        assert.is_false(result.success)
        assert.equals(1003, result.error.code)
        assert.match("notification or message", result.error.message)
    end)

    it("send() handles API error responses", function()
        local client = helper.create_client()
        helper.queue_response(client, 429, '{"error":{"code":2002,"message":"Rate limit exceeded"}}')

        local result = client.push:send({
            platform = "all",
            audience = "all",
            notification = { alert = "Hello" },
        })

        assert.is_false(result.success)
        assert.equals(2002, result.error.code)
        assert.equals(429, result.error.http_status)
    end)

    it("send() handles network errors", function()
        local client = helper.create_client()
        helper.queue_error(client, "timeout")

        local result = client.push:send({
            platform = "all",
            audience = "all",
            notification = { alert = "Hello" },
        })

        assert.is_false(result.success)
        assert.equals(1001, result.error.code)
        assert.match("timeout", result.error.message)
    end)

    describe("send_to_all()", function()
        it("sends notification to all devices", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{"msg_id":"abc123"}')

            local result = client.push:send_to_all("Hello everyone")
            assert.is_true(result.success)
        end)
    end)

    describe("send_to_alias()", function()
        it("sends to single alias", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{"msg_id":"abc123"}')

            local result = client.push:send_to_alias("user_1", "Hello")
            assert.is_true(result.success)
        end)

        it("sends to multiple aliases", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{"msg_id":"abc123"}')

            local result = client.push:send_to_alias({"user_1", "user_2"}, "Hello")
            assert.is_true(result.success)
        end)
    end)

    describe("send_to_tag()", function()
        it("sends to single tag", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{"msg_id":"abc123"}')

            local result = client.push:send_to_tag("vip", "VIP offer")
            assert.is_true(result.success)
        end)

        it("sends to multiple tags", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{"msg_id":"abc123"}')

            local result = client.push:send_to_tag({"vip", "active"}, "Hello")
            assert.is_true(result.success)
        end)
    end)

    describe("send_to_registration_id()", function()
        it("sends to single registration_id", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{"msg_id":"abc123"}')

            local result = client.push:send_to_registration_id("191e35f7e07c", "Hello")
            assert.is_true(result.success)
        end)

        it("sends to multiple registration_ids", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{"msg_id":"abc123"}')

            local result = client.push:send_to_registration_id(
                {"191e35f7e07c", "191e35f7e07d"}, "Hello"
            )
            assert.is_true(result.success)
        end)
    end)

    describe("send_message()", function()
        it("sends custom message without notification", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{"msg_id":"abc123"}')

            local result = client.push:send_message("all", "custom content", {
                title = "msg title",
                content_type = "text",
                extras = { key = "value" },
            })

            assert.is_true(result.success)
        end)
    end)

    describe("validate()", function()
        it("returns valid for correct payload", function()
            local client = helper.create_client()
            local result = client.push:validate({
                platform = "all",
                audience = "all",
                notification = { alert = "Hello" },
            })
            assert.is_true(result.valid)
        end)

        it("returns invalid for missing fields", function()
            local client = helper.create_client()
            local result = client.push:validate({})
            assert.is_false(result.valid)
            assert.match("platform", result.error)
        end)
    end)

    describe("debug logging", function()
        it("logs request and response when debug is enabled", function()
            local client = helper.create_client({ debug = true })
            helper.queue_response(client, 200, '{"msg_id":"abc123"}')

            client.push:send_to_all("Hello")

            local log = helper.get_log()
            assert.is_true(#log > 0)
        end)
    end)
end)
