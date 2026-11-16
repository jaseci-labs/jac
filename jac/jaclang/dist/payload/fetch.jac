glob TYPESHED_TARBALL_BASE: str = "https://codeload.github.com/python/typeshed/tar.gz",
     TYPESHED_VENDOR: str = "jaclang/vendor/typeshed",
     BUN_BASE: str = "https://github.com/oven-sh/bun/releases/download",
     USER_AGENT: str = "jac-payload-tool",
     ZIP_EOCD_SIG: bytes = b"PK\x05\x06",
     ZIP_CDH_SIG: bytes = b"PK\x01\x02",
     ZIP_LFH_SIG: bytes = b"PK\x03\x04";

def http_get(url: str) -> bytes;
def bun_asset_name(osarch: str) -> str | None;
def fetch_typeshed(repo_root: str);
def typeshed_sha(commit: str);
def parse_eocd(tail: bytes, who: str) -> tuple[int, int];
def inflate_member(method: int, data: bytes, who: str) -> bytes;
def unzip_member_by_suffix(zip_bytes: bytes, suffix: str) -> bytes;
def fetch_bun(osarch: str, dest: str);
