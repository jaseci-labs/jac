impl client_runtime_cl_basename(framework: str = "") -> str {
    return build_services().client_runtime_basename(framework);
}

impl resolve_client_runtime_cl_path(framework: str = "") -> str {
    runtime_dir = os.path.dirname(str(_client_pkg.__file__));
    return os.path.join(runtime_dir, client_runtime_cl_basename(framework));
}
