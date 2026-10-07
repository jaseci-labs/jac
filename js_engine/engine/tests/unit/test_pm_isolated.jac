"""Unit tests for the isolated linker's store construction (pm/isolated.jac),
checked against bun 1.3.13's layout for the `workspace` harness fixture
(tools/pm_diff/golden/workspace/install-fresh/tree.txt).

Run from the repo root:  jac run --backend native engine/tests/unit/test_pm_isolated.jac
"""

import from engine.src.ffi.libc { fflush, _exit }
import from engine.src.pm.config { PmConfig, PmRegistry }
import from engine.src.pm.lockfile { Lockfile, LockPkg, lockfile_load }
import from engine.src.pm.isolated {
    IsoStore,
    IsoEntry,
    IsoNode,
    IsoEntryDep,
    pm_isolated_store,
    iso_store_name,
    iso_entry_store_dir,
    iso_entry_node_modules,
    iso_sorted_entry_deps
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

"""Entry id whose store dir ends with `suffix`, or -1."""
def find_entry(st: IsoStore, rootp: str, suffix: str) -> int {
    i: int = 0;
    while i < len(st.entries) {
        d: str = iso_entry_store_dir(rootp, st, i);
        if len(d) >= len(suffix) and d[len(d) - len(suffix):] == suffix {
            return i;
        }
        i = i + 1;
    }
    return -1;
}

def dep_names(e: IsoEntry) -> str {
    names: list[str] = [];
    for d in iso_sorted_entry_deps(e.deps) {
        names.append(d.name);
    }
    return ",".join(names);
}

glob rootp: str = "/p";
with entry {
    cfg: PmConfig = PmConfig(registry=PmRegistry());

    # ── store names ──────────────────────────────────────────────────────────
    check_eq(
        iso_store_name(LockPkg(kind="npm", name="is-odd", version="3.0.1")),
        "is-odd@3.0.1",
        "store name"
    );
    check_eq(
        iso_store_name(LockPkg(kind="npm", name="@scope/x", version="1.2.3")),
        "@scope+x@1.2.3",
        "store name scoped"
    );
    check_eq(
        iso_store_name(LockPkg(kind="workspace", name="@ws/a", version="packages/a")),
        "",
        "store name workspace"
    );

    # ── the workspace fixture (bun's golden tree) ────────────────────────────
    lf: Lockfile = lockfile_load(
        "tools/pm_diff/golden/workspace/install-fresh/bun.lock"
    );
    check(lf.ok, "golden lockfile loads");
    if lf.ok {
        st: IsoStore = pm_isolated_store(cfg, lf, "linux", "x64");
        check_eq(st.error, "", "store builds");
        # root, @ws/a, @ws/b, is-odd@3.0.1, is-even, @ws/a (from @ws/b), is-number@7, is-number@6,
        # is-odd@0.1.2, is-number@3, kind-of, is-buffer
        check_eq(str(len(st.entries)), "12", "entry count");
        check_eq(str(len(st.nodes)), "12", "node count");

        # entry 0 is the root; its dependencies exclude the workspaces
        check_eq(
            iso_entry_node_modules(rootp, st, 0), "/p/node_modules", "root node_modules"
        );
        check_eq(iso_entry_store_dir(rootp, st, 0), "", "root has no store dir");
        check_eq(dep_names(st.entries[0]), "is-odd", "root deps (no workspaces)");
        check(not st.entries[0].hoisted, "root not hoisted");

        # store paths
        e_isodd: int = find_entry(st, rootp, "/is-odd@3.0.1/node_modules/is-odd");
        check(e_isodd > 0, "is-odd@3.0.1 entry exists");
        if e_isodd > 0 {
            check_eq(
                iso_entry_store_dir(rootp, st, e_isodd),
                "/p/node_modules/.bun/is-odd@3.0.1/node_modules/is-odd",
                "store dir"
            );
            check_eq(
                iso_entry_node_modules(rootp, st, e_isodd),
                "/p/node_modules/.bun/is-odd@3.0.1/node_modules",
                "store node_modules"
            );
            check(st.entries[e_isodd].hoisted, "is-odd@3.0.1 is the hoisted is-odd");
            check_eq(dep_names(st.entries[e_isodd]), "is-number", "is-odd@3.0.1 deps");
            check_eq(st.entries[e_isodd].peer_hash, "", "no peers → no suffix");
        }
        e_isodd0: int = find_entry(st, rootp, "/is-odd@0.1.2/node_modules/is-odd");
        check(e_isodd0 > 0, "is-odd@0.1.2 entry exists");
        if e_isodd0 > 0 {
            check(
                not st.entries[e_isodd0].hoisted,
                "is-odd@0.1.2 not hoisted (second is-odd)"
            );
        }

        # is-number: 7.0.0 (via @ws/b) is created before 6.0.0 (via is-odd@3.0.1) and 3.0.0 → it is the hoisted one
        e_n7: int = find_entry(st, rootp, "/is-number@7.0.0/node_modules/is-number");
        e_n6: int = find_entry(st, rootp, "/is-number@6.0.0/node_modules/is-number");
        e_n3: int = find_entry(st, rootp, "/is-number@3.0.0/node_modules/is-number");
        check(e_n7 > 0 and e_n6 > 0 and e_n3 > 0, "all three is-number entries exist");
        if e_n7 > 0 and e_n6 > 0 and e_n3 > 0 {
            check(e_n7 < e_n6 and e_n6 < e_n3, "is-number entry order 7 < 6 < 3");
            check(st.entries[e_n7].hoisted, "is-number@7.0.0 hoisted");
            check(not st.entries[e_n6].hoisted, "is-number@6.0.0 not hoisted");
            check(not st.entries[e_n3].hoisted, "is-number@3.0.0 not hoisted");
            check_eq(dep_names(st.entries[e_n3]), "kind-of", "is-number@3 deps");
        }
        e_kind: int = find_entry(st, rootp, "/kind-of@3.2.2/node_modules/kind-of");
        e_buf: int = find_entry(st, rootp, "/is-buffer@1.1.6/node_modules/is-buffer");
        check(e_kind > 0 and e_buf > 0, "kind-of / is-buffer entries exist");
        if e_kind > 0 and e_buf > 0 {
            check(
                st.entries[e_kind].hoisted and st.entries[e_buf].hoisted,
                "kind-of and is-buffer hoisted"
            );
            check_eq(dep_names(st.entries[e_kind]), "is-buffer", "kind-of deps");
            deps: list[IsoEntryDep] = st.entries[e_kind].deps;
            check(
                len(deps) == 1 and deps[0].entry_id == e_buf,
                "kind-of → is-buffer entry edge"
            );
        }

        # workspaces: root-level entries, plus a separate empty entry for @ws/a as @ws/b's dependency
        e_a: int = find_entry(st, rootp, "/p/packages/a");
        e_b: int = find_entry(st, rootp, "/p/packages/b");
        check(e_a > 0 and e_b > 0, "workspace entries exist");
        if e_a > 0 and e_b > 0 {
            check_eq(
                iso_entry_node_modules(rootp, st, e_a),
                "/p/packages/a/node_modules",
                "workspace node_modules"
            );
            check_eq(dep_names(st.entries[e_a]), "is-even", "@ws/a deps");
            check_eq(dep_names(st.entries[e_b]), "@ws/a,is-number", "@ws/b deps");
            check(
                st.entries[e_a].hoisted and st.entries[e_b].hoisted,
                "workspace entries carry bun's hoisted flag (the hidden link is only made for npm packages)"
            );
            dup: int = -1;
            for d in st.entries[e_b].deps {
                if d.name == "@ws/a" {
                    dup = d.entry_id;
                }
            }
            check(dup > 0 and dup != e_a, "@ws/a from @ws/b is its own entry");
            if dup > 0 {
                check_eq(
                    iso_entry_store_dir(rootp, st, dup),
                    "/p/packages/a",
                    "dup workspace entry points at the workspace dir"
                );
                check_eq(
                    str(len(st.entries[dup].deps)),
                    "0",
                    "dup workspace entry has no dependencies"
                );
            }
            n7: int = -1;
            for d2 in st.entries[e_b].deps {
                if d2.name == "is-number" {
                    n7 = d2.entry_id;
                }
            }
            check(n7 == e_n7, "@ws/b's is-number is the 7.0.0 entry");
        }
        e_even: int = find_entry(st, rootp, "/is-even@1.0.0/node_modules/is-even");
        check(e_even > 0, "is-even entry exists");
        if e_even > 0 {
            check(st.entries[e_even].hoisted, "is-even hoisted");
            check_eq(dep_names(st.entries[e_even]), "is-odd", "is-even deps");
            for d3 in st.entries[e_even].deps {
                check(d3.entry_id == e_isodd0, "is-even's is-odd is the 0.1.2 entry");
            }
        }
    }

    print("pm_isolated: passed=" + str(_ok) + " failed=" + str(_fail));
    fflush(0);
    if _fail > 0 {
        _exit(1);
    }
}
