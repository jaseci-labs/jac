"""
Package-manager configuration (engine/src/pm): everything bun reads before an
install / add / run, resolved into one PmConfig.

Sources, applied in this order (later wins):

    defaults
    ~/.npmrc                      registry, @scope:registry, //host/:_authToken, ca…
    <cwd>/.npmrc
    ~/.bunfig.toml                [install] section
    <cwd>/bunfig.toml             (or the -c/--config path)
    environment                   BUN_CONFIG_REGISTRY, BUN_INSTALL_CACHE_DIR, …
    command line                  --registry, --frozen-lockfile, …

This is the order documented for bun ("bunfig.toml takes precedence over
.npmrc"; CLI over everything). The env-vs-bunfig position is not documented
and is on the P1 list to verify differentially (a registry that logs which
port each tool hits).

Cache and global directories follow decision D3 of the plan: bun's own env
variables are honoured, and the defaults live under ~/.js_engine, never inside
~/.bun (so a half-written cache can never corrupt the user's real bun).
"""

import from engine.src.ffi.libc { getenv, getcwd }
import from engine.src.pm.toml {
    TomlDoc,
    TomlValue,
    toml_parse,
    toml_has,
    toml_get_str,
    toml_get_bool,
    toml_get_int,
    toml_get_list,
    toml_keys_under
}
import from engine.src.pm.npmrc { NpmrcEntry, npmrc_parse }

glob:pub PM_DEFAULT_REGISTRY: str = "https://registry.npmjs.org/";

# ── Parsed command line (produced by cli.jac) ────────────────────────────────

obj:pub PmArgs {
    has command: str = "",
        flags: dict[str, str] = {},
        flag_order: list[str] = [],
        positionals: list[str] = [],
        passthrough: list[str] = [],
        unknown: list[str] = [],
        help: bool = False;  # canonical name: install, add, remove, …
}

# long flag name -> value ("true" for switches)
# first-seen order of `flags` keys

# everything after `--`
# flags not in bun 1.3.13's tables (bun ignores them; kept for JS_PM_DEBUG)
# ── Configuration ─────────────────────────────────────────────────────────────

obj:pub PmRegistry {
    has url: str = "",
        token: str = "",
        username: str = "",
        password: str = "",
        auth_basic: str = "",
        source: str = "",
        inline_auth: list[str] = [];  # bunfig/env [token, _auth, username, password], kept before .npmrc keys apply
}

# .npmrc `_password` is base64 — decoded when the request is built
# .npmrc `_auth` (base64 "user:pass")
"""A `//host/path/:field=value` .npmrc line, kept until every registry is known
and then matched by URL prefix (pm_config_finalize)."""
obj:pub PmAuthEntry {
    has prefix: str = "",
        field: str = "",
        value: str = "",
        source: str = "";  # host/path/ (no scheme, trailing slash)
}

# _authToken | _auth | username | _password | certfile | keyfile
obj:pub PmConfig {
    has registry: PmRegistry,
        scopes: dict[str, PmRegistry] = {},
        auth_entries: list[PmAuthEntry] = [],
        cwd: str = "",
        home: str = "",
        install_root: str = "",
        cache_dir: str = "",
        cache_disable: bool = False,
        cache_disable_manifest: bool = False,
        global_dir: str = "",
        global_bin_dir: str = "",
        bunfig_path: str = "",
        lockfile_save: bool = True,
        lockfile_load: bool = True,
        lockfile_print: str = "",
        save_text_lockfile: bool = True,
        frozen_lockfile: bool = False,
        lockfile_only: bool = False,
        production: bool = False,
        install_dev: bool = True,
        install_optional: bool = True,
        install_peer: bool = True,
        omit: list[str] = [],
        auto_install: str = "auto",
        exact: bool = False,
        save: bool = True,
        add_kind: str = "",
        only_missing: bool = False,
        global: bool = False,
        filters: list[str] = [],
        target_os: str = "",
        target_cpu: str = "",
        dry_run: bool = False,
        force: bool = False,
        no_verify: bool = False,
        ignore_scripts: bool = False,
        trust: bool = False,
        linker: str = "auto",
        backend: str = "",
        concurrent_scripts: int = 0,
        network_concurrency: int = 48,
        minimum_release_age: int = 0,
        minimum_release_age_excludes: list[str] = [],
        skip_install_packages: bool = False,
        ca: list[str] = [],
        cafile: str = "",
        strict_ssl: bool = True,
        silent: bool = False,
        quiet: bool = False,
        verbose: bool = False,
        no_progress: bool = False,
        no_summary: bool = False,
        sources: dict[str, str] = {},
        files_read: list[str] = [],
        warnings: list[str] = [],
        ignored_keys: list[str] = [];
}

# "@scope" -> registry

# directories

# $BUN_INSTALL (bun's ~/.bun); "" -> ~/.js_engine

# -c/--config
# lockfile

# "yarn" -> also write yarn.lock

# what to install

# auto | force | disable | fallback

# add: "" | dev | optional | peer

# behaviour

# auto: isolated for workspaces, hoisted otherwise (bun 1.3)

# 0 -> bun's default (2 x CPU cores)

# network

# output

# provenance
# setting -> where it came from
def:pub pm_config_new -> PmConfig {
    reg: PmRegistry = PmRegistry(
        url=PM_DEFAULT_REGISTRY,
        token="",
        username="",
        password="",
        auth_basic="",
        source="default"
    );
    return PmConfig(registry=reg);
}

def _cfg_mark(cfg: PmConfig, name: str, source: str) {
    cfg.sources[name] = source;
}

def _cfg_scope(cfg: PmConfig, name: str) -> PmRegistry {
    scope: str = name;
    if not scope.startswith("@") {
        scope = "@" + scope;
    }
    if scope in cfg.scopes {
        return cfg.scopes[scope];
    }
    r: PmRegistry = PmRegistry(
        url="", token="", username="", password="", auth_basic="", source=""
    );
    cfg.scopes[scope] = r;
    return r;
}

def _cfg_truthy(v: str) -> bool {
    low: str = v.strip().lower();
    return low != "" and low != "0" and low != "false" and low != "no" and low != "off";
}

def _cfg_int(v: str, dflt: int) -> int {
    s: str = v.strip();
    if s == "" {
        return dflt;
    }
    i: int = 0;
    while i < len(s) {
        o: int = ord(s[i]);
        if o < 48 or o > 57 {
            return dflt;
        }
        i = i + 1;
    }
    return int(s);
}

# ── .npmrc ────────────────────────────────────────────────────────────────────

def:pub pm_config_apply_npmrc(cfg: PmConfig, entries: list[NpmrcEntry], source: str) {
    for e in entries {
        k: str = e.key;
        if k == "registry" {
            cfg.registry.url = e.value.strip();
            cfg.registry.source = source;
            _cfg_mark(cfg, "registry", source);
        } elif k.startswith("@") and k.endswith(":registry") {
            r: PmRegistry = _cfg_scope(cfg, k[0:len(k) - 9]);
            r.url = e.value.strip();
            r.source = source;
        } elif k.startswith("//") {
            colon: int = k.rfind(":");
            if colon < 2 {
                cfg.ignored_keys.append(source + ": " + k);
                continue;
            }
            prefix: str = k[2:colon];
            if not prefix.endswith("/") {
                prefix = prefix + "/";
            }
            a: PmAuthEntry = PmAuthEntry(
                prefix=prefix, field=k[colon + 1:], value=e.value, source=source
            );
            cfg.auth_entries.append(a);
        } elif k == "cafile" {
            cfg.cafile = e.value;
            _cfg_mark(cfg, "cafile", source);
        } elif k == "ca" {
            cfg.ca.append(e.value);
            _cfg_mark(cfg, "ca", source);
        } elif k == "strict-ssl" {
            cfg.strict_ssl = _cfg_truthy(e.value);
            _cfg_mark(cfg, "strict_ssl", source);
        } else {
            cfg.ignored_keys.append(source + ": " + k);
        }
    }
}

# ── bunfig.toml ───────────────────────────────────────────────────────────────

def _cfg_bunfig_registry(
    cfg: PmConfig, r: PmRegistry, doc: TomlDoc, key: str, source: str
) {
    # `registry = "url"` or `registry = { url = "...", token = "...", username = "...", password = "..." }`
    if toml_has(doc, key) {
        r.url = toml_get_str(doc, key).strip();
        r.source = source;
    }
    if toml_has(doc, key + ".url") {
        r.url = toml_get_str(doc, key + ".url").strip();
        r.source = source;
    }
    if toml_has(doc, key + ".token") {
        r.token = toml_get_str(doc, key + ".token");
        r.source = source;
    }
    if toml_has(doc, key + ".username") {
        r.username = toml_get_str(doc, key + ".username");
        r.source = source;
    }
    if toml_has(doc, key + ".password") {
        r.password = toml_get_str(doc, key + ".password");
        r.source = source;
    }
}

def:pub pm_config_apply_bunfig(cfg: PmConfig, doc: TomlDoc, source: str) {
    if toml_has(doc, "install.registry") or toml_has(doc, "install.registry.url") {
        _cfg_bunfig_registry(cfg, cfg.registry, doc, "install.registry", source);
        _cfg_mark(cfg, "registry", source);
    }
    # [install.scopes]  myorg = "url"  |  "@myorg" = { url = "...", token = "..." }
    seen_scopes: dict[str, bool] = {};
    for k in toml_keys_under(doc, "install.scopes") {
        rest: str = k[len("install.scopes."):];
        dot: int = rest.find(".");
        name: str = rest;
        if dot >= 0 {
            name = rest[0:dot];
        }
        if name in seen_scopes {
            continue;
        }
        seen_scopes[name] = True;
        _cfg_bunfig_registry(
            cfg, _cfg_scope(cfg, name), doc, "install.scopes." + name, source
        );
    }
    if toml_has(doc, "install.optional") {
        cfg.install_optional = toml_get_bool(doc, "install.optional", True);
        _cfg_mark(cfg, "install_optional", source);
    }
    if toml_has(doc, "install.dev") {
        cfg.install_dev = toml_get_bool(doc, "install.dev", True);
        _cfg_mark(cfg, "install_dev", source);
    }
    if toml_has(doc, "install.peer") {
        cfg.install_peer = toml_get_bool(doc, "install.peer", True);
        _cfg_mark(cfg, "install_peer", source);
    }
    if toml_has(doc, "install.production") {
        cfg.production = toml_get_bool(doc, "install.production", False);
        _cfg_mark(cfg, "production", source);
    }
    if toml_has(doc, "install.exact") {
        cfg.exact = toml_get_bool(doc, "install.exact", False);
        _cfg_mark(cfg, "exact", source);
    }
    if toml_has(doc, "install.auto") {
        cfg.auto_install = toml_get_str(doc, "install.auto");
        _cfg_mark(cfg, "auto_install", source);
    }
    if toml_has(doc, "install.frozenLockfile") {
        cfg.frozen_lockfile = toml_get_bool(doc, "install.frozenLockfile", False);
        _cfg_mark(cfg, "frozen_lockfile", source);
    }
    if toml_has(doc, "install.dryRun") {
        cfg.dry_run = toml_get_bool(doc, "install.dryRun", False);
        _cfg_mark(cfg, "dry_run", source);
    }
    if toml_has(doc, "install.saveTextLockfile") {
        cfg.save_text_lockfile = toml_get_bool(doc, "install.saveTextLockfile", True);
        _cfg_mark(cfg, "save_text_lockfile", source);
    }
    if toml_has(doc, "install.globalDir") {
        cfg.global_dir = toml_get_str(doc, "install.globalDir");
        _cfg_mark(cfg, "global_dir", source);
    }
    if toml_has(doc, "install.globalBinDir") {
        cfg.global_bin_dir = toml_get_str(doc, "install.globalBinDir");
        _cfg_mark(cfg, "global_bin_dir", source);
    }
    if toml_has(doc, "install.concurrentScripts") {
        cfg.concurrent_scripts = toml_get_int(doc, "install.concurrentScripts", 0);
        _cfg_mark(cfg, "concurrent_scripts", source);
    }
    if toml_has(doc, "install.linker") {
        cfg.linker = toml_get_str(doc, "install.linker");
        _cfg_mark(cfg, "linker", source);
    }
    if toml_has(doc, "install.ca") {
        for c in toml_get_list(doc, "install.ca") {
            cfg.ca.append(c);
        }
        _cfg_mark(cfg, "ca", source);
    }
    if toml_has(doc, "install.cafile") {
        cfg.cafile = toml_get_str(doc, "install.cafile");
        _cfg_mark(cfg, "cafile", source);
    }
    if toml_has(doc, "install.minimumReleaseAge") {
        cfg.minimum_release_age = toml_get_int(doc, "install.minimumReleaseAge", 0);
        _cfg_mark(cfg, "minimum_release_age", source);
    }
    if toml_has(doc, "install.minimumReleaseAgeExcludes") {
        for x in toml_get_list(doc, "install.minimumReleaseAgeExcludes") {
            cfg.minimum_release_age_excludes.append(x);
        }
        _cfg_mark(cfg, "minimum_release_age_excludes", source);
    }
    if toml_has(doc, "install.cache.dir") {
        cfg.cache_dir = toml_get_str(doc, "install.cache.dir");
        _cfg_mark(cfg, "cache_dir", source);
    }
    if toml_has(doc, "install.cache.disable") {
        cfg.cache_disable = toml_get_bool(doc, "install.cache.disable", False);
        _cfg_mark(cfg, "cache_disable", source);
    }
    if toml_has(doc, "install.cache.disableManifest") {
        cfg.cache_disable_manifest = toml_get_bool(
            doc, "install.cache.disableManifest", False
        );
        _cfg_mark(cfg, "cache_disable_manifest", source);
    }
    if toml_has(doc, "install.lockfile.save") {
        cfg.lockfile_save = toml_get_bool(doc, "install.lockfile.save", True);
        _cfg_mark(cfg, "lockfile_save", source);
    }
    if toml_has(doc, "install.lockfile.print") {
        cfg.lockfile_print = toml_get_str(doc, "install.lockfile.print");
        _cfg_mark(cfg, "lockfile_print", source);
    }
}

# ── Environment ───────────────────────────────────────────────────────────────

def _env(name: str) -> str {
    v: str = getenv(name);
    if v == None {
        return "";
    }
    return v;
}

def:pub pm_config_apply_env(cfg: PmConfig) {
    # npm's variables first, bun's own override them.
    v: str = _env("npm_config_registry");
    if v != "" {
        cfg.registry.url = v;
        cfg.registry.source = "env npm_config_registry";
        _cfg_mark(cfg, "registry", "env npm_config_registry");
    }
    v = _env("NPM_CONFIG_REGISTRY");
    if v != "" {
        cfg.registry.url = v;
        cfg.registry.source = "env NPM_CONFIG_REGISTRY";
        _cfg_mark(cfg, "registry", "env NPM_CONFIG_REGISTRY");
    }
    v = _env("BUN_CONFIG_REGISTRY");
    if v != "" {
        cfg.registry.url = v;
        cfg.registry.source = "env BUN_CONFIG_REGISTRY";
        _cfg_mark(cfg, "registry", "env BUN_CONFIG_REGISTRY");
    }
    v = _env("BUN_CONFIG_TOKEN");
    if v != "" {
        cfg.registry.token = v;
        _cfg_mark(cfg, "registry.token", "env BUN_CONFIG_TOKEN");
    }
    v = _env("BUN_INSTALL");
    if v != "" {
        cfg.install_root = v;
        _cfg_mark(cfg, "install_root", "env BUN_INSTALL");
    }
    v = _env("BUN_INSTALL_CACHE_DIR");
    if v != "" {
        cfg.cache_dir = v;
        _cfg_mark(cfg, "cache_dir", "env BUN_INSTALL_CACHE_DIR");
    }
    v = _env("BUN_INSTALL_GLOBAL_DIR");
    if v != "" {
        cfg.global_dir = v;
        _cfg_mark(cfg, "global_dir", "env BUN_INSTALL_GLOBAL_DIR");
    }
    v = _env("BUN_INSTALL_BIN");
    if v != "" {
        cfg.global_bin_dir = v;
        _cfg_mark(cfg, "global_bin_dir", "env BUN_INSTALL_BIN");
    }
    v = _env("BUN_CONFIG_MAX_HTTP_REQUESTS");
    if v != "" {
        cfg.network_concurrency = _cfg_int(v, cfg.network_concurrency);
        _cfg_mark(cfg, "network_concurrency", "env BUN_CONFIG_MAX_HTTP_REQUESTS");
    }
    v = _env("BUN_CONFIG_NO_VERIFY");
    if v != "" {
        cfg.no_verify = _cfg_truthy(v);
        _cfg_mark(cfg, "no_verify", "env BUN_CONFIG_NO_VERIFY");
    }
    v = _env("BUN_CONFIG_YARN_LOCKFILE");
    if v != "" and _cfg_truthy(v) {
        cfg.lockfile_print = "yarn";
        _cfg_mark(cfg, "lockfile_print", "env BUN_CONFIG_YARN_LOCKFILE");
    }
    v = _env("BUN_CONFIG_SKIP_SAVE_LOCKFILE");
    if v != "" and _cfg_truthy(v) {
        cfg.lockfile_save = False;
        _cfg_mark(cfg, "lockfile_save", "env BUN_CONFIG_SKIP_SAVE_LOCKFILE");
    }
    v = _env("BUN_CONFIG_SKIP_LOAD_LOCKFILE");
    if v != "" and _cfg_truthy(v) {
        cfg.lockfile_load = False;
        _cfg_mark(cfg, "lockfile_load", "env BUN_CONFIG_SKIP_LOAD_LOCKFILE");
    }
    v = _env("BUN_CONFIG_SKIP_INSTALL_PACKAGES");
    if v != "" and _cfg_truthy(v) {
        cfg.skip_install_packages = True;
        _cfg_mark(cfg, "skip_install_packages", "env BUN_CONFIG_SKIP_INSTALL_PACKAGES");
    }
    if cfg.home == "" {
        cfg.home = _env("HOME");
    }
}

# ── Command line ──────────────────────────────────────────────────────────────

def:pub pm_config_apply_cli(cfg: PmConfig, args: PmArgs) {
    for f in args.flag_order {
        v: str = args.flags[f];
        if f == "registry" {
            cfg.registry.url = v;
            cfg.registry.source = "cli";
            _cfg_mark(cfg, "registry", "cli");
        } elif f == "production" {
            cfg.production = True;
            _cfg_mark(cfg, "production", "cli");
        } elif f == "frozen-lockfile" {
            cfg.frozen_lockfile = True;
            _cfg_mark(cfg, "frozen_lockfile", "cli");
        } elif f == "lockfile-only" {
            cfg.lockfile_only = True;
            _cfg_mark(cfg, "lockfile_only", "cli");
        } elif f == "dry-run" {
            cfg.dry_run = True;
            _cfg_mark(cfg, "dry_run", "cli");
        } elif f == "force" {
            cfg.force = True;
            _cfg_mark(cfg, "force", "cli");
        } elif f == "cache-dir" {
            cfg.cache_dir = v;
            _cfg_mark(cfg, "cache_dir", "cli");
        } elif f == "no-cache" {
            cfg.cache_disable = True;
            _cfg_mark(cfg, "cache_disable", "cli");
        } elif f == "silent" {
            cfg.silent = True;
        } elif f == "quiet" {
            cfg.quiet = True;
        } elif f == "verbose" {
            cfg.verbose = True;
        } elif f == "no-progress" {
            cfg.no_progress = True;
        } elif f == "no-summary" {
            cfg.no_summary = True;
        } elif f == "no-verify" {
            cfg.no_verify = True;
            _cfg_mark(cfg, "no_verify", "cli");
        } elif f == "ignore-scripts" {
            cfg.ignore_scripts = True;
            _cfg_mark(cfg, "ignore_scripts", "cli");
        } elif f == "trust" {
            cfg.trust = True;
        } elif f == "global" {
            cfg.global = True;
        } elif f == "cwd" {
            cfg.cwd = v;
        } elif f == "backend" {
            cfg.backend = v;
            _cfg_mark(cfg, "backend", "cli");
        } elif f == "linker" {
            cfg.linker = v;
            _cfg_mark(cfg, "linker", "cli");
        } elif f == "concurrent-scripts" {
            cfg.concurrent_scripts = _cfg_int(v, cfg.concurrent_scripts);
            _cfg_mark(cfg, "concurrent_scripts", "cli");
        } elif f == "network-concurrency" {
            cfg.network_concurrency = _cfg_int(v, cfg.network_concurrency);
            _cfg_mark(cfg, "network_concurrency", "cli");
        } elif f == "minimum-release-age" {
            cfg.minimum_release_age = _cfg_int(v, 0);
            _cfg_mark(cfg, "minimum_release_age", "cli");
        } elif f == "save-text-lockfile" {
            cfg.save_text_lockfile = True;
            _cfg_mark(cfg, "save_text_lockfile", "cli");
        } elif f == "yarn" {
            cfg.lockfile_print = "yarn";
            _cfg_mark(cfg, "lockfile_print", "cli");
        } elif f == "omit" {
            for o in v.split("\n") {
                if o != "" {
                    cfg.omit.append(o);
                }
            }
            _cfg_mark(cfg, "omit", "cli");
        } elif f == "filter" {
            for fl in v.split("\n") {
                if fl != "" {
                    cfg.filters.append(fl);
                }
            }
        } elif f == "ca" {
            for c in v.split("\n") {
                if c != "" {
                    cfg.ca.append(c);
                }
            }
            _cfg_mark(cfg, "ca", "cli");
        } elif f == "cafile" {
            cfg.cafile = v;
            _cfg_mark(cfg, "cafile", "cli");
        } elif f == "cpu" {
            cfg.target_cpu = v;
        } elif f == "os" {
            cfg.target_os = v;
        } elif f == "dev" {
            cfg.add_kind = "dev";
        } elif f == "optional" {
            cfg.add_kind = "optional";
        } elif f == "peer" {
            cfg.add_kind = "peer";
        } elif f == "exact" {
            cfg.exact = True;
            _cfg_mark(cfg, "exact", "cli");
        } elif f == "only-missing" {
            cfg.only_missing = True;
        } elif f == "no-save" {
            cfg.save = False;
            _cfg_mark(cfg, "save", "cli");
        } elif f == "save" {
            cfg.save = True;
            _cfg_mark(cfg, "save", "cli");
        } elif f == "config" {
            cfg.bunfig_path = v;
        }
    }
    # --omit dev|optional|peer narrows what is installed (bun: repeatable).
    for o in cfg.omit {
        if o == "dev" {
            cfg.install_dev = False;
        } elif o == "optional" {
            cfg.install_optional = False;
        } elif o == "peer" {
            cfg.install_peer = False;
        }
    }
    if cfg.production {
        cfg.install_dev = False;
    }
}

# ── Finalize (defaults that depend on other settings, auth matching) ─────────

def _cfg_url_no_scheme(url: str) -> str {
    u: str = url.strip();
    if u.startswith("https://") {
        u = u[8:];
    } elif u.startswith("http://") {
        u = u[7:];
    }
    if not u.endswith("/") {
        u = u + "/";
    }
    return u;
}

def _cfg_apply_auth_to(r: PmRegistry, a: PmAuthEntry) -> None {
    if r.url == "" {
        return;
    }
    if not _cfg_url_no_scheme(r.url).startswith(a.prefix) {
        return;
    }
    if a.field == "_authToken" {
        r.token = a.value;
    } elif a.field == "_auth" {
        r.auth_basic = a.value;
    } elif a.field == "username" {
        r.username = a.value;
    } elif a.field == "_password" {
        r.password = a.value;
    }
}

def _cfg_keep_inline_auth(r: PmRegistry) -> None {
    if len(r.inline_auth) == 0 {
        r.inline_auth = [r.token, r.auth_basic, r.username, r.password];
    }
}

def _cfg_auth_field_index(field: str) -> int {
    if field == "_authToken" {
        return 0;
    }
    if field == "_auth" {
        return 1;
    }
    if field == "username" {
        return 2;
    }
    if field == "_password" {
        return 3;
    }
    return -1;
}

"""The .npmrc credentials for a request to `url`, chosen as npm does: of the
`//host/path/` keys that prefix the URL (scheme dropped), the longest one that
holds a token, `_auth` or a username. A key's fields go together (the last
value of each wins) and never mix with another key's, so a broader key's token
is not held to a narrower key's path. Returns [token, _auth, username,
_password], or [] when no key covers `url`."""
def:pub pm_npmrc_auth_for(cfg: PmConfig, url: str) -> list[str] {
    key: str = _cfg_url_no_scheme(url);
    by_prefix: dict[str, list[str]] = {};
    for a in cfg.auth_entries {
        idx: int = _cfg_auth_field_index(a.field);
        if idx < 0 or not key.startswith(a.prefix) {
            continue;
        }
        if not (a.prefix in by_prefix) {
            by_prefix[a.prefix] = ["", "", "", ""];
        }
        creds: list[str] = by_prefix[a.prefix];
        creds[idx] = a.value;
    }
    best: str = "";
    found: bool = False;
    for p in by_prefix {
        c: list[str] = by_prefix[p];
        usable: bool = c[0] != "" or c[1] != "" or c[2] != "";
        if usable and (not found or len(p) > len(best)) {
            best = p;
            found = True;
        }
    }
    if not found {
        return [];
    }
    return by_prefix[best];
}

def:pub pm_config_finalize(cfg: PmConfig) {
    inst_root: str = cfg.install_root;
    if inst_root == "" {
        if cfg.home != "" {
            inst_root = cfg.home + "/.js_engine";
        } else {
            inst_root = ".js_engine";
        }
    }
    if cfg.cache_dir == "" {
        cfg.cache_dir = inst_root + "/install/cache";
        _cfg_mark(cfg, "cache_dir", "default");
    }
    if cfg.global_dir == "" {
        cfg.global_dir = inst_root + "/install/global";
        _cfg_mark(cfg, "global_dir", "default");
    }
    if cfg.global_bin_dir == "" {
        cfg.global_bin_dir = inst_root + "/bin";
        _cfg_mark(cfg, "global_bin_dir", "default");
    }
    _cfg_keep_inline_auth(cfg.registry);
    for s0 in cfg.scopes {
        _cfg_keep_inline_auth(cfg.scopes[s0]);
    }
    for a in cfg.auth_entries {
        _cfg_apply_auth_to(cfg.registry, a);
        for s in cfg.scopes {
            _cfg_apply_auth_to(cfg.scopes[s], a);
        }
    }
    # A scope without its own registry uses the default one (bun does the same).
    for s2 in cfg.scopes {
        if cfg.scopes[s2].url == "" {
            cfg.scopes[s2].url = cfg.registry.url;
            cfg.scopes[s2].source = "default registry";
        }
    }
}

# ── Loading from disk ─────────────────────────────────────────────────────────

def _cfg_read(path: str) -> tuple[bool, str] {
    ok: bool = True;
    text: str = "";
    try {
        text = open(path).read();
    } except Exception {
        ok = False;
    }
    return (ok, text);
}

def _cfg_load_npmrc(cfg: PmConfig, path: str) -> None {
    r: tuple[bool, str] = _cfg_read(path);
    if not r[0] {
        return;
    }
    cfg.files_read.append(path);
    entries: list[NpmrcEntry] = npmrc_parse(r[1], path, cfg.warnings);
    pm_config_apply_npmrc(cfg, entries, path);
}

def _cfg_load_bunfig(cfg: PmConfig, path: str) -> None {
    r: tuple[bool, str] = _cfg_read(path);
    if not r[0] {
        return;
    }
    cfg.files_read.append(path);
    doc: TomlDoc = toml_parse(r[1]);
    if doc.error != "" {
        cfg.warnings.append(path + ": " + doc.error);
    }
    pm_config_apply_bunfig(cfg, doc, path);
}

"""Resolve the full configuration for a command line (see the module doc for
the precedence). `--cwd` and `-c/--config` are honoured while loading."""
def:pub pm_config_load(args: PmArgs) -> PmConfig {
    cfg: PmConfig = pm_config_new();
    cwd: str = "";
    if "cwd" in args.flags {
        cwd = args.flags["cwd"];
    }
    if cwd == "" {
        cwd = getcwd(0, 0);
    }
    if cwd == None {
        cwd = ".";
    }
    cfg.cwd = cwd;
    cfg.home = _env("HOME");
    if cfg.home != "" {
        _cfg_load_npmrc(cfg, cfg.home + "/.npmrc");
    }
    _cfg_load_npmrc(cfg, cwd + "/.npmrc");
    if cfg.home != "" {
        _cfg_load_bunfig(cfg, cfg.home + "/.bunfig.toml");
    }
    local_cfg: str = cwd + "/bunfig.toml";
    if "config" in args.flags {
        local_cfg = args.flags["config"];
        if not local_cfg.startswith("/") {
            local_cfg = cwd + "/" + local_cfg;
        }
    }
    _cfg_load_bunfig(cfg, local_cfg);
    pm_config_apply_env(cfg);
    pm_config_apply_cli(cfg, args);
    pm_config_finalize(cfg);
    return cfg;
}

# ── Debug dump (JS_PM_DEBUG) ──────────────────────────────────────────────────

def _cfg_src(cfg: PmConfig, name: str) -> str {
    if name in cfg.sources {
        return "  [" + cfg.sources[name] + "]";
    }
    return "  [default]";
}

def _cfg_b(b: bool) -> str {
    if b {
        return "true";
    }
    return "false";
}

def _cfg_secret(v: str) -> str {
    if v == "" {
        return "(unset)";
    }
    return "(set, " + str(len(v)) + " chars)";
}

def:pub pm_config_describe(cfg: PmConfig) -> str {
    out: list[str] = [];
    out.append("pm config:");
    out.append("  cwd = " + cfg.cwd);
    out.append("  home = " + cfg.home);
    out.append("  registry = " + cfg.registry.url + _cfg_src(cfg, "registry"));
    out.append("  registry.token = " + _cfg_secret(cfg.registry.token));
    if cfg.registry.username != "" {
        out.append("  registry.username = " + cfg.registry.username);
    }
    for s in cfg.scopes {
        r: PmRegistry = cfg.scopes[s];
        out.append(
            "  scope "
                + s
                + " = "
                + r.url
                + "  ["
                + r.source
                + "]  token "
                + _cfg_secret(r.token)
        );
    }
    out.append("  cache_dir = " + cfg.cache_dir + _cfg_src(cfg, "cache_dir"));
    out.append("  global_dir = " + cfg.global_dir + _cfg_src(cfg, "global_dir"));
    out.append(
        "  global_bin_dir = " + cfg.global_bin_dir + _cfg_src(cfg, "global_bin_dir")
    );
    out.append("  linker = " + cfg.linker + _cfg_src(cfg, "linker"));
    out.append(
        "  frozen_lockfile = "
            + _cfg_b(cfg.frozen_lockfile)
            + _cfg_src(cfg, "frozen_lockfile")
    );
    out.append(
        "  lockfile_save = "
            + _cfg_b(cfg.lockfile_save)
            + "  save_text_lockfile = "
            + _cfg_b(cfg.save_text_lockfile)
            + "  lockfile_print = "
            + cfg.lockfile_print
    );
    out.append(
        "  production = "
            + _cfg_b(cfg.production)
            + "  dev = "
            + _cfg_b(cfg.install_dev)
            + "  optional = "
            + _cfg_b(cfg.install_optional)
            + "  peer = "
            + _cfg_b(cfg.install_peer)
    );
    out.append(
        "  exact = "
            + _cfg_b(cfg.exact)
            + "  save = "
            + _cfg_b(cfg.save)
            + "  add_kind = "
            + cfg.add_kind
            + "  dry_run = "
            + _cfg_b(cfg.dry_run)
            + "  force = "
            + _cfg_b(cfg.force)
    );
    out.append(
        "  ignore_scripts = "
            + _cfg_b(cfg.ignore_scripts)
            + "  trust = "
            + _cfg_b(cfg.trust)
            + "  no_verify = "
            + _cfg_b(cfg.no_verify)
            + "  global = "
            + _cfg_b(cfg.global)
    );
    out.append(
        "  network_concurrency = "
            + str(cfg.network_concurrency)
            + "  concurrent_scripts = "
            + str(cfg.concurrent_scripts)
            + "  minimum_release_age = "
            + str(cfg.minimum_release_age)
    );
    if cfg.cafile != "" {
        out.append("  cafile = " + cfg.cafile);
    }
    out.append(
        "  ca entries = "
            + str(len(cfg.ca))
            + "  strict_ssl = "
            + _cfg_b(cfg.strict_ssl)
    );
    for f in cfg.files_read {
        out.append("  read: " + f);
    }
    for w in cfg.warnings {
        out.append("  warning: " + w);
    }
    for ig in cfg.ignored_keys {
        out.append("  ignored .npmrc key: " + ig);
    }
    return "\n".join(out) + "\n";
}
