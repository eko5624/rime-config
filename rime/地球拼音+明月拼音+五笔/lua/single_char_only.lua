--- 过滤器：仅单字
local function single_char_only_filter(input, env)
  on = env.engine.context:get_option("single_char_only")
  for cand in input:iter() do
    if not on or utf8.len(cand.text) == 1 then
      yield(cand)
    end
  end
end

return single_char_only_filter