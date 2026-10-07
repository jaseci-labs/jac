"""
bun-compatible package-manager command line for js_engine (engine/src/pm).

`js_engine` is the bun replacement (plan decision D2): the commands bun has —
install / add / remove / update / outdated / audit / link / unlink / publish /
patch / pm / info / why / x / run — are subcommands of the same binary, parsed
with bun 1.3.13's grammar. `js_engine <file>` keeps working: main.jac calls
pm_try_dispatch() first and only falls through to the Node-style argv parser
when argv[1] is not one of these command names (as in bun, a command name wins
over a file of the same name; `./install` still runs the file).

Phase P0 (docs/PACKAGE_MANAGER_PLAN.md §4): the grammar, the configuration
(bunfig.toml / .npmrc / env / flags — config.jac) and the help texts are in
place. Help output is the byte-for-byte text of bun 1.3.13 (help/*.txt,
captured with `bun <cmd> --help`). Every real operation still ends in
"not implemented"; P1 adds them.

Observed bun 1.3.13 behaviour reproduced here (tools/pm_diff records it):
  * unknown flags are ignored (`bun install --bogus` exits 0);
  * `bun add` / `bun remove` with no package print the version banner and the
    command's help on stdout, "error: no package specified to add" on stderr,
    and exit 0;
  * `bun x --help` (and `bun x` alone) print bunx's help on STDERR and exit 1;
  * `bun pm` prints help and exits 0; `bun pm <unknown>` prints the help, then
    `error: "<unknown>" unknown command` on stderr, and exits 1;
  * `bun run <missing>` -> `error: Script not found "<missing>"`, exit 1.
"""

import from engine.src.ffi.libc { write, getenv, getcwd, chdir }
import from engine.src.builtins.path_utils { path_abspath, path_dirname }
import from engine.src.version { JS_ENGINE_VERSION }
import from engine.src.pm.config {
    PmArgs,
    PmConfig,
    pm_config_load,
    pm_config_describe
}
import from engine.src.pm.install { pm_cmd_install }
import from engine.src.pm.add { pm_cmd_add }
import from engine.src.pm.remove { pm_cmd_remove }
import from engine.src.pm.pm_trust {
    pm_cmd_default_trusted,
    pm_cmd_untrusted,
    pm_cmd_trust
}
import from engine.src.pm.run {
    pm_run_script,
    pm_scripts_listing,
    pm_x_local,
    pm_find_project_dir
}
import from engine.src.pm.fsx { fsx_cwd, fsx_readlink }
import from engine.src.pm.lifecycle { lifecycle_force_node_shim }

"""The bun release whose behaviour and help texts this CLI reproduces."""
glob:pub PM_BUN_COMPAT_VERSION: str = "1.3.13";

"""Flags accepted in front of the command (`js_engine [flags] <command> …`):
everything the root help lists, plus the engine's Node-style flags. 0 =
unknown, 1 = switch, 2 = takes a value. main.jac's parser implements the
runtime ones; this table lets the dispatcher skip over them to find the command
and tells it which ones apply to package-manager commands. Unknown flags are
skipped like switches (bun ignores flags it does not know)."""
def:pub pm_root_flag_kind(name: str) -> int {
    if name == "smol"
        or name == "if-present"
        or name == "expose-gc"
        or name == "no-deprecation"
        or name == "throw-deprecation"
        or name == "zero-fill-buffers"
        or name == "silent"
        or name == "version"
        or name == "bun"
        or name == "help"
        or name == "no-warnings"
        or name == "preserve-symlinks"
        or name == "preserve-symlinks-main"
        or name == "gc"
        or name == "experimental-require-module"
        or name == "no-experimental-require-module"
        or name == "ast"
        or name == "bc"
        or name == "norun"
        or name == "debug"
        or name == "ic"
        or name == "nogc"
        or name == "no-gc" {
        return 1;
    }
    if name == "preload"
        or name == "require"
        or name == "import"
        or name == "eval"
        or name == "print"
        or name == "title"
        or name == "unhandled-rejections"
        or name == "console-depth"
        or name == "env-file"
        or name == "cwd"
        or name == "config"
        or name == "input-type"
        or name == "loader"
        or name == "experimental-loader"
        or name == "conditions" {
        return 2;
    }
    return 0;
}

"""Short forms of the root flags (`-v`, `-e code`, `-r mod`, `-c file`, …)."""
def:pub pm_root_short_flag(c: str) -> str {
    if c == "v" {
        return "version";
    }
    if c == "h" {
        return "help";
    }
    if c == "e" {
        return "eval";
    }
    if c == "p" {
        return "print";
    }
    if c == "r" {
        return "preload";
    }
    if c == "c" {
        return "config";
    }
    if c == "b" {
        return "bun";
    }
    if c == "C" {
        return "conditions";
    }
    return "";
}

"""What the dispatcher needs from the root flags."""
obj PmGlobal {
    has version: bool = False,
        help: bool = False,
        silent: bool = False,
        bun: bool = False,
        if_present: bool = False,
        eval: bool = False,
        cwd: str = "",
        config: str = "",
        next: int = 1;
}

# index of the first non-flag argument (the command)
def _pm_scan_root_flags(argv: list[str]) -> PmGlobal {
    g: PmGlobal = PmGlobal();
    n: int = len(argv);
    i: int = 1;
    while i < n {
        a: str = argv[i];
        if len(a) < 2 or a[0] != "-" or a == "--" {
            break;
        }
        name: str = "";
        val: str = "";
        has_val: bool = False;
        if a[1] == "-" {
            body: str = a[2:];
            name = body;
            eq: int = body.find("=");
            if eq >= 0 {
                name = body[0:eq];
                val = body[eq + 1:];
                has_val = True;
            }
        } else {
            name = pm_root_short_flag(a[1:2]);
            if name == "" {
                name = a[1:];
            } elif len(a) > 2 {
                val = a[2:];
                has_val = True;
            }
        }
        if pm_root_flag_kind(name) == 2 and not has_val and i + 1 < n {
            val = argv[i + 1];
            i = i + 1;
        }
        if name == "version" {
            g.version = True;
        } elif name == "help" {
            g.help = True;
        } elif name == "silent" {
            g.silent = True;
        } elif name == "bun" {
            g.bun = True;
        } elif name == "if-present" {
            g.if_present = True;
        } elif name == "eval" or name == "print" {
            g.eval = True;
        } elif name == "cwd" {
            g.cwd = val;
        } elif name == "config" {
            g.config = val;
        }
        i = i + 1;
    }
    g.next = i;
    return g;
}

glob PM_PROG: str = "js_engine";

def _out(s: str) {
    write(1, s, len(s));
}
def _err(s: str) {
    write(2, s, len(s));
}

# ── Command names ─────────────────────────────────────────────────────────────

"""Canonical command for a bun command name or alias; "" when not a command."""
def:pub pm_canonical_command(name: str) -> str {
    if name == "install" or name == "i" {
        return "install";
    }
    if name == "add" or name == "a" {
        return "add";
    }
    if name == "remove" or name == "rm" or name == "r" {
        return "remove";
    }
    if name == "update" {
        return "update";
    }
    if name == "outdated" {
        return "outdated";
    }
    if name == "audit" {
        return "audit";
    }
    if name == "link" {
        return "link";
    }
    if name == "unlink" {
        return "unlink";
    }
    if name == "publish" {
        return "publish";
    }
    if name == "patch" {
        return "patch";
    }
    if name == "pm" {
        return "pm";
    }
    if name == "info" {
        return "info";
    }
    if name == "why" {
        return "why";
    }
    if name == "x" {
        return "x";
    }
    if name == "run" {
        return "run";
    }
    return "";
}

def _pm_pm_subcommand_known(sub: str) -> bool {
    return sub == "scan"
        or sub == "pack"
        or sub == "bin"
        or sub == "ls"
        or sub == "why"
        or sub == "whoami"
        or sub == "view"
        or sub == "version"
        or sub == "pkg"
        or sub == "hash"
        or sub == "hash-string"
        or sub == "hash-print"
        or sub == "cache"
        or sub == "migrate"
        or sub == "untrusted"
        or sub == "trust"
        or sub == "default-trusted";
}

# ── Flag tables (bun 1.3.13 `--help` for the install family, run and x) ──────

def _pm_flag_takes_value(name: str) -> bool {
    return name == "config"
        or name == "ca"
        or name == "cafile"
        or name == "cache-dir"
        or name == "cwd"
        or name == "backend"
        or name == "registry"
        or name == "concurrent-scripts"
        or name == "network-concurrency"
        or name == "omit"
        or name == "linker"
        or name == "minimum-release-age"
        or name == "cpu"
        or name == "os"
        or name == "filter"
        or name == "patches-dir"
        or name == "access"
        or name == "tag"
        or name == "otp"
        or name == "auth-type"
        or name == "gzip-level"
        or name == "destination"
        or name == "filename"
        or name == "package"
        or name == "elide-lines"
        or name == "shell";
}

def _pm_flag_is_switch(name: str) -> bool {
    return name == "yarn"
        or name == "production"
        or name == "no-save"
        or name == "save"
        or name == "dry-run"
        or name == "frozen-lockfile"
        or name == "force"
        or name == "no-cache"
        or name == "silent"
        or name == "quiet"
        or name == "verbose"
        or name == "no-progress"
        or name == "no-summary"
        or name == "no-verify"
        or name == "ignore-scripts"
        or name == "trust"
        or name == "global"
        or name == "save-text-lockfile"
        or name == "lockfile-only"
        or name == "dev"
        or name == "optional"
        or name == "peer"
        or name == "exact"
        or name == "analyze"
        or name == "only-missing"
        or name == "help"
        or name == "latest"
        or name == "interactive"
        or name == "recursive"
        or name == "commit"
        or name == "tolerate-republish"
        or name == "all"
        or name == "bun"
        or name == "no-install"
        or name == "workspaces"
        or name == "parallel"
        or name == "sequential"
        or name == "no-exit-on-error"
        or name == "if-present"
        or name == "json";
}

"""Repeatable flags accumulate (values joined with a newline)."""
def _pm_flag_repeats(name: str) -> bool {
    return name == "omit" or name == "filter" or name == "ca";
}

def _pm_short_to_long(c: str) -> str {
    if c == "c" {
        return "config";
    }
    if c == "y" {
        return "yarn";
    }
    if c == "p" {
        return "production";
    }
    if c == "f" {
        return "force";
    }
    if c == "g" {
        return "global";
    }
    if c == "d" {
        return "dev";
    }
    if c == "E" {
        return "exact";
    }
    if c == "a" {
        return "analyze";
    }
    if c == "h" {
        return "help";
    }
    if c == "i" {
        return "interactive";
    }
    if c == "r" {
        return "recursive";
    }
    if c == "F" {
        return "filter";
    }
    if c == "b" {
        return "bun";
    }
    if c == "P" {
        return "package";
    }
    return "";
}

def _pm_set_flag(args: PmArgs, name: str, val: str) -> None {
    if name in args.flags {
        if _pm_flag_repeats(name) {
            args.flags[name] = args.flags[name] + "\n" + val;
        } else {
            args.flags[name] = val;
        }
        return;
    }
    args.flag_order.append(name);
    args.flags[name] = val;
}

"""Parse argv[start:] with bun's grammar: `--flag`, `--flag=value`, `--flag value`
for value flags, clustered short flags (`-dE`), `-c value` / `-cvalue`, `--`
ends flag parsing. Unknown flags are recorded and otherwise ignored (bun)."""
def:pub pm_parse_args(cmd: str, argv: list[str], start: int) -> PmArgs {
    args: PmArgs = PmArgs();
    args.command = cmd;
    i: int = start;
    n: int = len(argv);
    after_dd: bool = False;
    while i < n {
        a: str = argv[i];
        if after_dd {
            args.passthrough.append(a);
            i = i + 1;
            continue;
        }
        # `run <script> …` / `x <bin> …`: everything after the target belongs to it
        if (cmd == "run" or cmd == "x") and len(args.positionals) > 0 {
            args.passthrough.append(a);
            i = i + 1;
            continue;
        }
        if a == "--" {
            after_dd = True;
            i = i + 1;
            continue;
        }
        if len(a) >= 3 and a[0] == "-" and a[1] == "-" {
            body: str = a[2:];
            name: str = body;
            val: str = "";
            has_val: bool = False;
            eq: int = body.find("=");
            if eq >= 0 {
                name = body[0:eq];
                val = body[eq + 1:];
                has_val = True;
            }
            if name == "help" {
                args.help = True;
                i = i + 1;
                continue;
            }
            if _pm_flag_takes_value(name) and not has_val {
                if i + 1 < n {
                    val = argv[i + 1];
                    i = i + 1;
                }
                has_val = True;
            }
            if not _pm_flag_takes_value(name) and not _pm_flag_is_switch(name) {
                args.unknown.append(a);
            }
            if not has_val {
                val = "true";
            }
            _pm_set_flag(args, name, val);
            i = i + 1;
            continue;
        }
        if len(a) >= 2 and a[0] == "-" {
            j: int = 1;
            while j < len(a) {
                c: str = a[j];
                long: str = _pm_short_to_long(c);
                if long == "" {
                    args.unknown.append("-" + c);
                    j = j + 1;
                    continue;
                }
                if long == "help" {
                    args.help = True;
                    j = j + 1;
                    continue;
                }
                if _pm_flag_takes_value(long) {
                    rest: str = a[j + 1:];
                    sval: str = "";
                    if rest != "" {
                        if rest[0] == "=" {
                            rest = rest[1:];
                        }
                        sval = rest;
                    } elif i + 1 < n {
                        sval = argv[i + 1];
                        i = i + 1;
                    }
                    _pm_set_flag(args, long, sval);
                    j = len(a);
                    continue;
                }
                _pm_set_flag(args, long, "true");
                j = j + 1;
            }
            i = i + 1;
            continue;
        }
        args.positionals.append(a);
        i = i + 1;
    }
    return args;
}

# ── Help texts (engine/src/pm/help/<name>.txt, verbatim bun 1.3.13) ──────────

"""The engine directory (…/js_engine/engine): $JAC_ENGINE_ROOT, else derived from
the binary's location the same way vm/event_loop.jac does for the JS builtins."""
def _pm_engine_root(argv0: str) -> str {
    eroot: str = "";
    env_root: str = getenv("JAC_ENGINE_ROOT");
    if env_root != None and env_root != "" {
        eroot = env_root;
    } else {
        exe: str = "";
        if argv0.find("/") < 0 {
            # exec'd through PATH (e.g. as the lifecycle `node` shim): argv0 is
            # bare, so locate the real binary instead of guessing from the cwd
            exe = fsx_readlink("/proc/self/exe");
        }
        if exe == "" {
            cwd: str = getcwd(0, 0);
            if cwd == None {
                cwd = ".";
            }
            exe = path_abspath(argv0, cwd);
        }
        eroot = path_dirname(path_dirname(exe));
    }
    if eroot.endswith("/engine") {
        return eroot;
    }
    return eroot + "/engine";
}

def _pm_is_word_char(c: str) -> bool {
    if c == "" {
        return False;
    }
    o: int = ord(c);
    if o >= 48 and o <= 57 {
        return True;
    }
    if o >= 65 and o <= 90 {
        return True;
    }
    if o >= 97 and o <= 122 {
        return True;
    }
    return c == "_" or c == "-";
}

"""Print bun's help text as js_engine's: the command word `bun` becomes
`js_engine` and `bunx` becomes `js_engine x`, matched as whole words
(`--bun`, `bunfig.toml`, `bun.lock`, `Bun's` and `bundle` are left alone) and
skipped on lines that carry a URL (`Learn more about bun install: https://…`
keeps pointing at bun's docs). tools/pm_diff applies the same rule to bun's
output before comparing (help-diff), so the command files stay verbatim
captures. The exception is root.txt: its first line (what js_engine is, with
its own version) and its footer links (jaclang.org docs, the Jaseci GitHub
repository, the Jac Discord) are js_engine's own; help-diff maps bun's
corresponding lines onto them."""
def:pub pm_localize_help(text: str) -> str {
    out: list[str] = [];
    lines: list[str] = text.split("\n");
    li: int = 0;
    while li < len(lines) {
        line: str = lines[li];
        if li > 0 {
            out.append("\n");
        }
        if line.find("https://") >= 0 or line.find("bun") < 0 {
            out.append(line);
            li = li + 1;
            continue;
        }
        n: int = len(line);
        i: int = 0;
        seg: int = 0;
        while i < n {
            if line[i] == "b"
                and i + 2 < n
                and line[i + 1] == "u"
                and line[i + 2] == "n"
                and (i == 0 or not _pm_is_word_char(line[i - 1])) {
                after: int = i + 3;
                repl: str = PM_PROG;
                if after < n and line[after] == "x" {
                    after = after + 1;
                    repl = PM_PROG + " x";
                }
                nxt: str = "";
                if after < n {
                    nxt = line[after];
                }
                if not _pm_is_word_char(nxt) and nxt != "." {
                    out.append(line[seg:i]);
                    out.append(repl);
                    i = after;
                    seg = i;
                    continue;
                }
            }
            i = i + 1;
        }
        out.append(line[seg:]);
        li = li + 1;
    }
    return "".join(out);
}

def _pm_help_text(eroot: str, name: str) -> str {
    path: str = eroot + "/src/pm/help/" + name + ".txt";
    text: str = "";
    try {
        text = open(path).read();
    } except Exception {
        text = "";
    }
    if text == "" {
        text = "\nUsage: "
            + PM_PROG
            + " "
            + name
            + " [flags]\n\n(help text not found: "
            + path
            + ")\n";
    }
    # root.txt carries js_engine's own tagline: "(v@VERSION@, bun-compat @BUN_COMPAT@)"
    text = text.replace("@VERSION@", JS_ENGINE_VERSION).replace(
        "@BUN_COMPAT@", PM_BUN_COMPAT_VERSION
    );
    return pm_localize_help(text);
}

def _pm_banner(cmd: str) -> str {
    return PM_PROG
        + " "
        + cmd
        + " v"
        + JS_ENGINE_VERSION
        + " (bun-compat "
        + PM_BUN_COMPAT_VERSION
        + ")\n";
}

def _pm_not_implemented(what: str) -> int {
    _err(
        "error: "
            + PM_PROG
            + " "
            + what
            + " is not implemented yet (package manager phase P0: command line and configuration only; see docs/PACKAGE_MANAGER_PLAN.md)\n"
    );
    return 1;
}

def _pm_file_exists(path: str) -> bool {
    ok: bool = True;
    try {
        open(path).read();
    } except Exception {
        ok = False;
    }
    return ok;
}

# ── Commands ──────────────────────────────────────────────────────────────────

"""`js_engine x` (bunx). bun prints the help on stderr with exit 1 both for
`--help` and for a missing package name. A binary already installed in the
project's node_modules/.bin runs directly; auto-install is not implemented."""
def _pm_cmd_x(eroot: str, args: PmArgs) -> int {
    if args.help or len(args.positionals) == 0 {
        _err(_pm_help_text(eroot, "x"));
        return 1;
    }
    cwd: str = fsx_cwd();
    proj: str = pm_find_project_dir(cwd);
    if proj == "" {
        proj = cwd;
    }
    extra: list[str] = [];
    i: int = 1;
    while i < len(args.positionals) {
        extra.append(args.positionals[i]);
        i = i + 1;
    }
    for p in args.passthrough {
        extra.append(p);
    }
    rc: int = pm_x_local(proj, args.positionals[0], extra);
    if rc >= 0 {
        return rc;
    }
    _err(
        "error: js_engine x cannot install \""
            + args.positionals[0]
            + "\" yet (package manager phase P1: only binaries already in node_modules/.bin run)\n"
    );
    return 1;
}

"""`js_engine run`: a file runs through the engine (-2 tells main.jac to drop
the `run` token and continue as `js_engine <file>`); a package.json script runs
pre/script/post through the shell. With nothing to run bun prints the help
followed by the script list."""
def _pm_cmd_run(eroot: str, args: PmArgs, cwd_override: str) -> int {
    if args.help {
        _out(_pm_help_text(eroot, "run"));
        return 0;
    }
    target: str = "";
    if len(args.positionals) > 0 {
        target = args.positionals[0];
    }
    probe: str = target;
    if cwd_override != "" and target != "" {
        probe = path_abspath(target, cwd_override);
    }
    if target != ""
        and (
            target.startswith("./")
            or target.startswith("../")
            or target.startswith("/")
            or _pm_file_exists(probe)
        ) {
        return -2;  # a file: main.jac runs it (and applies --cwd itself)
    }
    if cwd_override != "" and chdir(cwd_override) != 0 {
        _err("error: --cwd: cannot change to \"" + cwd_override + "\"\n");
        return 1;
    }
    cwd: str = fsx_cwd();
    proj: str = pm_find_project_dir(cwd);
    if target == "" {
        _out(_pm_help_text(eroot, "run"));
        if proj != "" {
            _out(pm_scripts_listing(proj, PM_PROG));
        }
        return 0;
    }
    if proj != "" {
        extra: list[str] = [];
        i: int = 1;
        while i < len(args.positionals) {
            extra.append(args.positionals[i]);
            i = i + 1;
        }
        for p in args.passthrough {
            extra.append(p);
        }
        silent: bool = "silent" in args.flags;
        rc: int = pm_run_script(proj, target, extra, silent);
        if rc >= 0 {
            return rc;
        }
    }
    if "if-present" in args.flags {
        return 0;
    }  # bun: no error when the script does not exist
    _err("error: Script not found \"" + target + "\"\n");
    return 1;
}

def _pm_cmd_pm(eroot: str, args: PmArgs) -> int {
    if args.help or len(args.positionals) == 0 {
        _out(_pm_help_text(eroot, "pm"));
        return 0;
    }
    sub: str = args.positionals[0];
    if not _pm_pm_subcommand_known(sub) {
        _out(_pm_help_text(eroot, "pm"));
        _err("\nerror: \"" + sub + "\" unknown command\n");
        return 1;
    }
    if sub == "default-trusted" {
        return pm_cmd_default_trusted(eroot);
    }
    if sub == "untrusted" or sub == "trust" {
        cfg: PmConfig = pm_config_load(args);
        if sub == "untrusted" {
            return pm_cmd_untrusted(eroot, cfg, _pm_banner("pm untrusted"));
        }
        return pm_cmd_trust(eroot, args, cfg, _pm_banner("pm trust"));
    }
    return _pm_not_implemented("pm " + sub);
}

"""Entry point from main.jac. Returns -1 when argv[1] is not a package-manager
command (main.jac then runs argv as a script), -2 to run argv[2:] as a file
(`run <file>`), otherwise the process exit code."""
def:pub pm_try_dispatch(argv: list[str]) -> int {
    n: int = len(argv);
    if n < 2 {
        return -1;
    }
    eroot: str = _pm_engine_root(argv[0]);
    # `js_engine [root flags] <command> …` (bun: `bun --silent run build`, `bun --cwd dir install`)
    g: PmGlobal = _pm_scan_root_flags(argv);
    if g.version {
        _out(JS_ENGINE_VERSION + "\n");
        return 0;
    }
    if g.next >= n {
        if g.help and not g.eval {
            _out(_pm_help_text(eroot, "root"));
            return 0;
        }
        return -1;  # -e / -p or nothing to run: main.jac decides
    }
    cmd: str = pm_canonical_command(argv[g.next]);
    if cmd == "" {
        if g.help and not g.eval {
            _out(_pm_help_text(eroot, "root"));
            return 0;
        }
        return -1;  # a file to run
    }
    if g.bun {
        lifecycle_force_node_shim(True);
    }
    args: PmArgs = pm_parse_args(cmd, argv, g.next + 1);
    if g.silent {
        _pm_set_flag(args, "silent", "true");
    }
    if g.if_present {
        _pm_set_flag(args, "if-present", "true");
    }
    if g.config != "" and not ("config" in args.flags) {
        _pm_set_flag(args, "config", g.config);
    }
    if cmd == "run" {
        rc_run: int = _pm_cmd_run(eroot, args, g.cwd);
        if rc_run == -2 {
            del argv[g.next];
        }  # main.jac runs the file with the remaining argv
        return rc_run;
    }
    if g.cwd != "" and chdir(g.cwd) != 0 {
        _err("error: --cwd: cannot change to \"" + g.cwd + "\"\n");
        return 1;
    }
    if cmd == "x" {
        return _pm_cmd_x(eroot, args);
    }
    if args.help {
        _out(_pm_help_text(eroot, cmd));
        return 0;
    }
    if cmd == "pm" {
        return _pm_cmd_pm(eroot, args);
    }
    cfg: PmConfig = pm_config_load(args);
    if getenv("JS_PM_DEBUG") != None {
        _err(pm_config_describe(cfg));
        if len(args.unknown) > 0 {
            _err("  ignored unknown flags: " + " ".join(args.unknown) + "\n");
        }
    }
    if (cmd == "add" or cmd == "remove") and len(args.positionals) == 0 {
        _out(_pm_banner(cmd));
        _out(_pm_help_text(eroot, cmd));
        _err("error: no package specified to " + cmd + "\n");
        return 0;
    }
    if cmd == "install" {
        return pm_cmd_install(eroot, args, cfg, _pm_banner(cmd));
    }
    if cmd == "add" {
        return pm_cmd_add(eroot, args, cfg, _pm_banner(cmd));
    }
    if cmd == "remove" {
        return pm_cmd_remove(eroot, args, cfg, _pm_banner(cmd));
    }
    return _pm_not_implemented(cmd);
}
