"""`--env-file=<path>` (Node.js semantics, also bun's flag).

Format, as Node's dotenv parser reads it:
  KEY=value              whitespace around KEY and value is trimmed
  export KEY=value       the `export ` prefix is accepted
  # comment              full-line comments; an unquoted value ends at ` #`
  KEY="a b"  KEY='a b'  KEY=`a b`
                         quoted values keep spaces and may span lines;
                         double-quoted values turn `\\n` into a newline
  KEY=                   empty value
A variable already present in the environment wins over the file (Node and bun
both leave existing variables alone). A missing file is an error (Node:
`node: <path>: not found`, exit 9).
"""

import from engine.src.ffi.libc { setenv, getenv }

"""Variables applied from --env-file that were not already in the environment,
as a flat [key, value, …] list. process.env is built from /proc/self/environ
(the startup block, which setenv does not touch), so process.jac adds these
right after process_populate_env (process_apply_env_file_vars)."""
glob _ENV_FILE_VARS: list[str] = [];

def:pub env_file_pending_vars -> list[str] {
    return _ENV_FILE_VARS;
}

"""Parse dotenv text into a flat [key, value, key, value, …] list."""
def:pub env_file_parse(text: str) -> list[str] {
    out: list[str] = [];
    n: int = len(text);
    i: int = 0;
    while i < n {
        # skip blank space at the start of a line
        while i < n
            and (
                text[i] == " " or text[i] == "\t" or text[i] == "\r" or text[i] == "\n"
            ) {
            i = i + 1;
        }
        if i >= n {
            break;
        }
        if text[i] == "#" {
            while i < n and text[i] != "\n" {
                i = i + 1;
            }
            continue;
        }
        # key (optionally `export `)
        line_end: int = text.find("\n", i);
        if line_end < 0 {
            line_end = n;
        }
        eq: int = text.find("=", i);
        if eq < 0 or eq > line_end {
            i = line_end;
            continue;
        }
        key: str = text[i:eq].strip();
        if key.startswith("export ") {
            key = key[7:].strip();
        }
        if key == "" {
            i = line_end;
            continue;
        }
        # value
        j: int = eq + 1;
        while j < line_end and (text[j] == " " or text[j] == "\t") {
            j = j + 1;
        }
        val: str = "";
        if j < n and (text[j] == "\"" or text[j] == "'" or text[j] == "`") {
            q: str = text[j];
            close: int = text.find(q, j + 1);
            if close < 0 {
                # unterminated: Node takes the rest of the line
                val = text[j + 1:line_end].rstrip();
                i = line_end;
            } else {
                val = text[j + 1:close];
                if q == "\"" {
                    val = val.replace("\\n", "\n");
                }
                i = text.find("\n", close);
                if i < 0 {
                    i = n;
                }
            }
        } else {
            raw: str = text[j:line_end];
            hash: int = raw.find(" #");
            if hash >= 0 {
                raw = raw[0:hash];
            }
            if raw.startswith("#") {
                raw = "";
            }
            val = raw.rstrip();
            i = line_end;
        }
        out.append(key);
        out.append(val);
    }
    return out;
}

"""Apply parsed pairs to the process environment without overriding existing
variables: the OS environment (setenv, so spawned processes inherit them) and
process.env (recorded for process_apply_env_file_vars). Returns the number of
variables set."""
def:pub env_file_apply(pairs: list[str]) -> int {
    count: int = 0;
    k: int = 0;
    while k + 1 < len(pairs) {
        if getenv(pairs[k]) == None {
            setenv(pairs[k], pairs[k + 1], 0);
            _ENV_FILE_VARS.append(pairs[k]);
            _ENV_FILE_VARS.append(pairs[k + 1]);
            count = count + 1;
        }
        k = k + 2;
    }
    return count;
}

"""Load one --env-file. Returns the number of variables set, or -1 when the
file cannot be read."""
def:pub env_file_load(path: str) -> int {
    text: str = "";
    try {
        text = open(path).read();
    } except Exception {
        return -1;
    }
    return env_file_apply(env_file_parse(text));
}
