"""os.environ item assignment, deletion, membership, pop, getpid and rename."""
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
    print("pid", os.getpid() > 0);
    with open("rename_probe.src", "w") as handle {
        handle.write("x");
    }
    os.rename("rename_probe.src", "rename_probe.dst");
    print(
        "renamed",
        os.path.isfile("rename_probe.dst"),
        os.path.isfile("rename_probe.src")
    );
    os.remove("rename_probe.dst");
    try {
        os.rename("rename_probe.src", "rename_probe.dst");
    } except FileNotFoundError as error {
        print("rename missing", error);
    }
}
