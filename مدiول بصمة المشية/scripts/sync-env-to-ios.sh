#!/bin/bash
# ينقل SUPABASE_URL و SUPABASE_ANON_KEY من .env.local إلى SupabaseConfig.swift
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/.env.local"
CONFIG="$ROOT/ios/HorseHealth/Config/SupabaseConfig.swift"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "✗ .env.local غير موجود — انسخ من .env.example"
  exit 1
fi

read_env() {
  local key="$1"
  grep -E "^${key}=" "$ENV_FILE" | head -1 | cut -d= -f2- | sed 's/^["'\'']//;s/["'\'']$//'
}

SUPABASE_URL="$(read_env SUPABASE_URL)"
SUPABASE_ANON_KEY="$(read_env SUPABASE_ANON_KEY)"

if [[ -z "$SUPABASE_URL" || -z "$SUPABASE_ANON_KEY" ]]; then
  echo "✗ SUPABASE_URL أو SUPABASE_ANON_KEY فارغ في .env.local"
  exit 1
fi

python3 - "$CONFIG" "$SUPABASE_URL" "$SUPABASE_ANON_KEY" <<'PY'
import re, sys
path, url, key = sys.argv[1:4]
text = open(path, encoding="utf-8").read()
text = re.sub(
    r'(private static let configuredURL = )".*?"( // SYNC:SUPABASE_URL)',
    rf'\1"{url}"\2',
    text,
    count=1,
)
text = re.sub(
    r'(private static let configuredAnonKey = )".*?"( // SYNC:SUPABASE_ANON_KEY)',
    rf'\1"{key}"\2',
    text,
    count=1,
)
open(path, "w", encoding="utf-8").write(text)
PY

echo "✓ تم تحديث SupabaseConfig.swift من .env.local"
echo "  URL: ${SUPABASE_URL:0:40}…"
