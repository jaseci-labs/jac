import ctypes;
import logging;
import from collections.abc { Callable, Iterable }
import from typing { Protocol }
class CallbackSignature(Protocol) {
    has name: str,
        ret_type: str,
        param_types: list[str];
}

obj NativeCallback {
    has name: str,
        ret_type: str,
        param_types: list[str];
}

obj NativeLibrary {
    has path: str,
        bindings: list[NativeCallback] = [],
        library: ctypes.CDLL | None = None,
        initialized: bool = False,
        callbacks: list[object] = [],
        functions: dict[str, Callable] = {};

    def handle -> ctypes.CDLL;
    def get_function_address(name: str) -> int;
    def register_symbol(name: str, address: int);
    def initialize -> None;
}

glob logger = logging.getLogger(__name__),
     JAC_TO_CTYPES: dict[(str, type)] = {
         'int': ctypes.c_int64,
         'float': ctypes.c_double,
         'bool': ctypes.c_bool,
         'str': ctypes.c_char_p
     },
     _pyb_shadows: dict[(int, object)] = {},
     _pyb_class_memo: dict[(tuple[any, ...], type)] = {},
     _pyb_module_memo: dict[(str, object)] = {};

def _pyb_import_module(mod_path: str) -> object;

def _pyb_class_for(
    mod_path: str, base_name: str, cls_name: str, suppress_postinit: bool
) -> type;

def _pyb_instantiate(
    mod_path: str,
    base_name: str,
    cls_name: str,
    kwargs: dict[str, any],
    suppress_postinit: bool,
    owner_addr: int
) -> object;

def _pyb_shadow_of(owner_addr: int) -> object;

def _pyb_drop_owner(owner_addr: int);

def _pyb_super_call(
    shadow: object,
    anchor_name: str,
    meth_names: tuple[str, ...],
    args: tuple[any, ...],
    kwargs: dict[str, any]
) -> object;

def register_py_callbacks(
    bindings: Iterable[CallbackSignature],
    py_func_table: dict[(str, Callable[(..., object)])],
    callbacks_list: list[object],
    register_symbol: Callable[[str, int], None]
);
