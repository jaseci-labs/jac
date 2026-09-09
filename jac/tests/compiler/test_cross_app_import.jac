"""The one cross-app import rule (#8823).

Every import is classified once by `classify_cross_app_import` over the
workspace's app facts: LOCAL (same app or shared), CLIENT_BRIDGE (client code
reaching server-placed elements), SERVICE_BRIDGE (server/native code reaching
elements owned by another serving app) and NATIVE_BIND (a client-native edge
recorded in the interop manifest). The fixture under fixtures/apps is a five-app
workspace: a dir-rooted web-app, a file-rooted social service, a cli app and a
pair of mutually-importing services that close an app cycle.
"""

import os;
import from tests.support { JAC_ROOT }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.boundary_classify {
    CrossAppKind,
    classify_cross_app_import,
    import_crosses_apps,
    import_provider_app,
    import_provider_route,
    is_client_boundary_import
}
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.codeinfo {
    InteropBinding,
    InteropContext,
    InteropManifest
}

glob APPS_DIR = os.path.join(JAC_ROOT, "tests", "compiler", "fixtures", "apps");

def fixture(*parts: str) -> str {
    return os.path.join(APPS_DIR, *parts);
}

def compile_fixture(path: str, cgen: bool = False) -> tuple {
    prog = JacProgram();
    mod = prog.compile(path, no_cgen=not cgen);
    return (prog, mod);
}

def import_of(mod: uni.Module, stem: str) -> uni.Import {
    for imp in mod.get_all_sub_nodes(uni.Import) {
        if imp.from_loc is not None and imp.from_loc.base_module_name == stem {
            return imp;
        }
    }
    raise AssertionError(f"no import of '{stem}' in {mod.loc.mod_path}");
}

def codes(prog: JacProgram) -> list[str] {
    return [
        e.code.code
        for e in prog.errors_had
        if e.code is not None
    ];
}

test "same-app import is LOCAL" {
    (prog, mod) = compile_fixture(fixture("web", "main.jac"));
    imp = import_of(mod, "helpers");
    assert classify_cross_app_import(imp, None) == CrossAppKind.LOCAL;
    assert not imp.is_service_import;
    assert not import_crosses_apps(imp);
    assert import_provider_app(imp) is None;
}

test "server-context import of another serving app is SERVICE_BRIDGE" {
    (prog, mod) = compile_fixture(fixture("web", "main.jac"));
    imp = import_of(mod, "social_app");
    assert classify_cross_app_import(imp, None) == CrossAppKind.SERVICE_BRIDGE;
    assert imp.is_service_import , (
        "Import.is_service_import is the SERVICE_BRIDGE verdict"
    );
    assert import_provider_app(imp) == "social";
    assert import_provider_route(imp) == "/api/social";
    assert not is_client_boundary_import(imp);
    manifest = mod.gen.interop_manifest;
    assert ("web", "social") in manifest.app_edges , (
        f"consumer->provider edge must be recorded; got {manifest.app_edges}"
    );
    assert manifest.provider_routes.get("social") == "/api/social";
    greet = manifest.bindings.get("greet");
    assert greet is not None and greet.provider_app == "social";
    walker_binding = manifest.bindings.get("Greet");
    assert walker_binding is not None and walker_binding.kind == "walker" , (
        "a plain (non-:pub) walker bridges like any archetype"
    );
    assert "E5106" not in codes(prog) , f"{[str(e) for e in prog.errors_had]}";
    assert "E5104" not in codes(prog);
}

test "SERVICE_BRIDGE stubs are typed-async and keyed by the owner app" {
    (prog, mod) = compile_fixture(fixture("web", "main.jac"), cgen=True);
    py = mod.gen.py;
    assert "async def greet(" in py , py;
    assert "await __jac_sv_client.call('social', 'greet'" in py , py;
    assert "__jac_provider_app__ = 'social'" in py , py;
    assert "spawn_walker('social', 'Greet', kwargs, cls)" in py , py;
    assert "def _deferred(cls, **kwargs)" in py , py;
    assert "spawn_deferred('social', 'Greet', kwargs)" in py , py;
    assert "_declare_consumer_provider('web', 'social', '/api/social')" in py , py;
    assert "Greet._deferred(name='z')" in py , (
        "an un-awaited statement-level spawn lowers to deferred delivery; got:\n" + py
    );
    assert "__jac_provider_module__" not in py;
}

test "cli app importing a service walker is a SERVICE_BRIDGE consumer" {
    (prog, mod) = compile_fixture(fixture("cli_app.jac"), cgen=True);
    imp = import_of(mod, "social_app");
    assert classify_cross_app_import(imp, None) == CrossAppKind.SERVICE_BRIDGE;
    assert ("cli", "social") in mod.gen.interop_manifest.app_edges;
    assert "spawn_walker('social', 'Greet'" in mod.gen.py;
    assert "E5106" not in codes(prog) , f"{[str(e) for e in prog.errors_had]}";
}

test "client-context import of server-placed elements is CLIENT_BRIDGE" {
    (prog, mod) = compile_fixture(fixture("web", "panel.jac"), cgen=True);
    imp = import_of(mod, "social_app");
    assert classify_cross_app_import(imp, None) == CrossAppKind.CLIENT_BRIDGE;
    assert is_client_boundary_import(imp);
    assert not imp.is_service_import;
    js = mod.gen.js;
    assert '__jacCallFunction("greet"' in js , js;
    assert '"route": "/api/social"' in js or "route: \"/api/social\"" in js , (
        "cross-app client stubs carry the provider route; got:\n" + js
    );
    assert ("web", "social") in mod.gen.interop_manifest.app_edges;
}

test "NATIVE_BIND wins for a client import recorded as a client-native edge" {
    (prog, mod) = compile_fixture(fixture("web", "panel.jac"));
    imp = import_of(mod, "social_app");
    from_loc = imp.from_loc;
    if from_loc is None {
        raise AssertionError("import has no from_loc");
    }
    resolved = from_loc.resolve_relative_path();
    manifest = InteropManifest();
    manifest.bindings["greet"] = InteropBinding(
        name="greet",
        source_context=InteropContext.NATIVE,
        callers={InteropContext.CLIENT},
        source_module=resolved
    );
    assert classify_cross_app_import(imp, manifest) == CrossAppKind.NATIVE_BIND;
}

test "bridging to a non-pub def of another app is E5106" {
    (prog, mod) = compile_fixture(fixture("web", "bad_bridge.jac"));
    found = codes(prog);
    assert "E5106" in found , (
        f"expected E5106, got {[str(e) for e in prog.errors_had]}"
    );
    assert "E5082" not in found , "cross-app dead bindings report E5106, not E5082";
}

test "app dependency cycle is E5104" {
    (prog, mod) = compile_fixture(fixture("cycle_a.jac"));
    found = codes(prog);
    assert "E5104" in found , (
        f"expected E5104, got {[str(e) for e in prog.errors_had]}"
    );
    msg = [
        str(e)
        for e in prog.errors_had
        if e.code is not None and e.code.code == "E5104"
    ][0];
    assert "cycle_a" in msg and "cycle_b" in msg , msg;
}

test "missing await on a SERVICE_BRIDGE stub is E1042" {
    (prog, mod) = compile_fixture(fixture("web", "no_await.jac"));
    found = codes(prog);
    assert "E1042" in found , (
        f"expected E1042, got {[str(e) for e in prog.errors_had]}"
    );
}

test "a generator-returning SERVICE_BRIDGE stub is a coroutine until awaited" {
    # The bridge stub is `async def` whatever the provider returns, so a
    # streaming provider is reached as `await narrate(...)`; iterating the
    # un-awaited call is a type error, not a runtime TypeError.
    (prog, mod) = compile_fixture(fixture("web", "stream_no_await.jac"));
    msgs = [str(e) for e in prog.errors_had];
    assert any("Coroutine" in m and "not iterable" in m for m in msgs) , (
        f"iterating an un-awaited bridge stub checked clean: {msgs}"
    );
    (prog, mod) = compile_fixture(fixture("web", "stream_awaited.jac"), cgen=True);
    assert not prog.errors_had , [str(e) for e in prog.errors_had];
    assert "await __jac_sv_client.call('social', 'narrate'" in mod.gen.py , mod.gen.py;
}

test "spawning a bridged walker types as the stub's coroutine, not E1114" {
    # A `cli` app has no server, so its import of a service walker bridges and
    # the stub's constructor is the remote spawn. Codegen lowers
    # `root spawn Stub(...)` to the stub call alone, so the checker types the
    # spawn as that coroutine: awaited it is the walker, un-awaited it is E1042.
    (prog, mod) = compile_fixture(fixture("cli_spawn.jac"), cgen=True);
    found = codes(prog);
    assert "E1114" not in found , f"{[str(e) for e in prog.errors_had]}";
    unawaited = [
        e
        for e in prog.errors_had
        if e.code and e.code.code == "E1042"
    ];
    assert len(unawaited) == 1 and unawaited[0].loc.first_line == 13 , (
        f"{[str(e) for e in prog.errors_had]}"
    );
    assert len(prog.errors_had) == 1 , [str(e) for e in prog.errors_had];
    import re;
    assert re.search(r"(?<![\w.])spawn\(", mod.gen.py) is None , (
        "the runtime spawn must not wrap a bridged stub:\n" + mod.gen.py
    );
}

test "a bridged obj imported alone mirrors as a boundary type, not an RPC stub" {
    (prog, mod) = compile_fixture(fixture("web", "only_profile.jac"), cgen=True);
    assert not prog.errors_had , [str(e) for e in prog.errors_had];
    py = mod.gen.py;
    assert "async def Profile" not in py , (
        "a data type must never lower to a coroutine stub; got:\n" + py
    );
    assert "class Profile:" in py , (
        "the consumer needs a local mirror of the provider's obj; got:\n" + py
    );
    assert "Profile" in mod.gen.interop_manifest.boundary_types;
}

test "a bridged node imported alone is E5108" {
    (prog, mod) = compile_fixture(fixture("web", "only_node.jac"));
    found = codes(prog);
    assert "E5108" in found , (
        f"expected E5108, got {[str(e) for e in prog.errors_had]}"
    );
    msg = [
        str(e)
        for e in prog.errors_had
        if e.code is not None and e.code.code == "E5108"
    ][0];
    assert "Post" in msg and "node" in msg and "social" in msg , msg;
}

test "a provider's import of a shared pure helper is not an app edge" {
    (prog, mod) = compile_fixture(fixture("portal", "main.jac"), cgen=True);
    found = codes(prog);
    assert "E5104" not in found , (
        f"false cycle through a shared helper: {[str(e) for e in prog.errors_had]}"
    );
    import from jaclang.compiler.driver.boundary_classify {
        symbol_linked_source_module
    }
    import from jaclang.compiler.passes.boundary_analysis_pass {
        _parse_module_for_types
    }
    feed = _parse_module_for_types(fixture("feed_app.jac"));
    assert feed is not None;
    imp = import_of(feed, "shared_fmt");
    assert symbol_linked_source_module(imp) is None , (
        "a parsed-for-types module has unlinked import bindings; the importer itself"
        + " is not their source module"
    );
    assert import_provider_app(imp) is None , (
        "shared_fmt carries no walker, node or edge: importing it bridges nowhere"
    );
    ui = _parse_module_for_types(fixture("shared_ui.jac"));
    assert ui is not None;
    assert import_provider_app(import_of(ui, "feed_app")) == "feed" , (
        "the walker import still bridges to its owner when the binding is unlinked"
    );
}


test "ownership classification parses syntax without retaining type analysis trees" {
    import tempfile;
    import from pathlib { Path }
    import from unittest.mock { patch }
    import from jaclang.compiler.driver.compiler { JacCompiler }
    import jaclang.compiler.driver.boundary_classify as boundary;
    import jaclang.compiler.frontend.parser.frontend as frontend;
    unlinked: any = None;
    with tempfile.TemporaryDirectory() as d {
        path = Path(d) / "owned.jac";
        path.write_text("node Owned {}\n");
        with patch.object(boundary, "symbol_linked_source_module", return_value=None), patch.object(
            boundary, "bridgeable_import_target", return_value=str(path)
        ), patch.object(
            JacCompiler, "parse_str", side_effect=AssertionError("placement reentry")
        ), patch.object(frontend, "parse", wraps=frontend.parse) as parse {
            assert boundary._module_carries_owned_elements(unlinked);
            assert boundary._module_carries_owned_elements(unlinked);
            assert parse.call_count == 1;
            path.write_text("def helper -> int { return 1; }\n");
            assert not boundary._module_carries_owned_elements(unlinked);
            assert parse.call_count == 2;
        }
    }
}
