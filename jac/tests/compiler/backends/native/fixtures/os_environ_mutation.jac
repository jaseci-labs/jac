"""os.environ item assignment, deletion, membership and pop."""
import os;

def caught(action: str) -> str {
    try {
        if action == "read" {
            return os.environ["JAC_ENV_PROBE_MISSING"];
        }
        if action == "delete" {
            del os.environ["JAC_ENV_PROBE_MISSING"];
        }
        if action == "pop" {
            return os.environ.pop("JAC_ENV_PROBE_MISSING");
        }
        if action == "name" {
            os.environ["JAC=PROBE"] = "1";
        }
    } except KeyError {
        return "KeyError";
    } except ValueError as error {
        return f"ValueError {error}";
    }
    return "no error";
}

with entry {
    os.environ["JAC_ENV_PROBE"] = "set";
    print("read", os.environ["JAC_ENV_PROBE"], os.environ.get("JAC_ENV_PROBE", ""));
    print("in", "JAC_ENV_PROBE" in os.environ, "JAC_ENV_PROBE_MISSING" in os.environ);
    print("not in", "JAC_ENV_PROBE_MISSING" not in os.environ);
    print("child", os.system('test "$JAC_ENV_PROBE" = set'));
    os.environ["JAC_ENV_PROBE"] = "again";
    print("overwrite", os.environ["JAC_ENV_PROBE"]);
    del os.environ["JAC_ENV_PROBE"];
    print("deleted", os.environ.get("JAC_ENV_PROBE", "gone"));
    os.environ["JAC_ENV_PROBE"] = "popped";
    print(
        "pop",
        os.environ.pop("JAC_ENV_PROBE"),
        os.environ.pop("JAC_ENV_PROBE", "default")
    );
    for action in ["read", "delete", "pop", "name"] {
        print(action, caught(action));
    }
}
