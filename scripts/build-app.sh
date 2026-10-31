#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

configuration="${1:-release}"
if [[ "$configuration" != debug && "$configuration" != release ]]; then
    print -u2 'Usage: build-app.sh [debug|release]'
    exit 2
fi

# Keep caches local so builds also work in restricted development environments.
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-module-cache"
swift build -c "$configuration" --disable-sandbox --cache-path "$PWD/.build/cache"
binary_dir="$(swift build -c "$configuration" --show-bin-path --disable-sandbox --cache-path "$PWD/.build/cache")"
app_dir="$PWD/dist/HocusFocus.app"
signing_identity="${HOCUSFOCUS_SIGNING_IDENTITY:--}"
mkdir -p "$PWD/.build" "$PWD/dist"
inputs="$(mktemp "$PWD/.build/package-inputs.XXXXXX")"
trap 'rm -f "$inputs"' EXIT
{
    print -r -- "$signing_identity"
    shasum -a 256 "$binary_dir/HocusFocusApp" "$binary_dir/BrandAssets" Resources/Info.plist Resources/Yabai-LICENSE.txt LICENSE
} > "$inputs"
stamp="$PWD/.build/packaged-inputs.sha256"
cp "$binary_dir/hocusfocus" "$PWD/dist/hocusfocus"
if [[ -f "$stamp" && -x "$app_dir/Contents/MacOS/HocusFocus" ]] &&
    cmp -s "$inputs" "$stamp" && codesign --verify --strict "$app_dir" >/dev/null 2>&1; then
    print "Build unchanged; keeping the signed app at $app_dir"
    exit 0
fi
if pgrep -u "$(id -u)" -x '^(HocusFocus|HocusFocusApp)$' >/dev/null; then
    print -u2 'The app changed but HocusFocus is running. Run just stop before rebuilding.'
    exit 1
fi
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
"$binary_dir/BrandAssets" "$PWD"
iconutil --convert icns --output "$app_dir/Contents/Resources/HocusFocus.icns" "$PWD/.build/branding/HocusFocus.iconset"
cp "$binary_dir/HocusFocusApp" "$app_dir/Contents/MacOS/HocusFocus"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
cp Resources/Yabai-LICENSE.txt "$app_dir/Contents/Resources/Yabai-LICENSE.txt"
cp LICENSE "$app_dir/Contents/Resources/LICENSE"
codesign --force --sign "$signing_identity" --identifier io.bitsugar.hocusfocus "$app_dir"
mv "$inputs" "$stamp"
print "Built $app_dir"
print "Built $PWD/dist/hocusfocus"
if [[ "$signing_identity" == - ]]; then
    print 'Ad-hoc signing: macOS may require Accessibility permission again after code changes.'
    print 'Set HOCUSFOCUS_SIGNING_IDENTITY to a code-signing certificate to preserve signing identity.'
fi
