"""Regenerate win_floor_ir.jac from win_floor.c.

The Windows floor (jac/jaclang/compiler/backends/native/win_floor.c) reaches a
PE image as LLVM IR text carried by the link glue, so building a Windows image
needs no C toolchain. This script is the one place a C compiler is involved:
it compiles the floor with `zig cc` (any clang that targets
x86_64-windows-msvc will do, named in CC), strips what is specific to that
compiler's build, and writes the IR and the list of the floor's kernel32
imports as a Jac module.

Usage:
    jac run scripts/gen_win_floor.jac
"""

import os;
import re;
import shlex;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }

glob ROOT: Path = Path(__file__).resolve().parent.parent,
     NATIVE: Path = ROOT / "jac" / "jaclang" / "compiler" / "backends" / "native",
     SOURCE: Path = NATIVE / "win_floor.c",
     OUTPUT: Path = NATIVE / "win_floor_ir.jac";

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

"""The floor as the C compiler's LLVM IR text."""
def compile_ir -> str {
    compiler = shlex.split(os.environ.get("CC", "zig cc"));
    with tempfile.TemporaryDirectory() as scratch {
        out = os.path.join(scratch, "win_floor.ll");
        command = compiler
            + [
                "-target",
                "x86_64-windows-msvc",
                "-ffreestanding",
                "-nostdinc",
                "-fno-stack-protector",
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
    text = "\n".join(lines);
    return re.sub(r"\n{3,}", "\n\n", text).strip() + "\n";
}

"""The names win_floor.c declares in its kernel32 section."""
def kernel32_names(source: str) -> list[str] {
    start = source.index("/* ---- kernel32.dll ---- */");
    end = source.index("#define CP_UTF8");
    return re.findall(r"\b([A-Za-z_]\w*)\(", source[start:end]);
}

with entry {
    source = SOURCE.read_text(encoding="utf-8");
    ir = clean(compile_ir());
    if '"""' in ir {
        sys.exit("the floor's IR holds a triple quote; it cannot be a raw string");
    }
    declared = set(re.findall(r"^declare [^@]*@(\w+)\(", ir, re.M));
    imports = [
        name
        for name in kernel32_names(source)
        if name in declared
    ];
}

glob
     # No header in the module: `jac fmt --lintfix` strips one, and the module
     # must come out of the formatter as it went in. win_floor.jac says what
     # the two globals are.
     out: list[str] = ["glob WIN_FLOOR_KERNEL32: list[str] = ["];

with entry {
    # Laid out as `jac fmt` lays a glob's list out, so the formatter leaves it alone.
    for (i, name) in enumerate(imports) {
        out.append('         "' + name + '"' + ("," if i + 1 < len(imports) else ""));
    }
    out.extend(
        ["     ],", '     WIN_FLOOR_IR: str = r"""', ir.rstrip("\n"), '""";', ""]
    );
    OUTPUT.write_text("\n".join(out), encoding="utf-8");
    print(
        f"wrote {OUTPUT.relative_to(ROOT)}: {len(ir.splitlines())} lines of IR, "
        f"{len(imports)} kernel32 imports"
    );
}
