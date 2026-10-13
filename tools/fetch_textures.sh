#!/usr/bin/env bash
# Downloads the CC0 photo scans (ambientCG, 1K) the Blender material recipes use for surface detail
# into art/textures_src/ (not committed). Sources are listed in CREDITS.md.
set -euo pipefail
cd "$(dirname "$0")/.."
dest=art/textures_src
mkdir -p "$dest"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for id in Metal009 PaintedMetal013 Metal021 MetalPlates013 DiamondPlate008A Concrete034; do
	if [[ -f "$dest/${id}_Color.jpg" ]]; then continue; fi
	mkdir -p "$tmp/$id"
	curl -sSLf -o "$tmp/$id/$id.zip" "https://ambientcg.com/get?file=${id}_1K-JPG.zip"
	unzip -q -o "$tmp/$id/$id.zip" -d "$tmp/$id"
	cp "$tmp/$id/${id}_1K-JPG_Color.jpg" "$dest/${id}_Color.jpg"
	echo "fetched $id"
done
