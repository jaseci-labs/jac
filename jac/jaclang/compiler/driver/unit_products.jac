import base64;
import json;
import os;

glob CLIENT_RECORD_VERSION: int = 5,
     DEF_DEP_SEP: str = "\x1f";

obj UnitProducts {
    has path: str,
        mtir: str = "",
        interop: str = "",
        client: (ClientArtifact | None) = None,
        placement: str = "",
        ct_file_deps: list[str] = [],
        ct_body_deps: list[str] = [],
        ct_def_deps: list[tuple[str, str]] = [],
        def_spans: list[str] = [];
}

def definition_span_rows(tree: uni.Module) -> list[str];

def note_definition_span(rows: list[str], definition: uni.UniNode, qualname: str);

def dependency_span_rows(module: uni.Module, program: JacProgram) -> list[str];

def import_edges(module: uni.Module) -> list[tuple[bool, str, list[str]]];

def interop_record(module: uni.Module) -> dict[str, any];

def interop_json(module: uni.Module) -> str;

def interop_manifest_of(record: dict[str, any]) -> InteropManifest;

def literal_to_json(value: any) -> dict[str, any];

def literal_from_json(raw: any) -> any;

def str_list_map(value: any) -> dict[str, list[str]];

def manifest_record(manifest: ClientManifest) -> dict[str, any];

def manifest_from_record(raw: dict[str, any]) -> ClientManifest;

def client_artifact_json(artifact: ClientArtifact) -> str;

def source_segment(raw: any) -> (tuple[int, int, int, int, str] | None);

def client_artifact_from_json(text: str) -> (ClientArtifact | None);

def client_pulled_indexes(module: uni.Module) -> list[int];

def client_artifact_of(module: uni.Module) -> (ClientArtifact | None);

def placement_record(
    module: uni.Module, program: JacProgram, solved: bool = True
) -> str;

def unit_products(module: uni.Module, program: JacProgram) -> UnitProducts;

def json_str_list(value: object) -> list[str];

def json_str_map(value: object) -> dict[str, str];

def json_map(value: object) -> dict[str, any];

def json_maps(value: object) -> list[dict[str, any]];

def json_opt_str(value: object) -> (str | None);
