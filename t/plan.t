use Test::Nginx::Socket::Lua;

repeat_each(1);
plan tests => repeat_each() * (blocks() * 3);
no_long_string();
run_tests();

__DATA__

=== TEST 1: push_plan create
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
    server {
        listen 19993;
        location /v3/push_plan/create {
            content_by_lua_block { ngx.req.read_body(); ngx.say('{"plan_id":"p123"}') }
        }
    }
--- config
    location /t {
        content_by_lua_block {
            local cjson = require("cjson")
            local jpush = require("resty.jpush")
            local client = jpush.new({ app_key = "k", master_secret = "s", base_urls = { push = "http://127.0.0.1:19993" }, ssl_verify = false, timeout = 5000 })
            local result = client.plan:create({ name = "test", push = { platform = "all", audience = "all", notification = { alert = "test" } } })
            ngx.say(cjson.encode(result))
        }
    }
--- request
GET /t
--- response_body_like
^.*(?=.*"success":true)(?=.*"plan_id":"p123").*$
--- no_error_log
[error]

=== TEST 2: push_plan list
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
    server {
        listen 19993;
        location /v3/push_plan/list {
            content_by_lua_block { ngx.req.read_body(); ngx.say('{"plans":[{"id":"p1"}],"total":1}') }
        }
    }
--- config
    location /t {
        content_by_lua_block {
            local cjson = require("cjson")
            local jpush = require("resty.jpush")
            local client = jpush.new({ app_key = "k", master_secret = "s", base_urls = { push = "http://127.0.0.1:19993" }, ssl_verify = false, timeout = 5000 })
            ngx.say(cjson.encode(client.plan:list({ page = 1, page_size = 10 })))
        }
    }
--- request
GET /t
--- response_body_like
^.*(?=.*"success":true).*$
--- no_error_log
[error]

=== TEST 3: push_plan update
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
    server {
        listen 19993;
        location /v3/push_plan/update {
            content_by_lua_block { ngx.req.read_body(); ngx.say('{"plan_id":"p123"}') }
        }
    }
--- config
    location /t {
        content_by_lua_block {
            local cjson = require("cjson")
            local jpush = require("resty.jpush")
            local client = jpush.new({ app_key = "k", master_secret = "s", base_urls = { push = "http://127.0.0.1:19993" }, ssl_verify = false, timeout = 5000 })
            ngx.say(cjson.encode(client.plan:update({ plan_id = "p123", name = "updated" })))
        }
    }
--- request
GET /t
--- response_body_like
^.*(?=.*"success":true).*$
--- no_error_log
[error]
