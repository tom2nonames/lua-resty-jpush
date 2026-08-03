package = "lua-resty-jpush"
version = "1.1.0-1"
source = {
   url = "git://github.com/tom2nonames/lua-resty-jpush"
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
      ["jpush"]            = "lib/resty/jpush/init.lua",
      ["jpush.utils"]      = "lib/resty/jpush/utils.lua",
      ["jpush.push"]       = "lib/resty/jpush/push.lua",
      ["jpush.device"]     = "lib/resty/jpush/device.lua",
      ["jpush.report"]     = "lib/resty/jpush/report.lua",
      ["jpush.schedule"]   = "lib/resty/jpush/schedule.lua",
      ["jpush.file"]       = "lib/resty/jpush/file.lua",
      ["jpush.image"]      = "lib/resty/jpush/image.lua",
      ["jpush.plan"]       = "lib/resty/jpush/plan.lua",
   }
}
