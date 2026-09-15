"""What a finished compile is allowed to keep (jac#8222).

A compiler that runs once and exits may retain whatever it likes. A jac
server and a `jac test` runner compile hundreds of modules inside one
process, so every structure a compile leaves behind is a permanent cost.
Three of them had no owner and no lifecycle:

  - `Import.boundary_facts` held the imported module's whole tree
    (`sv_source_mod` / `na_source_mod`), so a service or pinned-server
    import pinned a second module for the process lifetime -- and, because
    the hub probe used an un-normalized path, a private parsed copy rather
    than the hub's.
  - `JacProgram.scratch.na_dep_units` memoized dependency units compiled purely to
    read a demotion verdict. The verdict is a set of names; the unit is a
    module tree plus a live LLVM `ModuleRef`. Nothing ever released one.
    (That scratch is gone since #8943: a dependency's verdict is read from
    its native interface, served by the program's `NativeUnitRegistry`
    from the module JIR, so no unit is compiled to answer it.)
  - The `TypeEvaluator` flow-narrowing caches are keyed by `id()` and were
    never cleared on the runtime paths, so they grew with every module the
    process ever checked.

Two more things this pins. The hub kept one module under several path
spellings and `find_module` missed the entry it held when the caller
spelled the path differently, which is what turned the first retainer
from one extra tree into one per importer. And `clear_type_system`, the
documented release for expression types, could not release anything: it
walked the sub-node table under the abstract `Expr` key, which is never a
key there.

These tests pin the released state. They are object-count tests, not RSS
tests: each one names the structure, the thing it must not hold, and the
seam that releases it.
"""

import gc;
import os;
import tempfile;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.program { JacProgram }

"""Write a throwaway project and answer its directory."""
def write_mods(mods: dict[(str, str)]) -> str {
    tmp = tempfile.mkdtemp(prefix="jac_retention_");
    for (fname, src) in mods.items() {
        with open(os.path.join(tmp, fname), "w") as f {
            f.write(src);
        }
    }
    return tmp;
}

"""A client module importing a server-pinned provider: the sv-facts trigger."""
def pinned_server_project -> str {
    return write_mods(
        {
            "jac.toml": ('[placement.pins]\nprovider = "server"\n'),
            "provider.jac": (
                "def:pub greet(who: str) -> str {\n" "    return \"hi \" + who;\n" "}\n"
            ),
            "app.jac": (
                "import from .provider { greet as hello }\n\n"
                "def:pub Panel -> JsxElement {\n"
                "    return <div>{hello(\"x\")}</div>;\n"
                "}\n"
            )
        }
    );
}

"""Every live `Module` parsed from `path`, counted through the collector."""
def live_modules_for(path: str) -> list[uni.Module] {
    gc.collect();
    return [
        o
        for o in gc.get_objects()
        if isinstance(o, uni.Module)
            and o.loc is not None
            and os.path.realpath(o.loc.mod_path) == os.path.realpath(path)
    ];
}

"""Count expressions, and how many still carry evaluator types."""
def type_census(mod: uni.Module) -> tuple[(int, int, int)] {
    n_expr = 0;
    n_typed = 0;
    n_narrowed = 0;
    stack: list[uni.UniNode] = [mod];
    while stack {
        cur = stack.pop();
        if isinstance(cur, uni.Expr) {
            n_expr += 1;
            if cur.type is not None {
                n_typed += 1;
            }
            if cur.narrowed_type is not None {
                n_narrowed += 1;
            }
        }
        for k in cur.kid {
            stack.append(k);
        }
    }
    return (n_expr, n_typed, n_narrowed);
}

test "boundary facts carry extracted signatures, never module trees" {
    tmp = pinned_server_project();
    prog = JacProgram();
    mod = prog.compile(os.path.join(tmp, "app.jac"));
    held: list[str] = [];
    for nd in mod.get_all_sub_nodes(uni.Import) {
        facts = nd.boundary_facts;
        if facts is None {
            continue;
        }
        for (slot, val) in vars(facts).items() {
            if isinstance(val, uni.Module) {
                held.append(slot);
            }
        }
    }
    assert not held , (
        f"ImportBoundaryFacts holds a whole Module tree in {sorted(set(held))}. "
        "The facts live on the Import node for the process lifetime, so a "
        "module reference there pins a second tree (and its Source text) per "
        "boundary import. Stamp the extracted decls, not the tree"
    );
    binding = mod.gen.interop_manifest.bindings.get("hello");
    assert binding is not None , (
        "dropping the tree must not drop the binding it was read for; got "
        f"keys {list(mod.gen.interop_manifest.bindings.keys())}"
    );
    assert binding.param_names == ["who"] , "the extracted signature survives";
    assert binding.param_types == ["str"];
    assert binding.ret_type == "str";
}

test "no boundary fact anywhere in the process holds a module tree" {
    mods: dict[(str, str)] = {
        "jac.toml": ('[placement.pins]\nprovider = "server"\n'),
        "provider.jac": (
            "def:pub greet(who: str) -> str {\n" "    return \"hi \" + who;\n" "}\n"
        )
    };
    importers = ["app_a", "app_b", "app_c", "app_d"];
    for stem in importers {
        mods[f"{stem}.jac"] = (
            "import from .provider { greet as hello }\n\n"
            f"def:pub Panel_{stem} -> JsxElement {{\n"
            "    return <div>{hello(\"x\")}</div>;\n"
            "}\n"
        );
    }
    tmp = write_mods(mods);
    prog = JacProgram();
    for stem in importers {
        prog.compile(os.path.join(tmp, f"{stem}.jac"));
    }
    provider = os.path.join(tmp, "provider.jac");
    pinned = 0;
    for mod in live_modules_for(provider) {
        for ref in gc.get_referrers(mod) {
            if isinstance(ref, uni.ImportBoundaryFacts) {
                pinned += 1;
                break;
            }
        }
    }
    assert pinned == 0 , (
        f"{pinned} of the live provider.jac trees are held by an "
        f"ImportBoundaryFacts after {len(importers)} importers compiled. "
        "Each importer that misses the hub forks its own parse and pins it "
        "on its Import node for the process lifetime; the facts must carry "
        "the extracted decls instead"
    );
    for stem in importers {
        importer_mod = prog.find_module(os.path.join(tmp, f"{stem}.jac"));
        assert importer_mod is not None , (
            f"{stem} is not in the hub under the path it was compiled from"
        );
        binding = importer_mod.gen.interop_manifest.bindings.get("hello");
        assert binding is not None and binding.ret_type == "str" , (
            f"{stem} lost its cl->sv binding when the tree stopped being stamped"
        );
    }
}

test "the module hub keys one module once" {
    tmp = pinned_server_project();
    prog = JacProgram();
    prog.compile(os.path.join(tmp, "app.jac"));
    seen: dict[(int, list[str])] = {};
    for (key, mod) in prog.mod.hub.items() {
        seen.setdefault(id(mod), []).append(key);
    }
    dupes = {
        mod_id: keys
        for (mod_id, keys) in seen.items()
        if len(keys) > 1
    };
    assert not dupes , (
        f"the hub keys one module under several spellings: {list(dupes.values())}. "
        "A hub with two keys for one module is not a dedup layer -- the next "
        "lookup that spells the path differently misses and re-parses"
    );
}

test "a hub lookup finds the module however the path is spelled" {
    tmp = pinned_server_project();
    prog = JacProgram();
    prog.compile(os.path.join(tmp, "app.jac"));
    provider = os.path.join(tmp, "provider.jac");
    real = os.path.realpath(provider);
    by_real = prog.find_module(real);
    assert by_real is not None , "the compiled provider is not in the hub at all";
    by_spelling = prog.find_module(provider);
    assert by_spelling is by_real , (
        f"find_module({provider!r}) missed the module it finds under "
        f"{real!r}. Every hub lookup must normalize through "
        "JacProgram.hub_key, or a symlinked root (macOS /var, a git "
        "worktree, a container mount) defeats the hub silently"
    );
}

"""Two evaluator structures are deliberately NOT in the released set.

`_flow_pending_symbols` / `_flow_pending_keys` are in-flight recursion
guards rather than caches, and `_ts_synth_class_cache` holds synthesized
class types whose identity later comparisons depend on. Clearing either
at the compile boundary changes checker results (an order-dependent
E1053 on `isinstance` narrowing), so they stay.
"""
test "the flow-narrowing caches do not survive the compile" {
    tmp = write_mods(
        {
            "jac.toml": "[project]\nname = \"retention_tc\"\n",
            "lib.jac": (
                "def widen(x: (int | str | None)) -> str {\n"
                "    if x is None {\n"
                "        return \"none\";\n"
                "    }\n"
                "    if isinstance(x, int) {\n"
                "        return str(x + 1);\n"
                "    }\n"
                "    return x.upper();\n"
                "}\n"
            ),
            "main.jac": (
                "import from .lib { widen }\n\n"
                "def go(n: (int | str | None)) -> str {\n"
                "    v = widen(n);\n"
                "    if v {\n"
                "        return v;\n"
                "    }\n"
                "    return \"\";\n"
                "}\n"
            )
        }
    );
    prog = JacProgram();
    prog.compile(os.path.join(tmp, "main.jac"));
    ev = prog.type_evaluator;
    if ev is None {
        testskip("no type evaluator: this runtime has no typeshed stubs");
    } else {
        held: dict[(str, int)] = {
            "_flow_node_type_cache": len(ev._flow_node_type_cache),
            "_flow_key_type_cache": len(ev._flow_key_type_cache),
            "_and_narrowing_overrides": len(ev._and_narrowing_overrides),
            "_strict_site_cache": len(ev._strict_site_cache),
            "_loop_written_keys_cache": len(ev._loop_written_keys_cache),
            "_sv_async_syms_cache": len(ev._sv_async_syms_cache),
            "_type_guard_probes": len(ev._type_guard_probes)
        };
        kept = {
            name: n
            for (name, n) in held.items()
            if n
        };
        assert not kept , (
            f"the evaluator still holds {kept} after the compile returned. "
            "These caches are keyed by id() of a flow node and hold a "
            "synthesized type per entry; on a process that checks module "
            "after module they grow without bound, and a reused id() hands a "
            "new node another node's narrowing"
        );
    }
}

test "clear_type_system actually releases expression types" {
    tmp = write_mods(
        {
            "jac.toml": "[project]\nname = \"retention_clear\"\n",
            "one.jac": (
                "def pick(x: (int | str)) -> str {\n"
                "    if isinstance(x, int) {\n"
                "        return str(x);\n"
                "    }\n"
                "    return x;\n"
                "}\n"
            )
        }
    );
    prog = JacProgram();
    prog.compile(os.path.join(tmp, "one.jac"));
    if prog.type_evaluator is None {
        testskip("no type evaluator: this runtime has no typeshed stubs");
    }
    before = 0;
    for mod in prog.mod.hub.values() {
        if mod.stub_only {
            continue;
        }
        (_, typed, narrowed) = type_census(mod);
        before += typed + narrowed;
    }
    assert before > 0 , "the fixture must type some expressions to measure a release";
    prog.clear_type_system();
    after = 0;
    for mod in prog.mod.hub.values() {
        if mod.stub_only {
            continue;
        }
        (_, typed, narrowed) = type_census(mod);
        after += typed + narrowed;
    }
    assert after == 0 , (
        f"clear_type_system left {after} of {before} expression types in "
        "place. It walks `get_all_sub_nodes(uni.Expr)`, and the sub-node "
        "table is keyed by concrete node type only -- the abstract `Expr` "
        "key is never present, so the release is a no-op"
    );
}

test "a code-intel compile keeps the types its callers read" {
    tmp = write_mods(
        {
            "jac.toml": "[project]\nname = \"retention_ci\"\n",
            "hoverable.jac": (
                "def label(x: int) -> str {\n" "    return str(x);\n" "}\n"
            )
        }
    );
    prog = JacProgram();
    mod = prog.compile(os.path.join(tmp, "hoverable.jac"), no_cgen=True);
    if prog.type_evaluator is None {
        testskip("no type evaluator: this runtime has no typeshed stubs");
    }
    (_, typed, _) = type_census(mod);
    assert typed > 0 , (
        "releasing the compile's caches must not null the expression types "
        "themselves: hover, go-to-definition and semantic tokens read "
        "`Expr.type` off the tree long after the compile returned"
    );
}
