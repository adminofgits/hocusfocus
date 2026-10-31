#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

# Run the real packaging script against fake tools, never a real app or signer.
fixture="$(mktemp -d "${TMPDIR:-/tmp}/hocusfocus-package.XXXXXX")"
fixture="${fixture:A}"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/scripts" "$fixture/Resources" "$fixture/bin" "$fixture/products"
cp scripts/build-app.sh "$fixture/scripts/"
cp Resources/Info.plist "$fixture/Resources/"
cp Resources/Yabai-LICENSE.txt "$fixture/Resources/"
cp LICENSE "$fixture/LICENSE"
print executable > "$fixture/products/HocusFocusApp"
print cli > "$fixture/products/hocusfocus"
chmod +x "$fixture/products/HocusFocusApp"
cat > "$fixture/products/BrandAssets" <<'SH'
#!/bin/zsh
mkdir -p "$1/.build/branding/HocusFocus.iconset"
SH
cat > "$fixture/bin/swift" <<'SH'
#!/bin/zsh
if [[ "$*" == *--show-bin-path* ]]; then print -r -- "$HOCUSFOCUS_TEST_PRODUCTS"; fi
exit 0
SH
cat > "$fixture/bin/pgrep" <<'SH'
#!/bin/zsh
exit 1
SH
cat > "$fixture/bin/iconutil" <<'SH'
#!/bin/zsh
while (( $# )); do
    if [[ "$1" == --output ]]; then print icon > "$2"; exit 0; fi
    shift
done
exit 1
SH
cat > "$fixture/bin/codesign" <<'SH'
#!/bin/zsh
if [[ "$1" == --verify ]]; then [[ -f "$argv[-1]/signed" ]]; exit $?; fi
print signed >> "$HOCUSFOCUS_TEST_SIGN_LOG"
print signature >> "$argv[-1]/Contents/MacOS/HocusFocus"
touch "$argv[-1]/signed"
SH
chmod +x "$fixture/products/BrandAssets" "$fixture/bin/"*
export HOCUSFOCUS_TEST_PRODUCTS="$fixture/products"
export HOCUSFOCUS_TEST_SIGN_LOG="$fixture/sign.log"
export HOCUSFOCUS_SIGNING_IDENTITY=-
export PATH="$fixture/bin:$PATH"

zsh "$fixture/scripts/build-app.sh" > "$fixture/first.log"
cmp -s Resources/Yabai-LICENSE.txt "$fixture/dist/HocusFocus.app/Contents/Resources/Yabai-LICENSE.txt"
cmp -s LICENSE "$fixture/dist/HocusFocus.app/Contents/Resources/LICENSE"
before="$(shasum -a 256 "$fixture/dist/HocusFocus.app/Contents/MacOS/HocusFocus")"
zsh "$fixture/scripts/build-app.sh" > "$fixture/second.log"
after="$(shasum -a 256 "$fixture/dist/HocusFocus.app/Contents/MacOS/HocusFocus")"
[[ "$before" == "$after" ]]
signs=("${(@f)$(< "$fixture/sign.log")}")
[[ ${#signs} == 1 ]]

print changed >> "$fixture/products/HocusFocusApp"
zsh "$fixture/scripts/build-app.sh" > "$fixture/changed.log"
signs=("${(@f)$(< "$fixture/sign.log")}")
[[ ${#signs} == 2 ]]

HOCUSFOCUS_SIGNING_IDENTITY='fixture certificate' zsh "$fixture/scripts/build-app.sh" > "$fixture/identity.log"
signs=("${(@f)$(< "$fixture/sign.log")}")
[[ ${#signs} == 3 ]]
print '3 packaging tests passed (unchanged signature, changed binary, and changed signing identity).'
