"""Living Workspace of Jac project."""

import asyncio;
import logging;
import time;
import from concurrent.futures { ThreadPoolExecutor }  # TODO: go_to_def is not working here bcz threadpoolexecutor is inside some if statement
import from typing { Optional }

import jaclang.compiler.ir.schema as uni;
import from jaclang { JacRuntimeInterface }
import from jaclang.compiler.ir.enums { SymbolType }
import from jaclang.compiler.session.session { JacProgram }
import from jaclang.lsp.server.utils { get_completion_items }
import from jaclang.compiler.ir.types.nodes {
    ClassType,
    FunctionType,
    ModuleType,
    TypeBase
}
import from jaclang.compiler.ir.schema { UniScopeNode }
import from missing_mod { SemTokManager }
import from circle { RAD }
import from jaclang.lsp.protocol { uris }
import from jaclang.lsp.protocol.server { LanguageServer }

import jaclang.lsp.protocol.types as lspt;
import nonexistent_module;

include jaclang.compiler.pipeline.log;
