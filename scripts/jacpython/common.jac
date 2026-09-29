"""Paths, the pinned CPython archive and formatting shared by the JacPython generators.

The generators write Jac that `jac fmt --check --lintfix` must accept, and
their own `--check` must agree with it, so every output goes through
format_jac() exactly as it would be formatted in place.
"""
import hashlib;
import json;
import os;
import sys;
import tarfile;
import from pathlib { Path }

glob REPO: Path = Path(__file__).resolve().parents[2],
     JAC: Path = REPO / "jac",
     BOOTSTRAP: Path = JAC / "bootstrap/python",
     RUNTIME: Path = JAC / "jaclang/runtime/python",
     SOURCES: list[Path] = [
         JAC / "jaclang/runtime/python",
         JAC / "jaclang/compiler/frontend/python",
         JAC / "jaclang/compiler/backends/py/jacpython"
     ];

def pin -> dict[str, str] {
    return json.loads((BOOTSTRAP / "sources.json").read_text())["cpython"];
}

# The checksum-pinned CPython archive a JacPython build downloads.
def archive_path -> Path {
    pinned = pin();
    path = JAC / ".python-build/jacpython/sources" / f"{pinned['sha256']}.tar.gz";
    if not path.is_file() {
        sys.exit(
            f"Pinned CPython archive not found: {path}; run a JacPython build once"
        );
    }
    if hashlib.sha256(path.read_bytes()).hexdigest() != pinned["sha256"] {
        sys.exit(f"{path} does not match the pinned SHA256");
    }
    return path;
}

# Files of the pinned archive whose relative path starts with one of `prefixes`.
def archive_texts(prefixes: tuple[str, ...]) -> dict[str, str] {
    found: dict[str, str] = {};
    with tarfile.open(archive_path()) as bundle {
        for member in bundle.getmembers() {
            relative = member.name.split("/", 1)[-1];
            if member.isfile() and relative.startswith(prefixes) {
                stream = bundle.extractfile(member);
                if stream is not None {
                    found[relative] = stream.read().decode("utf-8", "replace");
                }
            }
        }
    }
    return found;
}

# Extract the archive members under `prefixes` into `target`; returns the tree root.
def extract_tree(target: Path, prefixes: tuple[str, ...]) -> Path {
    with tarfile.open(archive_path()) as bundle {
        members = [
            m
            for m in bundle.getmembers()
            if m.name.split("/", 1)[-1].startswith(prefixes)
        ];
        bundle.extractall(target, members=members, filter="data");
    }
    return next(target.iterdir());
}

# Format `text` as `jac fmt --lintfix` formats it at `target`. The scratch file
# sits beside the target so the project's jac.toml applies, and formatting is
# repeated to a fixed point because one pass can add blank lines a second keeps.
def format_jac(text: str, target: Path) -> str {
    import from jaclang.compiler.driver.program { JacProgram }
    for _ in range(3) {
        program = JacProgram.jac_str_formatter(text, str(target), auto_lint=True);
        formatted = program.mod.main.gen.jac;
        if any(e.code is not None and e.code.code == "E5051" for e in program.errors_had) or not formatted or not formatted.strip() {
            sys.exit("jac fmt failed on generated Jac for " + f"{target}:\n" + "\n".join(str(e) for e in program.errors_had));
        }
        if formatted == text { break; }
        text = formatted;
    }
    return text;
}

# Write `text` to `target`, or with `check` fail when the committed file differs.
def write_or_check(target: Path, text: str, check: bool, command: str) -> bool {
    if check {
        if not target.is_file() or target.read_text() != text {
            print(
                f"{target.relative_to(REPO)} is stale; rerun {command}", file=sys.stderr
            );
            return False;
        }
        return True;
    }
    target.parent.mkdir(parents=True, exist_ok=True);
    target.write_text(text);
    print(f"wrote {target.relative_to(REPO)}");
    return True;
}
