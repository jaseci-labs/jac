import os;

glob FIREBASE_PROJECT_ID_ENV: str = "FIREBASE_PROJECT_ID",
     FIREBASE_AUTH_PROJECT_ID_ENV: str = "FIREBASE_AUTH_PROJECT_ID",
     FIRESTORE_PROJECT_ID_ENV: str = "FIRESTORE_PROJECT_ID",
     JAC_STORAGE_FIREBASE_PROJECT_ID_ENV: str = "JAC_STORAGE_FIREBASE_PROJECT_ID",
     JAC_STORAGE_GCS_PROJECT_ID_ENV: str = "JAC_STORAGE_GCS_PROJECT_ID";

def resolve_firebase_project_id(
    specific_env_vars: (list[str] | str | None) = None,
    config_value: (str | None) = None
) -> (str | None);

def firebase_project_id_env_hint -> str;
