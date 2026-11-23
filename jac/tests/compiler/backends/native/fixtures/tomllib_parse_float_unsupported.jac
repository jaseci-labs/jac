import from tomllib { loads }

def parse_float_marker(raw: str) -> str {
    return "float:" + raw;
}

with entry {
    try {
        loads("value = 1.25", parse_float=parse_float_marker);
        print("parse_float callback unexpectedly accepted");
    } except NotImplementedError {
        print("native parse_float callback unsupported");
    }
}
