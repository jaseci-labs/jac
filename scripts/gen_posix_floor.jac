"""Regenerate posix_floor_ir.jac from posix_floor.c.

The POSIX floor (jac/jaclang/compiler/backends/native/posix_floor.c) reaches
an ELF or Mach-O artifact as LLVM IR text carried by the link glue, so a
native build needs no C toolchain. This script is the one place a C compiler
is involved: it compiles the floor once per release target with `zig cc`
against that target's own C headers, strips what is specific to that
compiler's build, and writes the IR as a Jac module together with the
source's sha256, which test_posix_floor_ir.jac holds the module to.

Usage:
    jac run scripts/gen_posix_floor.jac
"""
import hashlib;
import os;
import re;
import shlex;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }

glob ROOT: Path = Path(__file__).resolve().parent.parent,
     NATIVE: Path = ROOT / "jac" / "jaclang" / "compiler" / "backends" / "native",
     SOURCE: Path = NATIVE / "posix_floor.c",
     OUTPUT: Path = NATIVE / "posix_floor_ir.jac",
     TARGETS: list[tuple[str, str, str]] = [
         ("linux-x86_64", "x86_64-linux-gnu.2.17", "POSIX_FLOOR_IR_LINUX_X86_64"),
         ("linux-aarch64", "aarch64-linux-gnu.2.17", "POSIX_FLOOR_IR_LINUX_AARCH64"),
         ("macos-aarch64", "aarch64-macos.11.0", "POSIX_FLOOR_IR_MACOS_AARCH64"),
         ("macos-x86_64", "x86_64-macos.10.15", "POSIX_FLOOR_IR_MACOS_X86_64")
     ];

"""Function attributes that record the generating compiler's target defaults."""
glob DROPPED_ATTRIBUTES: list[str] = [
         "target-cpu",
         "target-features",
         "tune-cpu",
         "stack-protector-buffer-size",
         "min-legal-vector-width",
         "no-trapping-math",
         "frame-pointer"
     ];

"""The floor as the C compiler's LLVM IR text for one zig target."""
def compile_ir(zig_target: str) -> str {
    compiler = shlex.split(os.environ.get("CC", "zig cc"));
    with tempfile.TemporaryDirectory() as scratch {
        out = os.path.join(scratch, "posix_floor.ll");
        command = compiler
            + [
                "-target",
                zig_target,
                "-fno-stack-protector",
                "-fno-asynchronous-unwind-tables",
                "-fno-exceptions",
                "-ffp-contract=off",
                "-O2",
                "-g0",
                "-Wall",
                "-Wextra",
                "-S",
                "-emit-llvm",
                "-o",
                out,
                str(SOURCE)
            ];
        done = subprocess.run(command, capture_output=True, text=True);
        if done.returncode != 0 {
            sys.exit(done.stderr);
        }
        for line in done.stderr.splitlines() {
            if "argument unused" not in line {
                print(line, file=sys.stderr);
            }
        }
        return Path(out).read_text(encoding="utf-8");
    }
}

"""The IR without its module header, metadata and target-specific attributes:
the link glue it joins names the target."""
def clean(ir: str) -> str {
    lines: list[str] = [];
    for raw in ir.splitlines() {
        line = raw;
        if line.startswith(("; ModuleID", "source_filename", "target ", "!")) {
            continue;
        }
        if line.startswith("; Function Attrs") {
            continue;
        }
        line = re.sub(r", ![A-Za-z_.]+ !\d+", "", line);
        if line.startswith("attributes #") {
            for name in DROPPED_ATTRIBUTES {
                line = re.sub(' "' + re.escape(name) + '"="[^"]*"', "", line);
            }
        }
        lines.append(line.rstrip());
    }
    empty = [
        m.group(1)
        for line in lines
        if (m := re.match(r"attributes #(\d+) = \{\s*\}$", line))
    ];
    kept: list[str] = [];
    for line in lines {
        if re.match(r"attributes #(\d+) = \{\s*\}$", line) {
            continue;
        }
        for group in empty {
            line = re.sub(r" #" + group + r"\b", "", line);
        }
        kept.append(line);
    }
    text = "\n".join(kept);
    return re.sub(r"\n{3,}", "\n\n", text).strip() + "\n";
}

with entry {
    source = SOURCE.read_bytes();
    digest = hashlib.sha256(source).hexdigest();
    out: list[str] = [f'glob POSIX_FLOOR_SOURCE_SHA256: str = "{digest}",'];
    for (i, (osarch, zig_target, name)) in enumerate(TARGETS) {
        ir = clean(compile_ir(zig_target));
        if '"""' in ir {
            sys.exit(f"the {osarch} floor's IR holds a triple quote");
        }
        end = '""";' if i + 1 == len(TARGETS) else '""",';
        out.extend([f'     {name}: str = r"""', ir.rstrip("\n"), end]);
        print(f"{osarch}: {len(ir.splitlines())} lines of IR");
    }
    out.append("");
    OUTPUT.write_text("\n".join(out), encoding="utf-8");
    print(f"wrote {OUTPUT.relative_to(ROOT)}");
}
