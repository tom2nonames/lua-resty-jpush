use Test::Nginx::Socket::Lua;

repeat_each(1);
plan tests => repeat_each() * (blocks() * 3);
no_long_string();
run_tests();

__DATA__

=== TEST 1: send push
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
    server {
        listen 19999;
        location /v3/push {
            content_by_lua_block {
                ngx.req.read_body()
                ngx.say('{"msg_id":"test_msg"}')
            }
        }
    }
--- config
    location /t {
        content_by_lua_block {
            local cjson = require("cjson")
            local jpush = require("resty.jpush")
            local client = jpush.new({ app_key = "k", master_secret = "s", base_urls = { push = "http://127.0.0.1:19999" }, ssl_verify = false, timeout = 5000 })
            ngx.say(cjson.encode(client.push:send({ platform = "all", audience = "all", notification = { alert = "Hello" } })))
        }
    }
--- request
GET /t
--- response_body_like
^.*(?=.*"success":true)(?=.*"msg_id":"test_msg").*$
--- no_error_log
[error]

=== TEST 2: get_cid
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
    server {
        listen 19998;
        location /v3/push/cid {
            content_by_lua_block {
                ngx.say('{"cidlist":["cid_123"]}')
            }
        }
    }
--- config
    location /t {
        content_by_lua_block {
            local cjson = require("cjson")
            local jpush = require("resty.jpush")
            local client = jpush.new({ app_key = "k", master_secret = "s", base_urls = { push = "http://127.0.0.1:19998" }, ssl_verify = false, timeout = 5000 })
            ngx.say(cjson.encode(client.push:get_cid(1)))
        }
    }
--- request
GET /t
--- response_body_like
^.*(?=.*"success":true)(?=.*"cidlist").*$
--- no_error_log
[error]
