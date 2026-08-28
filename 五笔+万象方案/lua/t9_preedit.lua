-- @amzxyz https://github.com/amzxyz/rime-wanxiang
local function escape_pattern_class(s)
    return (s:gsub("([%%%^%[%]%-])", "%%%1"))
end

-- 按自动、手动分隔符拆分 preedit，并保留分隔符原位。
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

-- 从候选注释中提取与 preedit 音节一一对应的拼音。
local function extract_pinyin_segments(initial_comment, split_pattern)
    local pinyins = {}

    for segment in initial_comment:gmatch(split_pattern) do
        local pinyin = segment:match("^[^;]+")
        if pinyin then
            pinyins[#pinyins + 1] = pinyin:gsub("[%[%]]", "")
        end
    end

    return pinyins
end

-- 取得真实拼音的显示声母；zh/ch/sh 优先使用完整声母。
local function get_display_initial(py)
    if not py or py == "" then return "" end
    local prefix = py:match("^(zh|ch|sh)")
    if prefix then
        return prefix
    end

    return py:match("[%z\1-\127\194-\244][\128-\191]*") or ""
end

-- false：简码保留；true：简码直接转换为完整拼音。
local function render_abbreviation(typed, py, should_convert)
    if should_convert then return py end

    local initial = get_display_initial(py)
    if initial == "zh" or initial == "ch" or initial == "sh" then
        return initial
    end

    return typed
end

-- T9 优先处理：单数字是简码
local function convert_t9_syllable(part, py, state)
    if not part:match("^%d$") then return py end

    local typed = get_display_initial(py)
    if typed == "" then return part end
    return render_abbreviation(
        typed, py, state.convert_abbrev_preedit
    )
end

-- 单音节转换总入口：T9 优先，再进入26键处理。
local function convert_preedit_syllable(part, py, state)
    return convert_t9_syllable(part, py, state)
end

-- 完成 preedit 拆分、拼音对齐、逐音节转换和最终去声调。
local function convert_preedit(preedit, initial_comment, state)
    local parts = split_preedit_parts(
        preedit, state.auto_delimiter, state.manual_delimiter
    )
    local pinyins = extract_pinyin_segments(
        initial_comment, state.comment_split_pattern
    )
    local pinyin_index = 1

    for i, part in ipairs(parts) do
        if part ~= state.auto_delimiter
            and part ~= state.manual_delimiter
        then
            local py = pinyins[pinyin_index]
            if py then
                parts[i] = convert_preedit_syllable(part, py, state)
            end
            pinyin_index = pinyin_index + 1
        end
    end

    local result = table.concat(parts)
    return result
end

-- ----------------------
-- 主函数：根据优先级处理候选词的注释和preedit
-- ----------------------
local ZH = {}
function ZH.init(env)
    local config = env.engine.schema.config
    local delimiter = config:get_string('speller/delimiter') or " '"
    local auto_delimiter = delimiter:sub(1, 1)
    local manual_delimiter = delimiter:sub(2, 2)
    local escaped_delimiters = escape_pattern_class(delimiter)
    local convert_abbrev_preedit =
        config:get_bool("super_comment/convert_abbrev_preedit")
    if convert_abbrev_preedit == nil then convert_abbrev_preedit = false end

    env.settings = {
        delimiter = delimiter,
        auto_delimiter = auto_delimiter,
        manual_delimiter = manual_delimiter,
        convert_abbrev_preedit = convert_abbrev_preedit,
        comment_split_pattern = "[^" .. escaped_delimiters .. "]+",
    }
end

function ZH.fini(env)
    env.settings = nil
end

function ZH.func(input, env)
    local context = env.engine.context
    local input_str = context.input or ""
    local skip_comment = input_str == ""
    -- preedit相关声明
    local is_tone_display = context:get_option("tone_display")
    local preedit_state = {
        convert_abbrev_preedit =
            env.settings.convert_abbrev_preedit,
        auto_delimiter = env.settings.auto_delimiter,
        manual_delimiter = env.settings.manual_delimiter,
        comment_split_pattern = env.settings.comment_split_pattern,
    }

    for cand in input:iter() do
        local genuine_cand = cand:get_genuine()
        local preedit = genuine_cand.preedit or ""
        local initial_comment = genuine_cand.comment
        local final_comment = initial_comment

        -- preedit相关处理只跳过 preedit，不影响注释
        if not is_tone_display then
            goto after_preedit
        end
        if (not initial_comment or initial_comment == "") then
            goto after_preedit
        end
        genuine_cand.preedit = convert_preedit(
            preedit, initial_comment, preedit_state
        )
        ::after_preedit::
        if skip_comment then
            yield(genuine_cand)
            goto continue
        end
        -- 进入注释处理阶段
        -- ① 辅助码注释或者声调注释
        if initial_comment and string.find(initial_comment, "~") then
            final_comment = initial_comment
        else
            final_comment = ""
        end

        -- 应用注释
        if final_comment ~= initial_comment then
            genuine_cand.comment = final_comment
        end

        yield(genuine_cand)
        ::continue::
    end
end
return ZH