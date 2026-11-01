"""The host's compile entry. Every compile is a request to the in-process
kernel (`jac_kernel`); the host only builds requests and adopts results."""
import marshal;
import os;
import sys;

glob _APPLICATION_UNITS: dict[str, CompiledUnit] = {};

class KernelReported {}

def compile_request_for(
    paths: list[str],
    options: CompileOptions,
    sources: dict[str, str],
    products: list[str]
) -> CompileRequest;

def check_request_for(
    paths: list[str],
    options: CompileOptions,
    native_coverage: bool = False,
    placements: bool = False,
    closure: bool = False
) -> CheckRequest;

def span_of(record: SourceSpan) -> Span;

def alert_of(diag: KernelDiagnostic) -> Alert;

def adopt_diagnostics(
    program: JacProgram, errors: list[KernelDiagnostic], warnings: list[KernelDiagnostic]
);

def kernel_compile(
    program: JacProgram,
    paths: list[str],
    options: CompileOptions,
    sources: (dict[str, str] | None) = None,
    products: (list[str] | None) = None
) -> CompileResult;

def compile_through_kernel(
    program: JacProgram, file_path: str, use_str: (str | None), options: CompileOptions
) -> uni.Module;

def kernel_compile_application(
    program: JacProgram, paths: list[str], options: CompileOptions
) -> CompileResult;

def take_application_unit(path: str) -> (CompiledUnit | None);

def forget_application_units;

def native_build_request_for(
    roots: list[str], kind: str, options: CompileOptions, output: str = ""
) -> NativeBuildRequest;

def kernel_native_build(
    program: JacProgram, request: NativeBuildRequest
) -> NativeBuildResult;

def kernel_module_facts(
    program: JacProgram, paths: list[str], options: CompileOptions, closure: bool = False
) -> CheckResult;

def persist_units(units: list[CompiledUnit]);

def unit_client_artifact(unit: CompiledUnit) -> (ClientArtifact | None);

def kernel_client_artifact(
    program: JacProgram, path: str, options: CompileOptions
) -> (ClientArtifact | None);
