--- pattern: ^[;A-Z]
function check_alphabet_mode(env)
    local context = env.engine.context
    local input = context.input
    local candidate = context:get_selected_candidate()
    if candidate == nil then
        return false
    end
    candidate = candidate.text
    if (candidate == input and input:match('^[A-Z].*$')) or (';' .. candidate) == input then
        return true
    end
    return false
end

local function processor(key, env)
    local engine = env.engine
    local context = engine.context

    local repr = key:repr()
    if string.sub(repr, 1, 6) == 'Shift+'
            and string.sub(repr, 7):match('^[A-Z]$')
            and not check_alphabet_mode(env)
            and string.sub(context.input, 1, 1) ~= '/'
    then
        if context:is_composing() and not context:has_menu() then
            context.input = ''
        end
        if context:is_composing() and context:has_menu() then
            context:commit()
        end
    end

    if (repr == 'space' or repr == 'Shift+space') and check_alphabet_mode(env) then
        context.input = context.input .. ' '
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
    if not input:match('^[;A-Z]') then
        return
    end
    local first = string.sub(input, 1, 1)
    local text = ''
    if first == ';' then
        text = string.sub(input, 2)
    else
        text = input
    end
    if text ~= '' then
        yield(Candidate('', seg.start, seg._end, text, ''))
    end
end

_G.alphabet_mode_processor = processor
_G.alphabet_mode_translator = translator
_G.alphabet_mode_post_speller_processor = post_processor
