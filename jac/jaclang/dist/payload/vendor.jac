glob WASM_FLOOR_MANIFEST: str = "SOURCES.sha256",
     MUSL_ARTIFACTS: tuple[str, ...] = (
         "libc.a",
         "libzigc.a",
         "libcompiler_rt.a",
         "libclang_rt.atomics.a",
         "libmusl_compat.a",
         "crt1.o",
         "crti.o",
         "crtn.o"
     ),
     MUSL_MANDATORY: tuple[str, ...] = ("libc.a", "libzigc.a", "crt1.o"),
     MUSL_LFS64_ENTRIES: tuple[str, ...] = (
         "fopen64",
         "fseeko64",
         "ftello64",
         "open64",
         "openat64",
         "lseek64",
         "pread64",
         "pwrite64",
         "ftruncate64",
         "truncate64",
         "mmap64",
         "stat64",
         "lstat64",
         "fstat64",
         "fstatat64",
         "readdir64"
     ),
     MUSL_STUB_C: str = (
         "#include <string.h>\n#include <stdlib.h>\n#include <stdio.h>\n#include <math.h>\n"
         "int main(int c, char **v){char b[8];snprintf(b,sizeof b,\"%d\",c);void*p=malloc(8);free(p);"
         "return (int)(strncmp(b,\"x\",1)+(long)sin((double)v[0][0]));}\n"
     );

obj WasmSources {
    has srcs: list[str],
        outs: list[str],
        rels: list[str],
        hdrs: list[str],
        hdr_rels: list[str];
}

def build_musl(osarch: str, dest: str, zig_exe: str);
def build_outline_atomics(dest: str, zig_exe: str);
def build_musl_compat(ztarget: str, dest: str, zig_exe: str);
def build_wasm_libc(src_root: str, dest: str, zig_exe: str);
def collect_wasm_sources(src_root: str) -> WasmSources;
def read_source_manifest(manifest_path: str) -> dict[str, str];
def write_source_manifest(
    manifest_path: str, rels: list[str], digest_of: dict[str, str]
);

def wasm_floor_unit_stale(
    dest: str,
    out_name: str,
    rel: str,
    digest_of: dict[str, str],
    prev: dict[str, str],
    hdrs_changed: bool
) -> bool;
