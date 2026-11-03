def json_map(value: any) -> dict[str, any];

def json_maps(value: any) -> list[dict[str, any]];

def json_list(value: any) -> list[any];

def json_str_list(value: any) -> list[str];

def json_str_map(value: any) -> dict[str, str];

def json_opt_str(value: any) -> (str | None);

def json_opt_str_list(value: any) -> (list[str | None] | None);

def json_bytes(value: any) -> bytes;

def json_int_bytes_map(value: any) -> dict[int, bytes];
