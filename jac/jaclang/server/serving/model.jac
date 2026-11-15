import from enum { Enum }


def _dump_value(value: any, exclude_none: bool) -> any;

obj ApiModel {
    def model_dump(mode: str = 'json', exclude_none: bool = False) -> dict[str, any];
    def to_dict -> dict[str, any];
}

def require_str(data: dict[str, any], key: str, label: str = '') -> str;
