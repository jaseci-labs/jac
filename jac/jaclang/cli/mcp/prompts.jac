def load_resource_content(uri: str) -> str;

def build_system_prompt(extra_uris: list[str] = []) -> str;

obj PromptProvider {
    def list_prompts -> list[dict[str, any]];
    def get_prompt(name: str, arguments: dict[str, str]) -> dict[str, any];
}
