--[
--modify: 空山明月
--date: 2024-04-03	
--]

-- --=========================================================关键字修改--==========================================================
-- --==========================================================--==========================================================
rv_var={ week_var="week",date_var="date",nl_var="nl",time_var="time",jq_var="jq"}	-- 编码关键字修改
single_keyword="single_char"	-- 单字过滤switcher参数
-- --==========================================================--==========================================================
-- --==========================================================--==========================================================
require("lunarDate")
require("lunarJq")
require("lunarGz")
--===================================================时间／日期／农历／历法／数字转换输出=================================================================
-- --====================================================================================================================
function CnDate_translator(y)
	 local t,cstr,t2,t1
	 cstr = {"〇","一","二","三","四","五","六","七","八","九"}  t=""  t1=tostring(y)
	if t1.len(tostring(t1))~=8 then return t1 end
	 for i =1,t1.len(t1) do
		  t2=cstr[tonumber(t1.sub(t1,i,i))+1]
		  if i==5 and t2 ~= "〇" then t2="年十" elseif i==5 and t2 == "〇" then t2="年"  end
		  if i==6 and t2 ~= "〇" then t2 =t2 .. "月" elseif i==6 and t2 == "〇" then t2="月"  end
		  --if t.sub(t,t.len(t)-1)=="年" then t2=t2 .. "月" end
		  if i==7 and tonumber(t1.sub(t1,7,7))>1 then t2= t2 .. "十" elseif i==7 and t2 == "〇" then t2="" elseif i==7 and tonumber(t1.sub(t1,7,7))==1 then t2="十" end
		  if i==8 and t2 ~= "〇" then t2 =t2 .. "日" elseif i==8 and t2 == "〇" then t2="日"  end
		  t=t .. t2
	end
		  return t
end

local GetLunarSichen= function(time,t)
	local time=tonumber(time)
	local LunarSichen = {"子时(夜半｜三更)", "丑时(鸡鸣｜四更)", "寅时(平旦｜五更)", "卯时(日出)", "辰时(食时)", "巳时(隅中)", "午时(日中)", "未时(日昳)", "申时(哺时)", "酉时(日入)", "戌时(黄昏｜一更)", "亥时(人定｜二更)"}
	if tonumber(t)==1 then sj=math.floor((time+1)/2)+1 elseif tonumber(t)==0 then sj=math.floor((time+13)/2)+1 end
	if sj>12 then return LunarSichen[sj-12] else return LunarSichen[sj] end
end

--年天数判断
local function IsLeap(y)
	local year=tonumber(y)
	if math.fmod(year,400)~=0 and math.fmod(year,4)==0 or math.fmod(year,400)==0 then return 366
	else return 365 end
end

local format_Time= function()
	if os.date("%p")=="AM" then return "上午" else return "下午" end
end

-- 星期格式转换
local format_week= function(n)
	local obj={"日","一","二","三","四","五","六"}
	if tonumber(n)==1 then return "周"..obj[os.date("%w")+1] else return "星期"..obj[os.date("%w")+1] end
end
------------------------lua内置日期变量参考-------------------------------------
--[[
	--%a 星期简称，如Wed	%A 星期全称，如Wednesday
	--%b 月份简称，如Sep	%B 月份全称，如September
	--%c 日期时间格式 (e.g., 09/16/98 23:48:10)
	--%d 一个月的第几天 [01-31]	%j 一年的第几天
	--%H 24小时制 [00-23]	%I 12小时制 [01-12]
	--%M 分钟 [00-59]	%m 月份 (09) [01-12]
	--%p 上午/下午 (pm or am)
	--%S 秒 (10) [00-61]
	--%w 星期的第几天 [0-6 = Sunday-Saturday]	%W 一年的第几周
	--%x 日期格式 (e.g., 09/16/98)	%X 时间格式 (e.g., 23:48:10)
	--%Y 年份全称 (1998)	%y 年份简称 [00-99]
	--%% 百分号
	--os.date() 把时间戳转化成可显示的时间字符串
	--os.time ([table])
--]]
----------------------------------------------------------------

-- 公历日期
function date_translator(input, seg)
	local keyword = rv_var["date_var"]
	if (input == keyword) then
		local dates = {
			os.date("%Y年%m月%d日")
			,os.date("%Y-%m-%d")
			,os.date("%Y-%m-%d 第%W周")
			-- ,os.date("%Y.%m.%d")
			-- ,os.date("%Y%m%d")
			-- ,CnDate_translator(os.date("%Y%m%d"))
			-- ,os.date("%Y-%m-%d｜%j/" .. IsLeap(os.date("%Y")))
			}
		-- Candidate(type, start, end, text, comment)
		for i =1,#dates do
			local gregorian_date = (Candidate(keyword, seg.start, seg._end, dates[i], "〈日期〉"))
			gregorian_date.quality = 99999
			yield(gregorian_date)
		end
		dates = nil
	end
end

-- 公历时间
function time_translator(input, seg)
	local keyword = rv_var["time_var"]
	if (input == keyword) then
		local times = {
			os.date("%Y年%m月%d日 %H:%M:%S")
			,os.date("%Y-%m-%d " .. format_Time() .. "%I:%M")
			}
		for i =1,#times do
			local current_time = (Candidate(keyword, seg.start, seg._end, times[i], "〈时间〉"))
			current_time.quality = 99999
			yield(current_time)
		end
		times = nil
	end
end

-- 农历日期
function lunar_translator(input, seg)
	local keyword = rv_var["nl_var"]
	if (input == keyword) then
        -- 1. 先获取公历转农历的结果表（包含多个农历日期格式的字段）
        local todayLunar = Date2LunarDate(os.date("%Y%m%d"))
        -- 2. 从表中提取需要的农历日期字符串（例如 lunarDate_1: "癸卯年四月十一"）
        --    如果表为空或字段不存在，使用默认值 "未知农历日期"
        local lunarStr = todayLunar and todayLunar.lunarDate_1 or "未知农历日期"

        -- 3. 用提取的字符串（lunarStr）替代原表进行拼接
		local lunar = {
			{lunarStr .. JQtest(os.date("%Y%m%d")),"〈公历⇉农历〉"},
			{lunarStr .. GetLunarSichen(os.date("%H"),1),"〈公历⇉农历〉"},
			{lunarJzl(os.date("%Y%m%d%H")),"〈公历⇉干支〉"},
			{LunarDate2Date(os.date("%Y%m%d"),0),"〈农历⇉公历〉"}
		}
		-- 处理闰月情况（确保 LunarDate2Date 返回字符串）
		local leapDate={LunarDate2Date(os.date("%Y%m%d"),1).."（闰）","〈农历⇉公历〉"}
		if string.match(leapDate[1],"^(%d+)")~=nil then -- 检查是否为有效日期字符串
			table.insert(lunar,leapDate)
		end
		
        -- 生成候选词
		for i =1,#lunar do
			local lunar_ymd = (Candidate(keyword, seg.start, seg._end, lunar[i][1], lunar[i][2]))
			lunar_ymd.quality = 99999
			yield(lunar_ymd)
		end
		lunar = nil -- 释放内存
	end
end

local function QueryLunarInfo(date)
	local str,LunarDate,LunarGz,result,DateTime
	date=tostring(date)
	result={}
	str = date:gsub("^(%u+)","") -- 移除开头的大写字母
	-- 仅处理 19/20 开头的年份（如 19xx 或 20xx）
	if string.match(str,"^(20)%d%d+$")~=nil or string.match(str,"^(19)%d%d+$")~=nil then
		-- 补全日期（原逻辑
		if string.len(str)==4 then str=str..string.sub(os.date("%m%d%H"),1)
		elseif string.len(str)==5 then str=str..string.sub(os.date("%m%d%H"),2)
		elseif string.len(str)==6 then str=str..string.sub(os.date("%m%d%H"),3)
		elseif string.len(str)==7 then str=str..string.sub(os.date("%m%d%H"),4)
		elseif string.len(str)==8 then str=str..string.sub(os.date("%m%d%H"),5)
		elseif string.len(str)==9 then str=str..string.sub(os.date("%m%d%H"),6)
		else str=string.sub(str,1,10) end

        -- 新增：校验月份（01-12）和日期（01-31）
        local year = tonumber(string.sub(str,1,4))
        local month = tonumber(string.sub(str,5,6)) or 0
        local day = tonumber(string.sub(str,7,8)) or 0
        if month < 1 or month > 12 or day < 1 or day > 31 then
            return result  -- 无效日期，直接返回空结果
        end

        -- 原逻辑：继续处理有效日期
        LunarDate = Date2LunarDate(str)
        LunarGz = lunarJzl(str)  -- 假设 lunarJzl 需要公历日期的 YYYYMMDD 格式
        DateTime = LunarDate2Date(str, 0)

        if LunarGz ~= nil and LunarDate ~= nil then
            -- 确保 LunarDate 包含必要字段（如 month、day）
            if not LunarDate.month or not LunarDate.day then
                return result  -- 字段缺失，返回空结果
            end

            -- 提取农历日期字符串（确保非 nil）
            local lunarStr = LunarDate.lunarDate_1 or "未知农历日期"
            result = {
                {CnDate_translator(string.sub(str,1,8)),"〈中文日期〉"},
                {lunarStr,"〈公历⇉农历〉"},  -- 确保是字符串
                {LunarGz,"〈公历⇉干支〉"}
            }

            -- 农历转公历和闰月处理（原逻辑）
            if day < 31 then  -- 原逻辑：日期小于31才处理
                table.insert(result, {DateTime, "〈农历⇉公历〉"})
                local leapDate = {LunarDate2Date(str,1) .. "（闰）","〈农历⇉公历〉"}
                if string.match(leapDate[1], "^(%d+)")~=nil then  -- 校验闰日期有效性
                    table.insert(result, leapDate)
                end
            end
        end
    end
    return result
end

-- 农历查询
function QueryLunar_translator(input, seg)	--输入一个或一个以上等于号，进行农历反查
	local str,lunar
	if string.match(input,"^=+(%d+)$")~=nil then
		str = string.gsub(input,"^(=+)", "")
		if string.match(str,"^(20)%d%d+$")~=nil or string.match(str,"^(19)%d%d+$")~=nil then
			lunar=QueryLunarInfo(str)
			if #lunar>0 then
				for i=1,#lunar do
					yield(Candidate(input, seg.start, seg._end, lunar[i][1],lunar[i][2]))
				end
			end
		end
	end
end

--- 单字模式
function single_char(input, env)
	local b = env.engine.context:get_option(single_keyword)
	local input_text = env.engine.context.input
	for cand in input:iter() do
		if (not b or utf8.len(cand.text) == 1 or table.vIn(rv_var, input_text) or input_text:find("^z") or input_text:find("^[%u%p]")) then
			yield(cand)
		end
	end
end

-- 星期
function week_translator(input, seg)
	local keyword = rv_var["week_var"]
	-- local luapath=debug.getinfo(1,"S").source:sub(2):sub(1,-9)   -- luapath.."lua\\user.txt"
	if (input == keyword) then
		local weeks = {
			format_week(1)
			,format_week(2)
			,format_week(0)
			}
		for i =1,#weeks do
			yield(Candidate(keyword, seg.start, seg._end, weeks[i], "〈星期〉"))
		end
		weeks = nil
	end
end

--列出当年余下的节气
function Jq_translator(input, seg)
	local keyword = rv_var["jq_var"]
	if (input == keyword) then
		local jqs = GetNowTimeJq(os.date("%Y%m%d"))
		for i =1,#jqs do
			local lunar_jq = (Candidate(keyword, seg.start, seg._end, jqs[i], "〈节气〉"))
			lunar_jq.quality = 99999
			yield(lunar_jq)
		end
		jqs = nil
	end
end

-------------------------------------------------------------

-- 时间向前或向后计算
-- author: 空山明月
local function addDaysToDate(days, format)
    return os.date(format, os.time() + days * 86400)
end

-- 从当前日期向前或向后计算
-- author: 空山明月
function somedate_translator(input, seg, days)
	local keyword = rv_var["date_var"]
	if (input == keyword) then
		local dates = {
			addDaysToDate(days, "%Y年%m月%d日")
			,addDaysToDate(days, "%Y-%m-%d")
			,addDaysToDate(days, "%Y%m%d")
			}
		for i =1,#dates do
			yield(Candidate(keyword, seg.start, seg._end, dates[i], "〈日期〉"))
		end
		dates = nil
	end
end

-- 获取本月相邻月份同一天时的日期
-- 比如今天是 2024-05-13，则可获取 2024-04/6-13 的日期
-- today: 当天日期
-- is_next: true 表示获取下个月，fase 表示获取上个月
-- retrun: 返回结果表示与当天相差的天数
-- author: 空山明月
function get_month_sameday(is_next)
	local offset_days = 0
	local this_year, this_month = os.date("%Y", os.time()), os.date("%m", os.time())
	local now_days = os.date("%d", os.time())  -- 本月第几天
	
	local last_month, next_month = 0, 0
    local this_day_amount = 0
	local last_day_amount = 0
	local next_day_amount = 0

	if is_next then
		-- 如果现在是12月份，需要向后推一年
		if this_month == 12 then
			last_month, next_month = this_month - 1, 1
		else
			last_month, next_month = this_month - 1, this_month + 1
		end

        this_day_amount = os.date("%d", os.time({year=this_year, month=this_month+1, day=0}))
	    next_day_amount = os.date("%d", os.time({year=this_year, month=next_month+1, day=0}))	

        -- 如果时间间隔超出了下个月的最后一天，则按最后一天算
        local temp_offset_max = this_day_amount
        local temp_offset_min = this_day_amount - now_days + next_day_amount
        if now_days >= next_day_amount then
            offset_days = temp_offset_min
        else
            offset_days = temp_offset_max
        end
	else
		-- 如果当前是1月份，需要向前推一年
		if this_month == 1 then
			last_month, next_month = 12, this_month + 1
		else
			last_month, next_month = this_month - 1, this_month + 1
		end

        this_day_amount = os.date("%d", os.time({year=this_year, month=this_month+1, day=0}))
	    last_day_amount = os.date("%d", os.time({year=this_year, month=last_month+1, day=0}))	

        -- 如果时间间隔超出了下个月的最后一天，则按最后一天算
        if now_days <= last_day_amount then
            offset_days = last_day_amount
        else
            offset_days = now_days
        end
	end
    
	return offset_days
end

-- 时期类字符串集
-- author: 空山明月
str_date_time={ 
	today="wygd",
	next_day="jegd",
	after_next_day = "rggd",
	lastday = "jtgd",
	before_lastday = "uegd",
	time = "jfuj",
	this_week = "sgmf",
	last_week = "hhmf",
	next_week = "ghmf",
	this_month = "sgee",
	last_month = "hhee",
	next_month = "ghee",
	}

-- 时间字符串转译成时间
-- author: 空山明月
function str2datetime_translator(input, seg)

	-- 输出今天的日期
	if (input == str_date_time["today"]) then
		date_translator("date", seg)
	end

	-- 输出明天的日期
	if (input == str_date_time["next_day"]) then
		somedate_translator("date", seg, 1)
	end

	-- 输出后天的日期
	if (input == str_date_time["after_next_day"]) then
		somedate_translator("date", seg, 2)
	end

	-- 输出昨天的日期
	if (input == str_date_time["lastday"]) then
		somedate_translator("date", seg, -1)
	end

	-- 输出前天的日期
	if (input == str_date_time["before_lastday"]) then
		somedate_translator("date", seg, -2)
	end

	-- 输出当前时间
	if (input == str_date_time["time"]) then
		time_translator("time", seg)
	end

	-- 输出本周时间：表示本周的当天时间
	if (input == str_date_time["this_week"]) then
		date_translator("date", seg)
	end

	-- 输出上周时间：表示上周对应星期时间
	-- 比如今天是周三，则此函数返回上周周三对应的日期
	if (input == str_date_time["last_week"]) then
		somedate_translator("date", seg, -7)
	end

	-- 输出下周时间：表示上周对应星期时间
	-- 比如今天是周三，则此函数返回下周周三对应的日期
	if (input == str_date_time["next_week"]) then
		somedate_translator("date", seg, 7)
	end

	-- 输出本月日期，默认是本月当天日期
	if (input == str_date_time["this_month"]) then
		date_translator("date", seg)
	end

	-- 输出上月与当天天数相同的日期，有末则按最后一天计算
	if (input == str_date_time["last_month"]) then
		local days_offset = get_month_sameday(false)
		somedate_translator("date", seg, -days_offset)
	end

	-- 输出下月与当天天数相同的日期，有末则按最后一天计算
	if (input == str_date_time["next_month"]) then
		local days_offset = get_month_sameday(true)
		somedate_translator("date", seg, days_offset)
	end
end

function time_date(input, seg, env)
	date_translator(input, seg)
	time_translator(input, seg)
	week_translator(input, seg)
	lunar_translator(input, seg)
	Jq_translator(input, seg)
	QueryLunar_translator(input, seg)
	str2datetime_translator(input, seg)
end
