"""The root help (engine/src/pm/help/root.txt) may only advertise what
js_engine supports: every command it lists is dispatched by pm/cli.jac and
every flag is known to pm_root_flag_kind (main.jac implements the runtime
ones). Also checks the --env-file parser against node's results.

Run from the repo root:  jac run --backend native engine/tests/unit/test_pm_help.jac
"""

import from engine.src.ffi.libc { fflush, _exit }
import from engine.src.pm.cli {
    pm_root_flag_kind,
    pm_root_short_flag,
    pm_canonical_command
}
import from engine.src.pm.fsx { fsx_read_text }
import from engine.src.builtins.env_file { env_file_parse }

glob _ok: int = 0,
     _fail: int = 0;

def check(cond: bool, name: str) {
    if cond {
        _ok = _ok + 1;
    } else {
        _fail = _fail + 1;
        print("FAIL: " + name);
    }
}

def check_eq(got: str, want: str, name: str) {
    if got == want {
        _ok = _ok + 1;
    } else {
        _fail = _fail + 1;
        print("FAIL: " + name + " — got '" + got + "' want '" + want + "'");
    }
}

def tokens(line: str) -> list[str] {
    out: list[str] = [];
    for t in line.split(" ") {
        if t != "" {
            out.append(t);
        }
    }
    return out;
}

with entry {
    text: str = fsx_read_text("engine/src/pm/help/root.txt");
    check(len(text) > 0, "root help loads");
}

glob implemented: list[str] = ["run", "x", "install", "add"];
with entry {
    in_commands: bool = False;
    in_flags: bool = False;
    n_cmds: int = 0;
    n_flags: int = 0;
    for line in text.split("\n") {
        if line == "Commands:" {
            in_commands = True;
            in_flags = False;
            continue;
        }
        if line == "Flags:" {
            in_flags = True;
            in_commands = False;
            continue;
        }
        if line == "" or not line.startswith("  ") {
            continue;
        }
        if in_commands {
            if line.startswith("    ") or line.startswith("  <command>") {
                continue;
            }  # continuation / generic row
            toks: list[str] = tokens(line);
            if len(toks) == 0 {
                continue;
            }
            cmd: str = toks[0];
            n_cmds = n_cmds + 1;
            check(
                pm_canonical_command(cmd) in implemented,
                "command listed is implemented: " + cmd
            );
        }
        if in_flags {
            for t in tokens(line) {
                tok: str = t;
                if tok.endswith(",") {
                    tok = tok[0:len(tok) - 1];
                }
                if not tok.startswith("-") {
                    break;
                }
                if tok.startswith("--") {
                    name: str = tok[2:];
                    eq: int = name.find("=");
                    if eq >= 0 {
                        name = name[0:eq];
                    }
                    n_flags = n_flags + 1;
                    check(pm_root_flag_kind(name) != 0, "root flag known: --" + name);
                    if tok.find("=<val>") >= 0 {
                        check(
                            pm_root_flag_kind(name) == 2,
                            "root flag takes a value: --" + name
                        );
                    } else {
                        check(
                            pm_root_flag_kind(name) == 1,
                            "root flag is a switch: --" + name
                        );
                    }
                } else {
                    check(
                        pm_root_short_flag(tok[1:2]) != "",
                        "short root flag known: " + tok
                    );
                }
            }
        }
    }
    check(n_cmds >= 4, "commands section found (" + str(n_cmds) + ")");
    check(n_flags >= 20, "flags section found (" + str(n_flags) + ")");
    check(text.find("bun.com") < 0, "no bun.com links in the root help");
    check(
        text.find("@VERSION@") >= 0 and text.find("@BUN_COMPAT@") >= 0,
        "version placeholders present"
    );

    # ── --env-file parser (node 20 results for the same input) ───────────────
    pairs: list[str] = env_file_parse(
        "A=1\nexport B=\"two words\"\n# c\nC='sq' # trailing\nD=`bt`\nE=\"line1\\nline2\"\nF=unquoted # comment\nG=\nH\n  I = spaced  \n"
    );
    check_eq(str(len(pairs)), "16", "env: 8 pairs");
    if len(pairs) == 16 {
        check_eq(pairs[0] + "=" + pairs[1], "A=1", "env: plain");
        check_eq(
            pairs[2] + "=" + pairs[3], "B=two words", "env: export + double quotes"
        );
        check_eq(
            pairs[4] + "=" + pairs[5], "C=sq", "env: single quotes, trailing comment"
        );
        check_eq(pairs[6] + "=" + pairs[7], "D=bt", "env: backticks");
        check_eq(
            pairs[8] + "=" + pairs[9], "E=line1\nline2", "env: \\n in double quotes"
        );
        check_eq(
            pairs[10] + "=" + pairs[11], "F=unquoted", "env: inline comment stripped"
        );
        check_eq(pairs[12] + "=" + pairs[13], "G=", "env: empty value");
        check_eq(
            pairs[14] + "=" + pairs[15],
            "I=spaced",
            "env: whitespace trimmed, line without = skipped"
        );
    }
    multi: list[str] = env_file_parse("M=\"a\nb\"\nN=2\n");
    check(
        len(multi) == 4 and multi[1] == "a\nb" and multi[2] == "N",
        "env: multi-line quoted value"
    );

    print("pm_help: passed=" + str(_ok) + " failed=" + str(_fail));
    fflush(0);
    if _fail > 0 {
        _exit(1);
    }
}
