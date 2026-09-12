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
import type from jaclang.compiler.frontend.constant { EdgeDir }
import type from jaclang.runtime.graph_query { GraphQuery, QHop, QOrder, QPred }
import type from jaclang.runtime.runtime { JacRuntimeInterface }
import type from jaclang.runtime.object_model { field }
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
         "DSFunc": ("jaclang.runtime.archetype", "ObjectSpatialFunction"),
         "Edge": ("jaclang.runtime.archetype", "EdgeArchetype"),
         "EdgeDir": ("jaclang.compiler.frontend.constant", "EdgeDir"),
         "GenericEdge": ("jaclang.runtime.archetype", "GenericEdge"),
         "GraphQuery": ("jaclang.runtime.graph_query", "GraphQuery"),
         "JacRuntimeInterface": ("jaclang.runtime.runtime", "JacRuntimeInterface"),
         "JsxElement": ("jaclang.runtime.archetype", "JsxElement"),
         "Node": ("jaclang.runtime.archetype", "NodeArchetype"),
         "Obj": ("jaclang.runtime.archetype", "Archetype"),
         "QHop": ("jaclang.runtime.graph_query", "QHop"),
         "QOrder": ("jaclang.runtime.graph_query", "QOrder"),
         "QPred": ("jaclang.runtime.graph_query", "QPred"),
         "Root": ("jaclang.runtime.archetype", "Root"),
         "Walker": ("jaclang.runtime.archetype", "WalkerArchetype"),
         "field": ("jaclang.runtime.object_model", "field"),
         "impl_patch_filename": (
             "jaclang.runtime.function_metadata",
             "impl_patch_filename"
         ),

     };

def __getattr__(name: str) -> any {
    owner = _EXPORTS.get(name);
    if owner is not None {
        return getattr(importlib.import_module(owner[0]), owner[1]);
    }
    if name in __all__ {
        runtime = importlib.import_module("jaclang.runtime.runtime");
        return getattr(runtime.JacRuntimeInterface, name);
    }
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}");
}
