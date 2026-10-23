impl JacAPIServerAdminSurface.register_admin_surface -> None {
    self.register_admin_endpoints();
    self.register_llm_telemetry_endpoints();
    self.register_workloads_endpoints();
    self.register_logs_endpoints();
    self.register_traces_endpoints();
    self.register_ops_endpoints();
    self.register_deploy_health_endpoints();
    self.register_network_endpoints();
    self.register_podenv_endpoints();
}
