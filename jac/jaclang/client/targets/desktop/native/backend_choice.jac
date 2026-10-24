import json;
import os;

glob ASK: str = "ask",
     EMBEDDED_BACKEND: str = "embedded";


obj BackendChoice {
    has backends: dict[str, str],
        active: str = "",
        default_name: str = ASK,
        path: str = "",
        relaunch: bool = False;

    static def load(
        backends: dict[str, str], default_name: str, path: str
    ) -> BackendChoice;

    def backend -> str;
    def api_base -> str;
    def describe -> dict[str, any];
    def script -> str;
    def choose(name: str) -> bool;
}

impl BackendChoice.load(
    backends: dict[str, str], default_name: str, path: str
) -> BackendChoice {
    saved = "";
    try {
        with open(path, encoding="utf-8") as f {
            saved = str(json.load(f).get("name", "") or "");
        }
    } except (OSError, ValueError, AttributeError) {
        saved = "";
    }
    active = saved
        if saved in backends
        else (default_name if default_name in backends else "");
    return BackendChoice(
        backends=dict(backends), active=active, default_name=default_name, path=path
    );
}

impl BackendChoice.backend -> str {
    return self.backends.get(self.active, "");
}

impl BackendChoice.api_base -> str {
    value = self.backend();
    return "" if value == EMBEDDED_BACKEND else value;
}

impl BackendChoice.describe -> dict[str, any] {
    options: list[dict[str, str]] = [];
    for (name, value) in self.backends.items() {
        embedded = value == EMBEDDED_BACKEND;
        options.append(
            {
                "name": name,
                "kind": "embedded" if embedded else "remote",
                "url": "" if embedded else value
            }
        );
    }
    return {"active": self.active, "default": self.default_name, "backends": options};
}

impl BackendChoice.script -> str {
    lines = ["window.__JAC_BACKEND__=" + json.dumps(self.describe()) + ";"];
    base = self.api_base();
    if base {
        lines.append("window.__JAC_API_BASE_URL__=" + json.dumps(base) + ";");
    }
    return "\n".join(lines) + "\n";
}

impl BackendChoice.choose(name: str) -> bool {
    if name not in self.backends {
        raise ValueError(f"unknown backend '{name}'");
    }
    if name == self.active {
        return False;
    }
    os.makedirs(os.path.dirname(os.path.abspath(self.path)), exist_ok=True);
    tmp = self.path + ".tmp";
    with open(tmp, "w", encoding="utf-8") as f {
        json.dump({"name": name}, f);
    }
    os.replace(tmp, self.path);
    self.relaunch = True;
    return True;
}
