-- report_spec.lua
-- Tests for resty.jpush.report

describe("jpush.report", function()
    local helper

    setup(function()
        helper = require("spec.spec_helper")
    end)

    describe("get_received()", function()
        it("gets received count for a single msg_id", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '[{"msg_id":"123","android_received":42}]')

            local result = client.report:get_received("123")
            assert.is_true(result.success)
        end)

        it("gets received count for multiple msg_ids", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '[{"msg_id":"123"},{"msg_id":"456"}]')

            local result = client.report:get_received({"123", "456"})
            assert.is_true(result.success)
            assert.equals(2, #result.data)
        end)
    end)

    describe("get_message_detail()", function()
        it("gets message detail", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{"msg_id":"123","status":"送达"}')

            local result = client.report:get_message_detail("123")
            assert.is_true(result.success)
            assert.equals("123", result.data.msg_id)
        end)

        it("gets message detail with registration_ids", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{"msg_id":"123"}')

            local result = client.report:get_message_detail("123", {"dev1", "dev2"})
            assert.is_true(result.success)
        end)
    end)

    describe("get_user_stat()", function()
        it("gets user statistics", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{"online":42}')

            local result = client.report:get_user_stat("dev1")
            assert.is_true(result.success)
        end)

        it("gets user statistics for multiple devices", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{"items":[{"id":"dev1"},{"id":"dev2"}]}')

            local result = client.report:get_user_stat({"dev1", "dev2"})
            assert.is_true(result.success)
        end)
    end)

    describe("error handling", function()
        it("handles 404 for invalid msg_id", function()
            local client = helper.create_client()
            helper.queue_response(client, 404,
                '{"error":{"code":2003,"message":"msg_id not found"}}'
            )

            local result = client.report:get_received("invalid_id")
            assert.is_false(result.success)
            assert.equals(2003, result.error.code)
            assert.equals(404, result.error.http_status)
        end)
    end)
end)
