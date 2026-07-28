use Test::Nginx::Socket::Lua;

repeat_each(1);
plan tests => repeat_each() * (blocks() * 3);
no_long_string();
run_tests();

__DATA__

=== TEST 1: upload_by_urls
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
    server {
        listen 19995;
        location /v3/images/byurls {
            content_by_lua_block {
                ngx.req.read_body()
                ngx.say('{"media_id":"m123"}')
            }
        }
    }
--- config
    location /t {
        content_by_lua_block {
            local cjson = require("cjson")
            local jpush = require("resty.jpush")
            local client = jpush.new({ app_key = "k", master_secret = "s", base_urls = { push = "http://127.0.0.1:19995" }, ssl_verify = false, timeout = 5000 })
            ngx.say(cjson.encode(client.image:upload_by_urls({"https://example.com/img.png"})))
        }
    }
--- request
GET /t
--- response_body_like
^.*(?=.*"success":true)(?=.*"media_id":"m123").*$
--- no_error_log
[error]

=== TEST 2: update_by_url
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
    server {
        listen 19996;
        location /v3/images/byurls/ {
            content_by_lua_block {
                ngx.req.read_body()
                ngx.say('{"media_id":"m123"}')
            }
        }
    }
--- config
    location /t {
        content_by_lua_block {
            local cjson = require("cjson")
            local jpush = require("resty.jpush")
            local client = jpush.new({ app_key = "k", master_secret = "s", base_urls = { push = "http://127.0.0.1:19996" }, ssl_verify = false, timeout = 5000 })
            ngx.say(cjson.encode(client.image:update_by_url("m123", "https://example.com/new.png")))
        }
    }
--- request
GET /t
--- response_body_like
^.*(?=.*"success":true).*$
--- no_error_log
[error]
