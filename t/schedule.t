use Test::Nginx::Socket::Lua;

repeat_each(1);
plan tests => repeat_each() * (blocks() * 3);
no_long_string();

run_tests();

__DATA__

=== TEST 1: create_single schedule
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
    server {
        listen 19996;
        location /v3/schedules {
            content_by_lua_block {
                ngx.req.read_body()
                ngx.say('{"schedule_id":"sched_123","name":"test_push"}')
            }
        }
    }
--- config
    location /t {
        content_by_lua_block {
            local cjson = require("cjson")
            local jpush = require("resty.jpush")
            local client = jpush.new({
                app_key = "k", master_secret = "s",
                base_urls = { schedule = "http://127.0.0.1:19996" },
                ssl_verify = false, timeout = 5000,
            })
            local payload = { platform = "all", audience = "all", notification = { alert = "test" } }
            local result = client.schedule:create_single("test", payload, "2026-12-31 23:59:59")
            ngx.say(cjson.encode(result))
        }
    }
--- request
GET /t
--- response_body_like
^.*(?=.*"success":true)(?=.*"schedule_id":"sched_123").*$
--- no_error_log
[error]

=== TEST 2: create_periodical schedule
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
    server {
        listen 19996;
        location /v3/schedules {
            content_by_lua_block {
                ngx.req.read_body()
                ngx.say('{"schedule_id":"sched_456","name":"daily"}')
            }
        }
    }
--- config
    location /t {
        content_by_lua_block {
            local cjson = require("cjson")
            local jpush = require("resty.jpush")
            local client = jpush.new({
                app_key = "k", master_secret = "s",
                base_urls = { schedule = "http://127.0.0.1:19996" },
                ssl_verify = false, timeout = 5000,
            })
            local payload = { platform = "all", audience = "all", notification = { alert = "test" } }
            local result = client.schedule:create_periodical("daily", payload, {
                start = "2026-01-01 09:00:00",
                ["end"] = "2026-12-31 09:00:00",
                time = "09:00:00",
                time_unit = "DAY",
                frequency = 1,
                point = {},
            })
            ngx.say(cjson.encode(result))
        }
    }
--- request
GET /t
--- response_body_like
^.*(?=.*"success":true)(?=.*"schedule_id":"sched_456").*$
--- no_error_log
[error]

=== TEST 3: get_list schedules
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
    server {
        listen 19996;
        location /v3/schedules {
            content_by_lua_block {
                ngx.say('{"schedules":[{"id":"s1"}],"total":1}')
            }
        }
    }
--- config
    location /t {
        content_by_lua_block {
            local cjson = require("cjson")
            local jpush = require("resty.jpush")
            local client = jpush.new({
                app_key = "k", master_secret = "s",
                base_urls = { schedule = "http://127.0.0.1:19996" },
                ssl_verify = false, timeout = 5000,
            })
            local result = client.schedule:get_list(1)
            ngx.say(cjson.encode(result))
        }
    }
--- request
GET /t
--- response_body_like
^.*(?=.*"success":true)(?=.*"total":1).*$
--- no_error_log
[error]

=== TEST 4: get schedule detail
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
    server {
        listen 19996;
        location /v3/schedules/ {
            content_by_lua_block {
                ngx.say('{"schedule_id":"sched_123","name":"test"}')
            }
        }
    }
--- config
    location /t {
        content_by_lua_block {
            local cjson = require("cjson")
            local jpush = require("resty.jpush")
            local client = jpush.new({
                app_key = "k", master_secret = "s",
                base_urls = { schedule = "http://127.0.0.1:19996" },
                ssl_verify = false, timeout = 5000,
            })
            local result = client.schedule:get("sched_123")
            ngx.say(cjson.encode(result))
        }
    }
--- request
GET /t
--- response_body_like
^.*(?=.*"success":true)(?=.*"schedule_id":"sched_123").*$
--- no_error_log
[error]

=== TEST 5: update schedule
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
    server {
        listen 19996;
        location /v3/schedules/ {
            content_by_lua_block {
                ngx.req.read_body()
                ngx.say('{}')
            }
        }
    }
--- config
    location /t {
        content_by_lua_block {
            local cjson = require("cjson")
            local jpush = require("resty.jpush")
            local client = jpush.new({
                app_key = "k", master_secret = "s",
                base_urls = { schedule = "http://127.0.0.1:19996" },
                ssl_verify = false, timeout = 5000,
            })
            local result = client.schedule:update("sched_123", { name = "updated" })
            ngx.say(cjson.encode(result))
        }
    }
--- request
GET /t
--- response_body_like
.*"success":true.*
--- no_error_log
[error]

=== TEST 6: delete schedule
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
    server {
        listen 19996;
        location /v3/schedules/ {
            content_by_lua_block {
                ngx.say('{}')
            }
        }
    }
--- config
    location /t {
        content_by_lua_block {
            local cjson = require("cjson")
            local jpush = require("resty.jpush")
            local client = jpush.new({
                app_key = "k", master_secret = "s",
                base_urls = { schedule = "http://127.0.0.1:19996" },
                ssl_verify = false, timeout = 5000,
            })
            local result = client.schedule:delete("sched_123")
            ngx.say(cjson.encode(result))
        }
    }
--- request
GET /t
--- response_body_like
.*"success":true.*
--- no_error_log
[error]
