"""Entry module reaching a sibling through a relative import."""

import from .services.greeter { greet }

def entry_greeting -> str {
    return greet();
}
