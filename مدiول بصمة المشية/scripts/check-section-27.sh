#!/usr/bin/env bash
# القسم ٢٧ — DTW (مقارنة نمط المشية)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS="$ROOT/ios"
PBX="$IOS/HorseHealth.xcodeproj/project.pbxproj"
MISSING=0

check() {
  if [[ -f "$1" ]]; then
    echo "  ✓ $(basename "$1")"
  else
    echo "  ✗ $(basename "$1")"
    MISSING=$((MISSING + 1))
  fi
}

echo ""
echo "=== فحص القسم ٢٧ — DTW نمط المشية ==="

for f in \
  "$IOS/HorseHealth/Core/ML/GaitDTWEngine.swift" \
  "$IOS/HorseHealth/Core/ML/GaitPatternExtractor.swift" \
  "$IOS/HorseHealth/Core/ML/GaitPatternMatcher.swift" \
  "$IOS/HorseHealth/Data/Models/GaitPatternTemplate.swift"
do
  check "$f"
done

for token in GaitDTWEngine GaitPatternExtractor GaitPatternMatcher GaitPatternTemplate baseline_pattern; do
  if grep -q "$token" "$PBX" 2>/dev/null; then
    echo "  ✓ $token في Xcode"
  else
    echo "  ✗ $token غير موجود في Xcode"
    MISSING=$((MISSING + 1))
  fi
done

if grep -q "patternMatch" "$IOS/HorseHealth/Core/ML/GaitBaselineDeviationScorer.swift"; then
  echo "  ✓ دمج DTW في deviation scorer"
else
  echo "  ✗ دمج DTW في deviation scorer"
  MISSING=$((MISSING + 1))
fi

if grep -q "rebuildPatternTemplate" "$IOS/HorseHealth/Data/GaitBaselineStore.swift"; then
  echo "  ✓ baseline_pattern.json عند حساب baseline"
else
  echo "  ✗ baseline_pattern.json"
  MISSING=$((MISSING + 1))
fi

if grep -q "patternMatchPercent" "$IOS/HorseHealth/Data/Models/GaitDeviation.swift"; then
  echo "  ✓ حقول DTW في GaitDeviationResult"
else
  echo "  ✗ حقols DTW"
  MISSING=$((MISSING + 1))
fi

echo ""
echo "  → بناء Xcode (Simulator)…"
if (cd "$IOS" && xcodebuild -scheme HorseHealth -destination 'platform=iOS Simulator,name=iPhone 17' build -quiet); then
  echo "  ✓ Xcode build ناجح"
else
  echo "  ✗ Xcode build فشل"
  MISSING=$((MISSING + 1))
fi

echo ""
if [[ "$MISSING" -eq 0 ]]; then
  echo ">>> القسم ٢٧ مكتمل ✓ — DTW مُدمج"
  exit 0
fi
echo ">>> القسم ٢٧ غير مكتمل — $MISSING عنصر ناقص"
exit 1
