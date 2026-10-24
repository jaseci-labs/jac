import os;

def _coerce_module(module: uni.Module, context: CodeContext);

def _coerce_client_module(module: uni.Module);

def _coerce_native_module(module: uni.Module);

def _stamp_context_element(elem: uni.UniNode, context: CodeContext);

def hub_module_for_path(path: str, prog: JacProgram) -> (uni.Module | None);

def module_has_client_top(module: (uni.Module | None)) -> bool;

def ability_delegates_to_model(ab: uni.Ability) -> bool;

def is_server_anchored_module(module: (uni.Module | None)) -> bool;

def classify_import(imp: uni.Import) -> BareImportVerdict;

def module_own_native_anchor(module: (uni.Module | None)) -> bool;


def plain_native_import_target(nd: uni.Import, prog: JacProgram) -> (str | None);

def import_declares_native_target(
    nd: uni.Import, prog: (JacProgram | None) = None
) -> bool;

def native_only_import_target(nd: uni.Import, prog: JacProgram) -> (str | None);

def _python_side_emits(stmt: uni.UniNode, native_module: bool) -> bool;

def python_side_name_refs(mod: uni.Module) -> set[str];

def import_bound_names(nd: uni.Import) -> list[str];

def clib_decl_type_names(nd: uni.Import) -> set[str];

def is_client_native_edge_import(
    nd: uni.Import, prog: JacProgram, client_tops: (dict[str, bool] | None) = None
) -> bool;

def _has_client_top(
    module: (uni.Module | None), client_tops: (dict[str, bool] | None)
) -> bool;

enum ClientImportVerdict {
    CLIENT = "client",
    BRIDGED = "bridged",
    DEAD = "dead",
    UNKNOWN = "unknown"
}

enum CrossAppKind {
    LOCAL = "local",
    CLIENT_BRIDGE = "client_bridge",
    SERVICE_BRIDGE = "service_bridge",
    NATIVE_BIND = "native_bind"
}

def bridgeable_import_target(nd: uni.Import) -> (str | None);

def is_service_app_entry(path: str) -> bool;

def module_app(module: (uni.Module | None)) -> (str | None);

def import_consumer_app(nd: uni.Import) -> (str | None);

def same_workspace(consumer_path: str, provider_path: str) -> bool;

def import_provider_spec(nd: uni.Import) -> (AppSpec | None);

def import_provider_app(nd: uni.Import) -> (str | None);

def import_provider_route(nd: uni.Import) -> str;

def import_crosses_apps(nd: uni.Import) -> bool;

def is_service_bridge_import(nd: uni.Import) -> bool;

def classify_cross_app_import(
    nd: uni.Import, manifest: (InteropManifest | None)
) -> CrossAppKind;

def is_client_boundary_import(nd: uni.Import) -> bool;

def symbol_linked_source_module(nd: uni.Import) -> (uni.Module | None);

def _declared_name(stmt: uni.ContextAwareNode) -> (str | None);

def _import_item_declaration(
    source_mod: uni.Module, item: uni.ModuleItem
) -> (uni.ContextAwareNode | None);

def classify_client_import_item(
    source_mod: uni.Module, item: uni.UniNode
) -> ClientImportVerdict;

def import_binds_client_native(
    nd: uni.Import, manifest: (InteropManifest | None)
) -> bool;

def _default_codespace_for(target_program: JacProgram) -> str;
