obj SpawnedBunService {
    has base_url: str,
        proc: any;
}


def spawn_bun_sv_service(
    module_name: str,
    base_path: str,
    port: int,
    *,
    scale_mode: bool = False,
    health_timeout: (float | None) = None,
    progress: any = None
) -> SpawnedBunService;
