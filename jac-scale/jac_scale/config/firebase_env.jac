import os;

glob FIREBASE_PROJECT_ID_ENV: str = "FIREBASE_PROJECT_ID",
     FIREBASE_AUTH_PROJECT_ID_ENV: str = "FIREBASE_AUTH_PROJECT_ID",
     FIRESTORE_PROJECT_ID_ENV: str = "FIRESTORE_PROJECT_ID",
     JAC_STORAGE_FIREBASE_PROJECT_ID_ENV: str = "JAC_STORAGE_FIREBASE_PROJECT_ID",
     JAC_STORAGE_GCS_PROJECT_ID_ENV: str = "JAC_STORAGE_GCS_PROJECT_ID";

def resolve_firebase_project_id(
    specific_env_vars: (list[str] | str | None) = None,
    config_value: (str | None) = None
) -> (str | None) {
    env_vars: list[str];
    if isinstance(specific_env_vars, str) {
        env_vars = [specific_env_vars];
    } elif specific_env_vars {
        env_vars = specific_env_vars;
    } else {
        env_vars = [];
    }
    for env_var in env_vars {
        val = os.environ.get(env_var);
        if val {
            return val;
        }
    }
    shared = os.environ.get(FIREBASE_PROJECT_ID_ENV);
    if shared {
        return shared;
    }
    if config_value {
        return config_value;
    }
    return None;
}

def firebase_project_id_env_hint -> str {
    return (
        "Set FIREBASE_PROJECT_ID (shared), or a subsystem env var: "
        "FIREBASE_AUTH_PROJECT_ID (SSO), FIRESTORE_PROJECT_ID (Firestore), "
        "JAC_STORAGE_FIREBASE_PROJECT_ID / JAC_STORAGE_GCS_PROJECT_ID (Storage)."
    );
}
