import os;

class CompilerSourceError(RuntimeError) {}

glob _compiler_source_failures: dict[str, str] = {};

def note_compiler_source_failure(path: str, details: str);

def compiler_source_failure_details(path: str) -> str;

def module_scoped_failure_details(path: str, program: JacProgram) -> str;

def bootstrap_tier_failure_details(path: str) -> str;

def _compiler_source_root -> str;

def _jac_source_failure_path(err: BaseException) -> (str | None);

def fail_loud_on_compiler_source(err: ImportError) -> None;

def compiler_source_failure_origin(err: BaseException) -> (str | None);
