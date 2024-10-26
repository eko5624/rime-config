-- author: https://github.com/ChaosAlphard
-- 说明 https://github.com/gaboolic/rime-shuangpin-fuzhuma/pull/41
local T = {}

function T.init(env)
    local config = env.engine.schema.config
    -- env.name_space = env.name_space:gsub('^*', '')
    local _calc_pat = config:get_string("recognizer/patterns/calculator") or nil
    -- 获取 recognizer/patterns/calculator 的第 2 个字符作为触发前缀（也就是获取等于号 = 或其他自定义字符）
    T.prefix = _calc_pat and _calc_pat:sub(2, 2)
    -- T.tips = "计算器"
end

local function startsWith(str, start)
    return string.sub(str, 1, string.len(start)) == start
end

-- 函数表
local calc_methods = {
    -- e, exp(1) = e^1 = e
    e = math.exp(1),
    -- π
    pi = math.pi,
    b = 10 ^ 2,
    q = 10 ^ 3,
    k = 10 ^ 3,
    w = 10 ^ 4,
    tw = 10 ^ 5,
    m = 10 ^ 6,
    tm = 10 ^ 7,
    y = 10 ^ 8,
    g = 10 ^ 9
}

local methods_desc = {
  ["e"] = "自然常数, 欧拉数",
  ["pi"] = "圆周率 π",
    ["b"] = "百",
    ["q"] = "千",
    ["k"] = "千",
    ["w"] = "万",
    ["tw"] = "十万",
    ["m"] = "百万",
    ["tm"] = "千万",
    ["y"] = "亿",
    ["g"] = "十亿"
}

-- random([m [,n ]]) 返回m-n之间的随机数, n为空则返回1-m之间, 都为空则返回0-1之间的小数
local function random(...) return math.random(...) end
-- 注册到函数表中
calc_methods["rdm"] = random
methods_desc["rdm"] = "随机数"

-- 正弦
local function sin(x) return math.sin(x) end
calc_methods["sin"] = sin
methods_desc["sin"] = "正弦"

-- 双曲正弦
local function sinh(x)
    return (math.exp(x) - math.exp(-x)) / 2
end
calc_methods["sinh"] = sinh
methods_desc["sinh"] = "双曲正弦"

-- 反正弦
local function asin(x) return math.asin(x) end
calc_methods["asin"] = asin
methods_desc["asin"] = "反正弦"

-- 余弦
local function cos(x) return math.cos(x) end
calc_methods["cos"] = cos
methods_desc["cos"] = "余弦"

-- 双曲余弦
local function cosh(x)
    return (math.exp(x) + math.exp(-x)) / 2
end
calc_methods["cosh"] = cosh
methods_desc["cosh"] = "双曲余弦"

-- 反余弦
local function acos(x) return math.acos(x) end
calc_methods["acos"] = acos
methods_desc["acos"] = "反余弦"

-- 正切
local function tan(x) return math.tan(x) end
calc_methods["tan"] = tan
methods_desc["tan"] = "正切"

-- 双曲正切
local function tanh(x)
    local e = math.exp(2 * x)
    return (e - 1) / (e + 1)
end
calc_methods["tanh"] = tanh
methods_desc["tanh"] = "双曲正切"

-- 反正切
local function atan(x) return math.atan(x) end
calc_methods["atan"] = atan
methods_desc["atan"] = "反正切"

-- 返回以弧度为单位的点(x,y)相对于x轴的逆时针角度。y是点的纵坐标，x是点的横坐标
-- 返回范围从−π到π （以弧度为单位），其中负角度表示向下旋转，正角度表示向上旋转
-- 它与传统的 math.atan(y/x) 函数相比，具有更好的数学定义，因为它能够正确处理边界情况（例如x=0）
local function atan2(y, x)
    if x == 0 and y == 0 then
        return 0 / 0 -- 返回NaN
    elseif x == 0 and y ~= 0 then
        if y > 0 then
            return math.pi / 2
        else
            return -math.pi / 2
        end
    else
        return math.atan(y / x) + (x < 0 and math.pi or 0)
    end
end
calc_methods["atan2"] = atan2
methods_desc["atan2"] = "返回以弧度为单位的点(x,y)相对于x轴的逆时针角度"

-- 将角度从弧度转换为度 e.g. deg(π) = 180
local function deg(x) return math.deg(x) end
calc_methods["deg"] = deg
methods_desc["deg"] = "弧度转换为角度"

-- 将角度从度转换为弧度 e.g. rad(180) = π
local function rad(x) return math.rad(x) end
calc_methods["rad"] = rad
methods_desc["rad"] = "角度转换为弧度"

-- 返回两个值, 无法参与运算后续
-- 返回m,e 使得x = m*2^e
--[[
local function frexp(x)
  return math.frexp(x)
end
calcPlugin["frexp"] = frexp
--]]

-- 返回 x*2^y
local function ldexp(x, y) return x * 2 ^ y end
calc_methods["ldexp"] = ldexp
methods_desc["ldexp"] = "返回 x*2^y"

-- 返回 e^x
local function exp(x) return math.exp(x) end
calc_methods["exp"] = exp
methods_desc["exp"] = "返回 e^x"

-- 计算开 N 次方
local function nth_root(x, n)
    if n % 2 == 0 and x < 0 then
        return nil -- 偶次方时负数没有实数解
    elseif x < 0 then
        return -((-x) ^ (1 / n))
    else
        return x ^ (1 / n)
    end
end
calc_methods["nroot"] = nth_root
methods_desc["nroot"] = "计算 x 开 N 次方"

-- 返回x的平方根 e.g. sqrt(x) = x^0.5
local function sqrt(x) return math.sqrt(x) end
calc_methods["sqrt"] = sqrt
methods_desc["sqrt"] = "计算 x 平方根"

-- x为底的对数, log(10, 100) = log(100) / log(10) = 2
local function log(x, y)
    -- 不能为负数或0
    if x <= 0 or y <= 0 then
        return nil
    end

    return math.log(y) / math.log(x)
end
calc_methods["log"] = log
methods_desc["log"] = "x作为底数的对数"

-- 自然数e为底的对数
local function loge(x)
    -- 不能为负数或0
    if x <= 0 then return nil end

    return math.log(x)
end
calc_methods["loge"] = loge
methods_desc["loge"] = "e作为底数的对数"

-- 10为底的对数
local function logt(x)
    -- 不能为负数或0
    if x <= 0 then return nil end

    return math.log(x) / math.log(10)
end
calc_methods["logt"] = logt
methods_desc["logt"] = "10作为底数的对数"

-- 平均值
local function avg(...)
    local data = {...}
    local n = select("#", ...)
    -- 样本数量不能为0
    if n == 0 then return nil end

    -- 计算总和
    local sum = 0
    for _, value in ipairs(data) do
        sum = sum + value
    end

    return sum / n
end
calc_methods["avg"] = avg
methods_desc["avg"] = "平均值"

-- 方差
local function variance(...)
    local data = {...}
    local n = select("#", ...)
    -- 样本数量不能为0
    if n == 0 then return nil end

    -- 计算均值
    local sum = 0
    for _, value in ipairs(data) do
        sum = sum + value
    end
    local mean = sum / n

    -- 计算方差
    local sum_squared_diff = 0
    for _, value in ipairs(data) do
        sum_squared_diff = sum_squared_diff + (value - mean) ^ 2
    end

    return sum_squared_diff / n
end
calc_methods["var"] = variance
methods_desc["var"] = "方差"

-- 阶乘
local function factorial(x)
    -- 不能为负数
    if x < 0 then return nil end
    if x == 0 or x == 1 then return 1 end

    local result = 1
    for i = 1, x do
        result = result * i
    end

    return result
end
calc_methods["fact"] = factorial
methods_desc["fact"] = "阶乘"

-- 实现阶乘计算(!)
local function replaceToFactorial(str)
    -- 替换[0-9]!字符为fact([0-9])以实现阶乘
    return str:gsub("([0-9]+)!", "fact(%1)")
end

local function serialize(obj)
  local type = type(obj)
  if type == "number" then
    return isinteger(obj) and floor(obj) or obj
  elseif type == "boolean" then
    return tostring(obj)
  elseif type == "string" then
    return '"'..obj..'"'
  elseif type == "table" then
    local str = "{"
    local i = 1
    for k, v in pairs(obj) do
      if i ~= k then  
        str = str.."["..serialize(k).."]="
      end
      str = str..serialize(v)..", "  
      i = i + 1
    end
    str = str:len() > 3 and str:sub(0,-3) or str
    return str.."}"
  elseif pcall(obj) then -- function類型
    return "callable"
  end
  return obj
end

local function speakLiterally(str, valMap)
	valMap = valMap or {
		[0]="零"; "一"; "二"; "三"; "四"; "五"; "六"; "七"; "八"; "九"; "十";
		["+"]="正"; ["-"]="负"; ["."]="点"; [""]=""
	}

	local tbOut = {}
	for k = 1, #str do
		local v = string.sub(str, k, k)
		v = tonumber(v) or v
		tbOut[k] = valMap[v]
	end
	return table.concat(tbOut)
end

local function speakMillitary(str)
	return speakLiterally(str, {[0]="洞"; "幺"; "两"; "三"; "四"; "五"; "六"; "拐"; "八"; "勾"; "十";["+"]="正"; ["-"]="负"; ["."]="点"; [""]=""})
end

local function splitNumStr(str)
	--[[
		split a number (or a string describing a number) into 4 parts:
		.sym: "+", "-" or ""
		.int: "0", "000", "123456", "", etc
		.dig: "." or ""
		.dec: "0", "10000", "00001", "", etc
	--]]
	local part = {}
	part.sym, part.int, part.dig, part.dec = string.match(str, "^([%+%-]?)(%d*)(%.?)(%d*)")
	return part
end

local function speakBar(str, posMap, valMap)
	posMap = posMap or {[1]="仟"; [2]="佰"; [3]="拾"; [4]=""}
	valMap = valMap or {[0]="零"; "一"; "二"; "三" ;"四"; "五"; "六"; "七"; "八"; "九"} -- the length of valMap[0] should not excess 1

	local out = ""
	local bar = string.sub("****" .. str, -4, -1) -- the integer part of a number string can be divided into bars; each bar has 4 bits
	for pos = 1, 4 do
		local val = tonumber(string.sub(bar, pos, pos))
		-- case1: place holder
		if val == nil then
			goto continue
		end
		-- case2: number 1~9
		if val > 0 then
			out = out .. valMap[val] .. posMap[pos]
			goto continue
		end
		-- case3: number 0
		local valNext = tonumber(string.sub(bar, pos+1, pos+1))
		if ( valNext==nil or valNext==0 )then
			goto continue
		else
			out = out .. valMap[0]
			goto continue
		end
	::continue::
	end
	if out == "" then out = valMap[0] end
	return out
end

local function speakIntOfficially(str, posMap, valMap)
	posMap = posMap or {[1]="千"; [2]="百"; [3]="十"; [4]=""}
	valMap = valMap or {[0]="零"; "一"; "二"; "三" ;"四"; "五"; "六"; "七"; "八"; "九"} -- the length of valMap[0] should not excess 1

	-- split the number string into bars, for example, in:str=123456789 → out:tbBar={1|2345|6789}
	local int = string.match(str, "^0*(%d+)$")
	if int=="" then int = "0" end
	local remain = #int % 4
	if remain==0 then remain = 4 end
	local tbBar = {[1] = string.sub(int, 1, remain)}
	for pos = remain+1, #int, 4 do
		local bar = string.sub(int, pos, pos+3)
		table.insert(tbBar, bar)
	end
	-- generate the suffixes of each bar, for example, tbSpeakBarSuffix={亿|万|""}
	local tbSpeakBarSuffix = {[1]=""}
	for iBar = 2, #tbBar do
		local suffix = (iBar % 2 == 0) and ("万"..tbSpeakBarSuffix[1]) or ("亿"..tbSpeakBarSuffix[2])
		table.insert(tbSpeakBarSuffix, 1, suffix)
	end
	-- speak each bar
	local tbSpeakBar = {}
	for k = 1, #tbBar do
		tbSpeakBar[k] = speakBar(tbBar[k], posMap, valMap)
	end
	-- combine the results
	local out = ""
	for k = 1, #tbBar do
		local speakBar = tbSpeakBar[k]
		if speakBar ~= valMap[0] then
			out = out .. speakBar .. tbSpeakBarSuffix[k]
		end
	end
	if out == "" then out = valMap[0] end
	return out
end

local function speakDecMoney(str, posMap, valMap)
	posMap = posMap or {[1]="角"; [2]="分"; [3]="厘"; [4]="毫"}
	valMap = valMap or {[0]="零"; "壹"; "贰"; "叁" ;"肆"; "伍"; "陆"; "柒"; "捌"; "玖"} -- the length of valMap[0] should not excess 1

	local dec = string.sub(str, 1, 4)
	dec = string.gsub(dec, "0*$", "")
	if dec == "" then
		return "整"
	end

	local out = ""
	for pos = 1, #dec do
		local val = tonumber(string.sub(dec, pos, pos))
		out = out .. valMap[val] .. posMap[pos]
	end
	return out
end

local function speakOfficiallyLower(str)
	local part = splitNumStr(str)
	local speakSym = speakLiterally(part.sym)
	local speakInt = speakIntOfficially(part.int)
	local speakDig = speakLiterally(part.dig)
	local speakDec = speakLiterally(part.dec)
	local out = speakSym .. speakInt .. speakDig .. speakDec
	return out
end

local function speakOfficiallyUpper(str)
    local part = splitNumStr(str)
	local speakSym = speakLiterally(part.sym)
	local speakInt = speakIntOfficially(part.int, {[1]="仟"; [2]="佰"; [3]="拾"; [4]=""}, {[0]="零"; "壹"; "贰"; "叁" ;"肆"; "伍"; "陆"; "柒"; "捌"; "玖"})
	local speakDig = speakLiterally(part.dig)
	local speakDec = speakLiterally(part.dec)
	local out = speakSym .. speakInt .. speakDig .. speakDec
	return out
end

local function speakMoneyUpper(str)
	local part = splitNumStr(str)
	local speakSym = speakLiterally(part.sym)
	local speakInt = speakIntOfficially(part.int, {[1]="仟"; [2]="佰"; [3]="拾"; [4]=""}, {[0]="零"; "壹"; "贰"; "叁" ;"肆"; "伍"; "陆"; "柒"; "捌"; "玖"}) .. "元"
	local speakDec = speakDecMoney(part.dec)
	local out = speakSym .. speakInt .. speakDec
	return out
end

local function speakMoneyLower(str)
	local part = splitNumStr(str)
	local speakSym = speakLiterally(part.sym)
	local speakInt = speakIntOfficially(part.int, {[1]="千"; [2]="百"; [3]="十"; [4]=""}, {[0]="〇"; "一"; "二"; "三" ;"四"; "五"; "六"; "七"; "八"; "九"}) .. "元"
	local speakDec = speakDecMoney(part.dec)
	local out = speakSym .. speakInt .. speakDec
	return out
end

local function baseConverse(str, from, to)
	local str10 = str
	if from == 16 then
		str10 = string.format("%d", str)
	end
	local strout = str10
	if to == 16 then
		strout = string.format("%#x", str10)
	end
	return strout
end

-- 简单计算器
function T.func(input, seg, env)
    local composition = env.engine.context.composition
    if composition:empty() then return end
    local segment = composition:back()

    if startsWith(input, T.prefix) or (seg:has_tag("calculator")) then
        -- segment.prompt = "〔" .. T.tips .. "〕"
        -- 提取算式
        local express = input:gsub(T.prefix, "")
        -- 算式长度 = 0 直接终止(只打出 = 没有计算意义)
        if (string.len(express) == 0) and (not calc_methods[express]) then return end
        -- if (string.len(express) == 2) and (express:match("^%d[^%!]$")) then return end
        local code = replaceToFactorial(express)

        local loaded_func, load_error = load("return " .. code, "calculate", "t", calc_methods)
        if loaded_func and (type(methods_desc[code]) == "string") then
            yield(Candidate(input, seg.start, seg._end, express .. ":" .. methods_desc[code], ""))
            	elseif loaded_func then
            local success, result = pcall(loaded_func)
            if success then
                yield(Candidate(input, seg.start, seg._end, express .. "=" .. tostring(result), "〈等式〉"))
                yield(Candidate(input, seg.start, seg._end, tostring(result), "〈结果〉"))
			    yield(Candidate("number", seg.start, seg._end, speakMoneyUpper(result), "〈大写金额〉"))
			    yield(Candidate("number", seg.start, seg._end, speakMoneyLower(result), "〈小写金额〉"))
			    yield(Candidate("number", seg.start, seg._end, speakOfficiallyUpper(result), "〈大写数字〉"))
			    yield(Candidate("number", seg.start, seg._end, speakOfficiallyLower(result), "〈小写数字〉"))
            else
                -- 处理执行错误
        		yield(Candidate(input, seg.start, seg._end, express, "执行错误"))
            end
        else
            -- 处理加载错误
      		yield(Candidate(input, seg.start, seg._end, express, "解析失败"))
        end
    end
end

return T

