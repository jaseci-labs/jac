import os;
import from jaclang.scale._optdeps.optional_deps { require_optional }

glob PROJECT_ENV_FILE: str = ".env",
     PROJECT_ENV_CAPABILITY: str = "env";


def project_env_path(code_folder: str) -> str {
    return os.path.join(code_folder or '.', PROJECT_ENV_FILE);
}


def load_project_env(code_folder: str) -> bool {
    require_optional("dotenv", PROJECT_ENV_CAPABILITY);
    import from dotenv { load_dotenv }
    return bool(load_dotenv(project_env_path(code_folder)));
}
