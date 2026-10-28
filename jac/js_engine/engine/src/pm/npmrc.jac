"""
.npmrc reader (engine/src/pm).

npm's ini dialect as bun reads it: one `key=value` per line, `#`/`;` comments,
`[section]` lines ignored, one pair of surrounding quotes stripped from a value,
`${VAR}` expanded from the environment. Keys are returned as written — the
interpretation (`registry`, `@scope:registry`, `//host/path/:_authToken`, …)
is config.jac's job.
"""

import from engine.src.ffi.libc { getenv }

import from engine.src.runtime.mem {
    byte_chr,
    str_bfind,
    str_bslice,
    str_bslice_from,
    str_byte,
    str_nbytes
}

obj:pub NpmrcEntry {
    has key: str = "",
        value: str = "",
        line: int = 0;
}

"""Expand `${NAME}` references from the environment. An unset variable expands
to "" and is reported in `warnings` (npm errors out; bun leaves it empty)."""
def:pub npmrc_expand_env(val: str, source: str, ln: int, warnings: list[str]) -> str {
    if str_bfind(val, "${") < 0 {
        return val;
    }
    out: str = "";
    i: int = 0;
    n: int = str_nbytes(val);
    while i < n {
        if byte_chr(str_byte(val, i)) == "$" and i + 1 < n and byte_chr(str_byte(val, i + 1)) == "{" {
            close: int = i + 2;
            while close < n and byte_chr(str_byte(val, close)) != "}" {
                close = close + 1;
            }
            if close >= n {
                # No closing brace: keep the rest literally.
                out = out + str_bslice_from(val, i);
                break;
            }
            name: str = str_bslice(val, i + 2, close);
            ev: str = getenv(name);
            if ev == None {
                warnings.append(
                    source
                        + ":"
                        + str(ln)
                        + ": environment variable "
                        + name
                        + " is not set (expanded to empty)"
                );
                ev = "";
            }
            out = out + ev;
            i = close + 1;
            continue;
        }
        out = out + byte_chr(str_byte(val, i));
        i = i + 1;
    }
    return out;
}

def:pub npmrc_parse(text: str, source: str, warnings: list[str]) -> list[NpmrcEntry] {
    out: list[NpmrcEntry] = [];
    lines: list[str] = text.split("\n");
    ln: int = 0;
    for raw in lines {
        ln = ln + 1;
        line: str = raw.strip();
        if line == "" {
            continue;
        }
        c0: str = byte_chr(str_byte(line, 0));
        if c0 == "#" or c0 == ";" {
            continue;
        }
        if c0 == "[" {
            continue;
        }
        eq: int = str_bfind(line, "=");
        if eq < 0 {
            warnings.append(source + ":" + str(ln) + ": ignored line without '='");
            continue;
        }
        key: str = str_bslice(line, 0, eq).strip();
        val: str = str_bslice_from(line, eq + 1).strip();
        # ini `key[] = v` appends to an array; npm has no array keys we act on,
        # so the bare key is kept (the last value wins, as in npm's own reader).
        if key.endswith("[]") {
            key = str_bslice(key, 0, str_nbytes(key) - 2);
        }
        if str_nbytes(val) >= 2 {
            q0: str = byte_chr(str_byte(val, 0));
            q1: str = byte_chr(str_byte(val, str_nbytes(val) - 1));
            if (q0 == "\"" and q1 == "\"") or (q0 == "'" and q1 == "'") {
                val = str_bslice(val, 1, str_nbytes(val) - 1);
            }
        }
        val = npmrc_expand_env(val, source, ln, warnings);
        e: NpmrcEntry = NpmrcEntry(key=key, value=val, line=ln);
        out.append(e);
    }
    return out;
}
