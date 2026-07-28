-- device_spec.lua
-- Tests for resty.jpush.device

describe("jpush.device", function()
    local helper

    setup(function()
        helper = require("spec.spec_helper")
    end)

    local RID = "191e35f7e07c2b2315f"

    describe("get_tags()", function()
        it("retrieves tags for a device", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{"tags":["active","vip"],"alias":"user_1"}')

            local result = client.device:get_tags(RID)

            assert.is_true(result.success)
            assert.equals("user_1", result.data.alias)
            assert.same({"active", "vip"}, result.data.tags)
        end)
    end)

    describe("set_tags()", function()
        it("overwrites tags with a new list", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{}')

            local result = client.device:set_tags(RID, {"new_tag"})
            assert.is_true(result.success)
        end)

        it("clears all tags when called with empty table", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{}')

            local result = client.device:set_tags(RID, {})
            assert.is_true(result.success)
        end)
    end)

    describe("update_tags()", function()
        it("adds and removes tags", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{}')

            local result = client.device:update_tags(RID, {"new_tag"}, {"old_tag"})
            assert.is_true(result.success)
        end)
    end)

    describe("clear_tags()", function()
        it("clears all tags", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{}')

            local result = client.device:clear_tags(RID)
            assert.is_true(result.success)
        end)
    end)

    describe("get_alias()", function()
        it("gets device info including alias via devices endpoint", function()
            local client = helper.create_client()
            helper.queue_response(client, 200,
                '{"alias":"user_123","tags":["vip"],"mobile":"13800138000"}'
            )

            local result = client.device:get_alias(RID)

            assert.is_true(result.success)
            assert.equals("user_123", result.data.alias)
            assert.same({"vip"}, result.data.tags)
            assert.equals("13800138000", result.data.mobile)
        end)
    end)

    describe("set_alias()", function()
        it("sets alias for a device", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{}')

            local result = client.device:set_alias(RID, "user_123")
            assert.is_true(result.success)
        end)
    end)

    describe("delete_alias()", function()
        it("deletes an alias", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{}')

            local result = client.device:delete_alias("user_123")
            assert.is_true(result.success)
        end)

        it("deletes alias with platform filter", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{}')

            local result = client.device:delete_alias("user_123", "android,ios")
            assert.is_true(result.success)
        end)
    end)

    describe("get_devices_by_tag()", function()
        it("gets devices under a tag", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{"device_ids":["dev1","dev2"]}')

            local result = client.device:get_devices_by_tag("vip")
            assert.is_true(result.success)
            assert.same({"dev1", "dev2"}, result.data.device_ids)
        end)
    end)

    describe("check_device_in_tag()", function()
        it("returns exists=true when device is in tag", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{"result":true}')

            local result = client.device:check_device_in_tag(RID, "vip")
            assert.is_true(result.success)
            assert.is_true(result.data.exists)
        end)

        it("returns exists=false when device is not in tag", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{"result":false}')

            local result = client.device:check_device_in_tag(RID, "vip")
            assert.is_true(result.success)
            assert.is_false(result.data.exists)
        end)
    end)

    describe("update_tag_devices()", function()
        it("adds and removes devices from tag", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{}')

            local result = client.device:update_tag_devices("vip", {"dev1"}, {"dev2"})
            assert.is_true(result.success)
        end)
    end)

    describe("delete_tag()", function()
        it("deletes a tag", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{}')

            local result = client.device:delete_tag("old_tag")
            assert.is_true(result.success)
        end)
    end)

    describe("error handling", function()
        it("handles network error", function()
            local client = helper.create_client()
            helper.queue_error(client, "connection refused")

            local result = client.device:get_tags(RID)

            assert.is_false(result.success)
            assert.equals(1001, result.error.code)
        end)

        it("handles API error", function()
            local client = helper.create_client()
            helper.queue_response(client, 400,
                '{"error":{"code":2003,"message":"invalid registration_id"}}'
            )

            local result = client.device:get_tags("invalid_rid")

            assert.is_false(result.success)
            assert.equals(2003, result.error.code)
            assert.equals(400, result.error.http_status)
        end)
    end)
end)
