import os;
import sys;
import from jaclang.compiler.driver.program { JacProgram }

class CompilerSourceError(RuntimeError) {}

glob _compiler_source_failures: dict[str, str] = {};

def note_compiler_source_failure(path: str, details: str) {
    key = os.path.realpath(path);
    if details {
        _compiler_source_failures[key] = details;
    } else {
        _compiler_source_failures.pop(key, None);
    }
}

def compiler_source_failure_details(path: str) -> str {
    return _compiler_source_failures.get(os.path.realpath(path), '');
}

def module_scoped_failure_details(path: str, program: JacProgram) -> str {
    return '\n'.join(a.pretty_print() for a in program.diags.owned_errors(path));
}

def bootstrap_tier_failure_details(path: str) -> str {
    import from jaclang.compiler.driver.schedules { schedule_tier_reason }
    reason = schedule_tier_reason();
    if not reason {
        return '';
    }
    return (
        f"{path} was compiled on the bootstrap tier because {reason}, and "
        "that tier could not produce its bytecode. A module that needs the "
        "full compiler must not be reached from a schedule dependency at "
        "module scope: keep that import function-local, or pre-import the "
        "module in the schedule loader (see IR_SCHED_DEPS in "
        "jaclang.compiler.driver.schedules)."
    );
}

def _compiler_source_root -> str {
    import jaclang;
    return os.path.realpath(os.path.dirname(str(jaclang.__file__)));
}

def _jac_source_failure_path(err: BaseException) -> (str | None) {
    cursor: any = err;
    for _ in range(8) {
        if cursor is None {
            break;
        }
        path = cursor?.jac_source_path;
        if isinstance(path, str) and path {
            return path;
        }
        cursor = cursor?.__cause__ or cursor?.__context__;
    }
    return None;
}

def fail_loud_on_compiler_source(err: ImportError) -> None {
    path = _jac_source_failure_path(err);
    if path is None {
        return;
    }
    real = os.path.realpath(path);
    if not real.startswith(_compiler_source_root() + os.sep) {
        return;
    }
    raise CompilerSourceError(
        "the Jac compiler's own source failed to compile, so the pass "
        f"schedule cannot be built: {real}\n{err}"
    ) from err;
}

def compiler_source_failure_origin(err: BaseException) -> (str | None) {
    `root = _compiler_source_root() + os.sep;
    cursor: any = err;
    for _ in range(8) {
        if cursor is None {
            break;
        }
        for cand in (cursor?.jac_source_path, cursor?.path) {
            if isinstance(cand, str) and cand {
                real = os.path.realpath(cand);
                if real.startswith(`root) {
                    return real;
                }
            }
        }
        name = cursor?.name;
        if isinstance(name, str)
            and (name == 'jaclang' or name.startswith('jaclang.')) {
            return name;
        }
        cursor = cursor?.__cause__ or cursor?.__context__;
    }
    return None;
}

def module_import_in_flight(file_path: str) -> bool {
    for mod in list(sys.modules.values()) {
        spec = mod?.__spec__;
        if spec is None {
            continue;
        }
        if spec?.origin == file_path and bool(spec?._initializing) {
            return True;
        }
    }
    return False;
}

def import_error_re_enters(err: BaseException, file_path: str) -> (str | None) {
    if not isinstance(err, ImportError) or not module_import_in_flight(file_path) {
        return None;
    }
    cursor: any = err;
    for _ in range(8) {
        if cursor is None {
            break;
        }
        name = cursor?.name;
        if isinstance(name, str) and name {
            spec = sys.modules.get(name)?.__spec__;
            if spec is not None and spec?.origin == file_path {
                return name;
            }
        }
        cursor = cursor?.__cause__ or cursor?.__context__;
    }
    return None;
}
