
rockspec_format = "3.0"
package = "lua-resty-jpush"
version = "1.1.0-1"
source = {
     url = "git+https://github.com/tom2nonames/lua-resty-jpush.git"

}
description = {
   summary = "JPush (极光推送) REST API client for OpenResty",
   detailed = [[
     JPush (极光推送) REST API client for OpenResty/LuaJIT.
     Supports push notification, device tag/alias management,
     report statistics, scheduled push, file/image management,
     and push plan management.
   ]],
   homepage = "https://github.com/tom2nonames/lua-resty-jpush",
   license = "MIT",
   maintainer = "tom2nonames@gmail.com"
}
dependencies = {
   "lua-resty-http"
}
build = {
   type = "builtin",
   modules = {
      ["resty.jpush"]            = "lib/resty/jpush/init.lua",
      ["resty.jpush.utils"]      = "lib/resty/jpush/utils.lua",
      ["resty.jpush.push"]       = "lib/resty/jpush/push.lua",
      ["resty.jpush.device"]     = "lib/resty/jpush/device.lua",
      ["resty.jpush.report"]     = "lib/resty/jpush/report.lua",
      ["resty.jpush.schedule"]   = "lib/resty/jpush/schedule.lua",
      ["resty.jpush.file"]       = "lib/resty/jpush/file.lua",
      ["resty.jpush.image"]      = "lib/resty/jpush/image.lua",
      ["resty.jpush.plan"]       = "lib/resty/jpush/plan.lua",
   }
}
