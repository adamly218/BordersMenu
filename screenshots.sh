#!/bin/bash
# Takes the README screenshots with the installed app's demo mode.
# Needs Screen Recording permission for the terminal that runs it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP=/Applications/BordersMenu.app/Contents/MacOS/BordersMenu
OUT="$ROOT/docs"
mkdir -p "$OUT"

# Helper that prints "layer id x y w h" for each on-screen window of a process.
# Compiled once up front: compiling on every call is slow enough to miss the demo.
LISTER="$(mktemp -d)/windows"
trap 'rm -rf "$(dirname "$LISTER")"' EXIT
swiftc -O -o "$LISTER" - <<'EOF'
import CoreGraphics
let pid = Int32(CommandLine.arguments[1])!
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
for w in list where (w[kCGWindowOwnerPID as String] as? Int32) == pid {
    let b = w[kCGWindowBounds as String] as! [String: Double]
    print(w[kCGWindowLayer as String] as! Int, w[kCGWindowNumber as String] as! Int,
          Int(b["X"]!), Int(b["Y"]!), Int(b["Width"]!), Int(b["Height"]!))
}
EOF

windows() { "$LISTER" "$1"; }

shoot() {
    local mode=$1 file=$2
    "$APP" --demo "$mode" & local pid=$!
    sleep 2.5
    local list=""
    for _ in 1 2 3 4 5; do
        list=$(windows "$pid" | sort -rn)
        # Menus are at window layer 101; the window demo's focused window is under 800 pt wide.
        if [ "$mode" = window ] && echo "$list" | awk '$5 < 800' | grep -q .; then break; fi
        if [ "$mode" != window ] && echo "$list" | grep -q '^101 '; then break; fi
        sleep 0.5
    done
    if [ "$mode" = window ]; then
        # Crop around the 520x300 focused window; the margin stays inside the 900x600 backdrop.
        read -r _ _ x y w h < <(echo "$list" | awk '$5 < 800' | head -1)
        local rx=$((x - 70)) ry=$((y - 60)) rw=$((w + 140)) rh=$((h + 120))
        # Never capture outside the backdrop, or the shot would show whatever is behind it.
        local bx by bw bh
        read -r _ _ bx by bw bh < <(echo "$list" | awk '$5 >= 800' | head -1) || true
        if [ -z "${bw:-}" ] || [ "$rx" -lt "$bx" ] || [ "$ry" -lt "$by" ] ||
           [ $((rx + rw)) -gt $((bx + bw)) ] || [ $((ry + rh)) -gt $((by + bh)) ]; then
            echo "Backdrop not on screen; skipped $file" >&2
            kill "$pid" 2>/dev/null || true
            return 1
        fi
        screencapture -x -R"$rx,$ry,$rw,$rh" "$OUT/$file"
    else
        read -r _ id _ < <(echo "$list" | head -1)
        screencapture -x -l"$id" "$OUT/$file"
    fi
    wait "$pid" 2>/dev/null || true
}

# The first capture after a rebuild sometimes fails, so try each shot up to three times.
for shot in "menu menu.png" "colors colors.png" "window border.png"; do
    for attempt in 1 2 3; do
        # shellcheck disable=SC2086
        shoot $shot && break
        [ "$attempt" = 3 ] && { echo "Failed: $shot" >&2; exit 1; }
    done
done
echo "Saved to $OUT"
