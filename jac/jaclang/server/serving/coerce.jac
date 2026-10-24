import inspect;
import typing;

import from enum { EnumMeta }
import from types { UnionType }
import from typing { Union, get_args, get_origin, get_type_hints }


obj RequestValidationError(Exception) {
    has errors: list[dict[str, any]] = [];

    def __str__ -> str;
}

glob _TRUE_STRINGS: set[str] = {'1', 'true', 'yes', 'on', 'y'},
     _FALSE_STRINGS: set[str] = {'0', 'false', 'no', 'off', 'n', ''},
     _NAME_TYPES: dict[str, any] = {
         'str': str,
         'string': str,
         'int': int,
         'integer': int,
         'float': float,
         'number': float,
         'bool': bool,
         'boolean': bool,
         'list': list,
         'array': list,
         'dict': dict,
         'object': dict,
         'any': None,
         '': None
     };


def _coerce_bool(value: any) -> bool;

def _construct_object(value: any, target: any) -> any;

def _as_item_list(value: any) -> list[any];

def is_upload_type(target: any) -> bool;

def _accepts_upload(target: any) -> bool;

def _accepts_upload_list(target: any) -> bool;

def _accepts_single_upload(target: any) -> bool;

def _without_none(target: any) -> any;

def coerce_value(value: any, target: any = None) -> any;

def _coerce_union(value: any, options: tuple[object, ...]) -> any;

def _param_target(param: APIParameter) -> any;

def _header_lookup(request: Request, name: str) -> (str | None);

def _extract_raw(
    param: APIParameter, request: Request, body_json: any
) -> tuple[bool, any];

def _fresh_default(value: any) -> any;

def bind_parameters(ep: JEndPoint, request: Request, body_json: any) -> dict[str, any];

obj CallbackSpec {
    has names: set[str] = set(),
        body_candidates: list[str] = [],
        accepts_var_kw: bool = False,
        wants_request: bool = False,
        request_positional: bool = False,
        introspectable: bool = True,
        is_async: bool = False;
}

def build_callback_spec(callback: any) -> CallbackSpec;

def get_callback_spec(ep: JEndPoint) -> CallbackSpec;

def body_param_name(spec: CallbackSpec, bound: dict[str, any]) -> (str | None);

def filter_kwargs_for_callback(
    spec: CallbackSpec, kwargs: dict[str, any], request: Request
) -> dict[str, any];
