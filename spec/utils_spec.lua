-- utils_spec.lua
-- Tests for resty.jpush.utils

describe("jpush.utils", function()
    local utils
    local helper

    setup(function()
        utils = require("resty.jpush.utils")
        helper = require("spec.spec_helper")
    end)

    describe("ERROR_CODES", function()
        it("defines standard error codes", function()
            assert.equals(0, utils.ERROR_CODES.SUCCESS)
            assert.equals(1001, utils.ERROR_CODES.NETWORK_ERROR)
            assert.equals(1002, utils.ERROR_CODES.AUTH_ERROR)
            assert.equals(1003, utils.ERROR_CODES.PARAM_ERROR)
            assert.equals(1004, utils.ERROR_CODES.RATE_LIMIT)
            assert.equals(1005, utils.ERROR_CODES.SERVER_ERROR)
            assert.equals(1999, utils.ERROR_CODES.UNKNOWN_ERROR)
        end)
    end)

    describe("generate_auth_header()", function()
        it("generates correct Basic Auth header", function()
            local header = utils.generate_auth_header("app123", "secret456")
            assert.is_true(header:find("^Basic ") ~= nil)
            assert.equals("Basic YXBwMTIzOnNlY3JldDQ1Ng==", header)
        end)

        it("handles keys with special characters", function()
            local header = utils.generate_auth_header("key/with:chars", "secret==")
            assert.is_true(header:find("^Basic ") ~= nil)
        end)
    end)

    describe("build_error_response()", function()
        it("builds error response with code and message", function()
            local resp = utils.build_error_response(1001, "network error", 500)
            assert.is_false(resp.success)
            assert.equals(1001, resp.error.code)
            assert.equals("network error", resp.error.message)
            assert.equals(500, resp.error.http_status)
        end)

        it("defaults http_status to 500", function()
            local resp = utils.build_error_response(1003, "param error")
            assert.equals(500, resp.error.http_status)
        end)
    end)

    describe("build_success_response()", function()
        it("builds success response with data", function()
            local resp = utils.build_success_response({ msg_id = "123" })
            assert.is_true(resp.success)
            assert.equals("123", resp.data.msg_id)
        end)

        it("handles nil data", function()
            local resp = utils.build_success_response(nil)
            assert.is_true(resp.success)
            assert.is_nil(resp.data)
        end)
    end)

    describe("parse_response()", function()
        it("returns success for 200 OK with JSON body", function()
            local res = { status = 200, body = '{"msg_id":"abc123"}' }
            local result = utils.parse_response(res, nil)
            assert.is_true(result.success)
            assert.equals("abc123", result.data.msg_id)
        end)

        it("returns error when HTTP request failed", function()
            local result = utils.parse_response(nil, "connection refused")
            assert.is_false(result.success)
            assert.equals(1001, result.error.code)
            assert.match("connection refused", result.error.message)
        end)

        it("returns error when response body is not valid JSON", function()
            local res = { status = 200, body = "not-json" }
            local result = utils.parse_response(res, nil)
            assert.is_false(result.success)
            assert.equals(1005, result.error.code)
            assert.match("Failed to parse", result.error.message)
        end)

        it("returns error for non-200 status with JPush error body", function()
            local res = { status = 400, body = '{"error":{"code":2003,"message":"Bad request"}}' }
            local result = utils.parse_response(res, nil)
            assert.is_false(result.success)
            assert.equals(2003, result.error.code)
            assert.equals("Bad request", result.error.message)
            assert.equals(400, result.error.http_status)
        end)

        it("handles non-200 status with missing error field", function()
            local res = { status = 429, body = '{"msg":"too many requests"}' }
            local result = utils.parse_response(res, nil)
            assert.is_false(result.success)
            assert.equals(429, result.error.code)
            assert.equals("Unknown error", result.error.message)
        end)
    end)

    describe("extract_rate_limit_info()", function()
        it("extracts rate limit headers", function()
            local info = utils.extract_rate_limit_info({
                ["X-Rate-Limit-Limit"] = "100",
                ["X-Rate-Limit-Remaining"] = "42",
                ["X-Rate-Limit-Reset"] = "1628000000",
            })
            assert.equals(100, info.limit)
            assert.equals(42, info.remaining)
            assert.equals(1628000000, info.reset)
        end)

        it("handles missing headers gracefully", function()
            local info = utils.extract_rate_limit_info({})
            assert.is_nil(info.limit)
            assert.is_nil(info.remaining)
            assert.is_nil(info.reset)
        end)
    end)

    describe("request()", function()
        it("sends request via httpc and returns response", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{"ok":true}', {
                ["X-Rate-Limit-Remaining"] = "99",
            })

            local res, err = utils.request(client, "https://example.com/test", {
                method = "GET",
                headers = { Authorization = client.auth_header },
                ssl_verify = false,
            })

            assert.is_nil(err)
            assert.equals(200, res.status)
            assert.equals('{"ok":true}', res.body)
        end)

        it("records rate limit info on client", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{"ok":true}', {
                ["X-Rate-Limit-Remaining"] = "88",
                ["X-Rate-Limit-Limit"] = "100",
            })

            utils.request(client, "https://example.com/test", {
                method = "GET", headers = {}, ssl_verify = false,
            })

            assert.equals(88, client.last_rate_limit.remaining)
            assert.equals(100, client.last_rate_limit.limit)
        end)

        it("returns connection to pool via set_keepalive", function()
            local client = helper.create_client()
            helper.queue_response(client, 200, '{}')

            utils.request(client, "https://example.com/test", {
                method = "GET", headers = {}, ssl_verify = false,
            })

            assert.equals(60000, client.httpc._keepalive_timeout)
            assert.equals(100, client.httpc._keepalive_pool_size)
        end)
    end)
end)
