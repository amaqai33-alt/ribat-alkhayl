#!/bin/bash
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODELS="$ROOT/ios/HorseHealth/Data/Models"
IOS="$ROOT/ios/HorseHealth/Features/Gait"
DATA="$ROOT/ios/HorseHealth/Data"
CAM="$ROOT/ios/HorseHealth/Core/Camera"
PBX="$ROOT/ios/HorseHealth.xcodeproj/project.pbxproj"

echo ""
echo "=== فحص القسم ٢٠ — شاشة النتيجة ==="

missing=0

if [[ -f "$IOS/GaitResultView.swift" ]]; then
  echo "  ✓ GaitResultView.swift"
else
  echo "  ✗ GaitResultView.swift — غير موجود"
  missing=$((missing + 1))
fi

if grep -q "headlineText" "$MODELS/GaitDeviation.swift" 2>/dev/null; then
  echo "  ✓ «تغيّr / لا تغيّr» (headlineText)"
else
  echo "  ✗ headlineText — غير موجود"
  missing=$((missing + 1))
fi

if grep -q "medicalDisclaimer" "$MODELS/GaitDeviation.swift" 2>/dev/null; then
  echo "  ✓ إخلاء مسؤولية — ليس تشخيصاً"
else
  echo "  ✗ medicalDisclaimer — غير موجود"
  missing=$((missing + 1))
fi

if grep -q "loadLatestDeviation" "$DATA/GaitCaptureStore.swift" 2>/dev/null; then
  echo "  ✓ loadLatestDeviation"
else
  echo "  ✗ loadLatestDeviation — غير موجود"
  missing=$((missing + 1))
fi

if grep -q "GaitLatestResultView" "$IOS/PermissionsSetupView.swift" 2>/dev/null; then
  echo "  ✓ رابط «نتيجة آخر فحص»"
else
  echo "  ✗ GaitLatestResultView — غير مربوط"
  missing=$((missing + 1))
fi

if grep -q "deviationResultSheet" "$IOS/CameraPreviewView.swift" 2>/dev/null; then
  echo "  ✓ شاشة النتيجة بعد التسجيل"
else
  echo "  ✗ deviationResultSheet — غير مربوط"
  missing=$((missing + 1))
fi

if grep -q "GaitResultView" "$IOS/GaitDeviationView.swift" 2>/dev/null; then
  echo "  ✓ رابط من درجة الانحراف"
else
  echo "  ✗ GaitResultView — غير مربوط"
  missing=$((missing + 1))
fi

if grep -q "GaitResultView.swift in Sources" "$PBX" 2>/dev/null; then
  echo "  ✓ الملفات في Xcode project"
else
  echo "  ✗ pbxproj — ملفات القسم 20 غير مضافة"
  missing=$((missing + 1))
fi

if command -v xcodebuild >/dev/null 2>&1; then
  echo ""
  echo "  → بناء Xcode (Simulator)…"
  if xcodebuild \
    -project "$ROOT/ios/HorseHealth.xcodeproj" \
    -scheme HorseHealth \
    -destination 'generic/platform=iOS Simulator' \
    -quiet \
    build 2>/dev/null; then
    echo "  ✓ Xcode build ناجح"
  else
    echo "  ✗ Xcode build فشل — افتح المشروع و⌘B"
    missing=$((missing + 1))
  fi
else
  echo "  ⚠ xcodebuild غير متاح — تحقق يدوياً بـ ⌘B"
fi

echo ""
if [[ "$missing" -gt 0 ]]; then
  echo ">>> القسم ٢٠ غير مكتمل — $missing عنصر ناقص"
  exit 1
fi

echo ">>> القسم ٢٠ مكتمل ✓ — جاهز للقسم ٢١ (وضع الهرولة)"
