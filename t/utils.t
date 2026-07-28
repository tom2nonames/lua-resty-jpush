use Test::Nginx::Socket::Lua;

repeat_each(1);
plan tests => repeat_each() * (blocks() * 3);
no_long_string();

run_tests();

__DATA__

=== TEST 1: generate_auth_header Basic Auth
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
--- config
    location /t {
        content_by_lua_block {
            local utils = require("resty.jpush.utils")
            ngx.say(utils.generate_auth_header("app123", "secret456"))
        }
    }
--- request
GET /t
--- response_body
Basic YXBwMTIzOnNlY3JldDQ1Ng==
--- no_error_log
[error]

=== TEST 2: build_error_response
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
--- config
    location /t {
        content_by_lua_block {
            local cjson = require("cjson")
            local utils = require("resty.jpush.utils")
            ngx.say(cjson.encode(utils.build_error_response(1001, "network error", 500)))
        }
    }
--- request
GET /t
--- response_body_like
^.*(?=.*"success":false)(?=.*"code":1001)(?=.*"http_status":500).*$
--- no_error_log
[error]

=== TEST 3: build_error_response default 500
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
--- config
    location /t {
        content_by_lua_block {
            local cjson = require("cjson")
            local utils = require("resty.jpush.utils")
            ngx.say(cjson.encode(utils.build_error_response(1003, "param error")))
        }
    }
--- request
GET /t
--- response_body_like
^.*(?=.*"success":false)(?=.*"code":1003).*$
--- no_error_log
[error]

=== TEST 4: build_success_response
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
--- config
    location /t {
        content_by_lua_block {
            local cjson = require("cjson")
            local utils = require("resty.jpush.utils")
            ngx.say(cjson.encode(utils.build_success_response({ msg_id = "123" })))
        }
    }
--- request
GET /t
--- response_body_like
^.*(?=.*"success":true)(?=.*"msg_id":"123").*$
--- no_error_log
[error]

=== TEST 5: parse_response 200 OK
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
--- config
    location /t {
        content_by_lua_block {
            local cjson = require("cjson")
            local utils = require("resty.jpush.utils")
            local result = utils.parse_response({ status = 200, body = '{"msg_id":"abc"}' }, nil)
            ngx.say(cjson.encode(result))
        }
    }
--- request
GET /t
--- response_body_like
^.*(?=.*"success":true)(?=.*"msg_id":"abc").*$
--- no_error_log
[error]

=== TEST 6: parse_response network error
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
--- config
    location /t {
        content_by_lua_block {
            local cjson = require("cjson")
            local utils = require("resty.jpush.utils")
            local result = utils.parse_response(nil, "connection refused")
            ngx.say(cjson.encode(result))
        }
    }
--- request
GET /t
--- response_body_like
^.*(?=.*"success":false)(?=.*"code":1001).*$
--- no_error_log
[error]

=== TEST 7: parse_response invalid JSON
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
--- config
    location /t {
        content_by_lua_block {
            local cjson = require("cjson")
            local utils = require("resty.jpush.utils")
            local result = utils.parse_response({ status = 200, body = "not-json" }, nil)
            ngx.say(cjson.encode(result))
        }
    }
--- request
GET /t
--- response_body_like
^.*(?=.*"success":false)(?=.*"code":1005).*$
--- no_error_log
[error]

=== TEST 8: parse_response API error
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
--- config
    location /t {
        content_by_lua_block {
            local cjson = require("cjson")
            local utils = require("resty.jpush.utils")
            local res = { status = 400, body = '{"error":{"code":2003,"message":"Bad request"}}' }
            local result = utils.parse_response(res, nil)
            ngx.say(cjson.encode(result))
        }
    }
--- request
GET /t
--- response_body_like
^.*(?=.*"success":false)(?=.*"code":2003).*$
--- no_error_log
[error]

=== TEST 9: ERROR_CODES
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
--- config
    location /t {
        content_by_lua_block {
            local utils = require("resty.jpush.utils")
            ngx.say(utils.ERROR_CODES.SUCCESS, ",", utils.ERROR_CODES.NETWORK_ERROR)
        }
    }
--- request
GET /t
--- response_body
0,1001
--- no_error_log
[error]
