"""Compile products cross the kernel boundary and the JIR cache as JSON records.

The MTIR graph shares nodes and closes cycles (a method points back at its
class), so its record keys nodes by position; a client manifest's global
values may be bytes or nested containers, so its record tags them."""
import from jaclang.runtime.semantic {
    ClassInfo,
    FieldInfo,
    Info,
    MethodInfo,
    ParamInfo,
    TypeForm,
    info_graph_from_json,
    info_graph_to_json
}
import from jaclang.compiler.frontend.codeinfo { ClientArtifact, ClientManifest }
import from jaclang.compiler.driver.unit_products {
    client_artifact_from_json,
    client_artifact_json
}

test "the MTIR graph keeps shared nodes and cycles through its record" {
    point = ClassInfo(
        name="Point",
        semstr="a point",
        fields=[FieldInfo(name="x", semstr=None, type_info="int")],
        base_classes=[],
        methods=[]
    );
    move = MethodInfo(
        name="move",
        semstr="moves it",
        params=[ParamInfo(name="dx", semstr=None, type_info="int")],
        return_type=TypeForm(head="list", args=[point, "str", None]),
        parent_class=point
    );
    point.methods.append(move);
    entries: dict[str, Info] = {"geo.Point": point, "geo.Point.move": move};
    restored = info_graph_from_json(info_graph_to_json(entries));
    assert sorted(restored) == ["geo.Point", "geo.Point.move"];
    back_point = restored["geo.Point"];
    back_move = restored["geo.Point.move"];
    assert isinstance(back_point, ClassInfo) and isinstance(back_move, MethodInfo);
    assert back_point.methods[0] is back_move;
    assert back_move.parent_class is back_point;
    assert back_point.fields[0].name == "x" and back_point.fields[0].type_info == "int";
    returned = back_move.return_type;
    assert isinstance(returned, TypeForm) and returned.head == "list";
    assert returned.args[0] is back_point and returned.args[1:] == ["str", None];
    assert back_move.params[0].name == "dx";
    assert back_point.semstr == "a point" and back_move.semstr == "moves it";
}

test "an unknown graph version restores nothing" {
    assert info_graph_from_json('{"version": 0, "entries": {}, "nodes": []}') == {};
}

test "a client artifact record keeps tagged global values and its source map" {
    manifest = ClientManifest(
        exports=["App"],
        globals=["LOGO", "SIZE", "TABLE"],
        params={"App": ["props"]},
        globals_values={
            "LOGO": b"\x00\xffpng",
            "SIZE": [3, 4.5],
            "TABLE": {"rows": [1, "two", True], "empty": []}
        },
        has_client=True,
        imports={"util": "/tmp/util.jac"},
        runtime_imports={"provider.jac": ["Value"]},
        tests=[{"name": "renders"}],
        server_imports=["api"],
        server_import_routes={"api": {"get_user": "/walker/get_user"}},
        page_export="App"
    );
    artifact = ClientArtifact(
        js="export function App() {}",
        manifest=manifest,
        native_import_sources=["/tmp/fast.jac"],
        source_map=[(1, 0, 3, 4, "/tmp/app.jac")],
        dep_digests={"/tmp/util.jac": "abc"},
        framework="react",
        boundary_contracts={"bindings": {}}
    );
    restored = client_artifact_from_json(client_artifact_json(artifact));
    assert restored is not None;
    assert restored.js == artifact.js;
    assert restored.manifest.globals_values == manifest.globals_values;
    assert isinstance(restored.manifest.globals_values["LOGO"], bytes);
    assert restored.manifest.server_import_routes == manifest.server_import_routes;
    assert restored.manifest.page_export == "App";
    assert restored.manifest.layout_export is None;
    assert restored.source_map == artifact.source_map;
    assert restored.dep_digests == artifact.dep_digests;
    assert restored.framework == "react";
}

test "a record from another format version is refused" {
    assert client_artifact_from_json('{"version": 3, "js": "", "manifest": {}}')
        is None;
    assert client_artifact_from_json("not json") is None;
}
