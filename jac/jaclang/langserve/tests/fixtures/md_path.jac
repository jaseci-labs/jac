"""Living Workspace of Jac project."""

import asyncio;
import logging;
import time;
import from concurrent.futures { ThreadPoolExecutor } # TODO: go_to_def is not working here bcz threadpoolexecutor is inside some if statement
import from typing { Callable, Optional }

import jaclang.compiler.unitree as uni;
import from jaclang { JacMachineInterface }
import from jaclang.compiler.constant { SymbolType }
import from jaclang.compiler.program { JacProgram }
import from jaclang.compiler.type_system.type_utils { get_completion_items }
import from jaclang.compiler.type_system.types { ClassType, FunctionType, ModuleType, TypeBase }
import from jaclang.compiler.unitree { UniScopeNode }
import from missing_mod { SemTokManager }
import from circle {RAD}
import from jaclang.vendor.pygls { uris }
import from jaclang.vendor.pygls.server { LanguageServer }

import lsprotocol.types as lspt;
import nonexistent_module;