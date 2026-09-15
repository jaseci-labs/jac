#!/bin/sh
# Native release builds: every C translation and archive uses the pinned Zig.
set -eu
platform=$1
work=$2
zig=$3
recipe=$4
host=${5:-}
root=$6
mode=$7
case "$mode:$host" in
    host:|jacpython:?*) ;;
    *) echo "Invalid Python build mode/host: $mode" >&2; exit 1 ;;
esac
jobs=${JAC_PYTHON_JOBS:-4}
case "$jobs" in ''|*[!0-9]*|0) echo 'JAC_PYTHON_JOBS must be a positive integer' >&2; exit 1;; esac
case "$platform" in
    linux-x86_64) target=x86_64-linux-gnu.2.17; openssl_target=linux-x86_64 ;;
    linux-aarch64) target=aarch64-linux-gnu.2.17; openssl_target=linux-aarch64 ;;
    macos-x86_64) target=x86_64-macos.12.0; openssl_target=darwin64-x86_64-cc ;;
    macos-aarch64) target=aarch64-macos.11.0; openssl_target=darwin64-arm64-cc ;;
    *) echo "Unsupported Python release platform: $platform" >&2; exit 1 ;;
esac
for tool in make perl patch; do
    command -v "$tool" >/dev/null || { echo "Source Python builds require $tool" >&2; exit 1; }
done
prefix=$work/python/install
deps=$work/deps
src=$work/src
mkdir -p "$prefix" "$deps/lib" "$deps/include" "$work/bin" "$work/logs"
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
cpython() {
    cd "$src/cpython"
    if [ -n "$host" ]; then
        patch -f -F0 -p1 -i "$recipe/compiler-bridge.patch"
        cp "$recipe/compiler_bridge.c" Python/jac_compile.c
        cp "$recipe/compiler_bridge.h" Python/jac_compile.h
        cp "$recipe/compiler_runtime.c" Python/jac_runtime.c
        cp "$recipe/object_api.c" Python/jac_objects.c
        cp "$recipe/binding_api.c" Python/jac_bindings.c
        cp "$recipe/evaluator_refs.c" Python/jac_evaluator_refs.c
        cp "$recipe/evaluator_refs.h" Python/evaluator_refs.h
        cp "$recipe/evaluator_frames.c" Python/jac_evaluator_frames.c
        cp "$recipe/evaluator_frames.h" Python/evaluator_frames.h
        cp "$recipe/evaluator_objects.c" Python/jac_evaluator_objects.c
        cp "$recipe/evaluator_objects.h" Python/evaluator_objects.h
        cp "$recipe/evaluator_binding.c" Python/jac_evaluator_binding.c
        cp "$recipe/evaluator_binding.h" Python/evaluator_binding.h
        cp "$recipe/evaluator_recursion.c" Python/jac_evaluator_recursion.c
        cp "$recipe/evaluator_recursion.h" Python/evaluator_recursion.h
        cp "$recipe/evaluator_metadata.c" Python/jac_evaluator_metadata.c
        cp "$recipe/evaluator_metadata.h" Python/evaluator_metadata.h
        cp "$recipe/evaluator_entry.c" Python/jac_evaluator_entry.c
        cp "$recipe/evaluator_entry.h" Python/evaluator_entry.h
        cp "$recipe/evaluator_activation.c" Python/jac_evaluator_activation.c
        cp "$recipe/evaluator_activation.h" Python/evaluator_activation.h
        cp "$recipe/evaluator_operations.h" Python/evaluator_operations.h
        cp "$recipe/generated/evaluator_scratch.h" Python/evaluator_scratch.h
        cp "$recipe/generated/evaluator_tier1_abi.c" Python/jac_evaluator_tier1_abi.c
        cp "$recipe/generated/evaluator_tier2_abi.c" Python/jac_evaluator_tier2_abi.c
        cp "$work/native/jacpython.o" Python/jacpython.o
        cp "$work/native/evaluator_support.o" Python/jac_evaluator_support.o
        cp "$work/native/evaluator_frames.o" Python/jac_evaluator_frame_clear.o
        cp "$work/native/evaluator_monitoring.o" Python/jac_evaluator_monitoring.o
        cp "$work/native/evaluator_errors.o" Python/jac_evaluator_errors.o
        cp "$work/native/evaluator_imports.o" Python/jac_evaluator_imports.o
        cp "$work/native/evaluator_exceptions.o" Python/jac_evaluator_exceptions.o
        cp "$work/native/evaluator_arguments.o" Python/jac_evaluator_arguments.o
        cp "$work/native/evaluator_binding.o" Python/jac_evaluator_bind_locals.o
        cp "$work/native/evaluator_calls.o" Python/jac_evaluator_calls.o
        cp "$work/native/evaluator_legacy.o" Python/jac_evaluator_legacy.o
        cp "$work/native/evaluator_context.o" Python/jac_evaluator_context.o
        cp "$work/native/evaluator_unpack.o" Python/jac_evaluator_unpack.o
        cp "$work/native/evaluator_matching.o" Python/jac_evaluator_matching.o
        cp "$work/native/evaluator_groups.o" Python/jac_evaluator_groups.o
        cp "$work/native/evaluator_recursion.o" Python/jac_evaluator_recursion_policy.o
        cp "$work/native/evaluator_utilities.o" Python/jac_evaluator_utilities.o
    fi
    # The shared interpreter must survive relocation into the Jac payload.
    case "$platform" in
        linux-*)
            sed 's/-Wl,-h\$(INSTSONAME)/-Wl,-soname,$(INSTSONAME)/g; s/-Wl,-h\$@/-Wl,-soname,$@/g; s/^INSTSONAME=.*/INSTSONAME= libpython$(LDVERSION).so/' \
                Makefile.pre.in > Makefile.pre.in.new
            mv Makefile.pre.in.new Makefile.pre.in
            cat > "$work/bin/pycc" <<'SH'
#!/bin/sh
exec "$JAC_PYTHON_ZIG" cc -target "$JAC_PYTHON_TARGET" -Wno-unused-command-line-argument -Wno-error=date-time '-Wl,-rpath,$ORIGIN/../lib' "$@"
SH
            ;;
        macos-*)
            # Zig's driver ignores -bundle and crashes while linking an
            # executable with unresolved Python symbols. dlopen accepts a
            # shared Mach-O library with the same dynamic symbol lookup.
            export LDSHARED='$(CC) -shared -undefined dynamic_lookup'
            export BLDSHARED="$LDSHARED"
            cat > "$work/bin/pycc" <<'SH'
#!/bin/sh
exec "$JAC_PYTHON_ZIG" cc -target "$JAC_PYTHON_TARGET" -isysroot "$JAC_PYTHON_SDK" -isystem "$JAC_PYTHON_SDK/usr/include" -L "$JAC_PYTHON_SDK/usr/lib" -F "$JAC_PYTHON_SDK/System/Library/Frameworks" -Wno-unused-command-line-argument -Wno-error=date-time '-Wl,-rpath,@loader_path/../lib' "$@"
SH
            # Keep the dylib relocatable and use the three-component versions
            # required by Zig's Mach-O linker (CPython supplies major.minor).
            sed -e 's|-Wl,-install_name,$(prefix)/lib/|-Wl,-install_name,@rpath/|' \
                -e 's/-compatibility_version,$(VERSION)/-compatibility_version,$(VERSION).0/g' \
                -e 's/-current_version,$(VERSION)/-current_version,$(VERSION).0/g' \
                Makefile.pre.in > Makefile.pre.in.new
            mv Makefile.pre.in.new Makefile.pre.in
            ;;
    esac
    chmod +x "$work/bin/pycc"
    export CC="$work/bin/pycc"
    export LIBFFI_CFLAGS="-I$deps/include" LIBFFI_LIBS="$deps/lib/libffi.a"
    export LIBMPDEC_CFLAGS="-I$deps/include" LIBMPDEC_LIBS="$deps/lib/libmpdec.a -lm"
    export LIBSQLITE3_CFLAGS="-I$deps/include" LIBSQLITE3_LIBS="$deps/lib/libsqlite3.a -lm -lpthread"
    export LIBZSTD_CFLAGS="-I$deps/include" LIBZSTD_LIBS="$deps/lib/libzstd.a"
    export ZLIB_CFLAGS="-I$deps/include" ZLIB_LIBS="$deps/lib/libz.a"
    export BZIP2_CFLAGS="-I$deps/include" BZIP2_LIBS="$deps/lib/libbz2.a"
    export LIBLZMA_CFLAGS="-I$deps/include" LIBLZMA_LIBS="$deps/lib/liblzma.a"
    export LIBEXPAT_CFLAGS="-I$deps/include" LIBEXPAT_LIBS="$deps/lib/libexpat.a"
    cat > Modules/Setup.local <<'SETUP'
*disabled*
_tkinter
_testcapi
_testinternalcapi
_testlimitedcapi
_testclinic
_ctypes_test
_gdbm
_dbm
_curses
_curses_panel
readline
SETUP
    if [ -n "$host" ]; then
        cat >> Modules/Setup.local <<'SETUP'
*static*
_bisect
_heapq
_random
binascii
_operator -lcrypto
_queue
_json
_csv
_struct
cmath
math
_collections
_functools
itertools
array
_pickle
SETUP
    fi
    # CPython runs the compiler itself; dependency-oriented -O2 flags above
    # must not override the release interpreter's optimization settings.
    export CFLAGS='-O3 -fPIC -fno-semantic-interposition' LLVM_AR="$AR"
    # Zig 0.16's Mach-O linker cannot consume LTO objects. Keep the supported
    # interpreter optimizations there; Linux uses the bundled LLVM linker.
    case "$platform" in
        linux-*) python_lto=--with-lto=thin ;;
        macos-*) python_lto=--without-lto ;;
    esac
    ./configure --prefix="$prefix" --enable-shared --without-static-libpython \
        --with-tail-call-interp "$python_lto" \
        --disable-test-modules --with-ensurepip=no --with-pkg-config=no \
        --with-openssl="$deps" --with-openssl-rpath=no \
        --with-system-expat --with-system-libmpdec --without-readline
    # Embed the same core objects in the executable: venv --copies must run
    # without a libpython next to the copied executable. Jac's launcher still
    # uses the separately built shared library. Neither needs libpython3.so.
    python_make -j"$jobs" PY3LIBRARY= 'LINK_PYTHON_OBJS=$(LIBRARY_OBJS)'
    # CPython's install targets create overlapping directories. BSD install
    # fails if another target creates the same directory after its check.
    python_make -j1 PY3LIBRARY= 'LINK_PYTHON_OBJS=$(LIBRARY_OBJS)' "COMPILEALL_OPTS=-j$jobs" install
    if [ -n "$host" ]; then
        # Check the completed build, including generated sources and objects.
        sed -n 's/^# \([^ ]*\)  # removed:.*/\1/p' "$recipe/cpython-sources.txt" |
        while IFS= read -r excluded; do
            if [ -e "$excluded" ] || { [ "${excluded%.c}" != "$excluded" ] && [ -e "${excluded%.c}.o" ]; }; then
                echo "Excluded compiler input reappeared: $excluded" >&2
                exit 1
            fi
        done
    fi
}
python_make() {
    if [ -n "$host" ]; then
        # Freeze with the explicit build-time interpreter. Neither helper
        # executable needs to run before the reduced runtime is linked.
        freezer="$host/python/install/bin/python3.14 $src/cpython/Programs/_freeze_module.py"
        make "$@" "FREEZE_MODULE_BOOTSTRAP=$freezer" FREEZE_MODULE_BOOTSTRAP_DEPS= \
            "FREEZE_MODULE=$freezer" FREEZE_MODULE_DEPS= \
            "JAC_NATIVE_ROOT=$root" "JAC_NATIVE_ARTIFACTS=$work/native" \
            "JAC_NATIVE_LINKER=$recipe/link_evaluator.py" \
            "JAC_NATIVE_PYTHON=$host/python/install/bin/python3.14"
    else
        make "$@"
    fi
}

if [ -n "$host" ]; then
    cp -R "$host/python/build/include/." "$deps/include/"
    cp "$host/python/build/lib/"*.a "$deps/lib/"
    cp -R "$host/python/licenses" "$work/python/licenses"
    step native "$host/python/install/bin/python3.14" -I "$recipe/prepare_native.py" "$root" "$work/native" "$platform"
else
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
fi
step cpython cpython
step finalize "$prefix/bin/python3.14" -I "$recipe/finalize.py"
mkdir -p "$work/python/build/lib" "$work/python/licenses"
cp "$deps/lib/"*.a "$work/python/build/lib/"
if [ -n "$host" ]; then
    cp "$host/python/build/cacert.pem" "$work/python/build/cacert.pem"
    cp "$work/native/sha256" "$work/python/build/jacpython-native-sha256"
    cp "$work/native/evaluator_support.sha256" "$work/python/build/jacpython-evaluator-support-sha256"
    cp "$work/native/evaluator_frames.sha256" "$work/python/build/jacpython-evaluator-frames-sha256"
    cp "$work/native/evaluator_monitoring.sha256" "$work/python/build/jacpython-evaluator-monitoring-sha256"
    cp "$work/native/evaluator_errors.sha256" "$work/python/build/jacpython-evaluator-errors-sha256"
    cp "$work/native/evaluator_imports.sha256" "$work/python/build/jacpython-evaluator-imports-sha256"
    cp "$work/native/evaluator_exceptions.sha256" "$work/python/build/jacpython-evaluator-exceptions-sha256"
    cp "$work/native/evaluator_arguments.sha256" "$work/python/build/jacpython-evaluator-arguments-sha256"
    cp "$work/native/evaluator_binding.sha256" "$work/python/build/jacpython-evaluator-binding-sha256"
    cp "$work/native/evaluator_calls.sha256" "$work/python/build/jacpython-evaluator-calls-sha256"
    cp "$work/native/evaluator_legacy.sha256" "$work/python/build/jacpython-evaluator-legacy-sha256"
    cp "$work/native/evaluator_context.sha256" "$work/python/build/jacpython-evaluator-context-sha256"
    cp "$work/native/evaluator_unpack.sha256" "$work/python/build/jacpython-evaluator-unpack-sha256"
    cp "$work/native/evaluator_matching.sha256" "$work/python/build/jacpython-evaluator-matching-sha256"
    cp "$work/native/evaluator_groups.sha256" "$work/python/build/jacpython-evaluator-groups-sha256"
    cp "$work/native/evaluator_recursion.sha256" "$work/python/build/jacpython-evaluator-recursion-sha256"
    cp "$work/native/evaluator_utilities.sha256" "$work/python/build/jacpython-evaluator-utilities-sha256"
    cp "$work/native/evaluator_entry.sha256" "$work/python/build/jacpython-evaluator-entry-sha256"
    cp "$work/native/evaluator-provenance.json" "$work/python/build/jacpython-evaluator-provenance.json"
    rm -rf "$work/native"
else
    # Only dependency headers/archives are reused by the target build. Host
    # CPython objects and libpython are never copied into the reduced runtime.
    cp -R "$deps/include" "$work/python/build/include"
    cp "$src/certifi/certifi/cacert.pem" "$work/python/build/cacert.pem"
fi
step smoke env PYTHONFAULTHANDLER=1 "$prefix/bin/python3.14" -X faulthandler -I "$recipe/smoke.py" "$mode"
# No compiled test modules, docs, or configuration machinery in the runtime.
rm -rf "$prefix/share" "$prefix/lib/python3.14/test" \
    "$prefix/lib/python3.14/idlelib" "$prefix/lib/python3.14/tkinter" \
    "$prefix/lib/python3.14/turtledemo"
echo 'build-python: runtime and native archives ready'
