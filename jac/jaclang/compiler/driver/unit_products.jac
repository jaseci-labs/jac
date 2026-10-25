import base64;
import json;
import os;

glob CLIENT_RECORD_VERSION: int = 5,
     DEF_DEP_SEP: str = "\x1f",
     NO_CLIENT_SIDE: str = "-";

obj UnitProducts {
    has path: str,
        jcir: bytes = b"",
        mtir: str = "",
        interop: str = "",
        client: str = "",
        placement: str = "",
        ct_file_deps: list[str] = [],
        ct_body_deps: list[str] = [],
        ct_def_deps: list[str] = [],
        def_spans: list[str] = [],
        app: str = "",
        persistence: list[str] = [],
        import_edges: list[str] = [],
        client_manifest: str = "",
        native_ir: str = "",
        native_iface: str = "",
        native_layout: str = "",
        native_deps: list[str] = [],
        iface: str = "",
        iface_shape: str = "",
        effects: str = "",
        jac_deps: list[str] = [];
}

def definition_span_rows(tree: uni.Module) -> list[str];

def note_definition_span(rows: list[str], definition: uni.UniNode, qualname: str);

def dependency_span_rows(module: uni.Module, program: JacProgram) -> list[str];

def jac_dependencies(module: uni.Module) -> list[str];

def import_edge_rows(module: uni.Module) -> list[str];

def interop_record(module: uni.Module) -> dict[str, any];

def app_edges_record(edges: list[tuple[str, str]]) -> list[any];

def interop_manifest_of(record: dict[str, any]) -> InteropManifest;

def literal_to_json(value: any) -> dict[str, any];

def literal_from_json(raw: any) -> any;

def str_list_map(value: any) -> dict[str, list[str]];

def manifest_record(manifest: ClientManifest) -> dict[str, any];

def manifest_from_record(raw: dict[str, any]) -> ClientManifest;

def client_artifact_json(artifact: ClientArtifact) -> str;

def source_map_record(segments: list[tuple[int, int, int, int, str]]) -> list[any];

def source_segment(raw: any) -> (tuple[int, int, int, int, str] | None);

def client_artifact_from_json(text: str) -> (ClientArtifact | None);

def client_pulled_indexes(module: uni.Module) -> list[int];

def client_artifact_of(module: uni.Module) -> (ClientArtifact | None);

def placement_record(module: uni.Module, program: JacProgram) -> str;

def unit_products(module: uni.Module, program: JacProgram) -> UnitProducts;

def native_products(module: uni.Module, products: UnitProducts);

def products_record(products: UnitProducts) -> dict[str, any];

def products_from_record(raw: dict[str, any]) -> UnitProducts;

def definition_deps(products: UnitProducts) -> list[tuple[str, str]];
