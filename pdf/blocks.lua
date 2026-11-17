-- Blocos do PDF: diagramas ASCII e tabelas.
--
-- Diagramas (```text ou sem linguagem) viram "figuras": sem quebra de linha e
-- sem realce de sintaxe (que coloria as barras e quebrava as molduras com "↪"),
-- com a fonte reduzida até caber na largura útil, para as colunas continuarem
-- alinhadas, dentro de uma moldura leve. Código com linguagem (cpp, ini, ...)
-- segue o fluxo normal do pandoc (ambiente Shaded, estilizado no metadata).
--
-- Tabelas: fonte menor, cabeçalho em negrito sobre fundo cinza, linhas zebradas
-- e respiro lateral nas células (o pandoc usa @{} e cola o texto na borda).

local TEXT_WIDTH_PT = 372   -- largura útil: (170 - 22 - 18) mm
local FRAME_PT = 10         -- moldura + respiro interno do diagrama
local ADVANCE = 0.602       -- avanço da DejaVu Sans Mono, em em
local MAX_PT, MIN_PT = 8.4, 5.4

local function columns(text)
  local w = 0
  for line in (text .. '\n'):gmatch('(.-)\n') do
    local n = utf8.len(line) or #line
    if n > w then w = n end
  end
  return w
end

function CodeBlock(el)
  local cls = el.classes[1]
  if cls and cls ~= 'text' and cls ~= 'txt' then return nil end

  local text = el.text:gsub('%s+$', '')
  local size = (TEXT_WIDTH_PT - FRAME_PT) / (ADVANCE * math.max(columns(text), 1))
  local wrap = ',breaklines=false'
  if size > MAX_PT then size = MAX_PT end
  if size < MIN_PT then -- largo demais: no mínimo legível, quebrando só se preciso
    size = MIN_PT
    wrap = ',breaklines=true,breakanywhere=true'
  end
  size = math.floor(size * 10) / 10

  -- um "\end{Verbatim}" literal fecharia o ambiente antes da hora
  text = text:gsub('\\end{Verbatim}', '\\end {Verbatim}')

  return pandoc.RawBlock('latex', string.format(
    '\\begin{diagrama}\n\\begin{Verbatim}[fontsize=\\fontsize{%.1fpt}{%.1fpt}\\selectfont%s]\n%s\n\\end{Verbatim}\n\\end{diagrama}',
    size, size * 1.18, wrap, text))
end

local function bold_cells(rows)
  for _, row in ipairs(rows) do
    for _, cell in ipairs(row.cells) do
      for _, blk in ipairs(cell.contents) do
        if (blk.t == 'Plain' or blk.t == 'Para') and #blk.content > 0 then
          blk.content = { pandoc.Strong(blk.content) }
        end
      end
    end
  end
end

function Table(tbl)
  bold_cells(tbl.head.rows)
  local tex = pandoc.write(pandoc.Pandoc({ tbl }), 'latex')

  -- respiro lateral: tira o @{} das pontas e desconta o espaço das colunas
  -- nas larguras relativas (p{...} = (\linewidth - N\tabcolsep) * fração).
  tex = tex:gsub('\\begin{longtable}(%b[])(%b{})', function(opt, spec)
    spec = spec:gsub('^{@{}', '{'):gsub('@{}}$', '}')
    return '\\begin{longtable}' .. opt .. spec
  end, 1)
  tex = tex:gsub('\\linewidth %- (%d+)\\tabcolsep', function(n)
    return '\\linewidth - ' .. (tonumber(n) + 2) .. '\\tabcolsep'
  end)
  -- cabeçalho com fundo (aparece de novo após \endfirsthead, daí sem limite)
  tex = tex:gsub('(\\toprule\\noalign{}\n)', '%1\\rowcolor{black!10}')

  return pandoc.RawBlock('latex',
    '{\\small\\renewcommand{\\arraystretch}{1.25}\\rowcolors{2}{white}{black!4}\n' .. tex .. '}')
end
