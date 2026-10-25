"""posix_floor_ir.jac is generated from the posix_floor.c in the tree.

The floor reaches an artifact as IR text, so the C source and its IR must not
drift apart: editing posix_floor.c means running
`jac run scripts/gen_posix_floor.jac`, which records the source it compiled.
"""
import hashlib;
import from pathlib { Path }
import from jaclang.compiler.backends.native.posix_floor_ir {
    POSIX_FLOOR_SOURCE_SHA256
}
import from jaclang.compiler.backends.native.posix_floor { posix_floor_ir }

test "the floor's IR was generated from the floor's source" {
    import jaclang;
    source = Path(jaclang.__file__).resolve().parent
        / "compiler"
        / "backends"
        / "native"
        / "posix_floor.c";
    digest = hashlib.sha256(source.read_bytes()).hexdigest();
    assert digest == POSIX_FLOOR_SOURCE_SHA256 , (
        "posix_floor.c changed since posix_floor_ir.jac was generated; "
        "run `jac run scripts/gen_posix_floor.jac`"
    );
}

test "every release target has a floor that defines the whole API" {
    for osarch in ["linux-x86_64", "linux-aarch64", "macos-aarch64", "macos-x86_64"] {
        ir = posix_floor_ir(osarch);
        for name in [
            "__jac_errno",
            "__jac_stdio",
            "__jac_platform_id",
            "__jac_stat",
            "__jac_opendir",
            "__jac_readdir",
            "__jac_closedir",
            "__jac_dirent_name",
            "__jac_at_fdcwd",
            "__jac_home_dir",
            "__jac_clock_id",
            "__jac_sleep_ns",
            "__jac_malloc_size",
            "__jac_fmadd",
            "__jac_va_list",
            "__jac_va_i64",
            "__jac_va_f64"
        ] {
            assert f"@{name}(" in ir , f"{osarch} floor lacks {name}";
        }
    }
    assert posix_floor_ir("wasm32") == "";
}

"""The floor's home lookup grows its record buffer while the account database
reports ERANGE. The floor's own source is compiled against stand-ins for
getpwnam_r and getpwuid_r that need a record far larger than the first
buffer, so no real account has to be that large."""
test "the floor's home lookup grows its record buffer on ERANGE" {
    import os;
    import shlex;
    import shutil;
    import subprocess;
    import tempfile;
    import jaclang;
    compiler = shlex.split(os.environ.get("CC", "zig cc"));
    if shutil.which(compiler[0]) is None {
        testskip(f"no C compiler ({compiler[0]}) to build the floor with");
    }
    floor = Path(jaclang.__file__).resolve().parent
        / "compiler"
        / "backends"
        / "native"
        / "posix_floor.c";
    harness = """
#define getpwnam_r jac_test_getpwnam_r
#define getpwuid_r jac_test_getpwuid_r
#include "FLOOR"
#undef getpwnam_r
#undef getpwuid_r

static int calls = 0;
static char home[] = "/home/jac-test";

static int lookup(struct passwd *pw, char *buf, size_t len, struct passwd **out) {
    calls++;
    if (len < 100000) {
        *out = NULL;
        return ERANGE;
    }
    memset(pw, 0, sizeof *pw);
    strcpy(buf, home);
    pw->pw_dir = buf;
    *out = pw;
    return 0;
}

int jac_test_getpwnam_r(const char *name, struct passwd *pw, char *buf, size_t len,
                        struct passwd **out) {
    (void)name;
    return lookup(pw, buf, len, out);
}

int jac_test_getpwuid_r(uid_t uid, struct passwd *pw, char *buf, size_t len,
                        struct passwd **out) {
    (void)uid;
    return lookup(pw, buf, len, out);
}

int main(void) {
    char out[64];
    long long named = (long long)__jac_home_dir("someone", out, sizeof out);
    printf("%lld %s %d\\n", named, named >= 0 ? out : "-", calls);
    calls = 0;
    char tiny[4];
    long long mine = (long long)__jac_home_dir("", tiny, sizeof tiny);
    printf("%lld %d\\n", mine, calls);
    return 0;
}
""".replace(
        "FLOOR", str(floor)
    );
    with tempfile.TemporaryDirectory() as directory {
        source = Path(directory) / "harness.c";
        source.write_text(harness);
        binary = str(Path(directory) / "harness");
        build = subprocess.run(
            compiler + ["-o", binary, str(source)],
            capture_output=True,
            text=True,
            timeout=300
        );
        assert build.returncode == 0 , build.stdout + build.stderr;
        run = subprocess.run([binary], capture_output=True, text=True, timeout=60);
        assert run.returncode == 0 , run.stdout + run.stderr;
        lines = run.stdout.splitlines();
        """4096 doubles to 131072, the first size past 100000: six lookups.""";
        assert lines == ["14 /home/jac-test 6", "14 6"] , run.stdout;
    }
}
