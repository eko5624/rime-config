-- @amzxyz  https://github.com/amzxyz/rime-wanxiang
-- @modify: eko5624

-- 支持：\n \r \t \s \z、[[字面区块]]、字符\重复次数
----------------------------------------------------
-- 数量重复 ( 字符 + \ + 数字 )
-- a\3 => aaa     哈\2 => 哈哈     !\5 => !!!!!

-- 基础转义
-- \n : 换行符    \s : 空格    \t : 制表符
-- [[...]] : 区块内不转义 (如: [[\Y]] 输出 \Y)

--  示例: 吧	b	5
-- 示例: 哈\5	hhhhh	5
-- 示例: 静夜思\n\s\3李白\n床前明月光\n疑似地上霜\n举头望明月\n低头思故乡	jys	5

local M = {}

local find = string.find
local gsub = string.gsub

-- 转义映射
local escape_map = {
    ["\\n"] = "\n",
    ["\\r"] = "\r",
    ["\\t"] = "\t",
    ["\\s"] = " ",
    ["\\z"] = "\226\128\139",
}
local utf8_char_pattern = "[%z\1-\127\194-\244][\128-\191]*"

-- 核心转义处理
local function apply_escape_fast(text)
    if not text or not find(text, "\\", 1, true) then
        return text, false
    end
    local blocks = {}
    local s = text:gsub("%[%[(.-)%]%]", function(txt)
        blocks[#blocks + 1] = txt
        return "\0BLK" .. #blocks .. "\0"
    end)
    s = s:gsub("\\[ntrsz]", escape_map)
    s = s:gsub("(" .. utf8_char_pattern .. ")\\(%d+)", function(char, count)
        local n = tonumber(count)
        if n and n > 0 and n < 200 then
            return string.rep(char, n)
        end
        return char .. "\\" .. count
    end)
    s = s:gsub("\0BLK(%d+)\0", function(i)
        return blocks[tonumber(i)] or ""
    end)
    return s, s ~= text
end

-- 候选文本应用转义
local function process_candidate(cand)
    local text = cand.text
    if not text or text == "" then
        return cand
    end
    local t2, text_changed = apply_escape_fast(text)
    if text_changed then
        local nc = Candidate(cand.type, cand.start, cand._end, t2, cand.comment)
        nc.preedit = cand.preedit
        return nc
    end
    return cand
end

function M.init(env) end
function M.fini(env) end

function M.func(input, env)
    for cand in input:iter() do
        yield(process_candidate(cand))
    end
end

return M