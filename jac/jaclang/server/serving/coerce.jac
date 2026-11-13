import inspect;

import from types { UnionType }
import from typing { Union, get_args, get_origin }


obj RequestValidationError(Exception) {
    has errors: list[dict[str, any]] = [];

    def __str__ -> str;
}

glob _NAME_TYPES: dict[str, any] = {
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


def is_upload_type(target: any) -> bool;

def _accepts_upload(target: any) -> bool;

def _accepts_upload_list(target: any) -> bool;

def _accepts_single_upload(target: any) -> bool;

def _without_none(target: any) -> any;

def coerce_value(
    value: any, target: any = None, mode: ConvertMode = ConvertMode.STRICT
) -> any;

def _param_target(param: APIParameter) -> any;

def _header_lookup(request: Request, name: str) -> (str | None);

def _extract_raw(
    param: APIParameter, request: Request, body_json: any
) -> tuple[bool, any, ConvertMode];

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
