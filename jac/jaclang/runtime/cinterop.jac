import ctypes;
import ctypes.util;
import json;
import os;
import sys;
import from ctypes.util { find_library }

def shape_ctype(shape: ScalarShape) -> any;
def _scalar_ctypes -> dict[str, any];

glob _SCALAR_CTYPES: dict[str, any] = _scalar_ctypes(),
     _LIBS: dict[str, any] = {},
     _C_STRINGS: dict[str, any] = {},
     _C_FUNCTIONS: list[any] = [],
     _C_FUNCTION_TYPES: dict[any, any] = {},
     _VIEW_RANGE: str = "PtrView index out of range";

class JacCOpaque {}

def _c_string(text: str) -> any;

class JacCStruct(ctypes.Structure) {
    def init(self: JacCStruct, *args: any, **kwargs: any);
    def __repr__(self: JacCStruct) -> str;
}

class JacPtr {
    with entry {
        _jac_elem: any = None;
        _jac_views: dict[int, type] = {};
    }

    def init(self: JacPtr, address: any = None);
    @classmethod
    def __class_getitem__(cls: type, elem: any) -> type;

    def is_null(self: JacPtr) -> bool;
    def view(self: JacPtr, n: int) -> JacPtrView;
    def _stride(self: JacPtr) -> int;
    def __add__(self: JacPtr, n: int) -> JacPtr;
    def __sub__(self: JacPtr, other: any) -> any;
    def __int__(self: JacPtr) -> int;
    def __eq__(self: JacPtr, other: any) -> bool;
    def __ne__(self: JacPtr, other: any) -> bool;
    def __lt__(self: JacPtr, other: any) -> any;
    def __le__(self: JacPtr, other: any) -> any;
    def __gt__(self: JacPtr, other: any) -> any;
    def __ge__(self: JacPtr, other: any) -> any;
    def __hash__(self: JacPtr) -> int;
    def __bool__(self: JacPtr) -> bool;
    def __repr__(self: JacPtr) -> str;
}

class JacPtrView {
    @classmethod
    def __class_getitem__(cls: type, elem: any) -> type;

    def init(self: JacPtrView, addr: int, n: int, elem: any);
    def __len__(self: JacPtrView) -> int;
    def _slot(self: JacPtrView, i: int) -> int;
    def __getitem__(self: JacPtrView, i: int) -> any;
    def __setitem__(self: JacPtrView, i: int, value: any) -> None;
}

class JacPinned {
    @classmethod
    def __class_getitem__(cls: type, elem: any) -> type;

    def init(self: JacPinned, payload: any, elem: any);

    has value: any {
        getter {
            if _is_struct_class(self._jac_elem) {
                return self._jac_obj;
            }
            return _from_c(self._jac_elem, self._jac_obj.value);
        }
        setter(self: JacPinned, new: any) -> None {
            if _is_struct_class(self._jac_elem) {
                ctypes.memmove(
                    ctypes.addressof(self._jac_obj),
                    ctypes.addressof(new),
                    ctypes.sizeof(self._jac_obj)
                );
                return;
            }
            self._jac_obj.value = _to_c_scalar(self._jac_elem, new);
        }
    }
}

class CCell {
    def init(self: CCell, elem: any, value: any);
    def get(self: CCell) -> any;
}

def _is_struct_class(elem: any) -> bool;

def _elem_ctype(elem: any) -> any;

def _scalar_name(elem: any) -> (str | None);

def _from_c(elem: any, raw: any) -> any;

def _to_c_scalar(elem: any, value: any) -> any;

def _make_ptr(cls: any, raw: any) -> any;

def c_copy(value: any) -> any;

def jac_pin(value: any, spec: any = None) -> JacPinned;

def _spec_scalar_elem(spec: any) -> (str | None);

class JacVaList {
    def init(self: JacVaList, values: any);
    def arg(self: JacVaList, kind: any) -> any;
    def to_c(self: JacVaList) -> any;
}

class _SysVVaList(ctypes.Structure) {
    with entry {
        _fields_: any = [
            ("gp_offset", ctypes.c_uint32),
            ("fp_offset", ctypes.c_uint32),
            ("overflow_arg_area", ctypes.c_void_p),
            ("reg_save_area", ctypes.c_void_p)
        ];
    }
}

class _AapcsVaList(ctypes.Structure) {
    with entry {
        _fields_: any = [
            ("stack", ctypes.c_void_p),
            ("gr_top", ctypes.c_void_p),
            ("vr_top", ctypes.c_void_p),
            ("gr_offs", ctypes.c_int32),
            ("vr_offs", ctypes.c_int32)
        ];
    }
}

def c_vararg(value: any, spec_json: str) -> any;

def c_cell(spec: str, value: any, scope: any) -> CCell;

def c_lend(spec: str, target: any, scope: any) -> JacPtr;

def _resolve_elem(spec: list[any], scope: any) -> any;

def _field_ctype(spec: list[any], scope: any) -> any;

def _c_function_address(fn: any) -> int;

def _fn_ctype(spec: list[any], scope: any) -> any;

def _arg_ctype(spec: list[any], scope: any) -> any;

def _ret_ctype(spec: list[any], scope: any) -> any;

def _field_property(name: str, raw: str, elem: any) -> property;

def _callback_property(name: str, raw: str, spec: list[any], scope: any) -> property;

def _callback_trampoline(spec: list[any], fn: any, scope: any) -> any;

def _callback_arg(spec: list[any], raw: any, scope: any) -> any;

def _lib_candidates(desc: dict[str, any], module_file: str) -> list[str];

def _load_library(desc: dict[str, any], module_file: str) -> any;

def _system_library(desc: dict[str, any]) -> (str | None);

class CFunction {
    def init(
        self: CFunction,
        lib: any,
        name: str,
        params: list[any],
        ret: list[any],
        variadic: bool,
        scope: any
    );

    def _bind(self: CFunction) -> any;
    def __call__(self: CFunction, *args: any) -> any;
    def _to_c(self: CFunction, spec: list[any], value: any, keep: list[any]) -> any;
    def _ref_addr(
        self: CFunction, spec: list[any], value: any, keep: list[any]
    ) -> any;

    def _from_c(self: CFunction, spec: list[any], raw: any) -> any;
}

class CGlobal {
    def init(self: CGlobal, lib: any, name: str, spec: list[any], scope: any);
    def define(self: CGlobal, initializer: any);
    def _cell(self: CGlobal) -> any;
    def _defined_slot(self: CGlobal, value: any) -> any;
    def _check_plain(self: CGlobal);

    has value: any { getter; setter(value: any); }

    def get(self: CGlobal) -> any;
    def set(self: CGlobal, value: any);
    def address(self: CGlobal) -> JacPtr;
}

impl CGlobal.value.getter -> any {
    return self.get();
}

impl CGlobal.value.setter(value: any) {
    self.set(value);
}

def jac_addressof(symbol: any) -> JacPtr;

def c_function_ptr(fn: any, spec_json: str, scope: any) -> JacPtr;

class _LazyLibrary {
    def init(self: _LazyLibrary, desc: dict[str, any], module_file: str);
    def __getattr__(self: _LazyLibrary, name: str) -> any;
}

def _loaded_library(lib: any) -> any;

def clib_bind(scope: any, desc_json: str) -> dict[str, any];

class _ChainScope {
    def init(self: _ChainScope, first: dict[str, any], second: dict[str, any]);
    def get(self: _ChainScope, key: str, fallback: any = None) -> any;
    def __getitem__(self: _ChainScope, key: str) -> any;
}
