#!/usr/bin/env bash
# find_text.sh — pull out text files that look like source code or configs
#
# Photorec doesn't carve source code well — most text recoveries come out
# as .txt with no indication of what they were. This script scans photorec
# text output, heuristically identifies likely source code / config / notes,
# and copies them to a sorted output tree.
#
# Heuristics:
#   - Python: shebang or `import`, `def`, `class` patterns
#   - Rust: `fn main`, `use std::`, `impl`, `pub fn`
#   - JavaScript/TypeScript: `const`, `let`, `import ... from`, `function`
#   - Shell: shebang `#!/bin/`
#   - Config: [sections], key=value patterns, TOML-like [[tables]]
#   - Markdown: # headers, ## subheaders
#   - JSON/YAML: structural patterns
#
# Usage: ./find_text.sh <input_dir> [output_dir]

set -u

INPUT_DIR="${1:-}"
OUTPUT_DIR="${2:-}"

if [[ -z "$INPUT_DIR" ]]; then
    echo "Usage: $0 <input_dir> [output_dir]" >&2
    exit 1
fi

if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="$(dirname "$INPUT_DIR")/text-sorted"
fi

mkdir -p "$OUTPUT_DIR"/{python,rust,javascript,typescript,shell,config,markdown,json,yaml,toml,unknown}

classify() {
    local f="$1"

    # Binary check — skip files that aren't plain text.
    # `file` examines the first few KB and reports MIME type.
    local mime
    mime=$(file -b --mime-type "$f" 2>/dev/null || echo "")
    case "$mime" in
        text/*|application/json|application/xml|application/x-shellscript|inode/x-empty) : ;;
        *) return 1 ;;
    esac

    local head
    head=$(head -c 4096 "$f" 2>/dev/null) || return 1

    # Shebang lines (check first line only)
    local first_line
    first_line=$(printf '%s' "$head" | head -n 1)
    if [[ "$first_line" =~ ^\#\!.*python ]]; then
        echo "python"; return 0
    fi
    if [[ "$first_line" =~ ^\#\! ]]; then
        echo "shell"; return 0
    fi

    # Rust: distinctive keywords + brace syntax
    if echo "$head" | grep -qE '^(fn |pub fn |use std::|impl |struct |enum |trait )' && \
       echo "$head" | grep -qE '\{'; then
        echo "rust"; return 0
    fi

    # Python
    if echo "$head" | grep -qE '^(import |from [a-zA-Z_]+ import|def [a-z_]+\(|class [A-Z])'; then
        echo "python"; return 0
    fi

    # TypeScript (check before JS — TS is a superset)
    if echo "$head" | grep -qE '(interface [A-Z]|: string|: number|: boolean|<[A-Z][a-zA-Z]*>)' && \
       echo "$head" | grep -qE '(const |let |import .* from)'; then
        echo "typescript"; return 0
    fi

    # JavaScript
    if echo "$head" | grep -qE '^(const |let |var |import |export |function )'; then
        echo "javascript"; return 0
    fi

    # TOML
    if echo "$head" | grep -qE '^\[\[?[a-zA-Z_][a-zA-Z0-9_.-]*\]?\]' && \
       echo "$head" | grep -qE '^[a-zA-Z_][a-zA-Z0-9_-]* *='; then
        echo "toml"; return 0
    fi

    # JSON
    local first_nonws
    first_nonws=$(printf '%s' "$head" | tr -d '[:space:]' | cut -c1)
    if [[ "$first_nonws" == '{' || "$first_nonws" == '[' ]]; then
        # Sanity: must contain quoted keys
        if echo "$head" | grep -qE '"[a-zA-Z_][a-zA-Z0-9_]*"[[:space:]]*:'; then
            echo "json"; return 0
        fi
    fi

    # YAML — document separator OR at least 2 top-level keys and 4 total key:value lines
    if echo "$head" | grep -qE '^---[[:space:]]*$'; then
        echo "yaml"; return 0
    fi
    local top_level_keys indented_keys
    top_level_keys=$(echo "$head" | grep -cE '^[a-zA-Z_][a-zA-Z0-9_-]*:([[:space:]]|$)' || true)
    indented_keys=$(echo "$head" | grep -cE '^[[:space:]]+[a-zA-Z_][a-zA-Z0-9_-]*:([[:space:]]|$)' || true)
    if [[ -n "$top_level_keys" && -n "$indented_keys" ]] && \
       (( top_level_keys >= 2 )) && (( top_level_keys + indented_keys >= 4 )); then
        echo "yaml"; return 0
    fi

    # Markdown
    if echo "$head" | grep -qE '^#{1,6} '; then
        echo "markdown"; return 0
    fi

    # INI/config
    if echo "$head" | grep -qE '^\[[a-zA-Z_]' && echo "$head" | grep -qE '^[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*='; then
        echo "config"; return 0
    fi

    echo "unknown"
    return 0
}

found=0
checked=0

echo "Scanning $INPUT_DIR for text files..."

while IFS= read -r -d '' f; do
    checked=$((checked + 1))
    if (( checked % 500 == 0 )); then
        echo "  scanned $checked files..."
    fi

    # Only interested in plausible text sizes
    size=$(stat -c '%s' "$f" 2>/dev/null || echo 0)
    (( size < 50 )) && continue
    (( size > 5242880 )) && continue  # 5MB max — larger is suspicious

    type=$(classify "$f") || continue
    [[ -z "$type" ]] && continue

    # Skip "unknown" unless it has meaningful content density
    if [[ "$type" == "unknown" ]]; then
        # Require at least a few lines of >20 chars
        line_count=$(head -c 4096 "$f" | awk 'length($0) > 20' | wc -l)
        (( line_count < 3 )) && continue
    fi

    basename_f=$(basename "$f")
    dest="$OUTPUT_DIR/$type/$basename_f"
    counter=1
    while [[ -e "$dest" ]]; do
        dest="$OUTPUT_DIR/$type/${basename_f%.*}_${counter}.${basename_f##*.}"
        counter=$((counter + 1))
    done
    cp "$f" "$dest"
    found=$((found + 1))
done < <(find "$INPUT_DIR" -type f \( -iname '*.txt' -o -iname '*.md' -o -iname '*.json' -o -iname '*.yaml' -o -iname '*.yml' -o -iname '*.toml' -o -iname '*.ini' -o -iname '*.conf' -o -iname '*.cfg' -o -iname '*.py' -o -iname '*.rs' -o -iname '*.js' -o -iname '*.ts' -o -iname '*.sh' \) -print0)

echo ""
echo "Scanned $checked files, classified $found."
echo "Output: $OUTPUT_DIR"
for d in "$OUTPUT_DIR"/*/; do
    [[ -d "$d" ]] || continue
    count=$(find "$d" -type f | wc -l)
    (( count > 0 )) && echo "  $(basename "$d"): $count"
done
