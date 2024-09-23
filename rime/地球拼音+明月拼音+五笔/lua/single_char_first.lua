--- 过滤器：单字在先
local function single_char_first_filter(input, env)
  on = env.engine.context:get_option("single_char_first")
  local l = {}
  for cand in input:iter() do
    if not on or utf8.len(cand.text) == 1 then
      yield(cand)
    else
      table.insert(l, cand)
    end
  end
  for i, cand in ipairs(l) do
    yield(cand)
  end
end

return single_char_first_filter
