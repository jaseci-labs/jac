#!/usr/bin/env bash
# Throwaway: build jac for linux-aarch64 in a container, reproduce the
# jac_engine_boot SIGSEGV, and dump breadcrumbs + a gdb backtrace.
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive

echo "=== [1/6] apt deps ==="
apt-get update -qq
apt-get install -y -qq curl xz-utils git build-essential patchelf gdb \
  ca-certificates libxml2-dev zlib1g-dev libzstd-dev pkg-config >/dev/null

echo "=== [2/6] zig 0.16.0 (aarch64-linux) ==="
cd /opt
curl -fsSL https://ziglang.org/download/0.16.0/zig-aarch64-linux-0.16.0.tar.xz | tar -xJ
export PATH=/opt/zig-aarch64-linux-0.16.0:$PATH
zig version

cd /work/jac
echo "=== [3/6] zig build fetch-llvm ==="
zig build fetch-llvm --cache-dir /tmp/zc 2>&1 | tail -3

echo "=== [4/6] zig build (full jac -> /tmp/out) ==="
zig build --cache-dir /tmp/zc --prefix /tmp/out 2>&1 | tail -6
JAC=/tmp/out/bin/jac
file "$JAC"
"$JAC" --version >/dev/null 2>&1 || true

echo "=== [5/6] build engine-boot host ==="
mkdir -p /tmp/eb && cd /tmp/eb
cat > host.na.jac <<'NAEOF'
import sys;
import from jacpyembed {
    def jac_engine_boot() -> i32;
    def PyRun_SimpleString(cmd: str) -> i32;
    def Py_Finalize() -> None;
}
with entry {
    rc: i32 = jac_engine_boot();
    if rc != 0 { sys.exit(1); }
    PyRun_SimpleString("import jaclang; from jaclang.runtimelib.client.targets.desktop.native import oauth_broker; print('ENGINE_BOOT_OK', flush=True)");
    Py_Finalize();
}
NAEOF
RT=$(ls -d /root/.cache/jac/rt/*/ 2>/dev/null | head -1)
echo "RT=$RT"
cp "$RT/site/jaclang/runtimelib/client/targets/desktop/native/libjacpyembed.so" .
"$JAC" nacompile host.na.jac -o engineboot 2>&1 | tail -3
# append the jac binary's [payload][trailer] suffix (what _bundle_runtime does)
"$JAC" -c "
data=open('$JAC','rb').read(); tl=80
assert data[-tl:-tl+8]==b'JACBIN01', 'no trailer'
plen=int.from_bytes(data[-tl+8:-tl+16],'little'); suf=data[-(tl+plen):]
open('engineboot','ab').write(suf); print('bundled', len(suf), 'bytes')
"
chmod +x engineboot

echo "=== [6/6] RUN engineboot (breadcrumbs -> last one = crash site) ==="
./engineboot; echo "RAW exit=$?"
echo "--- gdb backtrace ---"
gdb -q -batch -ex 'run' -ex 'bt' -ex 'info registers' -ex 'quit' ./engineboot 2>&1 | tail -40
