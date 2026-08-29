#!/bin/bash
# Slice a 1024×1024 master into the ten PNGs macOS wants, and fill in the
# filenames in AppIcon.appiconset/Contents.json.
#
#   Scripts/make_app_icon.sh path/to/icon-1024.png
#
# The master must be square and at least 1024×1024; anything larger is
# downsampled. Uses sips, so there is nothing to install.
set -euo pipefail

master=${1:-}
if [[ -z $master || ! -f $master ]]; then
    echo "usage: $0 <icon-1024.png>" >&2
    exit 2
fi

root=$(cd "$(dirname "$0")/.." && pwd)
iconset="$root/App/Sources/Assets.xcassets/AppIcon.appiconset"

width=$(sips -g pixelWidth "$master" | awk '/pixelWidth/ {print $2}')
height=$(sips -g pixelHeight "$master" | awk '/pixelHeight/ {print $2}')
if [[ $width != "$height" ]]; then
    echo "error: master is ${width}×${height}; it must be square" >&2
    exit 1
fi
if (( width < 1024 )); then
    echo "error: master is ${width}px; 1024 is the minimum" >&2
    exit 1
fi

for pt in 16 32 128 256 512; do
    for scale in 1 2; do
        px=$(( pt * scale ))
        out="$iconset/AppIcon-${pt}@${scale}x.png"
        sips -z "$px" "$px" "$master" --out "$out" >/dev/null
        echo "  ${px}×${px}  $(basename "$out")"
    done
done

python3 - "$iconset" <<'PY'
import json, pathlib, sys
iconset = pathlib.Path(sys.argv[1])
contents = json.loads((iconset / "Contents.json").read_text())
for image in contents["images"]:
    pt = int(image["size"].split("x")[0])
    scale = image["scale"].rstrip("x")
    image["filename"] = f"AppIcon-{pt}@{scale}x.png"
(iconset / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
print(f"wrote filenames for {len(contents['images'])} slots")
PY
