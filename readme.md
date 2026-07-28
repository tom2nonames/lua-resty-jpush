# lua-resty-jpush

基于 OpenResty LuaJIT 的极光推送（JPush）REST API 客户端库。极光官方未提供 Lua SDK，此库填补了该空白。

支持极光推送的四大核心 API：

- **推送** — `POST /v3/push`（全量推送、别名推送、标签推送、设备推送）
- **设备管理** — 标签（tag）与别名（alias）的增删改查
- **统计报表** — 消息送达统计、消息详情、用户统计
- **定时任务** — 单次/周期性定时任务的创建、查询、更新、删除

---

## 安装

### 依赖

- OpenResty（内置 `cjson`）
- `lua-resty-http`（cosocket 驱动的 HTTP 客户端）
- `lua-resty-upload`（上传文件时需要，可选）

```bash
# 通过 LuaRocks 安装
luarocks install lua-resty-jpush

# 或手动安装依赖
opm get ledgetech/lua-resty-http
```

### rockspec

项目自带 `lua-resty-jpush.src.rockspec`，可本地构建：

```bash
luarocks make lua-resty-jpush.src.rockspec
```

---

## 快速开始

```lua
local jpush = require("resty.jpush")

local client = jpush.new({
    app_key = "your_app_key",
    master_secret = "your_master_secret",
})

-- 向所有用户推送通知
local result = client.push:send_to_all("Hello from OpenResty!")
```

---

## 核心概念

### 统一响应格式

所有 API 方法返回统一的响应结构：

```lua
-- 成功
{ success = true, data = { ... } }

-- 失败
{ success = false, error = { code = 2003, message = "Bad request", http_status = 400 } }
```

### 错误码

| 常量 | 值 | 含义 |
|---|---|---|
| `SUCCESS` | 0 | 成功 |
| `NETWORK_ERROR` | 1001 | 网络请求失败 |
| `AUTH_ERROR` | 1002 | 鉴权失败 |
| `PARAM_ERROR` | 1003 | 参数校验失败 |
| `RATE_LIMIT` | 1004 | 频率限制 |
| `SERVER_ERROR` | 1005 | 服务端响应解析失败 |
| `UNKNOWN_ERROR` | 1999 | 未知错误 |

极光 API 返回的业务错误码（如 `2002` 频率超限、`2003` 参数错误）会透传到 `error.code` 字段。

### 频率限制

每次请求后自动从响应头提取频率限制信息，通过 `client:get_rate_limit()` 获取：

```lua
local result = client.push:send_to_all("Hello")
local rate_info = client:get_rate_limit()
if rate_info.remaining and rate_info.remaining < 10 then
    ngx.log(ngx.WARN, "JPush rate limit nearly exceeded: ", rate_info.remaining)
end
```

### 连接池

库自动管理 HTTP 连接池。每次请求后将连接归还到连接池（空闲超时 60 秒，池容量 100），无需调用方手动处理 `set_keepalive`。

### 调试日志

创建客户端时开启 `debug = true`，将在 error.log 中记录每次请求的 URL 和响应状态码：

```lua
local client = jpush.new({
    app_key = "...",
    master_secret = "...",
    debug = true,
})
```

---

## API 参考

### 客户端

```lua
local jpush = require("resty.jpush")

local client = jpush.new({
    app_key       = "app_key",
    master_secret = "master_secret",
    timeout       = 10000,     -- 超时时间，毫秒，默认 10000
    ssl_verify    = true,      -- SSL 验证，默认 true
    debug         = false,     -- 调试日志，默认 false
    base_urls     = {          -- 自定义 API 地址，不传则使用默认地址
        push     = "https://api.jpush.cn",
        report   = "https://report.jpush.cn",
        device   = "https://device.jpush.cn",
        schedule = "https://api.jpush.cn",
        -- 可只覆写部分地址，其余使用默认值
    },
})

-- 运行时更新鉴权凭证
client:update_auth("new_app_key", "new_master_secret")

-- 获取最近一次请求的频率限制信息
local rate_info = client:get_rate_limit()
```

当自定义 `base_urls` 时，未指定的服务仍使用默认地址（例如只传 `push` 时，`report` / `device` / `schedule` 不受影响）。

### 推送 API (`client.push`)

| 方法 | 说明 |
|---|---|
| `send(payload)` | 发送推送（完整推送对象） |
| `send_to_all(alert, options?)` | 向所有设备推送通知 |
| `send_to_alias(alias, alert, options?)` | 按别名推送（支持单/多个别名） |
| `send_to_tag(tag, alert, options?)` | 按标签推送（支持单/多个标签） |
| `send_to_registration_id(rid, alert, options?)` | 按设备注册 ID 推送（支持单/多个） |
| `send_message(audience, msg_content, options?)` | 发送自定义消息（不展示通知栏） |
| `validate(payload)` | 校验推送对象（不实际发送） |
| `get_cid(count?)` | 获取推送标识 CID，用于幂等推送 |
| `send(payload, opts)` | 支持 `opts.cid` 传入 CID 实现幂等推送 |

```lua
-- 向所有用户推送
client.push:send_to_all("Hello everyone")

-- 向多个别名推送
client.push:send_to_alias({"user_1", "user_2"}, "Group message")

-- 向标签推送（附加 iOS 配置）
client.push:send_to_tag("vip", "VIP offer", {
    platform = "ios",
    time_to_live = 86400,
})

-- 完整推送对象（支持 Android/iOS 差异化配置）
local result = client.push:send({
    platform = {"android", "ios"},
    audience = { tag = {"active_users"} },
    notification = {
        alert = "Hello",
        android = {
            title = "New Message",
            alert = "You have a new message",
            builder_id = 1,
            extras = { key = "value" },
        },
        ios = {
            alert = "You have a new message",
            sound = "default",
            badge = "+1",
            extras = { key = "value" },
        },
    },
    options = {
        time_to_live = 60,
        apns_production = false,
    },
})
```

### 设备管理 API (`client.device`)

| 方法 | 说明 |
|---|---|
| `get_tags(registration_id)` | 获取设备的标签和别名信息 |
| `set_tags(registration_id, tags)` | 覆盖设置设备标签 |
| `update_tags(registration_id, add_tags?, remove_tags?)` | 增删设备标签 |
| `clear_tags(registration_id)` | 清除设备所有标签 |
| `get_device_info(registration_id)` | 获取设备完整信息（别名、标签、手机号） |
| `set_alias(registration_id, alias)` | 设置设备别名 |
| `get_aliases(alias_value)` | 按别名值查询其下的设备列表 |
| `delete_alias(alias_value, platforms?)` | 删除别名 |
| `get_tags_list()` | 获取全部标签列表 |
| `get_devices_by_tag(tag_value, registration_id?)` | 查询标签下的设备 |
| `check_device_in_tag(registration_id, tag_value)` | 判断设备是否在标签下 |
| `update_tag_devices(tag_value, add_reg_ids?, remove_reg_ids?)` | 批量添加/移除标签下的设备 |
| `delete_tag(tag_value, platforms?)` | 删除标签 |
| `get_devices_status(registration_ids)` | 批量查询设备在线状态 |

```lua
-- 覆盖设置标签
client.device:set_tags("191e35f7e07c2b2315f", {"active", "vip"})

-- 增量增减标签
client.device:update_tags("191e35f7e07c2b2315f", {"new_tag"}, {"old_tag"})

-- 查询设备信息（包含 alias、tags、mobile）
local info = client.device:get_device_info("191e35f7e07c2b2315f")
if info.success then
    ngx.say("Alias:", info.data.alias)
end

-- 检查设备是否在某个标签下
local result = client.device:check_device_in_tag("rid_123", "vip")
if result.data.exists then
    ngx.say("Device is in vip tag")
end
```

### 统计 API (`client.report`)

| 方法 | 说明 |
|---|---|
| `get_received(msg_ids)` | 获取消息送达统计（支持单/多个 msg_id，最多 100 个） |
| `get_received_detail(msg_ids)` | 获取送达统计详情（新接口，字段更丰富） |
| `get_messages(msg_ids)` | 获取消息统计详情（提供更多统计数据） |
| `get_messages_detail(msg_ids)` | 获取消息统计详情（新接口，VIP 专属） |
| `get_message_status(msg_id, registration_ids)` | 查询消息在某组设备上的送达状态（排查工具） |
| `get_users(time_unit, start, duration)` | 获取用户统计（时间单位 + 起始日期 + 持续天数） |

```lua
-- 消息送达统计
local result = client.report:get_received("1828256757")
local result = client.report:get_received({"1828256757", "1828256758"})

-- 送达统计详情
local result = client.report:get_received_detail("1828256757")

-- 消息统计详情
local result = client.report:get_messages("1828256757")
local result = client.report:get_messages_detail("1828256757")

-- 消息送达状态排查
local result = client.report:get_message_status(1828256757, {"dev_1", "dev_2"})

-- 用户统计
local result = client.report:get_users("DAY", "2014-06-10", 3)
```

### 定时任务 API (`client.schedule`)

| 方法 | 说明 |
|---|---|
| `create_single(name, push_payload, trigger_time)` | 创建单次定时任务 |
| `create_periodical(name, push_payload, periodical_config)` | 创建周期性定时任务 |
| `get_list(page?)` | 获取定时任务列表 |
| `get(schedule_id)` | 获取定时任务详情 |
| `update(schedule_id, update_data)` | 更新定时任务 |
| `delete(schedule_id)` | 删除定时任务 |

```lua
-- 单次定时任务
local payload = {
    platform = "all",
    audience = "all",
    notification = { alert = "Happy New Year!" },
}
client.schedule:create_single("NewYearPush", payload, "2026-12-31 23:59:59")

-- 每日定时任务
client.schedule:create_periodical("DailyNews", payload, {
    start = "2026-01-01 09:00:00",
    ["end"] = "2026-12-31 09:00:00",
    time = "09:00:00",
    time_unit = "DAY",
    frequency = 1,
    point = {},
})
```


### 文件管理 API (`client.file`)

用于上传/管理设备列表文件，供大批量推送使用。

| 方法 | 说明 |
|---|---|
| `upload_registration_ids(file_path)` | 上传 registration_id CSV 文件 |
| `get(file_id)` | 获取文件信息 |
| `list(file_type)` | 按类型列出文件 |
| `delete(file_id)` | 删除文件 |

```lua
-- 上传 CSV 文件（单列，每行一个 registration_id）
local result = client.file:upload_registration_ids("/path/to/rids.csv")
if result.success then
    local file_id = result.data.file_id
end

-- 获取文件信息
local info = client.file:get("file_id_here")

-- 列出所有 registration_id 文件
local list = client.file:list("registration_id")

-- 删除文件
client.file:delete("file_id_here")
```

### 图片管理 API (`client.image`)

用于上传/管理推送需要的图片素材。

| 方法 | 说明 |
|---|---|
| `upload_by_urls(urls)` | 通过 URL 上传图片（单次最多 5 个） |
| `update_by_url(media_id, image_url)` | 通过 URL 更新图片 |
| `upload_by_file(file_path)` | 通过文件上传图片 |
| `update_by_file(media_id, file_path)` | 通过文件更新图片 |

```lua
-- 通过 URL 上传图片
local result = client.image:upload_by_urls({"https://example.com/img.png"})
if result.success then
    local media_id = result.data.media_id
end

-- 更新图片
client.image:update_by_url(media_id, "https://example.com/new.png")
```

### 推送计划管理 API (`client.plan`)

用于创建、查询、更新推送计划。

| 方法 | 说明 |
|---|---|
| `create(plan_data)` | 创建推送计划 |
| `list(params)` | 获取推送计划列表 |
| `update(plan_data)` | 更新推送计划 |

```lua
-- 创建推送计划
local plan = {
    name = "Weekly Promo",
    push = {
        platform = "all",
        audience = "all",
        notification = { alert = "Weekly special offer!" },
    },
    -- 计划特定的其他字段
}
local result = client.plan:create(plan)

-- 查询计划列表
client.plan:list({ page = 1, page_size = 10 })

-- 更新计划
client.plan:update({ plan_id = "plan_id_here", name = "Updated Name" })
```

---

## Nginx 配置示例

```nginx
http {
    lua_package_path "/usr/local/openresty/lualib/?.lua;;";

    server {
        listen 8080;

        location /push {
            content_by_lua_block {
                local cjson = require("cjson.safe")
                local jpush = require("resty.jpush")

                local client = jpush.new({
                    app_key = os.getenv("JPUSH_APP_KEY"),
                    master_secret = os.getenv("JPUSH_MASTER_SECRET"),
                })

                ngx.req.read_body()
                local payload = cjson.decode(ngx.req.get_body_data())
                local result = client.push:send(payload)
                ngx.say(cjson.encode(result))
            }
        }
    }
}
```

---

## 测试

### 单元测试（busted）

```bash
busted
```

### 集成测试（Test::Nginx）

测试基于 `Test::Nginx::Socket::Lua`，在每个测试块中启动真实的 OpenResty 实例，配合内嵌的 mock 服务器端到端验证库的行为。

```bash
prove -v t/*.t
```

---

## 注意事项

1. **鉴权信息保管** — Master Secret 拥有完整的 API 调用权限，切勿暴露在客户端代码中。建议通过环境变量或 `lua_shared_dict` 读取配置。
2. **iOS 推送环境** — 推送 iOS 设备时需正确设置 `options.apns_production`。`true` 表示生产环境，`false` 表示开发环境。
3. **广播限制** — 广播推送（`audience = "all"`）每天限制 10 次，请谨慎调用。
4. **SSL 验证** — 生产环境务必保持 `ssl_verify = true`。
5. **北京机房** — 调用方服务器也在北京时，可使用 `https://bjapi.push.jiguang.cn` 获得更快的响应速度：

    ```lua
    local client = jpush.new({
        app_key = "...",
        master_secret = "...",
        base_urls = { push = "https://bjapi.push.jiguang.cn" },
    })
    ```

---

## 许可

MIT
