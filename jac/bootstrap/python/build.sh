#!/bin/sh
# The third-party libraries JacPython links (zlib, bzip2, zstd, sqlite, xz,
# libffi, mpdecimal, expat and OpenSSL), with their headers, notices and the CA
# bundle. Every C translation and archive uses the pinned Zig. The runtime
# itself is built by build_jacpython.zig.
#
#   build.sh <platform> <work> <zig>
#
# Only on the platform itself: another platform's build lowers only its
# native object, which needs none of these.
set -eu
platform=$1
work=$2
zig=$3
jobs=${JAC_PYTHON_JOBS:-4}
case "$jobs" in ''|*[!0-9]*|0) echo 'JAC_PYTHON_JOBS must be a positive integer' >&2; exit 1;; esac
case "$platform" in
    linux-x86_64) target=x86_64-linux-gnu.2.17; openssl_target=linux-x86_64 ;;
    linux-aarch64) target=aarch64-linux-gnu.2.17; openssl_target=linux-aarch64 ;;
    macos-x86_64) target=x86_64-macos.12.0; openssl_target=darwin64-x86_64-cc ;;
    macos-aarch64) target=aarch64-macos.11.0; openssl_target=darwin64-arm64-cc ;;
    *) echo "Unsupported Python release platform: $platform" >&2; exit 1 ;;
esac
for tool in make perl; do
    command -v "$tool" >/dev/null || { echo "The vendored libraries' build requires $tool" >&2; exit 1; }
done
deps=$work/deps
src=$work/src
mkdir -p "$deps/lib" "$deps/include" "$work/bin" "$work/logs"
export JAC_PYTHON_ZIG="$zig" JAC_PYTHON_TARGET="$target"
case "$platform" in
    macos-*)
        JAC_PYTHON_SDK=$(xcrun --sdk macosx --show-sdk-path)
        # Framework stubs reexport libraries from the SDK, including libobjc.
        # Zig needs the SDK library search path as well as header/framework paths.
        export JAC_PYTHON_SDK
        case "$platform" in
            macos-x86_64) export MACOSX_DEPLOYMENT_TARGET=12.0 ;;
            macos-aarch64) export MACOSX_DEPLOYMENT_TARGET=11.0 ;;
        esac
        ;;
    *) unset JAC_PYTHON_SDK || true ;;
esac
cat > "$work/bin/cc" <<'SH'
#!/bin/sh
if [ -n "${JAC_PYTHON_SDK:-}" ]; then
    exec "$JAC_PYTHON_ZIG" cc -target "$JAC_PYTHON_TARGET" -isysroot "$JAC_PYTHON_SDK" -isystem "$JAC_PYTHON_SDK/usr/include" -L "$JAC_PYTHON_SDK/usr/lib" -F "$JAC_PYTHON_SDK/System/Library/Frameworks" -Wno-unused-command-line-argument "$@"
fi
exec "$JAC_PYTHON_ZIG" cc -target "$JAC_PYTHON_TARGET" -Wno-unused-command-line-argument "$@"
SH
cat > "$work/bin/ar" <<'SH'
#!/bin/sh
exec "$JAC_PYTHON_ZIG" ar "$@"
SH
cat > "$work/bin/ranlib" <<'SH'
#!/bin/sh
exec "$JAC_PYTHON_ZIG" ranlib "$@"
SH
chmod +x "$work/bin/cc" "$work/bin/ar" "$work/bin/ranlib"
export CC="$work/bin/cc" AR="$work/bin/ar" RANLIB="$work/bin/ranlib"
# The completed SDK is cached separately. Keep transient C compilation caches
# in this build tree so dependency objects cannot exhaust release-runner disks.
export ZIG_LOCAL_CACHE_DIR="$work/cc-cache" ZIG_GLOBAL_CACHE_DIR="$work/cc-cache"
export SOURCE_DATE_EPOCH=0
# Zig's tar extractor does not preserve mtimes. Equalize the released source
# inputs so make uses the shipped generated files instead of invoking Autotools.
TZ=UTC0 find "$src" -exec touch -t 200001010000.00 {} +
export CFLAGS='-O2 -fPIC' CPPFLAGS="-I$deps/include" LDFLAGS="-L$deps/lib"
# Do not discover libraries from the runner's package manager.
export PKG_CONFIG=false PKG_CONFIG_PATH= PKG_CONFIG_LIBDIR="$deps/lib/pkgconfig"
unset CXXFLAGS CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH LD_LIBRARY_PATH DYLD_LIBRARY_PATH || true

step() {
    label=$1; shift
    echo "build-python: $label"
    ( "$@" ) > "$work/logs/$label.log" 2>&1
    rm -rf "$work/cc-cache"
    case "$label" in
        zlib|bzip2|zstd|sqlite|xz|libffi|mpdecimal|expat|openssl)
            rm -rf "$src/$label"
            ;;
    esac
}
trap 'result=$?; if [ "$result" -ne 0 ] && [ -n "${label:-}" ]; then tail -80 "$work/logs/$label.log" >&2; fi' EXIT
zlib() {
    cd "$src/zlib"
    ./configure --prefix="$deps" --static
    make -j"$jobs"
    make install
}
bzip2() {
    cd "$src/bzip2"
    make -j"$jobs" libbz2.a CC="$CC" AR="$AR" RANLIB="$RANLIB" CFLAGS="$CFLAGS"
    cp libbz2.a "$deps/lib/"
    cp bzlib.h "$deps/include/"
}
zstd() {
    cd "$src/zstd"
    make -C lib -j"$jobs" libzstd.a ZSTD_LEGACY_SUPPORT=0
    cp lib/libzstd.a "$deps/lib/"
    cp lib/zstd.h lib/zdict.h lib/zstd_errors.h "$deps/include/"
}
sqlite() {
    cd "$src/sqlite"
    "$CC" $CFLAGS -DSQLITE_THREADSAFE=1 -DSQLITE_ENABLE_COLUMN_METADATA \
        -DSQLITE_ENABLE_FTS5 -DSQLITE_ENABLE_RTREE -DSQLITE_ENABLE_MATH_FUNCTIONS \
        -c sqlite3.c -o sqlite3.o
    "$AR" rcs "$deps/lib/libsqlite3.a" sqlite3.o
    cp sqlite3.h sqlite3ext.h "$deps/include/"
}
xz() {
    cd "$src/xz"
    ./configure --prefix="$deps" --libdir="$deps/lib" --disable-shared \
        --disable-doc --disable-nls --disable-xz --disable-xzdec \
        --disable-lzmadec --disable-lzmainfo --disable-lzma-links --disable-scripts
    make -j"$jobs"
    make install
}
libffi() {
    cd "$src/libffi"
    ./configure --prefix="$deps" --libdir="$deps/lib" --disable-shared \
        --disable-docs --disable-multi-os-directory
    make -j"$jobs"
    make install
}
mpdecimal() {
    cd "$src/mpdecimal"
    ./configure --prefix="$deps" --libdir="$deps/lib" --disable-shared --disable-cxx
    make -j"$jobs"
    make install
}
expat() {
    cd "$src/expat"
    ./configure --prefix="$deps" --libdir="$deps/lib" --disable-shared \
        --without-docbook --without-examples --without-tests
    make -j"$jobs"
    make install
}
openssl() {
    cd "$src/openssl"
    perl Configure "$openssl_target" --prefix="$deps" --libdir=lib \
        no-shared no-tests no-docs no-apps no-asm -fPIC
    make -j"$jobs" build_libs
    make install_dev
}
# Preserve notices before discarding each dependency's installed build tree.
mkdir -p "$work/python/licenses"
find "$src" -type f \( -iname 'LICENSE*' -o -iname 'COPYING*' -o -iname 'Copyright*' \) |
while IFS= read -r notice; do
    relative=${notice#"$src/"}
    mkdir -p "$work/python/licenses/$(dirname "$relative")"
    cp "$notice" "$work/python/licenses/$relative"
done
step zlib zlib
step bzip2 bzip2
step zstd zstd
step sqlite sqlite
step xz xz
step libffi libffi
step mpdecimal mpdecimal
step expat expat
step openssl openssl
mkdir -p "$work/python/build/lib" "$work/python/licenses"
cp "$deps/lib/"*.a "$work/python/build/lib/"
# The JacPython build links these archives and headers and ships them in
# python/build, with the notices and the CA bundle.
cp -R "$deps/include" "$work/python/build/include"
cp "$src/certifi/certifi/cacert.pem" "$work/python/build/cacert.pem"
echo "build-python: vendored libraries for $platform ready"
