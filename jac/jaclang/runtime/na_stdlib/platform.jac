import from ._platform_native {
    plat_uname_ok,
    plat_sysname,
    plat_nodename,
    plat_release,
    plat_version,
    plat_machine,
    plat_uname_p,
    plat_libc_name,
    plat_libc_version,
    plat_arch_bits,
    plat_arch_linkage,
    plat_macos_release
}

glob _PY_VERSION: str = "3.14.6";

obj _UnameCache {
    has done: bool = False,
        pdone: bool = False,
        ldone: bool = False,
        system: str = "",
        `node: str = "",
        release: str = "",
        version: str = "",
        machine: str = "",
        processor: str = "",
        libc_n: str = "",
        libc_v: str = "",
        pdone_f: bool = False,
        pdone_t: bool = False,
        pfull: str = "",
        pterse: str = "";
}

glob _UC: _UnameCache = _UnameCache();

obj:pub uname_result {
    has system: str,
        `node: str,
        release: str,
        version: str,
        machine: str,
        processor: str;
}

def _load_uname;

def _processor -> str;

def:pub uname -> uname_result;

def:pub system -> str;

def:pub `node -> str;

def:pub release -> str;

def:pub version -> str;

def:pub machine -> str;

def:pub processor -> str;

def:pub architecture(
    executable: str = "", bits: str = "", linkage: str = ""
) -> tuple[(str, str)];

def:pub libc_ver(
    executable: str = "", lib: str = "", version: str = ""
) -> tuple[(str, str)];

def:pub python_version -> str;

def:pub python_version_tuple -> tuple[(str, str, str)];

def _platform_join(args: list[str]) -> str;

def:pub platform(aliased: bool = False, terse: bool = False) -> str;
