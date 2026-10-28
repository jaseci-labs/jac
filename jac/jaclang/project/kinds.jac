import os;

obj RunPlan {
    has spec: KindSpec,
        entry_path: str,
        flags: dict[str, any],
        summary: str,
        app: str = "";

    has kind: str {
        getter {
            return self.spec.name;
        }
    }

    has action: str {
        getter {
            return self.spec.action;
        }
    }

    has verb: str {
        getter {
            return self.spec.verb;
        }
    }

    def command_line -> str;
    def build_line -> str;
    def:priv _target -> str;
}

def _has_client(config: JacConfig) -> bool;

def resolve_entry(config: JacConfig, project_root: str, app: AppConfig) -> str;

def resolve_app_kind(config: JacConfig, app: AppConfig, entry_path: str) -> str;

def plan_app_run(
    config: JacConfig, project_root: str, app: AppConfig, entry_override: str = ""
) -> RunPlan;

def plan_workspace(config: JacConfig, project_root: str) -> list[RunPlan];
