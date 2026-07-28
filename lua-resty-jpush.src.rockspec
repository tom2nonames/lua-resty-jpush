package = "lua-resty-jpush"
version = "1.0.0-1"
source = {
   url = "git://github.com/tom2nonames/lua-resty-jpush"
}
description = {
   summary = "Jpush for OpenResty",
   detailed = [[
     Jpush for OpenResty]],
   homepage = "https://github.com/tom2nonames/lua-resty-jpush",
   license = "MIT",
   maintainer = "tom2nonames@gmail.com"
}
dependencies = {
}
build = {
   type = "builtin",
   modules = {
      -- Main entry point
      ["jpush"]           = "lib/resty/jpush/init.lua",
      -- Utils
      ["jpush.utils"]     = "lib/resty/jpush/utils.lua",
      ["jpush.push"]      = "lib/resty/jpush/push.lua",
      ["jpush.device"]    = "lib/resty/jpush/device.lua",
      ["jpush.report"]    = "lib/resty/jpush/report.lua",
      ["jpush.schedule"]  = "lib/resty/jpush/schedule.lua",
   }
}
