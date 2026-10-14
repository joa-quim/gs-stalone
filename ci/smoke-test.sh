#!/usr/bin/env bash
# Smoke-test a Ghostscript binary with the devices GMT's psconvert uses.
# Run from any directory, with no GS_LIB set: the binary must be self-contained.
# usage: ci/smoke-test.sh <path-to-gs>
set -euo pipefail

GS="$1"
HERE="$(cd "$(dirname "$0")" && pwd)"
PS="$HERE/smoke.ps"
WORK="$(mktemp -d)"
unset GS_LIB GS_FONTPATH || true

"$GS" --version

DEVS="$("$GS" -h)"
for d in bbox png16m pngalpha jpeg tiff24nc pdfwrite eps2write ps2write; do
    echo "$DEVS" | grep -qw "$d" || { echo "missing device: $d"; exit 1; }
done

"$GS" -q -dNOPAUSE -dBATCH -dSAFER -sDEVICE=bbox "$PS" 2> "$WORK/bbox.txt"
cat "$WORK/bbox.txt"
grep -q '%%HiResBoundingBox' "$WORK/bbox.txt"

"$GS" -q -dNOPAUSE -dBATCH -dSAFER -sDEVICE=png16m -r100 -o "$WORK/out.png" "$PS"
"$GS" -q -dNOPAUSE -dBATCH -dSAFER -sDEVICE=pdfwrite -o "$WORK/out.pdf" "$PS"
test -s "$WORK/out.png"
test -s "$WORK/out.pdf"

# PDF as INPUT: psconvert's path for PS with transparency (PS -> PDF -> raster).
"$GS" -q -dNOPAUSE -dBATCH -dSAFER -sDEVICE=png16m -r100 -o "$WORK/from_pdf.png" "$WORK/out.pdf"
test -s "$WORK/from_pdf.png"

# Fonts, ICC profiles and CMaps are compiled into the binary: nothing on disk.
for d in Font CMap; do
    n="$("$GS" -q -dNODISPLAY -dNOSAFER -c "0 (%rom%Resource/$d/*) { pop 1 add } 512 string filenameforall == quit")"
    echo "%rom%Resource/$d: $n files"
    [ "$n" -gt 0 ]
done
"$GS" -q -dNODISPLAY -dNOSAFER -c "(%rom%iccprofiles/default_rgb.icc) status { pop pop pop pop } { (no ICC) = 1 .quit } ifelse quit"

"$GS" -dNOPAUSE -dBATCH -dSAFER -sDEVICE=png16m -r60 -o "$WORK/fonts.png" "$HERE/fonts.ps" > "$WORK/fonts.log" 2>&1
cat "$WORK/fonts.log"
if grep -qi "substitut\|can't find\|cannot find" "$WORK/fonts.log"; then
    echo "font substitution: a standard font is missing"; exit 1
fi
test -s "$WORK/fonts.png"
ls -l "$WORK"
echo "smoke test OK"
