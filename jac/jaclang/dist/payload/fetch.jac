import from jaclang.dist.payload.pins { LlvmSlice }

glob TYPESHED_TARBALL_BASE: str = "https://codeload.github.com/python/typeshed/tar.gz",
     TYPESHED_VENDOR: str = "jaclang/vendor/typeshed",
     USER_AGENT: str = "jac-payload-tool",
     SLICE_RUN_GAP: int = 16 * 1024 * 1024,
     ZIP_EOCD_SIG: bytes = b"PK\x05\x06",
     ZIP_CDH_SIG: bytes = b"PK\x01\x02",
     ZIP_LFH_SIG: bytes = b"PK\x03\x04";

obj ZipMember {
    has name: str,
        method: int,
        csize: int,
        crc: int,
        lho: int;
}

obj HttpSource {
    def get(url: str) -> bytes;
    def get_range(url: str, start: int, end: int) -> bytes;
}

def http_get(url: str) -> bytes;
def http_get_range(url: str, start: int, end: int) -> bytes;
def fetch_typeshed(repo_root: str);
def typeshed_sha(commit: str);
def fetch_llvm(dest: str);
def slice_wanted(name: str, macos: bool) -> bool;
def parse_eocd(tail: bytes, who: str) -> tuple[int, int];
def parse_central_directory(cd: bytes) -> list[ZipMember];
def inflate_member(method: int, data: bytes, who: str) -> bytes;
def member_data(run: bytes, run_start: int, m: ZipMember) -> bytes;
def fetch_llvm_slice(dest: str, rel: LlvmSlice, src: HttpSource, macos: bool);
