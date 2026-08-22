glob PAYLOAD_ZSTD_LEVEL: int = 19,
     PAYLOAD_WINDOW_LOG: int = 24,
     TAR_PAX_FORMAT: int = 2,
     TAR_REGTYPE: bytes = b"0",
     TAR_DIRTYPE: bytes = b"5",
     FLOOR_ARCHIVES: tuple[str, ...] = (
         "libssl.a",
         "libcrypto.a",
         "libsqlite3.a",
         "libmpdec.a",
         "liblzma.a",
         "libbz2.a",
         "libexpat.a",
         "libz.a",
         "libzstd.a"
     ),
     STDLIB_PRUNE: tuple[str, ...] = (
         "test",
         "idlelib",
         "turtledemo",
         "tkinter",
         "lib2to3"
     ),
     ENTRY_POINTS_TXT: str = (
         "[jac.modules]\n"
         "desktop = jaclang.runtimelib.client.desktop_plugin_config:desktop_sdk_path\n"
         "\n"
         "[jac.module_exports]\n"
         "desktop = jaclang.runtimelib.client.desktop_plugin_config:desktop_sdk_exports\n"
     ),
     PRECOMPILE_BOOT_SRC: str = (
         "import os, sys\n"
         "if len(sys.argv) > 2:\n"
         "    try:\n"
         "        os.unlink(os.path.join(sys.argv[2], 'jaclang', '_precompiled', 'MANIFEST.json'))\n"
         "    except OSError:\n"
         "        pass\n"
         "import _jac_finder; _jac_finder.install()\n"
         "sys.argv = ['jac', 'run'] + sys.argv[1:]\n"
         "from jaclang.jac0core.cli_boot import start_cli\n"
         "start_cli()\n"
     );

obj MkPayloadOpts {
    has shim_so: str | None = None,
        bun_bin: str | None = None,
        skip_precompile: bool = False,
        link_source: str | None = None,
        musl_dir: str | None = None,
        wasm_libc_dir: str | None = None,
        precompiled_cache: str | None = None,
        layer_cache: str | None = None,
        seal: bool = False,
        debug_src: bool = False;
}

obj FoundLib {
    has src: str,
        bare: str;
}

obj TarEntry {
    has path: str,
        is_dir: bool;
}

def mk_payload(pbs_py_dir: str, repo_root: str, out: str, opts: MkPayloadOpts);
def resolve_python(pbs_py_dir: str) -> str;
def assemble_site(repo_root: str, site: str, opts: MkPayloadOpts);
def write_dist_info(repo_root: str, site: str);
def run_precompile_stage(py: str, pbs_py_dir: str, site: str, opts: MkPayloadOpts);
def precompile(py: str, pbs_py_dir: str, site: str, seal: bool, debug_src: bool);
def precompile_env(pbs_py_dir: str, site: str) -> dict[str, str];
def stage_python_bin(pbs_py_dir: str, stage: str);
def stage_tree(
    pbs_py_dir: str,
    site: str,
    stage: str,
    musl_dir: str | None,
    wasm_libc_dir: str | None
);

def stage_stdlib(pbs_lib: str, lib_dst: str);
def precompile_pyc(py: str, stage: str);
def stage_floor(pbs_py_dir: str, stage: str);
def stage_musl(musl_dir: str, stage: str);
def stage_wasm_libc(wasm_libc_dir: str, stage: str);
def find_ca_bundle(pbs_py_dir: str) -> str | None;
def shim_file_name -> str;
def find_libpython(lib_dir: str) -> FoundLib;
def is_volatile_path(p: str) -> bool;
def collect_stage_entries(stage: str) -> list[TarEntry];
def tar_stage(stage: str) -> tuple[bytes, bytes];
def tar_zst_dir(stage: str, out: str, layer_cache: str | None);
def zstd_compress(data: bytes) -> bytes;
def deps_frame_cached(layer_cache: str | None, tar_bytes: bytes) -> bytes;
def frame_decodes_to(frame: bytes, expect: bytes) -> bool;
def prune_layer_cache(dir_path: str, keep: str);
