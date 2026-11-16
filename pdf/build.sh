#!/usr/bin/env bash
# Gera build/livro-gamedev-ia.pdf na ordem de leitura do livro (README).
set -euo pipefail
cd "$(dirname "$0")/.."

order=(00-introducao.md parte-01 parte-02 parte-03 parte-04 interludio-1
       parte-05 parte-06 parte-07 parte-08 interludio-2 parte-09 interludio-3
       parte-10 parte-11)

files=()
for item in "${order[@]}"; do
  if [[ -f $item ]]; then files+=("$item"); continue; fi
  while IFS= read -r f; do files+=("$f"); done < <(ls "$item"/*.md | grep -v '/ESTADO\.md$' | sort)
done

version="$(git describe --tags --always 2>/dev/null || echo dev)"
mkdir -p build
pandoc "${files[@]}" \
  --metadata-file=pdf/metadata.yaml \
  -M version="$version" \
  --lua-filter=pdf/emoji.lua \
  --lua-filter=pdf/book.lua \
  --top-level-division=chapter \
  --pdf-engine=lualatex \
  --resource-path=. \
  -o build/livro-gamedev-ia.pdf
echo "PDF: build/livro-gamedev-ia.pdf (${#files[@]} arquivos, $version)"
