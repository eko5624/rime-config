-- @amzxyz https://github.com/amzxyz/rime-wanxiang
-- @author: amzxyz
-- @modify: eko5624

local SCHEME_CAPABILITIES = {
    wanxiang_zrm = {tone = true, t9 = false},
    wanxiang_pinyin = {tone = true, t9 = false},
    wanxiang_t9 = {tone = true, t9 = true},
}

local COMMENT_CLEAR = 0
local COMMENT_TONE = 1
local COMMENT_TONELESS = 2

local tone_map = {
    ['ā']='a', ['á']='a', ['ǎ']='a', ['à']='a',
    ['ē']='e', ['é']='e', ['ě']='e', ['è']='e',
    ['ī']='i', ['í']='i', ['ǐ']='i', ['ì']='i',
    ['ō']='o', ['ó']='o', ['ǒ']='o', ['ò']='o', ['ň']='en',
    ['ū']='u', ['ú']='u', ['ǔ']='u', ['ù']='u', ['ǹ']='en',
    ['ǖ']='ü', ['ǘ']='ü', ['ǚ']='ü', ['ǜ']='ü', ['ń']='en',
}

-- 以 `tag` 方式检测是否处于反查模式
function is_in_radical_mode(env)
    local seg = env.engine.context.composition:back()
    return seg and (
        seg:has_tag("wubi86") or seg:has_tag("radical")
    ) or false
end

local function remove_pinyin_tone(s)
    local result = {}
    for uchar in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        result[#result + 1] = tone_map[uchar] or uchar
    end
    return table.concat(result)
end

local function escape_pattern_class(s)
    return (s:gsub("([%%%^%[%]%-])", "%%%1"))
end

local function escape_pattern_literal(s)
    return (s:gsub("([^%w])", "%%%1"))
end

local function normalize_comment_delimiter(comment, delimiter_pattern)
    if not delimiter_pattern or not comment or comment == "" then return comment end
    return (comment:gsub(delimiter_pattern, " "))
end

-- 只判断 UTF-8 字符数是否未超过上限。
local function utf8_within(text, limit)
    if not text or text == "" then return true end
    if not limit or limit < 1 then return false end
    local pos = utf8.offset(text, limit + 1)
    return not pos or pos > #text
end

local function apply_tone_digits(env, cand)
    local preedit = cand.preedit
    if not preedit or preedit == "" or not preedit:find("%d") then return end
    if cand.text:match("^[%a%p%s]+$") then return end
    cand.preedit = preedit:gsub("([^%d%s]+)(%d+)", function(body, digits)
        local mapped = digits:gsub("%d", function(d)
            return env.tone_map[d] or d
        end)
        return body .. mapped
    end)
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
        local pinyin = segment
        pinyins[#pinyins + 1] = pinyin:gsub("[%[%]]", "")
    end

    return pinyins
end

-- 取得真实拼音的显示声母；zh/ch/sh 优先使用完整声母。
local function get_display_initial(py)
    if not py or py == "" then return "" end

    local normalized = remove_pinyin_tone(py):lower()
    local prefix = normalized:sub(1, 2)
    if prefix == "zh" or prefix == "ch" or prefix == "sh" then
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

local function is_alpha_abbreviation(part, state)
    if part:match("^[%a]$") then return true end
    
    local lower = part:lower()
    if lower ~= "zh" and lower ~= "ch" and lower ~= "sh" then
        return false
    end
end

-- T9 优先处理：单数字是简码，多数字音节直接转换为完整拼音。
local function convert_t9_syllable(part, py, state)
    if not part:match("^%d$") then return py end

    local typed = get_display_initial(py)
    if typed == "" then return part end
    return render_abbreviation(typed, py, state.convert_abbrev_preedit)
end


-- 26键处理：简码按配置保留或转全拼，其他音节维持原有转换语义。
local function convert_alpha_syllable(part, py, state)
    if is_alpha_abbreviation(part, state) then
        return render_abbreviation(part, py, state.convert_abbrev_preedit)
    end

    local _, tone = part:match("([%a]+)([^%a]+)")
    if state.tone_isolate then return py .. (tone or "") end
    return py
end

-- 单音节转换总入口：T9 优先，再进入26键处理。
local function convert_preedit_syllable(part, py, state)
    if state.is_t9 then
        return convert_t9_syllable(part, py, state)
    end

    return convert_alpha_syllable(part, py, state)
end

-- 完成 preedit 拆分、拼音对齐、逐音节转换和最终去声调。
local function convert_preedit(preedit, initial_comment, state)
    local parts = split_preedit_parts(preedit, state.auto_delimiter, state.manual_delimiter)
    local pinyins = extract_pinyin_segments(initial_comment, state.comment_split_pattern)
    local pinyin_index = 1

    for i, part in ipairs(parts) do
        if part ~= state.auto_delimiter and part ~= state.manual_delimiter then
            local py = pinyins[pinyin_index]
            if py then
                parts[i] = convert_preedit_syllable(part, py, state)
            end
            pinyin_index = pinyin_index + 1
        end
    end

    local result = table.concat(parts)
    if state.is_full_pinyin and state.has_tone then
        result = remove_pinyin_tone(result)
    end

    return result
end

-- ----------------------
-- 主函数：根据优先级处理候选词的注释和preedit
-- ----------------------
local ZH = {}
function ZH.init(env)
    local config = env.engine.schema.config
    local schema_id = env.engine.schema.schema_id
    local caps = SCHEME_CAPABILITIES[schema_id]
    local delimiter = config:get_string('speller/delimiter') or " '"
    local auto_delimiter = delimiter:sub(1, 1)
    local manual_delimiter = delimiter:sub(2, 2)
    local escaped_delimiters = escape_pattern_class(delimiter)
    local convert_abbrev_preedit = config:get_bool("super_comment/convert_abbrev_preedit")
    if convert_abbrev_preedit == nil then convert_abbrev_preedit = false end

    env.has_tone = caps.tone
    env.is_t9 = caps.t9

    env.settings = {
        auto_delimiter = auto_delimiter,
        manual_delimiter = manual_delimiter,
        comment_delimiter_pattern = auto_delimiter ~= " "
            and escape_pattern_literal(auto_delimiter) or nil,
        candidate_length = tonumber(config:get_string("super_comment/candidate_length")) or 1,
        convert_abbrev_preedit = convert_abbrev_preedit,
        comment_split_pattern = "[^" .. escaped_delimiters .. "]+",
    }

    if env.has_tone then
        env.settings.tone_isolate = config:get_bool("super_comment/tone_isolate")
    end

    env.tone_map = nil
    if env.has_tone and not env.is_t9 then
        env.tone_map = {}
        for d = 0, 9 do
            local key = tostring(d)
            local value = config:get_string("tone_preedit/" .. key)
            env.tone_map[key] = value and value ~= "" and value or key
        end
    end
end

function ZH.fini(env)
    env.settings = nil
    env.tone_map = nil
    env.has_tone = nil
    env.is_t9 = nil
end

function ZH.func(input, env)
    local context = env.engine.context
    local settings = env.settings
    local has_tone = env.has_tone
    local is_t9 = env.is_t9
    local input_str = context.input or ""
    local is_radical_mode = is_in_radical_mode(env)
    local skip_comment = input_str == ""

    local preedit_state = nil
    if not is_radical_mode then
        local is_full_pinyin = context:get_option("full_pinyin")
        local is_tone_display = has_tone and context:get_option("tone_display") or false
        
        if is_full_pinyin or is_tone_display then
            preedit_state = {
                is_t9 = is_t9,
                has_tone = has_tone,
                is_full_pinyin = is_full_pinyin,
                tone_isolate = settings.tone_isolate,
                convert_abbrev_preedit = settings.convert_abbrev_preedit,
                auto_delimiter = settings.auto_delimiter,
                manual_delimiter = settings.manual_delimiter,
                comment_split_pattern = settings.comment_split_pattern,
            }
        end
    end    

    local comment_mode = COMMENT_CLEAR
    if not skip_comment and not is_radical_mode then
        if has_tone then
            if context:get_option("tone_hint") then
                comment_mode = COMMENT_TONE
            elseif context:get_option("toneless_hint") then
                comment_mode = COMMENT_TONELESS
            end
        end
    end

    local candidate_length = settings.candidate_length
    local comment_split_pattern = settings.comment_split_pattern
    local comment_delimiter_pattern = settings.comment_delimiter_pattern

    for cand in input:iter() do
        local genuine_cand = cand:get_genuine()
        local cand_type = genuine_cand.type

        local initial_comment = genuine_cand.comment
        if preedit_state and initial_comment and initial_comment ~= "" then
            genuine_cand.preedit = convert_preedit(genuine_cand.preedit or "", initial_comment, preedit_state)
        end

        if skip_comment then
            yield(genuine_cand)
            goto continue
        end

        if not is_t9 then
            if has_tone then apply_tone_digits(env, genuine_cand) end
        end

        if is_radical_mode then
            genuine_cand.comment = normalize_comment_delimiter(
                initial_comment,
                comment_delimiter_pattern
            )
            yield(genuine_cand)
            goto continue
        end

        local final_comment
        if initial_comment and initial_comment:find("~", 1, true) then
            final_comment = initial_comment
        elseif comment_mode ~= COMMENT_CLEAR and utf8_within(cand.text, candidate_length) then
            if comment_mode == COMMENT_TONE then
                final_comment = initial_comment or ""
            elseif comment_mode == COMMENT_TONELESS then
                final_comment = remove_pinyin_tone(initial_comment or "")
            else
                final_comment = initial_comment or ""
            end
        else
            final_comment = ""
        end

        final_comment = normalize_comment_delimiter(final_comment, comment_delimiter_pattern)
        if final_comment ~= initial_comment then
            genuine_cand.comment = final_comment
        end

        yield(genuine_cand)
        ::continue::
    end
end

return ZH