import from dataclasses { fields, is_dataclass }
import from enum { Enum }


def _dump_value(value: any, exclude_none: bool) -> any {
    if isinstance(value, ApiModel) {
        return value.model_dump(exclude_none=exclude_none);
    }
    if is_dataclass(value) and not isinstance(value, type) {
        result: dict[str, any] = {};
        for f in fields(value) {
            item = _dump_value(getattr(value, f.name), exclude_none);
            if exclude_none and item is None {
                continue;
            }
            result[f.name] = item;
        }
        return result;
    }
    if isinstance(value, Enum) {
        return value.value;
    }
    if isinstance(value, list) {
        return [_dump_value(v, exclude_none) for v in value];
    }
    if isinstance(value, tuple) {
        return [_dump_value(v, exclude_none) for v in value];
    }
    if isinstance(value, dict) {
        return {k: _dump_value(v, exclude_none) for (k, v) in value.items()};
    }
    return value;
}

obj ApiModel {
    def model_dump(mode: str = 'json', exclude_none: bool = False) -> dict[str, any] {
        result: dict[str, any] = {};
        for f in fields(self) {
            value = _dump_value(getattr(self, f.name), exclude_none);
            if exclude_none and value is None {
                continue;
            }
            result[f.name] = value;
        }
        return result;
    }

    def to_dict -> dict[str, any] {
        return self.model_dump();
    }
}

def require_str(data: dict, key: str, label: str = '') -> str {
    value = data.get(key);
    name = label or key;
    if not isinstance(value, str) or not value {
        raise ValueError(f"{name} is required and must be a non-empty string");
    }
    return value;
}
