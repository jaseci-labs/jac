import os;
import shutil;
import tempfile;

glob ELF_INTERPRETERS: dict[str, list[str]] = {
         "x86_64": [
             "/lib64/ld-linux-x86-64.so.2",
             "/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2"
         ],
         "aarch64": [
             "/lib/ld-linux-aarch64.so.1",
             "/lib/aarch64-linux-gnu/ld-linux-aarch64.so.1"
         ]
     },
     MACHO_ARCH: dict[str, str] = {
         "aarch64": "arm64",
         "arm64": "arm64",
         "x86_64": "x86_64"
     },
     MACHO_MIN_VERSION: dict[str, str] = {"arm64": "11.0", "x86_64": "10.15"},
     MACHO_SYSTEM_DYLIB: str = "/usr/lib/libSystem.B.dylib",
     PE_MACHINE: dict[str, int] = {"x86_64": 0x8664, "aarch64": 0xAA64},
     PE_LINK_MACHINE: dict[str, str] = {"x86_64": "x64", "aarch64": "arm64"},
     PE_EXE_ENTRY: str = "_jac_win_start",
     PE_DLL_ENTRY: str = "__jac_dll_main",
     MUSL_CRT: tuple[str, ...] = ("crt1.o", "crti.o", "crtn.o"),
     MUSL_ARCHIVES: tuple[str, ...] = (
         "libc.a",
         "libzigc.a",
         "libcompiler_rt.a",
         "libmusl_compat.a"
     );

class NativeLinkError(RuntimeError) {}

obj NativeLinkJob {
    has platform: str,
        triple: str,
        output_path: str,
        shared: bool = False,
        soname: str = "",
        objects: list[bytes] = [],
        archives: list[str] = [],
        crt_objects: list[str] = [],
        needed_libs: list[str] = [],
        symbol_lib_map: dict[str, str] = {},
        export_symbols: list[str] = [],
        archive_symbols: set[str] = set(),
        static_musl: bool = False;
}

obj WasmLinkJob {
    has objects: list[bytes],
        output_path: str,
        export_funcs: list[str] = [],
        allowed_imports: (list[str] | None) = None;
}

def triple_arch_of(triple: str) -> str;

def floor_lib_dir(triple: str) -> (str | None);

def musl_lib_dir(triple: str) -> (str | None);

def clib_to_archive_name(clib_path: str) -> str;

def floor_archives(clib_paths: list[str], triple: str) -> tuple[list[str], set[str]];

def musl_runtime(triple: str) -> (tuple[list[str], list[str]] | None);

def outline_atomics_archive(triple: str) -> (str | None);

def elf_runtime_soname(name: str) -> str;

def clib_needed_libs(
    needed_libs: list[str],
    clib_paths: list[str],
    floor_handled: set[str],
    host_elf: bool = False
) -> dict[str, str];

def clib_symbol_lib_map(
    clib_symbol_lib: dict[str, str],
    floor_handled: set[str],
    lib_norm: dict[str, str],
    shared: bool,
    is_macos: bool
) -> dict[str, str];

def _run_lld(args: list[str], what: str) -> list[str];

def _write_objects(work: str, objects: list[bytes], suffix: str) -> list[str];

def _undefined_symbols(objects: list[bytes]) -> list[str];

def link_native(job: NativeLinkJob) -> list[str];

def _elf_interpreter(triple: str) -> str;

def _empty_object(work: str, triple: str) -> str;

def _elf_stub_library(work: str, triple: str, soname: str, index: int) -> str;

def _link_elf(job: NativeLinkJob, work: str) -> list[str];

def _macho_version(triple: str, arch: str) -> str;

def _tbd(path: str, install_name: str, target: str, symbols: list[str]);

def _macho_install_name(lib: str) -> str;

def macho_stub_symbols(
    job: NativeLinkJob, undefined: list[str]
) -> dict[str, list[str]];

def _link_macho(job: NativeLinkJob, work: str) -> list[str];

def _link_pe(job: NativeLinkJob, work: str) -> list[str];

def link_wasm_module(job: WasmLinkJob);

def write_symbol_map(output_path: str);
