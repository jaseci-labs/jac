"""Unit tests for dependency-spec classification, manifest parsing/selection and
the hoisting port. The hoist test rebuilds the graph behind the recorded
`workspace` golden and must reproduce bun's install-path keys exactly.

Run from the repo root:  jac run engine/tests/unit/test_pm_resolve.jac
(the manifest tests need the recorded registry store in local/pm_registry).
"""

import from engine.src.ffi.libc { fflush, _exit }
import from engine.src.pm.depspec {
    DepSpec,
    depspec_infer,
    depspec_parse,
    SPEC_NPM,
    SPEC_DIST_TAG,
    SPEC_WORKSPACE,
    SPEC_FOLDER,
    SPEC_SYMLINK,
    SPEC_TARBALL,
    SPEC_GIT,
    SPEC_GITHUB,
    SPEC_CATALOG,
    BEH_PROD,
    BEH_DEV,
    BEH_OPTIONAL,
    BEH_PEER,
    BEH_WORKSPACE,
    behavior_cmp,
    dep_less_than
}
import from engine.src.pm.semver {
    SemVer,
    semver_parse_exact,
    semver_group_format,
    semver_parse_range
}
import from engine.src.pm.manifest {
    Manifest,
    MVersion,
    manifest_parse_bytes,
    manifest_find_best,
    manifest_find_dist_tag
}
import from engine.src.pm.fsx { fsx_read_bytes, fsx_exists }
import from engine.src.pm.bytes { ByteBuf, bytebuf_free }
import from engine.src.pm.graph {
    Graph,
    RPkg,
    RDep,
    graph_new,
    graph_add,
    graph_sort_deps,
    graph_find_satisfying
}
import from engine.src.pm.hoist {
    HoistOptions,
    HoistResult,
    HTree,
    hoist_build,
    hoist_tree_path,
    hoist_dep
}

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

def check_tag(spec: str, want: int, name: str) {
    check_eq(str(depspec_infer(spec)), str(want), "infer '" + spec + "' " + name);
}

"""A registry package for the synthetic graph."""
def npm_pkg(g: Graph, name: str, version: str, deps: list[RDep]) -> int {
    pe: tuple[bool, SemVer] = semver_parse_exact(version);
    p: RPkg = RPkg(kind="npm", name=name, version=version, semver=pe[1]);
    p.deps = deps;
    graph_sort_deps(p.deps);
    return graph_add(g, p);
}

def dep(name: str, spec: str, behavior: int, resolution: int) -> RDep {
    d: RDep = RDep(name=name, spec=depspec_parse(name, spec), behavior=behavior);
    d.resolution = resolution;
    return d;
}

with entry {
    # ── depspec ──────────────────────────────────────────────────────────────
    check_tag("^1.2.3", SPEC_NPM, "caret");
    check_tag("~1", SPEC_NPM, "tilde");
    check_tag(">=1 <2", SPEC_NPM, "cmp");
    check_tag("1.2.3", SPEC_NPM, "exact");
    check_tag("*", SPEC_NPM, "star");
    check_tag("x", SPEC_NPM, "x");
    check_tag("1.x", SPEC_NPM, "1.x");
    check_tag("", SPEC_DIST_TAG, "empty");
    check_tag("latest", SPEC_DIST_TAG, "latest");
    check_tag("next", SPEC_DIST_TAG, "next");
    check_tag("v", SPEC_DIST_TAG, "v alone");
    check_tag("v1.2.3", SPEC_NPM, "v1.2.3");
    check_tag("workspace:*", SPEC_WORKSPACE, "workspace");
    check_tag("workspace:packages/a", SPEC_WORKSPACE, "workspace path");
    check_tag("file:../x", SPEC_FOLDER, "file:");
    check_tag("./x", SPEC_FOLDER, "dot");
    check_tag("../x.tgz", SPEC_TARBALL, "local tgz");
    check_tag("link:../x", SPEC_SYMLINK, "link:");
    check_tag("https://example.com/x.tgz", SPEC_TARBALL, "https tarball");
    check_tag(
        "git+https://github.com/u/r.git", SPEC_GITHUB, "git+https github shorthand path"
    );
    check_tag("git+https://gitlab.com/u/r.git", SPEC_GIT, "git+https other host");
    check_tag("github:u/r", SPEC_GITHUB, "github:");
    check_tag("u/r", SPEC_GITHUB, "shorthand");
    check_tag("git://host/x.git", SPEC_GIT, "git://");
    check_tag("catalog:", SPEC_CATALOG, "catalog");
    check_tag("npm:react@^18", SPEC_NPM, "alias range");
    check_tag("npm:@scope/x@1.0.0", SPEC_NPM, "scoped alias");
    check_tag("npm:foo@latest", SPEC_DIST_TAG, "alias tag");
    check_tag("npm:foo", SPEC_NPM, "alias no version");
    a: DepSpec = depspec_parse("react-dom", "npm:react@^18.0.0");
    check(a.tag == SPEC_NPM and a.name == "react" and a.is_alias, "alias parsed");
    check_eq(semver_group_format(a.range), ">=18.0.0 <19.0.0", "alias range");
    b: DepSpec = depspec_parse("x", "");
    check(
        b.tag == SPEC_DIST_TAG and b.dist_tag == "latest" and b.name == "x",
        "empty -> latest"
    );
    c: DepSpec = depspec_parse("x", "v1.2.3");
    check_eq(semver_group_format(c.range), "==1.2.3", "leading v stripped");
    w: DepSpec = depspec_parse("@ws/a", "workspace:packages/a");
    check_eq(w.path, "packages/a", "workspace path");
    check(
        behavior_cmp(BEH_WORKSPACE, BEH_DEV) < 0
            and behavior_cmp(BEH_DEV, BEH_OPTIONAL) < 0
            and behavior_cmp(BEH_OPTIONAL, BEH_PROD) < 0
            and behavior_cmp(BEH_PROD, BEH_PEER) < 0,
        "behavior order"
    );
    check(
        dep_less_than(BEH_PROD, "b", BEH_PROD, "c")
            and not dep_less_than(BEH_PROD, "c", BEH_PROD, "b"),
        "name order within behavior"
    );
    check(
        dep_less_than(BEH_DEV, "z", BEH_PROD, "a"), "dev before prod regardless of name"
    );
}

glob
     # ── manifest (recorded packuments) ───────────────────────────────────────
     path: str = "local/pm_registry/packuments/is-odd.json";
with entry {
    if fsx_exists(path) {
        buf: ByteBuf = fsx_read_bytes(path);
        m: Manifest = manifest_parse_bytes(buf.ptr, buf.len, "is-odd");
        bytebuf_free(buf);
        check(m.ok, "is-odd manifest parses");
        check_eq(m.dist_tags["latest"], "3.0.1", "is-odd latest tag");
        check(len(m.releases) >= 5, "is-odd releases");
        best: MVersion = manifest_find_best(m, semver_parse_range("^0.1.0"));
        check_eq(best.version_str, "0.1.2", "^0.1.0 -> 0.1.2");
        check_eq(
            manifest_find_best(m, semver_parse_range("3.0.1")).version_str,
            "3.0.1",
            "exact"
        );
        check_eq(
            manifest_find_best(m, semver_parse_range("*")).version_str,
            "3.0.1",
            "* -> latest tag"
        );
        check_eq(
            manifest_find_best(m, semver_parse_range("^99")).version_str, "", "no match"
        );
        check_eq(
            manifest_find_dist_tag(m, "latest").version_str, "3.0.1", "dist tag lookup"
        );
        check_eq(manifest_find_dist_tag(m, "nope").version_str, "", "missing dist tag");
        v301: MVersion = manifest_find_best(m, semver_parse_range("3.0.1"));
        check_eq(
            v301.deps[0].name
                + "@"
                + v301.deps[0].spec
                + ":"
                + str(v301.deps[0].behavior),
            "is-number@^6.0.0:" + str(BEH_PROD),
            "deps parsed"
        );
        check(
            v301.integrity.startswith("sha512-")
                and v301.tarball.endswith("/is-odd-3.0.1.tgz"),
            "dist fields"
        );
    } else {
        print("skip: no recorded registry store");
    }
}

glob epath: str = "local/pm_registry/packuments/esbuild.json";
with entry {
    if fsx_exists(epath) {
        buf2: ByteBuf = fsx_read_bytes(epath);
        em: Manifest = manifest_parse_bytes(buf2.ptr, buf2.len, "esbuild");
        bytebuf_free(buf2);
        ev: MVersion = manifest_find_best(em, semver_parse_range("^0.25.0"));
        check(
            ev.version_str.startswith("0.25."),
            "esbuild ^0.25.0 picks a 0.25.x (" + ev.version_str + ")"
        );
        check(ev.has_install_script, "esbuild hasInstallScript");
        check_eq(ev.bin.vals["esbuild"].s, "bin/esbuild", "esbuild bin");
        check(
            len(ev.deps) > 20
                and ev.deps[0].behavior == BEH_OPTIONAL
                and ev.deps[0].name == "@esbuild/aix-ppc64",
            "esbuild optional deps sorted"
        );
    }

    # ── hoisting: the workspace golden ───────────────────────────────────────
    # root (ws-root): devDependencies is-odd@3.0.1; workspaces @ws/a, @ws/b
    # @ws/a: is-even@1.0.0 ; @ws/b: @ws/a workspace:*, is-number@7.0.0
    # is-even@1.0.0 -> is-odd@^0.1.2 ; is-odd@0.1.2 -> is-number@^3.0.0 ; is-number@3.0.0 -> kind-of@^3.0.2
    # kind-of@3.2.2 -> is-buffer@^1.1.5 ; is-odd@3.0.1 -> is-number@^6.0.0
    g: Graph = graph_new();
    rootp: RPkg = RPkg(kind="root", name="ws-root");
    graph_add(g, rootp);
    wa: RPkg = RPkg(
        kind="workspace",
        name="@ws/a",
        version="packages/a",
        ws_version="1.0.0",
        has_ws_version=True
    );
    wa_id: int = graph_add(g, wa);
    wb: RPkg = RPkg(
        kind="workspace",
        name="@ws/b",
        version="packages/b",
        ws_version="1.0.0",
        has_ws_version=True
    );
    wb_id: int = graph_add(g, wb);
    is_odd3: int = npm_pkg(g, "is-odd", "3.0.1", []);
    is_num6: int = npm_pkg(g, "is-number", "6.0.0", []);
    g.pkgs[is_odd3].deps = [dep("is-number", "^6.0.0", BEH_PROD, is_num6)];
    is_even: int = npm_pkg(g, "is-even", "1.0.0", []);
    is_odd0: int = npm_pkg(g, "is-odd", "0.1.2", []);
    is_num3: int = npm_pkg(g, "is-number", "3.0.0", []);
    kind_of: int = npm_pkg(g, "kind-of", "3.2.2", []);
    is_buf: int = npm_pkg(g, "is-buffer", "1.1.6", []);
    is_num7: int = npm_pkg(g, "is-number", "7.0.0", []);
    g.pkgs[is_even].deps = [dep("is-odd", "^0.1.2", BEH_PROD, is_odd0)];
    g.pkgs[is_odd0].deps = [dep("is-number", "^3.0.0", BEH_PROD, is_num3)];
    g.pkgs[is_num3].deps = [dep("kind-of", "^3.0.2", BEH_PROD, kind_of)];
    g.pkgs[kind_of].deps = [dep("is-buffer", "^1.1.5", BEH_PROD, is_buf)];
    wa.deps = [dep("is-even", "1.0.0", BEH_PROD, is_even)];
    wb.deps = [
        dep("@ws/a", "workspace:*", BEH_PROD, wa_id),
        dep("is-number", "7.0.0", BEH_PROD, is_num7)
    ];
    graph_sort_deps(wb.deps);
    rootp.deps = [
        dep("is-odd", "3.0.1", BEH_DEV, is_odd3),
        dep("@ws/a", "workspace:packages/a", BEH_WORKSPACE, wa_id),
        dep("@ws/b", "workspace:packages/b", BEH_WORKSPACE, wb_id)
    ];
    graph_sort_deps(rootp.deps);
    check_eq(
        rootp.deps[0].name + "," + rootp.deps[1].name + "," + rootp.deps[2].name,
        "@ws/a,@ws/b,is-odd",
        "root deps order (workspaces first)"
    );
    hr: HoistResult = hoist_build(g, HoistOptions(filter=False));
    check(hr.ok, "hoist ok: " + hr.error);
}

glob keys: list[str] = [];
with entry {
    t: int = 0;
    while t < len(hr.trees) {
        pd: tuple[str, int] = hoist_tree_path(hr, g, t);
        for d in hr.trees[t].deps {
            rd: RDep = hoist_dep(hr, g, d);
            k: str = rd.name;
            if pd[1] > 0 {
                k = pd[0] + "/" + rd.name;
            }
            keys.append(
                k
                    + "="
                    + g.pkgs[rd.resolution].name
                    + "@"
                    + g.pkgs[rd.resolution].version
            );
        }
        t = t + 1;
    }
    keys.sort();
}

glob want: list[str] = [
         "@ws/a=@ws/a@packages/a",
         "@ws/b=@ws/b@packages/b",
         "is-buffer=is-buffer@1.1.6",
         "is-even=is-even@1.0.0",
         "is-even/is-odd=is-odd@0.1.2",
         "is-even/is-odd/is-number=is-number@3.0.0",
         "is-number=is-number@7.0.0",
         "is-odd=is-odd@3.0.1",
         "is-odd/is-number=is-number@6.0.0",
         "kind-of=kind-of@3.2.2"
     ];

with entry {
    want.sort();
    check_eq("|".join(keys), "|".join(want), "hoisted keys match the workspace golden");
    check_eq(
        str(len(hr.trees)), "4", "tree count (root, is-even, is-odd, is-even/is-odd)"
    );

    # a filtered build drops disabled platform packages and their subtrees
    g2: Graph = graph_new();
    r2: RPkg = RPkg(kind="root", name="plat");
    graph_add(g2, r2);
    fsev: int = npm_pkg(g2, "fsevents", "2.3.3", []);
    r2.deps = [dep("fsevents", "2.3.3", BEH_OPTIONAL, fsev)];
    hr2: HoistResult = hoist_build(
        g2, HoistOptions(filter=True, os_name="linux", cpu_name="x64")
    );
    check(
        hr2.ok and len(hr2.trees) == 1 and len(hr2.trees[0].deps) == 1,
        "filter keeps fsevents without an os field"
    );

    check(
        graph_find_satisfying(g, "is-number", semver_parse_range("^6")) == is_num6,
        "graph_find_satisfying picks first satisfying"
    );
    check(
        graph_find_satisfying(g, "is-number", semver_parse_range("^9")) == -1,
        "graph_find_satisfying none"
    );

    # git / github specifiers carry owner, repo and ref (the goldens: gh-is-odd, gh-prefixed, git-https)
    gh1: DepSpec = depspec_parse("gh-is-odd", "jonschlinkert/is-odd#3.0.1");
    check_eq(
        gh1.owner + "|" + gh1.repo + "|" + gh1.committish,
        "jonschlinkert|is-odd|3.0.1",
        "github shorthand parts"
    );
    gh2: DepSpec = depspec_parse("x", "github:jonschlinkert/is-even#1.0.0");
    check_eq(
        gh2.owner + "|" + gh2.repo + "|" + gh2.committish,
        "jonschlinkert|is-even|1.0.0",
        "github: parts"
    );
    gh3: DepSpec = depspec_parse(
        "x", "git+https://github.com/jonschlinkert/is-number.git#7.0.0"
    );
    check(gh3.tag == SPEC_GITHUB, "git+https github url is a github dependency");
    check_eq(
        gh3.owner + "|" + gh3.repo + "|" + gh3.committish,
        "jonschlinkert|is-number|7.0.0",
        "git+https github parts (.git stripped)"
    );
    gh4: DepSpec = depspec_parse("x", "git@github.com:owner/repo.git");
    check_eq(
        gh4.owner + "|" + gh4.repo + "|" + gh4.committish,
        "owner|repo|",
        "ssh github parts, no ref"
    );
    gt1: DepSpec = depspec_parse("x", "git+https://gitlab.com/u/r.git#v1.2.3");
    check(gt1.tag == SPEC_GIT, "other host stays git");
    check_eq(
        gt1.repo + "|" + gt1.committish,
        "https://gitlab.com/u/r.git|v1.2.3",
        "git url and ref"
    );
    gt2: DepSpec = depspec_parse("x", "git://host/x.git");
    check_eq(
        gt2.repo + "|" + gt2.committish, "git://host/x.git|", "git:// url, no ref"
    );

    print("pm_resolve: passed=" + str(_ok) + " failed=" + str(_fail));
    fflush(0);
    if _fail > 0 {
        _exit(1);
    }
}
