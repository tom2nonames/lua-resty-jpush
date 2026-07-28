use Test::Nginx::Socket::Lua;

repeat_each(1);
plan tests => repeat_each() * (blocks() * 3);
no_long_string();
run_tests();

__DATA__

=== TEST 1: create client
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
--- config
    location /t {
        content_by_lua_block {
            local jpush = require("resty.jpush")
            local c = jpush.new({ app_key = "k", master_secret = "s" })
            ngx.say(c.app_key, ",", c.master_secret)
        }
    }
--- request
GET /t
--- response_body
k,s
--- no_error_log
[error]

=== TEST 2: mount all 7 sub-modules
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
--- config
    location /t {
        content_by_lua_block {
            local jpush = require("resty.jpush")
            local c = jpush.new({ app_key = "k", master_secret = "s" })
            local names = { "push", "device", "report", "schedule", "file", "image", "plan" }
            local ok = true
            for _, name in ipairs(names) do
                if c[name] == nil then ok = false end
            end
            ngx.say(ok and "all mounted" or "missing")
        }
    }
--- request
GET /t
--- response_body
all mounted
--- no_error_log
[error]

=== TEST 3: missing app_key raises error
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
--- config
    location /t {
        content_by_lua_block {
            local ok, _ = pcall(function()
                require("resty.jpush").new({ master_secret = "s" })
            end)
            ngx.say(ok and "no error" or "error caught")
        }
    }
--- request
GET /t
--- response_body
error caught
--- no_error_log
[error]

=== TEST 4: update_auth
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
--- config
    location /t {
        content_by_lua_block {
            local jpush = require("resty.jpush")
            local c = jpush.new({ app_key = "old", master_secret = "old" })
            local old = c.auth_header
            c:update_auth("new", "new")
            ngx.say((old ~= c.auth_header) and "changed" or "same")
        }
    }
--- request
GET /t
--- response_body
changed
--- no_error_log
[error]

=== TEST 5: base_urls merge with defaults
--- http_config
    lua_package_path "/Users/tom/dev/lua-resty-jpush/lib/?.lua;/Users/tom/dev/lua-resty-jpush/lib/?/init.lua;;";
--- config
    location /t {
        content_by_lua_block {
            local jpush = require("resty.jpush")
            local c = jpush.new({ app_key = "k", master_secret = "s", base_urls = { push = "http://custom" } })
            ngx.say(c.base_urls.push, "|", c.base_urls.report, "|", c.base_urls.device)
        }
    }
--- request
GET /t
--- response_body
http://custom|https://report.jpush.cn|https://device.jpush.cn
--- no_error_log
[error]
