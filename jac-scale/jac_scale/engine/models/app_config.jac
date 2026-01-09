"""Application configuration model."""
import from typing { Any }

"""Application deployment configuration."""
class AppConfig {
    has name: str,
        image: str,
        env_vars: list[dict[(str, Any)]] = [],
        resources: (dict[(str, Any)] | None) = None,
        health_check: (dict[(str, Any)] | None) = None;
}
