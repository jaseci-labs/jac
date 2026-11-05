import inspect;
import re;
import typing;

import from datetime { date, datetime, time }
import from enum { EnumMeta }
import from math { isfinite }
import from types { UnionType }
import from typing { Union, get_args, get_origin, get_type_hints }
import from uuid { UUID }


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
     },
     _JSON_KINDS: dict[type, str] = {
         bool: 'boolean',
         int: 'integer',
         float: 'number',
         str: 'string',
         list: 'array',
         dict: 'object'
     },
     _MAX_EXACT_FLOAT_INT: int = 2 ** 53,
     _INT_TEXT: re.Pattern = re.compile(r'[+-]?[0-9]+'),
     _FLOAT_TEXT: re.Pattern = re.compile(
         r'[+-]?([0-9]+(\.[0-9]*)?|\.[0-9]+)([eE][+-]?[0-9]+)?'
     ),
     _STRING_PARSERS: dict[type, any] = {
         datetime: datetime.fromisoformat,
         date: date.fromisoformat,
         time: time.fromisoformat,
         UUID: UUID
     };


def _mismatch(expected: str, value: any) -> ValueError;

def _coerce_bool(value: any, text: bool) -> bool;

def _coerce_int(value: any, text: bool) -> int;

def _coerce_float(value: any, text: bool) -> float;

def _coerce_string_type(value: any, target: type) -> any;

def _coerce_literal(value: any, options: tuple[object, ...], text: bool) -> any;

def _coerce_tuple(value: any, args: tuple[object, ...], text: bool) -> tuple[any, ...];

def _coerce_dict(value: any, args: tuple[object, ...], text: bool) -> dict[any, any];

def _construct_object(value: any, target: any) -> any;

def _as_item_list(value: any, text: bool) -> list[any];

def is_upload_type(target: any) -> bool;

def _accepts_upload(target: any) -> bool;

def _accepts_upload_list(target: any) -> bool;

def _accepts_single_upload(target: any) -> bool;

def _without_none(target: any) -> any;

def coerce_value(value: any, target: any = None, text: bool = False) -> any;

def _coerce_union(value: any, options: tuple[object, ...], text: bool) -> any;

def _param_target(param: APIParameter) -> any;

def _header_lookup(request: Request, name: str) -> (str | None);

def _text_values(values: list[str]) -> any;

def _extract_raw(
    param: APIParameter, request: Request, body_json: any
) -> tuple[bool, any, bool];

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
