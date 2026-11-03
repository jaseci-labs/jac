import os;
import sys;

obj SessionClient {
    has project_root: str,
        handle: int = 0,
        local: (KernelSession | None) = None;

    def query(method: str, args: list[any]) -> any;
    def close;
}

def world_paths -> tuple[list[str], str];

def call_compile(request: CompileRequest) -> CompileResult;

def call_check(request: CheckRequest) -> CheckResult;

def open_kernel_session(project_root: str) -> SessionClient;
