-- schedule_spec.lua
-- Tests for resty.jpush.schedule

describe("jpush.schedule", function()
    local helper

    setup(function()
        helper = require("spec.spec_helper")
    end)

    local PUSH_PAYLOAD = {
        platform = "all",
        audience = "all",
        notification = { alert = "Scheduled push" },
    }

    describe("create_single()", function()
        it("creates a one-time scheduled task", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{"schedule_id":"sched_123","name":"test"}')

            local result = client.schedule:create_single(
                "NewYearPush", PUSH_PAYLOAD, "2026-12-31 23:59:59"
            )

            assert.is_true(result.success)
            assert.equals("sched_123", result.data.schedule_id)
        end)
    end)

    describe("create_periodical()", function()
        it("creates a periodic scheduled task", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{"schedule_id":"sched_456","name":"daily"}')

            local result = client.schedule:create_periodical(
                "DailyNews", PUSH_PAYLOAD, {
                    start = "2026-01-01 09:00:00",
                    ["end"] = "2026-12-31 09:00:00",
                    time = "09:00:00",
                    time_unit = "DAY",
                    frequency = 1,
                    point = {},
                }
            )

            assert.is_true(result.success)
            assert.equals("sched_456", result.data.schedule_id)
        end)
    end)

    describe("get_list()", function()
        it("gets schedule list without page param", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{"schedules":[],"total":0}')

            local result = client.schedule:get_list()
            assert.is_true(result.success)
            assert.equals(0, result.data.total)
        end)

        it("gets schedule list with page param", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{"schedules":[{"id":"s1"}],"total":1}')

            local result = client.schedule:get_list(1)
            assert.is_true(result.success)
            assert.equals(1, result.data.total)
        end)
    end)

    describe("get()", function()
        it("gets schedule detail by id", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{"schedule_id":"sched_123","name":"test"}')

            local result = client.schedule:get("sched_123")
            assert.is_true(result.success)
            assert.equals("sched_123", result.data.schedule_id)
        end)
    end)

    describe("update()", function()
        it("updates an existing schedule", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{}')

            local result = client.schedule:update("sched_123", {
                name = "Updated Name",
                enabled = false,
            })

            assert.is_true(result.success)
        end)
    end)

    describe("delete()", function()
        it("deletes a schedule", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{}')

            local result = client.schedule:delete("sched_123")
            assert.is_true(result.success)
        end)
    end)

    describe("error handling", function()
        it("handles schedule not found", function()
            local client = helper.create_client()
            helper.queue_response(client, 404,
                '{"error":{"code":2003,"message":"schedule not found"}}'
            )

            local result = client.schedule:get("nonexistent")
            assert.is_false(result.success)
            assert.equals(2003, result.error.code)
            assert.equals(404, result.error.http_status)
        end)
    end)
end)
