use Test::Nginx::Socket::Lua;

repeat_each(1);
plan tests => repeat_each() * (blocks() * 3);
no_long_string();
run_tests();

__DATA__

=== TEST 1: get_tags
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
    server {
        listen 19998;
        location /v3/devices/ {
            content_by_lua_block {
                ngx.say('{"tags":["active","vip"],"alias":"user_1"}')
            }
        }
    }
--- config
    location /t {
        content_by_lua_block {
            local cjson = require("cjson")
            local jpush = require("resty.jpush")
            local client = jpush.new({ app_key = "k", master_secret = "s", base_urls = { device = "http://127.0.0.1:19998" }, ssl_verify = false, timeout = 5000 })
            ngx.say(cjson.encode(client.device:get_tags("test_rid")))
        }
    }
--- request
GET /t
--- response_body_like
^.*(?=.*"success":true)(?=.*"tags").*$
--- no_error_log
[error]

=== TEST 2: set_tags
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
    server {
        listen 19998;
        location /v3/devices/ {
            content_by_lua_block { ngx.say('{}') }
        }
    }
--- config
    location /t {
        content_by_lua_block {
            local cjson = require("cjson")
            local jpush = require("resty.jpush")
            local client = jpush.new({ app_key = "k", master_secret = "s", base_urls = { device = "http://127.0.0.1:19998" }, ssl_verify = false, timeout = 5000 })
            ngx.say(cjson.encode(client.device:set_tags("test_rid", {"new_tag"})))
        }
    }
--- request
GET /t
--- response_body_like
^.*(?=.*"success":true).*$
--- no_error_log
[error]

=== TEST 3: get_device_info
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
    server {
        listen 19998;
        location /v3/devices/ {
            content_by_lua_block { ngx.say('{"alias":"user_1","tags":["vip"]}') }
        }
    }
--- config
    location /t {
        content_by_lua_block {
            local cjson = require("cjson")
            local jpush = require("resty.jpush")
            local client = jpush.new({ app_key = "k", master_secret = "s", base_urls = { device = "http://127.0.0.1:19998" }, ssl_verify = false, timeout = 5000 })
            ngx.say(cjson.encode(client.device:get_device_info("test_rid")))
        }
    }
--- request
GET /t
--- response_body_like
^.*(?=.*"success":true)(?=.*"alias":"user_1").*$
--- no_error_log
[error]

=== TEST 4: get_aliases (by alias value)
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
    server {
        listen 19998;
        location /v3/aliases/ {
            content_by_lua_block { ngx.say('{"registration_ids":["rid1","rid2"]}') }
        }
    }
--- config
    location /t {
        content_by_lua_block {
            local cjson = require("cjson")
            local jpush = require("resty.jpush")
            local client = jpush.new({ app_key = "k", master_secret = "s", base_urls = { device = "http://127.0.0.1:19998" }, ssl_verify = false, timeout = 5000 })
            ngx.say(cjson.encode(client.device:get_aliases("user_1")))
        }
    }
--- request
GET /t
--- response_body_like
^.*(?=.*"success":true)(?=.*"registration_ids").*$
--- no_error_log
[error]

=== TEST 5: check_device_in_tag
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
    server {
        listen 19998;
        location ~ /v3/tags/vip/registration_ids/test_rid {
            content_by_lua_block { ngx.say('{"result":true}') }
        }
    }
--- config
    location /t {
        content_by_lua_block {
            local cjson = require("cjson")
            local jpush = require("resty.jpush")
            local client = jpush.new({ app_key = "k", master_secret = "s", base_urls = { device = "http://127.0.0.1:19998" }, ssl_verify = false, timeout = 5000 })
            ngx.say(cjson.encode(client.device:check_device_in_tag("test_rid", "vip")))
        }
    }
--- request
GET /t
--- response_body_like
^.*(?=.*"success":true)(?=.*"exists":true).*$
--- no_error_log
[error]

=== TEST 6: get_devices_status
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
    server {
        listen 19998;
        location /v3/devices/status/ {
            content_by_lua_block { ngx.req.read_body(); ngx.say('{"rid1":{"online":true}}') }
        }
    }
--- config
    location /t {
        content_by_lua_block {
            local cjson = require("cjson")
            local jpush = require("resty.jpush")
            local client = jpush.new({ app_key = "k", master_secret = "s", base_urls = { device = "http://127.0.0.1:19998" }, ssl_verify = false, timeout = 5000 })
            ngx.say(cjson.encode(client.device:get_devices_status({"rid1"})))
        }
    }
--- request
GET /t
--- response_body_like
^.*(?=.*"success":true).*$
--- no_error_log
[error]
