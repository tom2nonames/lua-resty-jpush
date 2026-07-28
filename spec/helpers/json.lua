-- Pure Lua JSON decoder/encoder (for test environment)
-- Supports the JSON subset needed for JPush API testing
local json = {}

local function encode(val)
    local t = type(val)
    if t == "nil" then
        return "null"
    elseif t == "string" then
        local s = val:gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r')
        return '"' .. s .. '"'
    elseif t == "number" then
        if val == math.huge then return '1e999'
        elseif val == -math.huge then return '-1e999'
        elseif val ~= val then return 'null'
        end
        return tostring(val)
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "table" then
        local is_array = true
        local max = 0
        for k in pairs(val) do
            if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
                is_array = false
                break
            end
            if k > max then max = k end
        end
        if is_array then
            local parts = {}
            for i = 1, max do
                parts[i] = encode(val[i])
            end
            if max == 0 then return "[]" end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            local keys = {}
            for k in pairs(val) do table.insert(keys, k) end
            table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
            for _, k in ipairs(keys) do
                local ks = type(k) == "string" and encode(k) or tostring(k)
                table.insert(parts, ks .. ":" .. encode(val[k]))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return tostring(val)
end

json.encode = encode

-- Recursive descent JSON decoder
local function skip_whitespace(str, pos)
    while pos <= #str do
        local c = str:sub(pos, pos)
        if c == ' ' or c == '\t' or c == '\n' or c == '\r' then
            pos = pos + 1
        else
            break
        end
    end
    return pos
end

local function decode_value(str, pos)
    pos = skip_whitespace(str, pos)
    if pos > #str then return nil, pos, "unexpected end" end

    local c = str:sub(pos, pos)

    if c == '"' then
        -- string
        local result = {}
        pos = pos + 1
        while pos <= #str do
            c = str:sub(pos, pos)
            if c == '"' then
                pos = pos + 1
                return table.concat(result), pos
            elseif c == '\\' then
                pos = pos + 1
                if pos > #str then return nil, pos, "unexpected end in escape" end
                local esc = str:sub(pos, pos)
                if esc == '"' then table.insert(result, '"')
                elseif esc == '\\' then table.insert(result, '\\')
                elseif esc == '/' then table.insert(result, '/')
                elseif esc == 'b' then table.insert(result, '\b')
                elseif esc == 'f' then table.insert(result, '\f')
                elseif esc == 'n' then table.insert(result, '\n')
                elseif esc == 'r' then table.insert(result, '\r')
                elseif esc == 't' then table.insert(result, '\t')
                elseif esc == 'u' then
                    local hex = str:sub(pos+1, pos+4)
                    if #hex < 4 then return nil, pos, "bad unicode escape" end
                    local cp = tonumber(hex, 16)
                    if cp then
                        table.insert(result, string.char(math.floor(cp/256)) .. string.char(cp % 256))
                        pos = pos + 4
                    else
                        return nil, pos, "bad unicode escape"
                    end
                else
                    table.insert(result, esc)
                end
                pos = pos + 1
            else
                table.insert(result, c)
                pos = pos + 1
            end
        end
        return nil, pos, "unterminated string"

    elseif c == '{' then
        -- object
        local obj = {}
        pos = pos + 1
        pos = skip_whitespace(str, pos)
        if pos <= #str and str:sub(pos, pos) == '}' then
            return obj, pos + 1
        end
        while pos <= #str do
            pos = skip_whitespace(str, pos)
            if pos > #str then return nil, pos, "unexpected end in object" end
            local key, new_pos = decode_value(str, pos)
            if key == nil then return nil, new_pos end
            pos = new_pos
            pos = skip_whitespace(str, pos)
            if pos > #str or str:sub(pos, pos) ~= ':' then
                return nil, pos, "expected ':'"
            end
            pos = pos + 1
            local val, new_pos2 = decode_value(str, pos)
            if val == nil and new_pos2 == nil then
                -- val might be null
                local sp = skip_whitespace(str, pos)
                if sp <= #str and str:sub(sp, sp+3) == "null" then
                    val = json.null
                    new_pos2 = sp + 4
                else
                    return nil, pos, "expected value"
                end
            end
            if val == nil then return nil, new_pos2 end
            pos = new_pos2
            obj[key] = val
            pos = skip_whitespace(str, pos)
            if pos > #str then return nil, pos, "unexpected end" end
            c = str:sub(pos, pos)
            if c == '}' then
                return obj, pos + 1
            elseif c == ',' then
                pos = pos + 1
            else
                return nil, pos, "expected ',' or '}'"
            end
        end
        return nil, pos, "unterminated object"

    elseif c == '[' then
        -- array
        local arr = {}
        pos = pos + 1
        pos = skip_whitespace(str, pos)
        if pos <= #str and str:sub(pos, pos) == ']' then
            return arr, pos + 1
        end
        local idx = 1
        while pos <= #str do
            local val, new_pos = decode_value(str, pos)
            if val == nil and new_pos == nil then
                local sp = skip_whitespace(str, pos)
                if sp <= #str and str:sub(sp, sp+3) == "null" then
                    val = json.null
                    new_pos = sp + 4
                else
                    return nil, pos, "expected value"
                end
            end
            if val == nil then return nil, new_pos end
            pos = new_pos
            arr[idx] = val
            idx = idx + 1
            pos = skip_whitespace(str, pos)
            if pos > #str then return nil, pos, "unexpected end in array" end
            c = str:sub(pos, pos)
            if c == ']' then
                return arr, pos + 1
            elseif c == ',' then
                pos = pos + 1
            else
                return nil, pos, "expected ',' or ']'"
            end
        end
        return nil, pos, "unterminated array"

    elseif c == 't' then
        if str:sub(pos, pos+3) == "true" then
            return true, pos + 4
        end
        return nil, pos, "expected 'true'"

    elseif c == 'f' then
        if str:sub(pos, pos+4) == "false" then
            return false, pos + 5
        end
        return nil, pos, "expected 'false'"

    elseif c == 'n' then
        if str:sub(pos, pos+3) == "null" then
            return json.null, pos + 4
        end
        return nil, pos, "expected 'null'"

    elseif c == '-' or (c >= '0' and c <= '9') then
        -- number
        local end_pos = pos
        if str:sub(end_pos, end_pos) == '-' then end_pos = end_pos + 1 end
        while end_pos <= #str and str:sub(end_pos, end_pos) >= '0' and str:sub(end_pos, end_pos) <= '9' do
            end_pos = end_pos + 1
        end
        if end_pos <= #str and str:sub(end_pos, end_pos) == '.' then
            end_pos = end_pos + 1
            while end_pos <= #str and str:sub(end_pos, end_pos) >= '0' and str:sub(end_pos, end_pos) <= '9' do
                end_pos = end_pos + 1
            end
        end
        if end_pos <= #str and (str:sub(end_pos, end_pos) == 'e' or str:sub(end_pos, end_pos) == 'E') then
            end_pos = end_pos + 1
            if end_pos <= #str and (str:sub(end_pos, end_pos) == '+' or str:sub(end_pos, end_pos) == '-') then
                end_pos = end_pos + 1
            end
            while end_pos <= #str and str:sub(end_pos, end_pos) >= '0' and str:sub(end_pos, end_pos) <= '9' do
                end_pos = end_pos + 1
            end
        end
        local num_str = str:sub(pos, end_pos - 1)
        local num = tonumber(num_str)
        if num then
            return num, end_pos
        end
        return nil, pos, "invalid number"
    end

    return nil, pos, "unexpected character '" .. c .. "'"
end

function json.decode(str)
    if type(str) ~= "string" then
        return nil, "expected string"
    end
    local val, pos, err = decode_value(str, 1)
    if val == nil then
        return nil, err or "parse error"
    end
    pos = skip_whitespace(str, pos)
    if pos <= #str then
        return nil, "trailing garbage"
    end
    if val == json.null then
        return nil
    end
    return val
end

return json
