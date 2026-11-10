---@type KeyColorStyles
local S = safe_require("nekocat.colors._key_colors")

local settings = key {
  key_text_size = 42,
  hint_text_size = 11,
  key_border_color = "0x00",
  key_back_color = "0x00"
}

local keyboard = keyboard {
  name = "布局与方案",
  author = "Carlson24(鹤衔春雪)",
  ascii_mode = false,
  label_transform = "NONE",
  lock = false,
  navbar = true,
  rows = {
    row {
      height = 0.3,
      keys = {
        key { spacer = true, width = 0.1 },
        key(merge(settings, key { click = "Schemawubi", hint = { { text = "86五笔" } } })),
        key(merge(settings, key { click = "Schemazrm", hint = { { text = "自然码" } } })),
        key(merge(settings, key { click = "Schemazrm18keys", hint = { { text = "自然码18键" } } })),
        key(merge(settings, key { click = "Schema9keys", hint = { { text = "万象九键" } } })),
        key { spacer = true, width = 0.1 }
      }
    },
    row {
      height = 0.3,
      keys = {
        key { spacer = true, width = 0.1 },
        key(merge(settings, key { click = "Schemapinyin", hint = { { text = "万象拼音" } } })),
        key(merge(settings, key { click = "SchemaEnglish", hint = { { text = "万象英文" } } })),

        key { spacer = true, width = 0.1 }
      }
    }
  }
}

return keyboard
