--@amzxyz https://github.com/amzxyz/rime-wanxiang

local tone_map = {
    ['ā']='a', ['á']='a', ['ǎ']='a', ['à']='a',
    ['ē']='e', ['é']='e', ['ě']='e', ['è']='e',
    ['ī']='i', ['í']='i', ['ǐ']='i', ['ì']='i',
    ['ō']='o', ['ó']='o', ['ǒ']='o', ['ò']='o', ['ň']='n',
    ['ū']='u', ['ú']='u', ['ǔ']='u', ['ù']='u', ['ǹ']='n',
    ['ǖ']='ü', ['ǘ']='ü', ['ǚ']='ü', ['ǜ']='ü', ['ń']='n',
}

local function remove_pinyin_tone(s)
    local result = {}
    for uchar in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        table.insert(result, tone_map[uchar] or uchar)
    end
    return table.concat(result)
end

-- ----------------------
-- # 带调全拼注释模块
-- ----------------------
local function get_fz_comment(cand, env, initial_comment)
    local length = utf8.len(cand.text)
    if length > env.settings.candidate_length then
        return ""
    end
    local auto_delimiter = env.settings.auto_delimiter or " "
    local segments = {}
    for segment in string.gmatch(initial_comment, "[^" .. auto_delimiter .. "]+") do
        table.insert(segments, segment)
    end
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
    env.settings = {
        delimiter = delimiter,
        auto_delimiter = auto_delimiter,
        manual_delimiter = manual_delimiter,
    }
end
function ZH.fini(env)
end
function ZH.func(input, env)
    local config = env.engine.schema.config
    local context = env.engine.context
    local input_str = context.input or ""
    local schema_id = env.engine.schema.schema_id or ""
    --preedit相关声明
    local delimiter = env.settings.delimiter
    local auto_delimiter = env.settings.auto_delimiter
    local manual_delimiter = env.settings.manual_delimiter
    local visual_delim = config:get_string("speller/visual_delimiter") or " "
    local is_tone_display = context:get_option("tone_display")
    local is_full_pinyin = context:get_option("full_pinyin")

    for cand in input:iter() do
        local genuine_cand = cand:get_genuine()
        local preedit = genuine_cand.preedit or ""
        local initial_comment = genuine_cand.comment
        local final_comment = initial_comment

        -- preedit相关处理只跳过 preedit，不影响注释
        if not is_tone_display and not is_full_pinyin then
            goto after_preedit
        end
        if (not initial_comment or initial_comment == "") then
            goto after_preedit
        end
        do
            -- 拆分逻辑
            local input_parts = {}
            local current_segment = ""
            for char in preedit:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
                if char == auto_delimiter or char == manual_delimiter then
                    if #current_segment > 0 then
                        table.insert(input_parts, current_segment)
                        current_segment = ""
                    end
                    table.insert(input_parts, char)
                else
                    current_segment = current_segment .. char
                end
            end
            if #current_segment > 0 then
                table.insert(input_parts, current_segment)
            end

            -- 拆分拼音段（comment）
            local pinyin_segments = {}
            for segment in string.gmatch(initial_comment, "[^" .. auto_delimiter .. manual_delimiter .. "]+") do
                local pinyin = segment:match("^[^;]+")
                if pinyin then
                    pinyin = pinyin:gsub("[%[%]]", "")  --去掉英文词库编码中的[]
                    table.insert(pinyin_segments, pinyin)
                end
            end

            -- 替换逻辑
            local pinyin_index = 1
            for i, part in ipairs(input_parts) do
                if part == auto_delimiter or part == manual_delimiter then
                    input_parts[i] = visual_delim
                else
                    local py = pinyin_segments[pinyin_index]

                    if py then
                        local body, tone = part:match("([%a]+)([^%a]+)")

                        if i == #input_parts and #part == 1 then
                            local prefix = py:sub(1, 2)
                            local first_char = part:sub(1,1):lower()
                            if first_char == "s" or first_char == "c" or first_char == "z" then
                                input_parts[i] = part
                            else
                                if prefix == "zh" or prefix == "ch" or prefix == "sh" then
                                    input_parts[i] = prefix
                                else
                                    input_parts[i] = part
                                end
                            end
                        else
                            input_parts[i] = py
                            pinyin_index = pinyin_index + 1
                        end
                    end
                end
            end

            if is_full_pinyin then
                for idx, part in ipairs(input_parts) do
                    input_parts[idx] = remove_pinyin_tone(part)
                end
            end

            genuine_cand.preedit = table.concat(input_parts)
        end
        ::after_preedit::
        -- 进入注释处理阶段
        -- ① 辅助码注释或者声调注释
        if initial_comment and (string.find(initial_comment, "~") or string.find(initial_comment, "\226\152\175")) then
            final_comment = initial_comment

        -- 其他情况一律清空注释
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
