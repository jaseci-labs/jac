def _is_enabled -> bool;

def _get_root_anchor(anchor: any) -> any;

def _type_name(`obj: object) -> str;

def _get_type_mro(`obj: object) -> list[str];

def _index_edge_into(root_anchor: any, source: any, target: any, `edge: any) -> None;

def _unindex_edge_from(root_anchor: any, source: any, target: any, `edge: any) -> None;

def on_edge_created(source: any, target: any, `edge: any) -> None;

def on_edge_destroyed(source: any, target: any, `edge: any) -> None;

def on_node_saved(node_anchor: any) -> None;

def on_node_destroyed(node_anchor: any) -> None;
