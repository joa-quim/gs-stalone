#!/usr/bin/env bash
# Build Ghostscript as a small gs executable plus the shared libgs (PostScript
# interpreter only, no PDF/PCL/XPS
# readers), packed as <outdir>/gs-<version>-<platform>.tar.gz.
#
# Every third-party library (zlib, libpng, jpeg, freetype, lcms2, tiff, ...) is
# taken from the source tree and linked in; COMPILE_INITS bakes Resource/ and
# lib/ into libgs, so the result needs no GS_LIB and no shared libraries
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

# Shared build only: sobin/libgs.* (what GMT.jl ccalls) and sobin/gsc, a small
# gs executable linked to that same libgs.
make -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu)" so

STAGE="$SRC/_stage"
rm -rf "$STAGE"
mkdir -p "$STAGE/bin" "$STAGE/share/licenses/ghostscript"
cp LICENSE "$STAGE/share/licenses/ghostscript/"
cp sobin/gsc "$STAGE/bin/gs"
# The versioned real file (libgs.so.10.09 / libgs.10.09.dylib); the others are symlinks.
REAL="$(find sobin -maxdepth 1 -type f -name 'libgs*' | head -1)"
[ -n "$REAL" ] || { echo "no libgs in sobin"; ls -l sobin; exit 1; }

# libgs sits next to gs, which finds it there wherever the folder lands.
if [ "$(uname)" = "Darwin" ]; then
    LIB="$STAGE/bin/libgs.dylib"
    cp "$REAL" "$LIB"
    OLD="$(otool -L "$STAGE/bin/gs" | awk '/libgs/ {print $1}')"
    install_name_tool -id "@rpath/libgs.dylib" "$LIB"
    install_name_tool -change "$OLD" "@rpath/libgs.dylib" "$STAGE/bin/gs"
    install_name_tool -add_rpath "@executable_path" "$STAGE/bin/gs"
    strip -x "$STAGE/bin/gs" "$LIB"
    codesign --force -s - "$LIB" "$STAGE/bin/gs"
    otool -L "$STAGE/bin/gs" "$LIB"
else
    LIB="$STAGE/bin/libgs.so"
    cp "$REAL" "$LIB"
    OLD="$(patchelf --print-needed "$STAGE/bin/gs" | grep libgs)"
    patchelf --set-soname libgs.so "$LIB"
    patchelf --replace-needed "$OLD" libgs.so --set-rpath '$ORIGIN' "$STAGE/bin/gs"
    strip "$STAGE/bin/gs"
    strip --strip-unneeded "$LIB"
    ldd "$STAGE/bin/gs" "$LIB"
fi

bash "$SRC/ci/smoke-test.sh" "$STAGE/bin/gs"

mkdir -p "$OUTDIR"
TARBALL="$OUTDIR/gs-$VER-$PLAT.tar.gz"
tar -C "$STAGE" -czf "$TARBALL" .
echo "Wrote $TARBALL"
