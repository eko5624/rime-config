-- ========================================================================
-- 预设键盘布局 (TextKeyboard)
-- ========================================================================

---@type { [string]: TextKeyboard }
local tk = {
  default               = safe_require("nekocat.layouts.47keys"),
  calculator            = safe_require("nekocat.layouts.calculator"),
  editor                = safe_require("nekocat.layouts.editor"),
  number                = safe_require("nekocat.layouts.number"),
  settings              = safe_require("nekocat.layouts.settings"),
  wubi86                = safe_require("nekocat.layouts.47keys"),
  wanxiang_zrm          = safe_require("nekocat.layouts.47keys"),
  wanxiang_zrm_18keys   = safe_require("nekocat.layouts.37keys"),
  wanxiang_zrm_14keys   = safe_require("nekocat.layouts.35keys"),
  wanxiang_pinyin       = safe_require("nekocat.layouts.47keys"),
  wanxiang_t9           = safe_require("nekocat.layouts.17keys"),
  wanxiang_english      = merge(safe_require("nekocat.layouts.47keys"), keyboard { name = "万象英文" }),
  t9_number             = merge(safe_require("nekocat.layouts.number"), keyboard { ascii_mode = true }),
  english               = merge(safe_require("nekocat.layouts.47keys"),
    keyboard { name = "英文布局", ascii_mode = true, rows = { [5] = { keys = { [6] = key { click = "KeyboardDefault" } } } } })
}

return tk
