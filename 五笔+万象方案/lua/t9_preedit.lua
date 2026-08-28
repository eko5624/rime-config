-- @amzxyz https://github.com/amzxyz/rime-wanxiang
-- @author: amzxyz
-- @modify: eko5624
-- T9方案专用preedit转换为拼音显示

local function escape_pattern_class(s)
    return (s:gsub("([%%%^%[%]%-])", "%%%1"))
end

local function escape_pattern_literal(s)
    return (s:gsub("([^%w])", "%%%1"))
end

-- 按分隔符拆分 preedit，保留分隔符位置
local function split_preedit_parts(preedit, auto_delimiter, manual_delimiter)
    local parts = {}
    local current_segment = ""
    for char in preedit:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if char == auto_delimiter or char == manual_delimiter then
            if current_segment ~= "" then
                parts[#parts + 1] = current_segment
                current_segment = ""
            end
            parts[#parts + 1] = char
        else
            current_segment = current_segment .. char
        end
    end
    if current_segment ~= "" then
        parts[#parts + 1] = current_segment
    end
    return parts
end

-- 从候选注释提取拼音片段
local function extract_pinyin_segments(initial_comment, split_pattern)
    local pinyins = {}
    for segment in initial_comment:gmatch(split_pattern) do
        local pinyin = segment:match("^[^~]+")
        pinyins[#pinyins + 1] = pinyin:gsub("[%[%]]", "")
    end
    return pinyins
end

local function get_display_initial(py)
    if not py or py == "" then return "" end
    local prefix = py:sub(1, 2)
    if prefix == "zh" or prefix == "ch" or prefix == "sh" then
        return prefix
    end
    return py:match("[%z\1-\127\194-\244][\128-\191]*") or ""
end

local function render_abbreviation(typed, py, should_convert)
    if should_convert then return py end
    local initial = get_display_initial(py)
    if initial == "zh" or initial == "ch" or initial == "sh" then
        return initial
    end
    return typed
end

-- T9 音节转换：单数字简码，多数字使用完整拼音（带声调）
local function convert_t9_syllable(part, py, state)
    if not part:match("^%d$") then return py end
    local typed = get_display_initial(py)
    if typed == "" then return part end
    return render_abbreviation(typed, py, state.convert_abbrev_preedit)
end

-- T9 preedit 主转换入口
local function convert_preedit(preedit, initial_comment, state)
    local parts = split_preedit_parts(preedit, state.auto_delimiter, state.manual_delimiter)
    local pinyins = extract_pinyin_segments(initial_comment, state.comment_split_pattern)
    local pinyin_index = 1

    for i, part in ipairs(parts) do
        if part ~= state.auto_delimiter and part ~= state.manual_delimiter then
            local py = pinyins[pinyin_index]
            if py then
                parts[i] = convert_t9_syllable(part, py, state)
            end
            pinyin_index = pinyin_index + 1
        end
    end
    return table.concat(parts)
end

local ZH = {}

function ZH.init(env)
    local config = env.engine.schema.config

    local delimiter = config:get_string('speller/delimiter') or " '"
    local auto_delimiter = delimiter:sub(1, 1)
    local manual_delimiter = delimiter:sub(2, 2)
    local escaped_delimiters = escape_pattern_class(delimiter)

    local convert_abbrev_preedit = config:get_bool("super_comment/convert_abbrev_preedit")
    if convert_abbrev_preedit == nil then convert_abbrev_preedit = false end

    env.settings = {
        auto_delimiter = auto_delimiter,
        manual_delimiter = manual_delimiter,
        comment_delimiter_pattern = auto_delimiter ~= " " and escape_pattern_literal(auto_delimiter) or nil,
        convert_abbrev_preedit = convert_abbrev_preedit,
        comment_split_pattern = "[^" .. escaped_delimiters .. "]+",
    }
end

function ZH.fini(env)
    env.settings = nil
end

function ZH.func(input, env)
    local context = env.engine.context
    local preedit_state = {
        convert_abbrev_preedit = env.settings.convert_abbrev_preedit,
        auto_delimiter = env.settings.auto_delimiter,
        manual_delimiter = env.settings.manual_delimiter,
        comment_split_pattern = env.settings.comment_split_pattern,
    }

    for cand in input:iter() do
        local genuine_cand = cand:get_genuine()
        local initial_comment = genuine_cand.comment

        -- preedit 声调转换无条件执行
        if initial_comment and initial_comment ~= "" then
            genuine_cand.preedit = convert_preedit(genuine_cand.preedit or "", initial_comment, preedit_state)
        end

        -- 清空注释
        local final_comment = ""

        if final_comment ~= initial_comment then
            genuine_cand.comment = final_comment
        end

        yield(genuine_cand)
    end
end

return ZH