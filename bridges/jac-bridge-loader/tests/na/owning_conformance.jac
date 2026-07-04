# Owning-wrapper conformance: prove the na and CPython runtimes are
# observationally identical for the nullable Option<Ref> surface, against the
# SAME libjac_bridge_owning.so.
#
# na side: synthesize Jac source from the .so's metadata, nacompile it with an
# appended probe that prints one line per observation, run the binary, diff the
# output against the CPython loader.  Gated on the LLVM shim; skips without it.
import os;
import subprocess;
import sys;
import tempfile;
import shutil;
import from pathlib { Path }
import from jaclang.compiler.rust_bridge { load_bridge }
import from jaclang.compiler.rust_bridge._blob { parse }
import from jaclang.compiler.rust_bridge._elf { read_jac_bridge_section }
import from jaclang.compiler.rust_bridge._synth { render_na_source }


glob REPO = Path(__file__).resolve().parents[4],
     JAC = REPO / "jac",
     LOADER = REPO / "bridges" / "jac-bridge-loader",
     SO = REPO / "bridges" / "target" / "release" / "libjac_bridge_owning.so",
     SHIM = JAC / "zig-out" / "lib" / "libjacllvm.so",
     # (pattern, haystack) -> find() text or None; brackets make "" vs None visible.
     FIND_CASES = [
         (r"\d+", "abc123def"),
         (r"\d+", "no digits"),
         (r"", "anything"),
         (r"\w+", "hello world")
     ],
     # (pattern, haystack, group) -> captures().name(group): text / "" / None.
     CAPS_CASES = [
         (r"(?P<num>\d+)-(?P<rest>\d+)", "nothing here", "num"),
         (r"(?P<num>\d+)-(?P<rest>\d+)", "12-34 today", "num"),
         (r"(?P<num>\d+)-(?P<rest>\d+)", "12-34 today", "nope"),
         (r"(?P<a>x)?(?P<b>y)", "y", "a"),
         (r"(?P<z>\d*)", "abc", "z")
     ],
     # (pattern, haystack, group) -> captures().name_match(group).as_str(): the NESTED
     # wrapper path (a Captures produces a Match).
     NAME_MATCH_CASES = [
         (r"(?P<num>\d+)-(?P<rest>\d+)", "12-34 today", "num"),
         (r"(?P<num>\d+)-(?P<rest>\d+)", "12-34 today", "nope"),
         (r"(?P<a>x)?(?P<b>y)", "y", "a"),
         (r"(?P<num>\d+)", "nothing here", "num"),
         (r"(?P<z>\d*)", "abc", "z")
     ],
     # (pattern, haystack) -> find_iter cursor drained to exhaustion.
     CURSOR_CASES = [
         (r"\d+", "a1 b22 c333"),
         (r"\d+", "no digits at all"),
         (r"\w+", "hi there world"),
         (r"x", "")
     ],
     # (pattern, haystack) -> split drain cursor exhausted.
     SPLIT_CASES = [
         (r",\s*", "a, bb,ccc"),
         (r"-", "x-y-z"),
         (r"\d+", "no numbers here"),
         (r"\d+", "1a2b3")
     ],
     # (pattern, haystack) -> replace_all driven by the "upper" callback.
     REPLACE_UPPER_CASES = [
         (r"[a-z]+", "hello world"),
         (r"\w+", "MixEd caSe x"),
         (r"z+", "no zeds here"),
         (r"\w+", "")
     ],
     # (pattern, haystack) -> replace_all driven by a SECOND callback that wraps in <>.
     REPLACE_BRACKET_CASES = [
         (r"\d+", "a1b22c333"),
         (r"-", "x-y-z"),
         (r"\d+", "no digits")
     ];


def _replace_label(pat: str, text: str, kind: str) -> str {
    return f"replace {repr(pat)} {repr(text)} {kind} = ";
}


def _cursor_label(pat: str, text: str) -> str {
    return f"iter {repr(pat)} {repr(text)} = ";
}


def _split_label(pat: str, text: str) -> str {
    return f"split {repr(pat)} {repr(text)} = ";
}


def _find_label(pat: str, text: str) -> str {
    return f"find {repr(pat)} {repr(text)} = ";
}


def _caps_label(pat: str, text: str, group: str) -> str {
    return f"caps {repr(pat)} {repr(text)} name({repr(group)}) = ";
}


def _nm_label(pat: str, text: str, group: str) -> str {
    return f"nmatch {repr(pat)} {repr(text)} name_match({repr(group)}) = ";
}


def cpython_side -> list {
    owning = load_bridge(str(SO));
    lines = [];
    for case in FIND_CASES {
        pat = case[0];
        text = case[1];
        re = owning.Regex(pat);
        m = re.find(text);
        if m is None {
            lines.append(_find_label(pat, text) + "None");
        } else {
            lines.append(_find_label(pat, text) + "[" + m.as_str() + "]");
            m.close();
        }
        re.close();
    }
    for case in CAPS_CASES {
        pat = case[0];
        text = case[1];
        group = case[2];
        label = _caps_label(pat, text, group);
        re = owning.Regex(pat);
        c = re.captures(text);
        if c is None {
            lines.append(label + "caps=None");
        } else {
            v = c.name(group);
            if v is None {
                lines.append(label + "None");
            } else {
                lines.append(label + "[" + v + "]");
            }
            c.close();
        }
        re.close();
    }
    for case in NAME_MATCH_CASES {
        pat = case[0];
        text = case[1];
        group = case[2];
        label = _nm_label(pat, text, group);
        re = owning.Regex(pat);
        c = re.captures(text);
        if c is None {
            lines.append(label + "caps=None");
        } else {
            mm = c.name_match(group);
            if mm is None {
                lines.append(label + "None");
            } else {
                lines.append(label + "[" + mm.as_str() + "]");
                mm.close();
            }
            c.close();
        }
        re.close();
    }
    for case in CURSOR_CASES {
        pat = case[0];
        text = case[1];
        re = owning.Regex(pat);
        cur = re.find_iter(text);
        acc = "";
        m = cur.next();
        while m is not None {
            acc = acc + m.as_str() + "|";
            m.close();
            m = cur.next();
        }
        lines.append(_cursor_label(pat, text) + "[" + acc + "]");
        cur.close();
        re.close();
    }
    for case in SPLIT_CASES {
        pat = case[0];
        text = case[1];
        re = owning.Regex(pat);
        dr = re.split(text);
        acc = "";
        s = dr.next();
        while s is not None {
            acc = acc + s + "|";
            s = dr.next();
        }
        lines.append(_split_label(pat, text) + "[" + acc + "]");
        dr.close();
        re.close();
    }
    for case in REPLACE_UPPER_CASES {
        pat = case[0];
        text = case[1];
        re = owning.Regex(pat);
        out = re.replace_all(text, lambda m : m.upper());
        lines.append(_replace_label(pat, text, "upper") + "[" + out + "]");
        re.close();
    }
    for case in REPLACE_BRACKET_CASES {
        pat = case[0];
        text = case[1];
        re = owning.Regex(pat);
        out = re.replace_all(text, lambda m : "<" + m + ">");
        lines.append(_replace_label(pat, text, "bracket") + "[" + out + "]");
        re.close();
    }
    return [
        ln
        for ln in "\n".join(lines).splitlines()
        if ln.strip()
    ];
}


def _jac_str(s: str) -> str {
    # embed a Python string as a Jac double-quoted literal
    return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
}


def na_side -> list {
    meta = parse(read_jac_bridge_section(str(SO)));
    src = render_na_source(meta, SO.name).source;

    # The na trampoline: module-level `def:pub` C-ABI thunks the callback ABI
    # calls back into.
    mb = f"jac_{meta.module_name}_make_buf";
    thunks = """
def:pub owning_upper_cb(arg_ptr: int, arg_len: int, out_buf: int, out_err: int) -> i32 {
    s = __jac_str_from_raw(arg_ptr, arg_len);
    r = s.upper();
    __MB__(r, strlen(r), out_buf);
    return 0;
}

def:pub owning_bracket_cb(arg_ptr: int, arg_len: int, out_buf: int, out_err: int) -> i32 {
    s = __jac_str_from_raw(arg_ptr, arg_len);
    r = "<" + s + ">";
    __MB__(r, strlen(r), out_buf);
    return 0;
}
""".replace(
        "__MB__", mb
    );
    src = src + thunks;

    probe = ["\nwith entry {"];
    for case in FIND_CASES {
        pat = case[0];
        text = case[1];
        label = _find_label(pat, text);
        probe.append("    re = Regex(" + _jac_str(pat) + ");");
        probe.append("    m = re.find(" + _jac_str(text) + ");");
        probe.append("    if m is not None {");
        probe.append("        om: OwnedMatch = m;");
        probe.append(
            "        print(" + _jac_str(label + "[") + " + om.as_str() + " + _jac_str(
                "]"
            ) + ");"
        );
        probe.append("        om.close();");
        probe.append("    } else {");
        probe.append("        print(" + _jac_str(label + "None") + ");");
        probe.append("    }");
        probe.append("    re.close();");
    }
    for case in CAPS_CASES {
        pat = case[0];
        text = case[1];
        group = case[2];
        label = _caps_label(pat, text, group);
        probe.append("    re = Regex(" + _jac_str(pat) + ");");
        probe.append("    c = re.captures(" + _jac_str(text) + ");");
        probe.append("    if c is not None {");
        probe.append("        oc: OwnedCaptures = c;");
        probe.append("        n = oc.name(" + _jac_str(group) + ");");
        probe.append("        if n is not None {");
        probe.append(
            "            print(" + _jac_str(label + "[") + " + n + " + _jac_str("]") + ");"
        );
        probe.append("        } else {");
        probe.append("            print(" + _jac_str(label + "None") + ");");
        probe.append("        }");
        probe.append("        oc.close();");
        probe.append("    } else {");
        probe.append("        print(" + _jac_str(label + "caps=None") + ");");
        probe.append("    }");
        probe.append("    re.close();");
    }
    for case in NAME_MATCH_CASES {
        pat = case[0];
        text = case[1];
        group = case[2];
        label = _nm_label(pat, text, group);
        probe.append("    re = Regex(" + _jac_str(pat) + ");");
        probe.append("    c = re.captures(" + _jac_str(text) + ");");
        probe.append("    if c is not None {");
        probe.append("        oc: OwnedCaptures = c;");
        probe.append("        mm = oc.name_match(" + _jac_str(group) + ");");
        probe.append("        if mm is not None {");
        probe.append("            om2: OwnedMatch = mm;");
        probe.append(
            "            print(" + _jac_str(label + "[") + " + om2.as_str() + " + _jac_str(
                "]"
            ) + ");"
        );
        probe.append("            om2.close();");
        probe.append("        } else {");
        probe.append("            print(" + _jac_str(label + "None") + ");");
        probe.append("        }");
        probe.append("        oc.close();");
        probe.append("    } else {");
        probe.append("        print(" + _jac_str(label + "caps=None") + ");");
        probe.append("    }");
        probe.append("    re.close();");
    }
    for case in CURSOR_CASES {
        pat = case[0];
        text = case[1];
        label = _cursor_label(pat, text);
        probe.append("    re = Regex(" + _jac_str(pat) + ");");
        probe.append("    cur = re.find_iter(" + _jac_str(text) + ");");
        probe.append("    acc = \"\";");
        probe.append("    m = cur.next();");
        probe.append("    while m is not None {");
        probe.append("        om: OwnedMatch = m;");
        probe.append("        acc = acc + om.as_str() + \"|\";");
        probe.append("        om.close();");
        probe.append("        m = cur.next();");
        probe.append("    }");
        probe.append(
            "    print(" + _jac_str(label + "[") + " + acc + " + _jac_str("]") + ");"
        );
        probe.append("    cur.close();");
        probe.append("    re.close();");
    }
    for case in SPLIT_CASES {
        pat = case[0];
        text = case[1];
        label = _split_label(pat, text);
        probe.append("    re = Regex(" + _jac_str(pat) + ");");
        probe.append("    dr = re.split(" + _jac_str(text) + ");");
        probe.append("    acc = \"\";");
        probe.append("    s = dr.next();");
        probe.append("    while s is not None {");
        probe.append("        acc = acc + s + \"|\";");
        probe.append("        s = dr.next();");
        probe.append("    }");
        probe.append(
            "    print(" + _jac_str(label + "[") + " + acc + " + _jac_str("]") + ");"
        );
        probe.append("    dr.close();");
        probe.append("    re.close();");
    }
    probe.append("    cb_up = owning_upper_cb as int;");
    probe.append("    cb_br = owning_bracket_cb as int;");
    for case in REPLACE_UPPER_CASES {
        pat = case[0];
        text = case[1];
        label = _replace_label(pat, text, "upper");
        probe.append("    re = Regex(" + _jac_str(pat) + ");");
        probe.append("    out = re.replace_all(" + _jac_str(text) + ", cb_up);");
        probe.append(
            "    print(" + _jac_str(label + "[") + " + out + " + _jac_str("]") + ");"
        );
        probe.append("    re.close();");
    }
    for case in REPLACE_BRACKET_CASES {
        pat = case[0];
        text = case[1];
        label = _replace_label(pat, text, "bracket");
        probe.append("    re = Regex(" + _jac_str(pat) + ");");
        probe.append("    out = re.replace_all(" + _jac_str(text) + ", cb_br);");
        probe.append(
            "    print(" + _jac_str(label + "[") + " + out + " + _jac_str("]") + ");"
        );
        probe.append("    re.close();");
    }
    probe.append("}");
    src = src + "\n".join(probe);

    td = tempfile.mkdtemp();
    try {
        jac_file = Path(td) / "owning_conf.jac";
        jac_file.write_text(src);
        binp = Path(td) / "owning_conf";
        env = dict(os.environ);
        env["JAC_LLVM_SHIM"] = str(SHIM);
        env["PYTHONPATH"] = str(JAC);
        r = subprocess.run(
            [
                sys.executable,
                "-m",
                "jaclang",
                "nacompile",
                str(jac_file),
                "-o",
                str(binp)
            ],
            cwd=str(JAC),
            env=env,
            capture_output=True,
            text=True,
            timeout=600
        );
        if not binp.exists() {
            raise RuntimeError(
                "nacompile failed:\n" + r.stdout[-2000:] + r.stderr[-2000:]
            );
        }
        runenv = dict(os.environ);
        runenv["LD_LIBRARY_PATH"] = str(SO.parent);
        run = subprocess.run(
            [str(binp)], capture_output=True, text=True, timeout=60, env=runenv
        );
        if run.returncode != 0 {
            raise RuntimeError(
                f"binary exited {run.returncode}:\n{run.stdout}\n{run.stderr}"
            );
        }
        return [
            ln
            for ln in run.stdout.splitlines()
            if ln.strip()
        ];
    } finally {
        shutil.rmtree(td, ignore_errors=True);
    }
}


test "owning na cpython conformance" {
    if not SO.is_file() {
        return;
    }
    if not (SHIM.is_file() or os.environ.get("JAC_LLVM_SHIM")) {
        return;
    }
    assert cpython_side() == na_side();
}
