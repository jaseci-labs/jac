import copy;
import hashlib;
import os;
import from contextlib { contextmanager }
import from contextvars { ContextVar }
import from collections.abc { Iterator }

glob _active_options: ContextVar[CompileOptions | None] = ContextVar(
         'jac_active_options', `default=None
     );

@contextmanager
def cache_scope(options: CompileOptions | None = None) -> Iterator[None];

@contextmanager
def compilation_scope(options: CompileOptions | None = None) -> Iterator[None];

def active_options -> CompileOptions | None;

def owned_module_options(path: str, options: CompileOptions) -> CompileOptions;

def owner_scope_options(
    program: JacProgram, options: (CompileOptions | None) = None
) -> (CompileOptions | None);

def package_owned(path: str, program: JacProgram, options: CompileOptions) -> bool;

def bind_options(
    path: str, program: JacProgram, options: CompileOptions
) -> CompileOptions;

def context_identity(options: CompileOptions) -> str;

def context_program(program: JacProgram, options: CompileOptions) -> JacProgram;

def program_for(path: str, program: JacProgram) -> JacProgram;

def context_app(path: str) -> AppSpec | None;
