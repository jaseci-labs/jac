"""Hook-dispatch tests: Phase-1 codegen + Phase-2 seal/devirtualization,
plus the `without_plugins` / reseal regression guards (the byllm bug class).

Built on a fresh `PluginManager` + a synthetic facade so the seal lifecycle,
register, and unregister paths are driven directly with no global state."""
import inspect;
import asyncio;
import os;
import subprocess;
import sys;
import jaclang.jac0core.plugin as pluggy;
import from jaclang.jac0core.plugin { _build_devirt, _is_simple_sig }
import from jaclang.jac0core.runtime { generate_plugin_helpers, plugin_manager }

glob hookimpl = pluggy.HookimplMarker("jac"),
     hookspec = pluggy.HookspecMarker("jac");

"""firstresult hookspec, so the dynamic dispatcher returns the first non-None
impl result (matching real runtime hooks)."""
class Spec {
    @hookspec(firstresult=True)
    static def act(x: int) -> object { }
}

class CorePlugin {
    @hookimpl
    static def act(x: int) -> object {
        return f"core:{x}";
    }
}

class ExtPlugin {
    @hookimpl
    static def act(x: int) -> object {
        return f"ext:{x}";
    }
}

class PassPlugin {
    @hookimpl
    static def act(x: int) -> object {
        return None;
    }
}

"""Non-firstresult spec: returns a result list, so seal() must not devirt."""
class SpecNoFirst {
    @hookspec
    static def act(x: int) -> object { }
}

"""Fresh plugin manager with the `act` firstresult hookspec registered."""
def fresh_pm -> pluggy.PluginManager {
    pm = pluggy.PluginManager("jac");
    pm.add_hookspecs(Spec);
    return pm;
}

"""Synthetic facade whose `act` dynamically dispatches to pm.hook.act (the
Phase-1 'base'). seal() either devirtualizes this or leaves it, per impl count."""
def facade_for(pm: pluggy.PluginManager) -> type {
    def act(x: int) -> object {
        return getattr(pm.hook, "act")(x=x);
    }
    act.__signature__ = inspect.signature(act);
    return `type("Facade", (object, ), {"act": act});
}

"""True when the facade's `act` is the direct-call devirtualization."""
def is_devirt(facade: type) -> bool {
    return "__jac_impl" in facade.act.__globals__;
}

# ===================== Tier 2: helper correctness =====================
def _f_simple(a: int, b: int = 1) { }

def _f_kwonly(a: int, *, b: int) { }

def _f_varargs(*a: int) { }

def _f_varkw(**k: int) { }

def _f_jacprefixed(__jac_x: int) { }

test "is_simple_sig classifies signatures" {
    assert _is_simple_sig(inspect.signature(_f_simple)) == True;
    assert _is_simple_sig(inspect.signature(_f_kwonly)) == True;
    assert _is_simple_sig(inspect.signature(_f_varargs)) == False;
    assert _is_simple_sig(inspect.signature(_f_varkw)) == False;
    assert _is_simple_sig(inspect.signature(_f_jacprefixed)) == False;
}

test "build_devirt preserves behavior and signature" {
    def impl(x: int) -> object {
        return x * 10;
    }
    sig = inspect.signature(impl);
    dv = _build_devirt("act", sig, impl, ("x", ), False);
    assert dv(5) == 50;
    assert dv(x=5) == 50;
    assert inspect.signature(dv) == sig;
    assert "__jac_impl" in dv.__globals__;
}

test "build_devirt survives collision-prone param names" {
    def impl(c: int, result: int = 2) -> object {
        return [c, result];
    }
    sig = inspect.signature(impl);
    dv = _build_devirt("act", sig, impl, ("c", "result"), False);
    assert dv(1) == [1, 2];
    assert dv(c=5, result=6) == [5, 6];
}

test "async build_devirt survives a param named inspect" {
    async def aimpl(inspect: int) -> object {
        return inspect + 100;
    }
    sig = inspect.signature(aimpl);
    dv = _build_devirt("act", sig, aimpl, ("inspect", ), True);
    assert asyncio.run(dv(4)) == 104;
}

test "build_devirt forwards only the impl's argnames" {
    def impl(a: int) -> object {
        return a + 1;
    }
    def spec(a: int, b: int = 0) -> object { }
    sig = inspect.signature(spec);
    dv = _build_devirt("act", sig, impl, ("a", ), False);
    # b is in the facade signature but not the impl argnames -> dropped, no TypeError
    assert dv(7, 99) == 8;
    assert dv(a=7, b=99) == 8;
}

test "build_devirt awaits coroutine results for async hooks" {
    async def aimpl(x: int) -> object {
        return x + 100;
    }
    sig = inspect.signature(aimpl);
    dv = _build_devirt("act", sig, aimpl, ("x", ), True);
    assert asyncio.run(dv(5)) == 105;
}

# ============ Tier 2: Phase-1 codegen proxy == reflective proxy ============
"""A simple-signature hook interface (codegen-eligible)."""
class EquivIface {
    static def equiv_hook(a: int, b: int = 7) -> object { }
}

class EquivImpl {
    @hookimpl
    static def equiv_hook(a: int, b: int = 7) -> object {
        return [a, b];
    }
}

test "phase-1 codegen proxy matches reflective proxy" {
    old = os.environ.get("JAC_HOOK_CODEGEN");
    try {
        # build the SAME hook two ways: codegen (real-signature) vs reflective
        os.environ["JAC_HOOK_CODEGEN"] = "1";
        (spec_cls, _ic, codegen_cls) = generate_plugin_helpers(EquivIface);
        os.environ["JAC_HOOK_CODEGEN"] = "0";
        (_sr, _ir, reflective_cls) = generate_plugin_helpers(EquivIface);
    } finally {
        if old is None {
            os.environ.pop("JAC_HOOK_CODEGEN", None);
        } else {
            os.environ["JAC_HOOK_CODEGEN"] = old;
        }
    }
    # prove we actually built two DISTINCT forms (else the test is vacuous):
    # codegen has the real signature, reflective is (*args, **kwargs)
    assert codegen_cls.equiv_hook.__code__.co_varnames[:1] == ("a", );
    assert reflective_cls.equiv_hook.__code__.co_varnames[:1] == ("args", );
    # wire the hook + an impl into the global manager both proxies dispatch to
    plugin_manager.add_hookspecs(spec_cls);
    inst = EquivImpl();
    pname = plugin_manager.register(inst);
    try {
        cases = [
            ((1, ), {}),
            ((1, 2), {}),
            ((), {"a": 3}),
            ((4, ), {"b": 9}),
            ((), {"a": 5, "b": 6})
        ];
        for (a, k) in cases {
            cg = codegen_cls.equiv_hook(*a, **k);
            rf = reflective_cls.equiv_hook(*a, **k);
            assert cg == rf , f"{a} {k}: codegen={cg} reflective={rf}";
        }
        # both also match the impl's ground-truth result (defaults applied)
        assert codegen_cls.equiv_hook(1, 2) == [1, 2];
        assert codegen_cls.equiv_hook(3) == [3, 7];
    } finally {
        plugin_manager.unregister(inst, name=pname);
        try {
            delattr(plugin_manager.hook, "equiv_hook");
        } except Exception { }
    }
}

"""Param names that would collide with unmangled codegen internals."""
class CollideIface {
    static def collide_hook(c: int, result: int = 2, inspect: int = 3) -> object { }
}

class CollideImpl {
    @hookimpl
    static def collide_hook(c: int, result: int = 2, inspect: int = 3) -> object {
        return [c, result, inspect];
    }
}

test "codegen proxy survives collision-prone param names" {
    (spec_cls, _ic, proxy_cls) = generate_plugin_helpers(CollideIface);
    assert proxy_cls.collide_hook.__code__.co_varnames[:3] == (
        "c",
        "result",
        "inspect"
    );
    plugin_manager.add_hookspecs(spec_cls);
    inst = CollideImpl();
    pname = plugin_manager.register(inst);
    try {
        assert proxy_cls.collide_hook(1) == [1, 2, 3];
        assert proxy_cls.collide_hook(7, result=8, inspect=9) == [7, 8, 9];
    } finally {
        plugin_manager.unregister(inst, name=pname);
        try {
            delattr(plugin_manager.hook, "collide_hook");
        } except Exception { }
    }
}

# ===================== Tier 1: seal / devirt / regression =====================
test "seal devirtualizes a single-impl hook" {
    pm = fresh_pm();
    facade = facade_for(pm);
    pm.register(CorePlugin());
    pm.seal(facade);
    assert is_devirt(facade);
    assert facade.act(5) == "core:5";
}

test "non-firstresult hook stays dynamic even with a single impl" {
    pm = pluggy.PluginManager("jac");
    pm.add_hookspecs(SpecNoFirst);
    facade = facade_for(pm);
    pm.register(CorePlugin());
    pm.seal(facade);
    assert not is_devirt(facade);
    assert facade.act(5) == ["core:5"];
}

test "multi-impl hook stays dynamic (not devirtualized)" {
    pm = fresh_pm();
    facade = facade_for(pm);
    pm.register(CorePlugin());
    pm.register(ExtPlugin());
    pm.seal(facade);
    assert not is_devirt(facade);
    # firstresult, reversed dispatch: last-registered (ext) wins
    assert facade.act(5) == "ext:5";
}

test "firstresult None-passthrough preserved under seal" {
    pm = fresh_pm();
    facade = facade_for(pm);
    pm.register(CorePlugin());
    pm.register(PassPlugin());
    pm.seal(facade);
    # reversed: Pass returns None -> falls through to Core
    assert facade.act(3) == "core:3";
}

test "register after seal flips devirt back to dynamic" {
    pm = fresh_pm();
    facade = facade_for(pm);
    pm.register(CorePlugin());
    pm.seal(facade);
    assert is_devirt(facade);
    pm.register(ExtPlugin());
    assert not is_devirt(facade);
    assert facade.act(2) == "ext:2";
}

test "seal is idempotent" {
    pm = fresh_pm();
    facade = facade_for(pm);
    pm.register(CorePlugin());
    pm.seal(facade);
    first = facade.act;
    pm.seal(facade);
    assert facade.act is first;
}

test "unregister does not transient-devirtualize (without_plugins regression)" {
    pm = fresh_pm();
    facade = facade_for(pm);
    core = CorePlugin();
    ext = ExtPlugin();
    pm.register(core);
    pm.seal(facade);
    pm.register(ext);
    assert not is_devirt(facade);
    assert facade.act(1) == "ext:1";
    base = facade.act;
    # simulate the compiler's `without_plugins`: drop the external plugin
    pm.unregister(ext);
    # CRITICAL: must NOT re-specialize -> facade.act is unchanged, never bound
    # to the core stub. (Old reseal-on-unregister devirtualized it here.)
    assert facade.act is base;
    assert not is_devirt(facade);
    assert facade.act(1) == "core:1";
    # `without_plugins` finally: restore the external plugin
    pm.register(ext);
    assert facade.act(1) == "ext:1";
}

# ===================== Tier 3: ablation flags =====================
test "JAC_HOOK_SEAL=0 disables devirtualization" {
    pm = fresh_pm();
    facade = facade_for(pm);
    pm.register(CorePlugin());
    old = os.environ.get("JAC_HOOK_SEAL");
    os.environ["JAC_HOOK_SEAL"] = "0";
    try {
        pm.seal(facade);
        assert not is_devirt(facade);
        assert facade.act(9) == "core:9";
    } finally {
        if old is None {
            os.environ.pop("JAC_HOOK_SEAL", None);
        } else {
            os.environ["JAC_HOOK_SEAL"] = old;
        }
    }
}

test "JAC_HOOK_CODEGEN=0 forces the reflective proxy" {
    code = "import inspect; from jaclang import JacRuntimeInterface as Jac; " + "m = Jac.check_write_access; " + "print('reflective' if m.__code__.co_varnames[:1] != ('to', ) else 'codegen')";
    env = dict(os.environ);
    env["JAC_HOOK_CODEGEN"] = "0";
    out = subprocess.run(
        [sys.executable, "-c", code], capture_output=True, text=True, env=env
    );
    assert "reflective" in out.stdout , out.stdout + out.stderr;
}
