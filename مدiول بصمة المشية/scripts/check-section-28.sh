#!/usr/bin/env bash
# القسم ٢٨ — pgvector embeddings
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS="$ROOT/ios"
PBX="$IOS/HorseHealth.xcodeproj/project.pbxproj"
MISSING=0

check() {
  if [[ -f "$1" ]]; then echo "  ✓ $(basename "$1")"; else echo "  ✗ $(basename "$1")"; MISSING=$((MISSING+1)); fi
}

echo ""
echo "=== فحص القسم ٢٨ — pgvector ==="
check "$ROOT/supabase/pgvector-migration.sql"
check "$IOS/HorseHealth/Data/Models/GaitFingerprintEmbedding.swift"
check "$IOS/HorseHealth/Core/ML/GaitEmbeddingBuilder.swift"
check "$IOS/HorseHealth/Core/ML/GaitEmbeddingComparator.swift"

for token in GaitFingerprintEmbedding GaitEmbeddingBuilder gait_baseline_embeddings gait_session_embeddings baseline_embedding.json; do
  if grep -rq "$token" "$IOS/HorseHealth" 2>/dev/null || grep -q "$token" "$ROOT/supabase/pgvector-migration.sql" 2>/dev/null; then
    echo "  ✓ $token"
  else
    echo "  ✗ $token"; MISSING=$((MISSING+1))
  fi
done

echo ""
echo "  → بناء Xcode…"
if (cd "$IOS" && xcodebuild -scheme HorseHealth -destination 'platform=iOS Simulator,name=iPhone 17' build -quiet); then
  echo "  ✓ Xcode build ناجح"
else
  echo "  ✗ Xcode build فشل"; MISSING=$((MISSING+1))
fi

echo ""
if [[ "$MISSING" -eq 0 ]]; then echo ">>> القسم ٢٨ مكتمل ✓ — pgvector"; exit 0; fi
echo ">>> القسم ٢٨ غير مكتمل — $MISSING عنصر ناقص"; exit 1
