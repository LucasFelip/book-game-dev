-- Filtro do PDF: transforma a concatenação dos capítulos (markdown de leitura
-- no GitHub) em um livro: capa, sumário, partes, sem navegação entre arquivos.

local function latex(inlines)
  return pandoc.write(pandoc.Pandoc({ pandoc.Plain(inlines) }), 'latex'):gsub('%s+$', '')
end

local function starts(inlines, prefix)
  return pandoc.utils.stringify(inlines):sub(1, #prefix) == prefix
end

-- "PARTE I — Pensando…" → \part[Parte I — Pensando…]{Parte I\\ Pensando…}
local function part(h)
  local text = latex(h.content)
  local num, title = text:match('^PARTE%s+(%S+)%s+—%s+(.*)$')
  if not num then return pandoc.RawBlock('latex', '\\part{' .. text .. '}') end
  return pandoc.RawBlock('latex', string.format(
    '\\part[Parte %s — %s]{{\\Large Parte %s}\\\\[1.5ex]%s}', num, title, num, title))
end

-- Links para outros .md do livro viram texto (no PDF não há arquivos).
function Link(el)
  if el.target:match('%.md$') or el.target:match('%.md#') then return el.content end
end

function Pandoc(doc)
  local meta = doc.meta
  local blocks, subtitle = {}, ''
  local first_h1 = true
  local i = 1
  while i <= #doc.blocks do
    local b = doc.blocks[i]
    local skip = false
    if b.t == 'Header' and b.level == 1 then
      if first_h1 then
        -- Introdução: o H1 é o título do livro e o H3 seguinte, o subtítulo.
        first_h1 = false
        local nxt = doc.blocks[i + 1]
        if nxt and nxt.t == 'Header' and nxt.level == 3 then
          subtitle = latex(nxt.content); i = i + 1
        end
        b = pandoc.Header(1, 'Introdução', b.attr)
      elseif starts(b.content, 'PARTE ') then
        b = part(b)
      end
    elseif b.t == 'Para' and starts(b.content, '➡') then
      skip = true -- "➡️ Próximo: …" é navegação do GitHub
    end
    if not skip then blocks[#blocks + 1] = b end
    i = i + 1
  end

  local version = meta.version and pandoc.utils.stringify(meta.version) or ''
  local front = string.format([[
\frontmatter
\begin{titlepage}
\centering
\vspace*{0.22\textheight}
{\fontsize{30}{36}\selectfont\bfseries Desenvolvimento de Jogos com IA\par}
\vspace{1.2em}
{\large %s\par}
\vspace{2.5em}
{\normalsize Unreal Engine 5 · C++ · Blueprint · Game AI · Narrativa · Multiplayer · IA generativa\par}
\vfill
{\small %s\par}
\end{titlepage}
\cleardoublepage
\tableofcontents
\mainmatter
]], subtitle, version)
  table.insert(blocks, 1, pandoc.RawBlock('latex', front))
  return pandoc.Pandoc(blocks, meta)
end
