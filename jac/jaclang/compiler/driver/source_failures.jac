import os;
import sys;

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

def module_import_in_flight(file_path: str) -> bool;

def import_error_re_enters(err: BaseException, file_path: str) -> (str | None);
