"""Jac library-mode surface area for Python codegen.

This module exists so the Jac compiler can import Jac "library mode" helpers
without importing `jaclang.lib` during bootstrap (which may require compiling
Jac code via the meta-importer).

It mirrors the behavior of `jaclang/lib.jac` and intentionally keeps the API
names stable because the Jac -> Python code generator emits imports for these.
"""
import from jaclang.jac0core.archetype { GenericEdge, Root }
import from jaclang.jac0core.archetype { ObjectSpatialFunction as DSFunc }
import from jaclang.jac0core.archetype { ObjectSpatialPath as OPath }
import from jaclang.jac0core.constant { EdgeDir }
import from jaclang.jac0core.constructs { Archetype as Obj }
import from jaclang.jac0core.constructs { EdgeArchetype as Edge }
import from jaclang.jac0core.constructs { JsxElement }
import from jaclang.jac0core.constructs { NodeArchetype as Node }
import from jaclang.jac0core.constructs { WalkerArchetype as Walker }
import from jaclang.jac0core.runtime { JacRuntimeInterface }
glob __all__ = [
         'Node',
         'Edge',
         'Walker',
         'Obj',
         'Root',
         'GenericEdge',
         'JsxElement',
         'OPath',
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
         'arefs',
         'filter_on',
         'assign_all',
         'safe_subscript',
         'build_edge',
         'destroy',
         'get_mtir',
         'sem',
         'call_llm',
         'by_operator',
         'on_entry',
         'on_exit',
         'thread_run',
         'thread_wait'
     ],
     connect = JacRuntimeInterface.connect,
     create_j_context = JacRuntimeInterface.create_j_context,
     disconnect = JacRuntimeInterface.disconnect,
     `disengage = JacRuntimeInterface.disengage,
     get_context = JacRuntimeInterface.get_context,
     `root = JacRuntimeInterface.root,
     `spawn = JacRuntimeInterface.spawn,
     `visit = JacRuntimeInterface.visit,
     arefs = JacRuntimeInterface.arefs,
     assign_all = JacRuntimeInterface.assign_all,
     build_edge = JacRuntimeInterface.build_edge,
     by_operator = JacRuntimeInterface.by_operator,
     call_llm = JacRuntimeInterface.call_llm,
     destroy = JacRuntimeInterface.destroy,
     field = JacRuntimeInterface.field,
     filter_on = JacRuntimeInterface.filter_on,
     get_mtir = JacRuntimeInterface.get_mtir,
     impl_patch_filename = JacRuntimeInterface.impl_patch_filename,
     jac_test = JacRuntimeInterface.jac_test,
     jsx = JacRuntimeInterface.jsx,
     log_report = JacRuntimeInterface.log_report,
     refs = JacRuntimeInterface.refs,
     safe_subscript = JacRuntimeInterface.safe_subscript,
     `sem = JacRuntimeInterface.sem,
     on_entry = JacRuntimeInterface.on_entry,
     on_exit = JacRuntimeInterface.on_exit,
     thread_run = JacRuntimeInterface.thread_run,
     thread_wait = JacRuntimeInterface.thread_wait;
