-- @amzxyz  https://github.com/amzxyz/rime-wanxiang
-- @modify: eko5624

-- 支持：\n \r \t \s、字符\重复次数
----------------------------------------------------
-- 数量重复 ( 字符 + \ + 数字 )
-- a\3 => aaa     哈\2 => 哈哈     !\5 => !!!!!

-- 基础转义
-- \n : 换行符    \s : 空格    \t : 制表符

--  示例: 吧	b	5
-- 示例: 哈\5	hhhhh	5
-- 示例: 静夜思\n\s\3李白\n床前明月光\n疑似地上霜\n举头望明月\n低头思故乡	jys	5

local M = {}

local byte = string.byte
local find = string.find
local sub = string.sub
local concat = table.concat

local zwsp = "\226\128\139"

local escape_map = {
    n = zwsp .. "\n",  -- 修复Electron类软件换行丢失
    r = "\r",
    t = "\t",
    s = " ",
    z = zwsp,
}

local function apply_escape(text)
    if not text or not find(text, "\\", 1, true) then
        return text, false
    end

    local parts = {}
    local count = 0
    local changed = false
    local last_char = nil
    local i = 1
    local len = #text

    local function push(value)
        if not value or value == "" then return end
        count = count + 1
        parts[count] = value
        local pos = utf8.offset(value, -1)
        last_char = pos and sub(value, pos) or value
    end

    while i <= len do
        local b = byte(text, i)
        if b == 0x5C then
            if i == len then
                push("\\")
                break
            end
            local next_char = sub(text, i + 1, i + 1)
            -- \\ 输出单个反斜杠
            if next_char == "\\" then
                push("\\")
                changed = true
                i = i + 2
                goto continue
            end
            -- 基础转义
            local escaped = escape_map[next_char]
            if escaped then
                push(escaped)
                changed = true
                i = i + 2
                goto continue
            end
            -- \数字 字符重复
            if next_char >= "0" and next_char <= "9" then
                local j = i + 1
                while j <= len do
                    local c = sub(text, j, j)
                    if c < "0" or c > "9" then break end
                    j = j + 1
                end
                local digits = sub(text, i + 1, j - 1)
                local n = tonumber(digits)
                if last_char and n and n > 0 and n < 200 then
                    if n > 1 then push(string.rep(last_char, n - 1)) end
                    changed = true
                else
                    push("\\" .. digits)
                end
                i = j
                goto continue
            end
            -- 未知转义原样保留
            push("\\" .. next_char)
            i = i + 2
        else
            -- utf‑8 多字节处理
            local char_len
            if b < 0x80 then char_len = 1
            elseif b < 0xE0 then char_len = 2
            elseif b < 0xF0 then char_len = 3
            else char_len = 4 end
            push(sub(text, i, i + char_len - 1))
            i = i + char_len
        end
        ::continue::
    end
    local result = concat(parts, "", 1, count)
    return result, changed or result ~= text
end

local function format_cand(cand)
    local text = cand.text
    if not text or text == "" then
        return cand
    end
    local new_text, changed = apply_escape(text)
    if not changed then
        return cand
    end
    local nc = Candidate(cand.type, cand.start, cand._end, new_text, cand.comment)
    nc.preedit = cand.preedit
    return nc
end

function M.init(env) end
function M.fini(env) end

function M.func(input, env)
    for cand in input:iter() do
        yield(format_cand(cand))
    end
end

return M