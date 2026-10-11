#!/usr/bin/env bash
# Build a self-contained Ghostscript (PostScript interpreter only, no PDF/PCL/XPS
# readers) and pack it as <outdir>/gs-<version>-<platform>.tar.gz.
#
# Every third-party library (zlib, libpng, jpeg, freetype, lcms2, tiff, ...) is
# taken from the source tree and linked in; COMPILE_INITS bakes Resource/ and
# lib/ into the binary, so the result needs no GS_LIB and no shared libraries
# beyond the C runtime.
#
# usage: ci/build-unix.sh <platform-tag> <outdir>
set -euo pipefail

PLAT="$1"
OUTDIR="$2"
SRC="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SRC"

VER="$(sed -n 's/^GS_VERSION_MAJOR=//p' base/version.mak).$(sed -n 's/^GS_VERSION_MINOR=//p' base/version.mak).$(sed -n 's/^GS_VERSION_PATCH=//p' base/version.mak)"
echo "Ghostscript $VER for $PLAT"

NOCONFIGURE=1 ./autogen.sh

./configure \
    --without-pdf --without-pcl --without-xps --without-gpdl --without-urf \
    --without-extract-dir --without-tesseract \
    --without-x --disable-cups --disable-gtk --disable-fontconfig --disable-dbus \
    --without-libidn --without-libpaper --without-ijs

make -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu)"

STAGE="$SRC/_stage"
rm -rf "$STAGE"
mkdir -p "$STAGE/bin" "$STAGE/share/licenses/ghostscript"
cp bin/gs "$STAGE/bin/gs"
strip "$STAGE/bin/gs" || true
cp LICENSE "$STAGE/share/licenses/ghostscript/"

echo "--- shared-library dependencies"
if [ "$(uname)" = "Darwin" ]; then
    otool -L "$STAGE/bin/gs"
else
    ldd "$STAGE/bin/gs" || true
fi

bash "$SRC/ci/smoke-test.sh" "$STAGE/bin/gs"

mkdir -p "$OUTDIR"
TARBALL="$OUTDIR/gs-$VER-$PLAT.tar.gz"
tar -C "$STAGE" -czf "$TARBALL" .
echo "Wrote $TARBALL"
