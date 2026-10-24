import json;
import types;
import typing;

import from typing { get_args, get_origin, get_type_hints, Union }

obj:pub ContractError(ValueError) {}

def:pub decode_contract(value: any, contract: any, path: str = "response") -> any;

obj:pub JsonEndpoint[T] {
    has response_type: type[T],
        path: str;

    def read(fetcher: Callable[[str], bytes]) -> T;
}
