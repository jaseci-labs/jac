"""The cli app: a plain program over the shared helper."""

import from core.helper { label }

with entry {
    print(label(3));
}

def cli_secret -> str {
    return "secret";
}
