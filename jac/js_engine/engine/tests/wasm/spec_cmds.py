#!/usr/bin/env python3
"""Flatten the wast2json spec fixtures into a line format the standalone Jac
spec driver (engine/tests/wasm/spec_driver.jac) reads without a JSON parser.

    python3 engine/tests/wasm/spec_cmds.py <fixtures/spec dir> <out dir>

Writes <out>/<suite>.cmds per suite. One command per line, space-separated
tokens; strings (module names, export names, registered names) are hex-encoded
UTF-8 so arbitrary names survive. `-` marks "no name / current module".

  module <line> <name|-> <path.wasm>
  register <line> <as-hex> <name|->
  action <line> <name|-> <field-hex> <nargs> <args...>
  assert_return <line> <name|-> <field-hex> <nargs> <args...> <nexp> <exps...>
  assert_get <line> <name|-> <field-hex> <nexp> <exps...>
  assert_trap|assert_exhaustion <line> <name|-> <field-hex> <nargs> <args...>
  assert_trap_module|assert_uninstantiable|assert_unlinkable <line> <path.wasm>
  assert_invalid|assert_malformed <line> <path.wasm>

Values: i32:<u32> i64:<u64> f32:<u32 bits> f64:<u64 bits> (decimal), or
f32:nan:canonical / f32:nan:arithmetic (same for f64), funcref:null,
externref:null, externref:<n>, funcref:<n>.
"""
import json
import os
import sys


def hexs(s):
    return s.encode("utf-8").hex() if s else "-"


def name(n):
    return hexs(n) if n else "-"


def val(v):
    t = v["type"]
    x = v.get("value")
    if t in ("externref", "funcref"):
        return "%s:%s" % (t, "null" if x in (None, "null") else x)
    if isinstance(x, str) and x.startswith("nan:"):
        return "%s:%s" % (t, x)
    if t in ("v128",):
        raise ValueError("v128 unsupported")
    return "%s:%s" % (t, x)


def action(a):
    toks = [name(a.get("module")), hexs(a["field"])]
    if a["type"] == "invoke":
        toks.append(str(len(a["args"])))
        toks += [val(x) for x in a["args"]]
    return toks


def convert(json_path, out_path):
    d = json.load(open(json_path))
    base = os.path.dirname(os.path.abspath(json_path))
    out = []
    for c in d["commands"]:
        t = c["type"]
        ln = str(c["line"])
        try:
            if t == "module":
                out.append(["module", ln, name(c.get("name")), os.path.join(base, c["filename"])])
            elif t == "register":
                out.append(["register", ln, hexs(c["as"]), name(c.get("name"))])
            elif t == "action":
                a = c["action"]
                if a["type"] == "get":
                    out.append(["assert_get", ln] + action(a) + ["-1"])
                else:
                    out.append(["action", ln] + action(a))
            elif t == "assert_return":
                a = c["action"]
                exps = c["expected"]
                if a["type"] == "get":
                    out.append(["assert_get", ln] + action(a) + [str(len(exps))] + [val(e) for e in exps])
                else:
                    out.append(["assert_return", ln] + action(a) + [str(len(exps))] + [val(e) for e in exps])
            elif t in ("assert_trap", "assert_exhaustion"):
                if "action" in c:
                    out.append([t, ln] + action(c["action"]))
                else:
                    out.append(["assert_trap_module", ln, os.path.join(base, c["filename"])])
            elif t in ("assert_uninstantiable", "assert_unlinkable", "assert_invalid", "assert_malformed"):
                if c.get("module_type", "binary") != "binary":
                    continue
                out.append([t, ln, os.path.join(base, c["filename"])])
        except ValueError:
            continue
    with open(out_path, "w") as f:
        for toks in out:
            f.write(" ".join(toks) + "\n")
    return len(out)


def main():
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    total = 0
    for suite in sorted(os.listdir(src)):
        jp = os.path.join(src, suite, suite + ".json")
        if os.path.isfile(jp):
            total += convert(jp, os.path.join(dst, suite + ".cmds"))
    print("wrote %d commands" % total)


if __name__ == "__main__":
    main()
