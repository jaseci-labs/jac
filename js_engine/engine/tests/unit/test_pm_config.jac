"""
Unit tests for engine/src/pm (package manager, phase P0): the TOML reader,
the .npmrc reader, configuration precedence and bun's argv grammar.

    jac run engine/tests/unit/test_pm_config.jac
"""

import from engine.src.pm.toml {
    TomlDoc,
    toml_parse,
    toml_has,
    toml_get_str,
    toml_get_bool,
    toml_get_int,
    toml_get_list,
    toml_keys_under
}
import from engine.src.pm.npmrc { NpmrcEntry, npmrc_parse }
import from engine.src.pm.config {
    PmArgs,
    PmConfig,
    pm_config_new,
    pm_config_apply_npmrc,
    pm_config_apply_bunfig,
    pm_config_apply_cli,
    pm_config_finalize,
    pm_config_describe
}
import from engine.src.pm.cli { pm_parse_args, pm_canonical_command }
import from engine.src.ffi.libc { fflush, _exit }

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

def b2s(b: bool) -> str {
    if b {
        return "true";
    }
    return "false";
}

glob
     # ── TOML ─────────────────────────────────────────────────────────────────
     # Root-level keys must precede the first [table]: a dotted key after a header
     # is relative to that table (`x.y = 1` under [install.cache] is install.cache.x.y).
     t1: str = "# bunfig\ntop.level.key = \"yes\"\nmulti = \"\"\"\nline1\nline2\"\"\"\nesc = \"a\\tb\\u00e9\"\nneg = -0x1F\nflt = 1.5\nlit = 'C:\\path'\n\n[install]\nregistry = \"https://r.example/\"   # trailing comment\nexact = true\nconcurrentScripts = 8\nminimumReleaseAgeExcludes = [\"a\", 'b',\n  \"c\",\n]\n\n[install.scopes]\nmyorg = \"https://scoped.example/\"\n\"@quoted\" = { url = \"https://q.example/\", token = \"tok\" }\n\n[install.cache]\ndir = \"/tmp/c\"\ndisable = false\nnested.under.table = 1\n\n[install.lockfile]\nprint = \"yarn\"\n";
with entry {
    doc: TomlDoc = toml_parse(t1);
    check_eq(doc.error, "", "toml: sample parses without error");
    check_eq(toml_get_str(doc, "top.level.key"), "yes", "toml: dotted key at root");
    check(
        toml_has(doc, "install.cache.nested.under.table"),
        "toml: dotted key under a table header is relative to it"
    );
    check_eq(
        toml_get_str(doc, "install.registry"),
        "https://r.example/",
        "toml: [install] registry string"
    );
    check(toml_get_bool(doc, "install.exact", False), "toml: bool true");
    check_eq(str(toml_get_int(doc, "install.concurrentScripts", 0)), "8", "toml: int");
    check_eq(
        ",".join(toml_get_list(doc, "install.minimumReleaseAgeExcludes")),
        "a,b,c",
        "toml: multi-line array, trailing comma, mixed quotes"
    );
    check_eq(
        toml_get_str(doc, "install.scopes.myorg"),
        "https://scoped.example/",
        "toml: scope string under [install.scopes]"
    );
    check_eq(
        toml_get_str(doc, "install.scopes.@quoted.url"),
        "https://q.example/",
        "toml: quoted key + inline table flattened"
    );
    check_eq(
        toml_get_str(doc, "install.scopes.@quoted.token"),
        "tok",
        "toml: inline table second key"
    );
    check_eq(
        toml_get_str(doc, "install.cache.dir"), "/tmp/c", "toml: [install.cache] dir"
    );
    check(not toml_get_bool(doc, "install.cache.disable", True), "toml: bool false");
    check_eq(
        toml_get_str(doc, "install.lockfile.print"),
        "yarn",
        "toml: [install.lockfile] print"
    );
    check_eq(
        toml_get_str(doc, "multi"),
        "line1\nline2",
        "toml: multi-line basic string trims first newline"
    );
    check_eq(
        toml_get_str(doc, "esc"), "a\tb" + chr(233), "toml: \\t and \\u00e9 escapes"
    );
    check_eq(str(toml_get_int(doc, "neg", 0)), "-31", "toml: negative hex int");
    check_eq(toml_get_str(doc, "flt"), "1.5", "toml: float kept as text");
    check_eq(
        toml_get_str(doc, "lit"), "C:\\path", "toml: literal string keeps backslash"
    );
    check_eq(
        str(len(toml_keys_under(doc, "install.scopes"))),
        "3",
        "toml: keys_under lists flattened keys"
    );
    check(
        toml_has(doc, "install.exact") and not toml_has(doc, "install.nope"),
        "toml: has"
    );
    check(
        toml_parse("[[x]]\nname = 1\n").error != "",
        "toml: [[x]] reported as unsupported"
    );
    check(toml_parse("a = [1, [2]]\n").error != "", "toml: nested array reported");
    check(
        toml_parse("a = \"unterminated\n").error != "",
        "toml: unterminated string reported"
    );
    check(toml_parse("a = 1 b = 2\n").error != "", "toml: trailing junk reported");
    check_eq(toml_parse("").error, "", "toml: empty document is fine");
}

glob
     # ── .npmrc ───────────────────────────────────────────────────────────────
     warnings: list[str] = [],
     rc: str = "registry=https://npm.example/\n@myorg:registry = https://scoped.example/\n//scoped.example/:_authToken=${TEST_PM_UNSET_TOKEN_X}\n//npm.example/:_authToken=tok-default\n; comment\n# comment\n[ignored]\nstrict-ssl = false\nquoted=\"v\"\nbroken line\n";

with entry {
    entries: list[NpmrcEntry] = npmrc_parse(rc, "test.npmrc", warnings);
    check_eq(
        str(len(entries)),
        "6",
        "npmrc: entry count (comments, section, broken line skipped)"
    );
    check_eq(
        entries[0].key + "=" + entries[0].value,
        "registry=https://npm.example/",
        "npmrc: registry"
    );
    check_eq(
        entries[1].key + "=" + entries[1].value,
        "@myorg:registry=https://scoped.example/",
        "npmrc: spaces around '=' trimmed"
    );
    check_eq(entries[2].value, "", "npmrc: unset ${VAR} expands to empty");
    check_eq(entries[5].value, "v", "npmrc: quotes stripped");
    check_eq(str(len(warnings)), "2", "npmrc: warnings for unset var and broken line");

    # ── Config precedence: npmrc < bunfig < cli ──────────────────────────────
    cfg: PmConfig = pm_config_new();
    check_eq(
        cfg.registry.url, "https://registry.npmjs.org/", "config: default registry"
    );
    pm_config_apply_npmrc(cfg, entries, "test.npmrc");
    check_eq(
        cfg.registry.url, "https://npm.example/", "config: .npmrc registry applied"
    );
    check("@myorg" in cfg.scopes, "config: .npmrc scope registered");
    check_eq(
        cfg.scopes["@myorg"].url, "https://scoped.example/", "config: .npmrc scope url"
    );
    check(not cfg.strict_ssl, "config: strict-ssl=false");
    pm_config_apply_bunfig(cfg, doc, "bunfig.toml");
    check_eq(
        cfg.registry.url,
        "https://r.example/",
        "config: bunfig overrides .npmrc registry"
    );
    check_eq(cfg.sources["registry"], "bunfig.toml", "config: source tracked");
    check(
        "@quoted" in cfg.scopes and cfg.scopes["@quoted"].token == "tok",
        "config: bunfig scope table (url + token)"
    );
    check(cfg.exact, "config: bunfig exact");
    check_eq(cfg.lockfile_print, "yarn", "config: bunfig lockfile.print");
    check_eq(cfg.cache_dir, "/tmp/c", "config: bunfig cache.dir");
}

glob argv: list[str] = [
         "js_engine",
         "install",
         "--registry=https://cli.example/",
         "--frozen-lockfile",
         "-pdE",
         "--omit",
         "dev",
         "--omit=peer",
         "--bogus",
         "pkg1",
         "-c",
         "my.toml",
         "--",
         "x",
         "--y"
     ];
with entry {
    args: PmArgs = pm_parse_args("install", argv, 2);
    check_eq(args.flags["registry"], "https://cli.example/", "args: --flag=value");
    check_eq(args.flags["frozen-lockfile"], "true", "args: switch");
    check(
        ("production" in args.flags)
            and ("dev" in args.flags)
            and ("exact" in args.flags),
        "args: clustered short flags -pdE"
    );
    check_eq(
        args.flags["omit"],
        "dev\npeer",
        "args: repeatable flag with separate and = value"
    );
    check_eq(args.flags["config"], "my.toml", "args: -c value");
    check_eq(",".join(args.positionals), "pkg1", "args: positionals");
    check_eq(
        ",".join(args.passthrough), "x,--y", "args: everything after -- is passthrough"
    );
    check_eq(
        ",".join(args.unknown),
        "--bogus",
        "args: unknown flag recorded (bun ignores it)"
    );
    check(not args.help, "args: no help");
    check(pm_parse_args("install", ["p", "install", "-h"], 2).help, "args: -h");
    check(pm_parse_args("install", ["p", "install", "--help"], 2).help, "args: --help");
    pm_config_apply_cli(cfg, args);
    check_eq(
        cfg.registry.url,
        "https://cli.example/",
        "config: cli overrides bunfig registry"
    );
    check(cfg.frozen_lockfile and cfg.production and cfg.exact, "config: cli switches");
    check_eq(cfg.add_kind, "dev", "config: -d -> add_kind dev");
    check(
        not cfg.install_dev and not cfg.install_peer and cfg.install_optional,
        "config: --omit dev/peer + production"
    );
    check_eq(cfg.bunfig_path, "my.toml", "config: -c recorded");

    cfg.home = "/home/t";
    pm_config_finalize(cfg);
    check_eq(
        cfg.global_dir,
        "/home/t/.js_engine/install/global",
        "config: default global dir under ~/.js_engine (D3)"
    );
    check_eq(
        cfg.global_bin_dir, "/home/t/.js_engine/bin", "config: default global bin dir"
    );
    check_eq(cfg.cache_dir, "/tmp/c", "config: explicit cache dir kept");
    check_eq(cfg.scopes["@myorg"].token, "", "config: unset-env token stays empty");
    check_eq(
        cfg.registry.token,
        "",
        "config: //npm.example/ auth does not apply to the cli registry"
    );
    cfg2: PmConfig = pm_config_new();
    pm_config_apply_npmrc(cfg2, entries, "test.npmrc");
    cfg2.home = "/home/t";
    pm_config_finalize(cfg2);
    check_eq(
        cfg2.registry.token,
        "tok-default",
        "config: //host/:_authToken matched to the registry by URL prefix"
    );
    check_eq(
        cfg2.cache_dir,
        "/home/t/.js_engine/install/cache",
        "config: default cache dir (D3)"
    );
    desc: str = pm_config_describe(cfg2);
    check(
        desc.find("registry = https://npm.example/") >= 0
            and desc.find("tok-default") < 0,
        "config: describe shows registry, redacts token"
    );

    # ── Command names ────────────────────────────────────────────────────────
    check_eq(pm_canonical_command("i"), "install", "cli: alias i");
    check_eq(pm_canonical_command("rm"), "remove", "cli: alias rm");
    check_eq(pm_canonical_command("a"), "add", "cli: alias a");
    check_eq(pm_canonical_command("frob"), "", "cli: not a command");
    check_eq(pm_canonical_command("main.js"), "", "cli: a file name is not a command");

    print("pm_config: passed=" + str(_ok) + " failed=" + str(_fail));
    fflush(0);
    if _fail > 0 {
        _exit(1);
    }
}
