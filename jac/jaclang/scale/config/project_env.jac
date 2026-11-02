import os;

glob PROJECT_ENV_FILE: str = ".env",
     PROJECT_ENV_CAPABILITY: str = "env";


def project_env_path(code_folder: str) -> str;


def load_project_env(code_folder: str) -> bool;
