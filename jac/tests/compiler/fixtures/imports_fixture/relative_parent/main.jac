import from project.sub.deep { DEEP_VALUE, deep_func }
import from project.config { CONFIG_VALUE }

with entry {
    print(f"Parent relative - CONFIG_VALUE: {CONFIG_VALUE}");
    print(f"Parent relative - DEEP_VALUE: {DEEP_VALUE}");
    print(f"Parent relative - deep_func(): {deep_func()}");
}
