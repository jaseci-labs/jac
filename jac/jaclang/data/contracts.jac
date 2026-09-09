import json;
import types;
import typing;
import from jaclang.runtime.object_interop { fields, is_record }
import from jaclang.runtime.object_model { MISSING }
import from typing { get_args, get_origin, get_type_hints, Union }

obj:pub ContractError(ValueError) {}

def:pub decode_contract(value: any, contract: any, path: str = "response") -> any {
    origin = get_origin(contract);
    args = get_args(contract);
    if contract is typing.Any {
        raise ContractError(f"{path}: external contracts must specify a value shape");
    }
    if origin is Union or origin is types.UnionType {
        for alternative in args {
            try {
                return decode_contract(value, alternative, path);
            } except ContractError {}
        }
        raise ContractError(f"{path}: value does not match {contract}");
    }
    if contract is type(None) {
        if value is None {
            return None;
        }
        raise ContractError(f"{path}: expected null");
    }
    if origin is list {
        if not isinstance(value, list) {
            raise ContractError(f"{path}: expected list");
        }
        return [
            decode_contract(v, args[0], f"{path}[{i}]") for (i, v) in enumerate(value)
        ];
    }
    if contract in (str, int, bool, float) {
        if type(value) is not contract {
            raise ContractError(f"{path}: expected {contract.__name__}");
        }
        return value;
    }
    if not is_record(contract) or not isinstance(value, dict) {
        raise ContractError(f"{path}: expected declared record {contract}");
    }
    hints = get_type_hints(contract);
    kwargs: dict = {};
    for f in fields(contract) {
        if not f.init {
            continue;
        }
        if f.name not in value {
            if f.default is MISSING and f.default_factory is None {
                raise ContractError(f"{path}.{f.name}: missing required field");
            }
            continue;
        }
        kwargs[f.name] = decode_contract(
            value[f.name], hints[f.name], path + "." + f.name
        );
    }
    return contract(**kwargs);
}

obj:pub JsonEndpoint[T] {
    has response_type: type[T],
        path: str;

    def read(fetcher: Callable[[str], bytes]) -> T {
        return decode_contract(json.loads(fetcher(self.path)), self.response_type);
    }
}
