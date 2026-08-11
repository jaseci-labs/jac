glob SUPPORTED_HTTP_INTERCEPTOR_API_VERSIONS: list[str] = ["v1beta1"];

obj KEDACapabilities {
    has core_available: bool = False,
        http_addon_available: bool = False,
        interceptor_route_api_version: (str | None) = None,
        external_scaler_address: (str | None) = None,
        interceptor_service_address: (str | None) = None,
        warnings: list[str] = [],
        errors: list[str] = [];
}
