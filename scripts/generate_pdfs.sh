#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Generate PDFs for admin Markdown documents.

Usage:
  scripts/generate_pdfs.sh [--list] [--check-tools] [--root PATH] [--pdf-root PATH] [--engine ENGINE]

Options:
  --list         Print the Markdown -> PDF mappings without generating files.
  --check-tools  Validate required CLI tools and exit.
  --root PATH    Repository root to operate from. Defaults to the script's repo root.
  --pdf-root PATH
                 Directory where generated PDFs are written. Defaults to <repo>/admin_pdfs.
  --engine NAME  PDF engine to pass to pandoc. Defaults to xelatex.
  -h, --help     Show this help message.
EOF
}

mode="generate"
engine="${PDF_ENGINE:-xelatex}"
root=""
pdf_root=""
pandoc_bin="${PANDOC_BIN:-pandoc}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --list)
      mode="list"
      ;;
    --check-tools)
      mode="check-tools"
      ;;
    --root)
      root="$2"
      shift
      ;;
    --engine)
      engine="$2"
      shift
      ;;
    --pdf-root)
      pdf_root="$2"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [[ -z "$root" ]]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  root="$(cd "$script_dir/.." && pwd)"
fi

if [[ -z "$pdf_root" ]]; then
  pdf_root="${PDF_ROOT:-$root/admin_pdfs}"
fi

admin_dir="$root/admin"
if [[ ! -d "$admin_dir" ]]; then
  echo "Admin directory not found: $admin_dir" >&2
  exit 1
fi

if [[ "$mode" == "generate" ]]; then
  mkdir -p "$pdf_root"
fi

if [[ "$mode" == "generate" || "$mode" == "check-tools" ]]; then
  if ! command -v "$pandoc_bin" >/dev/null 2>&1; then
    echo "Missing required tool: $pandoc_bin" >&2
    exit 1
  fi
  if ! command -v "$engine" >/dev/null 2>&1; then
    echo "Missing required PDF engine: $engine" >&2
    exit 1
  fi
fi

if [[ "$mode" == "check-tools" ]]; then
  echo "pandoc: $(command -v "$pandoc_bin")"
  echo "$engine: $(command -v "$engine")"
  exit 0
fi

sources=()
while IFS= read -r src; do
  sources+=("$src")
done < <(find "$admin_dir" -type f -name '*.md' ! -name 'README.md' | sort)

if [[ ${#sources[@]} -eq 0 ]]; then
  echo "No eligible Markdown files found under $admin_dir"
  exit 0
fi

for src in "${sources[@]}"; do
  rel_src_admin="${src#"$admin_dir"/}"
  pdf="$pdf_root/${rel_src_admin%.md}.pdf"
  rel_src="${src#"$root"/}"
  rel_pdf="${pdf#"$root"/}"

  if [[ "$mode" == "list" ]]; then
    printf '%s -> %s\n' "$rel_src" "$rel_pdf"
    continue
  fi

  echo "Generating $rel_pdf"
  mkdir -p "$(dirname "$pdf")"
  "$pandoc_bin" \
    "$src" \
    --from=gfm \
    --standalone \
    --pdf-engine="$engine" \
    -V geometry:margin=1in \
    -o "$pdf"
done



