import from http { HTTPMethod }

obj InstallStatus {
    has updated: bool = False,
        building: bool = False,
        sha: str = "",
        checked_at: str = "";
}

glob INSTALL_SRC: str = "https://raw.githubusercontent.com/jaseci-labs/jac/main/scripts/install.sh",
     USER_AGENT: str = "jaclang.org installer sync",
     CHECK_TTL_S: float = 900.0,
     MIN_SCRIPT_BYTES: int = 500,
     CACHE_DIR: str = ".jac",
     _pulling: bool = False;

node InstallMeta {
    has sha: str = "",
        checked_at: str = "",
        updated_at: str = "";
}

glob UNAVAILABLE_SH: str = "#!/usr/bin/env bash\necho 'jac: installer temporarily unavailable' >&2\nexit 1\n";

def _get_meta -> InstallMeta | None;

def cache_path -> str;

def _fresh(meta: InstallMeta) -> bool;

def looks_like_script(text: str) -> bool;

def _fetch_script -> str | None;

def _write_cache(text: str);

@restspec(
    method=HTTPMethod.GET,
    path="/install.sh",
    produces="text/x-shellscript",
    envelope=False
)
def:pub install_sh -> str;

def:pub ensure_install -> InstallStatus;
