#!/usr/bin/env bash
# One-time setup: generates the Android project around the Dart sources and
# applies the manifest / Gradle changes needed for AdMob + Google Play Billing.
# Run from the neon_flow folder:  bash tools/setup_android.sh
set -euo pipefail
cd "$(dirname "$0")/.."

command -v flutter >/dev/null || { echo "Flutter SDK not found. Install from https://docs.flutter.dev/get-started/install"; exit 1; }

echo "==> Generating Android platform files"
flutter create --platforms=android --org com.pavan --project-name neon_flow .

# flutter create adds a template widget test that references a class we do not have.
rm -f test/widget_test.dart

echo "==> Fetching packages"
flutter pub get

echo "==> Patching AndroidManifest + Gradle"
python3 - <<'PY'
import glob, re, os

# ---- AndroidManifest.xml ---------------------------------------------------
mf = "android/app/src/main/AndroidManifest.xml"
s = open(mf).read()
TEST_APP_ID = "ca-app-pub-3940256099942544~3347511713"  # Google sample App ID
if "com.google.android.gms.ads.APPLICATION_ID" not in s:
    s = re.sub(r"(<application\b[^>]*>)",
               r'\1\n        <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="%s"/>' % TEST_APP_ID,
               s, count=1)
for perm in ("android.permission.INTERNET", "android.permission.VIBRATE",
             "com.google.android.gms.permission.AD_ID"):
    if perm not in s:
        s = s.replace("<application", '<uses-permission android:name="%s"/>\n    <application' % perm, 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="Neon Flow"', s, count=1)
open(mf, "w").write(s)

# ---- minSdk 23 (required by google_mobile_ads) ------------------------------
for f in glob.glob("android/app/build.gradle*"):
    g = open(f).read()
    g = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 23", g)
    g = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 23", g)
    open(f, "w").write(g)
print("Patched manifest and Gradle.")
PY

echo "==> Generating launcher icon (needs Pillow; skipped if missing)"
python3 tools/generate_icon.py || true

echo
echo "Done. Next:"
echo "  flutter run                      # run on a device / emulator"
echo "  flutter test                     # engine + level tests"
echo "  flutter build appbundle --release  # Play Store upload (.aab)"
