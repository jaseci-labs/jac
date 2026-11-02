"""A native module resolves to its most specific platform variant.

`<name>.<os>.<arch>.jac` wins over `<name>.<arch>.jac`, which wins over
`<name>.<os>.jac`, which wins over `<name>.jac`, all chosen by the native
target rather than the host. A call into such a module reaches the variant's
declaration, including a C function its library block declares, rather than
the portable module the type checker reads.

A variant is reached by native module resolution alone, never by an import
the checker reads, so no import edge placed it: it used to parse with no
codespace, its globals and functions were never lowered, and a standalone
binary reading a variant global aborted at load on the missing symbol. A
platform variant is a native unit by what it is, so its own unit is the one
compiled and linked.
"""
import os;
import tempfile;
import from jaclang.compiler.frontend.codeinfo {
    native_target_os,
    set_native_target_override,
    _native_variant_path
}
import from tests.support { native_build, native_run }

test "the most specific platform variant of a native module wins" {
    with tempfile.TemporaryDirectory() as scratch {
        base = os.path.join(scratch, "records");
        for suffix in ["", ".linux", ".x86_64", ".linux.x86_64"] {
            with open(base + suffix + ".jac", "w") as handle {
                handle.write("");
            }
        }
        for (target, variant) in [
            ("x86_64-unknown-linux-gnu", "records.linux.x86_64.jac"),
            ("aarch64-unknown-linux-gnu", "records.linux.jac"),
            ("x86_64-apple-darwin", "records.x86_64.jac"),
            ("arm64-apple-darwin", "records.jac")
        ] {
            prev = set_native_target_override(target);
            try {
                chosen = _native_variant_path(base);
            } finally {
                set_native_target_override(prev);
            }
            assert chosen is not None and os.path.basename(chosen) == variant , (
                f"{target}: {chosen}"
            );
        }
    }
}

glob PORTABLE_PLATFORM: str = '''glob HAS_C: bool = False,
     PLATFORM_CODE: int = 1;

def platform_answer -> int {
    return 0;
}

def frexp(value: f64, exponent: &mut i32) -> f64 {
    return 0.0;
}

def snprintf(buf: ptr[u8], size: u64, fmt: ptr[u8]) -> i32 {
    return i32(-1);
}
''',
     TARGET_PLATFORM: str = '''import from c {
    def frexp(value: f64, exponent: &mut i32) -> f64;
    def snprintf(buf: ptr[u8], size: u64, fmt: ptr[u8], *args: any) -> i32;
}

glob HAS_C: bool = True,
     PLATFORM_CODE: int = 7;

def platform_answer -> int {
    return 42;
}
''',
     PLATFORM_USER: str = '''import from platform_facts {
    frexp,
    snprintf,
    HAS_C,
    PLATFORM_CODE,
    platform_answer
}
import from c { def malloc(size: u64) -> ptr[u8]; }

with entry {
    exponent = i32(0);
    mantissa = frexp(8.0, &mut exponent);
    print("frexp", mantissa, exponent);
    print("snprintf", snprintf(malloc(u64(16)), u64(16), ptr[u8]("seven")));
    print("facts", HAS_C, PLATFORM_CODE, platform_answer());
}
''';

test "a call through a platform variant reaches the variant's C declaration" {
    with tempfile.TemporaryDirectory() as scratch {
        files = {
            "platform_facts.jac": PORTABLE_PLATFORM,
            f"platform_facts.{native_target_os()}.jac": TARGET_PLATFORM,
            "platform_user.jac": PLATFORM_USER
        };
        for (name, text) in files.items() {
            with open(os.path.join(scratch, name), "w") as handle {
                handle.write(text);
            }
        }
        binary = os.path.join(scratch, "platform_user.nogc");
        native_build(os.path.join(scratch, "platform_user.jac"), binary, memory="nogc");
        out = native_run(binary);
    }
    assert out.splitlines() == ["frexp 0.5 4", "snprintf 5", "facts True 7 42"] , out;
}
