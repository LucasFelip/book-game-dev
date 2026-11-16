-- Troca emojis (sem glifo nas fontes do LaTeX) por símbolos que a DejaVu tem.
local map = {
  ["\u{FE0F}"] = "", ["🔁"] = "↻", ["🌉"] = "", ["🧱"] = "", ["📋"] = "", ["🔧"] = "",
  ["✅"] = "✓", ["❌"] = "✗", ["➡"] = "→", ["🟡"] = "●",
}

local function fix(s)
  for k, v in pairs(map) do s = s:gsub(k, v) end
  return s
end

function Str(el) el.text = fix(el.text); return el end
function Code(el) el.text = fix(el.text); return el end
function CodeBlock(el) el.text = fix(el.text); return el end
