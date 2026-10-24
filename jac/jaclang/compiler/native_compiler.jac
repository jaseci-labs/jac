import ctypes;
import json;
import os;
import sys;
import from ctypes { c_char_p, c_double, c_int64, c_void_p, cast, py_object }

glob CODE_INT: int = 1,
     CODE_BOOL: int = 2,
     CODE_STR: int = 3,
     CODE_ENUM: int = 4,
     CODE_OPTREF: int = 5,
     CODE_OBJ: int = 6,
     CODE_NATLIST: int = 7,
     CODE_UNION: int = 8,
     CODE_OPTENUM: int = 9,
     CODE_NATDICT: int = 10,
     CODE_SHAPES: int = 11,
     CODE_NATSET: int = 13,
     CODE_OPTSTR: int = 14,
     CODE_OPTLIST: int = 15;

glob SHAPES_FIELD: str = "_role_shapes";

glob CLASS_MODULES: tuple[str, ...] = (
         "jaclang.compiler.frontend.unitree",
         "jaclang.compiler.frontend.codeinfo",
         "jaclang.compiler.frontend.srcloc",
         "jaclang.compiler.frontend.constant",
         "jaclang.compiler.frontend.parser.tokens",
         "jaclang.compiler.frontend.roles",
         "jaclang.compiler.frontend.relations",
         "jaclang.compiler.frontend.diagnostics",
         "jaclang.compiler.passes.context",

     );

def _enum_class(name: str, owner: type) -> type | None;


def _enum_table(cls: any) -> (dict[int, object] | None);

class NativeCompiler {
    def init(self: NativeCompiler, lib_path: str, layout: dict[str, any]);
    def _ensure_registered(self: NativeCompiler);
    def _bind(self: NativeCompiler);
    def _hold(self: NativeCompiler, o: any) -> int;
    def _intern(self: NativeCompiler, s: str) -> int;
    def _resolve_classes(self: NativeCompiler);
    def _class_tag(self: NativeCompiler, name: str) -> int;
    def _field_annotations(self: NativeCompiler, cls: any) -> dict[str, str];
    def _register_fields(self: NativeCompiler, name: str, cls: any, tag: int);
    def _register_value(self: NativeCompiler, schema: dict[str, any]) -> int;
    def _shapes_layout(self: NativeCompiler, aux: str) -> int;
    def _register_defaults(self: NativeCompiler, cls: any, tag: int);
    def _register_edges(self: NativeCompiler);
    def _register(self: NativeCompiler);
    def _call_strs(self: NativeCompiler, name: str, *texts: str) -> int;
    def annex(self: NativeCompiler, annex: WovenAnnex) -> int;
    def run(self: NativeCompiler, source: str, path: str) -> int;
    def prepare_early(self: NativeCompiler, context: str);
    def take_pass_results(self: NativeCompiler) -> dict[str, PassResult];
    def _take(self: NativeCompiler, ptr: any) -> any;
    def take_module(self: NativeCompiler) -> any;
    def take_diags(self: NativeCompiler) -> list[SrcDiag];
    def take_lexdiags(self: NativeCompiler) -> list[SrcDiag];
    def take_comments(self: NativeCompiler) -> list[CommentData];
    def err_count(self: NativeCompiler) -> int;
    def lex_errs(self: NativeCompiler) -> int;
    def skipped(self: NativeCompiler) -> int;
}


glob _KERNEL_CELL: list[any] = [],
     _RESOLVED: list[any] = [],
     _RESOLVING: list[any] = [],
     _LOADED: dict[str, NativeCompiler] = {},
     _FAILED: list[tuple[str, str, str]] = [];

def runtime_builtin_initializing -> bool;

def ensure_loaded -> (NativeCompiler | None);

def load_failure -> (tuple[str, str, str] | None);

def reset_loaded;
