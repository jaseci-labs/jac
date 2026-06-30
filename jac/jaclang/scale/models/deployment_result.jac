obj DeploymentResult {
    has success: bool,
        service_url: (str | None) = None,
        message: (str | None) = None,
        details: dict[str, any] = {};

    def is_successful -> bool {
        return self.success;
    }
}
