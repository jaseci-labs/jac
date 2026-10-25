"""Paths, the pinned CPython archive, op definitions and formatting for the JacPython generators.

The generators write Jac that `jac fmt --check --lintfix` must accept, and
their own `--check` must agree with it, so every output goes through
format_jac() exactly as it would be formatted in place.
"""
import hashlib;
import json;
import os;
import re;
import shutil;
import subprocess;
import sys;
import tarfile;
import tempfile;
import from pathlib { Path }

glob REPO: Path = Path(__file__).resolve().parents[2],
     JAC: Path = REPO / "jac",
     BOOTSTRAP: Path = JAC / "bootstrap/python",
     RUNTIME: Path = JAC / "jaclang/runtime/python",
     INTERPRETER: Path = RUNTIME / "interpreter",
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

# An op definition's signature in ops.jac.
obj Signature {
    has params: list[tuple[str, str]],
        returns: str,
        body: str = "",
        module: str = "";
}

# The modules holding op bodies: interpreter/ops.jac and ops_<group>.jac.
def op_sources -> list[Path] {
    return sorted(INTERPRETER.glob("ops*.jac"));
}

# Read every top-level definition's parameters and return type from the op
# modules.
def read_signatures -> dict[str, Signature] {
    out: dict[str, Signature] = {};
    for source in op_sources() {
        for (name, sig) in read_module_signatures(source).items() {
            if name in out and name.isupper() {
                sys.exit(
                    f"op {name} is defined in {out[name].module} and {sig.module}"
                );
            }
            out[name] = sig;
        }
    }
    return out;
}

# A top-level definition is either `def name(params) -> T { body }` or, as
# `jac fmt --lintfix` writes it, a declaration `def name(params) -> T;` with
# an `impl name(params) -> T { body }` block.
def read_module_signatures(source: Path) -> dict[str, Signature] {
    text = source.read_text();
    pattern = re.compile(
        r"^(def|impl) (\w+)\s*(?:\((.*?)\))?\s*(?:->\s*([^{;]*?))?\s*([{;])",
        re.M | re.S
    );
    out: dict[str, Signature] = {};
    for m in pattern.finditer(text) {
        name = m.group(2);
        body = "";
        if m.group(5) == "{" {
            body = block_body(text, m.end());
        }
        if m.group(1) == "impl" {
            if name in out {
                out[name].body = body;
            }
            continue;
        }
        out[name] = Signature(
            params=split_params((m.group(3) or "").strip()),
            returns=(m.group(4) or "None").strip(),
            body=body,
            module=source.stem
        );
    }
    return out;
}

# The text of a block whose `{` ends just before `start`.
def block_body(text: str, start: int) -> str {
    depth = 1;
    end = start;
    while depth and end < len(text) {
        if text[end] == "{" {
            depth += 1;
        } elif text[end] == "}" {
            depth -= 1;
        }
        end += 1;
    }
    return text[start:end];
}

def split_params(body: str) -> list[tuple[str, str]] {
    depth = 0;
    current = "";
    parts: list[str] = [];
    for ch in body {
        if ch == "[" {
            depth += 1;
        } elif ch == "]" {
            depth -= 1;
        }
        if ch == "," and depth == 0 {
            parts.append(current);
            current = "";
        } else {
            current += ch;
        }
    }
    if current.strip() {
        parts.append(current);
    }
    params: list[tuple[str, str]] = [];
    for part in parts {
        (pname, ptype) = part.split(":", 1);
        params.append((pname.strip(), ptype.strip()));
    }
    return params;
}

# Format `text` as `jac fmt --lintfix` formats it at `target`.
def format_jac(text: str, target: Path) -> str {
    return format_jac_many([(text, target)])[0];
}

# Format each (text, target) pair as `jac fmt --lintfix` formats it at its
# target, in one formatter run: the scratch directory sits beside the first
# target so the project's jac.toml applies, and formatting is repeated to a
# fixed point because one pass can add blank lines a second keeps.
def format_jac_many(items: list[tuple[str, Path]]) -> list[str] {
    if not items {
        return [];
    }
    jac = shutil.which("jac");
    if jac is None {
        sys.exit("jac is not on PATH; generated Jac is formatted with `jac fmt`");
    }
    home = items[0][1].parent;
    home.mkdir(parents=True, exist_ok=True);
    scratch = Path(tempfile.mkdtemp(prefix=".gen_", dir=home));
    paths = [
        scratch / f"{index}_{target.name}" for (index, (_, target)) in enumerate(items)
    ];
    try {
        for (path, (text, _)) in zip(paths, items) {
            path.write_text(text);
        }
        for _ in range(3) {
            before = [path.read_text() for path in paths];
            result = subprocess.run(
                [jac, "fmt", "--lintfix", str(scratch)], capture_output=True, text=True
            );
            if result.returncode != 0 {
                sys.exit(
                    f"jac fmt failed on generated Jac:\n{result.stdout}{result.stderr}"
                );
            }
            if [path.read_text() for path in paths] == before {
                break;
            }
        }
        return [path.read_text() for path in paths];
    } finally {
        shutil.rmtree(scratch, ignore_errors=True);
    }
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

# Bytes of each sized integer type a C integer array holds.
glob INTEGER_WIDTHS: dict[str, int] = {
         "u8": 1,
         "u16": 2,
         "u32": 4,
         "i8": 1,
         "i16": 2,
         "i32": 4
     },
     # Characters of a bytes literal per generated line (indent and quotes aside).
     BYTES_LINE_CHARS: int = 72;

# The escape of one byte of a bytes literal: printable ASCII as itself, the
# rest as the shortest octal escape that `following` (the next byte) cannot
# extend.
def byte_escape(byte: int, following: int) -> str {
    ch = chr(byte);
    if ch in '\\"' {
        return "\\" + ch;
    }
    if 32 <= byte < 127 {
        return ch;
    }
    digits = f"{byte:o}";
    if 48 <= following <= 55 {
        digits = digits.rjust(3, "0");
    }
    return "\\" + digits;
}

# The initializer of a C integer array of `jt` holding `values`: a bytes
# literal of its little-endian elements (which the native compiler lays out as
# the array), split into adjacent literals that fit the formatter's line.
def bytes_literal(values: list[int], jt: str) -> str {
    import ast;
    width = INTEGER_WIDTHS[jt];
    signed = jt.startswith("i");
    data = b"".join(v.to_bytes(width, "little", signed=signed) for v in values);
    lines: list[str] = [];
    line: list[str] = [];
    size = 0;
    for i in range(len(data)) {
        token = byte_escape(data[i], data[i + 1] if i + 1 < len(data) else -1);
        if size + len(token) > BYTES_LINE_CHARS {
            lines.append('b"' + "".join(line) + '"');
            line = [];
            size = 0;
        }
        line.append(token);
        size += len(token);
    }
    lines.append('b"' + "".join(line) + '"');
    if b"".join(ast.literal_eval(text) for text in lines) != data {
        raise ValueError(f"a {jt} table does not survive its bytes literal");
    }
    return "(\n" + "\n".join(lines) + "\n)";
}
