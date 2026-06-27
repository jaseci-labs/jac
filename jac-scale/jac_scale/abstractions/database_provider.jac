import from typing { Any }

class DatabaseProvider {
    def deploy(self: DatabaseProvider, config: dict[str, any]) -> dict[str, any];
    def get_connection_string(self: DatabaseProvider) -> str;
    def is_available(self: DatabaseProvider) -> bool;
    def cleanup(self: DatabaseProvider) -> None;
    def get_init_container(
        self: DatabaseProvider, app_name: str, wait_image: str
    ) -> (dict[(str, Any)] | None);
}
