import importlib;
import type from jaclang.runtime.archetype {
    GenericEdge,
    Root,
    ObjectSpatialFunction as DSFunc,
    Archetype as Obj,
    EdgeArchetype as Edge,
    NodeArchetype as Node,
    WalkerArchetype as Walker,
    JsxElement
}
import type from jaclang.runtime.constants { EdgeDir }
import type from jaclang.runtime.graph_query { GraphQuery, QHop, QOrder, QPred }
import type from jaclang.runtime.runtime { JacRuntimeInterface }
import type from jaclang.runtime.object_model { field }
import type from jaclang.runtime.deletion { destroy, peek_attr, peek_item }
import type from jaclang.runtime.function_metadata { impl_patch_filename }

glob __all__ = [
         'GraphQuery',
         'QHop',
         'QOrder',
         'QPred',
         'Node',
         'Edge',
         'Walker',
         'Obj',
         'Root',
         'GenericEdge',
         'JsxElement',
         'DSFunc',
         'EdgeDir',
         'root',
         'spawn',
         'visit',
         'disengage',
         'connect',
         'disconnect',
         'create_j_context',
         'get_context',
         'impl_patch_filename',
         'jac_test',
         'jsx',
         'field',
         'log_report',
         'refs',
         'hop',
         'clear_edges',
         'arefs',
         'filter_on',
         'assign_all',
         'safe_subscript',
         'build_edge',
         'destroy',
         'peek_attr',
         'peek_item',
         'get_mtir',
         'sem',
         'call_llm',
         'acall_llm',
         'by_operator',
         'on_entry',
         'on_exit',
         'set_trigger',
         'thread_run',
         'thread_wait'
     ],
     _EXPORTS: dict[str, tuple[str, str]] = {
         "destroy": ("..runtime.deletion", "destroy"),
         "peek_attr": ("..runtime.deletion", "peek_attr"),
         "peek_item": ("..runtime.deletion", "peek_item"),
         "DSFunc": ("..runtime.archetype", "ObjectSpatialFunction"),
         "Edge": ("..runtime.archetype", "EdgeArchetype"),
         "EdgeDir": ("..runtime.constants", "EdgeDir"),
         "GenericEdge": ("..runtime.archetype", "GenericEdge"),
         "GraphQuery": ("..runtime.graph_query", "GraphQuery"),
         "JacRuntimeInterface": ("..runtime.runtime", "JacRuntimeInterface"),
         "JsxElement": ("..runtime.archetype", "JsxElement"),
         "Node": ("..runtime.archetype", "NodeArchetype"),
         "Obj": ("..runtime.archetype", "Archetype"),
         "QHop": ("..runtime.graph_query", "QHop"),
         "QOrder": ("..runtime.graph_query", "QOrder"),
         "QPred": ("..runtime.graph_query", "QPred"),
         "Root": ("..runtime.archetype", "Root"),
         "Walker": ("..runtime.archetype", "WalkerArchetype"),
         "field": ("..runtime.object_model", "field"),
         "impl_patch_filename": ("..runtime.function_metadata", "impl_patch_filename"),

     };

def __getattr__(name: str) -> any {
    owner = _EXPORTS.get(name);
    if owner is not None {
        return getattr(importlib.import_module(owner[0], __package__), owner[1]);
    }
    if name in __all__ {
        import from jaclang.runtime.exports { runtime_function }
        return runtime_function(name);
    }
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}");
}
