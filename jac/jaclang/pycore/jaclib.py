"""Jac library-mode surface area for Python codegen.

This module exists so the Jac compiler can import Jac "library mode" helpers
without importing `jaclang.lib` during bootstrap (which may require compiling
Jac code via the meta-importer).

It mirrors the behavior of `jaclang/lib.jac` and intentionally keeps the API
names stable because the Jac -> Python code generator emits imports for these.
"""

from __future__ import annotations

# Direct imports - no lazy loading needed since runtimelib is now pure Python
from jaclang.pycore.archetype import GenericEdge, Root
from jaclang.pycore.archetype import ObjectSpatialFunction as DSFunc
from jaclang.pycore.archetype import ObjectSpatialPath as OPath
from jaclang.pycore.constant import EdgeDir
from jaclang.pycore.constructs import Archetype as Obj
from jaclang.pycore.constructs import EdgeArchetype as Edge
from jaclang.pycore.constructs import NodeArchetype as Node
from jaclang.pycore.constructs import WalkerArchetype as Walker
from jaclang.pycore.runtime import JacRuntimeInterface

__all__ = [
    # Archetypes
    "Node",
    "Edge",
    "Walker",
    "Obj",
    "Root",
    "GenericEdge",
    "OPath",
    "DSFunc",
    # Constants
    "EdgeDir",
    # Core runtime functions
    "root",
    "spawn",
    "visit",
    "disengage",
    "connect",
    "disconnect",
    "create_j_context",
    "get_context",
    # Code generation helpers
    "impl_patch_filename",
    "jac_test",
    "jsx",
    "field",
    "log_report",
    "refs",
    "arefs",
    "filter_on",
    "assign_all",
    "safe_subscript",
    "build_edge",
    "destroy",
    "get_mtir",
    "sem",
    "call_llm",
    "by_operator",
    "on_entry",
    "on_exit",
    "thread_run",
    "thread_wait",
]

# Direct function references from JacRuntimeInterface (inherited by JacRuntime)
# Core runtime functions
connect = JacRuntimeInterface.connect
create_j_context = JacRuntimeInterface.create_j_context
disconnect = JacRuntimeInterface.disconnect
disengage = JacRuntimeInterface.disengage
get_context = JacRuntimeInterface.get_context
root = JacRuntimeInterface.root
spawn = JacRuntimeInterface.spawn
visit = JacRuntimeInterface.visit

# Code generation helpers
arefs = JacRuntimeInterface.arefs
assign_all = JacRuntimeInterface.assign_all
build_edge = JacRuntimeInterface.build_edge
by_operator = JacRuntimeInterface.by_operator
call_llm = JacRuntimeInterface.call_llm
destroy = JacRuntimeInterface.destroy
field = JacRuntimeInterface.field
filter_on = JacRuntimeInterface.filter_on
get_mtir = JacRuntimeInterface.get_mtir
impl_patch_filename = JacRuntimeInterface.impl_patch_filename
jac_test = JacRuntimeInterface.jac_test
jsx = JacRuntimeInterface.jsx
log_report = JacRuntimeInterface.log_report
refs = JacRuntimeInterface.refs
safe_subscript = JacRuntimeInterface.safe_subscript
sem = JacRuntimeInterface.sem
on_entry = JacRuntimeInterface.on_entry
on_exit = JacRuntimeInterface.on_exit
thread_run = JacRuntimeInterface.thread_run
thread_wait = JacRuntimeInterface.thread_wait
