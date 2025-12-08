# Fixture 08: deep.jac - uses .. to go up one level
# project/sub/deep.jac

import from ..config { CONFIG_VALUE, DEBUG }

glob DEEP_VALUE = f"Deep module using config: {CONFIG_VALUE}";

def deep_func -> str {
    return f"Deep function, DEBUG={DEBUG}";
}
