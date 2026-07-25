--- pattern: ^[;]
function check_alphabet_mode(env)
    local context = env.engine.context
    local input = context.input
    local candidate = context:get_selected_candidate()
    if candidate == nil then
        return false
    end
    candidate = candidate.text
    if input:match('^;') and cand_text == input:sub(2) then
        return true
    end
    return false
end

local function processor(key, env)
    local engine = env.engine
    local context = engine.context
    local repr = key:repr()

    if (repr == 'space' or repr == 'Return') and check_alphabet_mode(env) then
        context:commit()
        return Accepted
    end

    return Noop
end

local function post_processor(key, env)
    local context = env.engine.context

    if key:repr() == 'Return' and check_alphabet_mode(env) then
        context:commit()
        return Accepted
    end
    return Noop
end

local function translator(input, seg)
    if not input:match('^[;]') then
        return
    end

    local text = input:sub(2)
    if text ~= '' then
        yield(Candidate('', seg.start, seg._end, text, ''))
    end
end

_G.alphabet_mode_processor = processor
_G.alphabet_mode_translator = translator
_G.alphabet_mode_post_speller_processor = post_processor
