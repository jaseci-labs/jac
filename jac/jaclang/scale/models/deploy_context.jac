glob DATABASE_URL_ENV: str = "JAC_DB_URL";


obj DeployContext {
    has env_list: list[dict[str, any]] = [],
        init_containers: list[dict[str, any]] = [];
}
